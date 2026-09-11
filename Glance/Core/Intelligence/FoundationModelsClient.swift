import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    struct FoundationModelsClient: Sendable {
        func isAvailable() async -> Bool {
            SystemLanguageModel.default.isAvailable
        }

        func processRealMadrid(snippets: String) async throws -> RealMadridEnrichment {
            let session = LanguageModelSession()
            let prompt = """
            Analyze these Real Madrid related snippets and extract structured data.
            Return JSON with: form (array of recent match results like "W 2-1", "D 1-1"),
            standing (current La Liga position), intel (1-2 sentence tactical summary),
            head_to_head (recent record vs opponent if mentioned).
            Snippets: \(snippets)
            """
            return try await session.respond(to: prompt, generating: RealMadridEnrichment.self).content
        }

        func processPoGo(snippets: String) async throws -> PoGoPriority {
            let session = LanguageModelSession()
            let prompt = """
            From these Pokemon GO raid/event snippets, determine the top priority target.
            Consider: rarity, Shiny availability, meta relevance, time-limited status.
            Return JSON with: priority (one sentence explaining the top target and why).
            Snippets: \(snippets)
            """
            return try await session.respond(to: prompt, generating: PoGoPriority.self).content
        }

        func processAiIntel(snippets: String) async throws -> AiIntelItems {
            let session = LanguageModelSession()
            let prompt = """
            Read these AI/ML news summaries. For each significant item:
            1. Classify as "FRONTIER LABS" (OpenAI, Anthropic, Google, Meta, etc.) or "OPEN WEIGHTS" (community/open-source)
            2. Write a concise headline
            3. Add 1-2 bullet points with key details
            4. Optionally include benchmark results if mentioned
            Return 2-3 items sorted by significance.
            Snippets: \(snippets)
            """
            return try await session.respond(to: prompt, generating: AiIntelItems.self).content
        }
    }
#else
    struct FoundationModelsClient: Sendable {
        func isAvailable() async -> Bool { false }

        func processRealMadrid(snippets: String) async throws -> RealMadridEnrichment {
            throw GlanceError.notConfigured("Foundation Models unavailable on this device")
        }

        func processPoGo(snippets: String) async throws -> PoGoPriority {
            throw GlanceError.notConfigured("Foundation Models unavailable on this device")
        }

        func processAiIntel(snippets: String) async throws -> AiIntelItems {
            throw GlanceError.notConfigured("Foundation Models unavailable on this device")
        }
    }
#endif
