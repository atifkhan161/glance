import Foundation

struct MadridPipeline: Sendable {
    private let exa: any ExaClientProtocol
    private let madridClient: any ManagingMadridClientProtocol
    private let router: IntelligenceRouter
    private let cache: CacheStore
    private let keychain: KeychainStore

    init(
        exa: any ExaClientProtocol = ExaClient(),
        madridClient: any ManagingMadridClientProtocol = ManagingMadridClient(),
        router: IntelligenceRouter = IntelligenceRouter(),
        cache: CacheStore = .shared,
        keychain: KeychainStore = .shared
    ) {
        self.exa = exa
        self.madridClient = madridClient
        self.router = router
        self.cache = cache
        self.keychain = keychain
    }

    static func normaliseOpponent(_ raw: String) -> String {
        let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return clubNormalise[key] ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func looseDateParse(_ text: String) -> Date? {
        if let iso = Self.isoToken(in: text) { return iso }
        if let dated = Self.textDateTime(in: text) { return dated }
        if let dateOnly = Self.dateOnly(in: text) { return dateOnly }
        return nil
    }

    func refresh(force: Bool = false) async -> MadridRefreshResult {
        async let exaTask: [ExaResult]? = {
            guard let key = self.keychain.load(forKey: "keys_exa") else { return nil }
            return try? await self.exa.search(query: "Real Madrid next match fixture upcoming schedule", apiKey: key)
        }()
        async let mmTask: [MMArticle] = {
            (try? await self.madridClient.fetchArticles()) ?? []
        }()
        let exaResults = await exaTask
        let mmArticles = await mmTask

        guard let results = exaResults else {
            let cached: CacheEnvelope<MadridData>? = await cache.load("cache_madrid")
            if let cached { return .keyMissing(cachedData: cached.data, mmArticles: mmArticles) }
            return .keyMissing(cachedData: nil, mmArticles: mmArticles)
        }
        if results.isEmpty {
            return .degraded(
                data: MadridData(
                    fixture: nil, schedule: [], form: [], standing: "",
                    intel: "No match data available", headToHead: nil,
                    articles: [], mmArticles: mmArticles, source: "none", timestamp: Date.now
                ),
                reason: "No results"
            )
        }

        let articles = results.map {
            ExaArticle(
                title: $0.title, url: $0.url, publishedDate: $0.publishedDate,
                highlights: $0.highlights, image: $0.image
            )
        }
        let parsed = Self.parseFixture(from: results)
        let snippets = results.flatMap { $0.highlights }.joined(separator: "\n")
        let (enrichment, source) = await router.enrichMadrid(snippets: snippets)

        // Extract form dots from parsed results
        let formDots = parsed.formDots
        let formStrings = formDots.map { "\($0.result) \($0.score)" }

        let data = MadridData(
            fixture: parsed.fixture,
            schedule: parsed.schedule,
            form: enrichment?.form ?? formStrings,
            standing: enrichment?.standing ?? "",
            intel: enrichment?.intel ?? generateFallbackIntel(for: parsed.fixture),
            headToHead: enrichment?.headToHead,
            articles: articles,
            mmArticles: mmArticles,
            source: source,
            timestamp: Date.now
        )
        await cache.save("cache_madrid", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return parsed.fixture == nil ? .degraded(data: data, reason: "No fixture") : .ready(data: data)
    }

    private func generateFallbackIntel(for fixture: Fixture?) -> String {
        guard let fixture else { return "Real Madrid latest updates" }
        return "Upcoming match: Real Madrid vs \(fixture.opponent) in \(fixture.competition)"
    }
}

enum MadridRefreshResult: Sendable, Equatable {
    case ready(data: MadridData)
    case degraded(data: MadridData, reason: String)
    case keyMissing(cachedData: MadridData?, mmArticles: [MMArticle])
}
