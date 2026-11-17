import Testing
@testable import Glance
import Foundation

@Suite("MadridPipeline")
struct MadridPipelineTests {
    @Test("Normalise opponent names")
    func normaliseOpponent() {
        #expect(MadridPipeline.normaliseOpponent("inter milan") == "Inter Milan")
        #expect(MadridPipeline.normaliseOpponent("rayo") == "Rayo Vallecano")
        #expect(MadridPipeline.normaliseOpponent("atletico madrid") == "Atlético Madrid")
    }

    @Test("Loose date parse ISO format")
    func parseISODate() {
        let result = MadridPipeline.looseDateParse("2026-09-08T19:00Z")
        #expect(result != nil)
    }

    @Test("Loose date parse text format")
    func parseTextDate() {
        let result = MadridPipeline.looseDateParse("Sep 8, 7:00 PM UTC")
        #expect(result != nil)
    }

    @Test("Loose date parse returns nil for garbage")
    func parseGarbage() {
        let result = MadridPipeline.looseDateParse("not a date at all")
        #expect(result == nil)
    }

    private static func fdMatch(
        id: Int,
        utcDate: String,
        status: String,
        matchday: Int? = nil,
        competition: String = "La Liga",
        competitionCode: String = "PD",
        home: FDTeamRef,
        away: FDTeamRef,
        winner: String? = nil,
        fullTime: FDFullTime? = nil
    ) -> FDMatch {
        FDMatch(
            id: id,
            utcDate: utcDate,
            status: status,
            matchday: matchday,
            competition: FDCompetitionRef(id: 2014, name: competition, code: competitionCode),
            homeTeam: home,
            awayTeam: away,
            score: FDScore(winner: winner, fullTime: fullTime)
        )
    }

    private static let madrid = FDTeamRef(id: 86, name: "Real Madrid CF", crest: "https://crests.football-data.org/86.png")
    private static let atletico = FDTeamRef(id: 78, name: "Club Atlético de Madrid", crest: "https://crests.football-data.org/78.png")
    private static let elche = FDTeamRef(id: 89, name: "Elche CF", crest: "https://crests.football-data.org/89.png")
    private static let rayo = FDTeamRef(id: 87, name: "Rayo Vallecano de Madrid", crest: "https://crests.football-data.org/87.png")
    private static let barcelona = FDTeamRef(id: 81, name: "FC Barcelona", crest: "https://crests.football-data.org/81.png")

    @Test("parseMatchTimeline returns upcoming first then recent finished")
    func parseMatchTimeline_basic() {
        let teamID = "86"
        let teamName = "Real Madrid"

        let finished1 = Self.fdMatch(
            id: 1, utcDate: "2026-09-15T19:30:00Z", status: "FINISHED", matchday: 6,
            home: Self.elche, away: Self.madrid,
            fullTime: FDFullTime(home: 2, away: 3)
        )

        let finished2 = Self.fdMatch(
            id: 2, utcDate: "2026-09-12T19:00:00Z", status: "FINISHED", matchday: 5,
            home: Self.madrid, away: Self.rayo,
            fullTime: FDFullTime(home: 4, away: 1)
        )

        let upcoming1 = Self.fdMatch(
            id: 3, utcDate: "2026-09-20T14:15:00Z", status: "TIMED", matchday: 7,
            home: Self.atletico, away: Self.madrid
        )

        let timeline = MadridPipeline.parseMatchTimeline(
            matches: [finished1, finished2, upcoming1],
            teamID: teamID,
            teamName: teamName
        )

        #expect(timeline.count == 3)
        #expect(timeline[0].opponent == "Club Atlético de Madrid")
        #expect(timeline[0].isFinished == false)
        #expect(timeline[0].result == nil)
        #expect(timeline[0].homeScore == nil)
        #expect(timeline[0].isHome == false)

        #expect(timeline[1].opponent == "Elche CF")
        #expect(timeline[1].isFinished == true)
        #expect(timeline[1].result == "W")
        #expect(timeline[1].homeScore == 2)
        #expect(timeline[1].awayScore == 3)
        #expect(timeline[1].isHome == false)
        #expect(timeline[1].teamScore == 3)
        #expect(timeline[1].opponentScore == 2)
        #expect(timeline[1].scoreText == "3 - 2")

        #expect(timeline[2].opponent == "Rayo Vallecano de Madrid")
        #expect(timeline[2].isFinished == true)
        #expect(timeline[2].result == "W")
        #expect(timeline[2].isHome == true)
        #expect(timeline[2].teamScore == 4)
        #expect(timeline[2].opponentScore == 1)
        #expect(timeline[2].scoreText == "4 - 1")
    }

    @Test("Away loss reads 1 - 2 for Madrid, not 2 - 1")
    func awayLossScoreOrientation() {
        let awayLoss = Self.fdMatch(
            id: 9, utcDate: "2026-09-05T19:30:00Z", status: "FINISHED", matchday: 4,
            home: Self.barcelona, away: Self.madrid,
            fullTime: FDFullTime(home: 2, away: 1)
        )

        let timeline = MadridPipeline.parseMatchTimeline(
            matches: [awayLoss], teamID: "86", teamName: "Real Madrid"
        )

        let item = try! #require(timeline.first)
        #expect(item.isHome == false)
        #expect(item.result == "L")
        #expect(item.homeScore == 2)
        #expect(item.awayScore == 1)
        #expect(item.teamScore == 1)
        #expect(item.opponentScore == 2)
        #expect(item.scoreText == "1 - 2")
    }

    @Test("Result falls back to the winner field when fullTime goals are null")
    func winnerFieldFallback() {
        let draw = Self.fdMatch(
            id: 10, utcDate: "2026-09-05T19:30:00Z", status: "FINISHED",
            home: Self.madrid, away: Self.barcelona,
            winner: "DRAW", fullTime: FDFullTime(home: nil, away: nil)
        )
        let homeWin = Self.fdMatch(
            id: 11, utcDate: "2026-09-06T19:30:00Z", status: "FINISHED",
            home: Self.madrid, away: Self.rayo,
            winner: "HOME_TEAM", fullTime: FDFullTime(home: nil, away: nil)
        )
        let awayLoss = Self.fdMatch(
            id: 12, utcDate: "2026-09-07T19:30:00Z", status: "FINISHED",
            home: Self.atletico, away: Self.madrid,
            winner: "HOME_TEAM", fullTime: FDFullTime(home: nil, away: nil)
        )

        let timeline = MadridPipeline.parseMatchTimeline(
            matches: [draw, homeWin, awayLoss], teamID: "86", teamName: "Real Madrid"
        )

        #expect(timeline.count == 3)
        #expect(timeline[0].result == "D")
        #expect(timeline[1].result == "W")
        #expect(timeline[2].result == "L")
        #expect(timeline[0].homeScore == nil)
    }

    @Test("convertToLastMatch and convertToFixture carry team-relative scores")
    func conversionsAreTeamRelative() {
        let awayLoss = Self.fdMatch(
            id: 9, utcDate: "2026-09-05T19:30:00Z", status: "FINISHED", matchday: 4,
            home: Self.barcelona, away: Self.madrid,
            fullTime: FDFullTime(home: 2, away: 1)
        )

        let timeline = MadridPipeline.parseMatchTimeline(
            matches: [awayLoss], teamID: "86", teamName: "Real Madrid"
        )
        let item = try! #require(timeline.first)

        let lastMatch = try! #require(MadridPipeline.convertToLastMatch(item))
        #expect(lastMatch.isHome == false)
        #expect(lastMatch.score.team == 1)
        #expect(lastMatch.score.opponent == 2)
        #expect(lastMatch.score.text == "1 - 2")

        let fixture = try! #require(MadridPipeline.convertToFixture(item))
        #expect(fixture.isHome == false)
        #expect(fixture.scores?.team == 1)
        #expect(fixture.scores?.opponent == 2)
    }

    @Test("generateIntel reports an away loss as a loss")
    func generateIntelAwayLoss() {
        let awayLoss = Self.fdMatch(
            id: 9, utcDate: "2026-09-05T19:30:00Z", status: "FINISHED", matchday: 4,
            home: Self.barcelona, away: Self.madrid,
            fullTime: FDFullTime(home: 2, away: 1)
        )

        let lastMatch = try! #require(MadridPipeline.parseLastMatch(from: [awayLoss], teamID: "86"))
        let intel = MadridPipeline.generateIntel(nextFixture: nil, lastMatch: lastMatch, teamName: "Real Madrid")

        #expect(intel == "Lost last match 1-2 vs FC Barcelona")
    }

    @Test("MatchScore maps home/away to team/opponent")
    func matchScoreMapping() {
        let homeWin = MatchScore(home: 3, away: 1, isHome: true)
        #expect(homeWin.team == 3)
        #expect(homeWin.opponent == 1)
        #expect(homeWin.text == "3 - 1")

        let awayLoss = MatchScore(home: 2, away: 1, isHome: false)
        #expect(awayLoss.team == 1)
        #expect(awayLoss.opponent == 2)
        #expect(awayLoss.text == "1 - 2")
    }

    // MARK: - Form

    private static func realFormMatches() -> [FDMatch] {
        [
            Self.fdMatch(
                id: 22, utcDate: "2026-08-22T19:00:00Z", status: "FINISHED", matchday: 2,
                home: FDTeamRef(id: 80, name: "RCD Espanyol de Barcelona", crest: nil), away: Self.madrid,
                fullTime: FDFullTime(home: 1, away: 2)
            ),
            Self.fdMatch(
                id: 24, utcDate: "2026-09-04T19:00:00Z", status: "FINISHED", matchday: 4,
                home: FDTeamRef(id: 90, name: "Real Betis Balompié", crest: nil), away: Self.madrid,
                fullTime: FDFullTime(home: 1, away: 0)
            ),
            Self.fdMatch(
                id: 25, utcDate: "2026-09-12T19:00:00Z", status: "FINISHED", matchday: 5,
                home: Self.madrid, away: Self.rayo,
                fullTime: FDFullTime(home: 4, away: 1)
            ),
            Self.fdMatch(
                id: 26, utcDate: "2026-09-15T19:30:00Z", status: "FINISHED", matchday: 6,
                home: Self.elche, away: Self.madrid,
                fullTime: FDFullTime(home: 2, away: 3)
            ),
        ]
    }

    @Test("parseForm returns newest first, not oldest first")
    func parseForm_newestFirst() {
        let form = MadridPipeline.parseForm(
            from: Self.realFormMatches(), teamID: "86"
        )

        #expect(form.count == 4)
        #expect(form[0].result == "W")
        #expect(form[0].score == "3-2")
        #expect(form[0].opponent == "ELC")
        #expect(form[1].result == "W")
        #expect(form[1].score == "4-1")
        #expect(form[1].opponent == "RAY")
        #expect(form[2].result == "L")
        #expect(form[2].score == "0-1")
        #expect(form[2].opponent == "REA")
        #expect(form[3].result == "W")
        #expect(form[3].score == "2-1")
        #expect(form[3].opponent == "RCD")
    }

    @Test("parseForm keeps the latest 5 and drops older matches")
    func parseForm_keepsLatestFive() {
        let extra = (17...20).map { day in
            Self.fdMatch(
                id: 100 + day, utcDate: "2026-09-\(day)T19:00:00Z", status: "FINISHED", matchday: 7,
                home: Self.madrid, away: Self.rayo,
                fullTime: FDFullTime(home: 1, away: 0)
            )
        }

        let form = MadridPipeline.parseForm(
            from: Self.realFormMatches() + extra, teamID: "86"
        )

        #expect(form.count == 5)
        #expect(form[0].opponent == "RAY")
        #expect(form[0].result == "W")
        #expect(!form.contains { $0.opponent == "RCD" })
    }

    @Test("parseForm ignores unfinished matches")
    func parseForm_ignoresUnfinished() {
        let upcoming = Self.fdMatch(
            id: 27, utcDate: "2026-09-28T19:00:00Z", status: "TIMED", matchday: 7,
            home: Self.madrid, away: FDTeamRef(id: 82, name: "Getafe CF", crest: nil)
        )

        let form = MadridPipeline.parseForm(
            from: Self.realFormMatches() + [upcoming], teamID: "86"
        )

        #expect(form.count == 4)
        #expect(!form.contains { $0.opponent == "GET" })
    }

    @Test("parseForm handles empty events")
    func parseForm_empty() {
        #expect(MadridPipeline.parseForm(from: [], teamID: "86").isEmpty)
    }

    @Test("parseForm matches the timeline ordering")
    func parseForm_agreesWithTimeline() {
        let events = Self.realFormMatches()
        let form = MadridPipeline.parseForm(from: events, teamID: "86")
        let timeline = MadridPipeline.parseMatchTimeline(
            matches: events, teamID: "86", teamName: "Real Madrid"
        )
        let finishedInTimeline = timeline.filter { $0.isFinished }

        #expect(form.count == finishedInTimeline.count)
        for (formEntry, item) in zip(form, finishedInTimeline) {
            #expect(formEntry.result == item.result)
            #expect(item.teamScore != nil)
            #expect(item.opponentScore != nil)
            #expect(formEntry.score == "\(item.teamScore ?? -1)-\(item.opponentScore ?? -1)")
        }
    }

    @Test("parseMatchTimeline handles empty events")
    func parseMatchTimeline_empty() {
        let timeline = MadridPipeline.parseMatchTimeline(
            matches: [],
            teamID: "86",
            teamName: "Real Madrid"
        )
        #expect(timeline.isEmpty)
    }

    @Test("parseMatchTimeline limits to 4 finished and 3 upcoming")
    func parseMatchTimeline_limits() {
        let teamID = "86"
        let teamName = "Real Madrid"
        let finishedEvents = (1...6).map { i in
            let isHome = i % 2 == 0
            return Self.fdMatch(
                id: i, utcDate: "2026-09-\(10 + i)T19:00:00Z", status: "FINISHED", matchday: i,
                home: isHome ? Self.madrid : FDTeamRef(id: 9000 + i, name: "Opponent \(i)", crest: nil),
                away: isHome ? FDTeamRef(id: 9000 + i, name: "Opponent \(i)", crest: nil) : Self.madrid,
                fullTime: FDFullTime(home: 2, away: 1)
            )
        }
        let upcomingEvents = (1...5).map { i in
            let isHome = i % 2 == 0
            return Self.fdMatch(
                id: 100 + i, utcDate: "2026-10-\(10 + i)T19:00:00Z", status: "SCHEDULED", matchday: i,
                home: isHome ? Self.madrid : FDTeamRef(id: 9000 + i, name: "Opponent \(i)", crest: nil),
                away: isHome ? FDTeamRef(id: 9000 + i, name: "Opponent \(i)", crest: nil) : Self.madrid
            )
        }

        let timeline = MadridPipeline.parseMatchTimeline(
            matches: finishedEvents + upcomingEvents,
            teamID: teamID,
            teamName: teamName
        )

        #expect(timeline.filter { $0.isFinished }.count == 4)
        #expect(timeline.filter { !$0.isFinished }.count == 3)
    }

    // MARK: - v4 payload decoding

    @Test("Decodes a real football-data.org team-matches payload")
    func decodesTeamMatchesPayload() throws {
        let json = """
        {
          "matches": [
            {
              "id": 523311,
              "utcDate": "2026-11-21T20:00:00Z",
              "status": "TIMED",
              "matchday": 13,
              "competition": {"id": 2014, "name": "Primera Division", "code": "PD"},
              "homeTeam": {"id": 86, "name": "Real Madrid CF", "crest": "https://crests.football-data.org/86.png"},
              "awayTeam": {"id": 558, "name": "RC Celta de Vigo", "crest": "https://crests.football-data.org/558.png"},
              "score": {"winner": null, "fullTime": {"home": null, "away": null}}
            },
            {
              "id": 523300,
              "utcDate": "2026-11-08T20:00:00Z",
              "status": "FINISHED",
              "matchday": 12,
              "competition": {"id": 2014, "name": "Primera Division", "code": "PD"},
              "homeTeam": {"id": 86, "name": "Real Madrid CF", "crest": null},
              "awayTeam": {"id": 78, "name": "Club Atlético de Madrid", "crest": null},
              "score": {"winner": "HOME_TEAM", "fullTime": {"home": 1, "away": 0}}
            }
          ]
        }
        """
        let response = try JSONDecoder().decode(FDMatchesResponse.self, from: Data(json.utf8))
        let matches = try #require(response.matches)
        #expect(matches.count == 2)
        #expect(matches[0].isUpcoming == true)
        #expect(matches[0].isFinished == false)
        #expect(matches[0].matchDate != nil)
        #expect(matches[1].isFinished == true)
        #expect(matches[1].score?.winner == "HOME_TEAM")
        #expect(matches[1].score?.fullTime?.home == 1)
    }

    @Test("Decodes standings and picks the TOTAL regular-season table")
    func decodesStandingsPayload() throws {
        let json = """
        {
          "standings": [
            {
              "stage": "REGULAR_SEASON",
              "type": "TOTAL",
              "table": [
                {"position": 2, "team": {"id": 86, "name": "Real Madrid CF", "crest": "https://crests.football-data.org/86.png"},
                 "playedGames": 12, "won": 10, "draw": 1, "lost": 1,
                 "goalsFor": 28, "goalsAgainst": 12, "goalDifference": 16, "points": 31},
                {"position": 1, "team": {"id": 81, "name": "FC Barcelona", "crest": null},
                 "playedGames": 12, "won": 11, "draw": 0, "lost": 1,
                 "goalsFor": 33, "goalsAgainst": 10, "goalDifference": 23, "points": 33}
              ]
            },
            {"stage": "REGULAR_SEASON", "type": "HOME", "table": []}
          ]
        }
        """
        let response = try JSONDecoder().decode(FDStandingsResponse.self, from: Data(json.utf8))
        let table = FootballDataOrgClient.totalTable(from: response)
        let standing = MadridPipeline.parseStanding(from: table, teamID: "86")

        #expect(standing != nil)
        #expect(standing?.rank == 2)
        #expect(standing?.points == 31)
        #expect(standing?.played == 12)
        #expect(standing?.won == 10)
        #expect(standing?.drawn == 1)
        #expect(standing?.lost == 1)
        #expect(standing?.goalDifference == 16)
    }
}

@Suite("FootballData ID migration")
struct FootballDataMigrationTests {
    @Test("Legacy thesportsdb team IDs map to football-data.org IDs")
    func legacyTeamIDs() {
        #expect(FootballData.modernTeamID(for: "133738") == "86")
        #expect(FootballData.modernTeamID(for: "133739") == "81")
        #expect(FootballData.modernTeamID(for: "133729") == "78")
        #expect(FootballData.modernTeamID(for: "133613") == "65")
    }

    @Test("Legacy league IDs map to competition codes")
    func legacyLeagueIDs() {
        #expect(FootballData.modernLeagueID(for: "4335") == "PD")
        #expect(FootballData.modernLeagueID(for: "4328") == "PL")
        #expect(FootballData.modernLeagueID(for: "4331") == "BL1")
        #expect(FootballData.modernLeagueID(for: "4332") == "SA")
        #expect(FootballData.modernLeagueID(for: "4334") == "FL1")
        #expect(FootballData.modernLeagueID(for: "4344") == "PPL")
    }

    @Test("Modern IDs pass through unchanged")
    func modernIDsPassThrough() {
        #expect(FootballData.modernTeamID(for: "86") == "86")
        #expect(FootballData.modernLeagueID(for: "PD") == "PD")
    }

    @Test("Every listed team has a unique ID and a valid competition code")
    func teamListIntegrity() {
        let teams = FootballData.topChampionsLeagueTeams
        #expect(Set(teams.map { $0.id }).count == teams.count)
        let validCodes: Set<String> = ["PD", "PL", "BL1", "SA", "FL1", "PPL"]
        #expect(teams.allSatisfy { validCodes.contains($0.leagueID) })
        #expect(FootballData.team(byID: "86")?.name == "Real Madrid")
    }
}
