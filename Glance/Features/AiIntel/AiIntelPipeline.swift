import Foundation

struct AiIntelPipeline: Sendable {
    private let exa: any ExaClientProtocol
    private let router: IntelligenceRouter
    private let cache: CacheStore
    private let keychain: KeychainStore

    init(
        exa: any ExaClientProtocol = ExaClient(),
        router: IntelligenceRouter = IntelligenceRouter(),
        cache: CacheStore = .shared,
        keychain: KeychainStore = .shared
    ) {
        self.exa = exa
        self.router = router
        self.cache = cache
        self.keychain = keychain
    }

    static func classifyTag(headline: String, source: String) -> String {
        let text = (headline + " " + source).lowercased()
        let frontier = ["openai", "anthropic", "deepmind", "google", "meta"]
        return frontier.contains { text.contains($0) } ? "FRONTIER LABS" : "OPEN WEIGHTS"
    }

    func refresh(force: Bool = false) async -> AiIntelRefreshResult {
        guard let key = keychain.load(forKey: "keys_exa") else {
            let cached: CacheEnvelope<AiIntelData>? = await cache.load("cache_aiintel")
            return .keyMissing(cachedData: cached?.data)
        }
        let results = (try? await exa.search(
            query: "latest AI LLM breakthroughs, open source releases, frontier lab announcements",
            apiKey: key
        )) ?? []
        if results.isEmpty {
            return .degraded(data: AiIntelData(items: [], source: "none", timestamp: Date.now), reason: "No results")
        }
        let articles = results.map { r in
            ExaArticle(
                title: r.title, url: r.url, publishedDate: r.publishedDate,
                highlights: r.highlights, image: r.image
            )
        }
        let snippets = results.flatMap { $0.highlights }.joined(separator: "\n")
        if let structured = await router.briefAiIntel(snippets: snippets) {
            let items = structured.items.prefix(3).enumerated().map { i, item in
                AiIntelArticle(
                    id: articles.indices.contains(i) ? articles[i].url : item.headline,
                    tag: item.tag,
                    headline: item.headline,
                    url: articles.indices.contains(i) ? articles[i].url : "",
                    source: articles.indices.contains(i) ? URL(string: articles[i].url)?.host ?? "" : "",
                    author: "",
                    publishedDate: articles.indices.contains(i) ? articles[i].publishedDate : nil,
                    image: articles.indices.contains(i) ? articles[i].image : nil,
                    bullets: item.bullets,
                    highlights: item.bullets,
                    benchmarks: item.benchmarks ?? []
                )
            }
            let data = AiIntelData(items: Array(items), source: "apple", timestamp: Date.now)
            await cache.save("cache_aiintel", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
            return .ready(data: data)
        }
        let items = articles.prefix(3).map { a in
            AiIntelArticle(
                id: a.url, tag: "OPEN WEIGHTS", headline: a.title, url: a.url,
                source: URL(string: a.url)?.host ?? "", author: "",
                publishedDate: a.publishedDate, image: a.image,
                bullets: [a.highlights.first ?? ""], highlights: a.highlights, benchmarks: []
            )
        }
        let data = AiIntelData(items: Array(items), source: "none", timestamp: Date.now)
        await cache.save("cache_aiintel", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return .degraded(data: data, reason: "AI unavailable")
    }
}

enum AiIntelRefreshResult: Sendable, Equatable {
    case ready(data: AiIntelData)
    case degraded(data: AiIntelData, reason: String)
    case keyMissing(cachedData: AiIntelData?)
}
