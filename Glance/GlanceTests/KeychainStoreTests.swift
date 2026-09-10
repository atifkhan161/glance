import Testing
@testable import Glance

@Suite("KeychainStore")
struct KeychainStoreTests {
    @Test("Stub loads nil")
    func stubNil() {
        #expect(KeychainStore.shared.load(forKey: "missing") == nil)
    }
}
