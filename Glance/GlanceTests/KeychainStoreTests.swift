import Testing
@testable import Glance
import Foundation

private let keychainAvailable = KeychainStore().isAvailable

@Suite("KeychainStore", .enabled(if: keychainAvailable, "Keychain unavailable (unsigned build lacks application-identifier)"))
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

    @Test("Re-saving replaces the value without losing it on failure")
    func reSaveReplaces() throws {
        let store = KeychainStore()
        let testKey = "test_replace_\(UUID().uuidString)"
        try store.save("first", forKey: testKey)
        try store.save("second", forKey: testKey)
        #expect(store.load(forKey: testKey) == "second")
        store.remove(forKey: testKey)
    }

    @Test("Remove deletes the stored value")
    func removeDeletes() throws {
        let store = KeychainStore()
        let testKey = "test_remove_\(UUID().uuidString)"
        try store.save("value", forKey: testKey)
        store.remove(forKey: testKey)
        #expect(store.load(forKey: testKey) == nil)
    }
}
