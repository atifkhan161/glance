import Foundation

// MARK: - API-Sports (thesportsdb.com) — Free Tier

enum SportsDB {
    static let baseURL = "https://www.thesportsdb.com/api/v1/json/123"
    // Free-tier key "123" is embedded in the URL path; no auth header needed.
    static let realMadridID = "133738" // native thesportsdb ID (541 is the API-Football ID)
    static let laLigaID = "4335"

    /// La Liga season string, e.g. "2026-2027". Season rolls over in July.
    static func currentSeason(date: Date = Date.now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let startYear = month >= 7 ? year : year - 1
        return "\(startYear)-\(startYear + 1)"
    }

    /// Current La Liga round number. Season starts ~Aug 20, one round per week.
    static func currentRound(date: Date = Date.now) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let startYear = month >= 7 ? year : year - 1
        let seasonStart = calendar.date(from: DateComponents(year: startYear, month: 8, day: 20)) ?? date
        let days = calendar.dateComponents([.day], from: seasonStart, to: date).day ?? 0
        let round = (days / 7) + 1
        return max(1, min(round, 38))
    }
}

// MARK: - Models

struct SDBEvent: Codable, Sendable, Equatable {
    let idEvent: String
    let strEvent: String
    let strLeague: String
    let strSeason: String?
    let strTimestamp: String?
    let dateEvent: String?
    let strTime: String?
    let strHomeTeam: String
    let strAwayTeam: String
    let idHomeTeam: String?
    let idAwayTeam: String?
    let strVenue: String?
    let intRound: String?
    let strStatus: String?
    let intHomeScore: Int?
    let intAwayScore: Int?
    let strHomeTeamBadge: String?
    let strAwayTeamBadge: String?
    let strPostponed: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        idEvent = try c.decodeIfPresent(String.self, forKey: .idEvent) ?? ""
        strEvent = try c.decodeIfPresent(String.self, forKey: .strEvent) ?? ""
        strLeague = try c.decodeIfPresent(String.self, forKey: .strLeague) ?? ""
        strSeason = try c.decodeIfPresent(String.self, forKey: .strSeason)
        strTimestamp = try c.decodeIfPresent(String.self, forKey: .strTimestamp)
        dateEvent = try c.decodeIfPresent(String.self, forKey: .dateEvent)
        strTime = try c.decodeIfPresent(String.self, forKey: .strTime)
        strHomeTeam = try c.decodeIfPresent(String.self, forKey: .strHomeTeam) ?? ""
        strAwayTeam = try c.decodeIfPresent(String.self, forKey: .strAwayTeam) ?? ""
        idHomeTeam = try c.decodeIfPresent(String.self, forKey: .idHomeTeam)
        idAwayTeam = try c.decodeIfPresent(String.self, forKey: .idAwayTeam)
        strVenue = try c.decodeIfPresent(String.self, forKey: .strVenue)
        intRound = try c.decodeIfPresent(String.self, forKey: .intRound)
        strStatus = try c.decodeIfPresent(String.self, forKey: .strStatus)
        // API returns scores as numeric strings ("2") or null
        intHomeScore = try SDBEvent.flexibleInt(c, .intHomeScore)
        intAwayScore = try SDBEvent.flexibleInt(c, .intAwayScore)
        strHomeTeamBadge = try c.decodeIfPresent(String.self, forKey: .strHomeTeamBadge)
        strAwayTeamBadge = try c.decodeIfPresent(String.self, forKey: .strAwayTeamBadge)
        strPostponed = try c.decodeIfPresent(String.self, forKey: .strPostponed)
    }

    private enum CodingKeys: String, CodingKey {
        case idEvent, strEvent, strLeague, strSeason, strTimestamp, dateEvent, strTime
        case strHomeTeam, strAwayTeam, idHomeTeam, idAwayTeam, strVenue, intRound
        case strStatus, intHomeScore, intAwayScore, strHomeTeamBadge, strAwayTeamBadge, strPostponed
    }

    private static func flexibleInt(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) throws -> Int? {
        guard c.contains(key) else { return nil }
        if let s = try? c.decode(String.self, forKey: key) { return Int(s) }
        if let i = try? c.decode(Int.self, forKey: key) { return i }
        return nil
    }

    /// Memberwise initializer for testing
    init(
        idEvent: String, strEvent: String, strLeague: String,
        strSeason: String?, strTimestamp: String?,
        dateEvent: String?, strTime: String?,
        strHomeTeam: String, strAwayTeam: String,
        idHomeTeam: String?, idAwayTeam: String?,
        strVenue: String?, intRound: String?,
        strStatus: String?, intHomeScore: Int?, intAwayScore: Int?,
        strHomeTeamBadge: String?, strAwayTeamBadge: String?,
        strPostponed: String?
    ) {
        self.idEvent = idEvent
        self.strEvent = strEvent
        self.strLeague = strLeague
        self.strSeason = strSeason
        self.strTimestamp = strTimestamp
        self.dateEvent = dateEvent
        self.strTime = strTime
        self.strHomeTeam = strHomeTeam
        self.strAwayTeam = strAwayTeam
        self.idHomeTeam = idHomeTeam
        self.idAwayTeam = idAwayTeam
        self.strVenue = strVenue
        self.intRound = intRound
        self.strStatus = strStatus
        self.intHomeScore = intHomeScore
        self.intAwayScore = intAwayScore
        self.strHomeTeamBadge = strHomeTeamBadge
        self.strAwayTeamBadge = strAwayTeamBadge
        self.strPostponed = strPostponed
    }

    var isFinished: Bool {
        let status = strStatus ?? ""
        return status.contains("Finished") || status == "FT" || status == "AET" || status == "PEN"
    }

    var isNotStarted: Bool {
        let status = strStatus ?? ""
        return status.contains("Not Started") || status == "NS" || status == "TBD" || status.isEmpty
    }
}

struct SDBEventsResponse: Codable, Sendable {
    let events: [SDBEvent]?
    let results: [SDBEvent]?
}

struct SDBStanding: Codable, Sendable, Equatable {
    let idStanding: String?
    let intRank: String?
    let idTeam: String
    let strTeam: String
    let strBadge: String?
    let idLeague: String?
    let strLeague: String?
    let strSeason: String?
    let strForm: String?
    let intPlayed: String?
    let intWin: String?
    let intDraw: String?
    let intLoss: String?
    let intGoalsFor: String?
    let intGoalsAgainst: String?
    let intGoalDifference: String?
    let intPoints: String?
}

struct SDBTableResponse: Codable, Sendable {
    let table: [SDBStanding]?
}

struct SDBTeam: Codable, Sendable, Equatable {
    let idTeam: String
    let strTeam: String
    let strTeamBadge: String?
    let strStadium: String?
    let strLeague: String?
    let idLeague: String?
}

struct SDBTeamsResponse: Codable, Sendable {
    let teams: [SDBTeam]?
}

// MARK: - Client

protocol SportsDBClientProtocol: Sendable {
    func searchTeam(name: String) async throws -> SDBTeam?
    func lastEvents(teamID: String) async throws -> [SDBEvent]
    func nextEvents(teamID: String) async throws -> [SDBEvent]
    func leagueTable(leagueID: String, season: String) async throws -> [SDBStanding]
    func eventsRound(leagueID: String, round: String, season: String) async throws -> [SDBEvent]
}

struct SportsDBClient: SportsDBClientProtocol, Sendable {

    func searchTeam(name: String) async throws -> SDBTeam? {
        var components = URLComponents(string: "\(SportsDB.baseURL)/searchteams.php")!
        components.queryItems = [URLQueryItem(name: "t", value: name)]
        let response: SDBTeamsResponse = try await get(url: components.url!, label: "searchteams")
        return response.teams?.first
    }

    func lastEvents(teamID: String) async throws -> [SDBEvent] {
        var components = URLComponents(string: "\(SportsDB.baseURL)/eventslast.php")!
        components.queryItems = [URLQueryItem(name: "id", value: teamID)]
        let response: SDBEventsResponse = try await get(url: components.url!, label: "eventslast")
        return response.results ?? []
    }

    func nextEvents(teamID: String) async throws -> [SDBEvent] {
        var components = URLComponents(string: "\(SportsDB.baseURL)/eventsnext.php")!
        components.queryItems = [URLQueryItem(name: "id", value: teamID)]
        let response: SDBEventsResponse = try await get(url: components.url!, label: "eventsnext")
        return response.events ?? []
    }

    func leagueTable(leagueID: String, season: String) async throws -> [SDBStanding] {
        var components = URLComponents(string: "\(SportsDB.baseURL)/lookuptable.php")!
        components.queryItems = [
            URLQueryItem(name: "l", value: leagueID),
            URLQueryItem(name: "s", value: season)
        ]
        let response: SDBTableResponse = try await get(url: components.url!, label: "lookuptable")
        return response.table ?? []
    }

    func eventsRound(leagueID: String, round: String, season: String) async throws -> [SDBEvent] {
        var components = URLComponents(string: "\(SportsDB.baseURL)/eventsround.php")!
        components.queryItems = [
            URLQueryItem(name: "id", value: leagueID),
            URLQueryItem(name: "r", value: round),
            URLQueryItem(name: "s", value: season)
        ]
        let response: SDBEventsResponse = try await get(url: components.url!, label: "eventsround")
        return response.events ?? []
    }

    // MARK: - Private

    private func get<T: Decodable>(url: URL, label: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        for attempt in 0..<3 {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GlanceError.networkError("No HTTP response")
            }

            if http.statusCode == 200 {
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("[SportsDB] Decode failed (\(label)): \(error)")
                    throw GlanceError.networkError("API-Sports decode failed (\(label))")
                }
            }

            if http.statusCode == 429 {
                let delay = UInt64(attempt == 0 ? 1_000_000_000 : 2_000_000_000)
                print("[SportsDB] Rate limited (\(label)), retrying in \(delay / 1_000_000_000)s")
                try await Task.sleep(nanoseconds: delay)
                continue
            }

            print("[SportsDB] Error \(http.statusCode) (\(label))")
            throw GlanceError.networkError("API-Sports error \(http.statusCode) (\(label))")
        }

        throw GlanceError.networkError("API-Sports failed after retries (\(label))")
    }
}
