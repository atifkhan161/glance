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

private actor ExaCacheStore {
    static let shared = ExaCacheStore()
    
    private var cache: [String: (results: [ExaResult], timestamp: Date)] = [:]
    private let ttl: TimeInterval = 300 // 5 minutes
    
    func get(_ key: String) -> [ExaResult]? {
        guard let cached = cache[key],
              Date.now.timeIntervalSince(cached.timestamp) < ttl else {
            return nil
        }
        return cached.results
    }
    
    func set(_ key: String, results: [ExaResult]) {
        cache[key] = (results: results, timestamp: Date.now)
    }
    
    func clear() {
        cache.removeAll()
    }
}

struct ExaClient: ExaClientProtocol, Sendable {
    private let cacheStore = ExaCacheStore.shared
    
    func search(query: String, apiKey: String) async throws -> [ExaResult] {
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first (deduplication)
        if let cached = await cacheStore.get(cacheKey) {
            return cached
        }
        
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

        for attempt in 0 ..< 3 {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GlanceError.networkError("No HTTP response")
            }
            if http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(ExaResponse.self, from: data)
                await cacheStore.set(cacheKey, results: decoded.results)
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
    
    func clearCache() async {
        await cacheStore.clear()
    }
}

private struct ExaResponse: Codable {
    let results: [ExaResult]
}
