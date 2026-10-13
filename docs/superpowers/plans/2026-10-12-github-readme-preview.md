# GitHub README Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the tapped repository's GitHub README in Manrope and JetBrains Mono with theme-mapped syntax colors, inside a card at the bottom of `RepoDetailView`.

**Architecture:** Scrape `github.com/{owner}/{repo}` for GitHub's already-rendered README HTML (free, no API budget), falling back to `api.github.com/repos/{o}/{r}/readme` with `Accept: application/vnd.github.html+json` only when the scrape yields nothing. Extract the DOM `<article class="markdown-body">`, skipping the JSON-escaped `richText` decoy, absolutize relative URLs, cache the article HTML for 24h (negatively caching "no README"), then render it in a `WKWebView` loaded from a temp file with bundle read access so bundled fonts resolve.

**Tech Stack:** SwiftUI, WebKit, Swift Concurrency, Swift Testing, existing `HTTPTransport` / `CacheStore` / `Theme`

**Spec:** `docs/superpowers/specs/2026-10-12-github-readme-preview-design.md`

## Global Constraints

- **No new third-party dependencies.** No `swift-markdown`, no `Down`, no markdown-it.
- **No GitHub token.** Everything works unauthenticated.
- **Never run tests.** Per `AGENTS.md`, tests are written but never executed unprompted. Verify with `xcodebuild build` only.
- Build verification command (the only verification in this plan):
  ```bash
  cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance \
    -destination 'platform=iOS Simulator,id=4ABF9BBF-AB35-4739-B282-0EE19B2CE023,OS=26.5' \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
  ```
- **New `.swift` files must be registered in `project.pbxproj`** — git tracking is not enough. Each new file needs exactly 4 hits: build file, file ref, group child, Sources phase. `.gitignore` blocks `*.xcodeproj`, so commit with `git add -f`.
- No inline comments. Code should be self-documenting, per `AGENTS.md`.
- All styling through `Theme.*`. No hardcoded colors or font sizes in SwiftUI.
- Tests use **Swift Testing** (`import Testing`, `@Suite`, `@Test`), matching `GlanceTests/`.
- Cache TTL is `24 * 3_600_000` ms, matching `GitHubPipeline.swift:55`.

## Review Focus

Five input classes the spec implies that no happy-path test catches. Each has a test pinned to the task that owns the code.

1. **README-less repo, tapped repeatedly** — must not re-download 400+ KB each time (Task 4: negative cache test).
2. **Repo moved/renamed (`facebook/react` → `react/react`)** — relative images in the README must still load (Task 2: 301 + absolutization test).
3. **README shorter than the previously-rendered one in the same view** — content must not be truncated at the old height (Task 6: webview rebuild via `.id`).
4. **GitHub changes its page markup** — extraction must fail to nil (render nothing) rather than emit mangled half-HTML (Task 2: plausibility guard test).
5. **Offline tap on an already-read repo** — must render the cached README, not an error (Task 4: cache-hit test).

---

## File Structure

| File | Responsibility |
|---|---|
| `Glance/Core/Network/GitHubReadmeClient.swift` | **New.** Protocol + struct. Scrapes the repo page, extracts the article, absolutizes URLs, falls back to the API. Owns all regex/parsing. |
| `Glance/Core/Cache/CacheStore.swift` | **Modify.** Add `readmeKey(owner:name:)`. No `defaultTTLs` entry needed. |
| `Glance/Features/GitHub/GitHubPipeline.swift` | **Modify.** Add `readme(for:)` — read-through cache + fetch + write, including negative caching. |
| `Glance/Features/GitHub/RepoDetailStore.swift` | **New.** `@Observable`, `CardState<GitHubReadme?>`-equivalent state machine + retry. |
| `Glance/DesignSystem/READMEWebView.swift` | **New.** Temp-file HTML generation (CSS + syntax token map), `WKWebView` wrapper, height measurement, link interception, sanitization. |
| `Glance/Features/GitHub/RepoDetailView.swift` | **Modify.** Own store, insert card, move "Open on GitHub" below it. |
| `Glance/GlanceTests/MockGitHubURLProtocol.swift` | **New.** Shared `URLProtocol` stub supporting queued responses and 3xx. |
| `Glance/GlanceTests/GitHubReadmeClientTests.swift` | **New.** Extraction, absolutization, redirect, fallback, guard tests. |
| `Glance/GlanceTests/GitHubPipelineTests.swift` | **Modify.** Cache hit/miss, negative cache tests. |
| `Glance/GlanceTests/Fixtures/*.html` | **New.** Trimmed real pages: one with the `richText` decoy, one with no article. |

---

### Task 1: Shared test protocol stub

The existing `MockURLProtocol` is `private` to `GitHubTrendingClientTests.swift:5`, returns a single fixed `Data`, and never implements `didReceive(_:cacheStoragePolicy:)` — so it cannot express a 301 or a sequence of responses. Extract a shared stub before any client test needs it.

**Files:**
- Create: `Glance/GlanceTests/MockGitHubURLProtocol.swift`
- Modify: `Glance/GlanceTests/GitHubTrendingClientTests.swift` (delete its private copy, point at the shared one)
- Test: this file

**Interfaces:**
- Consumes: nothing
- Produces:
  ```swift
  final class MockGitHubURLProtocol: URLProtocol {
      struct Stub { let statusCode: Int; let data: Data?; let headers: [String: String] }
      static var stubs: [Stub]
      static var error: Error?
      static var requestedURLs: [URL]
      static func reset()
  }
  extension MockGitHubURLProtocol {
      static func makeSession() -> URLSession
  }
  ```
  `stubs` is consumed in order; the last one repeats if more requests arrive.

- [ ] **Step 1: Create the shared stub**

Create `Glance/GlanceTests/MockGitHubURLProtocol.swift` with the signatures above. `startLoading` pops the next stub, and when `Stub.statusCode` is in `300..<400` calls `client?.urlProtocol(self, wasRedirectedTo:redirectResponse:)` followed by `didReceive(_:cacheStoragePolicy:)` so `URLSession` genuinely follows the redirect and the final `HTTPURLResponse.url` reflects the post-redirect location. Use the `Stub.headers` value for `Location`. `makeSession()` returns a `URLSession` whose configuration has `protocolClasses = [MockGitHubURLProtocol.self]`.

- [ ] **Step 2: Delete the private copy from `GitHubTrendingClientTests.swift`**

Remove the `private class MockURLProtocol` block (lines 5–21) and change its `mockClient(html:)` helper to build the session via `MockGitHubURLProtocol.makeSession()` after calling `MockGitHubURLProtocol.reset()` and setting a single 200 stub with the HTML. The rest of that suite is unchanged.

- [ ] **Step 3: Build**

Run the Global Constraints build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Glance/GlanceTests/MockGitHubURLProtocol.swift Glance/GlanceTests/GitHubTrendingClientTests.swift
git commit -m "chore: extract shared github mock url protocol"
```

---

### Task 2: README fetch and article extraction

**Files:**
- Create: `Glance/Core/Network/GitHubReadmeClient.swift`
- Create: `Glance/GlanceTests/Fixtures/readme-with-decoy.html`, `Glance/GlanceTests/Fixtures/no-readme.html`
- Test: `Glance/GlanceTests/GitHubReadmeClientTests.swift`
- Register both new files in `project.pbxproj`

**Interfaces:**
- Consumes: `MockGitHubURLProtocol` from Task 1
- Produces:
  ```swift
  struct GitHubReadme: Codable, Sendable, Equatable {
      let fullName: String
      let html: String
      let resolvedURL: String
  }

  protocol GitHubReadmeClientProtocol: Sendable {
      func fetchReadme(owner: String, name: String) async throws -> GitHubReadme?
  }

  struct GitHubReadmeClient: GitHubReadmeClientProtocol, Sendable {
      init(session: URLSession? = nil)
      func fetchReadme(owner: String, name: String) async throws -> GitHubReadme?
      static func extractArticle(from html: String) -> String?
      static func absolutizeURLs(in fragment: String, base: URL) -> String
      static func sanitize(_ fragment: String) -> String
  }
  ```
  `fetchReadme` returns `nil` when the repo has no README. It throws `GlanceError` only for genuine failures. **It never returns `nil` for a transport failure** — it throws.

- [ ] **Step 1: Commit the HTML fixtures**

`Glance/GlanceTests/Fixtures/readme-with-decoy.html` — trimmed from a real `vercel/next.js` page. Must preserve the ordering that makes extraction hard: a `"richText":"\u003carticle class=\"markdown-body …` string appearing **before** the real `<article class="markdown-body">` element, then the real article containing an `<img src="/vercel.png">` and `<a href="./docs">` for the absolutization test.

`Glance/GlanceTests/Fixtures/no-readme.html` — a repo page with no `markdown-body` article anywhere.

Add the two `.html` files to the `GlanceTests` target's **Resources** build phase in `project.pbxproj`. The suite loads them with `Bundle(for:)`-style lookup — since this is a Swift Testing bundle, use `Bundle.module`-equivalent `Bundle(for: GitHubReadmeClientTests.self)` is not available for a non-class type; instead use `Bundle.main.url(forResource:withExtension:subdirectory:)` and fall back to the source-relative path via `#filePath`. State which one you used in the commit body.

- [ ] **Step 2: Write the client**

In `Glance/Core/Network/GitHubReadmeClient.swift`:

`extractArticle(from:)` — scan `<article[^>]*>` matches in document order with `NSRegularExpression`. For each, check the 60 characters preceding the match for `richText":"`; skip if found. For the first survivor, take contents from the match end to the next `</article>`. Then apply a plausibility guard: return `nil` unless the trimmed result is at least 200 characters **and** contains at least one block-level tag (`<p`, `<h1`–`<h6`, `<ul`, `<pre`, `<table`, `<img`, `<div`). This guard is what stops a markup change from emitting mangled half-HTML.

`absolutizeURLs(in:base:)` — rewrite `src` and `href` attributes whose value is relative (does not start with `http://`, `https://`, `//`, `data:`, `mailto:`, `#`) against `base`. Use `URL(string: relative, relativeTo: base)?.absoluteURL`. Preserve `#anchor` fragments.

`sanitize(_:)` — strip `<script>[\s\S]*?</script>`, `<iframe>`, `<object>`, `<embed>`, `<style>`, and any `on*="..."` / `on*='...'` attribute. Do **not** strip `<img>`, `<table>`, `<pre>`, or `<svg>` — the README is unusable without them and the syntax classes must survive.

`fetchReadme(owner:name:)` — the flow, with these branches exactly as specified:

```
URL https://github.com/{owner}/{name}
  headers: mobile Safari UA, Accept: text/html,application/xhtml+xml, Accept-Language: en-US,en;q=0.9
  request.timeoutInterval = 25   (the shared session's 15s resource cap is too tight for ~440 KB)
  hint: "readme \(owner)/\(name)"

  transport/data → (data, http)
    on GlanceError.httpStatus(404)  → go to apiFallback
    on any other GlanceError        → rethrow (never fall back after a transport failure)
    on success:
        resolvedURL = http.url
        html = String(data:, .utf8) ?? rethrow decodingError
        article = extractArticle(html)
          nil → apiFallback
          some → return GitHubReadme(fullName:, html: absolutize(article, base: resolvedURL), resolvedURL: resolvedURL.absoluteString)

apiFallback:   (reached only from a 404 or an empty extraction)
  GET https://api.github.com/repos/{owner}/{name}/readme
    Accept: application/vnd.github.html+json
    User-Agent: Glance-iOS
  httpStatus(404)  → return nil            (authoritative no-README signal)
  other GlanceError → rethrow
  success → return GitHubReadme(fullName:, html: sanitize(raw), resolvedURL: http.url?.absoluteString ?? "")
```

The API body is raw HTML, not a page — pass it through `sanitize` but not through `extractArticle`.

- [ ] **Step 3: Write the tests**

In `Glance/GlanceTests/GitHubReadmeClientTests.swift`, a `@Suite("GitHubReadmeClient")` with:

- `extractsDomArticleNotRichTextDecoy` — load `readme-with-decoy.html`, assert `extractArticle` returns a string containing the real article's text and **not** the literal `\u003c` escape sequence.
- `extractReturnsNilWhenNoArticle` — `no-readme.html` → `nil`.
- `extractRejectsImplausiblyShortArticle` — `"<article class=\"markdown-body\">hi</article>"` → `nil`.
- `absolutizesRelativeImagesAndLinks` — assert `src="/vercel.png"` becomes `https://github.com/vercel.png` and `href="./docs"` becomes `https://github.com/docs`, while `https://…` and `#anchor` are untouched.
- `followsRedirectAndReportsResolvedURL` — stub a 301 with `Location: https://github.com/react/react` then a 200 carrying the fixture; assert `resolvedURL == "https://github.com/react/react"`.
- `returnsNilWhenApiFallbackIs404` — stub a 200 page with no article, then a 404 for the API; assert `nil`.
- `doesNotFallBackAfterTransportFailure` — stub a transport error on the first request; assert it throws and that `requestedURLs.count == 1`.
- `sanitizeStripsScriptsButKeepsImages` — assert `<script>` gone, `<img` retained.
- `stripsInlineEventHandlers` — assert `onclick="…"` is gone.

- [ ] **Step 4: Build**

Run the Global Constraints build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add -f Glance/Glance.xcodeproj/project.pbxproj
git add Glance/Core/Network/GitHubReadmeClient.swift Glance/GlanceTests/GitHubReadmeClientTests.swift Glance/GlanceTests/Fixtures
git commit -m "feat: fetch and extract github readme html"
```

---

### Task 3: Cache key

**Files:**
- Modify: `Glance/Core/Cache/CacheStore.swift` (near `customRSSKey`, line 33)
- Test: additions to `Glance/GlanceTests/CacheStoreTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  ```swift
  static let readmePrefix = "cache_github_readme_"
  static func readmeKey(owner: String, name: String) -> String
  ```
  Key format: `cache_github_readme_{owner}_{name}`.

- [ ] **Step 1: Add the key factory**

Mirror the existing `customRSSPrefix` / `customRSSKey` pair. **Do not add a `defaultTTLs` entry** — expiry rides on `CacheEnvelope.ttlMs`, and `allKeys()` already sweeps every `cache_`-prefixed key so `hydrate()` and `clearAll()` pick these up automatically.

- [ ] **Step 2: Add a test**

In `CacheStoreTests.swift`: a test asserting `readmeKey(owner: "vercel", name: "next.js") == "cache_github_readme_vercel_next.js"` and that two different repos produce different keys.

- [ ] **Step 3: Build and commit**

```bash
git add Glance/Core/Cache/CacheStore.swift Glance/GlanceTests/CacheStoreTests.swift
git commit -m "feat: add github readme cache key"
```

---

### Task 4: Pipeline read-through cache

**Files:**
- Modify: `Glance/Features/GitHub/GitHubPipeline.swift`
- Test: additions to `Glance/GlanceTests/GitHubPipelineTests.swift`

**Interfaces:**
- Consumes: `GitHubReadmeClientProtocol` / `GitHubReadmeClient` / `GitHubReadme` (Task 2), `CacheStore.readmeKey` (Task 3)
- Produces:
  ```swift
  struct GitHubPipeline: Sendable {
      init(trendingClient:cache:readmeClient:)
      func readme(owner: String, name: String, forceRefresh: Bool = false) async throws -> GitHubReadme?
  }
  ```
  `readme(...)` returns `nil` for no-README and throws `GlanceError` for failure. Callers cannot distinguish "cached nil" from "freshly determined nil" — by design.

- [ ] **Step 1: Add the readme client dependency and method**

Extend `GitHubPipeline.init` with `readmeClient: any GitHubReadmeClientProtocol = GitHubReadmeClient()`. Keep `cache: CacheStore = .shared`.

```swift
func readme(owner: String, name: String, forceRefresh: Bool = false) async throws -> GitHubReadme? {
    let key = CacheStore.readmeKey(owner: owner, name: name)
    if !forceRefresh, let envelope: CacheEnvelope<GitHubReadme?> = await cache.load(key) {
        if !envelope.isExpired { return envelope.data }
    }
    let fetched = try await readmeClient.fetchReadme(owner: owner, name: name)
    await cache.save(key, envelope: CacheEnvelope(data: fetched, ttlMs: 24 * 3_600_000))
    return fetched
}
```

Caching the `nil` is deliberate — it is what stops a README-less repo re-downloading 400+ KB on every tap. Note `CacheEnvelope<GitHubReadme?>` is legal because `Optional` is `Codable` when its `Wrapped` is, but confirm it round-trips: `JSONEncoder` encodes `nil` as `null` inside the `data` key, and `JSONDecoder` decodes it back to `nil`. If it does not round-trip, use a wrapper struct `ReadmeCacheEntry { let readme: GitHubReadme? }` instead and cache that.

- [ ] **Step 2: Add the tests**

In `GitHubPipelineTests.swift`, with a spy client recording call counts:

- `readmeReturnsCachedWithoutNetwork` — prime the cache, call `readme`, assert the spy was called 0 times.
- `readmeRefetchesWhenExpired` — cache with a TTL already in the past, assert 1 spy call.
- `readmeNegativelyCachesNoReadme` — spy returns `nil`; call twice; assert 1 spy call total.
- `readmeForceRefreshBypassesCache` — assert `forceRefresh: true` calls the spy.

Construct with `UserDefaults(suiteName:)`-isolated `CacheStore` instances — `AGENTS.md` documents that sharing `UserDefaults.standard` across `CacheStore` actors caused a 10-minute full-suite stall.

- [ ] **Step 3: Build and commit**

```bash
git add Glance/Features/GitHub/GitHubPipeline.swift Glance/GlanceTests/GitHubPipelineTests.swift
git commit -m "feat: cache github readmes through pipeline"
```

---

### Task 5: README webview

The largest single piece. Manrope, Hanken Grotesk, and JetBrains Mono are all bundled via `UIAppFonts` (`Info.plist:25-33`), but a `WKWebView` whose `baseURL` is `github.com` cannot reach the app bundle — `font-family: Manrope` would silently fall back to the system face. Task 2's URL absolutization is what makes the fix possible.

**Files:**
- Create: `Glance/DesignSystem/READMEWebView.swift`
- Register in `project.pbxproj`

**Interfaces:**
- Consumes: `GitHubReadme` (Task 2), `ThemeManager.shared.current`
- Produces:
  ```swift
  struct READMEWebView: UIViewRepresentable {
      let readme: GitHubReadme
      var onHeightChange: (CGFloat) -> Void
      var onOpenExternal: (URL) -> Void
  }
  ```
  The view is **non-scrolling** — the parent `ScrollView` owns scrolling, so `onHeightChange` must fire on every document-size change, including after images decode.

- [ ] **Step 1: Write the CSS generator**

A private `enum READMEDocument` in the same file with `static func html(article: String, colors: ThemeColors) -> String`.

It must produce a full HTML document containing: the viewport meta tag, the article HTML, and a `<style>` block built by interpolating `colors` (so the README follows the user's selected theme). **Fetching hex out of `ThemeColors` is the hard part of this step** — the colors are `Color` values wrapping dynamic `UIColor`s built from `lightHex`/`darkHex` (`ThemeDefinition.swift:60-72`), and preset themes derive colors from HSL at runtime (`GlancePreset.swift:95+`) so there is no stored hex to read. Resolve each color at generation time against the effective trait collection:

```swift
let effectiveScheme: UIUserInterfaceStyle =
    ThemeManager.shared.current.colorSchemeOverride == .light ? .light : .dark
```

Use `.dark` unless the override says `.light` **and** the system is in light mode — `ThemeManagerTests.swift:98-100` documents presets that force light. Then `UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: effectiveScheme))` and read `getRed:green:blue:alpha:` to emit `#rrggbb`. A production `Color.hexString(resolvedScheme:)` helper is needed; mirror the logic in `ColorTestSupport.hex` (`ThemeManagerTests.swift:136-148`), which currently only handles a hardcoded `.dark` trait and lives in the test target.

The stylesheet must cover at minimum: `body`, `h1`–`h6`, `p`, `a`, `ul`/`ol`/`li`, `code`, `pre`, `table`/`th`/`td`, `blockquote`, `img`, `details`/`summary`, `hr`, and `div[align]`. Body uses `surface1` as background and `textSecondary` as base text. `pre` uses `canvasDeep` with a `borderSubtle` border. Code blocks render in `JetBrains Mono`.

**Critical:** GitHub's rendered code is wrapped in `<table class="highlight">` or `<div class="highlight highlight-source-*">`. Add a CSS rule forcing `table.highlight { display: block; }` and `table.highlight td { border: none; padding: 0; }`, or code renders as a broken grid.

**Syntax token map.** GitHub's token classes survive extraction (only its stylesheet is discarded), so map them onto theme colors — keyword `pl-k`/`pl-kn`/`pl-kc`/`pl-kt`/`pl-kd` → `tierPurple`; string `pl-s`/`pl-s1`/`pl-s2`/`pl-sa`/`pl-sr` → `cardCyan`; entity/function `pl-en`/`pl-fc` → `cardEmerald`; number/constant `pl-n`/`pl-no`/`pl-nc` → `cardAmber`; comment `pl-c`/`pl-c1`/`pl-cm` → `textMuted` italic; variable `pl-v`/`pl-vb`/`pl-py` → `textPrimary`; operator/punctuation `pl-o`/`pl-p` → `textSecondary`.

- [ ] **Step 2: Write the temp-file loader**

Write the generated document to a unique file in `FileManager.default.temporaryDirectory` and call `webView.loadFileURL(url, allowingReadAccessURL: bundleResourcesURL)` where the read-access URL is the bundle's resource directory. This is what lets `font-family: Manrope` resolve. Delete the temp file in `dismantleUIView`.

- [ ] **Step 3: Wire height measurement**

Three sources, with this precedence:

1. A JS `ResizeObserver` injected via `WKUserScript` at `.atEnd, forMainFrameOnly: true` that posts the document height on every change — this is the live source, because READMEs are image-heavy and height grows as images decode. Inject as a `WKUserScript` rather than inline JS so it cannot be affected by article content.
2. `webView(_:didFinish:)` seeds the first value via `document.documentElement.scrollHeight`.
3. KVO on `scrollView.contentSize` as a backstop.

Debounce reported heights by ~4 points to avoid thrashing the parent `ScrollView` while it moves.

Set `scrollView.isScrollEnabled = false` and `bounces = false` in `makeUIView`. A `WKWebView` does not shrink when shorter content is loaded into it — Task 6 handles that by rebuilding, not reloading.

- [ ] **Step 4: Intercept link taps**

In the `WKNavigationDelegate`, implement `decidePolicyFor navigationAction` and call `onOpenExternal(url)` then `.cancel` for any `http`/`https` navigation, so links leave the webview and the detail screen keeps its scroll position.

- [ ] **Step 5: Build**

Run the Global Constraints build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add -f Glance/Glance.xcodeproj/project.pbxproj
git add Glance/DesignSystem/READMEWebView.swift
git commit -m "feat: add themed readme webview"
```

---

### Task 6: Compose into the detail screen

**Files:**
- Create: `Glance/Features/GitHub/RepoDetailStore.swift`
- Modify: `Glance/Features/GitHub/RepoDetailView.swift`
- Register the store in `project.pbxproj`

**Interfaces:**
- Consumes: `GitHubPipeline.readme(owner:name:)` (Task 4), `READMEWebView` (Task 5)
- Produces:
  ```swift
  @MainActor @Observable
  final class RepoDetailStore {
      enum State: Equatable {
          case idle
          case loading
          case ready(GitHubReadme)
          case empty          // no README — render nothing
          case failed(message: String)
      }
      var state: State
      var height: CGFloat
      init(repository: GitHubTrendingRepo, pipeline: GitHubPipeline = GitHubPipeline())
      func load()
      func retry()
  }
  ```
  A bespoke enum rather than `CardState<T>`, because `CardState`'s `.stale`/`.offline` model a value that exists while `empty` is the absence of one. `State` is `Equatable` so the view can switch exhaustively.

- [ ] **Step 1: Write the store**

`load()` sets `.loading`, awaits `pipeline.readme(owner:name:)`, and maps `nil` → `.empty`, a value → `.ready`, and a thrown `GlanceError` → `.failed(message: error.localizedDescription)`. `retry()` calls `load()` with `forceRefresh: true`. Store the webview's reported height in `height`.

Do not treat a 403 as "rate limited" in the message — `HTTPStatusMapper` maps 403 → `.unauthorized` and GitHub signals unauthenticated exhaustion with 403 on some routes.

- [ ] **Step 2: Insert the card and move the button**

In `RepoDetailView`, wrap the body in `.id(repository.fullName)` on the **view root**. `RepoDetailView` is constructed once per pushed repo (`PulseView.swift:97-99`) and holds `let repository`, so pushing repo B after popping repo A can reuse the same view identity — without this, `@State` carries repo A's README into repo B, and the webview is not rebuilt when content shrinks.

Then, after the contributors card (which is conditional at line 77), render by state:

- `.loading` — a placeholder card using the app's existing skeleton treatment, fixed height so the layout does not jump when content lands.
- `.ready(readme)` — a `VStack` in `Theme.Colors.surface1` with `Theme.cornerRadius` and `Theme.cardPadding`, bordered `Theme.Colors.cardEmerald.opacity(0.3)` to match the header card's treatment at line 40, containing `READMEWebView` with `.frame(height: store.height)`.
- `.empty` — `EmptyView()`. No card, no error, no retry. Per the spec, a repo with no README is not a failure.
- `.failed(message)` — a compact inline row with the message and a retry button. **Do not reuse `GlanceErrorView`** (`Components.swift:28`) — it is a 40-padded full-width centered-icon alert, visually wrong for an inline slot. Build a small local notice view.

**Move the "Open on GitHub" `Link` (line 100) below the README card.** With no README it then simply sits where it does today.

Keep `@State private var store` initialized in `init` via `RepoDetailStore(repository: repository)`, and trigger `store.load()` from `.task`.

- [ ] **Step 3: Build**

Run the Global Constraints build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -f Glance/Glance.xcodeproj/project.pbxproj
git add Glance/Features/GitHub/RepoDetailStore.swift Glance/Features/GitHub/RepoDetailView.swift
git commit -m "feat: render github readme on repo detail"
```

---

## Self-Review

**Spec coverage.** Fetch routes and 404 semantics → Task 2. Article extraction and the `richText` decoy → Task 2. Absolute URLs → Task 2. Caching, negative caching, no `defaultTTLs`, no Settings listing → Tasks 3–4. Fonts via temp file → Task 5. Syntax token map and `table.highlight` rule → Task 5. Height re-measure on image load → Task 5. Link interception → Task 5. Sanitization → Task 2. `.id` rebuild → Task 6. Placement and button move → Task 6. States including silent-empty → Task 6. Test fixtures and shared mock → Task 1. Theme-change non-live-update → deliberately out of scope per spec.

**Step scan.** Every step names a signature or an assertion. The one algorithm step (Task 5's hex resolution) is spelled out because the signature does not determine it and `ThemeColors` has no stored hex.

**Type consistency.** `GitHubReadme` is produced in Task 2 and consumed unchanged in Tasks 4, 5, 6. `RepoDetailStore.State.ready(GitHubReadme)` matches. `readme(owner:name:forceRefresh:)` matches its call sites in Tasks 4 and 6.

**Review Focus coverage.** 1→Task 4, 2→Task 2, 3→Task 6 (documented; the `.id` on the view root is the mechanism, verified by build not by test since it is a view-identity property), 4→Task 2, 5→Task 4.

**Proportion.** Six tasks; the plan states signatures, branch tables, and CSS mappings rather than reproducing implementations. Task 5 is the one place where the CSS is enumerated rather than summarized, because the token map and the `table.highlight` rule are decisions that cannot be re-derived from a signature.