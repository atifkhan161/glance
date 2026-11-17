import Foundation

struct MadridPipeline: Sendable {
    private let footballData: any FootballDataOrgClientProtocol
    private let exa: any ExaClientProtocol
    private let madridClient: any ManagingMadridClientProtocol
    private let cache: CacheStore
    private let keychain: KeychainStore

    init(
        footballData: any FootballDataOrgClientProtocol = FootballDataOrgClient(),
        exa: any ExaClientProtocol = ExaClient(),
        madridClient: any ManagingMadridClientProtocol = ManagingMadridClient(),
        cache: CacheStore = .shared,
        keychain: KeychainStore = .shared
    ) {
        self.footballData = footballData
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
        let rssURL = await settings.madridRSSURL
        let teamID = await settings.madridTeamID
        let teamName = await settings.madridSelectedTeam.name

        guard let apiKey = keychain.load(forKey: ApiKey.footballData.rawValue), !apiKey.isEmpty else {
            return await refreshWithExaFallback(settings: settings, teamName: teamName)
        }

        do {
            let matches = try await footballData.teamMatches(teamID: teamID, apiKey: apiKey)
            let table = (try? await footballData.standings(
                competitionCode: await settings.madridLeagueID, apiKey: apiKey
            )) ?? []

            let teamMatches = matches.filter { $0.involves(teamID: teamID) }
            let matchTimeline = Self.parseMatchTimeline(
                matches: teamMatches,
                teamID: teamID,
                teamName: teamName
            )

            let lastMatch = matchTimeline.first(where: { $0.isFinished }).flatMap { Self.convertToLastMatch($0) }
            let nextFixture = matchTimeline.first(where: { !$0.isFinished }).flatMap { Self.convertToFixture($0) }
            let form = Self.parseForm(from: teamMatches, teamID: teamID)
            let standing = Self.parseStanding(from: table, teamID: teamID)

            let exaArticles = await fetchExaArticles(teamName: teamName)
            let mmArticles = (try? await madridClient.fetchArticles(rssURL: rssURL)) ?? []

            let data = MadridData(
                teamName: teamName,
                fixture: nextFixture,
                lastMatch: lastMatch,
                matchTimeline: matchTimeline,
                schedule: [],
                form: form,
                standing: standing,
                standingText: Self.formatStandingText(standing),
                intel: Self.generateIntel(nextFixture: nextFixture, lastMatch: lastMatch, teamName: teamName),
                headToHead: nil,
                articles: exaArticles,
                mmArticles: mmArticles,
                source: "football-data",
                timestamp: Date.now
            )

            await cache.save("cache_madrid", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
            return .ready(data: data)
        } catch is CancellationError {
            return await refreshWithExaFallback(settings: settings, teamName: teamName)
        } catch {
            await AppLog.shared.record(
                .error,
                subsystem: "madrid",
                message: "football-data fetch failed for \(teamName), falling back to Exa",
                error: error
            )
            return await refreshWithExaFallback(settings: settings, teamName: teamName)
        }
    }

    // MARK: - Exa Fallback (when no Football key)

    private func refreshWithExaFallback(settings: SettingsStore, teamName: String) async -> MadridRefreshResult {
        async let exaTask: [ExaResult]? = {
            guard let key = self.keychain.load(forKey: "keys_exa") else { return nil }
            return try? await self.exa.search(query: "\(teamName) next match fixture upcoming schedule", apiKey: key)
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
                    teamName: teamName,
                    fixture: nil, lastMatch: nil, matchTimeline: [], schedule: [], form: [],
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
        let formEntries = formDots.map { FormEntry(result: $0.result, score: $0.score, opponent: String($0.opponent.prefix(3)).uppercased()) }

        let enrichmentForm: [FormEntry] = enrichment?.form.map { str in
            let parts = str.split(separator: " ")
            let result = String(parts.first ?? "W")
            let score = parts.count > 1 ? String(parts[1]) : ""
            return FormEntry(result: result, score: score, opponent: "")
        } ?? []

        let data = MadridData(
            teamName: teamName,
            fixture: parsed.fixture,
            lastMatch: nil,
            matchTimeline: [],
            schedule: parsed.schedule,
            form: enrichmentForm.isEmpty ? formEntries : enrichmentForm,
            standing: nil,
            standingText: enrichment?.standing ?? "",
            intel: enrichment?.intel ?? generateFallbackIntel(for: parsed.fixture, teamName: teamName),
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

    private func fetchExaArticles(teamName: String) async -> [ExaArticle] {
        guard let key = keychain.load(forKey: "keys_exa") else { return [] }
        guard let results = try? await exa.search(query: "\(teamName) news transfers tactics", apiKey: key) else { return [] }
        return results.map {
            ExaArticle(
                title: $0.title, url: $0.url, publishedDate: $0.publishedDate,
                highlights: $0.highlights, image: $0.image
            )
        }
    }

    // MARK: - Parsing Helpers

    private static func badges(for match: FDMatch, teamID: String) -> (rm: String?, opponent: String?) {
        let isHome = match.isHome(teamID: teamID)
        return isHome
            ? (match.homeTeam?.crest, match.awayTeam?.crest)
            : (match.awayTeam?.crest, match.homeTeam?.crest)
    }

    static func parseLastMatch(from events: [FDMatch], teamID: String) -> LastMatch? {
        guard let match = events.first(where: { $0.isFinished }) else { return nil }

        let isHome = match.isHome(teamID: teamID)
        let opponent = isHome ? match.awayTeam?.name : match.homeTeam?.name
        let homeGoals = match.score?.fullTime?.home ?? 0
        let awayGoals = match.score?.fullTime?.away ?? 0
        let datetime = match.utcDate ?? ""
        let badges = Self.badges(for: match, teamID: teamID)

        return LastMatch(
            opponent: opponent ?? "",
            score: MatchScore(home: homeGoals, away: awayGoals, isHome: isHome),
            competition: match.competition?.name ?? "",
            venue: "",
            datetime: datetime,
            status: match.status ?? "FT",
            scorers: [],
            cards: [],
            round: match.matchday.map { "Round \($0)" },
            rmBadge: badges.rm,
            opponentBadge: badges.opponent,
            isHome: isHome
        )
    }

    static func parseMatchTimeline(
        matches: [FDMatch],
        teamID: String,
        teamName: String
    ) -> [MatchTimelineItem] {
        var items: [MatchTimelineItem] = []

        let upcoming = matches
            .filter { $0.isUpcoming }
            .sorted { ($0.matchDate ?? .distantFuture) < ($1.matchDate ?? .distantFuture) }
            .prefix(3)
        for event in upcoming {
            guard let item = timelineItem(from: event, teamID: teamID, teamName: teamName) else { continue }
            items.append(item)
        }

        let finished = matches
            .filter { $0.isFinished }
            .sorted { ($0.matchDate ?? .distantPast) > ($1.matchDate ?? .distantPast) }
            .prefix(4)
        for event in finished {
            guard let item = timelineItem(from: event, teamID: teamID, teamName: teamName) else { continue }
            items.append(item)
        }

        return items
    }

    private static func timelineItem(from event: FDMatch, teamID: String, teamName: String) -> MatchTimelineItem? {
        let isHome = event.isHome(teamID: teamID)
        let opponent = isHome ? event.awayTeam?.name : event.homeTeam?.name
        let badges = Self.badges(for: event, teamID: teamID)

        let homeScore = event.score?.fullTime?.home
        let awayScore = event.score?.fullTime?.away
        let isFinished = event.isFinished

        var result: String? = nil
        if isFinished, let h = homeScore, let a = awayScore {
            let teamGoals = isHome ? h : a
            let oppGoals = isHome ? a : h
            if teamGoals > oppGoals { result = "W" }
            else if teamGoals == oppGoals { result = "D" }
            else { result = "L" }
        } else if isFinished, let winner = event.score?.winner {
            switch winner {
            case "HOME_TEAM": result = isHome ? "W" : "L"
            case "AWAY_TEAM": result = isHome ? "L" : "W"
            case "DRAW": result = "D"
            default: result = nil
            }
        }

        return MatchTimelineItem(
            id: String(event.id),
            teamName: teamName,
            opponent: opponent ?? "",
            opponentBadge: badges.opponent,
            rmBadge: badges.rm,
            homeScore: homeScore,
            awayScore: awayScore,
            datetime: event.utcDate ?? "",
            competition: event.competition?.name ?? "",
            venue: "",
            isFinished: isFinished,
            result: result,
            round: event.matchday.map { "R\($0)" },
            isHome: isHome
        )
    }

    /// Convert MatchTimelineItem to LastMatch for backward compatibility with glance card
    static func convertToLastMatch(_ item: MatchTimelineItem) -> LastMatch? {
        guard item.isFinished, let h = item.homeScore, let a = item.awayScore else { return nil }
        return LastMatch(
            opponent: item.opponent,
            score: MatchScore(
                team: item.teamScore ?? 0,
                opponent: item.opponentScore ?? 0
            ),
            competition: item.competition,
            venue: item.venue,
            datetime: item.datetime,
            status: "FT",
            scorers: [],
            cards: [],
            round: item.round,
            rmBadge: item.rmBadge,
            opponentBadge: item.opponentBadge,
            isHome: item.isHome
        )
    }

    /// Convert MatchTimelineItem to Fixture for backward compatibility with glance card
    static func convertToFixture(_ item: MatchTimelineItem) -> Fixture? {
        let score: MatchScore?
        if let team = item.teamScore, let opponent = item.opponentScore {
            score = MatchScore(team: team, opponent: opponent)
        } else {
            score = nil
        }
        return Fixture(
            opponent: item.opponent,
            datetime: item.datetime,
            stadium: item.venue,
            competition: item.competition,
            venue: item.venue,
            scores: score,
            rmBadge: item.rmBadge,
            opponentBadge: item.opponentBadge,
            isHome: item.isHome
        )
    }

    static func parseForm(from events: [FDMatch], teamID: String) -> [FormEntry] {
        let finished = events.filter { $0.isFinished }
            .sorted { ($0.matchDate ?? .distantPast) > ($1.matchDate ?? .distantPast) }
            .prefix(5)

        return finished.compactMap { match in
            let isHome = match.isHome(teamID: teamID)
            guard let homeGoals = match.score?.fullTime?.home,
                  let awayGoals = match.score?.fullTime?.away else {
                guard let winner = match.score?.winner, let opponent = isHome ? match.awayTeam?.name : match.homeTeam?.name else {
                    return nil
                }
                let result: String
                switch winner {
                case "HOME_TEAM": result = isHome ? "W" : "L"
                case "AWAY_TEAM": result = isHome ? "L" : "W"
                default: result = "D"
                }
                return FormEntry(result: result, score: "", opponent: String(opponent.prefix(3)).uppercased())
            }

            let teamGoals = isHome ? homeGoals : awayGoals
            let oppGoals = isHome ? awayGoals : homeGoals

            let result: String
            if teamGoals > oppGoals {
                result = "W"
            } else if teamGoals == oppGoals {
                result = "D"
            } else {
                result = "L"
            }

            let opponent = isHome ? match.awayTeam?.name : match.homeTeam?.name
            let opponentAbbrev = String(opponent?.prefix(3) ?? "").uppercased()

            return FormEntry(
                result: result,
                score: "\(teamGoals)-\(oppGoals)",
                opponent: opponentAbbrev
            )
        }
    }

    static func parseStanding(from table: [FDTableRow], teamID: String) -> StandingInfo? {
        guard let row = table.first(where: { $0.team.map { String($0.id) } == teamID }) else { return nil }

        return StandingInfo(
            rank: row.position ?? 0,
            points: row.points ?? 0,
            played: row.playedGames ?? 0,
            won: row.won ?? 0,
            drawn: row.draw ?? 0,
            lost: row.lost ?? 0,
            goalsFor: row.goalsFor ?? 0,
            goalsAgainst: row.goalsAgainst ?? 0,
            goalDifference: row.goalDifference ?? 0,
            badge: row.team?.crest
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

    static func generateIntel(nextFixture: Fixture?, lastMatch: LastMatch?, teamName: String) -> String {
        var parts: [String] = []
        if let lm = lastMatch {
            let teamGoals = lm.score.team
            let oppGoals = lm.score.opponent
            if teamGoals > oppGoals {
                parts.append("Won last match \(teamGoals)-\(oppGoals) vs \(lm.opponent)")
            } else if teamGoals == oppGoals {
                parts.append("Drew last match \(teamGoals)-\(oppGoals) vs \(lm.opponent)")
            } else {
                parts.append("Lost last match \(teamGoals)-\(oppGoals) vs \(lm.opponent)")
            }
        }
        if let fixture = nextFixture {
            parts.append("Next: vs \(fixture.opponent) in \(fixture.competition)")
        }
        return parts.isEmpty ? "\(teamName) latest updates" : parts.joined(separator: " · ")
    }

    private func generateFallbackIntel(for fixture: Fixture?, teamName: String) -> String {
        guard let fixture else { return "\(teamName) latest updates" }
        return "Upcoming match: \(teamName) vs \(fixture.opponent) in \(fixture.competition)"
    }

    // MARK: - Exa Fixture Parsing (fallback)

    static func parseFixtureFromExa(from results: [ExaResult]) -> MadridPipeline.ParsedFixture {
        MadridPipeline.parseFixture(from: results)
    }
}

extension FDMatch {
    func isHome(teamID: String) -> Bool {
        homeTeam.map { String($0.id) } == teamID
    }

    func involves(teamID: String) -> Bool {
        isHome(teamID: teamID) || awayTeam.map { String($0.id) } == teamID
    }
}

enum MadridRefreshResult: Sendable, Equatable {
    case ready(data: MadridData)
    case degraded(data: MadridData, reason: String)
    case keyMissing(cachedData: MadridData?, mmArticles: [MMArticle])
}
