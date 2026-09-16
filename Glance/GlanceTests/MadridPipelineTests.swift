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

    @Test("parseMatchTimeline returns last 2 finished and next 3 upcoming")
    func parseMatchTimeline_basic() {
        let teamID = "133738"

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
            teamID: teamID
        )

        #expect(timeline.count == 3)
        #expect(timeline[0].opponent == "Elche")
        #expect(timeline[0].isFinished == true)
        #expect(timeline[0].result == "W")
        #expect(timeline[0].homeScore == 2)
        #expect(timeline[0].awayScore == 3)
        #expect(timeline[0].isHome == false)

        #expect(timeline[1].opponent == "Rayo Vallecano")
        #expect(timeline[1].isFinished == true)
        #expect(timeline[1].result == "W")
        #expect(timeline[1].isHome == true)

        #expect(timeline[2].opponent == "Atlético Madrid")
        #expect(timeline[2].isFinished == false)
        #expect(timeline[2].result == nil)
        #expect(timeline[2].homeScore == nil)
        #expect(timeline[2].isHome == false)
    }

    @Test("parseMatchTimeline handles empty events")
    func parseMatchTimeline_empty() {
        let timeline = MadridPipeline.parseMatchTimeline(
            recentEvents: [],
            nextEvents: [],
            teamID: "133738"
        )
        #expect(timeline.isEmpty)
    }

    @Test("parseMatchTimeline limits to 2 finished and 3 upcoming")
    func parseMatchTimeline_limits() {
        let teamID = "133738"
        let finishedEvents = (1...5).map { i in
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
        let upcomingEvents = (6...10).map { i in
            SDBEvent(
                idEvent: "\(i)", strEvent: "Match \(i)", strLeague: "La Liga",
                strSeason: "2026-2027", strTimestamp: "2026-09-\(10 + i)T19:00:00Z",
                dateEvent: "2026-09-\(10 + i)", strTime: "19:00:00",
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
            teamID: teamID
        )

        #expect(timeline.filter(\.isFinished).count == 2)
        #expect(timeline.filter({ !$0.isFinished }).count == 3)
    }
}
