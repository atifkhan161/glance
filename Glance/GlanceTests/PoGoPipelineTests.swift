import Testing
@testable import Glance
import Foundation

@Suite("PoGoPipeline")
struct PoGoPipelineTests {
    @Test("Pick fiveStar skips Shadow")
    func pickFiveStar() {
        let raids = [
            PoGoRaid(name: "Shadow Mewtwo", tier: "5-Star Raids"),
            PoGoRaid(name: "Dialga", tier: "5-Star Raids"),
        ]
        let pick = PoGoPipeline.pickFiveStar(raids)
        #expect(pick?.name == "Dialga")
    }

    @Test("Filter past events")
    func filterPastEvents() {
        let events = [
            PoGoEvent(eventID: "1", name: "Past", eventType: "event", start: "2020-01-01", end: "2020-01-02"),
            PoGoEvent(eventID: "2", name: "Future", eventType: "event", start: "2026-12-01", end: "2026-12-31"),
        ]
        let filtered = PoGoPipeline.filterActiveEvents(events)
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Future")
    }

    @Test("Group events by section")
    func groupBySection() {
        let events = [
            PoGoEvent(eventID: "1", name: "Ongoing", eventType: "event",
                      start: "2026-09-15T00:00:00.000", end: "2026-09-20T00:00:00.000"),
            PoGoEvent(eventID: "2", name: "Future", eventType: "event",
                      start: "2026-12-01T00:00:00.000", end: "2026-12-31T00:00:00.000"),
        ]
        let grouped = PoGoPipeline.groupBySection(events, now: Date(timeIntervalSince1970: 1757865600))
        #expect(grouped.count >= 1)
    }

    @Test("Filter events by type")
    func filterByType() {
        let events = [
            PoGoEvent(eventID: "1", name: "Raid", eventType: "raid-hour"),
            PoGoEvent(eventID: "2", name: "Spotlight", eventType: "pokemon-spotlight-hour"),
            PoGoEvent(eventID: "3", name: "CD", eventType: "community-day"),
        ]
        let raids = PoGoPipeline.filterByType(events, filter: .raids)
        #expect(raids.count == 1)
        #expect(raids.first?.name == "Raid")
        let all = PoGoPipeline.filterByType(events, filter: .all)
        #expect(all.count == 3)
    }

    @Test("Smart countdown shows startsIn for future events")
    func smartCountdownFuture() {
        let result = TimeFormat.smartCountdown(
            start: "2026-12-01T10:00:00.000",
            end: "2026-12-31T10:00:00.000"
        )
        #expect(result.hasPrefix("Starts in"))
    }

    @Test("Smart countdown shows endsIn for ongoing events")
    func smartCountdownOngoing() {
        let result = TimeFormat.smartCountdown(
            start: "2026-09-10T00:00:00.000",
            end: "2026-09-25T00:00:00.000"
        )
        #expect(result.contains("remaining"))
    }

    @Test("Event progress is 0 for future events")
    func eventProgressFuture() {
        let progress = TimeFormat.eventProgress(
            start: "2026-12-01T00:00:00.000",
            end: "2026-12-31T00:00:00.000"
        )
        #expect(progress == 0)
    }
}
