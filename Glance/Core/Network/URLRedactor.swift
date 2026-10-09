import Foundation

/// Log reports get pasted into public bug trackers, so request identity is reduced
/// to the host plus a caller-supplied hint. A full path can carry a LiveContainer
/// UUID; a query string can carry a token. Neither is ever emitted.
enum URLRedactor {
    static func hasUserinfo(_ url: URL) -> Bool {
        url.user != nil || url.password != nil
    }

    static func describe(_ url: URL, hint: String? = nil) -> String {
        guard let host = url.host, host.isEmpty == false else {
            return "unknown host"
        }
        // A URL carrying credentials is not made safe by a hint, and the hint
        // caller may itself be sensitive, so both the path and the hint are dropped.
        if hasUserinfo(url) {
            return "\(host) (path redacted)"
        }
        if let hint, hint.isEmpty == false {
            return "\(host) / \(hint)"
        }
        return host
    }
}