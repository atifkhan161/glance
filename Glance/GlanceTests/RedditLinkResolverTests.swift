import Testing
@testable import Glance
import Foundation

@Suite("RedditLinkResolver")
struct RedditLinkResolverTests {
    private func article(url: String, content: String) -> MMArticle {
        MMArticle(
            id: url, title: "T", url: url, published: "",
            author: "", category: "", content: content, scrapedContent: ""
        )
    }

    @Test("Recognizes reddit hosts")
    func redditHosts() {
        #expect(RedditLinkResolver.isRedditHost("www.reddit.com"))
        #expect(RedditLinkResolver.isRedditHost("old.reddit.com"))
        #expect(RedditLinkResolver.isRedditHost("reddit.com"))
        #expect(RedditLinkResolver.isRedditHost("redd.it"))
        #expect(!RedditLinkResolver.isRedditHost("example.com"))
        #expect(!RedditLinkResolver.isRedditHost("notreddit.com"))
    }

    @Test("isRedditPermalink true for comments URL")
    func permalinkTrue() {
        #expect(RedditLinkResolver.isRedditPermalink("https://www.reddit.com/r/technology/comments/abc/title/"))
        #expect(RedditLinkResolver.isRedditPermalink("https://old.reddit.com/r/x/comments/1/"))
        #expect(!RedditLinkResolver.isRedditPermalink("https://example.com/article"))
        #expect(!RedditLinkResolver.isRedditPermalink("not a url"))
    }

    @Test("Extracts first external href from link post content")
    func extractsExternalHref() {
        let content = """
        <div>submitted by <a href="/u/x">/u/x</a> <a href="https://www.reuters.com/article?utm=1&amp;x=2">[link]</a> <a href="https://www.reddit.com/r/technology/comments/abc/t/">[comments]</a></div>
        """
        let url = RedditLinkResolver.externalURL(fromContent: content)
        #expect(url?.host == "www.reuters.com")
        #expect(url?.query?.contains("utm=1") == true)
        #expect(url?.query?.contains("x=2") == true)
    }

    @Test("Self post with no external href returns nil")
    func selfPostNil() {
        let content = "<div class=\"md\"><p>Just a text post with a <a href=\"https://www.reddit.com/r/foo\">reddit link</a></p></div>"
        #expect(RedditLinkResolver.externalURL(fromContent: content) == nil)
    }

    @Test("Skips relative hrefs")
    func skipsRelative() {
        let content = #"<a href="/r/technology">sub</a><a href="https://blog.example.com/post">ext</a>"#
        let url = RedditLinkResolver.externalURL(fromContent: content)
        #expect(url?.host == "blog.example.com")
    }

    @Test("scrapeTarget nil for reddit self post")
    func scrapeTargetSelfPost() {
        let a = article(
            url: "https://www.reddit.com/r/technology/comments/abc/self/",
            content: "<p>hello world no external link</p>"
        )
        #expect(RedditLinkResolver.scrapeTarget(for: a) == nil)
    }

    @Test("scrapeTarget prefers external over reddit permalink")
    func scrapeTargetPrefersExternal() {
        let a = article(
            url: "https://www.reddit.com/r/technology/comments/abc/link/",
            content: #"<a href="https://www.nytimes.com/2026/09/story">[link]</a>"#
        )
        #expect(RedditLinkResolver.scrapeTarget(for: a)?.host == "www.nytimes.com")
    }

    @Test("scrapeTarget uses article url for non-reddit feeds")
    func scrapeTargetNonReddit() {
        let a = article(
            url: "https://example.com/blog/post",
            content: "<p>body</p>"
        )
        #expect(RedditLinkResolver.scrapeTarget(for: a)?.absoluteString == "https://example.com/blog/post")
    }

    @Test("commentsURL only for reddit permalinks")
    func commentsURL() {
        let reddit = article(url: "https://www.reddit.com/r/x/comments/1/t/", content: "")
        let blog = article(url: "https://example.com/a", content: "")
        #expect(RedditLinkResolver.commentsURL(for: reddit) != nil)
        #expect(RedditLinkResolver.commentsURL(for: blog) == nil)
    }
}