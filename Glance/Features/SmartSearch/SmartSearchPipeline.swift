import Foundation
import CryptoKit

struct SmartSearchPipeline: Sendable {
    private let exa = ExaEnhancedClient()
    private let openRouter = OpenRouterClient()
    private let keychain = KeychainStore.shared
    private let cache = CacheStore.shared

    func quickSearch(query: String, includeDomains: [String]? = nil) async throws -> [ExaResult] {
        let cacheKey = searchCacheKey(query, domains: includeDomains)

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
            contentsText: includeDomains != nil,
            includeDomains: includeDomains
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
            let content = result.highlights.isEmpty ? (result.text ?? "") : result.highlights.prefix(3).joined(separator: " ")
            return "[\(index + 1)] \(result.title): \(content)"
        }.joined(separator: "\n\n")

        let systemPrompt = """
        The user searched for "\(query)". From these results, extract: \
        (1) the key finding, (2) why it matters, (3) any consensus or disagreement. \
        Use **bold** for critical facts. Be direct — skip introductions and opinions.
        """
        let resolved = await OpenRouterModelPreference.resolveRequest()
        let summary = try await openRouter.complete(
            systemPrompt: systemPrompt,
            userPrompt: "Query: \(query)\n\nSearch results:\n\(combinedHighlights)",
            apiKey: openRouterKey,
            temperature: 0.4,
            model: resolved.id,
            disableReasoning: resolved.disableReasoning
        )

        await cache.save(cacheKey, envelope: CacheEnvelope(data: summary, ttlMs: 24 * 3_600 * 1000))
        return summary
    }

    private func searchCacheKey(_ query: String, domains: [String]?) -> String {
        let normalized = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let domainPart = domains?.sorted().joined(separator: ",") ?? ""
        let combined = "\(normalized)|\(domainPart)"
        let hash = SHA256.hash(data: Data(combined.utf8))
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
