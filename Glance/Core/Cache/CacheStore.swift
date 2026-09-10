import Foundation

actor CacheStore {
    static let shared = CacheStore()
    static var preview: CacheStore { CacheStore() }

    private var memory: [String: Data] = [:]

    func save<T: Codable & Sendable>(_ key: String, envelope: CacheEnvelope<T>) {
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        memory[key] = data
    }

    func load<T: Codable & Sendable>(_ key: String) -> CacheEnvelope<T>? {
        guard let data = memory[key] else { return nil }
        return try? JSONDecoder().decode(CacheEnvelope<T>.self, from: data)
    }

    func remove(_ key: String) {
        memory.removeValue(forKey: key)
    }

    func clearAll() {
        memory.removeAll()
    }
}
