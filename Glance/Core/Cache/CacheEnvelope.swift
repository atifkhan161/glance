import Foundation

struct CacheEnvelope<T: Codable & Sendable>: Codable, Sendable {
    let timestampMs: Int64
    let ttlMs: Int64?
    let data: T

    var isExpired: Bool {
        ttlMs.map { Date.now.millisecondsSinceEpoch - timestampMs >= $0 } ?? false
    }

    init(data: T, ttlMs: Int64? = nil) {
        self.timestampMs = Date.now.millisecondsSinceEpoch
        self.ttlMs = ttlMs
        self.data = data
    }
}
