import Testing
@testable import Glance
import Foundation

@Suite("CacheStore")
struct CacheStoreTests {
    private func makeStore() -> CacheStore {
        CacheStore(userDefaults: UserDefaults(suiteName: "test.CacheStore.\(UUID().uuidString)")!)
    }

    @Test("Save and load round-trip")
    func roundTrip() async {
        let store = makeStore()
        let envelope = CacheEnvelope(data: "test-value", ttlMs: 60_000)
        await store.save("test-key-roundtrip", envelope: envelope)
        let loaded: CacheEnvelope<String>? = await store.load("test-key-roundtrip")
        #expect(loaded?.data == "test-value")
        #expect(loaded?.isExpired == false)
        await store.remove("test-key-roundtrip")
    }

    @Test("Expired envelope reports expired")
    func expired() async {
        let envelope = CacheEnvelope(data: "old", ttlMs: 0)
        #expect(envelope.isExpired == true)
    }

    @Test("Permanent envelope never expires")
    func permanent() async {
        let envelope = CacheEnvelope(data: "forever", ttlMs: nil)
        #expect(envelope.isExpired == false)
    }

    @Test("ClearAll keeps keychain keys")
    func clearAll() async {
        let store = makeStore()
        await store.save("cache_pogo", envelope: CacheEnvelope(data: "x", ttlMs: nil))
        await store.clearAll()
        let loaded: CacheEnvelope<String>? = await store.load("cache_pogo")
        #expect(loaded == nil)
    }

    @Test("Custom RSS key uses prefix")
    func customRSSKey() {
        let key = CacheStore.customRSSKey(feedID: "abc-123")
        #expect(key == "cache_custom_rss_abc-123")
        #expect(key.hasPrefix(CacheStore.customRSSPrefix))
    }

    @Test("Custom RSS TTL is 24 hours")
    func customRSTTL() async {
        let store = makeStore()
        let ttl = await store.ttl(for: CacheStore.customRSSKey(feedID: "feed-1"))
        #expect(ttl == 24 * 3_600)
    }

    @Test("Custom RSS save and load round-trip")
    func customRSSRoundTrip() async {
        let store = makeStore()
        let key = CacheStore.customRSSKey(feedID: "round-trip-feed")
        let envelope = CacheEnvelope(data: ["article-1", "article-2"], ttlMs: 24 * 3_600_000)
        await store.save(key, envelope: envelope)
        let loaded: CacheEnvelope<[String]>? = await store.load(key)
        #expect(loaded?.data == ["article-1", "article-2"])
        let valid = await store.isValid(key: key)
        #expect(valid == true)
        await store.remove(key)
    }

    @Test("ClearAll removes custom RSS keys")
    func clearAllRemovesCustomRSS() async {
        let store = makeStore()
        let key = CacheStore.customRSSKey(feedID: "clear-me")
        await store.save(key, envelope: CacheEnvelope(data: ["a"], ttlMs: 1000))
        await store.clearAll()
        let loaded: CacheEnvelope<[String]>? = await store.load(key)
        #expect(loaded == nil)
    }

    @Test("ClearAll removes github trending keys")
    func clearAllRemovesGitHubTrending() async {
        let store = makeStore()
        let key = "cache_github_trending_daily"
        await store.save(key, envelope: CacheEnvelope(data: ["repo"], ttlMs: 1000))
        await store.clearAll()
        let loaded: CacheEnvelope<[String]>? = await store.load(key)
        #expect(loaded == nil)
    }

    @Test("Expired envelope still loads with data")
    func expiredStillLoads() async {
        let store = makeStore()
        let key = CacheStore.customRSSKey(feedID: "stale-feed")
        await store.save(key, envelope: CacheEnvelope(data: ["old"], ttlMs: 0))
        let loaded: CacheEnvelope<[String]>? = await store.load(key)
        #expect(loaded != nil)
        #expect(loaded?.data == ["old"])
        #expect(loaded?.isExpired == true)
        await store.remove(key)
    }

    @Test("GenericRSSPipeline loadCached returns expired envelope")
    func loadCachedReturnsExpired() async {
        let store = makeStore()
        let pipeline = GenericRSSPipeline(cache: store)
        let feed = CustomRSSFeed(name: "Stale", url: "https://example.com/rss")
        let key = CacheStore.customRSSKey(feedID: feed.id.uuidString)
        let article = MMArticle(
            id: "1", title: "T", url: "https://example.com/1", published: "",
            author: "", category: "", content: "", scrapedContent: ""
        )
        await store.save(key, envelope: CacheEnvelope(data: [article], ttlMs: 0))
        let loaded = await pipeline.loadCached(feed: feed)
        #expect(loaded != nil)
        #expect(loaded?.isExpired == true)
        #expect(loaded?.data.count == 1)
        await store.remove(key)
    }
}
