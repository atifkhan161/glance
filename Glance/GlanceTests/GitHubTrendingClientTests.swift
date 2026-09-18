import Testing
@testable import Glance
import Foundation

@Suite("GitHubTrendingClient")
struct GitHubTrendingClientTests {
    @Test("Trending repos have descriptions from live fetch")
    func trendingReposHaveDescriptions() async throws {
        let client = GitHubTrendingClient()
        let repos = try await client.fetchTrending(since: "daily")

        #expect(!repos.isEmpty, "Should have at least one trending repo")

        for repo in repos.prefix(5) {
            #expect(repo.description != nil && !repo.description!.isEmpty,
                   "Repo \(repo.fullName) should have a non-empty description")
        }
    }
}