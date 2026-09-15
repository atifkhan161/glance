# Provider Page + Navigation Restructure

## Overview

Restructure the app's bottom navigation and settings architecture:
- Merge API key management into Settings
- Create a new "Provider" tab for managing data sources
- Each provider gets a toggle + configurable input fields
- Users can add custom RSS feeds

## Navigation

### Current State

```
Bottom Nav: Feed | Keys | Settings
```

- `GlanceTab` enum: `.pulse`, `.sources`, `.settings`
- `SourcesView` handles API key inputs (Exa, Gemini, Football Data)
- `SettingsView` handles appearance, card visibility, cache, about

### Target State

```
Bottom Nav: Feed | Provider | Settings
```

- `GlanceTab` enum: `.pulse`, `.provider`, `.settings`
- Remove `.sources` case, add `.provider` case
- API key inputs move into Settings (below Appearance, above Cache)
- Card visibility toggles move into Provider view
- `SourcesView` file kept for reference but removed from navigation

## GlanceTab Enum

**File:** `Glance/Shared/Enums.swift`

```swift
enum GlanceTab: String, CaseIterable, Hashable, Sendable {
    case pulse
    case provider
    case settings
}
```

## AppState

**File:** `Glance/App/AppState.swift`

Replace `sourcesPath` with `providerPath`:

```swift
@Observable
@MainActor
final class AppState {
    var selectedTab: GlanceTab = .pulse
    var isLaunching = true

    var pulsePath = NavigationPath()
    var providerPath = NavigationPath()  // was sourcesPath
    var settingsPath = NavigationPath()

    func resetPath(for tab: GlanceTab) {
        switch tab {
        case .pulse: pulsePath = NavigationPath()
        case .provider: providerPath = NavigationPath()
        case .settings: settingsPath = NavigationPath()
        }
    }
}
```

## ContentView

**File:** `Glance/App/ContentView.swift`

Update tab switch and dock:

```swift
switch bindable.selectedTab {
case .pulse:
    NavigationStack(path: $bindable.pulsePath) { PulseView(store: store) }
case .provider:
    NavigationStack(path: $bindable.providerPath) { ProviderView() }
case .settings:
    NavigationStack(path: $bindable.settingsPath) { SettingsView() }
}
```

Update `GlanceTab` extensions:

```swift
extension GlanceTab {
    var icon: String {
        switch self {
        case .pulse: "bolt.fill"
        case .provider: "antenna.radiowaves.left.and.right"
        case .settings: "gearshape.fill"
        }
    }

    var shortLabel: String {
        switch self {
        case .pulse: "Feed"
        case .provider: "Providers"
        case .settings: "Settings"
        }
    }

    var accentColor: Color {
        switch self {
        case .pulse: Theme.Colors.cardEmerald
        case .provider: Theme.Colors.cardAmber
        case .settings: Theme.Colors.textMuted
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .pulse: "Pulse feed"
        case .provider: "Data providers"
        case .settings: "Settings"
        }
    }
}
```

## SettingsStore

**File:** `Glance/Settings/SettingsStore.swift`

Add provider URL properties and custom RSS feed storage:

```swift
@Observable
@MainActor
final class SettingsStore {
    // Existing
    var exaAPIKey: String = ""
    var geminiAPIKey: String = ""
    var selectedModel: String = "gemini-3.6-flash"
    var leadCard: String { ... }
    var showMadrid: Bool { ... }
    var showPoGo: Bool { ... }
    var showGithub: Bool { ... }
    var showAiIntel: Bool { ... }

    // Provider URLs - Madrid
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

    // Provider URLs - PoGo
    var pogoRaidsURL: String {
        get { defaults.string(forKey: "pogo_raids_url") ?? "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json" }
        set { defaults.set(newValue, forKey: "pogo_raids_url") }
    }

    var pogoEventsURL: String {
        get { defaults.string(forKey: "pogo_events_url") ?? "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json" }
        set { defaults.set(newValue, forKey: "pogo_events_url") }
    }

    // Provider URLs - GitHub
    var githubSearchTopics: String {
        get { defaults.string(forKey: "github_search_topics") ?? "llm, ai" }
        set { defaults.set(newValue, forKey: "github_search_topics") }
    }

    var githubSortOrder: String {
        get { defaults.string(forKey: "github_sort_order") ?? "stars" }
        set { defaults.set(newValue, forKey: "github_sort_order") }
    }

    // Provider URLs - AI Intel
    var aiIntelSearchQuery: String {
        get { defaults.string(forKey: "aiintel_search_query") ?? "latest AI LLM breakthroughs, new model releases" }
        set { defaults.set(newValue, forKey: "aiintel_search_query") }
    }

    // Custom RSS Feeds
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

    // ... existing methods ...
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
```

## ProviderView

**File:** `Glance/Settings/ProviderView.swift` (new file)

### Layout

```
ScrollView
  VStack
    SectionHeader("DATA PROVIDERS")

    // Built-in provider cards
    ProviderCard(title: "Real Madrid", icon: "sportscourt", isOn: $showMadrid)
      inputs: RSS URL, Team ID, League ID

    ProviderCard(title: "Pokemon GO", icon: "gamecontroller", isOn: $showPoGo)
      inputs: Raids URL, Events URL

    ProviderCard(title: "GitHub Trending", icon: "chevron.left.forwardslash.chevron.right", isOn: $showGithub)
      inputs: Search Topics, Sort Order

    ProviderCard(title: "AI Intel", icon: "brain", isOn: $showAiIntel)
      inputs: Search Query

    Divider

    SectionHeader("CUSTOM RSS FEEDS")
      // List of custom feeds with name + URL inputs
      // Each has a delete button

    Button("Add RSS Feed") {
      addCustomFeed()
    }
```

### ProviderCard Component

Each built-in provider card:

```swift
struct ProviderCard: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let inputs: [ProviderInput]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row: icon + title + toggle
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Theme.Colors.accent)
                Text(title)
                    .font(Theme.Fonts.manrope(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }

            // Input fields (shown when enabled)
            if isOn {
                ForEach(inputs) { input in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(input.label)
                            .font(Theme.Fonts.manrope(10, weight: .bold))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .tracking(1.2)

                        TextField(input.placeholder, text: input.binding)
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(10)
                            .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
    }
}

struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
}
```

### Custom RSS Feeds Section

```swift
// Each custom feed row
ForEach($settingsStore.customRSSFeeds) { $feed in
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            TextField("Feed Name", text: $feed.name)
                .font(Theme.Fonts.manrope(14))
            Button {
                removeCustomFeed(feed)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Theme.Colors.error)
            }
        }

        TextField("https://example.com/rss.xml", text: $feed.url)
            .font(Theme.Fonts.manrope(13))
            .foregroundStyle(Theme.Colors.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
    .padding(12)
    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
}

Button {
    addCustomFeed()
} label: {
    HStack {
        Image(systemName: "plus.circle.fill")
        Text("Add RSS Feed")
    }
    .font(Theme.Fonts.manrope(14, weight: .medium))
    .foregroundStyle(Theme.Colors.accent)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(Theme.Colors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
}
```

## SettingsView Updates

**File:** `Glance/Settings/SettingsView.swift`

### Remove

- `cardVisibilitySection` property (lines 138-174)
- `cardToggle()` helper function (lines 163-174)

### Add

API key inputs section (moved from SourcesView), inserted between `displaySection` and `cacheSection`:

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            brandingHeader
            appearanceSection
            displaySection
            apiKeysSection        // NEW - moved from SourcesView
            cacheSection
            Divider()
            aboutSection
        }
    }
}
```

The `apiKeysSection` replicates the key inputs from `SourcesView`:

```swift
private var apiKeysSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        SectionHeader("API KEYS")

        // Exa key input
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EXA SEARCH")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                // status badge
            }
            SecureField("Enter Exa API key", text: $settingsStore.exaAPIKey)
                // ... styling ...
        }

        // Gemini key input
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GEMINI")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                // status badge
            }
            SecureField("Enter Gemini API key", text: $settingsStore.geminiAPIKey)
                // ... styling ...
        }

        // Football Data info (no key required)
        infoSection(
            title: "FOOTBALL DATA",
            subtitle: "Powered by thesportsdb.com free tier - no key required"
        )

        // Save button
        Button { saveKeys() } label: { ... }
    }
}
```

## Pipeline Changes

Each pipeline reads URLs from `SettingsStore` instead of hardcoding them.

### ManagingMadridClient

**File:** `Glance/Core/Network/ManagingMadridClient.swift`

```swift
struct ManagingMadridClient: ManagingMadridClientProtocol, Sendable {
    func fetchArticles(rssURL: String) async throws -> [MMArticle] {
        guard let url = URL(string: rssURL) else {
            throw GlanceError.networkError("Invalid RSS URL")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = MMXMLParser()
        return parser.parse(data: data)
    }
}
```

### MadridPipeline

**File:** `Glance/Features/Madrid/MadridPipeline.swift`

Read from SettingsStore:

```swift
func refresh(settings: SettingsStore) async -> MadridData {
    let rssURL = settings.madridRSSURL
    let teamID = settings.madridTeamID
    let leagueID = settings.madridLeagueID

    // Use these values instead of hardcoded ones
    let sportsDB = SportsDBClient()
    let lastEvents = try? await sportsDB.lastEvents(teamID: teamID)
    let nextEvents = try? await sportsDB.nextEvents(teamID: teamID)
    // ...
    let articles = try? await managingMadrid.fetchArticles(rssURL: rssURL)
}
```

### ScrapedDuckClient

**File:** `Glance/Core/Network/ScrapedDuckClient.swift`

```swift
struct ScrapedDuckClient: Sendable {
    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid] { ... }
    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent] { ... }
}
```

### PoGoPipeline

**File:** `Glance/Features/PoGo/PoGoPipeline.swift`

```swift
func refresh(settings: SettingsStore) async -> PoGoData {
    let raidsURL = settings.pogoRaidsURL
    let eventsURL = settings.pogoEventsURL
    // Use these instead of hardcoded URLs
}
```

### GitHubClient

**File:** `Glance/Core/Network/GitHubClient.swift`

```swift
func searchRepos(topics: [String], sort: String, since: String) async throws -> GitHubSearchResult {
    let query = topics.map { "topic:\($0)" }.joined(separator: "+") + "+created:>\(since)"
    // ... rest unchanged
}
```

### GitHubPipeline

**File:** `Glance/Features/GitHub/GitHubPipeline.swift`

```swift
func refresh(settings: SettingsStore) async -> GitHubData {
    let topics = settings.githubSearchTopics.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let sort = settings.githubSortOrder
    // Use these instead of hardcoded values
}
```

### ExaClient (for AI Intel)

**File:** `Glance/Core/Network/ExaClient.swift`

```swift
func search(query: String, apiKey: String) async throws -> ExaResult { ... }
```

### AiIntelPipeline

**File:** `Glance/Features/AiIntel/AiIntelPipeline.swift`

```swift
func refresh(settings: SettingsStore) async -> AiIntelData {
    let query = settings.aiIntelSearchQuery
    // Use this instead of hardcoded rotated queries
}
```

## Custom RSS Support

### GenericRSSClient

**File:** `Glance/Core/Network/GenericRSSClient.swift` (new)

Reuses the XML parsing logic from `ManagingMadridClient`:

```swift
struct GenericRSSClient: Sendable {
    func fetchArticles(from urlString: String) async throws -> [MMArticle] {
        guard let url = URL(string: urlString) else {
            throw GlanceError.networkError("Invalid RSS URL: \(urlString)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = GenericRSSParser()
        return parser.parse(data: data)
    }
}

// Reuses MMArticle model - same XML parsing as MMXMLParser
private final class GenericRSSParser: NSObject, XMLParserDelegate { ... }
```

### GenericRSSPipeline

**File:** `Glance/Features/GenericRSS/GenericRSSPipeline.swift` (new)

```swift
struct GenericRSSPipeline {
    let client = GenericRSSClient()

    func refresh(feed: CustomRSSFeed) async -> [MMArticle] {
        guard feed.isEnabled else { return [] }
        return (try? await client.fetchArticles(from: feed.url)) ?? []
    }
}
```

### PulseStore Integration

**File:** `Glance/Features/Pulse/PulseStore.swift`

Add custom RSS articles to the feed:

```swift
// In refreshAll()
for feed in settings.customRSSFeeds where feed.isEnabled {
    let articles = await genericRSSPipeline.refresh(feed: feed)
    // Add to card states with feed.name as card title
}
```

## File Summary

### Modified Files

| File | Change |
|------|--------|
| `Glance/Shared/Enums.swift` | Replace `.sources` with `.provider` in `GlanceTab` |
| `Glance/App/AppState.swift` | Replace `sourcesPath` with `providerPath` |
| `Glance/App/ContentView.swift` | Update tab switch, dock icons/labels |
| `Glance/Settings/SettingsView.swift` | Remove card visibility section, add API keys section |
| `Glance/Settings/SettingsStore.swift` | Add provider URL properties, `CustomRSSFeed` model, `customRSSFeeds` array |
| `Glance/Core/Network/ManagingMadridClient.swift` | Accept `rssURL` parameter |
| `Glance/Core/Network/ScrapedDuckClient.swift` | Accept URL parameters |
| `Glance/Core/Network/GitHubClient.swift` | Accept `topics` and `sort` parameters |
| `Glance/Core/Network/ExaClient.swift` | Accept `query` parameter |
| `Glance/Features/Madrid/MadridPipeline.swift` | Read URLs from SettingsStore |
| `Glance/Features/PoGo/PoGoPipeline.swift` | Read URLs from SettingsStore |
| `Glance/Features/GitHub/GitHubPipeline.swift` | Read topics from SettingsStore |
| `Glance/Features/AiIntel/AiIntelPipeline.swift` | Read query from SettingsStore |
| `Glance/Features/Pulse/PulseStore.swift` | Integrate custom RSS feeds |

### New Files

| File | Purpose |
|------|---------|
| `Glance/Settings/ProviderView.swift` | Provider page UI with toggles and input cards |
| `Glance/Core/Network/GenericRSSClient.swift` | Reusable RSS parser for custom feeds |
| `Glance/Features/GenericRSS/GenericRSSPipeline.swift` | Pipeline for custom RSS feeds |

## Data Flow Summary

```
ProviderView (UI)
  │
  ├── Toggle: settingsStore.showMadrid / showPoGo / showGithub / showAiIntel
  │
  ├── Built-in Provider Inputs:
  │   ├── madridRSSURL, madridTeamID, madridLeagueID
  │   ├── pogoRaidsURL, pogoEventsURL
  │   ├── githubSearchTopics, githubSortOrder
  │   └── aiIntelSearchQuery
  │
  └── Custom RSS Feeds: settingsStore.customRSSFeeds
        │
        └── GenericRSSPipeline → PulseStore (feed cards)

Pipelines (data fetch)
  │
  ├── MadridPipeline → reads from settingsStore
  ├── PoGoPipeline → reads from settingsStore
  ├── GitHubPipeline → reads from settingsStore
  ├── AiIntelPipeline → reads from settingsStore
  └── GenericRSSPipeline → reads custom feeds from settingsStore
```

## Testing

- Verify each provider toggle hides/shows its card in the feed
- Verify changing a URL in provider settings updates the next fetch
- Verify adding a custom RSS feed creates a new card in the feed
- Verify deleting a custom RSS feed removes its card
- Verify API keys moved to Settings save/load correctly
- Verify bottom nav shows 3 tabs with correct icons
- Verify navigation paths reset correctly on dock tap
