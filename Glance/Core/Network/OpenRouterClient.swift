import Foundation

/// Decodes OpenAI-compatible `data:` frames. Stateless between events, so each
/// line is handled independently and frames split across reads still decode.
struct OpenRouterStreamDecoder {
    private(set) var isDone = false

    mutating func consume(line: String) -> [String] {
        guard !isDone else { return [] }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data:") else { return [] }

        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" {
            isDone = true
            return []
        }

        guard let data = payload.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(OpenRouterStreamChunk.self, from: data),
              let content = decoded.choices.first?.delta.content,
              !content.isEmpty
        else { return [] }

        return [content]
    }
}

struct OpenRouterClient: Sendable {
    private static let maxTokens = 2048

    func complete(
        systemPrompt: String,
        userPrompt: String,
        apiKey: String,
        temperature: Double = 0.7,
        model: String = OpenRouterModelPreference.legacyDefaultID
    ) async throws -> String {
        let request = makeRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            apiKey: apiKey,
            temperature: temperature,
            model: model,
            stream: false
        )

        for attempt in 0 ..< 3 {
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
                try await Task.sleep(nanoseconds: retryDelay(http: http, attempt: attempt))
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
        model: String = OpenRouterModelPreference.legacyDefaultID
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
                        stream: true
                    )
                    let bytes = try await openStream(request)

                    var decoder = OpenRouterStreamDecoder()
                    for try await line in bytes.lines {
                        for delta in decoder.consume(line: line) {
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
        for attempt in 0 ..< 3 {
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GlanceError.networkError("No HTTP response")
                }
                if http.statusCode == 200 { return bytes }
                if http.statusCode == 429 {
                    try await Task.sleep(nanoseconds: retryDelay(http: http, attempt: attempt))
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
                if attempt < 2 {
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
        stream: Bool
    ) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.timeoutInterval = stream ? 60 : 15
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
        if stream {
            body["stream"] = true
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func retryDelay(http: HTTPURLResponse, attempt: Int) -> UInt64 {
        if let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter) {
            return UInt64(seconds * 1_000_000_000)
        }
        return attempt == 0 ? 2_000_000_000 : 4_000_000_000
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
