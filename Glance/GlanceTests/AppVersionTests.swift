import Testing
@testable import Glance
import Foundation

@Suite("App Version")
struct AppVersionTests {
    @Test("Formats short version and build together")
    func formatsBothParts() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "1.2",
            "CFBundleVersion": "3",
        ])
        #expect(version.shortVersion == "1.2")
        #expect(version.build == "3")
        #expect(version.display == "1.2 (3)")
    }

    @Test("Missing build degrades to em dash, not empty parens")
    func missingBuild() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.2"])
        #expect(version.display == "1.2 (—)")
    }

    @Test("Missing short version degrades to em dash")
    func missingShortVersion() {
        let version = AppVersion(infoDictionary: ["CFBundleVersion": "3"])
        #expect(version.display == "— (3)")
    }

    @Test("Nil info dictionary degrades on both parts")
    func nilDictionary() {
        let version = AppVersion(infoDictionary: nil)
        #expect(version.display == "— (—)")
    }

    @Test("Non-string version values are ignored, not force-cast")
    func nonStringValues() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": 12,
            "CFBundleVersion": 3,
        ])
        #expect(version.display == "— (—)")
    }

    @Test("Current build reports non-empty display")
    func currentIsPopulated() {
        #expect(!AppVersion.current.display.isEmpty)
        #expect(!AppVersion.current.display.contains("( )"))
    }
}