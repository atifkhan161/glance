import Foundation

actor IntelligenceRouter {
    private let foundationModels: FoundationModelsClient
    private let geminiClient: any GeminiClientProtocol
    private let keychain: KeychainStore

    /// Caps the article handed to a model so latency stays predictable. Gemini
    /// snippets were already capped; the article paths were not.
    private let maxArticleChars = 12_000

    /// The cloud prompts run over a remote model whose throughput is the bottleneck,
    /// so a smaller slice of the article is worth more than the extra context: the
    /// tail of a 12k-character article rarely changes the 280-word summary, and
    /// every token of it is prefill the user waits through.
    private let maxCloudArticleChars = 8_000

    init(
        foundationModels: FoundationModelsClient = FoundationModelsClient(),
        geminiClient: any GeminiClientProtocol = GeminiClient(),
        keychain: KeychainStore = KeychainStore.shared
    ) {
        self.foundationModels = foundationModels
        self.geminiClient = geminiClient
        self.keychain = keychain
    }

    func enrichMadrid(snippets: String) async -> (RealMadridEnrichment?, String) {
        if await foundationModels.isAvailable(),
           let result = try? await foundationModels.processRealMadrid(snippets: snippets) {
            return (result, "apple")
        }
        #if !targetEnvironment(simulator)
        if let key = keychain.load(forKey: "keys_gemini") {
            let prompt = "Extract Real Madrid match information as JSON {form:[...], standing, intel, headToHead}. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: GeminiModelPreference.selected, apiKey: key),
               let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(RealMadridEnrichment.self, from: data) {
                return (decoded, "gemini")
            }
        }
        #endif
        return (nil, "none")
    }

    func priorityPoGo(snippets: String) async -> (String, String) {
        if await foundationModels.isAvailable(),
           let result = try? await foundationModels.processPoGo(snippets: snippets) {
            return (result.priority, "apple")
        }
        #if !targetEnvironment(simulator)
        if let key = keychain.load(forKey: "keys_gemini") {
            let prompt = "Based on current Pokemon GO raids and events, suggest the top priority target. Return JSON {priority}. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: GeminiModelPreference.selected, apiKey: key),
               let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(PoGoPriority.self, from: data) {
                return (decoded.priority, "gemini")
            }
        }
        #endif
        return ("", "none")
    }

    func briefAiIntel(snippets: String) async -> AiIntelItems? {
        if await foundationModels.isAvailable(),
           let result = try? await foundationModels.processAiIntel(snippets: snippets) {
            return result
        }
        #if !targetEnvironment(simulator)
        if let key = keychain.load(forKey: "keys_gemini") {
            let prompt = "Read these technology news summaries and classify each. Return 2-3 items with tag (FRONTIER LABS or OPEN WEIGHTS), headline, bullets, benchmarks optional. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: GeminiModelPreference.selected, apiKey: key),
               let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(AiIntelItems.self, from: data) {
                return decoded
            }
        }
        #endif
        return nil
    }

    func checkArticleIntelligenceAvailability() async -> (available: Bool, reason: String) {
        await foundationModels.availabilityStatus()
    }

    func articleIntelligence(content: String, type: ArticleIntelligenceType) async -> ArticleIntelligenceResult? {
        guard await foundationModels.isAvailable() else { return nil }
        return try? await foundationModels.summarizeArticle(
            content: truncate(content, maxChars: maxArticleChars),
            prompt: type.systemPrompt
        )
    }

    func streamArticleIntelligence(content: String, type: ArticleIntelligenceType) -> AsyncStream<ArticleStreamEvent> {
        foundationModels.streamSummary(
            content: truncate(content, maxChars: maxArticleChars),
            prompt: type.systemPrompt
        )
    }

    func streamCloudArticleIntelligence(content: String, type: ArticleIntelligenceType) -> AsyncStream<ArticleStreamEvent> {
        AsyncStream { continuation in
            let task = Task {
                guard let apiKey = keychain.load(forKey: "keys_openrouter") else {
                    continuation.yield(.failed(.modelUnavailable("Add an OpenRouter API key in Settings to use cloud summaries.")))
                    continuation.finish()
                    return
                }
                do {
                    let client = OpenRouterClient()
                    let request = await OpenRouterModelPreference.resolveRequest()
                    let stream = client.stream(
                        systemPrompt: type.systemPrompt,
                        userPrompt: truncate(content, maxChars: maxCloudArticleChars),
                        apiKey: apiKey,
                        temperature: 0.4,
                        model: request.id,
                        disableReasoning: request.disableReasoning
                    )

                    let started = Date.now
                    var firstDeltaMs: Int?
                    var charCount = 0

                    for try await delta in stream {
                        if firstDeltaMs == nil { firstDeltaMs = Int(Date.now.timeIntervalSince(started) * 1000) }
                        charCount += delta.count
                        continuation.yield(.delta(delta))
                    }

                    let totalMs = Int(Date.now.timeIntervalSince(started) * 1000)
                    let metrics = "cloud \(request.id) rsn-off=\(request.disableReasoning ? "yes" : "no") "
                        + "first=\(firstDeltaMs.map { "\($0)" } ?? "none")ms "
                        + "total=\(totalMs)ms chars=\(charCount)"
                    await AppLog.shared.record(.info, subsystem: "intelligence", message: metrics)

                    // A stream that ends without ever producing a token is a failure,
                    // not an empty article. Finishing cleanly here made the UI fall
                    // through to "No summary was generated", hiding the real cause.
                    if firstDeltaMs == nil {
                        continuation.yield(.failed(.unknown("The cloud model returned an empty response.")))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.yield(.failed(.cancelled))
                    continuation.finish()
                } catch {
                    await AppLog.shared.record(
                        .error,
                        subsystem: "intelligence",
                        message: "cloud stream failed",
                        error: error
                    )
                    continuation.yield(.failed(Self.mapCloudError(error)))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func mapCloudError(_ error: Error) -> ArticleStreamFailure {
        switch error {
        case GlanceError.unauthorized:
            return .modelUnavailable("OpenRouter rejected the API key. Check it in Settings.")
        case GlanceError.rateLimited:
            return .network("rate limited, try again shortly")
        case GlanceError.networkError(let detail):
            return .network(detail)
        case GlanceError.httpStatus(let code):
            return .network("status \(code)")
        default:
            return .unknown(error.localizedDescription)
        }
    }

    private func truncate(_ text: String, maxChars: Int? = nil) -> String {
        let limit = maxChars ?? 6000
        return text.count > limit ? String(text.prefix(limit)) : text
    }
}
