import Testing
@testable import Glance
import Foundation

@Suite("GitHubPipeline")
struct GitHubPipelineTests {
    @Test("TrendingPeriod displays correct names")
    func trendingPeriodNames() {
        #expect(TrendingPeriod.daily.displayName == "Day")
        #expect(TrendingPeriod.weekly.displayName == "Week")
        #expect(TrendingPeriod.monthly.displayName == "Month")
    }

    @Test("TrendingPeriod returns correct period labels")
    func trendingPeriodLabels() {
        #expect(TrendingPeriod.daily.periodLabel == "today")
        #expect(TrendingPeriod.weekly.periodLabel == "this week")
        #expect(TrendingPeriod.monthly.periodLabel == "this month")
    }

    @Test("GitHubTrendingRepo initializes correctly")
    func trendingRepoInit() {
        let repo = GitHubTrendingRepo(
            rank: 1,
            owner: "apple",
            name: "swift",
            fullName: "apple/swift",
            description: "The Swift Programming Language",
            language: "Swift",
            starsTotal: 67000,
            forksTotal: 10000,
            starsPeriod: 42,
            periodLabel: "stars today",
            builtBy: ["user1", "user2"],
            url: "https://github.com/apple/swift"
        )
        #expect(repo.id == "apple/swift")
        #expect(repo.starsTotal == 67000)
        #expect(repo.starsPeriod == 42)
    }
}
