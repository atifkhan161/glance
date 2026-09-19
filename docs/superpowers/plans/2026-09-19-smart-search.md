# Smart Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4th tab ("ExaSearch") with Quick Search (instant Exa browsing) and Deep Research (multi-query Exa + OpenRouter synthesis → MD file save).

**Architecture:** New `SmartSearch` feature directory with views, models, and pipeline. New `OpenRouterClient` and `ExaEnhancedClient` in Core/Network. New `MarkdownStore` for MD file persistence. Tab added to the floating dock via existing `GlanceTab` enum.

**Tech Stack:** SwiftUI, URLSession async/await, WKWebView (via UIViewRepresentable), KeychainStore, existing Theme system

**Spec:** `docs/superpowers/specs/2026-09-19-smart-search-design.md`

## Global Constraints

- Swift 5.9+ with strict concurrency (`Sendable`, actors)
- Use `@Observable` macro for view models (not `ObservableObject`)
- Use `@Environment(AppState.self)` for dependency injection
- All styling through `Theme.Colors.*`, `Theme.Fonts.*`, `Theme.Radius.*`
- No inline comments — code should be self-documenting
- File naming: named after primary type
- Feature-first organization: `Glance/Features/SmartSearch/`
- Network clients: `Glance/Core/Network/`
- Cache/storage: `Glance/Core/Cache/`

---

## File Map

### New Files (12)

| File | Responsibility |
|------|---------------|
| `Glance/Features/SmartSearch/SmartSearchModels.swift` | Data models for search state, research state, research files |
| `Glance/Features/SmartSearch/SmartSearchPipeline.swift` | Orchestrates Exa + OpenRouter calls |
| `Glance/Features/SmartSearch/SmartSearchView.swift` | Main tab view with Quick/Deep segmented control |
| `Glance/Features/SmartSearch/QuickSearchView.swift` | Search bar + instant results list |
| `Glance/Features/SmartSearch/QuickSearchResultRow.swift` | Individual search result card |
| `Glance/Features/SmartSearch/DeepResearchView.swift` | Topic input, sub-query config, progress |
| `Glance/Features/SmartSearch/ResearchListView.swift` | Chronological saved MD files list |
| `Glance/Features/SmartSearch/ResearchFileRow.swift` | MD file list item |
| `Glance/Features/SmartSearch/MarkdownPreviewView.swift` | WKWebView wrapper for MD rendering |
| `Glance/Core/Network/OpenRouterClient.swift` | API client for OpenRouter chat completions |
| `Glance/Core/Network/ExaEnhancedClient.swift` | Extended Exa search with deep-reasoning + text |
| `Glance/Core/Cache/MarkdownStore.swift` | FileManager wrapper for MD files in Documents/ |

### Modified Files (5)

| File | Change |
|------|--------|
| `Glance/Shared/Enums.swift:3-7` | Add `.search` case to `GlanceTab` |
| `Glance/App/ContentView.swift:14-24,101-133` | Add `.search` case + extension |
| `Glance/App/AppState.swift:10-11,25-31` | Add `searchPath` NavigationPath |
| `Glance/Settings/SettingsStore.swift:6-7,110-124,126-138` | Add `openrouterAPIKey` + keychain |
| `Glance/Settings/SettingsView.swift:150-284` | Add OpenRouter API key section |

---

### Task 1: Data Models

**Files:**
- Create: `Glance/Features/SmartSearch/SmartSearchModels.swift`

**Interfaces:**
- Consumes: existing `ExaResult` from `ExaClient.swift`
- Produces: `SmartSearchTab`, `QuickSearchState`, `DeepResearchState`, `ResearchFile`, `SubQueryResponse`

- [ ] **Step 1: Create the models file**

```swift
import Foundation

enum SmartSearchTab: String, CaseIterable {
    case quickSearch = "Quick Search"
    case deepResearch = "Deep Research"
}

enum QuickSearchState: Equatable {
    case idle
    case searching
    case results([ExaResult])
    case error(String)
}

enum DeepResearchState: Equatable {
    case idle
    case generatingSubQueries
    case searching(current: Int, total: Int)
    case synthesizing
    case saving
    case complete(ResearchFile)
    case error(String)
}

struct ResearchFile: Identifiable, Codable, Sendable {
    let id: UUID
    let query: String
    let date: Date
    let sourceCount: Int
    let fileName: String

    init(id: UUID = UUID(), query: String, date: Date = Date(), sourceCount: Int, fileName: String) {
        self.id = id
        self.query = query
        self.date = date
        self.sourceCount = sourceCount
        self.fileName = fileName
    }
}

struct SubQueryResponse: Codable {
    let queries: [String]
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

Expected: Build fails (file not in project yet) but syntax is valid.

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/SmartSearchModels.swift
git commit -m "feat: add SmartSearch data models"
```

---

### Task 2: Enhanced Exa Client

**Files:**
- Create: `Glance/Core/Network/ExaEnhancedClient.swift`

**Interfaces:**
- Consumes: `ExaResult`, `GlanceError`
- Produces: `ExaEnhancedClient.search(request:apiKey:)` with configurable type, numResults, contentsText, systemPrompt

- [ ] **Step 1: Create the enhanced client**

```swift
import Foundation

struct ExaEnhancedSearchRequest {
    let query: String
    let type: String
    let numResults: Int
    let contentsHighlights: Bool
    let contentsText: Bool
    let systemPrompt: String?

    init(
        query: String,
        type: String = "auto",
        numResults: Int = 10,
        contentsHighlights: Bool = true,
        contentsText: Bool = false,
        systemPrompt: String? = nil
    ) {
        self.query = query
        self.type = type
        self.numResults = numResults
        self.contentsHighlights = contentsHighlights
        self.contentsText = contentsText
        self.systemPrompt = systemPrompt
    }
}

struct ExaEnhancedClient: Sendable {
    func search(request: ExaEnhancedSearchRequest, apiKey: String) async throws -> [ExaResult] {
        var urlRequest = URLRequest(url: URL(string: "https://api.exa.ai/search")!)
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
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Core/Network/ExaEnhancedClient.swift
git commit -m "feat: add ExaEnhancedClient with deep-reasoning and text support"
```

---

### Task 3: OpenRouter Client

**Files:**
- Create: `Glance/Core/Network/OpenRouterClient.swift`

**Interfaces:**
- Consumes: `GlanceError`
- Produces: `OpenRouterClient.complete(systemPrompt:userPrompt:apiKey:) async throws -> String`

- [ ] **Step 1: Create the OpenRouter client**

```swift
import Foundation

struct OpenRouterClient: Sendable {
    func complete(systemPrompt: String, userPrompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Glance-iOS", forHTTPHeaderField: "HTTP-Referer")

        let body: [String: Any] = [
            "model": "openrouter/free",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt],
            ],
            "temperature": 0.7,
            "max_tokens": 4096,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        for attempt in 0 ..< 3 {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GlanceError.networkError("No HTTP response")
            }
            if http.statusCode == 200 {
                let decoded = try JSONDecoder().decode(OpenRouterResponse.self, from: data)
                guard let content = decoded.choices.first?.message.content else {
                    throw GlanceError.networkError("Empty response from OpenRouter")
                }
                return content
            }
            if http.statusCode == 429 {
                let delay: UInt64
                if let retryAfter = http.value(forHTTPHeaderField: "Retry-After"),
                   let seconds = Double(retryAfter) {
                    delay = UInt64(seconds * 1_000_000_000)
                } else {
                    delay = attempt == 0 ? 2_000_000_000 : 4_000_000_000
                }
                try await Task.sleep(nanoseconds: delay)
                continue
            }
            throw GlanceError.networkError("OpenRouter failed with status \(http.statusCode)")
        }
        throw GlanceError.networkError("OpenRouter failed after retries")
    }
}

private struct OpenRouterResponse: Codable {
    let choices: [Choice]
    struct Choice: Codable { let message: Message }
    struct Message: Codable { let content: String }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Core/Network/OpenRouterClient.swift
git commit -m "feat: add OpenRouterClient for LLM synthesis"
```

---

### Task 4: Markdown Store

**Files:**
- Create: `Glance/Core/Cache/MarkdownStore.swift`

**Interfaces:**
- Consumes: `ResearchFile`
- Produces: `MarkdownStore.shared.save()`, `.list()`, `.load()`, `.delete()`

- [ ] **Step 1: Create the MarkdownStore**

```swift
import Foundation

actor MarkdownStore: Sendable {
    static let shared = MarkdownStore()

    private let fileManager = FileManager.default
    private let researchDir: URL

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        researchDir = docs.appendingPathComponent("Research", isDirectory: true)
        try? fileManager.createDirectory(at: researchDir, withIntermediateDirectories: true)
    }

    func save(query: String, content: String, sources: [(title: String, url: String)]) async throws -> URL {
        let slug = query.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "research-\(timestamp)-\(slug).md"
        let fileURL = researchDir.appendingPathComponent(fileName)

        var md = "# \(query)\n\n"
        md += "*Researched on \(formattedDate()) — \(sources.count) sources*\n\n---\n\n"
        md += content + "\n\n---\n\n## Sources\n\n"
        for (index, source) in sources.enumerated() {
            md += "\(index + 1). \(source.title) — \(source.url)\n"
        }

        try md.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func list() async -> [ResearchFile] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: researchDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { url -> ResearchFile? in
                guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
                      let date = attrs[.creationDate] as? Date else { return nil }
                let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let title = content.components(separatedBy: "\n").first?
                    .replacingOccurrences(of: "# ", with: "") ?? url.lastPathComponent
                let sourceCount = content.components(separatedBy: "## Sources").last?
                    .components(separatedBy: "\n")
                    .filter { $0.range(of: #"^\d+\."#, options: .regularExpression) != nil }.count ?? 0
                return ResearchFile(
                    query: title,
                    date: date,
                    sourceCount: sourceCount,
                    fileName: url.lastPathComponent
                )
            }
            .sorted { $0.date > $1.date }
    }

    func load(url: URL) async throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func delete(url: URL) async throws {
        try fileManager.removeItem(at: url)
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Core/Cache/MarkdownStore.swift
git commit -m "feat: add MarkdownStore for research file persistence"
```

---

### Task 5: Smart Search Pipeline

**Files:**
- Create: `Glance/Features/SmartSearch/SmartSearchPipeline.swift`

**Interfaces:**
- Consumes: `ExaEnhancedClient`, `OpenRouterClient`, `MarkdownStore`, `KeychainStore`
- Produces: `quickSearch()`, `generateSubQueries()`, `searchSubQuery()`, `synthesize()`, `saveResearch()`, `loadResearchFiles()`, `deleteResearchFile()`

- [ ] **Step 1: Create the pipeline**

```swift
import Foundation

struct SmartSearchPipeline: Sendable {
    private let exa = ExaEnhancedClient()
    private let openRouter = OpenRouterClient()
    private let markdownStore = MarkdownStore.shared
    private let keychain = KeychainStore.shared

    func quickSearch(query: String) async throws -> [ExaResult] {
        guard let exaKey = keychain.load(forKey: "keys_exa") else {
            throw GlanceError.keyMissing("Exa API key not configured")
        }
        let request = ExaEnhancedSearchRequest(
            query: query,
            type: "auto",
            numResults: 10,
            contentsHighlights: true,
            contentsText: false
        )
        return try await exa.search(request: request, apiKey: exaKey)
    }

    func generateSubQueries(topic: String, count: Int) async throws -> [String] {
        guard let openRouterKey = keychain.load(forKey: "keys_openrouter") else {
            throw GlanceError.keyMissing("OpenRouter API key not configured")
        }
        let systemPrompt = """
        You are a research assistant. Given a topic, generate \(count) diverse search queries \
        that would comprehensively cover the topic from different angles. \
        Return ONLY a JSON object with a "queries" key containing an array of \(count) strings. \
        No other text. Example: {"queries": ["query 1", "query 2"]}
        """
        let response = try await openRouter.complete(
            systemPrompt: systemPrompt,
            userPrompt: "Topic: \(topic)",
            apiKey: openRouterKey
        )
        guard let data = response.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(SubQueryResponse.self, from: data) else {
            return [topic]
        }
        return decoded.queries.isEmpty ? [topic] : decoded.queries
    }

    func searchSubQuery(_ query: String) async throws -> [ExaResult] {
        guard let exaKey = keychain.load(forKey: "keys_exa") else {
            throw GlanceError.keyMissing("Exa API key not configured")
        }
        let request = ExaEnhancedSearchRequest(
            query: query,
            type: "deep-reasoning",
            numResults: 10,
            contentsHighlights: true,
            contentsText: true
        )
        return try await exa.search(request: request, apiKey: exaKey)
    }

    func synthesize(topic: String, results: [ExaResult]) async throws -> String {
        guard let openRouterKey = keychain.load(forKey: "keys_openrouter") else {
            throw GlanceError.keyMissing("OpenRouter API key not configured")
        }
        let resultsText = results.map { "- \($0.title): \($0.highlights.joined(separator: " "))" }.joined(separator: "\n")
        let systemPrompt = """
        You are a research compiler. Synthesize the following search results into a comprehensive, \
        well-structured markdown research document about "\(topic)". \
        Use headers, bullet points, and clear sections. Be factual and cite sources inline. \
        Output ONLY the markdown content, no preamble.
        """
        return try await openRouter.complete(
            systemPrompt: systemPrompt,
            userPrompt: "Search results:\n\(resultsText)",
            apiKey: openRouterKey
        )
    }

    func saveResearch(topic: String, content: String, results: [ExaResult]) async throws -> URL {
        let sources = results.map { (title: $0.title, url: $0.url) }
        return try await markdownStore.save(query: topic, content: content, sources: sources)
    }

    func loadResearchFiles() async -> [ResearchFile] {
        await markdownStore.list()
    }

    func deleteResearchFile(url: URL) async throws {
        try await markdownStore.delete(url: url)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/SmartSearchPipeline.swift
git commit -m "feat: add SmartSearchPipeline orchestrating Exa + OpenRouter"
```

---

### Task 6: Quick Search Result Row

**Files:**
- Create: `Glance/Features/SmartSearch/QuickSearchResultRow.swift`

**Interfaces:**
- Consumes: `ExaResult`
- Produces: View component for a single search result

- [ ] **Step 1: Create the result row**

```swift
import SwiftUI

struct QuickSearchResultRow: View {
    let result: ExaResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                if let image = result.image, let imageURL = URL(string: image) {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(Theme.Fonts.manrope(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(2)

                    Text(URL(string: result.url)?.host ?? result.url)
                        .font(Theme.Fonts.manrope(11))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }

            if let firstHighlight = result.highlights.first {
                Text(firstHighlight)
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(3)
            }

            if let date = result.publishedDate {
                Text(date)
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/QuickSearchResultRow.swift
git commit -m "feat: add QuickSearchResultRow component"
```

---

### Task 7: Quick Search View

**Files:**
- Create: `Glance/Features/SmartSearch/QuickSearchView.swift`

**Interfaces:**
- Consumes: `SmartSearchPipeline`, `QuickSearchResultRow`, `QuickSearchState`
- Produces: Full Quick Search UI with debounced search

- [ ] **Step 1: Create the Quick Search view**

```swift
import SwiftUI

struct QuickSearchView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var query = ""
    @State private var state: QuickSearchState = .idle
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            switch state {
            case .idle:
                emptyState
            case .searching:
                GlanceLoadingView(message: "Searching...")
            case .results(let results):
                resultsList(results)
            case .error(let message):
                GlanceErrorView(
                    message: message,
                    accentColor: Theme.Colors.cardCyan,
                    retryAction: { performSearch() }
                )
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Colors.textMuted)

            TextField("Search the web...", text: $query)
                .font(Theme.Fonts.manrope(15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }
                .onChange(of: query) { _, newValue in
                    searchTask?.cancel()
                    guard !newValue.isEmpty else {
                        state = .idle
                        return
                    }
                    searchTask = Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        guard !Task.isCancelled else { return }
                        performSearch()
                    }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    state = .idle
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textMuted)
            Text("Search the web with Exa AI")
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultsList(_ results: [ExaResult]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(results, id: \.url) { result in
                    if let url = URL(string: result.url) {
                        Link(destination: url) {
                            QuickSearchResultRow(result: result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state = .searching
        Task {
            do {
                let results = try await pipeline.quickSearch(query: query)
                state = .results(results)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/QuickSearchView.swift
git commit -m "feat: add QuickSearchView with debounced search"
```

---

### Task 8: Research File Row

**Files:**
- Create: `Glance/Features/SmartSearch/ResearchFileRow.swift`

**Interfaces:**
- Consumes: `ResearchFile`
- Produces: View component for a saved MD file row

- [ ] **Step 1: Create the research file row**

```swift
import SwiftUI

struct ResearchFileRow: View {
    let file: ResearchFile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(file.query)
                .font(Theme.Fonts.manrope(15, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(formattedDate)
                        .font(Theme.Fonts.manrope(11))
                }
                .foregroundStyle(Theme.Colors.textMuted)

                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("\(file.sourceCount) sources")
                        .font(Theme.Fonts.manrope(11))
                }
                .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: file.date)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/ResearchFileRow.swift
git commit -m "feat: add ResearchFileRow component"
```

---

### Task 9: Markdown Preview View

**Files:**
- Create: `Glance/Features/SmartSearch/MarkdownPreviewView.swift`

**Interfaces:**
- Consumes: MD file URL, `MarkdownStore`
- Produces: WKWebView-based markdown preview with share/delete actions

- [ ] **Step 1: Create the WKWebView wrapper**

```swift
import SwiftUI
import WebKit

struct MarkdownPreviewView: View {
    let url: URL
    let title: String
    @State private var markdownContent: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if markdownContent.isEmpty {
                GlanceLoadingView()
            } else {
                MarkdownWebView(content: markdownContent)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: markdownContent)
                    Button(role: .destructive) {
                        Task {
                            try? await MarkdownStore.shared.delete(url: url)
                            dismiss()
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            do {
                markdownContent = try await MarkdownStore.shared.load(url: url)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
}

struct MarkdownWebView: UIViewRepresentable {
    let content: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.contentInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = markdownToHTML(content)
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func markdownToHTML(_ markdown: String) -> String {
        let escaped = markdown
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        var html = escaped
        html = html.replacingOccurrences(of: #"^### (.+)$"#, with: "<h3>$1</h3>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^## (.+)$"#, with: "<h2>$1</h2>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^# (.+)$"#, with: "<h1>$1</h1>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^---+$"#, with: "<hr>", options: .regularExpression)
        html = html.replacingOccurrences(of: #"^- (.+)$"#, with: "<li>$1</li>", options: .regularExpression)
        html = html.replacingOccurrences(of: "\n", with: "<br>")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: -apple-system, sans-serif; font-size: 16px; line-height: 1.6;
                   color: #E0E0E0; background: #0A0A0A; margin: 0; padding: 20px; }
            h1 { font-size: 24px; color: #FFFFFF; margin-bottom: 8px; }
            h2 { font-size: 20px; color: #FFFFFF; margin-top: 24px; margin-bottom: 8px; }
            h3 { font-size: 17px; color: #FFFFFF; margin-top: 16px; margin-bottom: 4px; }
            hr { border: none; border-top: 1px solid #333; margin: 16px 0; }
            li { margin-left: 16px; margin-bottom: 4px; }
            a { color: #34D399; }
            strong { color: #FFFFFF; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/MarkdownPreviewView.swift
git commit -m "feat: add MarkdownPreviewView with WKWebView rendering"
```

---

### Task 10: Research List View

**Files:**
- Create: `Glance/Features/SmartSearch/ResearchListView.swift`

**Interfaces:**
- Consumes: `SmartSearchPipeline`, `ResearchFileRow`, `MarkdownPreviewView`, `ResearchFile`
- Produces: Full research list UI with swipe-to-delete and navigation

- [ ] **Step 1: Create the research list view**

```swift
import SwiftUI

struct ResearchListView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var files: [ResearchFile] = []
    @State private var showDeleteConfirm = false
    @State private var fileToDelete: ResearchFile?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var body: some View {
        Group {
            if files.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
        .navigationTitle("Saved Research")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadFiles() }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(Theme.Colors.textMuted)
            Text("No research yet")
                .font(Theme.Fonts.manrope(16, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Start your first deep research above.")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(files) { file in
                    NavigationLink(value: file) {
                        ResearchFileRow(file: file)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            fileToDelete = file
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .navigationDestination(for: ResearchFile.self) { file in
            MarkdownPreviewView(url: documentsURL.appendingPathComponent(file.fileName), title: file.query)
        }
        .alert("Delete Research", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let file = fileToDelete {
                    Task {
                        try? await pipeline.deleteResearchFile(
                            url: documentsURL.appendingPathComponent(file.fileName)
                        )
                        await loadFiles()
                    }
                }
            }
        } message: {
            Text("This research file will be permanently deleted.")
        }
    }

    private func loadFiles() async {
        files = await pipeline.loadResearchFiles()
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/ResearchListView.swift
git commit -m "feat: add ResearchListView with swipe-to-delete"
```

---

### Task 11: Deep Research View

**Files:**
- Create: `Glance/Features/SmartSearch/DeepResearchView.swift`

**Interfaces:**
- Consumes: `SmartSearchPipeline`, `ResearchListView`, `DeepResearchState`
- Produces: Full Deep Research UI with topic input, sub-query config, progress

- [ ] **Step 1: Create the Deep Research view**

```swift
import SwiftUI

struct DeepResearchView: View {
    @State private var pipeline = SmartSearchPipeline()
    @State private var topic = ""
    @State private var subQueryCount = 5
    @State private var state: DeepResearchState = .idle
    @State private var navigateToList = false

    var body: some View {
        VStack(spacing: 0) {
            inputSection

            switch state {
            case .idle:
                Spacer()
            case .generatingSubQueries:
                progressView("Generating sub-queries...")
            case .searching(let current, let total):
                progressView("Searching (\(current)/\(total))...")
            case .synthesizing:
                progressView("Synthesizing research...")
            case .saving:
                progressView("Saving research...")
            case .complete:
                Spacer()
            case .error(let message):
                GlanceErrorView(
                    message: message,
                    accentColor: Theme.Colors.cardCyan,
                    retryAction: { startResearch() }
                )
            }

            Spacer()
        }
        .navigationDestination(isPresented: $navigateToList) {
            ResearchListView()
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deep Research")
                .font(Theme.Fonts.manrope(20, weight: .bold))
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("Multi-query research that builds a comprehensive knowledge base")
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)

            TextEditor(text: $topic)
                .font(Theme.Fonts.manrope(15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(12)
                .frame(minHeight: 80)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )

            HStack {
                Text("Sub-queries")
                    .font(Theme.Fonts.manrope(13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Picker("Sub-queries", selection: $subQueryCount) {
                    ForEach(3...7, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Button {
                startResearch()
            } label: {
                HStack {
                    if case .searching = state { ProgressView().tint(.white) }
                    else if case .generatingSubQueries = state { ProgressView().tint(.white) }
                    else if case .synthesizing = state { ProgressView().tint(.white) }
                    else if case .saving = state { ProgressView().tint(.white) }
                    Text(buttonTitle)
                        .font(Theme.Fonts.scale(.callout).weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canStart ? Theme.Colors.cardCyan : Theme.Colors.textMuted, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .disabled(!canStart)
        }
        .padding(Theme.cardPadding)
    }

    private var canStart: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (state == .idle || state == .error(""))
    }

    private var buttonTitle: String {
        switch state {
        case .idle: "Start Research"
        case .generatingSubQueries: "Generating..."
        case .searching: "Searching..."
        case .synthesizing: "Synthesizing..."
        case .saving: "Saving..."
        case .complete: "Start New Research"
        case .error: "Retry Research"
        }
    }

    private func progressView(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.Colors.cardCyan)
            Text(message)
                .font(Theme.Fonts.manrope(13))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private func startResearch() {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else { return }

        state = .generatingSubQueries
        Task {
            do {
                let subQueries = try await pipeline.generateSubQueries(topic: trimmedTopic, count: subQueryCount)

                var allResults: [ExaResult] = []
                for (index, query) in subQueries.enumerated() {
                    state = .searching(current: index + 1, total: subQueries.count)
                    let results = try await pipeline.searchSubQuery(query)
                    allResults.append(contentsOf: results)
                }

                state = .synthesizing
                let synthesized = try await pipeline.synthesize(topic: trimmedTopic, results: allResults)

                state = .saving
                _ = try await pipeline.saveResearch(topic: trimmedTopic, content: synthesized, results: allResults)

                state = .complete
                navigateToList = true
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/DeepResearchView.swift
git commit -m "feat: add DeepResearchView with multi-query workflow"
```

---

### Task 12: Main Smart Search View (Tab Root)

**Files:**
- Create: `Glance/Features/SmartSearch/SmartSearchView.swift`

**Interfaces:**
- Consumes: `QuickSearchView`, `DeepResearchView`, `ResearchListView`, `SmartSearchTab`
- Produces: Main tab view with segmented control + saved research navigation

- [ ] **Step 1: Create the SmartSearchView**

```swift
import SwiftUI

struct SmartSearchView: View {
    @State private var selectedTab: SmartSearchTab = .quickSearch
    @State private var showResearchList = false

    var body: some View {
        VStack(spacing: 0) {
            researchListLink

            Picker("Mode", selection: $selectedTab) {
                ForEach(SmartSearchTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.cardPadding)
            .padding(.vertical, 8)

            switch selectedTab {
            case .quickSearch:
                QuickSearchView()
            case .deepResearch:
                DeepResearchView()
            }
        }
        .glanceBackground()
        .navigationDestination(isPresented: $showResearchList) {
            ResearchListView()
        }
    }

    private var researchListLink: some View {
        Button {
            showResearchList = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .foregroundStyle(Theme.Colors.cardCyan)
                Text("Saved Research")
                    .font(Theme.Fonts.manrope(14, weight: .medium))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            .padding(12)
            .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.top, 8)
    }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/SmartSearch/SmartSearchView.swift
git commit -m "feat: add SmartSearchView main tab view"
```

---

### Task 13: Add .search to GlanceTab and Wire Up

**Files:**
- Modify: `Glance/Shared/Enums.swift`
- Modify: `Glance/App/ContentView.swift`
- Modify: `Glance/App/AppState.swift`

**Interfaces:**
- Consumes: `SmartSearchView`, `.search` case
- Produces: Search tab visible in dock with navigation

- [ ] **Step 1: Add .search case to GlanceTab**

Replace `Enums.swift`:

```swift
import Foundation

enum GlanceTab: String, CaseIterable, Hashable, Sendable {
    case pulse
    case provider
    case search
    case settings
}

enum GlanceError: Error, Sendable, Equatable {
    case keyMissing(String)
    case networkError(String)
    case rateLimited(retryAfter: Double?)
    case decodingError(String)
    case networkUnavailable
    case httpStatus(Int)
    case decodingFailed
    case unauthorized
    case cacheMiss(String)
    case notConfigured(String)
}
```

- [ ] **Step 2: Add searchPath to AppState**

Add `var searchPath = NavigationPath()` after `settingsPath` in `AppState.swift`.

Add `case .search: searchPath = NavigationPath()` to `resetPath(for:)`.

- [ ] **Step 3: Update ContentView for .search**

Add to the tab switch in the `Group`:

```swift
case .search:
    NavigationStack(path: $bindable.searchPath) { SmartSearchView() }
        .tint(Theme.Colors.accent)
```

Add to `GlanceTab` extensions:

```swift
case .search: "magnifyingglass"       // icon
case .search: "Search"                // shortLabel
case .search: Theme.Colors.cardCyan   // accentColor
case .search: "Smart search"          // accessibilityLabel
```

- [ ] **Step 4: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Glance/Shared/Enums.swift Glance/App/ContentView.swift Glance/App/AppState.swift
git commit -m "feat: wire up ExaSearch tab in dock with navigation"
```

---

### Task 14: Settings — OpenRouter API Key

**Files:**
- Modify: `Glance/Settings/SettingsStore.swift`
- Modify: `Glance/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `KeychainStore`, existing key pattern
- Produces: `openrouterAPIKey` property, `keys_openrouter` keychain key, settings UI

- [ ] **Step 1: Add openrouterAPIKey to SettingsStore**

Add to `SettingsStore.swift`:

```swift
var openrouterAPIKey: String = ""
```

Update `loadFromKeychain()`:

```swift
openrouterAPIKey = ""
```

Update `saveToKeychain()`:

```swift
if !openrouterAPIKey.isEmpty {
    try? keychain.save(openrouterAPIKey, forKey: "keys_openrouter")
}
```

Update `existingKey(for:)`:

```swift
case "OpenRouter": key = "keys_openrouter"
```

- [ ] **Step 2: Add OpenRouter section to SettingsView**

Add before the save button in `apiKeysSection`:

```swift
// OpenRouter
VStack(alignment: .leading, spacing: 8) {
    HStack {
        Text("OPENROUTER")
            .font(Theme.Fonts.manrope(10, weight: .bold))
            .foregroundStyle(Theme.Colors.textMuted)
            .tracking(1.2)
        Spacer()
        Text(settingsStore.openrouterAPIKey.isEmpty ? "Missing" : "Configured ✓")
            .font(Theme.Fonts.manrope(10, weight: .medium))
            .foregroundStyle(settingsStore.openrouterAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                (settingsStore.openrouterAPIKey.isEmpty ? Theme.Colors.cardAmber : Theme.Colors.success).opacity(0.15),
                in: .capsule
            )
    }

    SecureField("Enter OpenRouter API key", text: $settingsStore.openrouterAPIKey)
        .font(Theme.Fonts.manrope(14))
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(12)
        .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
        )
}
```

- [ ] **Step 3: Verify compilation**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Settings/SettingsStore.swift Glance/Settings/SettingsView.swift
git commit -m "feat: add OpenRouter API key management to Settings"
```

---

### Task 15: Add New Files to Xcode Project

**Files:**
- Modify: `Glance/Glance.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: all new files from Tasks 1-12
- Produces: All files registered in Xcode project and compilable

- [ ] **Step 1: Add all new Swift files to the Xcode project**

This step requires adding each new `.swift` file to `project.pbxproj` so Xcode compiles them. The safest approach is to open the project in Xcode and drag the files in, or use `xcodebuild` after manual registration.

Files to add:
- `Glance/Features/SmartSearch/SmartSearchModels.swift`
- `Glance/Features/SmartSearch/SmartSearchPipeline.swift`
- `Glance/Features/SmartSearch/SmartSearchView.swift`
- `Glance/Features/SmartSearch/QuickSearchView.swift`
- `Glance/Features/SmartSearch/QuickSearchResultRow.swift`
- `Glance/Features/SmartSearch/DeepResearchView.swift`
- `Glance/Features/SmartSearch/ResearchListView.swift`
- `Glance/Features/SmartSearch/ResearchFileRow.swift`
- `Glance/Features/SmartSearch/MarkdownPreviewView.swift`
- `Glance/Core/Network/OpenRouterClient.swift`
- `Glance/Core/Network/ExaEnhancedClient.swift`
- `Glance/Core/Cache/MarkdownStore.swift`

- [ ] **Step 2: Full build verification**

Run: `cd /Users/atifkhan/development/glance-ios/Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "chore: register SmartSearch files in Xcode project"
```

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-19-smart-search.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
