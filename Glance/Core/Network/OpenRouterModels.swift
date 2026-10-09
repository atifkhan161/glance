import Foundation

/// Shared by the loader (which writes it) and the preference (which reads it).
let openRouterModelsCacheKey = "cache_openrouter_models"

/// A model's reasoning capability, as reported by `/api/v1/models`. Absent on
/// non-reasoning models and on routers, which is itself the signal that there is
/// nothing to disable.
struct OpenRouterReasoning: Codable, Hashable, Sendable {
    var mandatory: Bool?
    var defaultEnabled: Bool?
    var supportedEfforts: [String]?

    enum CodingKeys: String, CodingKey {
        case mandatory
        case defaultEnabled = "default_enabled"
        case supportedEfforts = "supported_efforts"
    }
}

struct OpenRouterModel: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let contextLength: Int
    let promptPrice: String
    let completionPrice: String
    let reasoning: OpenRouterReasoning?

    enum CodingKeys: String, CodingKey {
        case id, name, reasoning
        case contextLength = "context_length"
        case promptPrice = "pricing"
    }

    init(
        id: String,
        name: String,
        contextLength: Int,
        promptPrice: String,
        completionPrice: String,
        reasoning: OpenRouterReasoning? = nil
    ) {
        self.id = id
        self.name = name
        self.contextLength = contextLength
        self.promptPrice = promptPrice
        self.completionPrice = completionPrice
        self.reasoning = reasoning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? id
        contextLength = try container.decodeIfPresent(Int.self, forKey: .contextLength) ?? 0
        let pricing = try container.decodeIfPresent(Pricing.self, forKey: .promptPrice)
        promptPrice = pricing?.prompt ?? "0"
        completionPrice = pricing?.completion ?? "0"
        reasoning = try container.decodeIfPresent(OpenRouterReasoning.self, forKey: .reasoning)
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
        // Round-trips on purpose: the catalog is cached for 24h, and a list encoded
        // before this field existed would otherwise decode with `reasoning == nil`
        // and silently leave reasoning switched on.
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
    }

    private struct Pricing: Codable, Hashable, Sendable {
        let prompt: String
        let completion: String
    }

    /// The model reasons unless told otherwise. Free summarisation models that do
    /// this spend tokens and seconds on a trace whose deltas we discard.
    var thinksByDefault: Bool {
        reasoning?.defaultEnabled == true
    }

    /// A mandatory-reasoning model rejects a disable request outright, so this
    /// has to gate the suppression rather than merely inform it.
    var reasoningIsMandatory: Bool {
        reasoning?.mandatory == true
    }

    /// Whether it is safe to send `reasoning: {enabled: false}` for this model.
    var canDisableReasoning: Bool {
        reasoning != nil && !reasoningIsMandatory
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

    /// The cached catalog, without hitting the network. Empty when the
    /// catalog was never fetched, which `resolveRequest()` treats as unknown.
    static func cachedModels() async -> [OpenRouterModel] {
        guard let envelope: CacheEnvelope<[OpenRouterModel]> = await CacheStore.shared.load(openRouterModelsCacheKey),
              !envelope.isExpired
        else { return [] }
        return envelope.data
    }

    /// What to actually request: the model id, and whether its reasoning trace
    /// should be suppressed.
    struct ResolvedRequest: Sendable, Equatable {
        let id: String
        let disableReasoning: Bool
    }

    /// One cache read instead of two, because the id and the reasoning flag both
    /// come from the same catalog entry.
    ///
    /// An empty catalog means the models have never been fetched, so the stored
    /// choice is trusted and its defaults are left alone — otherwise a cold cache
    /// would downgrade every request to the free router and leave reasoning on.
    static func resolveRequest() async -> ResolvedRequest {
        let models = await cachedModels()
        let selectedID = selected
        guard !models.isEmpty else {
            return ResolvedRequest(id: selectedID, disableReasoning: false)
        }

        let match = models.first { $0.id == selectedID }
        let id = isPinnedRouter || match != nil ? selectedID : freeRouterID
        let disableReasoning = match?.canDisableReasoning == true && match?.thinksByDefault == true

        return ResolvedRequest(id: id, disableReasoning: disableReasoning)
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
            await AppLog.shared.record(
                .error,
                subsystem: "openrouter",
                message: "model list fetch failed",
                error: error
            )
            // A cached list beats an empty picker, so keep whatever loaded already.
            if models.isEmpty { loadError = error.logDetail ?? error.localizedDescription }
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
    ///
    /// `nonisolated` because it is a pure function of its input; the loader itself
    /// is `@MainActor` because it owns observable state.
    nonisolated static func trim(_ models: [OpenRouterModel]) -> [OpenRouterModel] {
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

        let transport = HTTPTransport(session: session, subsystem: "openrouter")
        let (data, _) = try await transport.data(for: request, hint: "model list")
        return try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data).data
    }
}
