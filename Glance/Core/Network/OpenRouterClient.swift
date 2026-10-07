import Foundation

/// Decodes OpenAI-compatible `data:` frames. Stateless between events, so each
/// line is handled independently and frames split across reads still decode.
struct OpenRouterStreamDecoder {
    private(set) var isDone = false

    /// - Throws: `GlanceError.networkError` when the provider reports an error
    ///   *inside* the stream. A mid-stream failure arrives as an ordinary `data:`
    ///   frame with an `error` object and no `choices`, so a decoder that only
    ///   understands `choices` drops it silently — the stream then ends "cleanly"
    ///   having produced nothing, and the user is told the summary simply didn't
    ///   exist. Surfacing the real message is the difference between "No summary
    ///   was generated for this article." and an actionable error.
    mutating func consume(line: String) throws -> [String] {
        guard !isDone else { return [] }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data:") else { return [] }

        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
            isDone = true
            return []
        }

        guard let data = payload.data(using: .utf8) else { return [] }

        if let failure = try? JSONDecoder().decode(OpenRouterStreamErrorFrame.self, from: data),
           let message = failure.error?.message {
            throw GlanceError.networkError(message)
        }

        guard let decoded = try? JSONDecoder().decode(OpenRouterStreamChunk.self, from: data),
              let content = decoded.choices.first?.delta.content,
              !content.isEmpty
        else { return [] }

        return [content]
    }
}

private struct OpenRouterStreamErrorFrame: Decodable {
    struct Payload: Decodable {
        let code: String?
        let message: String?
    }

    let error: Payload?
}

struct OpenRouterClient: Sendable {
    /// `max_tokens` is a *ceiling*, not a target: generation stops when the model
    /// emits its stop token, so raising this does not make a model ramble and costs
    /// nothing when reasoning is off.
    ///
    /// It has to leave real headroom, because reasoning tokens are drawn from this
    /// same budget. Measured on `z-ai/glm-5.3` with a 400 ceiling and a trivial
    /// "write a short Python function" prompt, a default-max reasoning model spent
    /// 402 tokens thinking and returned `finish_reason: "length"` with empty
    /// content — while still billing for the reasoning. Our prompts ask for
    /// 280-350 words (~470 tokens) plus `**bold**` markup, so ~600 visible tokens
    /// is a realistic ceiling. Anything below ~1000 truncates a summarisation
    /// prompt the moment a model reasons first.
    private static let maxTokens = 2048

    /// Attempts per request. Two is enough to ride out a single transport blip;
    /// the old three, combined with a 60s timeout, let one bad request occupy the
    /// screen for minutes.
    private static let maxAttempts = 2

    /// Streaming requests get a shorter leash than non-streaming. Once the socket
    /// is open and deltas are arriving, a stall means the model has wedged, not
    /// that the network is slow.
    private static let streamTimeout: TimeInterval = 30

    /// A `Retry-After` longer than this is not worth blocking on. Free-tier
    /// OpenRouter 429s persistently, so waiting out a long one usually just means
    /// the user watches a spinner instead of reading the failure.
    private static let maxRetryAfter: TimeInterval = 5

    func complete(
        systemPrompt: String,
        userPrompt: String,
        apiKey: String,
        temperature: Double = 0.7,
        model: String = OpenRouterModelPreference.legacyDefaultID,
        disableReasoning: Bool = false
    ) async throws -> String {
        let request = makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            apiKey: apiKey,
            temperature: temperature,
            model: model,
            disableReasoning: disableReasoning,
            stream: false
        )

        for attempt in 0 ..< Self.maxAttempts {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GlanceError.networkError("No HTTP response")
            }
            if http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content else {
                    throw GlanceError.networkError("Empty response from OpenRouter")
                }
                return content
            }
            if http.statusCode == 429 {
                guard attempt < Self.maxAttempts - 1,
                      let delay = Self.retryAfterSeconds(http: http),
                      delay <= Self.maxRetryAfter
                else { throw GlanceError.rateLimited(retryAfter: Self.retryAfterSeconds(http: http)) }
                try await Task.sleep(for: .seconds(delay))
                continue
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw GlanceError.unauthorized
            }
            throw GlanceError.httpStatus(http.statusCode)
        }
        throw GlanceError.rateLimited(retryAfter: nil)
    }

    /// Server-sent events, so the cloud path streams like the on-device path
    /// instead of rendering all at once after the full response arrives.
    func stream(
        systemPrompt: String,
        userPrompt: String,
        apiKey: String,
        temperature: Double = 0.4,
        model: String = OpenRouterModelPreference.legacyDefaultID,
        disableReasoning: Bool = false
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = makeRequest(
                        systemPrompt: systemPrompt,
                        userPrompt: userPrompt,
                        apiKey: apiKey,
                        temperature: temperature,
                        model: model,
                        disableReasoning: disableReasoning,
                        stream: true
                    )
                    let bytes = try await openStream(request)

                    var decoder = OpenRouterStreamDecoder()
                    for try await line in bytes.lines {
                        for delta in try decoder.consume(line: line) {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func openStream(_ request: URLRequest) async throws -> URLSession.AsyncBytes {
        for attempt in 0 ..< Self.maxAttempts {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GlanceError.networkError("No HTTP response")
                }
                if http.statusCode == 200 { return bytes }
                if http.statusCode == 429 {
                    // Only wait out a rate limit the provider expects us to wait out.
                    // A long Retry-After on the free tier means "come back much later",
                    // and burning it inline is worse than surfacing the failure.
                    guard attempt < Self.maxAttempts - 1,
                          let delay = Self.retryAfterSeconds(http: http),
                          delay <= Self.maxRetryAfter
                    else { throw GlanceError.rateLimited(retryAfter: Self.retryAfterSeconds(http: http)) }
                    try await Task.sleep(for: .seconds(delay))
                    continue
                }
                if http.statusCode == 401 || http.statusCode == 403 {
                    throw GlanceError.unauthorized
                }
                throw GlanceError.httpStatus(http.statusCode)
            } catch let error as GlanceError {
                throw error
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if attempt < Self.maxAttempts - 1 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }
                throw GlanceError.networkError(error.localizedDescription)
            }
        }
        throw GlanceError.rateLimited(retryAfter: nil)
    }

    private func makeRequest(
        systemPrompt: String,
        userPrompt: String,
        apiKey: String,
        temperature: Double,
        model: String,
        disableReasoning: Bool,
        stream: Bool
    ) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.timeoutInterval = stream ? Self.streamTimeout : 15
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Glance-iOS", forHTTPHeaderField: "HTTP-Referer")

        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "temperature": temperature,
            "max_tokens": Self.maxTokens,
        ]
        if disableReasoning {
            // Summarisation gets no quality benefit from a reasoning trace, and the
            // deltas arrive in `delta.reasoning`, which the decoder ignores — so the
            // user watches a skeleton for the whole trace and then sees the answer
            // arrive at once. Only sent for models that report reasoning and do not
            // require it; a mandatory-reasoning model rejects this with a 400.
            body["reasoning"] = ["enabled": false]
        }
        if stream {
            body["stream"] = true
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Only honors an explicit `Retry-After`. The old fallback invented its own
    /// 2s/4s backoff, which for a free-tier rate limit is just an arbitrary delay
    /// before the same failure.
    private static func retryAfterSeconds(http: HTTPURLResponse) -> Double? {
        guard let raw = http.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return Double(raw)
    }
}

private struct OpenRouterResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}

private struct OpenRouterStreamChunk: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let delta: Delta }
    struct Delta: Decodable { let content: String? }
}
