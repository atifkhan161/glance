# Provider Page + Navigation Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure bottom navigation from Feed|Keys|Settings to Feed|Provider|Settings, create a Provider page for managing data sources with toggles and configurable inputs, and add custom RSS feed support.

**Architecture:** Move API key inputs into Settings, create a new ProviderView with per-provider toggle+input cards, add CustomRSSFeed model and GenericRSSClient for user-added feeds. Pipelines read URLs from SettingsStore instead of hardcoding them.

**Tech Stack:** SwiftUI, Swift 6, UserDefaults (@Observable), KeychainStore, XMLParser (reuse existing MMXMLParser pattern)

**Spec:** `docs/superpowers/specs/2026-09-15-provider-restructure-design.md`

## Global Constraints

- Swift 6 strict concurrency (all types `Sendable`)
- iOS 26+ glass effects with fallback for older iOS
- Follow existing code style: `Theme.Colors.*`, `Theme.Fonts.manrope()`, `Theme.Radius.*`
- No new dependencies
- Keys stored in KeychainStore, preferences in UserDefaults via SettingsStore

---

## File Structure

### Modified Files

| File | Responsibility |
|------|---------------|
| `Glance/Shared/Enums.swift` | Add `.provider` case to `GlanceTab` |
| `Glance/App/AppState.swift` | Replace `sourcesPath` with `providerPath` |
| `Glance/App/ContentView.swift` | Update tab switch, dock icons/labels, remove `.sources` |
| `Glance/Settings/SettingsStore.swift` | Add provider URL properties, `CustomRSSFeed` model |
| `Glance/Settings/SettingsView.swift` | Remove card visibility, add API keys section |
| `Glance/Core/Network/ManagingMadridClient.swift` | Accept `rssURL` parameter |
| `Glance/Core/Network/ScrapedDuckClient.swift` | Accept URL parameters |
| `Glance/Core/Network/GitHubClient.swift` | Accept `topics` and `sort` parameters |
| `Glance/Features/Madrid/MadridPipeline.swift` | Read URLs from SettingsStore |
| `Glance/Features/PoGo/PoGoPipeline.swift` | Read URLs from SettingsStore |
| `Glance/Features/GitHub/GitHubPipeline.swift` | Read topics from SettingsStore |
| `Glance/Features/AiIntel/AiIntelPipeline.swift` | Read query from SettingsStore |
| `Glance/Features/Pulse/PulseStore.swift` | Integrate custom RSS feeds |

### New Files

| File | Responsibility |
|------|---------------|
| `Glance/Settings/ProviderView.swift` | Provider page UI with toggles and input cards |
| `Glance/Core/Network/GenericRSSClient.swift` | Reusable RSS parser for custom feeds |
| `Glance/Features/GenericRSS/GenericRSSPipeline.swift` | Pipeline for custom RSS feeds |

---

## Task 1: Add Provider Tab to Navigation

**Files:**
- Modify: `Glance/Shared/Enums.swift:3-7`
- Modify: `Glance/App/AppState.swift:1-32`
- Modify: `Glance/App/ContentView.swift:1-138`

**Interfaces:**
- Consumes: existing `GlanceTab` enum
- Produces: new `.provider` case used by ContentView and AppState

- [ ] **Step 1: Update GlanceTab enum**

In `Glance/Shared/Enums.swift`, replace `.sources` with `.provider`:

```swift
enum GlanceTab: String, CaseIterable, Hashable, Sendable {
    case pulse
    case provider
    case settings
}
```

- [ ] **Step 2: Update AppState**

In `Glance/App/AppState.swift`, replace `sourcesPath` with `providerPath`:

```swift
@Observable
@MainActor
final class AppState {
    var selectedTab: GlanceTab = .pulse
    var isLaunching = true

    var pulsePath = NavigationPath()
    var providerPath = NavigationPath()
    var settingsPath = NavigationPath()

    func markLaunched() {
        isLaunching = false
    }

    func selectTab(_ tab: GlanceTab) {
        selectedTab = tab
        resetPath(for: tab)
    }

    func resetPath(for tab: GlanceTab) {
        switch tab {
        case .pulse: pulsePath = NavigationPath()
        case .provider: providerPath = NavigationPath()
        case .settings: settingsPath = NavigationPath()
        }
    }
}
```

- [ ] **Step 3: Update ContentView tab switch**

In `Glance/App/ContentView.swift`, update the `Group` switch at line 14:

```swift
Group {
    switch bindable.selectedTab {
    case .pulse:
        NavigationStack(path: $bindable.pulsePath) { PulseView(store: store) }
            .tint(Theme.Colors.accent)
    case .provider:
        NavigationStack(path: $bindable.providerPath) { ProviderView() }
            .tint(Theme.Colors.accent)
    case .settings:
        NavigationStack(path: $bindable.settingsPath) { SettingsView() }
            .tint(Theme.Colors.accent)
    }
}
```

- [ ] **Step 4: Update GlanceTab extensions**

Replace the extensions at line 99-133 in `Glance/App/ContentView.swift`:

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

- [ ] **Step 5: Create placeholder ProviderView**

Create `Glance/Settings/ProviderView.swift` with a minimal placeholder so the project compiles:

```swift
import SwiftUI

struct ProviderView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Providers")
                    .font(Theme.Fonts.manrope(24, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack { ProviderView() }
}
```

- [ ] **Step 6: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Glance/Shared/Enums.swift Glance/App/AppState.swift Glance/App/ContentView.swift Glance/Settings/ProviderView.swift
git commit -m "feat: replace Keys tab with Provider tab in navigation"
```

---

## Task 2: Add Provider URL Properties to SettingsStore

**Files:**
- Modify: `Glance/Settings/SettingsStore.swift:1-67`

**Interfaces:**
- Consumes: existing `SettingsStore` with `UserDefaults`
- Produces: `madridRSSURL`, `madridTeamID`, `madridLeagueID`, `pogoRaidsURL`, `pogoEventsURL`, `githubSearchTopics`, `githubSortOrder`, `aiIntelSearchQuery`, `CustomRSSFeed` model, `customRSSFeeds` array

- [ ] **Step 1: Add CustomRSSFeed model**

Add at the bottom of `Glance/Settings/SettingsStore.swift` (after the `SettingsStore` class):

```swift
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

- [ ] **Step 2: Add provider URL properties to SettingsStore**

Add these properties inside the `SettingsStore` class, after the existing `showAiIntel` property (line 33):

```swift
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
```

- [ ] **Step 3: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Settings/SettingsStore.swift
git commit -m "feat: add provider URL properties and CustomRSSFeed model to SettingsStore"
```

---

## Task 3: Move API Keys into SettingsView

**Files:**
- Modify: `Glance/Settings/SettingsView.swift:1-287`

**Interfaces:**
- Consumes: `SettingsStore` properties (`exaAPIKey`, `geminiAPIKey`, `selectedModel`)
- Produces: `apiKeysSection` view property replacing `cardVisibilitySection`

- [ ] **Step 1: Remove card visibility section**

In `Glance/Settings/SettingsView.swift`, remove the `cardVisibilitySection` property (lines 138-174) and the `cardToggle` helper (lines 163-174).

- [ ] **Step 2: Remove cardVisibilitySection from body**

In the `body` property (line 10-33), remove the `cardVisibilitySection` line. The body becomes:

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            brandingHeader
            appearanceSection
            displaySection
            apiKeysSection
            cacheSection

            Divider()
                .background(Theme.Colors.borderSubtle)

            aboutSection
        }
        .padding(Theme.cardPadding)
        .padding(.bottom, 100)
    }
    .glanceBackground()
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.large)
    .task {
        await loadCacheAges()
    }
}
```

- [ ] **Step 3: Add apiKeysSection property**

Add this new property in the `// MARK: - Display Section` area (after `displaySection`, before the removed `cardVisibilitySection`):

```swift
// MARK: - API Keys Section

private var apiKeysSection: some View {
    VStack(alignment: .leading, spacing: 12) {
        SectionHeader("API KEYS")

        // Exa
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EXA SEARCH")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                Text(settingsStore.exaAPIKey.isEmpty ? "Missing" : "Configured ✓")
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(settingsStore.exaAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (settingsStore.exaAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success).opacity(0.15),
                        in: .capsule
                    )
            }

            SecureField("Enter Exa API key", text: $settingsStore.exaAPIKey)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(12)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        }

        // Gemini
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GEMINI")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                Text(settingsStore.geminiAPIKey.isEmpty ? "Missing" : "Configured ✓")
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(settingsStore.geminiAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        (settingsStore.geminiAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success).opacity(0.15),
                        in: .capsule
                    )
            }

            SecureField("Enter Gemini API key", text: $settingsStore.geminiAPIKey)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(12)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        }

        // Gemini Model Picker
        VStack(alignment: .leading, spacing: 8) {
            Text("GEMINI MODEL")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.textMuted)
                .tracking(1.2)

            Picker("Gemini Model", selection: $settingsStore.selectedModel) {
                Text("3.6 Flash").tag("gemini-3.6-flash")
                Text("3.7 Flash").tag("gemini-3.7-flash")
                Text("3.8 Flash").tag("gemini-3.8-flash")
            }
            .pickerStyle(.segmented)
        }

        // Football Data info
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FOOTBALL DATA")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)
                Spacer()
                Text("Configured ✓")
                    .font(Theme.Fonts.manrope(10, weight: .medium))
                    .foregroundStyle(Theme.Colors.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.success.opacity(0.15), in: .capsule)
            }

            Text("Powered by thesportsdb.com free tier — no key required")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }

        // Save button
        Button {
            saveKeys()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSaving ? "Saving..." : "Save Keys")
                    .font(Theme.Fonts.scale(.callout).weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.Colors.cardEmerald, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .disabled(isSaving)
        .padding(.top, 8)

        if saveSuccess {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("Keys saved successfully")
            }
            .font(Theme.Fonts.scale(.caption2))
            .foregroundStyle(Theme.Colors.success)
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(.opacity)
        }
    }
}
```

- [ ] **Step 4: Add missing @State properties**

Add these properties to `SettingsView` (after the existing `@AppStorage` at line 8):

```swift
@State private var showExaKey = false
@State private var showGeminiKey = false
@State private var saveSuccess = false
@State private var isSaving = false
```

- [ ] **Step 5: Add saveKeys helper**

Add this private method in the `// MARK: - Helpers` section:

```swift
private func saveKeys() {
    isSaving = true
    saveSuccess = false

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        settingsStore.saveToKeychain()
        isSaving = false
        saveSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            saveSuccess = false
        }
    }
}
```

- [ ] **Step 6: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 7: Commit**

```bash
git add Glance/Settings/SettingsView.swift
git commit -m "feat: move API keys section into SettingsView, remove card visibility"
```

---

## Task 4: Build ProviderView with Toggle Cards

**Files:**
- Modify: `Glance/Settings/ProviderView.swift` (replace placeholder)

**Interfaces:**
- Consumes: `SettingsStore` properties (`showMadrid`, `showPoGo`, etc., provider URLs)
- Produces: full ProviderView with toggle cards and input fields

- [ ] **Step 1: Add ProviderInput and ProviderCard types**

Replace the entire contents of `Glance/Settings/ProviderView.swift`:

```swift
import SwiftUI

struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
}

struct ProviderCard: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let inputs: [ProviderInput]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.accent)
                Text(title)
                    .font(Theme.Fonts.manrope(16, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }

            if isOn {
                VStack(spacing: 10) {
                    ForEach(inputs) { input in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(input.label)
                                .font(Theme.Fonts.manrope(10, weight: .bold))
                                .foregroundStyle(Theme.Colors.textMuted)
                                .tracking(1.2)

                            TextField(input.placeholder, text: input.binding)
                                .font(Theme.Fonts.manrope(13))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(10)
                                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

struct ProviderView: View {
    @State private var settingsStore = SettingsStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader("DATA PROVIDERS")

                ProviderCard(
                    title: "Real Madrid",
                    icon: "sportscourt",
                    isOn: $settingsStore.showMadrid,
                    inputs: [
                        ProviderInput(label: "RSS URL", placeholder: "https://...", binding: $settingsStore.madridRSSURL),
                        ProviderInput(label: "TEAM ID", placeholder: "133738", binding: $settingsStore.madridTeamID),
                        ProviderInput(label: "LEAGUE ID", placeholder: "4335", binding: $settingsStore.madridLeagueID),
                    ]
                )

                ProviderCard(
                    title: "Pokemon GO",
                    icon: "gamecontroller",
                    isOn: $settingsStore.showPoGo,
                    inputs: [
                        ProviderInput(label: "RAIDS URL", placeholder: "https://...", binding: $settingsStore.pogoRaidsURL),
                        ProviderInput(label: "EVENTS URL", placeholder: "https://...", binding: $settingsStore.pogoEventsURL),
                    ]
                )

                ProviderCard(
                    title: "GitHub Trending",
                    icon: "chevron.left.forwardslash.chevron.right",
                    isOn: $settingsStore.showGithub,
                    inputs: [
                        ProviderInput(label: "SEARCH TOPICS", placeholder: "llm, ai", binding: $settingsStore.githubSearchTopics),
                        ProviderInput(label: "SORT ORDER", placeholder: "stars", binding: $settingsStore.githubSortOrder),
                    ]
                )

                ProviderCard(
                    title: "AI Intel",
                    icon: "brain",
                    isOn: $settingsStore.showAiIntel,
                    inputs: [
                        ProviderInput(label: "SEARCH QUERY", placeholder: "latest AI LLM breakthroughs", binding: $settingsStore.aiIntelSearchQuery),
                    ]
                )

                Divider()
                    .background(Theme.Colors.borderSubtle)

                // Custom RSS Feeds
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("CUSTOM RSS FEEDS")

                    if settingsStore.customRSSFeeds.isEmpty {
                        Text("Add custom RSS feeds to create new cards in your feed.")
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }

                    ForEach(Array(settingsStore.customRSSFeeds.enumerated()), id: \.element.id) { index, feed in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("Feed Name", text: Binding(
                                    get: { settingsStore.customRSSFeeds[index].name },
                                    set: { settingsStore.customRSSFeeds[index].name = $0 }
                                ))
                                .font(Theme.Fonts.manrope(14, weight: .medium))
                                .foregroundStyle(Theme.Colors.textPrimary)

                                Button {
                                    removeFeed(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(Theme.Fonts.manrope(12))
                                        .foregroundStyle(Theme.Colors.error)
                                }
                                .accessibilityLabel("Remove \(feed.name)")
                            }

                            TextField("https://example.com/rss.xml", text: Binding(
                                get: { settingsStore.customRSSFeeds[index].url },
                                set: { settingsStore.customRSSFeeds[index].url = $0 }
                            ))
                            .font(Theme.Fonts.manrope(13))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        }
                        .padding(12)
                        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }

                    Button {
                        addFeed()
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
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .navigationTitle("Providers")
        .navigationBarTitleDisplayMode(.large)
    }

    private func addFeed() {
        var feeds = settingsStore.customRSSFeeds
        feeds.append(CustomRSSFeed(name: "New Feed", url: ""))
        settingsStore.customRSSFeeds = feeds
    }

    private func removeFeed(at index: Int) {
        var feeds = settingsStore.customRSSFeeds
        guard feeds.indices.contains(index) else { return }
        feeds.remove(at: index)
        settingsStore.customRSSFeeds = feeds
    }
}

#Preview {
    NavigationStack { ProviderView() }
}
```

- [ ] **Step 2: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Settings/ProviderView.swift
git commit -m "feat: build ProviderView with toggle cards, input fields, and custom RSS feeds"
```

---

## Task 5: Update Pipelines to Read from SettingsStore

**Files:**
- Modify: `Glance/Core/Network/ManagingMadridClient.swift:17-24`
- Modify: `Glance/Core/Network/ScrapedDuckClient.swift:1-20`
- Modify: `Glance/Core/Network/GitHubClient.swift:160-227`
- Modify: `Glance/Features/Madrid/MadridPipeline.swift:36-86`
- Modify: `Glance/Features/PoGo/PoGoPipeline.swift:105-137`
- Modify: `Glance/Features/GitHub/GitHubPipeline.swift:57-84`
- Modify: `Glance/Features/AiIntel/AiIntelPipeline.swift:39-101`

**Interfaces:**
- Consumes: `SettingsStore` with provider URL properties
- Produces: updated client/pipeline signatures accepting configurable URLs

- [ ] **Step 1: Update ManagingMadridClient to accept rssURL**

In `Glance/Core/Network/ManagingMadridClient.swift`, update the protocol and struct:

```swift
protocol ManagingMadridClientProtocol: Sendable {
    func fetchArticles(rssURL: String) async throws -> [MMArticle]
}

struct ManagingMadridClient: ManagingMadridClientProtocol, Sendable {
    func fetchArticles(rssURL: String) async throws -> [MMArticle] {
        guard let url = URL(string: rssURL) else {
            throw GlanceError.networkError("Invalid RSS URL: \(rssURL)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = MMXMLParser()
        return parser.parse(data: data)
    }
}
```

- [ ] **Step 2: Update ScrapedDuckClient to accept URLs**

In `Glance/Core/Network/ScrapedDuckClient.swift`:

```swift
protocol ScrapedDuckClientProtocol: Sendable {
    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid]
    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent]
}

struct ScrapedDuckClient: ScrapedDuckClientProtocol, Sendable {
    func fetchRaids(raidsURL: String) async throws -> [PoGoRaid] {
        guard let url = URL(string: raidsURL) else {
            throw GlanceError.networkError("Invalid raids URL: \(raidsURL)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoRaid].self, from: data)
    }

    func fetchEvents(eventsURL: String) async throws -> [PoGoEvent] {
        guard let url = URL(string: eventsURL) else {
            throw GlanceError.networkError("Invalid events URL: \(eventsURL)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoEvent].self, from: data)
    }
}
```

- [ ] **Step 3: Update GitHubClient to accept topics and sort**

In `Glance/Core/Network/GitHubClient.swift`, update the protocol and the `searchRepos` method signature:

```swift
protocol GitHubClientProtocol: Sendable {
    func searchRepos(topics: [String], sort: String, since: String) async throws -> GitHubSearchResult
}
```

Update the `searchRepos` implementation (line 172):

```swift
func searchRepos(topics: [String], sort: String, since: String) async throws -> GitHubSearchResult {
    var components = URLComponents(string: "https://api.github.com/search/repositories")!
    let query = topics.map { "topic:\($0)" }.joined(separator: "+") + "+created:>\(since)"
    components.queryItems = [
        URLQueryItem(name: "q", value: query),
        URLQueryItem(name: "sort", value: sort),
        URLQueryItem(name: "order", value: "desc"),
        URLQueryItem(name: "per_page", value: "10"),
    ]
    // ... rest of method unchanged from line 180 onward
```

- [ ] **Step 4: Update MadridPipeline.refresh() to read from SettingsStore**

In `Glance/Features/Madrid/MadridPipeline.swift`, update the `refresh` method signature and body:

```swift
func refresh(settings: SettingsStore, force: Bool = false) async -> MadridRefreshResult {
    let rssURL = settings.madridRSSURL
    let teamID = settings.madridTeamID
    let leagueID = settings.madridLeagueID

    do {
        let lastEvents = try await sportsDB.lastEvents(teamID: teamID)
        try? await Task.sleep(for: .milliseconds(600))
        let nextEvents = try await sportsDB.nextEvents(teamID: teamID)
        try? await Task.sleep(for: .milliseconds(600))
        let table = try await sportsDB.leagueTable(leagueID: leagueID, season: SportsDB.currentSeason())

        let lastMatch = Self.parseLastMatch(from: lastEvents)
        let form = Self.parseForm(from: lastEvents)
        let standing = Self.parseStanding(from: table, teamID: teamID)
        let nextFixture = Self.parseNextFixture(from: nextEvents.first)

        let exaArticles = await fetchExaArticles()
        let mmArticles = (try? await madridClient.fetchArticles(rssURL: rssURL)) ?? []

        let data = MadridData(
            fixture: nextFixture,
            lastMatch: lastMatch,
            schedule: [],
            form: form,
            standing: standing,
            standingText: Self.formatStandingText(standing),
            intel: Self.generateIntel(nextFixture: nextFixture, lastMatch: lastMatch),
            headToHead: nil,
            articles: exaArticles,
            mmArticles: mmArticles,
            source: "api-sports",
            timestamp: Date.now
        )

        await cache.save("cache_madrid", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return .ready(data: data)
    } catch {
        print("[MadridPipeline] API-Sports fetch failed: \(error)")
        return await refreshWithExaFallback(settings: settings)
    }
}
```

Update `refreshWithExaFallback` to also accept settings and pass rssURL:

```swift
private func refreshWithExaFallback(settings: SettingsStore) async -> MadridRefreshResult {
    // ... same as before but line 96 becomes:
    async let mmTask: [MMArticle] = {
        (try? await self.madridClient.fetchArticles(rssURL: settings.madridRSSURL)) ?? []
    }()
    // ... rest unchanged
}
```

- [ ] **Step 5: Update PoGoPipeline.refresh() to read from SettingsStore**

In `Glance/Features/PoGo/PoGoPipeline.swift`, update the `refresh` method:

```swift
func refresh(settings: SettingsStore, force: Bool = false) async -> PoGoData {
    let raidsURL = settings.pogoRaidsURL
    let eventsURL = settings.pogoEventsURL

    async let raidsTask: [PoGoRaid] = { (try? await self.client.fetchRaids(raidsURL: raidsURL)) ?? [] }()
    async let eventsTask: [PoGoEvent] = { (try? await self.client.fetchEvents(eventsURL: eventsURL)) ?? [] }()
    // ... rest unchanged from line 108 onward
```

- [ ] **Step 6: Update GitHubPipeline.refresh() to read from SettingsStore**

In `Glance/Features/GitHub/GitHubPipeline.swift`, update the `refresh` method:

```swift
func refresh(settings: SettingsStore, force: Bool = false) async throws -> GitHubData {
    let topics = settings.githubSearchTopics
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespaces) }
    let sort = settings.githubSortOrder

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let sevenDaysAgo = formatter.string(from: Date.now.addingTimeInterval(-7 * 86400))

    let result = try await client.searchRepos(topics: topics, sort: sort, since: sevenDaysAgo)
    // ... rest unchanged from line 69 onward
```

- [ ] **Step 7: Update AiIntelPipeline.refresh() to read from SettingsStore**

In `Glance/Features/AiIntel/AiIntelPipeline.swift`, update the `refresh` method:

```swift
func refresh(settings: SettingsStore, force: Bool = false) async -> AiIntelRefreshResult {
    guard let key = keychain.load(forKey: "keys_exa") else {
        let cached: CacheEnvelope<AiIntelData>? = await cache.load("cache_aiintel")
        return .keyMissing(cachedData: cached?.data)
    }

    let query = settings.aiIntelSearchQuery
    let results = (try? await exa.search(query: query, apiKey: key)) ?? []
    // ... rest unchanged from line 48 onward
```

- [ ] **Step 8: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add Glance/Core/Network/ManagingMadridClient.swift Glance/Core/Network/ScrapedDuckClient.swift Glance/Core/Network/GitHubClient.swift Glance/Features/Madrid/MadridPipeline.swift Glance/Features/PoGo/PoGoPipeline.swift Glance/Features/GitHub/GitHubPipeline.swift Glance/Features/AiIntel/AiIntelPipeline.swift
git commit -m "feat: update pipelines to read URLs from SettingsStore instead of hardcoding"
```

---

## Task 6: Update PulseStore to Pass SettingsStore to Pipelines

**Files:**
- Modify: `Glance/Features/Pulse/PulseStore.swift:1-179`

**Interfaces:**
- Consumes: updated pipeline signatures requiring `SettingsStore`
- Produces: PulseStore passing settings to each pipeline refresh call

- [ ] **Step 1: Add SettingsStore to PulseStore**

In `Glance/Features/Pulse/PulseStore.swift`, add a `settingsStore` property:

```swift
@MainActor
@Observable
final class PulseStore {
    var madrid: CardState<MadridData> = .loading
    var pogo: CardState<PoGoData> = .loading
    var github: CardState<GitHubData> = .loading
    var aiIntel: CardState<AiIntelData> = .loading

    // ... existing computed properties ...

    private let cache: CacheStore
    private let madridPipeline: MadridPipeline
    private let pogoPipeline: PoGoPipeline
    private let githubPipeline: GitHubPipeline
    private let aiIntelPipeline: AiIntelPipeline
    private let settingsStore: SettingsStore
    private var refreshTasks: [CardID: Task<Void, Never>] = [:]

    init(
        cache: CacheStore = .shared,
        madridPipeline: MadridPipeline = MadridPipeline(),
        pogoPipeline: PoGoPipeline = PoGoPipeline(),
        githubPipeline: GitHubPipeline = GitHubPipeline(),
        aiIntelPipeline: AiIntelPipeline = AiIntelPipeline(),
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.cache = cache
        self.madridPipeline = madridPipeline
        self.pogoPipeline = pogoPipeline
        self.githubPipeline = githubPipeline
        self.aiIntelPipeline = aiIntelPipeline
        self.settingsStore = settingsStore
    }
```

- [ ] **Step 2: Update refresh calls to pass settings**

In the `refresh(_:force:)` method, update each case to pass `settings`:

```swift
case .madrid:
    if case .ready(let data, let age) = madrid { madrid = .stale(data: data, age: age) }
    switch await madridPipeline.refresh(settings: settingsStore) {
    // ... rest of madrid case unchanged

case .pogo:
    if case .ready(let data, let age) = pogo { pogo = .stale(data: data, age: age) }
    let data = await pogoPipeline.refresh(settings: settingsStore)
    pogo = .ready(data: data, age: TimeFormat.age(from: data.timestamp))

case .github:
    if case .ready(let data, let age) = github { github = .stale(data: data, age: age) }
    do {
        let data = try await githubPipeline.refresh(settings: settingsStore)
        github = .ready(data: data, age: TimeFormat.age(from: data.timestamp))
    } catch {
        // ... error handling unchanged
    }

case .aiIntel:
    if case .ready(let data, let age) = aiIntel { aiIntel = .stale(data: data, age: age) }
    switch await aiIntelPipeline.refresh(settings: settingsStore) {
    // ... rest of aiIntel case unchanged
```

- [ ] **Step 3: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Features/Pulse/PulseStore.swift
git commit -m "feat: pass SettingsStore to pipeline refresh calls in PulseStore"
```

---

## Task 7: Create GenericRSSClient and GenericRSSPipeline

**Files:**
- Create: `Glance/Core/Network/GenericRSSClient.swift`
- Create: `Glance/Features/GenericRSS/GenericRSSPipeline.swift`

**Interfaces:**
- Consumes: `MMArticle` model from `ManagingMadridClient.swift`
- Produces: `GenericRSSClient.fetchArticles(from:)`, `GenericRSSPipeline.refresh(feed:)`

- [ ] **Step 1: Create GenericRSSClient**

Create `Glance/Core/Network/GenericRSSClient.swift`:

```swift
import Foundation

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

private final class GenericRSSParser: NSObject, XMLParserDelegate {
    private var articles: [MMArticle] = []
    private var current: GenericRSSItem?
    private var textBuffer = ""

    func parse(data: Data) -> [MMArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Array(articles.prefix(20))
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Support both RSS <item> and Atom <entry>
        if elementName == "item" || elementName == "entry" {
            current = GenericRSSItem()
        }
        if elementName == "link", let href = attributeDict["href"] {
            current?.url = href
        }
        if elementName == "link", current?.url.isEmpty == true {
            // RSS <link> element with text content
            textBuffer = ""
            return
        }
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard var item = current else { return }
        switch elementName {
        case "title":
            item.title = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "link":
            if item.url.isEmpty {
                item.url = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case "published", "pubDate", "updated":
            item.published = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "author", "name" where item.author.isEmpty:
            item.author = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "category":
            item.category = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "description", "summary", "content", "content:encoded":
            item.content = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "item", "entry":
            let article = MMArticle(
                id: item.url.isEmpty ? UUID().uuidString : item.url,
                title: item.title,
                url: item.url,
                published: item.published,
                author: item.author,
                category: item.category,
                content: item.content
            )
            articles.append(article)
            current = nil
            return
        default: break
        }
        current = item
    }
}

private struct GenericRSSItem {
    var title = ""
    var url = ""
    var published = ""
    var author = ""
    var category = ""
    var content = ""
}
```

- [ ] **Step 2: Create GenericRSSPipeline**

Create the directory and file `Glance/Features/GenericRSS/GenericRSSPipeline.swift`:

```swift
import Foundation

struct GenericRSSPipeline: Sendable {
    private let client: GenericRSSClient
    private let cache: CacheStore

    init(client: GenericRSSClient = GenericRSSClient(), cache: CacheStore = .shared) {
        self.client = client
        self.cache = cache
    }

    func refresh(feed: CustomRSSFeed) async -> [MMArticle] {
        guard feed.isEnabled, !feed.url.isEmpty else { return [] }
        return (try? await client.fetchArticles(from: feed.url)) ?? []
    }

    func refreshAll(feeds: [CustomRSSFeed]) async -> [String: [MMArticle]] {
        var results: [String: [MMArticle]] = [:]
        for feed in feeds {
            let articles = await refresh(feed: feed)
            if !articles.isEmpty {
                results[feed.id.uuidString] = articles
            }
        }
        return results
    }
}
```

- [ ] **Step 3: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Core/Network/GenericRSSClient.swift Glance/Features/GenericRSS/GenericRSSPipeline.swift
git commit -m "feat: add GenericRSSClient and GenericRSSPipeline for custom feeds"
```

---

## Task 8: Integrate Custom RSS Feeds into PulseStore

**Files:**
- Modify: `Glance/Features/Pulse/PulseStore.swift:1-179`
- Modify: `Glance/Features/Pulse/PulseView.swift:1-50`

**Interfaces:**
- Consumes: `GenericRSSPipeline`, `CustomRSSFeed`, `MMArticle`
- Produces: custom RSS cards displayed in the feed

- [ ] **Step 1: Add custom RSS state to PulseStore**

In `Glance/Features/Pulse/PulseStore.swift`, add custom RSS support:

```swift
@MainActor
@Observable
final class PulseStore {
    var madrid: CardState<MadridData> = .loading
    var pogo: CardState<PoGoData> = .loading
    var github: CardState<GitHubData> = .loading
    var aiIntel: CardState<AiIntelData> = .loading
    var customRSSCards: [String: CardState<[MMArticle]>] = [:]

    // ... existing properties ...

    private let genericRSSPipeline: GenericRSSPipeline

    init(
        // ... existing params ...
        genericRSSPipeline: GenericRSSPipeline = GenericRSSPipeline()
    ) {
        // ... existing assignments ...
        self.genericRSSPipeline = genericRSSPipeline
    }
```

- [ ] **Step 2: Add refreshCustomRSS method**

Add this method to `PulseStore`:

```swift
func refreshCustomRSS() async {
    let feeds = settingsStore.customRSSFeeds
    for feed in feeds {
        guard feed.isEnabled else {
            customRSSCards[feed.id.uuidString] = nil
            continue
        }
        let articles = await genericRSSPipeline.refresh(feed: feed)
        if articles.isEmpty {
            customRSSCards[feed.id.uuidString] = .error(message: "No articles found")
        } else {
            customRSSCards[feed.id.uuidString] = .ready(data: articles, age: "just now")
        }
    }
    // Remove cards for deleted feeds
    let activeIDs = Set(feeds.map(\.id.uuidString))
    for key in customRSSCards.keys where !activeIDs.contains(key) {
        customRSSCards.removeValue(forKey: key)
    }
}
```

- [ ] **Step 3: Update refreshAll to include custom RSS**

In the `refreshAll()` method, add:

```swift
func refreshAll() async {
    await refresh(.madrid, force: true)
    await refresh(.pogo, force: true)
    await refresh(.github, force: true)
    await refresh(.aiIntel, force: true)
    await refreshCustomRSS()
}
```

- [ ] **Step 4: Update PulseView to show custom RSS cards**

In `Glance/Features/Pulse/PulseView.swift`, add custom RSS cards to the `sortedCards` computed property and add a card view for them. After the existing `ForEach` for built-in cards, add:

```swift
// In the ForEach loop, after GlanceCardView for built-in cards,
// add custom RSS cards:

ForEach(Array(store.customRSSCards.keys.sorted()), id: \.self) { feedID in
    if case .ready(let articles, _) = store.customRSSCards[feedID] {
        let feedName = settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID })?.name ?? "Custom Feed"
        // Create a card view for the custom RSS feed
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rss")
                    .foregroundStyle(Theme.Colors.cardAmber)
                Text(feedName)
                    .font(Theme.Fonts.manrope(14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Text("\(articles.count) articles")
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }

            ForEach(articles.prefix(3)) { article in
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(Theme.Fonts.manrope(13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)
                    if !article.author.isEmpty {
                        Text(article.author)
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
            }
        }
        .padding(Theme.cardPadding)
        .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Colors.borderSubtle.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, Theme.cardPadding)
    }
}
```

- [ ] **Step 5: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Glance/Features/Pulse/PulseStore.swift Glance/Features/Pulse/PulseView.swift
git commit -m "feat: integrate custom RSS feeds into PulseStore and feed view"
```

---

## Task 9: Clean Up SourcesView

**Files:**
- Modify: `Glance/Settings/SourcesView.swift:1-305`

**Interfaces:**
- Consumes: nothing (removing from navigation)
- Produces: SourcesView kept as reference but not used in tab navigation

- [ ] **Step 1: Remove SourcesView from navigation**

SourcesView is no longer referenced in ContentView (Task 1 replaced it with ProviderView). The file can be kept for reference or deleted. To keep it clean, add a deprecation comment at the top:

```swift
// DEPRECATED: API key management moved to SettingsView.
// Provider configuration moved to ProviderView.
// This file is kept for reference only.
```

- [ ] **Step 2: Verify build compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Settings/SourcesView.swift
git commit -m "chore: deprecate SourcesView, keys moved to SettingsView"
```

---

## Task 10: Final Verification

**Files:**
- All modified files

- [ ] **Step 1: Full build verification**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Verify navigation structure**

Confirm in ContentView.swift:
- Bottom nav shows 3 tabs: Feed, Providers, Settings
- No reference to `.sources` tab remains

- [ ] **Step 3: Verify SettingsView has API keys section**

Confirm SettingsView.swift:
- No `cardVisibilitySection` reference
- `apiKeysSection` present with Exa, Gemini, Football Data inputs

- [ ] **Step 4: Verify ProviderView has all provider cards**

Confirm ProviderView.swift:
- 4 built-in provider cards (Madrid, PoGo, GitHub, AI Intel)
- Each has toggle + input fields
- Custom RSS feeds section with add/remove

- [ ] **Step 5: Verify pipelines read from SettingsStore**

Confirm each pipeline's `refresh()` method accepts `settings: SettingsStore` parameter.

- [ ] **Step 6: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "feat: complete provider restructure - navigation, settings, provider view, custom RSS"
```
