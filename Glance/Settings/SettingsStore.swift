import Foundation

enum ApiKey: String, CaseIterable, Hashable, Sendable {
    case exa = "keys_exa"
    case gemini = "keys_gemini"
    case openRouter = "keys_openrouter"

    var displayName: String {
        switch self {
        case .exa: "Exa"
        case .gemini: "Gemini"
        case .openRouter: "OpenRouter"
        }
    }
}

@Observable
@MainActor
final class SettingsStore {
    var exaAPIKey: String = ""
    var geminiAPIKey: String = ""
    var openrouterAPIKey: String = ""

    private(set) var storedKeys: Set<ApiKey> = []

    var selectedModel: String {
        get { GeminiModelPreference.selected }
        set { GeminiModelPreference.selected = newValue }
    }

    var leadCard: String {
        get { defaults.string(forKey: "leadCard") ?? "" }
        set { defaults.set(newValue, forKey: "leadCard") }
    }

    var cardOrder: [String] {
        get {
            guard let data = defaults.data(forKey: "cardOrder"),
                  let order = try? JSONDecoder().decode([String].self, from: data) else {
                return defaultCardOrder
            }
            return normalizeCardOrder(order)
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "cardOrder")
            }
        }
    }

    var defaultCardOrder: [String] {
        CardID.allCases.map(\.rawValue) + customRSSFeeds.filter(\.isEnabled).map { Self.customOrderPrefix + $0.id.uuidString }
    }

    static let customOrderPrefix = "custom:"

    func normalizeCardOrder(_ order: [String]) -> [String] {
        let providerIDs = Set(CardID.allCases.map(\.rawValue))
        let feedIDs = Set(customRSSFeeds.map { Self.customOrderPrefix + $0.id.uuidString })
        let known = providerIDs.union(feedIDs)
        var seen = Set<String>()
        var result = order.filter { known.contains($0) && seen.insert($0).inserted }
        for id in defaultCardOrder where !seen.contains(id) {
            result.append(id)
            seen.insert(id)
        }
        return result
    }

    func appendFeedToCardOrder(_ feed: CustomRSSFeed) {
        var order = cardOrder
        order.append(Self.customOrderPrefix + feed.id.uuidString)
        cardOrder = order
    }

    func removeFeedFromCardOrder(feedID: String) {
        cardOrder = cardOrder.filter { $0 != Self.customOrderPrefix + feedID }
    }

    var showMadrid: Bool {
        get { defaults.object(forKey: "showMadrid") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showMadrid") }
    }

    var showPoGo: Bool {
        get { defaults.object(forKey: "showPoGo") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showPoGo") }
    }

    var showGithub: Bool {
        get { defaults.object(forKey: "showGithub") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showGithub") }
    }

    var showAiIntel: Bool {
        get { defaults.object(forKey: "showAiIntel") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showAiIntel") }
    }

    /// Which backend a new article summary starts on. `false` prefers on-device
    /// Foundation Models and only reaches for OpenRouter when the user escalates,
    /// which is also why the default is local — cloud needs a key and is slower.
    var cloudSummariesByDefault: Bool {
        get { defaults.object(forKey: "cloud_summaries_default") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "cloud_summaries_default") }
    }

    // MARK: - Provider URLs

    var madridRSSURL: String {
        get { defaults.string(forKey: "madrid_rss_url") ?? "https://www.managingmadrid.com/rss/index.xml" }
        set { defaults.set(newValue, forKey: "madrid_rss_url") }
    }

    var madridTeamID: String {
        get { defaults.string(forKey: "madrid_team_id") ?? "133738" }
        set { defaults.set(newValue, forKey: "madrid_team_id") }
    }

    var madridLeagueID: String {
        get { defaults.string(forKey: "madrid_league_id") ?? "4335" }
        set { defaults.set(newValue, forKey: "madrid_league_id") }
    }

    var madridSelectedTeam: FootballTeam {
        get {
            FootballData.team(byID: madridTeamID) ?? FootballData.topChampionsLeagueTeams[0]
        }
        set {
            madridTeamID = newValue.id
            madridLeagueID = newValue.leagueID
        }
    }

    var pogoRaidsURL: String {
        get { defaults.string(forKey: "pogo_raids_url") ?? "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json" }
        set { defaults.set(newValue, forKey: "pogo_raids_url") }
    }

    var pogoEventsURL: String {
        get { defaults.string(forKey: "pogo_events_url") ?? "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json" }
        set { defaults.set(newValue, forKey: "pogo_events_url") }
    }

    var pogoTimeZone: PoGoTimeZone {
        get { PoGoTimeZone.stored }
        set { PoGoTimeZone.store(newValue) }
    }

    var githubSearchTopics: String {
        get { defaults.string(forKey: "github_search_topics") ?? "llm, ai" }
        set { defaults.set(newValue, forKey: "github_search_topics") }
    }

    var githubSortOrder: String {
        get { defaults.string(forKey: "github_sort_order") ?? "stars" }
        set { defaults.set(newValue, forKey: "github_sort_order") }
    }

    var githubTrendingSince: String {
        get { defaults.string(forKey: "github_trending_since") ?? "daily" }
        set { defaults.set(newValue, forKey: "github_trending_since") }
    }

    var aiIntelSearchQuery: String {
        get { defaults.string(forKey: "aiintel_search_query") ?? "latest AI LLM breakthroughs, new model releases" }
        set { defaults.set(newValue, forKey: "aiintel_search_query") }
    }

    var customRSSFeeds: [CustomRSSFeed] {
        get {
            guard let data = defaults.data(forKey: "custom_rss_feeds"),
                  let feeds = try? JSONDecoder().decode([CustomRSSFeed].self, from: data) else {
                return []
            }
            return feeds
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "custom_rss_feeds")
            }
        }
    }

    private let keychain: any KeychainStoring
    private let defaults = UserDefaults.standard

    init(keychain: any KeychainStoring = KeychainStore()) {
        self.keychain = keychain
    }

    // MARK: - API Key Persistence

    func draftValue(for key: ApiKey) -> String {
        switch key {
        case .exa: exaAPIKey
        case .gemini: geminiAPIKey
        case .openRouter: openrouterAPIKey
        }
    }

    func setDraftValue(_ value: String, for key: ApiKey) {
        switch key {
        case .exa: exaAPIKey = value
        case .gemini: geminiAPIKey = value
        case .openRouter: openrouterAPIKey = value
        }
    }

    func isStored(_ key: ApiKey) -> Bool {
        storedKeys.contains(key)
    }

    func refreshKeyState() {
        storedKeys = Set(ApiKey.allCases.filter { keychain.load(forKey: $0.rawValue) != nil })
    }

    func maskedKey(_ key: ApiKey) -> String? {
        guard let value = keychain.load(forKey: key.rawValue), !value.isEmpty else { return nil }
        if value.count <= 8 { return "••••••••" }
        return "\(value.prefix(4))••••\(value.suffix(4))"
    }

    func clearStoredKey(_ key: ApiKey) {
        keychain.remove(forKey: key.rawValue)
        setDraftValue("", for: key)
        refreshKeyState()
    }

    @discardableResult
    func saveToKeychain() -> [ApiKey: KeychainError] {
        var failures: [ApiKey: KeychainError] = [:]

        for key in ApiKey.allCases {
            let value = draftValue(for: key)
            guard !value.isEmpty else { continue }
            do {
                try keychain.save(value, forKey: key.rawValue)
            } catch let error as KeychainError {
                failures[key] = error
            } catch {
                failures[key] = .saveFailed(errSecParam)
            }
        }

        refreshKeyState()
        return failures
    }
}

struct CustomRSSFeed: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool
    var showThumbnails: Bool

    init(
        id: UUID = UUID(),
        name: String,
        url: String,
        isEnabled: Bool = true,
        showThumbnails: Bool = true
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.showThumbnails = showThumbnails
    }

    enum CodingKeys: String, CodingKey {
        case id, name, url, isEnabled, showThumbnails
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        showThumbnails = try container.decodeIfPresent(Bool.self, forKey: .showThumbnails) ?? true
    }
}
