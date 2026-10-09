import Foundation

protocol GeminiClientProtocol: Sendable {
    func generate(prompt: String, model: String, apiKey: String) async throws -> String?
}

struct GeminiClient: GeminiClientProtocol, Sendable {
    private static let transport = HTTPTransport(subsystem: "gemini")

    func generate(prompt: String, model: String, apiKey: String) async throws -> String? {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            await recordFailure(model: model, reason: "invalid URL")
            return nil
        }
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
                let (data, _) = try await Self.transport.data(for: request, hint: "model \(model)")
                let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                return decoded.candidates?.first?.content?.parts?.first?.text
            } catch {
                // Degradation is intentional here: callers treat nil as "no summary",
                // so nothing throws. That also means no `catch` site above can see
                // the failure — it has to be recorded explicitly.
                if error is CancellationError { break }
                await recordFailure(model: model, reason: error.logDetail ?? "\(error)")
                let delay = backoffNanoseconds(for: error, attempt: attempt)
                guard delay > 0, attempt < maxAttempts - 1 else { break }
                try await Task.sleep(nanoseconds: delay)
            }
        }
        return nil
    }

    /// Exponential backoff preserved from the pre-transport implementation:
    /// 429 → 1/2/4s, 503 → 5/15/45s. Anything else is not retryable, so the
    /// failure surfaces immediately as nil instead of burning three attempts.
    private func backoffNanoseconds(for error: Error, attempt: Int) -> UInt64 {
        let status: UInt64?
        switch error {
        case GlanceError.rateLimited:
            status = 429
        case GlanceError.httpStatus(503):
            status = 503
        default:
            status = nil
        }
        guard let status else { return 0 }
        let base: UInt64 = status == 429 ? 1 : 5
        let multiplier: UInt64 = status == 429 ? 2 : 3
        return base * UInt64(pow(Double(multiplier), Double(attempt))) * 1_000_000_000
    }

    private func recordFailure(model: String, reason: String) async {
        await AppLog.shared.record(
            .error,
            subsystem: "gemini",
            message: "generation returned nil (model \(model))",
            detail: reason
        )
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
