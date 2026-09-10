import Foundation

actor CacheStore {
    static let shared = CacheStore()
    static var preview: CacheStore { CacheStore() }

    private var memory: [String: Data] = [:]
    private let defaults = UserDefaults.standard

    func hydrate() {
        for key in Self.allCacheKeys {
            if let data = defaults.data(forKey: key) {
                memory[key] = data
            }
        }
    }

    func load<T: Codable & Sendable>(_ key: String) -> CacheEnvelope<T>? {
        if let data = memory[key],
           let envelope = try? JSONDecoder().decode(CacheEnvelope<T>.self, from: data) {
            return envelope
        }
        if let data = defaults.data(forKey: key),
           let envelope = try? JSONDecoder().decode(CacheEnvelope<T>.self, from: data) {
            memory[key] = data
            return envelope
        }
        return nil
    }

    func save<T: Codable & Sendable>(_ key: String, envelope: CacheEnvelope<T>) {
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        memory[key] = data
        defaults.set(data, forKey: key)
    }

    func remove(_ key: String) {
        memory.removeValue(forKey: key)
        defaults.removeObject(forKey: key)
    }

    func clearAll() {
        for key in Self.allCacheKeys {
            memory.removeValue(forKey: key)
            defaults.removeObject(forKey: key)
        }
    }

    static let allCacheKeys = [
        "cache_madrid",
        "cache_pogo",
        "cache_github",
        "cache_aiintel",
        "cache_scrapedd",
        "cache_github_raw",
        "gemini_model",
    ]
}
