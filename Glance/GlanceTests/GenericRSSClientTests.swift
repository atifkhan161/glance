import Testing
@testable import Glance
import Foundation

@Suite("CustomRSSFeed Codable")
struct CustomRSSFeedCodableTests {
    @Test("Missing showThumbnails decodes as true")
    func missingShowThumbnailsDefaultsTrue() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","name":"Old","url":"https://example.com/rss","isEnabled":true}
        """.data(using: .utf8)!
        let feed = try JSONDecoder().decode(CustomRSSFeed.self, from: json)
        #expect(feed.showThumbnails == true)
    }

    @Test("showThumbnails false is preserved")
    func showThumbnailsFalsePreserved() throws {
        let json = """
        {"id":"22222222-2222-2222-2222-222222222222","name":"NoThumb","url":"https://example.com/rss","isEnabled":true,"showThumbnails":false}
        """.data(using: .utf8)!
        let feed = try JSONDecoder().decode(CustomRSSFeed.self, from: json)
        #expect(feed.showThumbnails == false)
    }

    @Test("Init defaults showThumbnails to true")
    func initDefaultsShowThumbnails() {
        let feed = CustomRSSFeed(name: "N", url: "https://example.com/rss")
        #expect(feed.showThumbnails == true)
    }

    @Test("MMArticle thumbnailURL defaults to nil")
    func mmArticleThumbnailDefaultsNil() {
        let article = MMArticle(
            id: "1", title: "T", url: "https://example.com/1", published: "",
            author: "", category: "", content: "", scrapedContent: ""
        )
        #expect(article.thumbnailURL == nil)
    }
}

@Suite("GenericRSS parse")
struct GenericRSSParseTests {
    private let client = GenericRSSClient()

    private func atomFixture(thumbnailAttribute: String?, contentHTML: String) -> Data {
        let thumb = thumbnailAttribute.map { "    <media:thumbnail \($0)/>\n" } ?? ""
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
          <title>r/Technology</title>
          <entry>
            <author><name>/u/reuters</name></author>
            <category term="technology"/>
            <content type="html"><![CDATA[\(contentHTML)]]></content>
            <published>2026-09-24T01:03:08+00:00</published>
            <link rel="alternate" href="https://www.reddit.com/r/technology/comments/abc123/example/"/>
            <title>Example post title</title>
        \(thumb)  </entry>
        </feed>
        """
        return xml.data(using: .utf8)!
    }

    @Test("Captures media:thumbnail url into thumbnailURL")
    func capturesMediaThumbnail() {
        let data = atomFixture(
            thumbnailAttribute: #"url="https://external-preview.redd.it/thumb.jpg""#,
            contentHTML: "submitted by /u/x"
        )
        let (title, articles) = client.parseFeedInfo(from: data)
        #expect(title.contains("Technology") || title == "r/Technology")
        #expect(articles.count == 1)
        #expect(articles.first?.thumbnailURL == "https://external-preview.redd.it/thumb.jpg")
        #expect(articles.first?.title == "Example post title")
        #expect(articles.first?.author == "/u/reuters")
        #expect(articles.first?.url == "https://www.reddit.com/r/technology/comments/abc123/example/")
        #expect(articles.first?.published == "2026-09-24T01:03:08+00:00")
    }

    @Test("Entry without thumbnail leaves thumbnailURL nil")
    func noThumbnailNil() {
        let data = atomFixture(thumbnailAttribute: nil, contentHTML: "plain body")
        let articles = client.parseArticles(from: data)
        #expect(articles.first?.thumbnailURL == nil)
    }

    @Test("Falls back to first img src in content")
    func fallsBackToContentImg() {
        let data = atomFixture(
            thumbnailAttribute: nil,
            contentHTML: #"<p>hi</p><img src="https://example.com/pic.png" alt="x">"#
        )
        let articles = client.parseArticles(from: data)
        #expect(articles.first?.thumbnailURL == "https://example.com/pic.png")
    }

    @Test("Skips data URI img")
    func skipsDataUriImg() {
        let data = atomFixture(
            thumbnailAttribute: nil,
            contentHTML: #"<img src="data:image/png;base64,AAAA"><img src="https://example.com/real.jpg">"#
        )
        let articles = client.parseArticles(from: data)
        #expect(articles.first?.thumbnailURL == "https://example.com/real.jpg")
    }

    @Test("Parses classic RSS item with enclosure-style media content")
    func parsesRSSItemMediaContent() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
          <channel>
            <title>Feed</title>
            <item>
              <title>RSS title</title>
              <link>https://example.com/post</link>
              <pubDate>Wed, 24 Sep 2026 00:00:00 GMT</pubDate>
              <description>body</description>
              <media:content url="https://example.com/m.jpg" type="image/jpeg"/>
            </item>
          </channel>
        </rss>
        """
        let articles = client.parseArticles(from: xml.data(using: .utf8)!)
        #expect(articles.first?.thumbnailURL == "https://example.com/m.jpg")
        #expect(articles.first?.title == "RSS title")
    }
}