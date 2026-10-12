import Testing
@testable import Glance
import Foundation

@Suite("GitHubTrendingClient")
struct GitHubTrendingClientTests {
    private func mockClient(html: String) -> GitHubTrendingClient {
        MockGitHubURLProtocol.reset()
        MockGitHubURLProtocol.stubs = [.init(statusCode: 200, data: Data(html.utf8))]
        return GitHubTrendingClient(session: MockGitHubURLProtocol.makeSession())
    }

    @Test("Trending repos have descriptions from parsed HTML")
    func trendingReposHaveDescriptions() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
        <article class="Box-row">
            <h2><a href="/apple/swift">apple/swift</a></h2>
            <p class="color-fg-muted">A powerful and intuitive programming language.</p>
            <a href="/apple/swift/stargazers">100k stars</a>
            <a href="/apple/swift/network">50k forks</a>
            <span class="float-sm-right">1k stars today</span>
        </article>
        <article class="Box-row">
            <h2><a href="/vapor/vapor">vapor/vapor</a></h2>
            <p class="color-fg-muted">A fluent web framework for Swift.</p>
            <a href="/vapor/vapor/stargazers">20k stars</a>
        </article>
        </body>
        </html>
        """
        let client = mockClient(html: html)
        let repos = try await client.fetchTrending(since: "daily")

        #expect(repos.count == 2)
        #expect(repos[0].fullName == "apple/swift")
        #expect(repos[0].description == "A powerful and intuitive programming language.")
        #expect(repos[1].fullName == "vapor/vapor")
        #expect(repos[1].description == "A fluent web framework for Swift.")
    }

    @Test("Trending repos with missing description")
    func missingDescription() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
        <article class="Box-row">
            <h2><a href="/owner/repo">owner/repo</a></h2>
            <a href="/owner/repo/stargazers">5k stars</a>
        </article>
        </body>
        </html>
        """
        let client = mockClient(html: html)
        let repos = try await client.fetchTrending(since: "daily")

        #expect(repos.count == 1)
        #expect(repos[0].description == nil)
    }
}