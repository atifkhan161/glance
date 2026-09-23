import Foundation

actor CacheStore {
    static let shared = CacheStore()
    static var preview: CacheStore { CacheStore() }

    private var memory: [String: Data] = [:]
    private let defaults = UserDefaults.standard

    private static let maxCacheSize = 10 * 1_024 * 1_024 // 10 MB
    private static let evictionThreshold = 8 * 1_024 * 1_024 // 8 MB

    static let customRSSPrefix = "cache_custom_rss_"
    static let customRSSFreshTTL: TimeInterval = 24 * 3_600

    static let defaultTTLs: [String: TimeInterval] = [
        "cache_madrid": 6 * 3_600,    // 6 hours
        "cache_pogo": 6 * 3_600,      // 6 hours
        "cache_github": 24 * 3_600,   // 24 hours (legacy)
        "cache_github_trending_daily": 24 * 3_600,
        "cache_github_trending_weekly": 24 * 3_600,
        "cache_github_trending_monthly": 24 * 3_600,
        "cache_aiintel": 12 * 3_600,  // 12 hours
        "cache_exa_search": 24 * 3_600,   // 24 hours
        "cache_exa_summary": 24 * 3_600,  // 24 hours
        customRSSPrefix + "*": 24 * 3_600, // custom RSS feeds
    ]

    static func customRSSKey(feedID: String) -> String {
        customRSSPrefix + feedID
    }

    private func allKeys() -> [String] {
        var keys = Set(Self.allCacheKeys)
        let defaultsKeys = defaults.dictionaryRepresentation().keys
        for key in defaultsKeys where key.hasPrefix("cache_") && !key.hasSuffix("_meta") {
            keys.insert(key)
        }
        return Array(keys)
    }

    func hydrate() {
        for key in allKeys() {
            if let data = defaults.data(forKey: key) {
                memory[key] = data
            }
        }
        evictIfNeeded()
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
        if let ttlMs = envelope.ttlMs {
            let meta = CacheMeta(expiresAtMs: envelope.timestampMs + ttlMs)
            if let metaData = try? JSONEncoder().encode(meta) {
                defaults.set(metaData, forKey: "\(key)_meta")
            }
        }
        evictIfNeeded()
    }

    func remove(_ key: String) {
        memory.removeValue(forKey: key)
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: "\(key)_meta")
    }

    func clearAll() {
        for key in allKeys() {
            memory.removeValue(forKey: key)
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: "\(key)_meta")
        }
    }

    func isValid(key: String) -> Bool {
        let metaKey = "\(key)_meta"
        if let meta = defaults.data(forKey: metaKey),
           let info = try? JSONDecoder().decode(CacheMeta.self, from: meta) {
            return Date.now.millisecondsSinceEpoch < info.expiresAtMs
        }
        return false
    }

    func ttl(for key: String) -> TimeInterval {
        if key.hasPrefix(Self.customRSSPrefix) {
            return Self.customRSSFreshTTL
        }
        return Self.defaultTTLs[key] ?? 6 * 3_600
    }

    var currentSize: Int {
        memory.values.reduce(0) { $0 + $1.count }
    }

    private func evictIfNeeded() {
        let size = currentSize
        guard size > Self.evictionThreshold else { return }

        // Sort by size (largest first) and remove until under threshold
        let sorted = memory.sorted { $0.value.count > $1.value.count }
        var remaining = size
        for (key, data) in sorted {
            guard remaining > Self.evictionThreshold else { break }
            memory.removeValue(forKey: key)
            defaults.removeObject(forKey: key)
            remaining -= data.count
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
        "cache_exa_search",
        "cache_exa_summary",
    ]
}

struct CacheMeta: Codable {
    let expiresAtMs: Int64
}
