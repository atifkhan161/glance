import Testing
@testable import Glance
import Foundation

@Suite("CacheStore")
struct CacheStoreTests {
    @Test("Save and load round-trip")
    func roundTrip() async {
        let store = CacheStore.preview
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
        let store = CacheStore.preview
        await store.save("cache_pogo", envelope: CacheEnvelope(data: "x", ttlMs: nil))
        await store.clearAll()
        let loaded: CacheEnvelope<String>? = await store.load("cache_pogo")
        #expect(loaded == nil)
    }
}
