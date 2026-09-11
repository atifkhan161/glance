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
