import Foundation

protocol GeminiClientProtocol: Sendable {
    func generate(prompt: String, model: String, apiKey: String) async throws -> String?
}

struct GeminiClient: GeminiClientProtocol, Sendable {
    func generate(prompt: String, model: String, apiKey: String) async throws -> String? {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let maxAttempts = 3
        for attempt in 0 ..< maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                
                if http.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    return decoded.candidates?.first?.content?.parts?.first?.text
                }
                
                // Parse Retry-After header for 429/503
                let delay: UInt64
                if http.statusCode == 429 || http.statusCode == 503 {
                    if let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
                       let seconds = Double(retryAfter) {
                        delay = UInt64(seconds * 1_000_000_000)
                    } else {
                        // Exponential backoff: 429 -> 1/2/4s, 503 -> 5/15/45s
                        let base: UInt64 = http.statusCode == 429 ? 1 : 5
                        let multiplier: UInt64 = http.statusCode == 429 ? 2 : 3
                        delay = base * UInt64(pow(Double(multiplier), Double(attempt))) * 1_000_000_000
                    }
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                
                // Other errors: return nil (don't throw, let caller handle gracefully)
                return nil
            } catch {
                // Network error: retry with 1s delay
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
        return nil
    }
}

private struct GeminiResponse: Codable {
    let candidates: [Candidate]?
}

private struct Candidate: Codable {
    let content: Content?
}

private struct Content: Codable {
    let parts: [Part]?
}

private struct Part: Codable {
    let text: String?
}
