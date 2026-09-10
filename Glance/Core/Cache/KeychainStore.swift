import Foundation

struct KeychainStore: Sendable {
    static let shared = KeychainStore()

    func save(_ value: String, forKey key: String) {}
    func load(forKey key: String) -> String? { nil }
    func remove(forKey key: String) {}
}
