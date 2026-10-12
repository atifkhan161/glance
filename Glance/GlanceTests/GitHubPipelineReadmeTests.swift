import Testing
@testable import Glance
import Foundation

private final class SpyReadmeClient: GitHubReadmeClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    private let result: Result<GitHubReadme?, Error>

    init(result: Result<GitHubReadme?, Error>) {
        self.result = result
    }

    var calls: Int {
        lock.withLock { _calls }
    }

    func fetchReadme(owner: String, name: String) async throws -> GitHubReadme? {
        lock.withLock { _calls += 1 }
        return try result.get()
    }
}

@Suite("GitHubPipeline readme cache")
struct GitHubPipelineReadmeTests {
    private func makeStore() -> CacheStore {
        CacheStore(userDefaults: UserDefaults(suiteName: "test.GitHubReadme.\(UUID().uuidString)")!)
    }

    private func sample(_ html: String) -> GitHubReadme {
        GitHubReadme(fullName: "vercel/next.js", html: html, resolvedURL: "https://github.com/vercel/next.js")
    }

    @Test("returns cached readme without hitting the client")
    func returnsCachedWithoutNetwork() async throws {
        let store = makeStore()
        let key = CacheStore.readmeKey(owner: "vercel", name: "next.js")
        await store.save(key, envelope: CacheEnvelope(data: ReadmeCacheEntry(readme: sample("<p>cached</p>"))))

        let spy = SpyReadmeClient(result: .success(sample("<p>fresh</p>")))
        let pipeline = GitHubPipeline(cache: store, readmeClient: spy)
        let readme = try await pipeline.readme(owner: "vercel", name: "next.js")

        #expect(readme?.html == "<p>cached</p>")
        #expect(spy.calls == 0)
    }

    @Test("refetches when the cached entry is expired")
    func refetchesWhenExpired() async throws {
        let store = makeStore()
        let key = CacheStore.readmeKey(owner: "vercel", name: "next.js")
        await store.save(key, envelope: CacheEnvelope(data: ReadmeCacheEntry(readme: sample("<p>old</p>")), ttlMs: 0))

        let spy = SpyReadmeClient(result: .success(sample("<p>fresh</p>")))
        let pipeline = GitHubPipeline(cache: store, readmeClient: spy)
        let readme = try await pipeline.readme(owner: "vercel", name: "next.js")

        #expect(readme?.html == "<p>fresh</p>")
        #expect(spy.calls == 1)
    }

    @Test("negatively caches a repo with no readme")
    func negativelyCachesNoReadme() async throws {
        let store = makeStore()
        let spy = SpyReadmeClient(result: .success(nil))
        let pipeline = GitHubPipeline(cache: store, readmeClient: spy)

        let first = try await pipeline.readme(owner: "somerepo", name: "somerepo")
        let second = try await pipeline.readme(owner: "somerepo", name: "somerepo")

        #expect(first == nil)
        #expect(second == nil)
        #expect(spy.calls == 1)
    }

    @Test("force refresh bypasses a fresh cache entry")
    func forceRefreshBypassesCache() async throws {
        let store = makeStore()
        let key = CacheStore.readmeKey(owner: "vercel", name: "next.js")
        await store.save(key, envelope: CacheEnvelope(data: ReadmeCacheEntry(readme: sample("<p>cached</p>"))))

        let spy = SpyReadmeClient(result: .success(sample("<p>fresh</p>")))
        let pipeline = GitHubPipeline(cache: store, readmeClient: spy)
        let readme = try await pipeline.readme(owner: "vercel", name: "next.js", forceRefresh: true)

        #expect(readme?.html == "<p>fresh</p>")
        #expect(spy.calls == 1)
    }

    @Test("a failed fetch is not cached")
    func doesNotCacheFailure() async throws {
        let store = makeStore()
        let spy = SpyReadmeClient(result: .failure(GlanceError.networkUnavailable))
        let pipeline = GitHubPipeline(cache: store, readmeClient: spy)

        await #expect(throws: GlanceError.self) {
            _ = try await pipeline.readme(owner: "vercel", name: "next.js")
        }
        #expect(spy.calls == 1)
    }
}