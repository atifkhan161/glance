import Foundation

enum TimeFormat {
    private static let ist = TimeZone(identifier: "Asia/Kolkata")!

    static func age(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    static func stars(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    static func countdownTo(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "" }
        if interval < 60 { return "starting now" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "in \(minutes)m" }
        let hours = minutes / 60
        let remM = minutes % 60
        if hours < 48 {
            return remM > 0 ? "in \(hours)h \(remM)m" : "in \(hours)h"
        }
        let days = hours / 24
        let remH = hours % 24
        return remH > 0 ? "in \(days)d \(remH)h" : "in \(days)d"
    }

    static func istDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ist
        formatter.dateFormat = "EEE, MMM d · h:mm a"
        return formatter.string(from: date) + " IST"
    }

    static func relativeDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ist
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date.now)
        let target = formatter.string(from: date)
        if today == target { return "Today" }
        let tomorrow = formatter.string(from: Date.now.addingTimeInterval(86400))
        if tomorrow == target { return "Tomorrow" }
        return target
    }

    static func endsIn(_ endDate: Date) -> String {
        let interval = endDate.timeIntervalSinceNow
        if interval < 0 { return "" }
        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if hours >= 24 { return hours / 24 == 1 ? "Ends tomorrow" : "Ends in \(hours / 24)d" }
        if hours > 0 { return "Ends in \(hours)h" }
        return "Ends in \(max(1, minutes))m"
    }

    static func relativeTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ist
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date.now)
        let target = formatter.string(from: date)
        if today == target { return "today" }
        let yesterday = formatter.string(from: Date.now.addingTimeInterval(-86400))
        if yesterday == target { return "yesterday" }
        let days = Int(-date.timeIntervalSinceNow / 86400)
        return "\(days)d ago"
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
