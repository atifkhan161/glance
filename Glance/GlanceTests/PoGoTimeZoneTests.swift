import Testing
@testable import Glance
import Foundation

@Suite("PoGoTimeZone")
struct PoGoTimeZoneTests {
    @Test("Unset preference falls back to Tokyo")
    func defaultsToTokyo() {
        UserDefaults.standard.removeObject(forKey: PoGoTimeZone.defaultsKey)
        #expect(PoGoTimeZone.stored == .tokyo)
        #expect(PoGoTimeZone.stored.timeZone == TimeZone(identifier: "Asia/Tokyo"))
    }

    @Test("Selection round-trips through UserDefaults")
    func roundTrips() {
        PoGoTimeZone.store(.london)
        #expect(PoGoTimeZone.stored == .london)
        PoGoTimeZone.store(.deviceDefault)
        #expect(PoGoTimeZone.stored == .deviceDefault)
        UserDefaults.standard.removeObject(forKey: PoGoTimeZone.defaultsKey)
    }

    @Test("Unrecognised stored value falls back to Tokyo rather than breaking")
    func unknownStoredValueFallsBack() {
        UserDefaults.standard.set("Mars/Olympus", forKey: PoGoTimeZone.defaultsKey)
        #expect(PoGoTimeZone.stored == .tokyo)
        UserDefaults.standard.removeObject(forKey: PoGoTimeZone.defaultsKey)
    }

    @Test("deviceDefault carries no identifier and resolves to the device zone")
    func deviceDefaultResolvesToCurrent() {
        #expect(PoGoTimeZone.deviceDefault.identifier == nil)
        #expect(PoGoTimeZone.deviceDefault.timeZone == .current)
    }

    @Test("Tokyo is nine hours ahead of UTC")
    func tokyoOffset() {
        #expect(PoGoTimeZone.tokyo.timeZone.secondsFromGMT() == 9 * 3600)
    }

    @Test("Offset label reports the zone's UTC shift")
    func offsetLabel() {
        #expect(PoGoTimeZone.tokyo.offsetLabel == "UTC+9")
        #expect(PoGoTimeZone.newYork.offsetLabel.contains("UTC-"))
    }

    @Test("Every case resolves to a real zone")
    func allCasesResolve() {
        for zone in PoGoTimeZone.allCases {
            #expect(zone.timeZone != nil)
            #expect(!zone.label.isEmpty)
        }
    }

    @Test("TimeFormat renders an event range in the selected zone")
    func localTimeRangeUsesZone() {
        let tokyo = PoGoTimeZone.tokyo.timeZone
        let start = "2026-09-30T19:00:00.000"
        let end = "2026-09-30T20:00:00.000"
        #expect(TimeFormat.localTimeRange(start: start, end: end, timeZone: tokyo) == "Sep 30, 7:00 PM → 8:00 PM")
        #expect(TimeFormat.localTimeRange(start: start, end: end, timeZone: TimeZone(identifier: "UTC")!)
                == "Sep 30, 7:00 PM → 8:00 PM")
    }
}