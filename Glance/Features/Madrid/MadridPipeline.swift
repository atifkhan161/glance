import Foundation

struct MadridPipeline: Sendable {
    private let sportsDB: any SportsDBClientProtocol
    private let exa: any ExaClientProtocol
    private let madridClient: any ManagingMadridClientProtocol
    private let cache: CacheStore
    private let keychain: KeychainStore

    init(
        sportsDB: any SportsDBClientProtocol = SportsDBClient(),
        exa: any ExaClientProtocol = ExaClient(),
        madridClient: any ManagingMadridClientProtocol = ManagingMadridClient(),
        cache: CacheStore = .shared,
        keychain: KeychainStore = .shared
    ) {
        self.sportsDB = sportsDB
        self.exa = exa
        self.madridClient = madridClient
        self.cache = cache
        self.keychain = keychain
    }

    static func normaliseOpponent(_ raw: String) -> String {
        let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return clubNormalise[key] ?? raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func looseDateParse(_ text: String) -> Date? {
        if let iso = Self.isoToken(in: text) { return iso }
        if let dated = Self.textDateTime(in: text) { return dated }
        if let dateOnly = Self.dateOnly(in: text) { return dateOnly }
        return nil
    }

    func refresh(settings: SettingsStore, force: Bool = false) async -> MadridRefreshResult {
        // Extract values on main actor before async work
        let rssURL = await settings.madridRSSURL
        let teamID = await settings.madridTeamID
        let leagueID = await settings.madridLeagueID

        // 1. API-Sports (thesportsdb.com) free tier — no API key required.
        do {
            // Sequential calls to be gentle on free-tier rate limits
            let lastEvents = try await sportsDB.lastEvents(teamID: teamID)

            try? await Task.sleep(for: .milliseconds(600))

            let nextEvents = try await sportsDB.nextEvents(teamID: teamID)

            try? await Task.sleep(for: .milliseconds(600))

            let table = try await sportsDB.leagueTable(
                leagueID: leagueID, season: SportsDB.currentSeason()
            )

            // 2. Derive data
            let lastMatch = Self.parseLastMatch(from: lastEvents)
            let form = Self.parseForm(from: lastEvents)
            let standing = Self.parseStanding(from: table, teamID: teamID)
            let nextFixture = Self.parseNextFixture(from: nextEvents.first)

            // 3. Fetch Exa for related articles (unchanged)
            let exaArticles = await fetchExaArticles()

            // 4. Fetch MM articles (unchanged)
            let mmArticles = (try? await madridClient.fetchArticles(rssURL: rssURL)) ?? []

            // 5. Combine
            let data = MadridData(
                fixture: nextFixture,
                lastMatch: lastMatch,
                schedule: [],
                form: form,
                standing: standing,
                standingText: Self.formatStandingText(standing),
                intel: Self.generateIntel(nextFixture: nextFixture, lastMatch: lastMatch),
                headToHead: nil,
                articles: exaArticles,
                mmArticles: mmArticles,
                source: "api-sports",
                timestamp: Date.now
            )

            await cache.save("cache_madrid", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
            return .ready(data: data)
        } catch {
            print("[MadridPipeline] API-Sports fetch failed: \(error)")
            return await refreshWithExaFallback(settings: settings)
        }
    }

    // MARK: - Exa Fallback (when no Football key)

    private func refreshWithExaFallback(settings: SettingsStore) async -> MadridRefreshResult {
        async let exaTask: [ExaResult]? = {
            guard let key = self.keychain.load(forKey: "keys_exa") else { return nil }
            return try? await self.exa.search(query: "Real Madrid next match fixture upcoming schedule", apiKey: key)
        }()
        async let mmTask: [MMArticle] = {
            (try? await self.madridClient.fetchArticles(rssURL: settings.madridRSSURL)) ?? []
        }()
        let exaResults = await exaTask
        let mmArticles = await mmTask

        guard let results = exaResults else {
            let cached: CacheEnvelope<MadridData>? = await cache.load("cache_madrid")
            if let cached { return .keyMissing(cachedData: cached.data, mmArticles: mmArticles) }
            return .keyMissing(cachedData: nil, mmArticles: mmArticles)
        }
        if results.isEmpty {
            return .degraded(
                data: MadridData(
                    fixture: nil, lastMatch: nil, schedule: [], form: [],
                    standing: nil, standingText: "",
                    intel: "No match data available", headToHead: nil,
                    articles: [], mmArticles: mmArticles, source: "none", timestamp: Date.now
                ),
                reason: "No results"
            )
        }

        let articles = results.map {
            ExaArticle(
                title: $0.title, url: $0.url, publishedDate: $0.publishedDate,
                highlights: $0.highlights, image: $0.image
            )
        }
        let parsed = Self.parseFixtureFromExa(from: results)
        let snippets = results.flatMap { $0.highlights }.joined(separator: "\n")
        let (enrichment, source) = await IntelligenceRouter().enrichMadrid(snippets: snippets)

        let formDots = parsed.formDots
        let formStrings = formDots.map { "\($0.result) \($0.score)" }

        let data = MadridData(
            fixture: parsed.fixture,
            lastMatch: nil,
            schedule: parsed.schedule,
            form: enrichment?.form ?? formStrings,
            standing: nil,
            standingText: enrichment?.standing ?? "",
            intel: enrichment?.intel ?? generateFallbackIntel(for: parsed.fixture),
            headToHead: enrichment?.headToHead,
            articles: articles,
            mmArticles: mmArticles,
            source: source,
            timestamp: Date.now
        )
        await cache.save("cache_madrid", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return parsed.fixture == nil ? .degraded(data: data, reason: "No fixture") : .ready(data: data)
    }

    // MARK: - Exa Articles

    private func fetchExaArticles() async -> [ExaArticle] {
        guard let key = keychain.load(forKey: "keys_exa") else { return [] }
        guard let results = try? await exa.search(query: "Real Madrid news transfers tactics", apiKey: key) else { return [] }
        return results.map {
            ExaArticle(
                title: $0.title, url: $0.url, publishedDate: $0.publishedDate,
                highlights: $0.highlights, image: $0.image
            )
        }
    }

    // MARK: - Parsing Helpers

    /// Split event badge URLs into (Real Madrid, opponent) based on which side RM is on.
    private static func badges(for match: SDBEvent) -> (rm: String?, opponent: String?) {
        let isHome = match.idHomeTeam == SportsDB.realMadridID
        return isHome
            ? (match.strHomeTeamBadge, match.strAwayTeamBadge)
            : (match.strAwayTeamBadge, match.strHomeTeamBadge)
    }

    static func parseLastMatch(from events: [SDBEvent]) -> LastMatch? {
        // eventslast returns the most recent events first
        guard let match = events.first(where: { $0.isFinished }) else { return nil }

        let isHome = match.idHomeTeam == SportsDB.realMadridID
        let opponent = isHome ? match.strAwayTeam : match.strHomeTeam
        let homeGoals = match.intHomeScore ?? 0
        let awayGoals = match.intAwayScore ?? 0
        let datetime = match.strTimestamp ?? match.dateEvent ?? ""
        let badges = Self.badges(for: match)

        return LastMatch(
            opponent: opponent,
            score: LastMatch.LastMatchScore(home: homeGoals, away: awayGoals),
            competition: match.strLeague,
            venue: match.strVenue ?? "",
            datetime: datetime,
            status: match.strStatus ?? "FT",
            scorers: [],
            cards: [],
            round: match.intRound.map { "Round \($0)" },
            rmBadge: badges.rm,
            opponentBadge: badges.opponent
        )
    }

    static func parseNextFixture(from event: SDBEvent?) -> Fixture? {
        guard let match = event else { return nil }

        let isHome = match.idHomeTeam == SportsDB.realMadridID
        let opponent = isHome ? match.strAwayTeam : match.strHomeTeam
        let venue = match.strVenue ?? ""

        let score: Fixture.Score?
        if let h = match.intHomeScore, let a = match.intAwayScore {
            score = Fixture.Score(home: h, away: a)
        } else {
            score = nil
        }

        let datetime = match.strTimestamp
            ?? (match.dateEvent.map { "\($0)T\(match.strTime ?? "00:00:00")" })
            ?? match.dateEvent
            ?? ""
        let badges = Self.badges(for: match)

        return Fixture(
            opponent: opponent,
            datetime: datetime,
            stadium: venue,
            competition: match.strLeague,
            venue: venue,
            scores: score,
            rmBadge: badges.rm,
            opponentBadge: badges.opponent
        )
    }

    static func parseForm(from events: [SDBEvent]) -> [String] {
        // Form from last 5 finished matches (most recent first)
        let finished = events.filter { $0.isFinished }.prefix(5)

        return finished.map { match in
            let isHome = match.idHomeTeam == SportsDB.realMadridID
            let homeGoals = match.intHomeScore ?? 0
            let awayGoals = match.intAwayScore ?? 0

            let rmGoals = isHome ? homeGoals : awayGoals
            let oppGoals = isHome ? awayGoals : homeGoals

            let result: String
            if rmGoals > oppGoals {
                result = "W"
            } else if rmGoals == oppGoals {
                result = "D"
            } else {
                result = "L"
            }

            return "\(result) \(rmGoals)-\(oppGoals)"
        }
    }

    static func parseStanding(from table: [SDBStanding], teamID: String) -> StandingInfo? {
        guard let row = table.first(where: { $0.idTeam == teamID }) else { return nil }

        return StandingInfo(
            rank: Int(row.intRank ?? "") ?? 0,
            points: Int(row.intPoints ?? "") ?? 0,
            played: Int(row.intPlayed ?? "") ?? 0,
            won: Int(row.intWin ?? "") ?? 0,
            drawn: Int(row.intDraw ?? "") ?? 0,
            lost: Int(row.intLoss ?? "") ?? 0,
            goalsFor: Int(row.intGoalsFor ?? "") ?? 0,
            goalsAgainst: Int(row.intGoalsAgainst ?? "") ?? 0,
            goalDifference: Int(row.intGoalDifference ?? "") ?? 0,
            badge: row.strBadge
        )
    }

    static func formatStandingText(_ standing: StandingInfo?) -> String {
        guard let s = standing else { return "" }
        return "\(ordinal(s.rank)) · \(s.points)pts · W\(s.won) D\(s.drawn) L\(s.lost) · GD \(s.goalDifference >= 0 ? "+" : "")\(s.goalDifference)"
    }

    static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1: suffix = "st"
        case 2: suffix = "nd"
        case 3: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    static func generateIntel(nextFixture: Fixture?, lastMatch: LastMatch?) -> String {
        var parts: [String] = []
        if let lm = lastMatch {
            let rmGoals = lm.score.home > lm.score.away ? lm.score.home : lm.score.away
            let oppGoals = lm.score.home > lm.score.away ? lm.score.away : lm.score.home
            if rmGoals > oppGoals {
                parts.append("Won last match \(rmGoals)-\(oppGoals) vs \(lm.opponent)")
            } else if rmGoals == oppGoals {
                parts.append("Drew last match \(rmGoals)-\(oppGoals) vs \(lm.opponent)")
            } else {
                parts.append("Lost last match \(rmGoals)-\(oppGoals) vs \(lm.opponent)")
            }
        }
        if let fixture = nextFixture {
            parts.append("Next: vs \(fixture.opponent) in \(fixture.competition)")
        }
        return parts.isEmpty ? "Real Madrid latest updates" : parts.joined(separator: " · ")
    }

    private func generateFallbackIntel(for fixture: Fixture?) -> String {
        guard let fixture else { return "Real Madrid latest updates" }
        return "Upcoming match: Real Madrid vs \(fixture.opponent) in \(fixture.competition)"
    }

    // MARK: - Exa Fixture Parsing (fallback)

    static func parseFixtureFromExa(from results: [ExaResult]) -> MadridPipeline.ParsedFixture {
        MadridPipeline.parseFixture(from: results)
    }
}

enum MadridRefreshResult: Sendable, Equatable {
    case ready(data: MadridData)
    case degraded(data: MadridData, reason: String)
    case keyMissing(cachedData: MadridData?, mmArticles: [MMArticle])
}
