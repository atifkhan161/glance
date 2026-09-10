import Testing
@testable import Glance
import Foundation

@Suite("KeychainStore")
struct KeychainStoreTests {
    @Test("Save and load key")
    func roundTrip() throws {
        let store = KeychainStore()
        let testKey = "test_key_\(UUID().uuidString)"
        try store.save("secret123", forKey: testKey)
        let loaded = store.load(forKey: testKey)
        #expect(loaded == "secret123")
        store.remove(forKey: testKey)
    }

    @Test("Load missing key returns nil")
    func missingKey() {
        let store = KeychainStore()
        let loaded = store.load(forKey: "nonexistent_\(UUID().uuidString)")
        #expect(loaded == nil)
    }
}
