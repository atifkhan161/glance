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

        for attempt in 0 ..< 3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    return decoded.candidates?.first?.content?.parts?.first?.text
                }
                if http.statusCode == 429 || http.statusCode == 503 {
                    let delays: [UInt64] = http.statusCode == 429
                        ? [1_000_000_000, 2_000_000_000, 4_000_000_000]
                        : [5_000_000_000, 15_000_000_000, 45_000_000_000]
                    try await Task.sleep(nanoseconds: delays[attempt])
                    continue
                }
                return nil
            } catch {
                if attempt < 2 { try await Task.sleep(nanoseconds: 1_000_000_000) }
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
