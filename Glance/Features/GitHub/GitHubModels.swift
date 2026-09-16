import Foundation

struct GitHubData: Codable, Sendable, Equatable {
    let repos: [GitHubRepoWithVelocity]
    let totalCount: Int
    let rateLimitRemaining: Int?
    let timestamp: Date
    let source: String
}

struct GitHubRepoWithVelocity: Codable, Sendable, Identifiable, Hashable {
    let repo: GitHubRepo
    let velocity: Int?

    var id: String { repo.fullName }
}

// MARK: - Trending Models

struct GitHubTrendingData: Codable, Sendable, Equatable {
    let repos: [GitHubTrendingRepo]
    let timestamp: Date
    let since: String
}

struct GitHubTrendingRepo: Codable, Sendable, Identifiable, Hashable {
    let rank: Int
    let owner: String
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let starsTotal: Int
    let forksTotal: Int
    let starsPeriod: Int?
    let periodLabel: String?
    let builtBy: [String]
    let url: String

    var id: String { fullName }
}

enum TrendingPeriod: String, CaseIterable, Sendable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .daily: "Day"
        case .weekly: "Week"
        case .monthly: "Month"
        }
    }

    var periodLabel: String {
        switch self {
        case .daily: "today"
        case .weekly: "this week"
        case .monthly: "this month"
        }
    }
}
