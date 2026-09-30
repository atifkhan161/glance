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

    @Test("parseMatchTimeline returns upcoming first then recent finished")
    func parseMatchTimeline_basic() {
        let teamID = "133738"
        let teamName = "Real Madrid"

        let finished1 = SDBEvent(
            idEvent: "1", strEvent: "Elche vs Real Madrid", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-15T19:30:00Z",
            dateEvent: "2026-09-15", strTime: "19:30:00",
            strHomeTeam: "Elche", strAwayTeam: "Real Madrid",
            idHomeTeam: "134384", idAwayTeam: "133738",
            strVenue: "Estadio Martínez Valero", intRound: "6",
            strStatus: "FT", intHomeScore: 2, intAwayScore: 3,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let finished2 = SDBEvent(
            idEvent: "2", strEvent: "Real Madrid vs Rayo Vallecano", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-12T19:00:00Z",
            dateEvent: "2026-09-12", strTime: "19:00:00",
            strHomeTeam: "Real Madrid", strAwayTeam: "Rayo Vallecano",
            idHomeTeam: "133738", idAwayTeam: "133728",
            strVenue: "Santiago Bernabéu", intRound: "5",
            strStatus: "FT", intHomeScore: 4, intAwayScore: 1,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let upcoming1 = SDBEvent(
            idEvent: "3", strEvent: "Atlético Madrid vs Real Madrid", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-20T14:15:00Z",
            dateEvent: "2026-09-20", strTime: "14:15:00",
            strHomeTeam: "Atlético Madrid", strAwayTeam: "Real Madrid",
            idHomeTeam: "133729", idAwayTeam: "133738",
            strVenue: "Riyadh Air Metropolitano", intRound: "7",
            strStatus: "NS", intHomeScore: nil, intAwayScore: nil,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let recentEvents = [finished1, finished2]
        let nextEvents = [upcoming1]

        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: recentEvents,
            nextEvents: nextEvents,
            teamID: teamID,
            teamName: teamName
        )

        #expect(timeline.count == 3)
        #expect(timeline[0].opponent == "Atlético Madrid")
        #expect(timeline[0].isFinished == false)
        #expect(timeline[0].result == nil)
        #expect(timeline[0].homeScore == nil)
        #expect(timeline[0].isHome == false)

        #expect(timeline[1].opponent == "Elche")
        #expect(timeline[1].isFinished == true)
        #expect(timeline[1].result == "W")
        #expect(timeline[1].homeScore == 2)
        #expect(timeline[1].awayScore == 3)
        #expect(timeline[1].isHome == false)
        // Away win: score must read from Madrid's perspective, not home/away
        #expect(timeline[1].teamScore == 3)
        #expect(timeline[1].opponentScore == 2)
        #expect(timeline[1].scoreText == "3 - 2")

        #expect(timeline[2].opponent == "Rayo Vallecano")
        #expect(timeline[2].isFinished == true)
        #expect(timeline[2].result == "W")
        #expect(timeline[2].isHome == true)
        #expect(timeline[2].teamScore == 4)
        #expect(timeline[2].opponentScore == 1)
        #expect(timeline[2].scoreText == "4 - 1")
    }

    @Test("Away loss reads 1 - 2 for Madrid, not 2 - 1")
    func awayLossScoreOrientation() {
        let awayLoss = SDBEvent(
            idEvent: "9", strEvent: "Barcelona vs Real Madrid", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-05T19:30:00Z",
            dateEvent: "2026-09-05", strTime: "19:30:00",
            strHomeTeam: "Barcelona", strAwayTeam: "Real Madrid",
            idHomeTeam: "133739", idAwayTeam: "133738",
            strVenue: "Spotify Camp Nou", intRound: "4",
            strStatus: "FT", intHomeScore: 2, intAwayScore: 1,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: [awayLoss], nextEvents: [],
            teamID: "133738", teamName: "Real Madrid"
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

    @Test("convertToLastMatch and convertToFixture carry team-relative scores")
    func conversionsAreTeamRelative() {
        let awayLoss = SDBEvent(
            idEvent: "9", strEvent: "Barcelona vs Real Madrid", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-05T19:30:00Z",
            dateEvent: "2026-09-05", strTime: "19:30:00",
            strHomeTeam: "Barcelona", strAwayTeam: "Real Madrid",
            idHomeTeam: "133739", idAwayTeam: "133738",
            strVenue: "Spotify Camp Nou", intRound: "4",
            strStatus: "FT", intHomeScore: 2, intAwayScore: 1,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: [awayLoss], nextEvents: [],
            teamID: "133738", teamName: "Real Madrid"
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
        let awayLoss = SDBEvent(
            idEvent: "9", strEvent: "Barcelona vs Real Madrid", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-05T19:30:00Z",
            dateEvent: "2026-09-05", strTime: "19:30:00",
            strHomeTeam: "Barcelona", strAwayTeam: "Real Madrid",
            idHomeTeam: "133739", idAwayTeam: "133738",
            strVenue: "Spotify Camp Nou", intRound: "4",
            strStatus: "FT", intHomeScore: 2, intAwayScore: 1,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let lastMatch = try! #require(MadridPipeline.parseLastMatch(from: [awayLoss], teamID: "133738"))
        let intel = MadridPipeline.generateIntel(nextFixture: nil, lastMatch: lastMatch, teamName: "Real Madrid")

        #expect(intel == "Lost last match 1-2 vs Barcelona")
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

    /// Real fixtures from TheSportsDB (id 4335, season 2026-2027), in the
    /// ascending order the pipeline actually produces: rounds are appended 1...9.
    private static func realFormEvents() -> [SDBEvent] {
        [
            SDBEvent(
                idEvent: "r2", strEvent: "Espanyol vs Real Madrid", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-08-22T19:00:00Z",
                dateEvent: "2026-08-22", strTime: "19:00:00",
                strHomeTeam: "Espanyol", strAwayTeam: "Real Madrid",
                idHomeTeam: "133734", idAwayTeam: "133738",
                strVenue: "RCDE Stadium", intRound: "2",
                strStatus: "FT", intHomeScore: 1, intAwayScore: 2,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            ),
            SDBEvent(
                idEvent: "r4", strEvent: "Real Betis vs Real Madrid", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-09-04T19:00:00Z",
                dateEvent: "2026-09-04", strTime: "19:00:00",
                strHomeTeam: "Real Betis", strAwayTeam: "Real Madrid",
                idHomeTeam: "133722", idAwayTeam: "133738",
                strVenue: "Benito Villamarín", intRound: "4",
                strStatus: "FT", intHomeScore: 1, intAwayScore: 0,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            ),
            SDBEvent(
                idEvent: "r5", strEvent: "Real Madrid vs Rayo Vallecano", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-09-12T19:00:00Z",
                dateEvent: "2026-09-12", strTime: "19:00:00",
                strHomeTeam: "Real Madrid", strAwayTeam: "Rayo Vallecano",
                idHomeTeam: "133738", idAwayTeam: "133728",
                strVenue: "Santiago Bernabéu", intRound: "5",
                strStatus: "FT", intHomeScore: 4, intAwayScore: 1,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            ),
            SDBEvent(
                idEvent: "r6", strEvent: "Elche vs Real Madrid", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-09-15T19:30:00Z",
                dateEvent: "2026-09-15", strTime: "19:30:00",
                strHomeTeam: "Elche", strAwayTeam: "Real Madrid",
                idHomeTeam: "133729", idAwayTeam: "133738",
                strVenue: "Estadio Martínez Valero", intRound: "6",
                strStatus: "FT", intHomeScore: 2, intAwayScore: 3,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            ),
        ]
    }

    @Test("parseForm returns newest first, not oldest first")
    func parseForm_newestFirst() {
        let form = MadridPipeline.parseForm(
            from: Self.realFormEvents(), teamID: "133738"
        )

        #expect(form.count == 4)
        // Newest match leads the strip: Elche 2-3, an away win for Madrid.
        #expect(form[0].result == "W")
        #expect(form[0].score == "3-2")
        #expect(form[0].opponent == "ELC")
        // Then the Rayo home win.
        #expect(form[1].result == "W")
        #expect(form[1].score == "4-1")
        #expect(form[1].opponent == "RAY")
        // Real Betis 1-0 was the only away defeat.
        #expect(form[2].result == "L")
        #expect(form[2].score == "0-1")
        #expect(form[2].opponent == "REA")
        // Espanyol 1-2 was also an away win, not a loss.
        #expect(form[3].result == "W")
        #expect(form[3].score == "2-1")
        #expect(form[3].opponent == "ESP")
    }

    @Test("parseForm keeps the latest 5 and drops older matches")
    func parseForm_keepsLatestFive() {
        // Seven finished matches, ascending - more than the 5-entry limit.
        let extra = (17...20).map { day in
            SDBEvent(
                idEvent: "extra\(day)", strEvent: "Match \(day)", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-09-\(day)T19:00:00Z",
                dateEvent: "2026-09-\(day)", strTime: "19:00:00",
                strHomeTeam: "Real Madrid", strAwayTeam: "Rayo Vallecano",
                idHomeTeam: "133738", idAwayTeam: "133728",
                strVenue: "Santiago Bernabéu", intRound: "7",
                strStatus: "FT", intHomeScore: 1, intAwayScore: 0,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            )
        }

        let form = MadridPipeline.parseForm(
            from: Self.realFormEvents() + extra, teamID: "133738"
        )

        #expect(form.count == 5)
        // The newest match must survive the prefix; the oldest must not appear.
        #expect(form[0].opponent == "RAY")   // 2026-09-20, the latest
        #expect(form[0].result == "W")
        // The stale August fixture is the one dropped.
        #expect(!form.contains { $0.opponent == "ESP" })
    }

    @Test("parseForm ignores unfinished matches")
    func parseForm_ignoresUnfinished() {
        let upcoming = SDBEvent(
            idEvent: "r7", strEvent: "Real Madrid vs Sevilla", strLeague: "La Liga",
            strSeason: "2026-2027", strTimestamp: "2026-09-28T19:00:00Z",
            dateEvent: "2026-09-28", strTime: "19:00:00",
            strHomeTeam: "Real Madrid", strAwayTeam: "Sevilla",
            idHomeTeam: "133738", idAwayTeam: "133727",
            strVenue: "Santiago Bernabéu", intRound: "7",
            strStatus: "NS", intHomeScore: nil, intAwayScore: nil,
            strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
        )

        let form = MadridPipeline.parseForm(
            from: Self.realFormEvents() + [upcoming], teamID: "133738"
        )

        #expect(form.count == 4)
        #expect(!form.contains { $0.opponent == "SEV" })
    }

    @Test("parseForm handles empty events")
    func parseForm_empty() {
        #expect(MadridPipeline.parseForm(from: [], teamID: "133738").isEmpty)
    }

    @Test("parseForm matches the timeline ordering")
    func parseForm_agreesWithTimeline() {
        let events = Self.realFormEvents()
        let form = MadridPipeline.parseForm(from: events, teamID: "133738")
        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: events, nextEvents: [], teamID: "133738", teamName: "Real Madrid"
        )
        let finishedInTimeline = timeline.filter { $0.isFinished }

        // Both surfaces should read newest-first off the same fixtures.
        #expect(form.count == finishedInTimeline.count)
        for (formEntry, item) in zip(form, finishedInTimeline) {
            #expect(formEntry.result == item.result)
            #expect(item.teamScore != nil)
            #expect(item.opponentScore != nil)
            // teamScore/opponentScore are optionals - unwrap before interpolating.
            #expect(formEntry.score == "\(item.teamScore ?? -1)-\(item.opponentScore ?? -1)")
        }
    }

    @Test("parseMatchTimeline handles empty events")
    func parseMatchTimeline_empty() {
        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: [],
            nextEvents: [],
            teamID: "133738",
            teamName: "Real Madrid"
        )
        #expect(timeline.isEmpty)
    }

    @Test("parseMatchTimeline limits to 4 finished and 3 upcoming")
    func parseMatchTimeline_limits() {
        let teamID = "133738"
        let teamName = "Real Madrid"
        let finishedEvents = (1...6).map { i in
            SDBEvent(
                idEvent: "\(i)", strEvent: "Match \(i)", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-09-\(10 + i)T19:00:00Z",
                dateEvent: "2026-09-\(10 + i)", strTime: "19:00:00",
                strHomeTeam: i % 2 == 0 ? "Real Madrid" : "Opponent \(i)",
                strAwayTeam: i % 2 == 0 ? "Opponent \(i)" : "Real Madrid",
                idHomeTeam: i % 2 == 0 ? "133738" : "13400\(i)",
                idAwayTeam: i % 2 == 0 ? "13400\(i)" : "133738",
                strVenue: "Stadium \(i)", intRound: "\(i)",
                strStatus: "FT", intHomeScore: 2, intAwayScore: 1,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            )
        }
        let upcomingEvents = (1...5).map { i in
            SDBEvent(
                idEvent: "up-\(i)", strEvent: "Upcoming \(i)", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-10-\(10 + i)T19:00:00Z",
                dateEvent: "2026-10-\(10 + i)", strTime: "19:00:00",
                strHomeTeam: i % 2 == 0 ? "Real Madrid" : "Opponent \(i)",
                strAwayTeam: i % 2 == 0 ? "Opponent \(i)" : "Real Madrid",
                idHomeTeam: i % 2 == 0 ? "133738" : "13400\(i)",
                idAwayTeam: i % 2 == 0 ? "13400\(i)" : "133738",
                strVenue: "Stadium \(i)", intRound: "\(i)",
                strStatus: "NS", intHomeScore: nil, intAwayScore: nil,
                strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
            )
        }

        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: finishedEvents,
            nextEvents: upcomingEvents,
            teamID: teamID,
            teamName: teamName
        )

        #expect(timeline.filter { $0.isFinished }.count == 4)
        #expect(timeline.filter { !$0.isFinished }.count == 3)
    }
}
