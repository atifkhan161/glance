import Testing
@testable import Glance
import Foundation

@Suite("GitHubReadmeClient")
struct GitHubReadmeClientTests {
    private func fixture(_ name: String) throws -> String {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let url = base.appendingPathComponent("Fixtures/\(name).html")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func client() -> GitHubReadmeClient {
        MockGitHubURLProtocol.reset()
        return GitHubReadmeClient(session: MockGitHubURLProtocol.makeSession())
    }

    @Test("extracts the DOM article, not the richText decoy")
    func extractsDomArticle() throws {
        let html = try fixture("readme-with-decoy")
        let article = GitHubReadmeClient.extractArticle(from: html)
        #expect(article != nil)
        #expect(!(article ?? "").contains("\\u003c"))
        #expect(!(article ?? "").contains("JSON ESCAPED DECOY"))
        #expect((article ?? "").contains("Next.js"))
    }

    @Test("extract returns nil when the page has no article")
    func extractReturnsNilWithoutArticle() throws {
        #expect(GitHubReadmeClient.extractArticle(from: try fixture("no-readme")) == nil)
    }

    @Test("extract rejects an implausibly short article")
    func extractRejectsShortArticle() {
        #expect(GitHubReadmeClient.extractArticle(from: "<article class=\"markdown-body\">hi</article>") == nil)
    }

    @Test("absolutizes relative image and link targets")
    func absolutizesRelativeURLs() throws {
        let base = URL(string: "https://github.com/vercel/next.js")!
        let result = GitHubReadmeClient.absolutizeURLs(
            in: "<img src=\"/vercel.png\"><a href=\"./docs\">d</a><a href=\"#nextjs\">n</a><img src=\"https://cdn.example/x.png\">",
            base: base
        )
        #expect(result.contains("src=\"https://github.com/vercel.png\""))
        #expect(result.contains("href=\"https://github.com/vercel/docs\""))
        #expect(result.contains("href=\"#nextjs\""))
        #expect(result.contains("src=\"https://cdn.example/x.png\""))
    }

    @Test("follows a redirect and reports the resolved URL")
    func followsRedirect() async throws {
        let html = try fixture("readme-with-decoy")
        MockGitHubURLProtocol.stubs = [
            .init(statusCode: 301, headers: ["Location": "https://github.com/react/react"]),
            .init(statusCode: 200, data: Data(html.utf8)),
        ]
        let readme = try await GitHubReadmeClient(session: MockGitHubURLProtocol.makeSession())
            .fetchReadme(owner: "facebook", name: "react")
        #expect(readme?.resolvedURL == "https://github.com/react/react")
        #expect(readme?.fullName == "facebook/react")
    }

    @Test("returns nil when the api fallback is a 404")
    func returnsNilWhenApiIs404() async throws {
        MockGitHubURLProtocol.stubs = [
            .init(statusCode: 200, data: Data(try fixture("no-readme").utf8)),
            .init(statusCode: 404, data: Data(#"{"message":"Not Found"}"#.utf8)),
        ]
        let readme = try await GitHubReadmeClient(session: MockGitHubURLProtocol.makeSession())
            .fetchReadme(owner: "somerepo", name: "somerepo")
        #expect(readme == nil)
    }

    @Test("does not fall back after a transport failure")
    func noFallbackAfterTransportFailure() async {
        MockGitHubURLProtocol.error = URLError(.notConnectedToInternet)
        do {
            _ = try await GitHubReadmeClient(session: MockGitHubURLProtocol.makeSession())
                .fetchReadme(owner: "vercel", name: "next.js")
            Issue.record("expected a thrown error")
        } catch {
            #expect(MockGitHubURLProtocol.requestedURLs.count == 1)
        }
    }

    @Test("sanitize strips scripts but keeps images")
    func sanitizeStripsScripts() {
        let result = GitHubReadmeClient.sanitize(
            "<p>keep</p><script>alert(1)</script><img src=\"https://x/y.png\" onclick=\"steal()\">"
        )
        #expect(!result.contains("alert(1)"))
        #expect(!result.contains("onclick"))
        #expect(result.contains("<img"))
        #expect(result.contains("keep"))
    }

    @Test("sanitize strips iframes and objects")
    func sanitizeStripsFrames() {
        let result = GitHubReadmeClient.sanitize(#"<iframe src="https://evil"></iframe><object></object><b>x</b>"#)
        #expect(!result.contains("iframe"))
        #expect(!result.contains("object"))
        #expect(result.contains("<b>x</b>"))
    }
}