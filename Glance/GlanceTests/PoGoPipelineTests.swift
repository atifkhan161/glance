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
            start: "2026-12-01T10:00:00.000",
            end: "2026-12-31T10:00:00.000"
        )
        #expect(progress == 0)
    }
}

@Suite("PoGo Raid Rotation")
struct PoGoRotationTests {
    private func event(
        _ id: String,
        _ name: String,
        type: String = "raid-battles",
        start: String,
        end: String,
        bosses: [(String, Bool)] = []
    ) -> PoGoEvent {
        let payload = bosses.map { boss in
            PoGoEvent.ExtraData.RaidBattleData.RaidBossPayload(
                name: boss.0, image: "https://example.com/\(boss.0).png", canBeShiny: boss.1
            )
        }
        return PoGoEvent(
            eventID: id, name: name, eventType: type,
            start: start, end: end,
            raidBosses: bosses.map {
                RaidBoss(name: $0.0, image: "https://example.com/\($0.0).png", canBeShiny: $0.1)
            },
            extraData: PoGoEvent.ExtraData(
                raidbattles: payload.isEmpty ? nil
                    : PoGoEvent.ExtraData.RaidBattleData(bosses: payload)
            )
        )
    }

    @Test("Decodes bosses from extraData.raidbattles")
    func decodesBosses() throws {
        let json = """
        {"eventID":"mega-victreebel-in-mega-raids-september-2026",
         "name":"Mega Victreebel in Mega Raids","eventType":"raid-battles",
         "start":"2026-09-30T06:00:00.000","end":"2026-10-06T22:00:00.000",
         "extraData":{"raidbattles":{"bosses":[
            {"name":"Mega Victreebel","image":"https://cdn.leekduck.com/x.png","canBeShiny":true}]},
            "generic":{"hasSpawns":false}}}
        """
        let decoded = try JSONDecoder().decode(PoGoEvent.self, from: Data(json.utf8))
        #expect(decoded.raidBosses.count == 1)
        #expect(decoded.raidBosses.first?.name == "Mega Victreebel")
        #expect(decoded.raidBosses.first?.canBeShiny == true)
    }

    @Test("Events without extraData decode to empty bosses")
    func decodesMissingExtraData() throws {
        let json = """
        {"eventID":"raidhour20260930","name":"Xerneas Raid Hour","eventType":"raid-hour",
         "start":"2026-09-30T18:00:00.000","end":"2026-09-30T19:00:00.000"}
        """
        let decoded = try JSONDecoder().decode(PoGoEvent.self, from: Data(json.utf8))
        #expect(decoded.raidBosses.isEmpty)
        #expect(decoded.description.isEmpty)
    }

    @Test("Classifies mega, five-star and shadow rotations")
    func classifiesKinds() {
        let mega = event("m", "Mega Malamar in Mega Raids",
                         start: "2026-09-23T06:00:00.000", end: "2026-09-29T22:00:00.000")
        let fiveStar = event("f", "Xurkitree, Pheromosa, and Buzzwole in 5-star Raid Battles",
                             start: "2026-09-23T06:00:00.000", end: "2026-09-29T22:00:00.000")
        let shadow = event("s", "Shadow Thundurus (Incarnate Forme) in Shadow Raids",
                           start: "2026-09-09T06:00:00.000", end: "2026-10-06T22:00:00.000")

        #expect(PoGoPipeline.rotationKind(for: mega) == .mega)
        #expect(PoGoPipeline.rotationKind(for: fiveStar) == .fiveStar)
        #expect(PoGoPipeline.rotationKind(for: shadow) == .shadow)
    }

    @Test("Non-raid-battles events are not rotations")
    func ignoresOtherEventTypes() {
        let raidHour = event("r", "Xerneas Raid Hour", type: "raid-hour",
                             start: "2026-09-30T18:00:00.000", end: "2026-09-30T19:00:00.000")
        let spotlight = event("p", "Spotlight Hour", type: "pokemon-spotlight-hour",
                              start: "2026-09-30T17:00:00.000", end: "2026-09-30T18:00:00.000")
        #expect(PoGoPipeline.rotationKind(for: raidHour) == nil)
        #expect(PoGoPipeline.rotationKind(for: spotlight) == nil)
    }

    @Test("Shadow Mega falls back to boss name prefix")
    func shadowMegaFallback() {
        let shadowMega = event(
            "sm", "Shadow Mega Garchomp appears",
            start: "2026-10-01T06:00:00.000", end: "2026-10-07T22:00:00.000",
            bosses: [("Shadow Mega Garchomp", false)]
        )
        #expect(PoGoPipeline.rotationKind(for: shadowMega) == .mega)
    }

    @Test("Unknown vocabulary degrades to fiveStar")
    func unknownVocabularyFallsBack() {
        let odd = event("o", "Totally New Boss Type in Raids",
                        start: "2026-10-01T06:00:00.000", end: "2026-10-07T22:00:00.000",
                        bosses: [("Mysterymon", false)])
        #expect(PoGoPipeline.rotationKind(for: odd) == .fiveStar)
    }

    @Test("Raid Day becomes a flagged window and Raid Hour is excluded")
    func raidDayHandling() {
        let raidDay = event("rd", "Super Mega Raid Day", type: "raid-day",
                            start: "2026-10-31T14:00:00.000", end: "2026-10-31T17:00:00.000")
        let raidHour = event("rh", "Giratina Raid Hour", type: "raid-hour",
                             start: "2026-10-28T18:00:00.000", end: "2026-10-28T19:00:00.000")

        let windows = PoGoPipeline.buildRotationWindows(from: [raidDay, raidHour])
        #expect(windows.count == 1)
        #expect(windows.first?.isRaidDay == true)
        #expect(windows.first?.kind == .mega)
        #expect(windows.first?.tierText == "RAID DAY")
    }

    @Test("Builds and sorts weekly windows from real payload shape")
    func buildsSortedWindows() {
        let events = [
            event("mega-b", "Mega Victreebel in Mega Raids",
                  start: "2026-09-30T06:00:00.000", end: "2026-10-06T22:00:00.000",
                  bosses: [("Mega Victreebel", true)]),
            event("mega-a", "Mega Malamar in Mega Raids",
                  start: "2026-09-23T06:00:00.000", end: "2026-09-29T22:00:00.000",
                  bosses: [("Mega Malamar", true)]),
            event("five-a", "Xurkitree, Pheromosa, and Buzzwole in 5-star Raid Battles",
                  start: "2026-09-23T06:00:00.000", end: "2026-09-29T22:00:00.000",
                  bosses: [("Xurkitree", true), ("Pheromosa", true), ("Buzzwole", true)]),
        ]
        let windows = PoGoPipeline.buildRotationWindows(from: events)
        #expect(windows.map(\.id) == ["mega-a", "five-a", "mega-b"])
        #expect(windows[0].bosses.count == 1)
        #expect(windows[1].bosses.count == 3)
        #expect(windows[1].title == "Xurkitree, Pheromosa & Buzzwole")
    }

    @Test("Windows missing dates are skipped")
    func skipsUndatedWindows() {
        let undated = event("u", "Mega Eternatus in Mega Raids",
                            start: "2026-10-01T06:00:00.000", end: "2026-10-07T22:00:00.000",
                            bosses: [("Mega Eternatus", false)])
            .withoutDates()
        #expect(PoGoPipeline.buildRotationWindows(from: [undated]).isEmpty)
    }

    @Test("Past windows are retained")
    func retainsPastWindows() {
        let past = event("p", "Mega Venusaur in Mega Raids",
                         start: "2026-09-16T06:00:00.000", end: "2026-09-22T22:00:00.000",
                         bosses: [("Mega Venusaur", true)])
        let windows = PoGoPipeline.buildRotationWindows(from: [past])
        #expect(windows.count == 1)
        #expect(windows[0].isPast(at: Date(timeIntervalSince1970: 1800000000)))
        #expect(!windows[0].isPast(at: Date(timeIntervalSince1970: 1789000000)))
    }

    @Test("isCurrent respects window boundaries")
    func currentBoundaries() throws {
        let start = try #require(TimeFormat.parseISODate("2026-09-30T06:00:00.000"))
        let end = try #require(TimeFormat.parseISODate("2026-10-06T22:00:00.000"))
        let window = RaidRotationWindow(
            id: "c", kind: .fiveStar, bosses: [RaidBoss(name: "Xerneas", canBeShiny: true)],
            start: start, end: end, image: nil, link: nil, isRaidDay: false
        )

        #expect(window.isCurrent(at: start))
        #expect(window.isCurrent(at: end.addingTimeInterval(-1)))
        #expect(!window.isCurrent(at: end))
        #expect(!window.isCurrent(at: start.addingTimeInterval(-1)))
        #expect(window.isPast(at: end))
    }

    @Test("Generic event image falls back to first boss icon")
    func genericImageFallback() {
        let generic = event("g", "Mega Sableye in Mega Raids",
                            start: "2026-10-28T06:00:00.000", end: "2026-11-03T22:00:00.000",
                            bosses: [("Mega Sableye", true)])
            .withImage("https://cdn.leekduck.com/assets/img/events/mega-default.jpg")
        let windows = PoGoPipeline.buildRotationWindows(from: [generic])
        #expect(windows.first?.image == "https://example.com/Mega Sableye.png")
    }

    @Test("Track filtering separates kinds and excludes raid days")
    func trackFiltering() {
        let mega = RaidRotationWindow(
            id: "m", kind: .mega, bosses: [RaidBoss(name: "Mega X")],
            start: Date.now, end: Date.now, image: nil, link: nil, isRaidDay: false
        )
        let raidDay = RaidRotationWindow(
            id: "rd", kind: .mega, bosses: [], start: Date.now, end: Date.now,
            image: nil, link: nil, isRaidDay: true
        )
        let fiveStar = RaidRotationWindow(
            id: "f", kind: .fiveStar, bosses: [RaidBoss(name: "Y")],
            start: Date.now, end: Date.now, image: nil, link: nil, isRaidDay: false
        )
        let windows = [mega, raidDay, fiveStar]
        #expect(PoGoPipeline.rotationWindows(windows, kind: .mega) == [mega])
        #expect(PoGoPipeline.rotationWindows(windows, kind: .fiveStar) == [fiveStar])
        #expect(PoGoPipeline.rotationWindows(windows, kind: .shadow).isEmpty)
    }

    @Test("PoGoData decodes without rotations key")
    func decodesLegacyPoGoData() throws {
        let json = """
        {"raids":[],"events":[],"fiveStar":null,"mega":null,"shadow":null,
         "targetPriority":"x","credit":"y","source":"z","timestamp":700000000}
        """
        let decoded = try JSONDecoder().decode(PoGoData.self, from: Data(json.utf8))
        #expect(decoded.rotations.isEmpty)
    }

    @Test("filterActiveEvents preserves bosses and description")
    func filterPreservesBosses() {
        let source = event(
            "f", "Xerneas in 5-star Raid Battles",
            start: "2027-01-01T06:00:00.000", end: "2027-01-07T22:00:00.000",
            bosses: [("Xerneas", true)]
        )
        .described("A legendary return.")
        .withImage("https://example.com/event.jpg")

        let filtered = PoGoPipeline.filterActiveEvents([source])
        #expect(filtered.count == 1)
        #expect(filtered[0].raidBosses.map(\.name) == ["Xerneas"])
        #expect(filtered[0].description == "A legendary return.")
    }
}

private extension PoGoEvent {
    func withoutDates() -> PoGoEvent {
        PoGoEvent(
            eventID: eventID, name: name, eventType: eventType, heading: heading,
            link: link, image: image, start: nil, end: nil, countdown: countdown,
            description: description, raidBosses: raidBosses, extraData: extraData
        )
    }

    func withImage(_ image: String) -> PoGoEvent {
        PoGoEvent(
            eventID: eventID, name: name, eventType: eventType, heading: heading,
            link: link, image: image, start: start, end: end, countdown: countdown,
            description: description, raidBosses: raidBosses, extraData: extraData
        )
    }

    func described(_ description: String) -> PoGoEvent {
        PoGoEvent(
            eventID: eventID, name: name, eventType: eventType, heading: heading,
            link: link, image: image, start: start, end: end, countdown: countdown,
            description: description, raidBosses: raidBosses, extraData: extraData
        )
    }
}
