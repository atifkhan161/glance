import Foundation

struct GenericRSSPipeline: Sendable {
    private let client: GenericRSSClient
    private let cache: CacheStore

    init(client: GenericRSSClient = GenericRSSClient(), cache: CacheStore = .shared) {
        self.client = client
        self.cache = cache
    }

    func refresh(feed: CustomRSSFeed) async -> [MMArticle] {
        guard feed.isEnabled, !feed.url.isEmpty else { return [] }
        guard let articles = try? await client.fetchArticles(from: feed.url), !articles.isEmpty else {
            return []
        }
        let envelope = CacheEnvelope(data: articles, ttlMs: Int64(CacheStore.customRSSFreshTTL * 1000))
        await cache.save(CacheStore.customRSSKey(feedID: feed.id.uuidString), envelope: envelope)
        return articles
    }

    func loadCached(feed: CustomRSSFeed) async -> CacheEnvelope<[MMArticle]>? {
        let key = CacheStore.customRSSKey(feedID: feed.id.uuidString)
        let envelope: CacheEnvelope<[MMArticle]>? = await cache.load(key)
        return envelope
    }

    func refreshAll(feeds: [CustomRSSFeed]) async -> [String: [MMArticle]] {
        var results: [String: [MMArticle]] = [:]
        for feed in feeds {
            let articles = await refresh(feed: feed)
            if !articles.isEmpty {
                results[feed.id.uuidString] = articles
            }
        }
        return results
    }
}
