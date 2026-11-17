import Foundation

struct FDTeamRef: Codable, Sendable, Equatable {
    let id: Int
    let name: String?
    let crest: String?
}

struct FDCompetitionRef: Codable, Sendable, Equatable {
    let id: Int
    let name: String?
    let code: String?
}

struct FDScore: Codable, Sendable, Equatable {
    let winner: String?
    let fullTime: FDFullTime?
}

struct FDFullTime: Codable, Sendable, Equatable {
    let home: Int?
    let away: Int?
}

struct FDMatch: Codable, Sendable, Equatable {
    let id: Int
    let utcDate: String?
    let status: String?
    let matchday: Int?
    let competition: FDCompetitionRef?
    let homeTeam: FDTeamRef?
    let awayTeam: FDTeamRef?
    let score: FDScore?

    var isFinished: Bool { status == "FINISHED" }
    var isUpcoming: Bool { ["SCHEDULED", "TIMED", "IN_PLAY", "PAUSED"].contains(status ?? "") }

    var matchDate: Date? {
        guard let utcDate else { return nil }
        return try? Date(utcDate, strategy: .iso8601)
    }
}

struct FDMatchesResponse: Codable, Sendable {
    let matches: [FDMatch]?
}

struct FDTableRow: Codable, Sendable, Equatable {
    let position: Int?
    let team: FDTeamRef?
    let playedGames: Int?
    let won: Int?
    let draw: Int?
    let lost: Int?
    let goalsFor: Int?
    let goalsAgainst: Int?
    let goalDifference: Int?
    let points: Int?
}

struct FDStanding: Codable, Sendable, Equatable {
    let stage: String?
    let type: String?
    let table: [FDTableRow]?
}

struct FDStandingsResponse: Codable, Sendable {
    let standings: [FDStanding]?
}

protocol FootballDataOrgClientProtocol: Sendable {
    func teamMatches(teamID: String, apiKey: String) async throws -> [FDMatch]
    func standings(competitionCode: String, apiKey: String) async throws -> [FDTableRow]
}

struct FootballDataOrgClient: FootballDataOrgClientProtocol, Sendable {
    private static let transport = HTTPTransport(subsystem: "football-data")

    func teamMatches(teamID: String, apiKey: String) async throws -> [FDMatch] {
        let safeID = teamID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? teamID
        var components = URLComponents(string: "\(Self.baseURL)/teams/\(safeID)/matches")!
        components.queryItems = [URLQueryItem(name: "status", value: "FINISHED,SCHEDULED,TIMED,IN_PLAY")]
        let response: FDMatchesResponse = try await get(url: components.url!, apiKey: apiKey, label: "team-matches")
        return response.matches ?? []
    }

    func standings(competitionCode: String, apiKey: String) async throws -> [FDTableRow] {
        let safeCode = competitionCode.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? competitionCode
        var components = URLComponents(string: "\(Self.baseURL)/competitions/\(safeCode)/standings")!
        let response: FDStandingsResponse = try await get(url: components.url!, apiKey: apiKey, label: "standings")
        return Self.totalTable(from: response)
    }

    static func totalTable(from response: FDStandingsResponse) -> [FDTableRow] {
        let total = response.standings?.first { $0.stage == "REGULAR_SEASON" && $0.type == "TOTAL" }
            ?? response.standings?.first { $0.type == "TOTAL" }
            ?? response.standings?.first
        return total?.table ?? []
    }

    static let baseURL = "https://api.football-data.org/v4"

    private func get<T: Decodable>(url: URL, apiKey: String, label: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")

        for attempt in 0..<3 {
            do {
                let (data, _) = try await FootballDataOrgClient.transport.data(for: request, hint: label)
                return try JSONDecoder().decode(T.self, from: data)
            } catch GlanceError.rateLimited(let retryAfter) {
                guard attempt < 2, let delay = RateLimitBackoff.delay(retryAfter: retryAfter, attempt: attempt) else {
                    throw GlanceError.rateLimited(retryAfter: retryAfter)
                }
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch is DecodingError {
                throw GlanceError.decodingError("football-data decode failed (\(label))")
            }
        }

        throw GlanceError.networkError("football-data failed after retries (\(label))")
    }
}
