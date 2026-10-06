import Testing
@testable import Glance
import Foundation

final class InMemoryKeychain: KeychainStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: String] = [:]
    var failSavesFor: Set<String> = []

    func save(_ value: String, forKey key: String) throws {
        guard !value.isEmpty else { throw KeychainError.emptyValue }
        if failSavesFor.contains(key) { throw KeychainError.saveFailed(errSecMissingEntitlement) }
        lock.withLock { store[key] = value }
    }

    func load(forKey key: String) -> String? {
        lock.withLock { store[key] }
    }

    func remove(forKey key: String) {
        lock.withLock { _ = store.removeValue(forKey: key) }
    }

    var keys: [String] {
        lock.withLock { Array(store.keys).sorted() }
    }
}

@Suite("API key persistence")
@MainActor
struct SettingsStoreKeyPersistenceTests {
    @Test("Keys stay stored across a fresh store instance")
    func keysSurviveFreshStore() {
        let keychain = InMemoryKeychain()
        let first = SettingsStore(keychain: keychain)
        first.setDraftValue("exa-secret", for: .exa)
        first.setDraftValue("gemini-secret", for: .gemini)
        first.setDraftValue("openrouter-secret", for: .openRouter)

        let failures = first.saveToKeychain()
        #expect(failures.isEmpty)

        let reopened = SettingsStore(keychain: keychain)
        reopened.refreshKeyState()

        #expect(reopened.isStored(.exa))
        #expect(reopened.isStored(.gemini))
        #expect(reopened.isStored(.openRouter))
        #expect(reopened.storedKeys == Set(ApiKey.allCases))
    }

    @Test("Fresh store reports nothing stored before any save")
    func freshStoreIsEmpty() {
        let store = SettingsStore(keychain: InMemoryKeychain())
        store.refreshKeyState()
        #expect(store.storedKeys.isEmpty)
        #expect(!store.isStored(.exa))
    }

    @Test("Presence comes from the keychain, not the draft field")
    func presenceIgnoresDraftField() {
        let keychain = InMemoryKeychain()
        let store = SettingsStore(keychain: keychain)
        store.refreshKeyState()
        #expect(!store.isStored(.exa))

        store.setDraftValue("typed-but-unsaved", for: .exa)
        #expect(!store.isStored(.exa), "draft text must not mark a key as configured")

        store.saveToKeychain()
        #expect(store.isStored(.exa))
    }

    @Test("All three keys persist together")
    func allThreePersistTogether() {
        let keychain = InMemoryKeychain()
        let store = SettingsStore(keychain: keychain)
        store.setDraftValue("a", for: .exa)
        store.setDraftValue("b", for: .gemini)
        store.setDraftValue("c", for: .openRouter)

        #expect(store.saveToKeychain().isEmpty)
        #expect(keychain.keys == ["keys_exa", "keys_gemini", "keys_openrouter"])
    }

    @Test("Empty draft does not delete an already-stored key")
    func emptyDraftDoesNotDelete() {
        let keychain = InMemoryKeychain()
        let store = SettingsStore(keychain: keychain)
        store.setDraftValue("keep-me", for: .exa)
        #expect(store.saveToKeychain().isEmpty)

        store.setDraftValue("", for: .exa)
        #expect(store.saveToKeychain().isEmpty)
        #expect(store.isStored(.exa), "empty field must not wipe a stored key")
        #expect(keychain.load(forKey: "keys_exa") == "keep-me")
    }

    @Test("Clear removes exactly one key and leaves the others")
    func clearRemovesOne() {
        let keychain = InMemoryKeychain()
        let store = SettingsStore(keychain: keychain)
        store.setDraftValue("a", for: .exa)
        store.setDraftValue("b", for: .gemini)
        store.saveToKeychain()

        store.clearStoredKey(.exa)

        #expect(!store.isStored(.exa))
        #expect(store.isStored(.gemini))
        #expect(keychain.load(forKey: "keys_exa") == nil)
        #expect(keychain.load(forKey: "keys_gemini") == "b")
    }

    @Test("Failed save is reported and does not mark the key as stored")
    func failedSaveIsReported() {
        let keychain = InMemoryKeychain()
        keychain.failSavesFor = ["keys_exa"]
        let store = SettingsStore(keychain: keychain)
        store.setDraftValue("exa-secret", for: .exa)
        store.setDraftValue("gemini-secret", for: .gemini)

        let failures = store.saveToKeychain()

        #expect(failures.count == 1)
        #expect(failures[.exa] == .saveFailed(errSecMissingEntitlement))
        #expect(!store.isStored(.exa), "a failed write must not read as configured")
        #expect(store.isStored(.gemini), "a successful sibling key must still be stored")
    }

    @Test("Masked key never leaks the raw value")
    func maskedKeyIsMasked() {
        let keychain = InMemoryKeychain()
        let store = SettingsStore(keychain: keychain)
        store.setDraftValue("abcdefghijklmnop", for: .exa)
        store.saveToKeychain()

        let masked = store.maskedKey(.exa)
        #expect(masked == "abcd••••mnop")
        #expect(!(masked ?? "").contains("efghij"))
    }

    @Test("Short keys are fully masked")
    func shortKeyFullyMasked() {
        let keychain = InMemoryKeychain()
        let store = SettingsStore(keychain: keychain)
        store.setDraftValue("short", for: .gemini)
        store.saveToKeychain()
        #expect(store.maskedKey(.gemini) == "••••••••")
    }

    @Test("Missing key has no masked representation")
    func missingKeyHasNoMask() {
        let store = SettingsStore(keychain: InMemoryKeychain())
        store.refreshKeyState()
        #expect(store.maskedKey(.openRouter) == nil)
    }

    @Test("Draft values round-trip per key")
    func draftValuesRoundTrip() {
        let store = SettingsStore(keychain: InMemoryKeychain())
        for key in ApiKey.allCases {
            store.setDraftValue("value-\(key.rawValue)", for: key)
            #expect(store.draftValue(for: key) == "value-\(key.rawValue)")
        }
    }
}

/// Separate suite because these write to `UserDefaults.standard` rather than the
/// Keychain, and because the toggle is read by the summary card rather than the
/// key forms. Every test restores the key it touched — the shared defaults object
/// is a documented source of cross-suite interference in full/parallel runs.
@Suite("Cloud summary default")
@MainActor
struct CloudSummaryDefaultTests {
    private let defaultsKey = "cloud_summaries_default"

    private func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    @Test("Defaults to on-device, not cloud")
    func defaultsToLocal() {
        reset()
        defer { reset() }
        #expect(!SettingsStore(keychain: InMemoryKeychain()).cloudSummariesByDefault)
    }

    @Test("Turning it on survives a fresh store instance")
    func cloudDefaultPersists() {
        reset()
        defer { reset() }

        let store = SettingsStore(keychain: InMemoryKeychain())
        store.cloudSummariesByDefault = true

        let reopened = SettingsStore(keychain: InMemoryKeychain())
        #expect(reopened.cloudSummariesByDefault)
    }

    @Test("Turning it back off is stored, not treated as unset")
    func explicitFalseIsStored() {
        reset()
        defer { reset() }

        let store = SettingsStore(keychain: InMemoryKeychain())
        store.cloudSummariesByDefault = true
        store.cloudSummariesByDefault = false

        // Guards the `object(forKey:) as? Bool` cast: a plain `bool(forKey:)`
        // cannot tell a stored `false` from a missing key, and the default is
        // also `false`, so this only catches a regression to a truthy default.
        #expect(UserDefaults.standard.object(forKey: defaultsKey) != nil)
        #expect(!SettingsStore(keychain: InMemoryKeychain()).cloudSummariesByDefault)
    }
}
