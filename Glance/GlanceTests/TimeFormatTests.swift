import Testing
@testable import Glance
import Foundation

@Suite("TimeFormat")
struct TimeFormatTests {
    @Test("formatAge under 60s")
    func ageSeconds() {
        let date = Date.now.addingTimeInterval(-30)
        #expect(TimeFormat.age(from: date) == "just now")
    }

    @Test("formatAge under 60m")
    func ageMinutes() {
        let date = Date.now.addingTimeInterval(-300)
        #expect(TimeFormat.age(from: date) == "5m ago")
    }

    @Test("formatAge under 24h")
    func ageHours() {
        let date = Date.now.addingTimeInterval(-7200)
        #expect(TimeFormat.age(from: date) == "2h ago")
    }

    @Test("formatStars thousands")
    func starsThousands() {
        #expect(TimeFormat.stars(12400) == "12.4k")
    }

    @Test("formatStars small")
    func starsSmall() {
        #expect(TimeFormat.stars(523) == "523")
    }

    @Test("countdownTo future")
    func countdownFuture() {
        let date = Date.now.addingTimeInterval(7200)
        let result = TimeFormat.countdownTo(date)
        #expect(result.contains("in"))
    }

    @Test("countdownTo past returns empty")
    func countdownPast() {
        let date = Date.now.addingTimeInterval(-100)
        #expect(TimeFormat.countdownTo(date) == "")
    }
}

@Suite("TimeFormat.parseISODate timeZone")
struct ParseISODateTimeZoneTests {
    private let tokyo = TimeZone(identifier: "Asia/Tokyo")!

    @Test("offset-less timestamp is read as wall clock in the given zone")
    func naiveReadsAsWallClockInZone() throws {
        let date = try #require(TimeFormat.parseISODate("2026-09-30T19:00:00.000", timeZone: tokyo))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tokyo
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        #expect(formatter.string(from: date) == "2026-09-30 19:00")
    }

    @Test("Tokyo parse trails the UTC parse by nine hours")
    func tokyoParseTrailsUTCParse() throws {
        let tokyoDate = try #require(TimeFormat.parseISODate("2026-09-30T19:00:00.000", timeZone: tokyo))
        let utcDate = try #require(TimeFormat.parseISODate("2026-09-30T19:00:00.000"))
        #expect(tokyoDate.timeIntervalSince(utcDate) == -9 * 3600)
    }

    @Test("explicit offset in the payload still wins over the zone")
    func explicitOffsetWins() throws {
        let date = try #require(TimeFormat.parseISODate("2026-09-30T19:00:00Z", timeZone: tokyo))
        #expect(date == TimeFormat.parseISODate("2026-09-30T19:00:00.000"))
    }

    @Test("default zone stays UTC so existing callers are unchanged")
    func defaultZoneIsUTC() throws {
        let date = try #require(TimeFormat.parseISODate("2026-09-30T19:00:00.000"))
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        #expect(utc.component(.hour, from: date) == 19)
    }

    @Test("date-only payload is read at midnight in the given zone")
    func dateOnlyMidnightInZone() throws {
        let date = try #require(TimeFormat.parseISODate("2026-09-30", timeZone: tokyo))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tokyo
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        #expect(formatter.string(from: date) == "2026-09-30 00:00")
    }

    @Test("garbage still returns nil")
    func garbageIsNil() {
        #expect(TimeFormat.parseISODate("not-a-date", timeZone: tokyo) == nil)
    }
}
