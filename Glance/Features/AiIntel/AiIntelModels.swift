import Foundation

struct AiIntelData: Codable, Sendable, Equatable {
    let items: [AiIntelArticle]
    let source: String
    let timestamp: Date
}

struct AiIntelArticle: Codable, Sendable, Identifiable, Hashable, Equatable {
    let id: String
    let tag: String
    let headline: String
    let url: String
    let source: String
    let author: String
    let publishedDate: String?
    let image: String?
    let bullets: [String]
    let highlights: [String]
    let benchmarks: [String]
}
