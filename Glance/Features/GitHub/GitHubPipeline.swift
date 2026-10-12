import Foundation

struct GitHubPipeline: Sendable {
    private let trendingClient: any GitHubTrendingClientProtocol
    private let readmeClient: any GitHubReadmeClientProtocol
    private let cache: CacheStore

    init(
        trendingClient: any GitHubTrendingClientProtocol = GitHubTrendingClient(),
        cache: CacheStore = .shared,
        readmeClient: any GitHubReadmeClientProtocol = GitHubReadmeClient()
    ) {
        self.trendingClient = trendingClient
        self.cache = cache
        self.readmeClient = readmeClient
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
            "kotlin": "#A97BFF",
            "scala": "#c22d40",
            "r": "#198CE7",
            "julia": "#a270ba",
            "shell": "#89e051",
            "vue": "#41b883",
            "css": "#563d7c",
            "html": "#e34c26",
            "jupyter notebook": "#DA5B0B",
            "c#": "#178600",
            "lua": "#000080",
            "zig": "#ec915c",
            "elixir": "#6e4a7e",
            "haskell": "#5e5086",
        ]
        return colors[lang] ?? "#8B8B8B"
    }

    func refresh(since: TrendingPeriod = .daily) async throws -> GitHubTrendingData {
        let cacheKey = "cache_github_trending_\(since.rawValue)"

        let repos = try await trendingClient.fetchTrending(since: since.rawValue)

        let data = GitHubTrendingData(
            repos: repos,
            timestamp: Date.now,
            since: since.rawValue
        )

        await cache.save(cacheKey, envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return data
    }

    /// A repo with no README caches `nil` deliberately: without it every tap of a
    /// README-less repo re-downloads a ~440 KB page.
    func readme(owner: String, name: String, forceRefresh: Bool = false) async throws -> GitHubReadme? {
        let key = CacheStore.readmeKey(owner: owner, name: name)
        if !forceRefresh,
           let envelope: CacheEnvelope<ReadmeCacheEntry> = await cache.load(key),
           !envelope.isExpired {
            return envelope.data.readme
        }
        let fetched = try await readmeClient.fetchReadme(owner: owner, name: name)
        await cache.save(
            key,
            envelope: CacheEnvelope(data: ReadmeCacheEntry(readme: fetched), ttlMs: 24 * 3_600_000)
        )
        return fetched
    }
}

struct ReadmeCacheEntry: Codable, Sendable {
    let readme: GitHubReadme?
}
