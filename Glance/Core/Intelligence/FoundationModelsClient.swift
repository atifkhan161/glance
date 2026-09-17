import Foundation

#if canImport(FoundationModels)
    import FoundationModels

    struct FoundationModelsClient: Sendable {
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
            let session = LanguageModelSession()
            let fullPrompt = "\(prompt)\n\nArticle:\n\(content)"
            return AsyncStream { continuation in
                Task {
                    #if DEBUG
                    let status = SystemLanguageModel.default.availability
                    switch status {
                    case .available:
                        print("[FM] Model available, starting stream")
                    case .unavailable(let reason):
                        print("[FM] Model unavailable: \(reason)")
                    @unknown default:
                        print("[FM] Model unknown state")
                    }
                    #endif
                    do {
                        var currentSections: [String: String] = [:]
                        for try await partial in session.streamResponse(to: fullPrompt, generating: ArticleIntelligenceResult.self) {
                            guard let sections = partial.content.sections else { continue }
                            for section in sections {
                                guard let key = section.title, let newContent = section.content else { continue }
                                if let existing = currentSections[key], newContent.count > existing.count {
                                    let delta = String(newContent.dropFirst(existing.count))
                                    continuation.yield(delta)
                                    currentSections[key] = newContent
                                } else if currentSections[key] == nil {
                                    currentSections[key] = newContent
                                    continuation.yield(newContent)
                                }
                            }
                        }
                        continuation.finish()
                    } catch {
                        #if DEBUG
                        print("[FM] streamSummary error: \(error.localizedDescription)")
                        #endif
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
