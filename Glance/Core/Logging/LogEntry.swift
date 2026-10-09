import Foundation

struct LogEntry: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let timestampMs: Int64
    let level: LogLevel
    let subsystem: String
    let message: String
    let detail: String?

    init(
        id: UUID = UUID(),
        timestampMs: Int64 = Date.now.millisecondsSinceEpoch,
        level: LogLevel = .error,
        subsystem: String,
        message: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestampMs = timestampMs
        self.level = level
        self.subsystem = subsystem
        self.message = message
        self.detail = detail
    }

    var displayTimestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
    }
}