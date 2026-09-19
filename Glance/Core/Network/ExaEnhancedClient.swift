import Foundation

struct ExaEnhancedSearchRequest {
    let query: String
    let type: String
    let numResults: Int
    let contentsHighlights: Bool
    let contentsText: Bool
    let systemPrompt: String?
    let includeDomains: [String]?

    init(
        query: String,
        type: String = "auto",
        numResults: Int = 10,
        contentsHighlights: Bool = true,
        contentsText: Bool = false,
        systemPrompt: String? = nil,
        includeDomains: [String]? = nil
    ) {
        self.query = query
        self.type = type
        self.numResults = numResults
        self.contentsHighlights = contentsHighlights
        self.contentsText = contentsText
        self.systemPrompt = systemPrompt
        self.includeDomains = includeDomains
    }
}

struct ExaEnhancedClient: Sendable {
    func search(request: ExaEnhancedSearchRequest, apiKey: String) async throws -> [ExaResult] {
        var urlRequest = URLRequest(url: URL(string: "https://api.exa.ai/search")!)
        urlRequest.timeoutInterval = 15
        urlRequest.httpMethod = "POST"
        urlRequest.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [String: Any] = [:]
        if request.contentsHighlights { contents["highlights"] = true }
        if request.contentsText { contents["text"] = true }

        var body: [String: Any] = [
            "query": request.query,
            "type": request.type,
            "numResults": request.numResults,
            "contents": contents,
        ]
        if let sp = request.systemPrompt { body["systemPrompt"] = sp }
        if let domains = request.includeDomains, !domains.isEmpty {
            body["includeDomains"] = domains
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0 ..< 3 {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw GlanceError.networkError("No HTTP response")
            }
            if http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(ExaResponse.self, from: data)
                return decoded.results
            }
            if http.statusCode == 429 {
                let delay: UInt64
                if let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
                   let seconds = Double(retryAfter) {
                    delay = UInt64(seconds * 1_000_000_000)
                } else {
                    delay = attempt == 0 ? 1_000_000_000 : 2_000_000_000
                }
                try await Task.sleep(nanoseconds: delay)
                continue
            }
            throw GlanceError.networkError("Exa search failed with status \(http.statusCode)")
        }
        throw GlanceError.networkError("Exa search failed after retries")
    }
}

