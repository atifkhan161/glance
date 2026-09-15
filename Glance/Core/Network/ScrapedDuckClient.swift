import Foundation

protocol ScrapedDuckClientProtocol: Sendable {
    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid]
    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent]
}

struct ScrapedDuckClient: ScrapedDuckClientProtocol, Sendable {
    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid] {
        guard let url = URL(string: raidsURL) else {
            throw GlanceError.networkError("Invalid raids URL: \(raidsURL)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoRaid].self, from: data)
    }

    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent] {
        guard let url = URL(string: eventsURL) else {
            throw GlanceError.networkError("Invalid events URL: \(eventsURL)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoEvent].self, from: data)
    }
}
