import Foundation

protocol ScrapedDuckClientProtocol: Sendable {
    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid]
    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent]
    func fetchEventDescription(from url: String) async throws -> String
}

struct ScrapedDuckClient: ScrapedDuckClientProtocol, Sendable {
    private static let transport = HTTPTransport(subsystem: "duckduckgo")

    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid] {
        guard let url = URL(string: raidsURL) else {
            throw GlanceError.networkError("Invalid raids URL")
        }
        let (data, _) = try await Self.transport.data(for: URLRequest(url: url), hint: "raids")
        return try JSONDecoder().decode([PoGoRaid].self, from: data)
    }

    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent] {
        guard let url = URL(string: eventsURL) else {
            throw GlanceError.networkError("Invalid events URL")
        }
        let (data, _) = try await Self.transport.data(for: URLRequest(url: url), hint: "events")
        return try JSONDecoder().decode([PoGoEvent].self, from: data)
    }

    func fetchEventDescription(from url: String) async throws -> String {
        guard let url = URL(string: url) else { return "" }
        let (html, _) = try await Self.transport.data(for: URLRequest(url: url), hint: "event description")
        guard let htmlString = String(data: html, encoding: .utf8) else { return "" }

        let pattern = #"<div class="event-description">\s*<p>(.*?)</p>\s*</div>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)) else {
            return ""
        }

        let range = Range(match.range(at: 1), in: htmlString)!
        var text = String(htmlString[range])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }
}
