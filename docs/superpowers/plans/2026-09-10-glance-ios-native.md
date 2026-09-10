# Glance Native iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS SwiftUI app that replicates the Glance Capacitor web app — 4-card intelligence dashboard with TikTok-style paging, on-device AI, and offline-first caching.

**Architecture:** Protocol-oriented SwiftUI with `@Observable` stores, `async/await` networking, Foundation Models for on-device AI with Gemini REST fallback. Single Xcode target with folder-layer organization.

**Tech Stack:** Swift 6.2+, iOS 26+, SwiftUI, Foundation Models (`LanguageModelSession`, `@Generable`), URLSession, Keychain Services, XCTest + XCUITest

**Spec:** `docs/glance-native-prd.md`

---

## Global Constraints

- iOS 26+ deployment target
- Swift 6.2+, strict concurrency
- No third-party dependencies (SwiftUI + Foundation only)
- API keys in Keychain (no biometric)
- Cache keys must match Capacitor string keys for migration
- Bundle ID: `com.atifkhan.glance`
- Dark-only Obsidian theme
- One file per type
- `@Observable` + `@MainActor` for shared state
- `NavigationStack` (not `NavigationView`)
- `foregroundStyle()` not `foregroundColor()`
- `Tab` items with enum selection (not integer)
- `task()` over `onAppear()` for async work
- `#Preview` (not `PreviewProvider`)
- Tap targets ≥ 44×44pt
- VoiceOver labels on all interactive elements
- Honor `accessibilityReduceMotion`

---

## File Structure

```
Glance/
├── App/
│   ├── GlanceApp.swift
│   └── AppState.swift
├── Core/
│   ├── Cache/
│   │   ├── CacheEnvelope.swift
│   │   ├── CacheStore.swift
│   │   └── KeychainStore.swift
│   ├── Network/
│   │   ├── ExaClient.swift
│   │   ├── GeminiClient.swift
│   │   ├── GitHubClient.swift
│   │   ├── ScrapedDuckClient.swift
│   │   └── ManagingMadridClient.swift
│   ├── Intelligence/
│   │   ├── FoundationModelsClient.swift
│   │   ├── IntelligenceRouter.swift
│   │   └── Models.swift
│   └── Time/
│       └── TimeFormat.swift
├── Features/
│   ├── Pulse/
│   │   ├── PulseView.swift
│   │   ├── PulseStore.swift
│   │   └── GlanceCardView.swift
│   ├── Madrid/
│   │   ├── MadridPipeline.swift
│   │   ├── MadridModels.swift
│   │   ├── MadridHubView.swift
│   │   └── MadridArticleView.swift
│   ├── PoGo/
│   │   ├── PoGoPipeline.swift
│   │   ├── PoGoModels.swift
│   │   ├── PoGoHubView.swift
│   │   ├── RaidDetailView.swift
│   │   └── EventDetailView.swift
│   ├── GitHub/
│   │   ├── GitHubPipeline.swift
│   │   ├── GitHubModels.swift
│   │   ├── GitHubHubView.swift
│   │   └── RepoDetailView.swift
│   └── AiIntel/
│       ├── AiIntelPipeline.swift
│       ├── AiIntelModels.swift
│       └── AiIntelArticleView.swift
├── Settings/
│   ├── SourcesView.swift
│   ├── SettingsView.swift
│   └── SettingsStore.swift
├── DesignSystem/
│   ├── Theme.swift
│   ├── GlanceBadge.swift
│   ├── SkeletonView.swift
│   └── PulseDot.swift
├── Shared/
│   ├── Enums.swift
│   └── Extensions.swift
├── Glance.xcodeproj
├── GlanceTests/
│   ├── MadridPipelineTests.swift
│   ├── PoGoPipelineTests.swift
│   ├── GitHubPipelineTests.swift
│   ├── AiIntelPipelineTests.swift
│   ├── CacheStoreTests.swift
│   ├── KeychainStoreTests.swift
│   └── TimeFormatTests.swift
├── GlanceUITests/
│   ├── PulseFlowUITests.swift
│   └── SourcesFlowUITests.swift
└── Resources/
    ├── Fonts/
    │   ├── Manrope-Regular.ttf
    │   ├── Manrope-SemiBold.ttf
    │   ├── Manrope-Bold.ttf
    │   ├── Manrope-ExtraBold.ttf
    │   ├── HankenGrotesk-Regular.ttf
    │   ├── HankenGrotesk-SemiBold.ttf
    │   └── HankenGrotesk-Bold.ttf
    ├── Glance.xcassets/
    │   ├── AppIcon.appiconset/  (from Capacitor)
    │   ├── AccentColor.colorset/
    │   ├── Canvas.colorset/
    │   ├── CardAmber.colorset/
    │   ├── CardRose.colorset/
    │   ├── CardEmerald.colorset/
    │   └── CardCyan.colorset/
    └── TestFixtures/
        ├── raids.json
        ├── events.json
        ├── madrid-search.json
        └── repositories.json
```

---

### Task 1: Xcode Project + Asset Catalog + Fonts

**Files:**
- Create: `Glance.xcodeproj` (via `xcodebuild` or Xcode)
- Create: `Resources/Glance.xcassets/` with all color sets
- Create: `Resources/Fonts/` with Manrope + Hanken Grotesk .ttf files

**Interfaces:**
- Produces: Xcode project that builds and runs on iOS 26+ simulator

- [ ] **Step 1: Create Xcode project**

```bash
# Use xcodegen or manual Xcode creation
# Bundle ID: com.atifkhan.glance
# Deployment target: iOS 26.0
# Swift version: 6.2
# Supported orientations: portrait only
```

- [ ] **Step 2: Import app icons**

Copy `ios/App/App/Assets.xcassets/AppIcon.appiconset/` into `Resources/Glance.xcassets/AppIcon.appiconset/`

- [ ] **Step 3: Create color sets in asset catalog**

Create Color Sets in `Glance.xcassets`:
- `Canvas` — Any: `#0F131D`, Dark: `#0F131D`
- `CardAmber` — Any: `#F5A623`, Dark: `#F5A623`
- `CardRose` — Any: `#FB7185`, Dark: `#FB7185`
- `CardEmerald` — Any: `#34D399`, Dark: `#34D399`
- `CardCyan` — Any: `#22D3EE`, Dark: `#22D3EE`
- `AccentColor` — Any: `#4EDEA3`, Dark: `#4EDEA3`
- Surface1: `#171B26`, Surface2: `#1E222E`, Surface3: `#252A37`
- BorderSubtle: `#334155`
- TextPrimary: `#F8FAFC`, TextSecondary: `#94A3B8`, TextMuted: `#64748B`
- Error: `#FFB4AB`

- [ ] **Step 4: Import fonts**

Convert Manrope + Hanken Grotesk .woff2 to .ttf (using `fonttools` or download .ttf versions). Add to `Resources/Fonts/`. Add to Info.plist `UIAppFonts`.

- [ ] **Step 5: Create folder structure**

Create all empty Swift files in the structure above so the project compiles.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: scaffold Xcode project with assets, fonts, and folder structure"
```

---

### Task 2: Core — CacheEnvelope + CacheStore + KeychainStore

**Files:**
- Create: `Core/Cache/CacheEnvelope.swift`
- Create: `Core/Cache/CacheStore.swift`
- Create: `Core/Cache/KeychainStore.swift`
- Test: `GlanceTests/CacheStoreTests.swift`
- Test: `GlanceTests/KeychainStoreTests.swift`

**Interfaces:**
- Produces: `CacheStore` actor with `load<T>()`, `save<T>()`, `remove()`, `clearAll()`, `hydrate()`
- Produces: `KeychainStore` with `save()`, `load()`, `remove()`
- Produces: `CacheEnvelope<T>` with `isExpired` computed property

- [ ] **Step 1: Write CacheEnvelope**

```swift
// Core/Cache/CacheEnvelope.swift
import Foundation

struct CacheEnvelope<T: Codable & Sendable>: Codable, Sendable {
    let timestampMs: Int64
    let ttlMs: Int64?
    let data: T

    var isExpired: Bool {
        ttlMs.map { Date.now.millisecondsSinceEpoch - timestampMs > $0 } ?? false
    }

    init(data: T, ttlMs: Int64? = nil) {
        self.timestampMs = Date.now.millisecondsSinceEpoch
        self.ttlMs = ttlMs
        self.data = data
    }
}
```

- [ ] **Step 2: Write CacheStore tests**

```swift
// GlanceTests/CacheStoreTests.swift
import Testing
@testable import Glance

@Suite("CacheStore")
struct CacheStoreTests {
    @Test("Save and load round-trip")
    func roundTrip() async {
        let store = CacheStore.preview
        let envelope = CacheEnvelope(data: "test-value", ttlMs: 60_000)
        await store.save("test-key", envelope: envelope)
        let loaded: CacheEnvelope<String>? = await store.load("test-key")
        #expect(loaded?.data == "test-value")
        #expect(loaded?.isExpired == false)
    }

    @Test("Expired envelope reports expired")
    func expired() async {
        let envelope = CacheEnvelope(data: "old", ttlMs: 0)
        #expect(envelope.isExpired == true)
    }

    @Test("Permanent envelope never expires")
    func permanent() async {
        let envelope = CacheEnvelope(data: "forever", ttlMs: nil)
        #expect(envelope.isExpired == false)
    }

    @Test("ClearAll keeps keychain keys")
    func clearAll() async {
        let store = CacheStore.preview
        await store.save("cache_test", envelope: CacheEnvelope(data: "x", ttlMs: nil))
        await store.clearAll()
        let loaded: CacheEnvelope<String>? = await store.load("cache_test")
        #expect(loaded == nil)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `xctest GlanceTests.CacheStoreTests`
Expected: FAIL (types not defined)

- [ ] **Step 4: Implement CacheStore**

```swift
// Core/Cache/CacheStore.swift
import Foundation

actor CacheStore {
    static let shared = CacheStore()
    static let preview = CacheStore()

    private var memory: [String: Data] = [:]
    private let defaults = UserDefaults.standard

    func hydrate() {
        for key in Self.allCacheKeys {
            if let data = defaults.data(forKey: key) {
                memory[key] = data
            }
        }
    }

    func load<T: Codable>(_ key: String) async -> CacheEnvelope<T>? {
        if let data = memory[key],
           let envelope = try? JSONDecoder().decode(CacheEnvelope<T>.self, from: data) {
            return envelope
        }
        return nil
    }

    func save<T: Codable>(_ key: String, envelope: CacheEnvelope<T>) async {
        if let data = try? JSONEncoder().encode(envelope) {
            memory[key] = data
            defaults.set(data, forKey: key)
        }
    }

    func remove(_ key: String) async {
        memory.removeValue(forKey: key)
        defaults.removeObject(forKey: key)
    }

    func clearAll() async {
        for key in Self.allCacheKeys {
            memory.removeValue(forKey: key)
            defaults.removeObject(forKey: key)
        }
    }

    static let allCacheKeys = [
        "cache_madrid", "cache_pogo", "cache_github", "cache_aiintel",
        "cache_scrapedd", "cache_github_raw",
        "gemini_model"
    ]
}

extension Date {
    var millisecondsSinceEpoch: Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `xctest GlanceTests.CacheStoreTests`
Expected: PASS

- [ ] **Step 6: Write KeychainStore**

```swift
// Core/Cache/KeychainStore.swift
import Foundation
import Security

struct KeychainStore {
    func save(key: String, value: String) async throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    func load(key: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func remove(key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}
```

- [ ] **Step 7: Write KeychainStore tests**

```swift
// GlanceTests/KeychainStoreTests.swift
import Testing
@testable import Glance

@Suite("KeychainStore")
struct KeychainStoreTests {
    @Test("Save and load key")
    func roundTrip() async throws {
        let store = KeychainStore()
        let testKey = "test_key_\(UUID().uuidString)"
        try await store.save(key: testKey, value: "secret123")
        let loaded = await store.load(key: testKey)
        #expect(loaded == "secret123")
    }

    @Test("Load missing key returns nil")
    func missingKey() async {
        let store = KeychainStore()
        let loaded = await store.load(key: "nonexistent_\(UUID().uuidString)")
        #expect(loaded == nil)
    }
}
```

- [ ] **Step 8: Run all cache tests**

Run: `xctest GlanceTests`
Expected: PASS

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: CacheStore actor + KeychainStore with tests"
```

---

### Task 3: Core — Network Clients (Exa, Gemini, GitHub, ScrapedDuck, ManagingMadrid)

**Files:**
- Create: `Core/Network/ExaClient.swift`
- Create: `Core/Network/GeminiClient.swift`
- Create: `Core/Network/GitHubClient.swift`
- Create: `Core/Network/ScrapedDuckClient.swift`
- Create: `Core/Network/ManagingMadridClient.swift`

**Interfaces:**
- Produces: `ExaClientProtocol`, `GeminiClientProtocol`, etc.
- Produces: Concrete client implementations with `async/await` methods
- Consumes: API keys from `KeychainStore`

- [ ] **Step 1: Write ExaClient protocol + implementation**

```swift
// Core/Network/ExaClient.swift
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
}

struct ExaClient: ExaClientProtocol {
    func search(query: String, apiKey: String) async throws -> [ExaResult] {
        var request = URLRequest(url: URL(string: "https://api.exa.ai/search")!)
        request.httpMethod = "POST"
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "query": query,
            "type": "auto",
            "contents": ["highlights": true]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GlanceError.networkError(URLError(.badServerResponse))
        }
        let decoded = try JSONDecoder().decode(ExaResponse.self, from: data)
        return decoded.results
    }
}

private struct ExaResponse: Codable {
    let results: [ExaResult]
}
```

- [ ] **Step 2: Write GeminiClient with retry ladder**

```swift
// Core/Network/GeminiClient.swift
import Foundation

protocol GeminiClientProtocol: Sendable {
    func generate(prompt: String, model: String, apiKey: String) async throws -> String?
}

struct GeminiClient: GeminiClientProtocol {
    func generate(prompt: String, model: String, apiKey: String) async throws -> String? {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0..<3 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 200 {
                    let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    return decoded.candidates?.first?.content?.parts?.first?.text
                }
                if http.statusCode == 429 || http.statusCode == 503 {
                    let delay: UInt64 = http.statusCode == 429
                        ? [1_000_000_000, 2_000_000_000, 4_000_000_000][attempt]
                        : [5_000_000_000, 15_000_000_000, 45_000_000_000][attempt]
                    try await Task.sleep(for: .nanoseconds(delay))
                    continue
                }
                return nil
            } catch {
                if attempt < 2 { try await Task.sleep(for: .seconds(1)) }
            }
        }
        return nil
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
```

- [ ] **Step 3: Write GitHubClient**

```swift
// Core/Network/GitHubClient.swift
import Foundation

protocol GitHubClientProtocol: Sendable {
    func searchRepos(since: String) async throws -> GitHubSearchResult
}

struct GitHubSearchResult: Codable, Sendable {
    let totalCount: Int
    let items: [GitHubRepo]
    let rateLimitRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
        case rateLimitRemaining
    }
}

struct GitHubRepo: Codable, Sendable, Identifiable {
    let fullName: String
    let description: String?
    let language: String?
    let stars: Int
    let forks: Int
    let openIssues: Int
    let watchers: Int
    let pushedAt: String?
    let createdAt: String?
    let hasWiki: Bool
    let hasPages: Bool
    let hasDiscussions: Bool
    let topics: [String]
    let license: LicenseInfo?
    let ownerLogin: String
    let ownerAvatar: String
    let htmlUrl: String
    let homepage: String?

    var id: String { fullName }

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case description, language
        case stars = "stargazers_count"
        case forks = "forks_count"
        case openIssues = "open_issues_count"
        case watchers = "watchers_count"
        case pushedAt = "pushed_at"
        case createdAt = "created_at"
        case hasWiki = "has_wiki"
        case hasPages = "has_pages"
        case hasDiscussions = "has_discussions"
        case topics, license
        case ownerLogin = "owner_login"
        case ownerAvatar = "owner_avatar"
        case htmlUrl = "html_url"
        case homepage
    }
}

struct LicenseInfo: Codable, Sendable {
    let name: String?
}

struct GitHubClient: GitHubClientProtocol {
    func searchRepos(since: String) async throws -> GitHubSearchResult {
        let query = "topic:llm+topic:ai+created:>\(since)&sort=stars&order=desc"
        let url = URL(string: "https://api.github.com/search/repositories?q=\(query)&per_page=10")!
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GlanceError.networkError(URLError(.badServerResponse))
        }
        if http.statusCode == 403 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After")
            throw GlanceError.rateLimited(retryAfter: retryAfter.flatMap { Double($0) })
        }
        var result = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
        if let remaining = http.value(forHTTPHeaderField: "x-ratelimit-remaining") {
            result = GitHubSearchResult(
                totalCount: result.totalCount,
                items: result.items,
                rateLimitRemaining: Int(remaining)
            )
        }
        return result
    }
}
```

- [ ] **Step 4: Write ScrapedDuckClient**

```swift
// Core/Network/ScrapedDuckClient.swift
import Foundation

protocol ScrapedDuckClientProtocol: Sendable {
    func fetchRaids() async throws -> [PoGoRaid]
    func fetchEvents() async throws -> [PoGoEvent]
}

struct ScrapedDuckClient: ScrapedDuckClientProtocol {
    func fetchRaids() async throws -> [PoGoRaid] {
        let url = URL(string: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoRaid].self, from: data)
    }

    func fetchEvents() async throws -> [PoGoEvent] {
        let url = URL(string: "https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([PoGoEvent].self, from: data)
    }
}
```

- [ ] **Step 5: Write ManagingMadridClient (XML Parser)**

```swift
// Core/Network/ManagingMadridClient.swift
import Foundation

protocol ManagingMadridClientProtocol: Sendable {
    func fetchArticles() async throws -> [MMArticle]
}

struct MMArticle: Codable, Sendable, Identifiable {
    let id: String
    let title: String
    let url: String
    let published: String
    let author: String
    let category: String
    let content: String
}

struct ManagingMadridClient: ManagingMadridClientProtocol {
    func fetchArticles() async throws -> [MMArticle] {
        let url = URL(string: "https://www.managingmadrid.com/rss/index.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = MMXMLParser()
        return parser.parse(data: data)
    }
}

private class MMXMLParser: NSObject, XMLParserDelegate {
    private var articles: [MMArticle] = []
    private var current: MMXMLItem?
    private var textBuffer = ""

    func parse(data: Data) -> [MMArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "entry" { current = MMXMLItem() }
        if elementName == "link", let href = attributeDict["href"] { current?.url = href }
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard var item = current else { return }
        switch elementName {
        case "title": item.title = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "published": item.published = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "author": item.author = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "category": item.category = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "content": item.content = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "entry":
            item.id = item.url.hashValue.description
            articles.append(item)
            current = nil
        default: break
        }
        current = item
    }
}

private struct MMXMLItem {
    var id = ""
    var title = ""
    var url = ""
    var published = ""
    var author = ""
    var category = ""
    var content = ""
}
```

- [ ] **Step 6: Write GlanceError**

Add to `Shared/Enums.swift`:

```swift
// Shared/Enums.swift
import Foundation

enum GlanceError: Error, Equatable {
    case keyMissing(String)
    case networkError(String)
    case rateLimited(retryAfter: Double?)
    case decodingError(String)

    static func == (lhs: GlanceError, rhs: GlanceError) -> Bool {
        switch (lhs, rhs) {
        case (.keyMissing(let a), .keyMissing(let b)): a == b
        case (.networkError(let a), .networkError(let b)): a == b
        case (.rateLimited(let a), .rateLimited(let b)): a == b
        case (.decodingError(let a), .decodingError(let b)): a == b
        default: false
        }
    }
}
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: network clients (Exa, Gemini, GitHub, ScrapedDuck, ManagingMadrid)"
```

---

### Task 4: Core — Intelligence Layer (Foundation Models + Router)

**Files:**
- Create: `Core/Intelligence/Models.swift`
- Create: `Core/Intelligence/FoundationModelsClient.swift`
- Create: `Core/Intelligence/IntelligenceRouter.swift`

**Interfaces:**
- Produces: `@Generable` structs for each card's enrichment
- Produces: `IntelligenceRouter` with three-tier fallback
- Consumes: `FoundationModelsClient`, `GeminiClient`

- [ ] **Step 1: Write @Generable models**

```swift
// Core/Intelligence/Models.swift
import FoundationModels

@Generable
struct RealMadridEnrichment {
    @Guide(description: "Recent form results, e.g. ['W 2-0', 'D 1-1']")
    var form: [String]

    @Guide(description: "Current La Liga standing, one line")
    var standing: String

    @Guide(description: "Tactical intel summary, 2 sentences")
    var intel: String

    @Guide(description: "Head-to-head record, e.g. '13 previous meetings'")
    var headToHead: String?
}

@Generable
struct PoGoPriority {
    @Guide(description: "One sentence naming the top priority raid target and why")
    var priority: String
}

@Generable
struct AiIntelItem {
    @Guide(description: "FRONTIER LABS or OPEN WEIGHTS")
    var tag: String

    @Guide(description: "Short headline")
    var headline: String

    @Guide(description: "1-2 bullet points")
    var bullets: [String]

    @Guide(description: "Benchmark names if applicable")
    var benchmarks: [String]?
}

@Generable
struct AiIntelItems {
    @Guide(description: "2-3 classified news items")
    var items: [AiIntelItem]
}
```

- [ ] **Step 2: Write FoundationModelsClient**

```swift
// Core/Intelligence/FoundationModelsClient.swift
import FoundationModels

struct FoundationModelsClient {
    private let session: LanguageModelSession

    init() {
        session = LanguageModelSession()
    }

    func processRealMadrid(snippets: String) async throws -> RealMadridEnrichment {
        let prompt = "Extract Real Madrid enrichment (recent form results, La Liga standing, tactical intel summary, head-to-head record) from these snippets: \(snippets)"
        let response = try await session.respond(to: prompt)
        return response
    }

    func processPoGo(snippets: String) async throws -> PoGoPriority {
        let prompt = "From these Pokemon GO raid/event snippets, write one sentence naming the top priority raid target and why: \(snippets)"
        let response = try await session.respond(to: prompt)
        return response
    }

    func processAiIntel(snippets: String) async throws -> AiIntelItems {
        let prompt = "Read these technology news summaries and for each one, classify it as coming from a major research lab or an open-source community project. Return 2-3 items with a short headline and 1-2 bullet points summarizing the key detail. Snippets: \(snippets)"
        let response = try await session.respond(to: prompt)
        return response
    }
}
```

- [ ] **Step 3: Write IntelligenceRouter**

```swift
// Core/Intelligence/IntelligenceRouter.swift
import FoundationModels

actor IntelligenceRouter {
    private let foundationModels: FoundationModelsClient
    private let geminiClient: GeminiClient
    private let keychain: KeychainStore

    init(foundationModels: FoundationModelsClient = .init(),
         geminiClient: GeminiClient = .init(),
         keychain: KeychainStore = .init()) {
        self.foundationModels = foundationModels
        self.geminiClient = geminiClient
        self.keychain = keychain
    }

    func processRealMadrid(snippets: String) async -> RealMadridEnrichment? {
        // 1. Try on-device Foundation Models
        if let result = try? await foundationModels.processRealMadrid(snippets: truncate(snippets)) {
            return result
        }
        // 2. Fall back to Gemini
        if let key = await keychain.load(key: "keys_gemini"),
           let model = await keychain.load(key: "gemini_model") {
            let prompt = "Extract Real Madrid enrichment from these snippets: \(truncate(snippets))\n\nReturn JSON with keys: form (array of strings), standing (string), intel (string), head_to_head (string optional)\n\nRaw data:\n\(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: model, apiKey: key),
               let data = text.data(using: .utf8),
               let enriched = try? JSONDecoder().decode(RealMadridEnrichment.self, from: data) {
                return enriched
            }
        }
        // 3. Raw fallback
        return nil
    }

    func processPoGo(snippets: String) async -> PoGoPriority? {
        if let result = try? await foundationModels.processPoGo(snippets: truncate(snippets)) {
            return result
        }
        if let key = await keychain.load(key: "keys_gemini"),
           let model = await keychain.load(key: "gemini_model") {
            let prompt = "From these Pokemon GO raid/event snippets, write one sentence naming the top priority raid target and why: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: model, apiKey: key) {
                if let data = text.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode(PoGoPriority.self, from: data) {
                    return decoded
                }
                return PoGoPriority(priority: text)
            }
        }
        return nil
    }

    func processAiIntel(snippets: String) async -> AiIntelItems? {
        if let result = try? await foundationModels.processAiIntel(snippets: truncate(snippets)) {
            return result
        }
        if let key = await keychain.load(key: "keys_gemini"),
           let model = await keychain.load(key: "gemini_model") {
            let prompt = "Read these technology news summaries and classify each. Return 2-3 items with tag (FRONTIER LABS or OPEN WEIGHTS), headline, bullets, benchmarks optional. Snippets: \(truncate(snippets))"
            if let text = try? await geminiClient.generate(prompt: prompt, model: model, apiKey: key),
               let data = text.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(AiIntelItems.self, from: data) {
                return decoded
            }
        }
        return nil
    }

    private func truncate(_ text: String, maxChars: Int = 6000) -> String {
        text.count > maxChars ? String(text.prefix(maxChars)) : text
    }
}
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: intelligence layer — Foundation Models + Gemini fallback + router"
```

---

### Task 5: Core — TimeFormat utility

**Files:**
- Create: `Core/Time/TimeFormat.swift`
- Test: `GlanceTests/TimeFormatTests.swift`

**Interfaces:**
- Produces: `TimeFormat` with IST formatting, countdown, relative time, formatAge, formatStars

- [ ] **Step 1: Write TimeFormat tests**

```swift
// GlanceTests/TimeFormatTests.swift
import Testing
@testable import Glance

@Suite("TimeFormat")
struct TimeFormatTests {
    @Test("formatAge under 60s")
    func ageSeconds() {
        let date = Date.now.addingTimeInterval(-30)
        #expect(TimeFormat.age(from: date) == "just now")
    }

    @Test("formatAge under 60m")
    func ageMinutes() {
        let date = Date.now.addingTimeInterval(-300)
        #expect(TimeFormat.age(from: date) == "5m ago")
    }

    @Test("formatAge under 24h")
    func ageHours() {
        let date = Date.now.addingTimeInterval(-7200)
        #expect(TimeFormat.age(from: date) == "2h ago")
    }

    @Test("formatStars thousands")
    func starsThousands() {
        #expect(TimeFormat.stars(12400) == "12.4k")
    }

    @Test("formatStars small")
    func starsSmall() {
        #expect(TimeFormat.stars(523) == "523")
    }

    @Test("countdownTo future")
    func countdownFuture() {
        let date = Date.now.addingTimeInterval(7200)
        let result = TimeFormat.countdownTo(date)
        #expect(result.contains("in"))
    }

    @Test("countdownTo past returns empty")
    func countdownPast() {
        let date = Date.now.addingTimeInterval(-100)
        #expect(TimeFormat.countdownTo(date) == "")
    }
}
```

- [ ] **Step 2: Implement TimeFormat**

```swift
// Core/Time/TimeFormat.swift
import Foundation

enum TimeFormat {
    private static let ist = TimeZone(identifier: "Asia/Kolkata")!

    static func age(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    static func stars(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    static func countdownTo(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval < 0 || interval < 60 { return interval >= 0 ? "starting now" : "" }
        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if days > 0 { return "in \(days)d \(hours)h" }
        if hours > 0 { return "in \(hours)h \(minutes)m" }
        return "in \(minutes)m"
    }

    static func istDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ist
        formatter.dateFormat = "EEE, MMM d · h:mm a"
        return formatter.string(from: date) + " IST"
    }

    static func relativeDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ist
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date.now)
        let target = formatter.string(from: date)
        if today == target { return "Today" }
        let tomorrow = formatter.string(from: Date.now.addingTimeInterval(86400))
        if tomorrow == target { return "Tomorrow" }
        return formatter.string(from: date)
    }

    static func endsIn(_ endDate: Date) -> String {
        let interval = endDate.timeIntervalSinceNow
        if interval < 0 { return "" }
        let hours = Int(interval / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        if hours >= 24 { return "Ends in \(hours / 24)d" }
        if hours > 0 { return "Ends in \(hours)h" }
        return "Ends in \(minutes)m"
    }

    static func relativeTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = ist
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date.now)
        let target = formatter.string(from: date)
        if today == target { return "today" }
        let yesterday = formatter.string(from: Date.now.addingTimeInterval(-86400))
        if yesterday == target { return "yesterday" }
        let days = Int(-date.timeIntervalSinceNow / 86400)
        return "\(days)d ago"
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xctest GlanceTests.TimeFormatTests`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: TimeFormat utility with IST, countdown, relative time"
```

---

### Task 6: DesignSystem — Theme, GlanceBadge, SkeletonView, PulseDot

**Files:**
- Create: `DesignSystem/Theme.swift`
- Create: `DesignSystem/GlanceBadge.swift`
- Create: `DesignSystem/SkeletonView.swift`
- Create: `DesignSystem/PulseDot.swift`

**Interfaces:**
- Produces: `Theme` enum with colors, fonts, spacing
- Produces: Reusable UI components

- [ ] **Step 1: Write Theme**

```swift
// DesignSystem/Theme.swift
import SwiftUI

enum Theme {
    static let canvas = Color("Canvas")
    static let surface1 = Color(red: 0.09, green: 0.106, blue: 0.15)    // #171B26
    static let surface2 = Color(red: 0.118, green: 0.133, blue: 0.18)   // #1E222E
    static let surface3 = Color(red: 0.145, green: 0.165, blue: 0.216)  // #252A37
    static let borderSubtle = Color(red: 0.2, green: 0.255, blue: 0.333) // #334155

    static let textPrimary = Color(red: 0.973, green: 0.98, blue: 0.988)  // #F8FAFC
    static let textSecondary = Color(red: 0.58, green: 0.639, blue: 0.722) // #94A3B8
    static let textMuted = Color(red: 0.392, green: 0.455, blue: 0.545)    // #64748B

    static let cardAmber = Color("CardAmber")
    static let cardRose = Color("CardRose")
    static let cardEmerald = Color("CardEmerald")
    static let cardCyan = Color("CardCyan")

    static let primary = Color("AccentColor") // #4EDEA3
    static let error = Color(red: 1, green: 0.706, blue: 0.667) // #FFB4AB

    static let cornerRadius: CGFloat = 20
    static let cardPadding: CGFloat = 16
    static let spacing: CGFloat = 12
}
```

- [ ] **Step 2: Write GlanceBadge**

```swift
// DesignSystem/GlanceBadge.swift
import SwiftUI

struct GlanceBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(.capsule)
    }
}
```

- [ ] **Step 3: Write SkeletonView**

```swift
// DesignSystem/SkeletonView.swift
import SwiftUI

struct SkeletonView: View {
    @State private var phase: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.2))
                .frame(height: 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.2))
                .frame(height: 16)
                .frame(maxWidth: 200)
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray.opacity(0.2))
                .frame(height: 16)
                .frame(maxWidth: 160)
        }
        .padding()
        .opacity(phase ? 0.4 : 1)
        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase = true }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 4: Write PulseDot**

```swift
// DesignSystem/PulseDot.swift
import SwiftUI

struct PulseDot: View {
    @State private var animating = false
    let color: Color

    init(color: Color = Theme.primary) {
        self.color = color
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .overlay {
                Circle()
                    .stroke(color.opacity(0.6), lineWidth: 2)
                    .scaleEffect(animating ? 2 : 1)
                    .opacity(animating ? 0 : 0.8)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                    animating = true
                }
            }
            .accessibilityHidden(true)
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: DesignSystem — Theme, GlanceBadge, SkeletonView, PulseDot"
```

---

### Task 7: Feature — Madrid Models + Pipeline

**Files:**
- Create: `Features/Madrid/MadridModels.swift`
- Create: `Features/Madrid/MadridPipeline.swift`
- Test: `GlanceTests/MadridPipelineTests.swift`

**Interfaces:**
- Produces: `MadridData`, `Fixture`, `ScheduleItem` models
- Produces: `MadridPipeline` implementing the card pipeline pattern
- Consumes: `ExaClient`, `ManagingMadridClient`, `IntelligenceRouter`, `CacheStore`

- [ ] **Step 1: Write MadridModels**

```swift
// Features/Madrid/MadridModels.swift
import Foundation

struct MadridData: Codable, Sendable {
    let fixture: Fixture?
    let schedule: [ScheduleItem]
    let form: [String]
    let standing: String
    let intel: String
    let headToHead: String?
    let articles: [ExaArticle]
    let mmArticles: [MMArticle]
    let source: String
    let timestamp: Date
}

struct Fixture: Codable, Sendable {
    let opponent: String
    let datetime: String
    let stadium: String
    let competition: String
    let scores: Score?

    struct Score: Codable, Sendable {
        let home: Int
        let away: Int
    }
}

struct ScheduleItem: Codable, Sendable {
    let opponent: String
    let datetime: String
    let competition: String
    let venue: String
}

struct ExaArticle: Codable, Sendable {
    let title: String
    let url: String
    let publishedDate: String?
    let highlights: [String]
    let image: String?
}
```

- [ ] **Step 2: Write MadridPipeline tests**

```swift
// GlanceTests/MadridPipelineTests.swift
import Testing
@testable import Glance

@Suite("MadridPipeline")
struct MadridPipelineTests {
    @Test("Normalise opponent names")
    func normaliseOpponent() {
        #expect(MadridPipeline.normaliseOpponent("inter milan") == "Inter Milan")
        #expect(MadridPipeline.normaliseOpponent("rayo") == "Rayo Vallecano")
        #expect(MadridPipeline.normaliseOpponent("atlético madrid") == "Atlético Madrid")
    }

    @Test("Loose date parse ISO format")
    func parseISODate() {
        let result = MadridPipeline.looseDateParse("2026-09-08T19:00Z")
        #expect(result != nil)
    }

    @Test("Loose date parse text format")
    func parseTextDate() {
        let result = MadridPipeline.looseDateParse("Sep 8, 7:00 PM UTC")
        #expect(result != nil)
    }

    @Test("Loose date parse returns nil for garbage")
    func parseGarbage() {
        let result = MadridPipeline.looseDateParse("not a date at all")
        #expect(result == nil)
    }
}
```

- [ ] **Step 3: Implement MadridPipeline**

Port fixture parser logic from `src/modules/madrid.js`: date parsing, opponent normalization map, schedule parsing, competition/stadium regex detection. Implement 4-step pipeline: fetch (parallel Exa + MM RSS) → parse (local fixture parser) → enrich (IntelligenceRouter) → persist (CacheStore).

- [ ] **Step 4: Run tests**

Run: `xctest GlanceTests.MadridPipelineTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: Madrid models + pipeline with fixture parser"
```

---

### Task 8: Feature — PoGo Models + Pipeline

**Files:**
- Create: `Features/PoGo/PoGoModels.swift`
- Create: `Features/PoGo/PoGoPipeline.swift`
- Test: `GlanceTests/PoGoPipelineTests.swift`

**Interfaces:**
- Produces: `PoGoData`, `PoGoRaid`, `PoGoEvent` models
- Produces: `PoGoPipeline` with local picks + priority sentence
- Consumes: `ScrapedDuckClient`, `IntelligenceRouter`, `CacheStore`

- [ ] **Step 1: Write PoGoModels**

```swift
// Features/PoGo/PoGoModels.swift
import Foundation

struct PoGoData: Codable, Sendable {
    let raids: [PoGoRaid]
    let events: [PoGoEvent]
    let fiveStar: PoGoRaid?
    let mega: PoGoRaid?
    let shadow: PoGoRaid?
    let targetPriority: String
    let credit: String
    let source: String
    let timestamp: Date
}

struct PoGoRaid: Codable, Sendable, Identifiable {
    let name: String
    let tier: String
    let canBeShiny: Bool
    let types: [PoGoType]
    let combatPower: CombatPower?
    let boostedWeather: [PoGoType]?
    let image: String?

    var id: String { name }
    var isMega: Bool { tier.contains("Mega") }
    var isShadow: Bool { name.hasPrefix("Shadow") }
    var isFiveStar: Bool { tier.contains("5-Star") }

    struct PoGoType: Codable, Sendable {
        let name: String
        let image: String
    }

    struct CombatPower: Codable, Sendable {
        let normal: CPRange?
        let boosted: CPRange?

        struct CPRange: Codable, Sendable {
            let min: Int?
            let max: Int?
        }
    }
}

struct PoGoEvent: Codable, Sendable, Identifiable {
    let eventID: String
    let name: String
    let eventType: String
    let heading: String?
    let link: String?
    let image: String?
    let start: String?
    let end: String?

    var id: String { eventID }
}
```

- [ ] **Step 2: Write PoGoPipeline tests**

```swift
// GlanceTests/PoGoPipelineTests.swift
import Testing
@testable import Glance

@Suite("PoGoPipeline")
struct PoGoPipelineTests {
    @Test("Pick fiveStar skips Shadow")
    func pickFiveStar() {
        let raids = [
            PoGoRaid(name: "Shadow Mewtwo", tier: "5-Star Raids", canBeShiny: true, types: [], combatPower: nil, boostedWeather: nil, image: nil),
            PoGoRaid(name: "Dialga", tier: "5-Star Raids", canBeShiny: true, types: [], combatPower: nil, boostedWeather: nil, image: nil)
        ]
        let pick = PoGoPipeline.pickFiveStar(raids)
        #expect(pick?.name == "Dialga")
    }

    @Test("Filter past events")
    func filterPastEvents() {
        let events = [
            PoGoEvent(eventID: "1", name: "Past", eventType: "event", heading: nil, link: nil, image: nil, start: "2020-01-01", end: "2020-01-02"),
            PoGoEvent(eventID: "2", name: "Future", eventType: "event", heading: nil, link: nil, image: nil, start: "2026-12-01", end: "2026-12-31")
        ]
        let filtered = PoGoPipeline.filterActiveEvents(events)
        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Future")
    }
}
```

- [ ] **Step 3: Implement PoGoPipeline**

Port logic from `src/modules/pogo.js`: fetch raids + events in parallel, filter past events, pick fiveStar (first non-Shadow 5★), mega, shadow. Generate priority sentence via IntelligenceRouter. Fallback: "Focus on {boss} raids this week."

- [ ] **Step 4: Run tests + commit**

```bash
git add -A
git commit -m "feat: PoGo models + pipeline with local picks"
```

---

### Task 9: Feature — GitHub Models + Pipeline

**Files:**
- Create: `Features/GitHub/GitHubModels.swift`
- Create: `Features/GitHub/GitHubPipeline.swift`
- Test: `GlanceTests/GitHubPipelineTests.swift`

**Interfaces:**
- Produces: `GitHubData` with velocity computation
- Consumes: `GitHubClient`, `CacheStore`

- [ ] **Step 1: Write GitHubModels + Pipeline**

```swift
// Features/GitHub/GitHubModels.swift
struct GitHubData: Codable, Sendable {
    let repos: [GitHubRepoWithVelocity]
    let totalCount: Int
    let rateLimitRemaining: Int?
    let timestamp: Date
}

struct GitHubRepoWithVelocity: Codable, Sendable, Identifiable {
    let repo: GitHubRepo
    let velocity: Int?

    var id: String { repo.fullName }
}
```

Port velocity computation: compare `stargazers_count` against prior cache's `repos[].stars` by `full_name`. Positive delta = `+N` velocity pill. First sync shows no pills.

- [ ] **Step 2: Write tests + commit**

```bash
git add -A
git commit -m "feat: GitHub models + pipeline with velocity"
```

---

### Task 10: Feature — AiIntel Models + Pipeline

**Files:**
- Create: `Features/AiIntel/AiIntelModels.swift`
- Create: `Features/AiIntel/AiIntelPipeline.swift`
- Test: `GlanceTests/AiIntelPipelineTests.swift`

**Interfaces:**
- Produces: `AiIntelData` with tagged items + articles
- Consumes: `ExaClient`, `IntelligenceRouter`, `CacheStore`

- [ ] **Step 1: Write AiIntelModels + Pipeline**

```swift
// Features/AiIntel/AiIntelModels.swift
struct AiIntelData: Codable, Sendable {
    let items: [AiIntelItem]
    let articles: [ExaArticle]
    let source: String
    let timestamp: Date
}
```

Port tag classification: OpenAI/Anthropic/Google DeepMind/Meta → FRONTIER LABS, else → OPEN WEIGHTS. Join by index with Exa articles (never invent URLs). Degraded fallback: first 3 Exa articles tagged OPEN WEIGHTS. Cap at 3 items.

- [ ] **Step 2: Write tests + commit**

```bash
git add -A
git commit -m "feat: AiIntel models + pipeline with tag classification"
```

---

### Task 11: Feature — PulseStore + PulseView + GlanceCardView (TikTok-style paging)

**Files:**
- Create: `Features/Pulse/PulseStore.swift`
- Create: `Features/Pulse/PulseView.swift`
- Create: `Features/Pulse/GlanceCardView.swift`

**Interfaces:**
- Produces: `PulseStore` @Observable with 4 card states + refresh orchestration
- Produces: `PulseView` with vertical TabView paging
- Produces: `GlanceCardView` full-screen card with header (icon + badge + age + refresh) and footer (View hub link)

- [ ] **Step 1: Write PulseStore**

```swift
// Features/Pulse/PulseStore.swift
import Foundation

enum CardID: CaseIterable, Hashable {
    case madrid, pogo, github, aiIntel
}

enum CardState<T: Codable & Sendable>: Equatable where T: Equatable {
    case loading
    case ready(data: T, age: String)
    case stale(data: T, age: String)
    case degraded(data: T, age: String, reason: String)
    case error(message: String)
    case offline(data: T, age: String)
    case keyMissing(keyName: String)

    var age: String? {
        switch self {
        case .ready(_, let age), .stale(_, let age), .degraded(_, let age, _), .offline(_, let age): age
        default: nil
        }
    }
}

@MainActor @Observable
final class PulseStore {
    var madrid: CardState<MadridData> = .loading
    var pogo: CardState<PoGoData> = .loading
    var github: CardState<GitHubData> = .loading
    var aiIntel: CardState<AiIntelData> = .loading
    var currentCard: CardID = .madrid

    var freshestCacheAge: String {
        [madrid, pogo, github, aiIntel]
            .compactMap { $0.age }
            .min(by: { ageString($0) < ageString($1) }) ?? "never"
    }

    private let cache: CacheStore

    init(cache: CacheStore = .shared) {
        self.cache = cache
    }

    func loadFromCache() async {
        // Load all 4 cards from cache in parallel
        // Paint instantly from cache
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refresh(.madrid) }
            group.addTask { await self.refresh(.pogo) }
            group.addTask { await self.refresh(.github) }
            group.addTask { await self.refresh(.aiIntel) }
        }
    }

    func refresh(_ card: CardID) async {
        // 1. Set stale/loading state
        // 2. Call appropriate pipeline
        // 3. Update state with result or error
        // 4. Persist to cache
    }
}
```

- [ ] **Step 2: Write PulseView with TikTok-style paging**

```swift
// Features/Pulse/PulseView.swift
import SwiftUI

struct PulseView: View {
    @State private var store = PulseStore()

    var body: some View {
        TabView(selection: $store.currentCard) {
            GlanceCardView(card: .madrid, store: store)
                .tag(CardID.madrid)
            GlanceCardView(card: .pogo, store: store)
                .tag(CardID.pogo)
            GlanceCardView(card: .github, store: store)
                .tag(CardID.github)
            GlanceCardView(card: .aiIntel, store: store)
                .tag(CardID.aiIntel)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Theme.canvas)
        .task {
            await store.loadFromCache()
            await store.refreshAll()
        }
    }
}
```

- [ ] **Step 3: Write GlanceCardView**

Full-screen card component:
- **Header:** Feature icon (amber/rose/emerald/cyan) + GlanceBadge + cache age + refresh button
- **Body:** Card-specific content (shimmer skeleton when loading, full content when ready, error state)
- **Footer:** "View hub ›" link (pushes to NavigationStack) + source attribution badge

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: PulseStore + PulseView with TikTok-style paging + GlanceCardView"
```

---

### Task 12: Feature — Hub Views (Madrid, PoGo, GitHub, AiIntel)

**Files:**
- Create: `Features/Madrid/MadridHubView.swift`
- Create: `Features/Madrid/MadridArticleView.swift`
- Create: `Features/PoGo/PoGoHubView.swift`
- Create: `Features/PoGo/RaidDetailView.swift`
- Create: `Features/PoGo/EventDetailView.swift`
- Create: `Features/GitHub/GitHubHubView.swift`
- Create: `Features/GitHub/RepoDetailView.swift`
- Create: `Features/AiIntel/AiIntelArticleView.swift`

**Interfaces:**
- Produces: Full hub + detail views for each card
- Consumes: Data from `PulseStore`, navigation via `NavigationStack`

- [ ] **Step 1: Implement MadridHubView**

Sections: Next Match hero (crests, opponent, comp/stadium, IST date, countdown, scores), Fixtures timeline, UCL draw (Home/Away columns), Form & Standing (W/D/L dots), Tactical Intel (amber quote), Latest from Managing Madrid (10 rows: title, author, category, date, external link icon).

- [ ] **Step 2: Implement MadridArticleView**

Title, category pill, author, date, HTML body with media stripped (remove `img, figure, blockquote, iframe, script`), styled prose (headings, lists, bold, amber links), "Open on Managing Madrid" button.

- [ ] **Step 3: Implement PoGoHubView**

Tier tab filter (`All | 1★ | 3★ | 5★ | Mega | Shadow` with counts), raid rows (artwork, name, tier badge, type icons, CP range, shiny + weather lines), events section, target priority panel, credit footer.

- [ ] **Step 4: Implement RaidDetailView + EventDetailView**

Raid: hero artwork, name, tier pill, shiny pill, Types chips, Combat Power panel, Weather Boost chips.
Event: hero image, name, type pill, date range, source link, Raid Bosses grid, Community-Day bonuses, Special Research steps.

- [ ] **Step 5: Implement GitHubHubView + RepoDetailView**

Hub: sort segmented control (Stars / Fresh / Hot), header count, repo rows + description + topic chips, quota footer.
Detail: avatar + name + owner, Pushed/Created dates, 4-stat grid (Stars/Forks/Issues/Watchers), pills (language, license, Wiki, Pages, Discussions, Homepage), Topics chips, "Open on GitHub" button.

- [ ] **Step 6: Implement AiIntelArticleView**

Hero image, headline, tag pill, source · author · date, BENCHMARKS chips, Key Points list, "Full Coverage" expandable, "Read original article" button.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: hub views — Madrid, PoGo, GitHub, AiIntel"
```

---

### Task 13: Settings — SourcesView + SettingsView

**Files:**
- Create: `Settings/SourcesView.swift`
- Create: `Settings/SettingsView.swift`
- Create: `Settings/SettingsStore.swift`

**Interfaces:**
- Produces: Key entry UI with Keychain persistence
- Produces: Cache management UI

- [ ] **Step 1: Write SourcesView**

- Exa key: SecureField with show/hide toggle, status (`From .env` / `Configured ✓` / `Missing`), masked display (`ab12••••wxyz`)
- Gemini key: Same pattern
- Gemini model picker: Radio list (`gemini-3.6-flash` default, `gemini-3.7-flash`, `gemini-3.8-flash`)
- On-device AI status card: badge `Active` or reason label + "Re-check availability" button
- Footer: "Keys stored locally on your device. Never committed to git." + external links

- [ ] **Step 2: Write SettingsView**

- Per-card cache age display (Madrid, PoGo, GitHub, AI Intel)
- Clear All Cache button (keeps keys)
- About block (app name, version 0.1.0)

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: SourcesView + SettingsView with Keychain persistence"
```

---

### Task 14: App — GlanceApp + AppState + Tab Bar

**Files:**
- Create: `App/GlanceApp.swift`
- Create: `App/AppState.swift`
- Create: `Shared/Enums.swift` (Tab enum)

**Interfaces:**
- Produces: App entry point with TabView (floating dock)
- Produces: NavigationStack per tab

- [ ] **Step 1: Write GlanceApp**

```swift
// App/GlanceApp.swift
import SwiftUI

@main
struct GlanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 2: Write ContentView with TabView**

```swift
struct ContentView: View {
    @State private var selectedTab: Tab = .pulse

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Pulse", systemImage: "waveform.path.ecg", value: .pulse) {
                NavigationStack {
                    PulseView()
                        .navigationTitle("Glance")
                }
            }
            Tab("Explore", systemImage: "safari", value: .explore) {
                NavigationStack {
                    ExploreStubView()
                        .navigationTitle("Explore")
                }
            }
            Tab("Sources", systemImage: "key", value: .sources) {
                NavigationStack {
                    SourcesView()
                        .navigationTitle("Sources")
                }
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
            }
        }
        .tint(Theme.primary)
    }
}
```

- [ ] **Step 3: Write ExploreStubView**

```swift
struct ExploreStubView: View {
    var body: some View {
        ContentUnavailableView(
            "Coming Soon",
            systemImage: "safari",
            description: Text("Explore features will arrive in a future update.")
        )
    }
}
```

- [ ] **Step 4: Write Tab enum**

```swift
// Shared/Enums.swift
enum Tab: CaseIterable {
    case pulse, explore, sources, settings
}
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: GlanceApp entry point + Tab bar + Explore stub"
```

---

### Task 15: UI Tests

**Files:**
- Create: `GlanceUITests/PulseFlowUITests.swift`
- Create: `GlanceUITests/SourcesFlowUITests.swift`

**Interfaces:**
- Tests: Cold launch renders cards, card paging, tab navigation, Sources key entry

- [ ] **Step 1: Write PulseFlowUITests**

```swift
// GlanceUITests/PulseFlowUITests.swift
import XCTest

final class PulseFlowUITests: XCTestCase {
    func testColdLaunchRendersCards() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Pulse"].exists)
    }

    func testCardPaging() {
        let app = XCUIApplication()
        app.launch()
        app.swipeUp()
        // Verify page changed
    }

    func testTabNavigation() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Sources"].tap()
        XCTAssertTrue(app.navigationBars["Sources"].exists)
    }
}
```

- [ ] **Step 2: Write SourcesFlowUITests**

Test: key entry fields exist, save button works, model picker visible.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: UI tests for Pulse flow and Sources flow"
```

---

### Task 16: Final Integration + Verification

**Files:**
- Modify: All files as needed for integration

**Interfaces:**
- All tasks complete, all tests passing

- [ ] **Step 1: Run all unit tests**

Run: `xctest GlanceTests`
Expected: ALL PASS

- [ ] **Step 2: Run all UI tests**

Run: `xctest GlanceUITests`
Expected: ALL PASS

- [ ] **Step 3: Build for device**

Run: `xcodebuild -scheme Glance -destination 'generic/platform=iOS'`
Expected: BUILD SUCCEEDS

- [ ] **Step 4: Verify acceptance checklist**

- [ ] Cold launch paints all 4 cards from cache with zero network
- [ ] Each card refreshes independently; global sync refreshes all in parallel
- [ ] Airplane-mode launch shows cached data + Offline pill; no blanks/crashes
- [ ] Missing Exa key → Madrid + AI Intel show Key-Missing; missing Gemini key → AI features degrade to raw (never error)
- [ ] On-device AI path produces form/standing/intel, priority sentence, 2–3 tagged briefs; disabling it falls back to Gemini, then raw
- [ ] Madrid hub shows fixture, timeline, draw, form, intel, 10 MM articles; article body renders stripped of media with working outbound link
- [ ] PoGo hub tabs filter correctly; raid/event details render all sections; credit line visible on card + hub
- [ ] GitHub hub sorts 3 ways; velocity pills appear after 2nd sync; quota footer accurate; repo detail stats correct
- [ ] AI article detail shows benchmarks, key points, full coverage, source link
- [ ] Sources persists keys across restarts (Keychain), model choice persists, native status re-check works
- [ ] Settings cache ages accurate; Clear Cache forces refetch, keeps keys
- [ ] Dark-only Obsidian theme, correct accents/fonts/radii, safe-area clean on notched devices, Reduce Motion honored
- [ ] No API keys in source, logs, or the binary's plaintext resources

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: Glance native iOS v1 complete — all cards, hubs, settings, tests passing"
```

---

## Summary

| Task | Scope | Est. Time |
|------|-------|-----------|
| 1 | Xcode project + assets + fonts | 30 min |
| 2 | Cache + Keychain | 45 min |
| 3 | Network clients | 60 min |
| 4 | Intelligence layer | 45 min |
| 5 | TimeFormat | 20 min |
| 6 | DesignSystem | 30 min |
| 7 | Madrid pipeline | 60 min |
| 8 | PoGo pipeline | 45 min |
| 9 | GitHub pipeline | 30 min |
| 10 | AiIntel pipeline | 30 min |
| 11 | PulseStore + Views | 60 min |
| 12 | Hub views | 90 min |
| 13 | Settings views | 30 min |
| 14 | App entry + tabs | 20 min |
| 15 | UI tests | 30 min |
| 16 | Integration + verification | 30 min |
| **Total** | | **~10 hours** |

---

## Design Decisions (from brainstorming)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Min iOS version | iOS 26+ | Foundation Models always available, no fallback code needed |
| Keychain security | Keychain only (no biometric) | Simpler UX, still hardware-protected |
| Project structure | Single target + folder layers | Faster to build, simpler for app this size |
| Architecture | Protocol-oriented + DI | Highly testable, clean separation, follows SwiftUI Pro conventions |
| Card paging | TikTok-style vertical paging | Immersive, full-screen cards, swipe to switch |
| Color approach | Hybrid system + custom | System colors adapt automatically, custom accents for card sheen/badges |
| Testing | Unit + UI tests | Full coverage for critical flows |
