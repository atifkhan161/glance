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

    func refresh(force: Bool = false) async throws -> GitHubData {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let since = formatter.string(from: Date.now.addingTimeInterval(-30 * 86400))
        let result = try await client.searchRepos(since: since)
        let priorRaw: CacheEnvelope<GitHubSearchResult>? = await cache.load("cache_github_raw")
        let deltas = Self.velocity(current: result.items, prior: priorRaw?.data.items ?? [])
        let repos = zip(result.items, deltas).map { GitHubRepoWithVelocity(repo: $0, velocity: $1) }
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
