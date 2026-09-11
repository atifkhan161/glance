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

    init(
        fullName: String, description: String?, language: String?, stars: Int,
        forks: Int, openIssues: Int, watchers: Int, pushedAt: String?,
        createdAt: String?, hasWiki: Bool, hasPages: Bool, hasDiscussions: Bool,
        topics: [String], license: LicenseInfo?, ownerLogin: String,
        ownerAvatar: String, htmlUrl: String, homepage: String?
    ) {
        self.fullName = fullName
        self.description = description
        self.language = language
        self.stars = stars
        self.forks = forks
        self.openIssues = openIssues
        self.watchers = watchers
        self.pushedAt = pushedAt
        self.createdAt = createdAt
        self.hasWiki = hasWiki
        self.hasPages = hasPages
        self.hasDiscussions = hasDiscussions
        self.topics = topics
        self.license = license
        self.ownerLogin = ownerLogin
        self.ownerAvatar = ownerAvatar
        self.htmlUrl = htmlUrl
        self.homepage = homepage
    }

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
        case topics, license, owner
        case ownerLogin = "owner_login"
        case ownerAvatar = "owner_avatar"
        case htmlUrl = "html_url"
        case homepage
    }

    private enum OwnerKeys: String, CodingKey {
        case login, avatarUrl = "avatar_url"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullName = try container.decode(String.self, forKey: .fullName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        stars = try container.decode(Int.self, forKey: .stars)
        forks = try container.decode(Int.self, forKey: .forks)
        openIssues = try container.decode(Int.self, forKey: .openIssues)
        watchers = try container.decode(Int.self, forKey: .watchers)
        pushedAt = try container.decodeIfPresent(String.self, forKey: .pushedAt)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        hasWiki = try container.decode(Bool.self, forKey: .hasWiki)
        hasPages = try container.decode(Bool.self, forKey: .hasPages)
        hasDiscussions = try container.decodeIfPresent(Bool.self, forKey: .hasDiscussions) ?? false
        topics = try container.decodeIfPresent([String].self, forKey: .topics) ?? []
        license = try container.decodeIfPresent(LicenseInfo.self, forKey: .license)
        htmlUrl = try container.decode(String.self, forKey: .htmlUrl)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        // Owner: nested object (GitHub API) or flat keys (tests / cached format)
        if let ownerContainer = try? container.nestedContainer(keyedBy: OwnerKeys.self, forKey: .owner) {
            ownerLogin = try ownerContainer.decode(String.self, forKey: .login)
            ownerAvatar = try ownerContainer.decodeIfPresent(String.self, forKey: .avatarUrl) ?? ""
        } else {
            ownerLogin = try container.decodeIfPresent(String.self, forKey: .ownerLogin) ?? ""
            ownerAvatar = try container.decodeIfPresent(String.self, forKey: .ownerAvatar) ?? ""
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullName, forKey: .fullName)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(stars, forKey: .stars)
        try container.encode(forks, forKey: .forks)
        try container.encode(openIssues, forKey: .openIssues)
        try container.encode(watchers, forKey: .watchers)
        try container.encodeIfPresent(pushedAt, forKey: .pushedAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encode(hasWiki, forKey: .hasWiki)
        try container.encode(hasPages, forKey: .hasPages)
        try container.encode(hasDiscussions, forKey: .hasDiscussions)
        try container.encode(topics, forKey: .topics)
        try container.encodeIfPresent(license, forKey: .license)
        try container.encode(htmlUrl, forKey: .htmlUrl)
        try container.encodeIfPresent(homepage, forKey: .homepage)
        var ownerContainer = container.nestedContainer(keyedBy: OwnerKeys.self, forKey: .owner)
        try ownerContainer.encode(ownerLogin, forKey: .login)
        try ownerContainer.encode(ownerAvatar, forKey: .avatarUrl)
    }
}

struct LicenseInfo: Codable, Sendable, Hashable {
    let name: String?
}

struct GitHubClient: GitHubClientProtocol, Sendable {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        if #available(iOS 16.0, *) {
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: config)
    }()

    func searchRepos(since: String) async throws -> GitHubSearchResult {
        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "topic:llm+topic:ai+created:>\(since)"),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc"),
            URLQueryItem(name: "per_page", value: "10"),
        ]
        guard let url = components.url else {
            print("[GitHubClient] ERROR: Invalid URL")
            throw GlanceError.networkError("Invalid GitHub URL")
        }
        print("[GitHubClient] Requesting: \(url.absoluteString)")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.addValue("Glance-iOS", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await Self.session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                print("[GitHubClient] ERROR: No HTTP response")
                throw GlanceError.networkError("GitHub request failed")
            }
            print("[GitHubClient] Status: \(http.statusCode), Bytes: \(data.count)")
            if http.statusCode == 403 {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
                print("[GitHubClient] Rate limited, retryAfter: \(retryAfter ?? "nil")")
                throw GlanceError.rateLimited(retryAfter: retryAfter.flatMap { Double($0) })
            }
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? "unable to decode"
                print("[GitHubClient] ERROR: Status \(http.statusCode), Body: \(body.prefix(200))")
                throw GlanceError.networkError("GitHub API returned \(http.statusCode)")
            }
            var result = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
            if let remaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining") {
                result = GitHubSearchResult(
                    totalCount: result.totalCount,
                    items: result.items,
                    rateLimitRemaining: Int(remaining)
                )
            }
            print("[GitHubClient] Success: \(result.totalCount) repos, \(result.items.count) items")
            return result
        } catch let error as GlanceError {
            throw error
        } catch let error as URLError {
            print("[GitHubClient] URLError: code=\(error.code.rawValue), \(error.localizedDescription)")
            if let url = error.failingURL {
                print("[GitHubClient] Failing URL: \(url.absoluteString)")
            }
            throw GlanceError.networkError("GitHub network error: \(error.localizedDescription)")
        } catch {
            print("[GitHubClient] Unknown error: \(error)")
            throw GlanceError.networkError("GitHub error: \(error.localizedDescription)")
        }
    }
}
