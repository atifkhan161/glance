import Foundation

struct MadridData: Codable, Sendable, Equatable {
    let fixture: Fixture?
    let schedule: [ScheduleItem]
    let form: [String]
    let standing: String
    let intel: String
    let headToHead: String?
    let articles: [ExaArticle]
    let mmArticles: [MMArticle]
    let source: String
    let timestamp: Date
}

struct Fixture: Codable, Sendable, Equatable {
    let opponent: String
    let datetime: String
    let stadium: String
    let competition: String
    let venue: String
    let scores: Score?

    struct Score: Codable, Sendable, Equatable {
        let home: Int
        let away: Int
    }
}

struct ScheduleItem: Codable, Sendable, Equatable {
    let opponent: String
    let datetime: String
    let competition: String
    let venue: String
}

struct ExaArticle: Codable, Sendable, Identifiable, Equatable {
    let title: String
    let url: String
    let publishedDate: String?
    let highlights: [String]
    let image: String?

    var id: String { url }
}
