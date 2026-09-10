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
