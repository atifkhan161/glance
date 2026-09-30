import Testing
@testable import Glance
import Foundation

private class MockURLProtocol: URLProtocol {
    static var responseData: Data?
    static var responseError: Error?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let error = Self.responseError {
            client?.urlProtocol(self, didFailWithError: error)
        } else if let data = Self.responseData {
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@Suite("GitHubTrendingClient")
struct GitHubTrendingClientTests {
    private func mockClient(html: String) -> GitHubTrendingClient {
        let mockData = Data(html.utf8)
        MockURLProtocol.responseData = mockData
        MockURLProtocol.responseError = nil
        let config = URLSessionConfiguration.default
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return GitHubTrendingClient(session: session)
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