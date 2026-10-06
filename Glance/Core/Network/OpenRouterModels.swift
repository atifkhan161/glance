import Foundation

/// Shared by the loader (which writes it) and the preference (which reads it).
let openRouterModelsCacheKey = "cache_openrouter_models"

struct OpenRouterModel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let contextLength: Int
    let promptPrice: String
    let completionPrice: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case contextLength = "context_length"
        case promptPrice = "pricing"
    }

    init(id: String, name: String, contextLength: Int, promptPrice: String, completionPrice: String) {
        self.id = id
        self.name = name
        self.contextLength = contextLength
        self.promptPrice = promptPrice
        self.completionPrice = completionPrice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength) ?? 0
        let pricing = try container.decodeIfPresent(Pricing.self, forKey: .promptPrice)
        promptPrice = pricing?.prompt ?? "0"
        completionPrice = pricing?.completion ?? "0"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(contextLength, forKey: .contextLength)
        try container.encode(
            Pricing(prompt: promptPrice, completion: completionPrice),
            forKey: .promptPrice
        )
    }

    private struct Pricing: Codable, Hashable, Sendable {
        let prompt: String
        let completion: String
    }

    /// Priced by `pricing` rather than the `:free` suffix: some zero-cost entries
    /// ship without the suffix, and stripping it would misfile them as paid.
    var isFree: Bool {
        promptPrice == "0" && completionPrice == "0"
    }

    /// OpenRouter reports `-1` rather than a price for routers and other entries
    /// that have no billable rate. Those are unusable as a summary target.
    var hasRealPrice: Bool {
        let prompt = Double(promptPrice) ?? 0
        let completion = Double(completionPrice) ?? 0
        return prompt >= 0 && completion >= 0
    }

    var contextLabel: String {
        guard contextLength > 0 else { return "—" }
        if contextLength >= 1_000_000 {
            return String(format: "%.1fM", Double(contextLength) / 1_000_000)
        }
        return "\(contextLength / 1024)K"
    }

    var priceLabel: String {
        guard !isFree, let price = Double(promptPrice) else { return "Free" }
        let perMillion = price * 1_000_000
        if perMillion < 0.01 { return "<$0.01/Mtok" }
        return String(format: "$%.2f/Mtok", perMillion)
    }
}

struct OpenRouterModelsResponse: Codable, Sendable {
    let data: [OpenRouterModel]
}

enum OpenRouterModelPreference {
    /// Picks a free model per request. Always valid, never appears in the catalog.
    static let freeRouterID = "openrouter/free"
    /// The pre-picker default, pinned in the UI rather than listed.
    ///
    /// `openrouter/free` picks a free model *at random*, and free-tier throughput
    /// spans roughly three orders of magnitude — some models run at 4k tok/s, others
    /// at single digits, and some never produce output at all. The `:nitro` variant
    /// ranks the free tier by measured throughput and routes to the fastest model
    /// available, so this default is the difference between a summary in a couple of
    /// seconds and a spinner that times out. `:floor` (the old default) sorts by
    /// price instead, which picks the slowest provider every time.
    ///
    /// Must never trigger the unavailable-model fallback, because a routing variant
    /// is deliberately absent from the catalog.
    static let legacyDefaultID = "openrouter/free:nitro"

    private static let defaultsKey = "openrouter_model"

    static var selected: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? legacyDefaultID }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    static var isPinnedRouter: Bool {
        selected == legacyDefaultID || selected == freeRouterID
    }

    /// The id to actually send. A stored model that has rotated out of the catalog
    /// degrades to the free router instead of failing the request.
    ///
    /// An empty `availableIDs` means the catalog has not been fetched yet, so the
    /// stored choice is trusted — otherwise a cold cache would silently downgrade
    /// every request to the free router.
    static func resolve(availableIDs: Set<String>) -> String {
        let model = selected
        guard !isPinnedRouter, !availableIDs.isEmpty else { return model }
        return availableIDs.contains(model) ? model : freeRouterID
    }

    /// The available ids from cache, without hitting the network. Empty when the
    /// catalog was never fetched, which `resolve(availableIDs:)` treats as unknown.
    static func cachedAvailableIDs() async -> Set<String> {
        guard let envelope: CacheEnvelope<[OpenRouterModel]> = await CacheStore.shared.load(openRouterModelsCacheKey),
              !envelope.isExpired
        else { return [] }
        return Set(envelope.data.map { $0.id })
    }
}

@MainActor
@Observable
final class OpenRouterModelsLoader {
    private(set) var models: [OpenRouterModel] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    private let client: OpenRouterModelsClient
    private let cache: CacheStore

    init(
        client: OpenRouterModelsClient = .live,
        cache: CacheStore = .shared
    ) {
        self.client = client
        self.cache = cache
    }

    var availableIDs: Set<String> {
        Set(models.map { $0.id })
    }

    var freeModels: [OpenRouterModel] {
        models.filter(\.isFree).sorted { $0.name < $1.name }
    }

    /// Cheapest first, compared numerically on the prompt price. OpenRouter returns
    /// prices as decimal strings, so they must not be sorted lexicographically —
    /// that would put "0.0000001" ahead of "0.002".
    var paidModels: [OpenRouterModel] {
        let paid: [OpenRouterModel] = models.filter { model in !model.isFree }
        return paid.sorted { lhs, rhs in
            numericPrice(lhs.promptPrice) < numericPrice(rhs.promptPrice)
        }
    }

    private func numericPrice(_ raw: String) -> Double {
        Double(raw) ?? .infinity
    }

    /// The stored model, if it is absent from the last successful fetch.
    var unavailableModelID: String? {
        guard !models.isEmpty, !OpenRouterModelPreference.isPinnedRouter else { return nil }
        let selected = OpenRouterModelPreference.selected
        return availableIDs.contains(selected) ? nil : selected
    }

    func load(force: Bool = false) async {
        if !force,
           let cached: CacheEnvelope<[OpenRouterModel]> = await cache.load(openRouterModelsCacheKey),
           !cached.isExpired {
            apply(cached.data)
            return
        }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            let fetched = try await client.fetchModels()
            let trimmed = Self.trim(fetched)
            apply(trimmed)
            await cache.save(
                openRouterModelsCacheKey,
                envelope: CacheEnvelope(data: trimmed, ttlMs: Int64(cache.ttl(for: openRouterModelsCacheKey) * 1000))
            )
        } catch {
            // A cached list beats an empty picker, so keep whatever loaded already.
            if models.isEmpty { loadError = error.localizedDescription }
        }
    }

    func select(_ model: OpenRouterModel) {
        OpenRouterModelPreference.selected = model.id
    }

    func selectPinnedRouter() {
        OpenRouterModelPreference.selected = OpenRouterModelPreference.legacyDefaultID
    }

    private func apply(_ models: [OpenRouterModel]) {
        self.models = models
    }

    /// Drops entries that are not fixed, text-generating models.
    ///
    /// - The `openrouter/` namespace holds routers rather than models; the free
    ///   router is pinned as its own row instead of being listed.
    /// - OpenRouter encodes "no real price" as `-1` (Jev Router, Switchyard, the
    ///   `auto` family). Left in, those sort to the top of the paid section and
    ///   render as `-$1000000.00/Mtok`.
    static func trim(_ models: [OpenRouterModel]) -> [OpenRouterModel] {
        models.filter { model in
            guard model.id.contains("/"), !model.id.hasPrefix("openrouter/") else { return false }
            return model.hasRealPrice
        }
    }
}

struct OpenRouterModelsClient: Sendable {
    var session: URLSession = .shared

    static let live = OpenRouterModelsClient()

    /// `/api/v1/models` is public, so the picker populates before a key is entered.
    func fetchModels() async throws -> [OpenRouterModel] {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        request.timeoutInterval = 20
        request.httpMethod = "GET"
        request.addValue("Glance-iOS", forHTTPHeaderField: "HTTP-Referer")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlanceError.networkError("No HTTP response")
        }
        guard http.statusCode == 200 else {
            throw GlanceError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data).data
    }
}
