import Foundation

extension MadridPipeline {
    static let monthMap: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
    ]

    static func isoToken(in text: String) -> Date? {
        let pattern = "\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        var token = String(text[range])
        if !token.hasSuffix("Z") { token += "Z" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: token) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        if token.count == 17 { // yyyy-MM-ddTHH:mmZ -> append seconds
            let withSeconds = String(token.dropLast()) + ":00Z"
            return formatter.date(from: withSeconds)
        }
        return nil
    }

    static func regexGroup(_ match: NSTextCheckingResult, _ i: Int, in text: String) -> String? {
        let r = match.range(at: i)
        guard r.location != NSNotFound, let range = Range(r, in: text) else { return nil }
        return String(text[range])
    }

    static func textDateTime(in text: String) -> Date? {
        let pattern = "([A-Za-z]{3,})\\s+(\\d{1,2})[,\\s]+(?:(\\d{4})[,\\s]+)?(\\d{1,2}):(\\d{2})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        guard let mon = regexGroup(match, 1, in: text)?.lowercased().prefix(3),
              let month = monthMap[String(mon)],
              let dayStr = regexGroup(match, 2, in: text), let day = Int(dayStr),
              let hStr = regexGroup(match, 4, in: text), let hour = Int(hStr),
              let minStr = regexGroup(match, 5, in: text), let minute = Int(minStr) else { return nil }
        let year = regexGroup(match, 3, in: text).flatMap(Int.init)
            ?? Calendar.current.component(.year, from: Date.now)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)
    }

    static func dateOnly(in text: String) -> Date? {
        let pattern = "([A-Za-z]{3,})\\s+(\\d{1,2})[,\\s]+(\\d{4})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        guard let mon = regexGroup(match, 1, in: text)?.lowercased().prefix(3),
              let month = monthMap[String(mon)],
              let dayStr = regexGroup(match, 2, in: text), let day = Int(dayStr),
              let yrStr = regexGroup(match, 3, in: text), let year = Int(yrStr) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)
    }
}