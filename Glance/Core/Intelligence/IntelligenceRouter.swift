import Foundation

actor IntelligenceRouter {
    private let foundationModels: FoundationModelsClient
    private let geminiClient: any GeminiClientProtocol
    private let keychain: KeychainStore

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
        if let key = keychain.load(forKey: "keys_gemini"),
           let model = keychain.load(forKey: "gemini_model") {
            let prompt = "Extract Real Madrid match information as JSON {form:[...], standing, intel, head_to_head}. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: model, apiKey: key),
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
        if let key = keychain.load(forKey: "keys_gemini"),
           let model = keychain.load(forKey: "gemini_model") {
            let prompt = "Based on current Pokemon GO raids and events, suggest the top priority target. Return JSON {priority}. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: model, apiKey: key),
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
        if let key = keychain.load(forKey: "keys_gemini"),
           let model = keychain.load(forKey: "gemini_model") {
            let prompt = "Read these technology news summaries and classify each. Return 2-3 items with tag (FRONTIER LABS or OPEN WEIGHTS), headline, bullets, benchmarks optional. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: model, apiKey: key),
               let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(AiIntelItems.self, from: data) {
                return decoded
            }
        }
        #endif
        return nil
    }

    func checkArticleIntelligenceAvailability() async -> (available: Bool, reason: String) {
        let result = await foundationModels.availabilityStatus()
        NSLog("[AI][Router] checkAvailability — available: %@, reason: %@", result.available ? "YES" : "NO", result.reason)
        return result
    }

    func articleIntelligence(content: String, type: ArticleIntelligenceType) async -> ArticleIntelligenceResult? {
        let available = await foundationModels.isAvailable()
        NSLog("[AI][Router] articleIntelligence — available: %@, type: %@, content: %d chars", available ? "YES" : "NO", "\(type)", content.count)
        guard available else { return nil }
        return try? await foundationModels.summarizeArticle(content: content, prompt: type.systemPrompt)
    }

    func streamArticleIntelligence(content: String, type: ArticleIntelligenceType) -> AsyncStream<String> {
        NSLog("[AI][Router] streamArticleIntelligence — type: %@, content: %d chars", "\(type)", content.count)
        return foundationModels.streamSummary(content: content, prompt: type.systemPrompt)
    }

    private func truncate(_ text: String, maxChars: Int = 6000) -> String {
        text.count > maxChars ? String(text.prefix(maxChars)) : text
    }
}
