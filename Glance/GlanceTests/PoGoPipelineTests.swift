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
}
