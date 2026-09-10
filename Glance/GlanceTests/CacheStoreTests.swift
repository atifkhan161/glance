import Testing
@testable import Glance

@Suite("CacheStore")
struct CacheStoreTests {
    @Test("Save and load round-trip")
    func roundTrip() async {
        let store = CacheStore.preview
        let envelope = CacheEnvelope(data: "test-value", ttlMs: 60_000)
        await store.save("test-key", envelope: envelope)
        let loaded: CacheEnvelope<String>? = await store.load("test-key")
        #expect(loaded?.data == "test-value")
        #expect(loaded?.isExpired == false)
    }

    @Test("Expired envelope reports expired")
    func expired() {
        let envelope = CacheEnvelope(data: "old", ttlMs: 0)
        #expect(envelope.isExpired)
    }
}
