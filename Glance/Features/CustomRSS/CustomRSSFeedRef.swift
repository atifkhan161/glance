import Foundation

struct CustomRSSFeedRef: Hashable, Sendable {
    let feedID: String
    let feedName: String
}

struct CustomRSSArticleRef: Hashable, Sendable {
    let article: MMArticle
    let feedName: String
}
