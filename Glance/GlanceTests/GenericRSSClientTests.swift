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