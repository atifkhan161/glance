import Testing
@testable import Glance
import Foundation

@Suite("TimeFormat")
struct TimeFormatTests {
    @Test("Just now")
    func justNow() {
        let now = Date()
        #expect(TimeFormat.relativeString(from: now, now: now) == "just now")
    }
}
