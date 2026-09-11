import Testing
@testable import Glance
import Foundation

@Suite("Cache TTL and Eviction")
struct CacheTTTests {
    @Test("Default TTL for madrid cache")
    func madridTTL() {
        let ttl = CacheStore.defaultTTLs["cache_madrid"] ?? 0
        #expect(ttl == 6 * 3_600)
    }

    @Test("Default TTL for github cache")
    func githubTTL() {
        let ttl = CacheStore.defaultTTLs["cache_github"] ?? 0
        #expect(ttl == 24 * 3_600)
    }

    @Test("Default TTL for aiintel cache")
    func aiintelTTL() {
        let ttl = CacheStore.defaultTTLs["cache_aiintel"] ?? 0
        #expect(ttl == 12 * 3_600)
    }

    @Test("CacheStore size tracking")
    func sizeTracking() async {
        let store = CacheStore.preview
        await store.clearAll()
        let size = await store.currentSize
        #expect(size >= 0)
    }

    @Test("Fresh envelope is not expired")
    func freshEnvelope() {
        let envelope = CacheEnvelope(data: "test", ttlMs: 3_600_000)
        #expect(envelope.isExpired == false)
    }

    @Test("Zero TTL is immediately expired")
    func zeroTTL() {
        let envelope = CacheEnvelope(data: "instant", ttlMs: 0)
        #expect(envelope.isExpired == true)
    }

    @Test("Nil TTL never expires")
    func nilTTLNeverExpires() {
        let envelope = CacheEnvelope(data: "permanent", ttlMs: nil)
        #expect(envelope.isExpired == false)
    }
}
