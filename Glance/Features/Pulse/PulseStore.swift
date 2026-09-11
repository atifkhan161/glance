import Foundation

enum CardID: String, CaseIterable, Hashable, Sendable {
    case madrid, pogo, github, aiIntel
}

enum CardState<T: Codable & Sendable & Equatable>: Equatable {
    case loading
    case ready(data: T, age: String)
    case stale(data: T, age: String)
    case degraded(data: T, age: String, reason: String)
    case error(message: String)
    case offline(data: T, age: String)
    case keyMissing(keyName: String)

    var age: String? {
        switch self {
        case .ready(_, let age), .stale(_, let age), .degraded(_, let age, _), .offline(_, let age): age
        default: nil
        }
    }
}

@MainActor
@Observable
final class PulseStore {
    var madrid: CardState<MadridData> = .loading
    var pogo: CardState<PoGoData> = .loading
    var github: CardState<GitHubData> = .loading
    var aiIntel: CardState<AiIntelData> = .loading

    var freshestCacheAge: String {
        [madridAge, pogoAge, githubAge, aiIntelAge]
            .compactMap { $0 }
            .sorted()
            .first ?? "never"
    }

    var needsRefresh: Bool {
        if case .ready = madrid {} else { return true }
        if case .ready = pogo {} else { return true }
        if case .ready = github {} else { return true }
        if case .ready = aiIntel {} else { return true }
        return false
    }

    private var madridAge: String? { madrid.age }
    private var pogoAge: String? { pogo.age }
    private var githubAge: String? { github.age }
    private var aiIntelAge: String? { aiIntel.age }

    private let cache: CacheStore
    private let madridPipeline: MadridPipeline
    private let pogoPipeline: PoGoPipeline
    private let githubPipeline: GitHubPipeline
    private let aiIntelPipeline: AiIntelPipeline

    init(
        cache: CacheStore = .shared,
        madridPipeline: MadridPipeline = MadridPipeline(),
        pogoPipeline: PoGoPipeline = PoGoPipeline(),
        githubPipeline: GitHubPipeline = GitHubPipeline(),
        aiIntelPipeline: AiIntelPipeline = AiIntelPipeline()
    ) {
        self.cache = cache
        self.madridPipeline = madridPipeline
        self.pogoPipeline = pogoPipeline
        self.githubPipeline = githubPipeline
        self.aiIntelPipeline = aiIntelPipeline
    }

    func loadFromCache() async {
        async let madridEnvelope: CacheEnvelope<MadridData>? = cache.load("cache_madrid")
        async let pogoEnvelope: CacheEnvelope<PoGoData>? = cache.load("cache_pogo")
        async let githubEnvelope: CacheEnvelope<GitHubData>? = cache.load("cache_github")
        async let aiIntelEnvelope: CacheEnvelope<AiIntelData>? = cache.load("cache_aiintel")
        let (m, p, g, a) = await (madridEnvelope, pogoEnvelope, githubEnvelope, aiIntelEnvelope)
        if let m { madrid = .ready(data: m.data, age: TimeFormat.age(from: Date(timeIntervalSince1970: TimeInterval(m.timestampMs) / 1000))) }
        if let p { pogo = .ready(data: p.data, age: TimeFormat.age(from: Date(timeIntervalSince1970: TimeInterval(p.timestampMs) / 1000))) }
        if let g { github = .ready(data: g.data, age: TimeFormat.age(from: Date(timeIntervalSince1970: TimeInterval(g.timestampMs) / 1000))) }
        if let a { aiIntel = .ready(data: a.data, age: TimeFormat.age(from: Date(timeIntervalSince1970: TimeInterval(a.timestampMs) / 1000))) }
    }

    func refreshAll() async {
        await refresh(.madrid)
        await refresh(.pogo)
        await refresh(.github)
        await refresh(.aiIntel)
    }

    func refreshCard(_ card: CardID) async {
        await refresh(card, force: true)
    }

    func refresh(_ card: CardID, force: Bool = false) async {
        let cacheKey: String
        switch card {
        case .madrid: cacheKey = "cache_madrid"
        case .pogo: cacheKey = "cache_pogo"
        case .github: cacheKey = "cache_github"
        case .aiIntel: cacheKey = "cache_aiintel"
        }

        if !force {
            let isValid = await cache.isValid(key: cacheKey)
            if isValid {
                switch card {
                case .madrid:
                    if case .ready = madrid { return }
                case .pogo:
                    if case .ready = pogo { return }
                case .github:
                    if case .ready = github { return }
                case .aiIntel:
                    if case .ready = aiIntel { return }
                }
            }
        }
        switch card {
        case .madrid:
            if case .ready(let data, let age) = madrid { madrid = .stale(data: data, age: age) }
            switch await madridPipeline.refresh() {
            case .ready(let data):
                madrid = .ready(data: data, age: TimeFormat.age(from: data.timestamp))
            case .degraded(let data, let reason):
                madrid = .degraded(data: data, age: TimeFormat.age(from: data.timestamp), reason: reason)
            case .keyMissing(let cachedData, _):
                if let cachedData {
                    madrid = .keyMissing(keyName: "keys_exa")
                    _ = cachedData
                } else {
                    madrid = .keyMissing(keyName: "keys_exa")
                }
            }
        case .pogo:
            if case .ready(let data, let age) = pogo { pogo = .stale(data: data, age: age) }
            let data = await pogoPipeline.refresh()
            pogo = .ready(data: data, age: TimeFormat.age(from: data.timestamp))
        case .github:
            if case .ready(let data, let age) = github { github = .stale(data: data, age: age) }
            do {
                let data = try await githubPipeline.refresh()
                github = .ready(data: data, age: TimeFormat.age(from: data.timestamp))
            } catch {
                print("[PulseStore] GitHub refresh failed: \(error)")
                if case .stale(let data, _) = github {
                    github = .offline(data: data, age: TimeFormat.age(from: data.timestamp))
                } else {
                    github = .error(message: "GitHub refresh failed: \(error.localizedDescription)")
                }
            }
        case .aiIntel:
            if case .ready(let data, let age) = aiIntel { aiIntel = .stale(data: data, age: age) }
            switch await aiIntelPipeline.refresh() {
            case .ready(let data):
                aiIntel = .ready(data: data, age: TimeFormat.age(from: data.timestamp))
            case .degraded(let data, let reason):
                aiIntel = .degraded(data: data, age: TimeFormat.age(from: data.timestamp), reason: reason)
            case .keyMissing:
                aiIntel = .keyMissing(keyName: "keys_exa")
            }
        }
    }
}
