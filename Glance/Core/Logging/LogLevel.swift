import Foundation

enum LogLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case error
    case warning
    case info

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var rank: Int {
        switch self {
        case .error: 0
        case .warning: 1
        case .info: 2
        }
    }

    var label: String {
        rawValue.uppercased()
    }
}