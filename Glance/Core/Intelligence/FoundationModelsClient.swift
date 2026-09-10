import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    struct FoundationModelsClient: Sendable {
        func isAvailable() async -> Bool {
            SystemLanguageModel.default.isAvailable
        }

        func processRealMadrid(snippets: String) async throws -> RealMadridEnrichment {
            let session = LanguageModelSession()
            let prompt = "Extract Real Madrid enrichment (recent form results, La Liga standing, tactical intel summary, head-to-head record) from these snippets: \(snippets)"
            return try await session.respond(to: prompt, generating: RealMadridEnrichment.self).content
        }

        func processPoGo(snippets: String) async throws -> PoGoPriority {
            let session = LanguageModelSession()
            let prompt = "From these Pokemon GO raid/event snippets, write one sentence naming the top priority raid target and why: \(snippets)"
            return try await session.respond(to: prompt, generating: PoGoPriority.self).content
        }

        func processAiIntel(snippets: String) async throws -> AiIntelItems {
            let session = LanguageModelSession()
            let prompt = "Read these technology news summaries and for each one, classify it as coming from a major research lab or an open-source community project. Return 2-3 items with a short headline and 1-2 bullet points summarizing the key detail. Snippets: \(snippets)"
            return try await session.respond(to: prompt, generating: AiIntelItems.self).content
        }
    }
#else
    struct FoundationModelsClient: Sendable {
        func isAvailable() async -> Bool { false }

        func processRealMadrid(snippets: String) async throws -> RealMadridEnrichment {
            throw GlanceError.notConfigured("Foundation Models unavailable")
        }

        func processPoGo(snippets: String) async throws -> PoGoPriority {
            throw GlanceError.notConfigured("Foundation Models unavailable")
        }

        func processAiIntel(snippets: String) async throws -> AiIntelItems {
            throw GlanceError.notConfigured("Foundation Models unavailable")
        }
    }
#endif
