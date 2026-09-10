import Foundation

protocol GitHubClientProtocol: Sendable {
    func searchRepos(since: String) async throws -> GitHubSearchResult
}

struct GitHubSearchResult: Codable, Sendable {
    let totalCount: Int
    let items: [GitHubRepo]
    let rateLimitRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
        case rateLimitRemaining
    }

    init(totalCount: Int, items: [GitHubRepo], rateLimitRemaining: Int? = nil) {
        self.totalCount = totalCount
        self.items = items
        self.rateLimitRemaining = rateLimitRemaining
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCount = try container.decodeIfPresent(Int.self, forKey: .totalCount) ?? 0
        items = try container.decodeIfPresent([GitHubRepo].self, forKey: .items) ?? []
        rateLimitRemaining = try container.decodeIfPresent(Int.self, forKey: .rateLimitRemaining)
    }
}

struct GitHubRepo: Codable, Sendable, Identifiable, Hashable {
    let fullName: String
    let description: String?
    let language: String?
    let stars: Int
    let forks: Int
    let openIssues: Int
    let watchers: Int
    let pushedAt: String?
    let createdAt: String?
    let hasWiki: Bool
    let hasPages: Bool
    let hasDiscussions: Bool
    let topics: [String]
    let license: LicenseInfo?
    let ownerLogin: String
    let ownerAvatar: String
    let htmlUrl: String
    let homepage: String?

    var id: String { fullName }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case description, language
        case stars = "stargazers_count"
        case forks = "forks_count"
        case openIssues = "open_issues_count"
        case watchers = "watchers_count"
        case pushedAt = "pushed_at"
        case createdAt = "created_at"
        case hasWiki = "has_wiki"
        case hasPages = "has_pages"
        case hasDiscussions = "has_discussions"
        case topics, license
        case ownerLogin = "owner_login"
        case ownerAvatar = "owner_avatar"
        case htmlUrl = "html_url"
        case homepage
    }
}

struct LicenseInfo: Codable, Sendable, Hashable {
    let name: String?
}

struct GitHubClient: GitHubClientProtocol, Sendable {
    func searchRepos(since: String) async throws -> GitHubSearchResult {
        let query = "topic:llm+topic:ai+created:>\(since)&sort=stars&order=desc"
        guard let url = URL(string: "https://api.github.com/search/repositories?q=\(query)&per_page=10") else {
            throw GlanceError.networkError("Invalid GitHub URL")
        }
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlanceError.networkError("GitHub request failed")
        }
        if http.statusCode == 403 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
            throw GlanceError.rateLimited(retryAfter: retryAfter.flatMap { Double($0) })
        }
        var result = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
        if let remaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining") {
            result = GitHubSearchResult(
                totalCount: result.totalCount,
                items: result.items,
                rateLimitRemaining: Int(remaining)
            )
        }
        return result
    }
}
