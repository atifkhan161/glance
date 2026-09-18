import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    struct FoundationModelsClient: Sendable {
        private let permissiveModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)

        func isAvailable() async -> Bool {
            SystemLanguageModel.default.isAvailable
        }

        func availabilityStatus() -> (available: Bool, reason: String) {
            let status = SystemLanguageModel.default.availability
            switch status {
            case .available:
                return (true, "Model ready")
            case .unavailable(.appleIntelligenceNotEnabled):
                return (false, "Enable Apple Intelligence in Settings > General > Apple Intelligence & Siri")
            case .unavailable(.modelNotReady):
                return (false, "Model downloading. Connect to WiFi and wait a few minutes")
            case .unavailable(.deviceNotEligible):
                return (false, "Device does not support Apple Intelligence")
            case .unavailable(let other):
                return (false, "Model unavailable: \(other)")
            @unknown default:
                return (false, "Unknown state")
            }
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

        func isAvailableSync() -> Bool {
            SystemLanguageModel.default.isAvailable
        }

        func summarizeArticle(content: String, prompt: String) async throws -> ArticleIntelligenceResult {
            let session = LanguageModelSession()
            let fullPrompt = "\(prompt)\n\nArticle:\n\(content)"
            return try await session.respond(to: fullPrompt, generating: ArticleIntelligenceResult.self).content
        }

        func streamSummary(content: String, prompt: String) -> AsyncStream<String> {
            let session = LanguageModelSession(model: permissiveModel)
            let fullPrompt = "\(prompt)\n\nArticle:\n\(content)"
            NSLog("[AI][FM] streamSummary — prompt: %d chars, content: %d chars (permissive mode)", prompt.count, content.count)
            return AsyncStream { continuation in
                Task {
                    let status = permissiveModel.availability
                    NSLog("[AI][FM] permissiveModel availability: %@", "\(status)")

                    do {
                        NSLog("[AI][FM] Calling streamResponse (String mode, no @Generable)...")
                        var lastLength = 0
                        var partialCount = 0
                        for try await snapshot in session.streamResponse(to: fullPrompt) {
                            partialCount += 1
                            let text = snapshot.content
                            if text.count > lastLength {
                                let delta = String(text.dropFirst(lastLength))
                                continuation.yield(delta)
                                lastLength = text.count
                            }
                            if partialCount <= 3 || partialCount % 10 == 0 {
                                NSLog("[AI][FM] partial #%d — text: %d chars", partialCount, text.count)
                            }
                        }
                        NSLog("[AI][FM] Stream done — %d partials, total: %d chars", partialCount, lastLength)
                        if partialCount == 0 {
                            NSLog("[AI][FM] ZERO partials — streamResponse returned nothing")
                        }
                        continuation.finish()
                    } catch {
                        NSLog("[AI][FM] ERROR: %@", "\(error)")
                        NSLog("[AI][FM] error type: %@", "\(type(of: error))")
                        continuation.finish()
                    }
                }
            }
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

        func isAvailableSync() -> Bool { false }

        func availabilityStatus() -> (available: Bool, reason: String) {
            (false, "Foundation Models not available on this device")
        }

        func summarizeArticle(content: String, prompt: String) async throws -> ArticleIntelligenceResult {
            throw GlanceError.notConfigured("Foundation Models unavailable on this device")
        }

        func streamSummary(content: String, prompt: String) -> AsyncStream<String> {
            AsyncStream { $0.finish() }
        }
    }
#endif
