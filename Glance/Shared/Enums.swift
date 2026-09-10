import Foundation

enum GlanceTab: String, CaseIterable, Hashable, Sendable {
    case pulse
    case madrid
    case pogo
    case github
    case settings
}

enum GlanceError: Error, Sendable, Equatable {
    case networkUnavailable
    case httpStatus(Int)
    case decodingFailed
    case unauthorized
    case cacheMiss(String)
    case notConfigured(String)
}
