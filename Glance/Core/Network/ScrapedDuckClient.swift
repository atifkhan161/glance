import Foundation

protocol ScrapedDuckClientProtocol: Sendable {
    func fetchRaids() async throws -> [PoGoRaid]
    func fetchEvents() async throws -> [PoGoEvent]
}

struct ScrapedDuckClient: ScrapedDuckClientProtocol, Sendable {
    func fetchRaids() async throws -> [PoGoRaid] {
        let url = URL(string: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoRaid].self, from: data)
    }

    func fetchEvents() async throws -> [PoGoEvent] {
        let url = URL(string: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoEvent].self, from: data)
    }
}
