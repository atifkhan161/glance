import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    struct FoundationModelsClient: Sendable {
        private let permissiveModel = SystemLanguageModel(guardrails: .permissiveContentTransformations)

        func isAvailable() async -> Bool {
            if case .available = SystemLanguageModel.default.availability { return true }
            return false
        }

        func availabilityStatus() -> (available: Bool, reason: String) {
            let status = SystemLanguageModel.default.availability
            switch status {
            case .available:
                return (true, "Model ready")
            case .unavailable(.appleIntelligenceNotEnabled):
                return (false, "Enable Apple Intelligence in Settings > General > Apple Intelligence & Siri")
            case .unavailable(.modelNotReady):
                return (false, "Apple Intelligence model is still downloading. Connect to WiFi and try again, or use cloud.")
            case .unavailable(.deviceNotEligible):
                return (false, "This device does not support Apple Intelligence. Use cloud instead.")
            case .unavailable(let other):
                return (false, "Model unavailable: \(other)")
            @unknown default:
                return (false, "Model unavailable")
            }
        }

        func processRealMadrid(snippets: String) async throws -> RealMadridEnrichment {
            let session = LanguageModelSession()
            let prompt = """
            Analyze these Real Madrid related snippets and extract structured data.
            Return JSON with: form (array of recent match results like "W 2-1", "D 1-1"),
            standing (current La Liga position), intel (1-2 sentence tactical summary),
            headToHead (recent record vs opponent if mentioned).
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
            if case .available = SystemLanguageModel.default.availability { return true }
            return false
        }

        func summarizeArticle(content: String, prompt: String) async throws -> ArticleIntelligenceResult {
            let session = LanguageModelSession()
            let fullPrompt = "\(prompt)\n\nArticle:\n\(content)"
            return try await session.respond(to: fullPrompt, generating: ArticleIntelligenceResult.self).content
        }

        func streamSummary(content: String, prompt: String) -> AsyncStream<ArticleStreamEvent> {
            let session = LanguageModelSession(model: permissiveModel)
            let fullPrompt = "\(prompt)\n\nArticle:\n\(content)"
            return AsyncStream { continuation in
                Task {
                    do {
                        var lastLength = 0
                        for try await snapshot in session.streamResponse(to: fullPrompt) {
                            let text = snapshot.content
                            if text.count > lastLength {
                                let delta = String(text.dropFirst(lastLength))
                                continuation.yield(.delta(delta))
                                lastLength = text.count
                            }
                        }
                        continuation.finish()
                    } catch {
                        NSLog("[AI] streamSummary error: %@", "\(error)")
                        continuation.yield(.failed(Self.mapStreamError(error)))
                        continuation.finish()
                    }
                }
            }
        }

        private static func mapStreamError(_ error: Error) -> ArticleStreamFailure {
            if error is CancellationError { return .cancelled }
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return .cancelled }

            if #available(iOS 27.0, *) {
                if let modelError = error as? LanguageModelError {
                    switch modelError {
                    case .contextSizeExceeded:
                        return .exceededContextSize
                    case .guardrailViolation, .refusal, .unsupportedTranscriptContent:
                        return .guardrail
                    case .rateLimited:
                        return .rateLimited
                    default:
                        return .unknown(error.localizedDescription)
                    }
                }
            }

            if let generation = error as? LanguageModelSession.GenerationError {
                switch generation {
                case .exceededContextWindowSize:
                    return .exceededContextSize
                case .guardrailViolation:
                    return .guardrail
                case .refusal:
                    return .refusal
                case .rateLimited:
                    return .rateLimited
                default:
                    return .unknown(error.localizedDescription)
                }
            }

            return .unknown(error.localizedDescription)
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
            (false, "Foundation Models not available on this device. Use cloud instead.")
        }

        func summarizeArticle(content: String, prompt: String) async throws -> ArticleIntelligenceResult {
            throw GlanceError.notConfigured("Foundation Models unavailable on this device")
        }

        func streamSummary(content: String, prompt: String) -> AsyncStream<ArticleStreamEvent> {
            AsyncStream { continuation in
                continuation.yield(.failed(.modelUnavailable("Foundation Models not available on this device. Use cloud instead.")))
                continuation.finish()
            }
        }
    }
#endif
