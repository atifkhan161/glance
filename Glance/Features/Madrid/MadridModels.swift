import Foundation

struct MadridData: Codable, Sendable, Equatable {
    let teamName: String
    let fixture: Fixture?
    let lastMatch: LastMatch?
    let matchTimeline: [MatchTimelineItem]
    let schedule: [ScheduleItem]
    let form: [FormEntry]
    let standing: StandingInfo?
    let standingText: String
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
    let rmBadge: String?
    let opponentBadge: String?

    struct Score: Codable, Sendable, Equatable {
        let home: Int
        let away: Int
    }
}

struct LastMatch: Codable, Sendable, Equatable {
    let opponent: String
    let score: LastMatchScore
    let competition: String
    let venue: String
    let datetime: String
    let status: String
    let scorers: [MatchEvent]
    let cards: [MatchEvent]
    let round: String?
    let rmBadge: String?
    let opponentBadge: String?

    struct LastMatchScore: Codable, Sendable, Equatable {
        let home: Int
        let away: Int
    }
}

struct MatchEvent: Codable, Sendable, Equatable {
    let minute: Int
    let player: String
    let type: String
    let detail: String
    let team: String
}

struct ScheduleItem: Codable, Sendable, Equatable {
    let opponent: String
    let datetime: String
    let competition: String
    let venue: String
}

struct StandingInfo: Codable, Sendable, Equatable {
    let rank: Int
    let points: Int
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let badge: String?
}

struct FormEntry: Codable, Sendable, Equatable, Hashable {
    let result: String
    let score: String
    let opponent: String
}

struct ExaArticle: Codable, Sendable, Identifiable, Equatable {
    let title: String
    let url: String
    let publishedDate: String?
    let highlights: [String]
    let image: String?

    var id: String { url }
}

struct MatchTimelineItem: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let teamName: String
    let opponent: String
    let opponentBadge: String?
    let rmBadge: String?
    let homeScore: Int?
    let awayScore: Int?
    let datetime: String
    let competition: String
    let venue: String
    let isFinished: Bool
    let result: String?
    let round: String?
    let isHome: Bool
}
