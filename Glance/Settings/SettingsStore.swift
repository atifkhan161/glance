import Foundation

@Observable
@MainActor
final class SettingsStore {
    var exaAPIKey: String = ""
    var geminiAPIKey: String = ""
    var selectedModel: String = "gemini-3.6-flash"

    var leadCard: String {
        get { defaults.string(forKey: "leadCard") ?? "" }
        set { defaults.set(newValue, forKey: "leadCard") }
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

    var pogoRaidsURL: String {
        get { defaults.string(forKey: "pogo_raids_url") ?? "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json" }
        set { defaults.set(newValue, forKey: "pogo_raids_url") }
    }

    var pogoEventsURL: String {
        get { defaults.string(forKey: "pogo_events_url") ?? "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json" }
        set { defaults.set(newValue, forKey: "pogo_events_url") }
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

    private let keychain = KeychainStore()
    private let defaults = UserDefaults.standard

    func loadFromKeychain() {
        exaAPIKey = ""
        geminiAPIKey = ""
        selectedModel = defaults.string(forKey: "gemini_model") ?? "gemini-3.6-flash"
    }

    func saveToKeychain() {
        if !exaAPIKey.isEmpty {
            try? keychain.save(exaAPIKey, forKey: "keys_exa")
        }
        if !geminiAPIKey.isEmpty {
            try? keychain.save(geminiAPIKey, forKey: "keys_gemini")
        }
        defaults.set(selectedModel, forKey: "gemini_model")
    }

    func existingKey(for service: String) -> String? {
        let key: String
        switch service {
        case "Exa": key = "keys_exa"
        case "Gemini": key = "keys_gemini"
        default: return nil
        }
        guard let value = keychain.load(forKey: key) else { return nil }
        if value.count <= 8 { return "••••••••" }
        let prefix = String(value.prefix(4))
        let suffix = String(value.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}

struct CustomRSSFeed: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, url: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
    }
}
