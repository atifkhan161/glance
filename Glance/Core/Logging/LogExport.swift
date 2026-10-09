import Foundation
import UIKit

enum LogExport {
    static var currentDevice: String {
        "iOS \(UIDevice.current.systemVersion) · \(UIDevice.current.model)"
    }

    /// One log entry must never break the report's line structure, so any newline
    /// in a message or detail collapses to a single space.
    static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
    }

    static func markdown(
        entries: [LogEntry],
        appVersion: AppVersion,
        device: String,
        maxEntries: Int = 200
    ) -> String {
        var lines: [String] = []

        lines.append("# Glance error report")
        lines.append("\(appVersion.display) · \(device)")

        let shown = Array(entries.prefix(maxEntries))
        let errorCount = shown.filter { $0.level == .error }.count

        if let newest = shown.first, let oldest = shown.last {
            lines.append(
                "Window: \(stamp(oldest.displayTimestamp)) → \(stamp(newest.displayTimestamp))"
            )
        } else {
            lines.append("Window: —")
        }

        var countLine = "\(shown.count) entries, \(errorCount) errors"
        if entries.count > maxEntries {
            countLine += " (showing newest \(shown.count) of \(entries.count))"
        }
        lines.append(countLine)

        lines.append("")
        lines.append("## Summary")
        for line in summaryLines(shown) {
            lines.append(line)
        }

        lines.append("")
        lines.append("## Timeline (newest first)")
        for entry in shown {
            let head = "[\(clock(entry.displayTimestamp))] "
                + pad(entry.level.label, 7)
                + " "
                + pad(entry.subsystem, 12)
                + " "
                + sanitize(entry.message)
            lines.append(head)
            if let detail = entry.detail, !detail.isEmpty {
                lines.append("    detail: \(sanitize(detail))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func summaryLines(_ entries: [LogEntry]) -> [String] {
        var order: [String] = []
        var grouped: [String: [LogEntry]] = [:]
        for entry in entries {
            if grouped[entry.subsystem] == nil {
                grouped[entry.subsystem] = []
                order.append(entry.subsystem)
            }
            grouped[entry.subsystem]?.append(entry)
        }

        return order
            .sorted { lhs, rhs in
                let l = grouped[lhs]?.count ?? 0
                let r = grouped[rhs]?.count ?? 0
                if l == r { return lhs < rhs }
                return l > r
            }
            .map { subsystem in
                let group = grouped[subsystem] ?? []
                let newest = group.first?.message ?? ""
                let errors = group.filter { $0.level == .error }.count
                let notes = group.count - errors
                var text = "- \(subsystem): \(errors) error\(errors == 1 ? "" : "s")"
                if notes > 0 {
                    text += ", \(notes) \(notes == 1 ? "note" : "notes")"
                }
                return "\(text) (last: \(sanitize(newest)))"
            }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    /// Built per call rather than cached in a `static let`: `DateFormatter` is not
    /// `Sendable`, and this project compiles under strict concurrency. An export is
    /// a one-off paste, so two formatter allocations are irrelevant.
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static func stamp(_ date: Date) -> String {
        formatter("yyyy-MM-dd HH:mm:ss").string(from: date)
    }

    private static func clock(_ date: Date) -> String {
        formatter("HH:mm:ss").string(from: date)
    }
}