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
        return (try? await client.fetchArticles(from: feed.url)) ?? []
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
