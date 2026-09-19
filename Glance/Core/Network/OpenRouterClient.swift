import Foundation

struct OpenRouterClient: Sendable {
    func complete(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.timeoutInterval = 15
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Glance-iOS", forHTTPHeaderField: "HTTP-Referer")

        let body: [String: Any] = [
            "model": "openrouter/free:floor",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "temperature": 0.7,
            "max_tokens": 512,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
                let delay: UInt64
                if let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
                   let seconds = Double(retryAfter) {
                    delay = UInt64(seconds * 1_000_000_000)
                } else {
                    delay = attempt == 0 ? 2_000_000_000 : 4_000_000_000
                }
                try await Task.sleep(nanoseconds: delay)
                continue
            }
            throw GlanceError.networkError("OpenRouter failed with status \(http.statusCode)")
        }
        throw GlanceError.networkError("OpenRouter failed after retries")
    }
}

private struct OpenRouterResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}
