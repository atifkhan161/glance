# GitHub README Preview — Design

**Date:** 2026-10-12
**Status:** Approved in conversation, reviewed

## Intent

`RepoDetailView` today shows an avatar, a name, a one-line description, four stat
cells, a language pill, a contributor list, and a link out. Someone tapping a trending
repo learns almost nothing about what the project *is*. The README is the single
highest-signal piece of information GitHub publishes about a repo, and we drop it on
the floor.

This adds a rendered README to the bottom of the repo detail screen.

## Goals

- Show the actual README of the tapped repo, rendered richly — headings, lists, tables,
  images, badges, collapsible `<details>`, and per-token syntax-highlighted code.
- Render it in **Manrope** and **JetBrains Mono** (the app's bundled faces) with syntax
  colors mapped onto the active Glance theme, inside a `surface1` card matching every
  other card on the screen.
- Never cost an API call in the common path.
- Work offline for a repo you've already opened.

## Non-goals

- **Not** adding topics, license, open-issues, last-push, or any other repo metadata.
  Scoped out explicitly — README only.
- **Not** rendering markdown locally. No `swift-markdown`, no `Down`, no markdown-it.
- **Not** a second navigation mode. No tabs, no Overview/README split, no collapsed
  header. The README is appended to the existing single scroll.
- **Not** a caching layer for repo metadata.
- **Not** using a GitHub token. Everything works unauthenticated.
- **Not** listing README cache entries in Settings.

## Anti-goals

Things that would make this a failure even if it technically worked:

- A README that renders in GitHub's light/dark palette while the rest of the app sits in
  a Glance theme.
- A webview that renders at zero height, jumps on load, or truncates tall content.
- Burning the 60/hr unauthenticated API budget on every tap.
- Blocking or freezing the detail screen while the README loads.
- Showing a scary error for a repo that simply has no README.
- A visible seam where the README's typeface stops matching the cards above it.

## Constraints

- No new third-party dependencies.
- Must follow existing house patterns: `HTTPTransport`, `CacheStore`, a
  `Protocol` + struct-default-conformance pair, `Theme.*` accessors, `@Observable`
  stores, `GlanceError` for failures.
- `WKWebView` must live inside the detail screen's existing `ScrollView`.
- App ships Manrope (Regular/SemiBold/Bold/ExtraBold), Hanken Grotesk (3), and
  JetBrains Mono (4) via `UIAppFonts` (`Info.plist:25-33`).

---

## Approach

### 1. Fetching the README

Three routes were tested live. All work with zero authentication.

| Route | Auth | Rate limit | Returns |
|---|---|---|---|
| `api.github.com/repos/{o}/{r}/readme` + `Accept: application/vnd.github.html+json` | none | 60/hr/IP, **2 requests per call** (301 then 200) | finished HTML |
| `raw.githubusercontent.com/{o}/{r}/HEAD/README.md` | none | not in any bucket | markdown **source** |
| `GET https://github.com/{o}/{r}` scrape | none | none observed | finished HTML + metadata |

Order:

1. **Primary — scrape `github.com/{owner}/{repo}`.** Free, returns GitHub's own rendered
   HTML, and matches the regex-scraping pattern `GitHubTrendingClient` already uses.
   Cost is ~370–440 KB per fetch, mitigated by caching. Reuse the trending client's
   header set (mobile Safari UA + `Accept: text/html,application/xhtml+xml` +
   `Accept-Language`) — GitHub serves different markup by UA.
2. **Fallback — the API `.html+json` route.** Attempted only when the scrape *succeeds*
   but yields no article, or the scrape 404s. **Never** on a transport failure — an
   offline tap should not fire two doomed requests. Costs 2 of the 60/hr budget, only on
   that path.

The raw-CDN route is rejected: it returns markdown source, which would force us to build
the parser this design exists to avoid, and it requires an exact `README.md` filename
(`.rst`/`.txt`/differently-cased names 404).

### 2. Extracting the article

The scraped page contains the README **twice**:

- the real DOM `<article class="markdown-body …">` (offset ~395 KB on a 436 KB page), and
- a **JSON-escaped copy** inside the embedded React payload under `"richText":"…"`
  (offset ~173 KB), where `<` is written `<`.

A naive "first `markdown-body` match" grabs the escaped copy and yields broken output.
Extraction must scan candidate `<article>` tags in document order and **skip any whose
preceding ~60 characters contain `richText":"`**, then take the first survivor's contents
through to its matching `</article>`.

Verified against `vercel/next.js` (11.9 KB article, 5 images) and `react/react`
(17.4 KB article).

**Treat the `richText` filter as a heuristic, not a guarantee.** Extraction should also
assert the result looks like a README (non-trivial length, contains block markup), and
return nil rather than emitting a mangled article.

### 3. Absolute URLs

Repos get moved: `github.com/facebook/react` **301s to `github.com/react/react`**.
`URLSession` follows it, and `HTTPTransport.data(for:hint:)` returns the final
`HTTPURLResponse`, so the resolved URL is available. Relative `src`/`href` inside the
extracted article must be rewritten to absolute against that resolved URL during
extraction — this is what frees the webview to load from a local file (see §5).

### 4. Caching and state

`CacheStore`, key `cache_github_readme_{owner}_{name}`, exposed as a `static` factory on
`CacheStore` alongside the existing `customRSSKey` helper. **No `defaultTTLs` entry is
needed** — expiry travels on the envelope (`CacheEnvelope.ttlMs`), and no test asserts
exhaustiveness of that dictionary. **No `CacheStore` "registration" is needed** —
`allKeys()` sweeps every `cache_`-prefixed key, so `hydrate()` and `clearAll()` already
cover it.

Cache the **extracted article HTML**, not the generated document. Smaller cache entries,
and a theme change re-renders correctly from cache.

**A "no README" result is negatively cached** with the same TTL. Otherwise every tap of a
README-less repo re-downloads 400+ KB.

Read-through follows `GenericRSSPipeline.loadCached` as the precedent: the pipeline owns
the cache, the store owns the async load and the UI state.

State uses the house `CardState<T>` (`PulseStore.swift:7-14`), whose `.stale` and
`.offline` cases cover the offline goal. An expired-but-present cache entry renders
immediately as `.stale` and revalidates in the background.

#### 404 semantics

A 404 means different things on the two routes and must be disambiguated:

| Condition | Result |
|---|---|
| Scrape 404 | Try API fallback (a 404 on the repo page is unexpected; the API gives the true signal) |
| Scrape OK, no article found | Try API fallback |
| API 404 | **No README.** Render nothing. No error, no retry. |
| Scrape transport failure | Surface error. Do not attempt fallback. |
| API failure / rate limited | Surface error with retry |

Rate limiting surfaces as `GlanceError.unauthorized`, not `.rateLimited`, because
`HTTPStatusMapper` maps 403 → `.unauthorized` and GitHub signals unauthenticated
exhaustion with 403 on some routes. The error UI must not claim "rate limited" unless
the status was actually 429.

### 5. Rendering

`WKWebView` in a `UIViewRepresentable`.

**Fonts.** A `WKWebView` loaded with a `github.com` base URL cannot reach the app bundle,
so `font-family: Manrope` would silently fall back to the system face — exactly the
"pasted webpage" failure the anti-goals forbid. Instead: absolutize relative URLs during
extraction (§3), then `loadFileURL` from a generated temp file with
`allowingReadAccessURL` set to the bundle resources directory. The webview then resolves
`Manrope` / `JetBrains Mono` from the bundle and the app renders in its real typeface
with no base64 bloat and no network dependency for fonts. The temp file is written per
render and deleted on teardown.

**Syntax highlighting.** GitHub's rendered article carries its own token classes —
`<span class="pl-k">` for keywords, `pl-s` strings, `pl-en` entity names, `pl-n` numbers,
`pl-c` comments, and so on — and wraps code in `<table class="highlight">` /
`<div class="highlight highlight-source-*">`. Stripping the page to the article discards
GitHub's stylesheet but **keeps the classes**, so highlighting survives. The theme CSS
maps them:

| GitHub class | Theme color |
|---|---|
| `pl-k`, `pl-kn`, `pl-kc`, `pl-kt`, `pl-kd` | `tierPurple` |
| `pl-s`, `pl-s1`, `pl-s2`, `pl-sa`, `pl-sr` | `cardCyan` |
| `pl-en`, `pl-fc` | `cardEmerald` |
| `pl-n`, `pl-no`, `pl-nc` | `cardAmber` |
| `pl-c`, `pl-c1`, `pl-cm` | `textMuted`, italic |
| `pl-v`, `pl-vb`, `pl-py` | `textPrimary` |
| `pl-o`, `pl-p` | `textSecondary` |

Code blocks get a `canvasDeep`-toned background and `borderSubtle` border, matching the
app rather than GitHub. The `<table class="highlight">` wrapper must be styled to a
non-tabular layout or code renders as a broken grid.

**Card treatment.** The README sits in a `surface1` card with `Theme.cornerRadius` and
`Theme.cardPadding`, identical to every other card on the screen, with a
`cardEmerald`-tinted border to match the header card's treatment.

**Theme.** CSS is generated per render by interpolating
`ThemeManager.shared.current.colors` into the document, so the README follows whichever
theme the user picked. Note `ThemeManager.selectedID` wraps its backing store in a
hand-rolled lock accessor, so `@Observable` does not track it the way a plain stored
property would — a theme change does **not** live-update an open README. It renders
correctly on next appearance. Making it live is out of scope.

**Height.** The webview scrolls as part of the parent `ScrollView`:

- `scrollView.isScrollEnabled = false`, `bounces = false` — only the parent scrolls.
- Height bound to a `@State`, fed by KVO on `scrollView.contentSize` **and** by
  `document.documentElement.scrollHeight` in `didFinish`.
- READMEs are image-heavy and the height grows as images decode, so a JS `ResizeObserver`
  posts the height back on every change rather than measuring once. Precedence: the
  `ResizeObserver` value wins while the document is live; `didFinish` seeds the first
  value. Debounce by a few points to avoid thrash while the parent `ScrollView` moves.
- A `WKWebView` does not shrink when shorter content is loaded into it, so when the
  README changes the webview is **rebuilt, not reloaded** — via `.id()` on the view root.

**Identity.** `RepoDetailView` is constructed once per pushed repo
(`PulseView.swift:97-99`) and holds `let repository`. Pushing repo B after popping repo A
can reuse the same view identity, so `@State` would carry repo A's README into repo B.
The view root is therefore `.id(repository.fullName)` — on the root, not on the webview
alone, so the whole per-repo state resets together.

**Links.** Taps are intercepted in `WKNavigationDelegate` and opened outside the webview
so the detail screen keeps its place.

**Sanitization.** The extracted HTML is remote content rendered in a JS-enabled webview.
Strip `<script>`, `<iframe>`, `<object>`, `<embed>`, and inline `on*` handler attributes
before interpolation, following the strip list already in `ArticleScraper.swift:24-42`.
JavaScript stays enabled only for our own injected `ResizeObserver`; remote scripts never
execute. Remote images (`camo.githubusercontent.com`, `github-user-assets`) do load —
READMEs are unusable without them.

**Accessibility.** A scroll-disabled webview is a known weak spot for VoiceOver
traversal and Dynamic Type (CSS px do not scale). Acknowledge this in the implementation;
it is not a launch blocker but should not be silently ignored.

---

## Screen composition

Appended at the bottom of the existing `ScrollView`, after the contributors card. Both the
language card and the contributors card are conditional (`RepoDetailView.swift:61,77`),
so the README follows whichever cards rendered.

The "Open on GitHub" button moves from its current position to **after** the README card,
so it terminates the page. With no README it simply sits where it does today.

States:

- **Loading** — a placeholder card sized to avoid a layout jump when content lands.
- **No README** — render **nothing**. Not an error, no retry affordance.
- **Fetch failed** — a compact inline notice with a retry action. The existing
  `GlanceErrorView` is a 40-padded full-width centered-icon alert; a compact row is
  better here and a new small component is expected.

---

## Parts

| Concern | Location |
|---|---|
| README fetch + article extraction + URL absolutization | `Glance/Core/Network/GitHubReadmeClient.swift` (new, mirrors `GitHubTrendingClient`) |
| Protocol + conformance | same file |
| Cache key factory | `Glance/Core/Cache/CacheStore.swift` |
| Fetch/cache orchestration | `Glance/Features/GitHub/GitHubPipeline.swift` |
| Async load + state (`@Observable`, `CardState`) | `Glance/Features/GitHub/RepoDetailStore.swift` (new) |
| Webview, CSS generation, syntax color mapping, temp-file loading | `Glance/DesignSystem/READMEWebView.swift` (new) |
| Screen composition + retry notice | `Glance/Features/GitHub/RepoDetailView.swift` |
| Tests + HTML fixtures | `Glance/GlanceTests/GitHubReadmeClientTests.swift` (new) |

`READMEWebView` lives in `DesignSystem/` because the CSS generation is generic machinery;
the README-specific parts (the token map, the card treatment) are passed in or live with
the feature. **Builder's call.**

### Test infrastructure

`MockURLProtocol` is currently `private` to `GitHubTrendingClientTests.swift:5` and never
implements `didReceive(_:cacheStoragePolicy:)`. It must be lifted to a shared internal
test helper and taught to emit 301s, or the redirect test is untestable. Committed HTML
fixtures (one page containing the `richText` decoy, one with no article) are required —
the extraction test has nothing to assert against otherwise, and the real page will drift
silently.

### Tests to write

- Extraction picks the DOM article, not the `richText` decoy.
- Extraction returns nil for a page with no article.
- Relative URLs are absolutized against the resolved URL.
- Fetch follows a 301 and reports the resolved URL.
- Cache hit returns without a network call; TTL expiry re-fetches.
- No-README result is negatively cached (second call makes no network request).
- Failed fetch surfaces `GlanceError` for the retry affordance.

**Do not run these.** Per `AGENTS.md`, tests are written when asked and never executed
unprompted.

---

## Decisions made by me, for review

These were open in the first draft. Rationale is in the sections above.

1. Cache the extracted article, not the generated document — smaller, and theme-correct
   on re-render.
2. Negatively cache the no-README result — otherwise 400+ KB per tap, forever.
3. Do not attempt the API fallback after a transport failure — don't double a doomed tap.
4. `API 404` is the authoritative no-README signal; a scrape 404 isn't.
5. Render no-README as silence, per your call — the states table encodes this.
6. No `CacheStore` `defaultTTLs` entry and no Settings listing — neither is needed.
7. Theme changes do not live-update an open README; out of scope.
8. Sanitize remote HTML but allow remote images.

## Open items for the builder

Settle these yourself; none change what gets built:

- Whether `READMEWebView` stays generic or absorbs the token map.
- Whether the `ResizeObserver` is inline JS in the generated document or a
  `WKUserScript` at configuration time.
- Exact debounce for height updates.
- Whether to extend `CardState` or add a README-specific case for the no-README silence.
- Whether `MockURLProtocol` moves to a new shared file or gains a sibling.