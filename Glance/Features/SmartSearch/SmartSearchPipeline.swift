import Foundation
import CryptoKit

struct SmartSearchPipeline: Sendable {
    private let exa = ExaEnhancedClient()
    private let openRouter = OpenRouterClient()
    private let markdownStore = MarkdownStore.shared
    private let keychain = KeychainStore.shared
    private let cache = CacheStore.shared

    func quickSearch(query: String) async throws -> [ExaResult] {
        let cacheKey = searchCacheKey(query)

        if let cached: CacheEnvelope<[ExaResult]> = await cache.load(cacheKey),
           !cached.isExpired {
            return cached.data
        }

        guard let exaKey = keychain.load(forKey: "keys_exa") else {
            throw GlanceError.keyMissing("Exa API key not configured")
        }
        let request = ExaEnhancedSearchRequest(
            query: query,
            type: "auto",
            numResults: 10,
            contentsHighlights: true,
            contentsText: false
        )
        let results = try await exa.search(request: request, apiKey: exaKey)
        await cache.save(cacheKey, envelope: CacheEnvelope(data: results, ttlMs: 24 * 3_600 * 1000))
        return results
    }

    func generateAggregatedSummary(query: String, results: [ExaResult]) async throws -> String {
        let cacheKey = summaryCacheKey(query)

        if let cached: CacheEnvelope<String> = await cache.load(cacheKey),
           !cached.isExpired {
            return cached.data
        }

        guard let openRouterKey = keychain.load(forKey: "keys_openrouter") else {
            throw GlanceError.keyMissing("OpenRouter API key not configured")
        }

        let combinedHighlights = results.enumerated().map { index, result in
            let snippets = result.highlights.prefix(3).joined(separator: " ")
            return "[\(index + 1)] \(result.title): \(snippets)"
        }.joined(separator: "\n\n")

        let systemPrompt = """
        You are a research summarizer. Given search results about a query, produce a concise \
        2-3 sentence overview covering the key findings, trends, or consensus across the sources. \
        Be factual and specific. Do not use headers or markdown formatting — just plain text.
        """
        let summary = try await openRouter.complete(
            systemPrompt: systemPrompt,
            userPrompt: "Query: \(query)\n\nSearch results:\n\(combinedHighlights)",
            apiKey: openRouterKey
        )

        await cache.save(cacheKey, envelope: CacheEnvelope(data: summary, ttlMs: 24 * 3_600 * 1000))
        return summary
    }

    func generateSubQueries(topic: String, count: Int) async throws -> [String] {
        guard let openRouterKey = keychain.load(forKey: "keys_openrouter") else {
            throw GlanceError.keyMissing("OpenRouter API key not configured")
        }
        let systemPrompt = """
        You are a research assistant. Given a topic, generate \(count) diverse search queries \
        that would comprehensively cover the topic from different angles. \
        Return ONLY a JSON object with a "queries" key containing an array of \(count) strings. \
        No other text. Example: {"queries": ["query 1", "query 2"]}
        """
        let response = try await openRouter.complete(
            systemPrompt: systemPrompt,
            userPrompt: "Topic: \(topic)",
            apiKey: openRouterKey
        )
        guard let data = response.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SubQueryResponse.self, from: data) else {
            return [topic]
        }
        return decoded.queries.isEmpty ? [topic] : decoded.queries
    }

    func searchSubQuery(_ query: String) async throws -> [ExaResult] {
        guard let exaKey = keychain.load(forKey: "keys_exa") else {
            throw GlanceError.keyMissing("Exa API key not configured")
        }
        let request = ExaEnhancedSearchRequest(
            query: query,
            type: "deep-reasoning",
            numResults: 10,
            contentsHighlights: true,
            contentsText: true
        )
        return try await exa.search(request: request, apiKey: exaKey)
    }

    func synthesize(topic: String, results: [ExaResult]) async throws -> String {
        guard let openRouterKey = keychain.load(forKey: "keys_openrouter") else {
            throw GlanceError.keyMissing("OpenRouter API key not configured")
        }
        let resultsText = results.map { "- \($0.title): \($0.highlights.joined(separator: " "))" }.joined(separator: "\n")
        let systemPrompt = """
        You are a research compiler. Synthesize the following search results into a comprehensive, \
        well-structured markdown research document about "\(topic)". \
        Use headers, bullet points, and clear sections. Be factual and cite sources inline. \
        Output ONLY the markdown content, no preamble.
        """
        return try await openRouter.complete(
            systemPrompt: systemPrompt,
            userPrompt: "Search results:\n\(resultsText)",
            apiKey: openRouterKey
        )
    }

    func saveResearch(topic: String, content: String, results: [ExaResult]) async throws -> URL {
        let sources = results.map { (title: $0.title, url: $0.url) }
        return try await markdownStore.save(query: topic, content: content, sources: sources)
    }

    func loadResearchFiles() async -> [ResearchFile] {
        await markdownStore.list()
    }

    func deleteResearchFile(url: URL) async throws {
        try await markdownStore.delete(url: url)
    }

    private func searchCacheKey(_ query: String) -> String {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(normalized.utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "cache_exa_search_\(hex.prefix(16))"
    }

    private func summaryCacheKey(_ query: String) -> String {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(normalized.utf8))
        let hex = hash.map { String(format: "%02x", $0) }.joined()
        return "cache_exa_summary_\(hex.prefix(16))"
    }
}
