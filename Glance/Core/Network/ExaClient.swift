import Foundation

protocol ExaClientProtocol: Sendable {
    func search(query: String, apiKey: String) async throws -> [ExaResult]
}

struct ExaResult: Codable, Sendable {
    let title: String
    let url: String
    let text: String?
    let highlights: [String]
    let image: String?
    let publishedDate: String?
    let source: String?

    init(
        title: String,
        url: String,
        text: String? = nil,
        highlights: [String] = [],
        image: String? = nil,
        publishedDate: String? = nil,
        source: String? = nil
    ) {
        self.title = title
        self.url = url
        self.text = text
        self.highlights = highlights
        self.image = image
        self.publishedDate = publishedDate
        self.source = source
    }
}

struct ExaClient: ExaClientProtocol, Sendable {
    func search(query: String, apiKey: String) async throws -> [ExaResult] {
        var request = URLRequest(url: URL(string: "https://api.exa.ai/search")!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "query": query,
            "type": "auto",
            "contents": ["highlights": true],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GlanceError.networkError("Exa search failed")
        }
        let decoded = try JSONDecoder().decode(ExaResponse.self, from: data)
        return decoded.results
    }
}

private struct ExaResponse: Codable {
    let results: [ExaResult]
}
