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

struct MatchScore: Codable, Sendable, Equatable {
    let team: Int
    let opponent: Int

    var text: String { "\(team) - \(opponent)" }

    init(team: Int, opponent: Int) {
        self.team = team
        self.opponent = opponent
    }

    /// Build from an API home/away pair relative to the tracked team.
    init(home: Int, away: Int, isHome: Bool) {
        self.team = isHome ? home : away
        self.opponent = isHome ? away : home
    }
}

struct Fixture: Codable, Sendable, Equatable {
    let opponent: String
    let datetime: String
    let stadium: String
    let competition: String
    let venue: String
    let scores: MatchScore?
    let rmBadge: String?
    let opponentBadge: String?
    let isHome: Bool
}

struct LastMatch: Codable, Sendable, Equatable {
    let opponent: String
    let score: MatchScore
    let competition: String
    let venue: String
    let datetime: String
    let status: String
    let scorers: [MatchEvent]
    let cards: [MatchEvent]
    let round: String?
    let rmBadge: String?
    let opponentBadge: String?
    let isHome: Bool
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

    /// Score relative to the tracked team, not home/away.
    var teamScore: Int? { isHome ? homeScore : awayScore }
    var opponentScore: Int? { isHome ? awayScore : homeScore }

    var scoreText: String? {
        guard let teamScore, let opponentScore else { return nil }
        return "\(teamScore) - \(opponentScore)"
    }
}
