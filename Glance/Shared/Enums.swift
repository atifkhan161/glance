import Foundation

enum GlanceTab: String, CaseIterable, Hashable, Sendable {
    case pulse
    case madrid
    case pogo
    case github
    case sources
    case settings
}

enum GlanceError: Error, Sendable, Equatable {
    case keyMissing(String)
    case networkError(String)
    case rateLimited(retryAfter: Double?)
    case decodingError(String)
    case networkUnavailable
    case httpStatus(Int)
    case decodingFailed
    case unauthorized
    case cacheMiss(String)
    case notConfigured(String)
}
