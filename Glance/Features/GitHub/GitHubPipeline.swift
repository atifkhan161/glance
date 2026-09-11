import Foundation

struct GitHubPipeline: Sendable {
    private let client: any GitHubClientProtocol
    private let cache: CacheStore

    init(client: any GitHubClientProtocol = GitHubClient(), cache: CacheStore = .shared) {
        self.client = client
        self.cache = cache
    }

    static func velocity(current: [GitHubRepo], prior: [GitHubRepo]) -> [Int?] {
        let priorByName = Dictionary(uniqueKeysWithValues: prior.map { ($0.fullName, $0.stars) })
        return current.map { repo in
            guard let old = priorByName[repo.fullName] else { return nil }
            let delta = repo.stars - old
            return delta > 0 ? delta : nil
        }
    }

    static func velocityDirection(_ velocity: Int?) -> String {
        guard let v = velocity, v > 0 else { return "" }
        if v >= 100 { return "↑↑" }
        if v >= 50 { return "↑" }
        return "↗"
    }

    static func languageColor(for language: String?) -> String {
        guard let lang = language?.lowercased() else { return "#8B8B8B" }
        let colors: [String: String] = [
            "swift": "#F05138",
            "python": "#3572A5",
            "javascript": "#f1e05a",
            "typescript": "#3178c6",
            "rust": "#dea584",
            "go": "#00ADD8",
            "java": "#b07219",
            "c++": "#f34b7d",
            "c": "#555555",
            "ruby": "#701516",
            "php": "#4F5D95",
            "swift": "#F05138",
            "kotlin": "#A97BFF",
            "dart": "#00B4AB",
            "scala": "#c22d40",
            "r": "#198CE7",
            "julia": "#a270ba",
            "shell": "#89e051",
            "vue": "#41b883",
            "css": "#563d7c",
            "html": "#e34c26",
            "jupyter notebook": "#DA5B0B",
        ]
        return colors[lang] ?? "#8B8B8B"
    }

    func refresh(force: Bool = false) async throws -> GitHubData {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Use 7-day window for velocity calculation
        let sevenDaysAgo = formatter.string(from: Date.now.addingTimeInterval(-7 * 86400))
        let thirtyDaysAgo = formatter.string(from: Date.now.addingTimeInterval(-30 * 86400))
        
        // Fetch current data (7-day window for velocity)
        let result = try await client.searchRepos(since: sevenDaysAgo)
        
        // Load prior data for velocity comparison
        let priorRaw: CacheEnvelope<GitHubSearchResult>? = await cache.load("cache_github_raw")
        let deltas = Self.velocity(current: result.items, prior: priorRaw?.data.items ?? [])
        
        let repos = zip(result.items, deltas).map { repo, delta in
            GitHubRepoWithVelocity(repo: repo, velocity: delta)
        }
        
        let data = GitHubData(
            repos: repos, totalCount: result.totalCount,
            rateLimitRemaining: result.rateLimitRemaining, timestamp: Date.now,
            source: "github"
        )
        await cache.save("cache_github", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        await cache.save("cache_github_raw", envelope: CacheEnvelope(data: result, ttlMs: 24 * 3_600_000))
        return data
    }
}
