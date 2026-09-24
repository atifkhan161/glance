# Reddit Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Reddit subreddit feeds as Custom RSS cards (RSS URL builder + Option B external scrape + thumbnails), matching web Glance `type: reddit` / `show-thumbnails` intent with zero backend.

**Architecture:** Reuse the entire Custom RSS stack (`CustomRSSFeed` → `GenericRSSPipeline` → `PulseStore.customRSSCards` → existing card/detail/article views). Add a Reddit mode on `AddRSSFeedSheet` that builds `https://www.reddit.com/r/{sub}/{sort}.rss`, extend `MMArticle` with `thumbnailURL`, parse Media RSS thumbnails in `GenericRSSClient`, and resolve scrape targets via new `RedditLinkResolver` so link posts open external articles instead of reddit.com.

**Tech Stack:** Swift 5.9+, SwiftUI, `URLSession`, Foundation `XMLParser`, Swift Testing (`import Testing` / `@Test` / `#expect`), existing Theme/CacheStore.

**Spec:** `docs/superpowers/specs/2026-09-24-reddit-provider-design.md`

## Global Constraints

- Swift 5.9+ with strict concurrency (`Sendable`, actors)
- Use `@Observable` macro for view models (not `ObservableObject`)
- Use `@Environment(AppState.self)` for dependency injection
- All styling through `Theme.Colors.*`, `Theme.Fonts.*`, `Theme.Radius.*`
- No inline comments — code should be self-documenting
- File naming: named after primary type
- Network clients: `Glance/Core/Network/`; utilities: `Glance/Core/Utilities/`
- No secrets, API keys, or OAuth for Reddit
- New `.swift` files must be registered in `project.pbxproj` (gitignore blocks `*.xcodeproj` — use `git add -f` for pbxproj)
- Build before committing: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build`
- Tests: Swift Testing, not XCTest
- Custom RSS cache TTL remains `CacheStore.customRSSFreshTTL` (24h)
- Array literals use `let`/`var x = [...]`, never `var x: [a, b]` type-annotation syntax

## Review Focus

Failure modes the spec implies that naive implementations break — each is pinned to a task below:

1. **Legacy `customRSSFeeds` JSON without `showThumbnails`** — decode must default to `true` or existing users lose all custom feeds → Task 1 step: decode missing-key fixture.
2. **Scraping reddit.com on self/text posts** — 403 or useless chrome; must skip scrape when only Reddit URL → Task 4 resolver tests + Task 5 scrape decision.
3. **HTML-entity hrefs in Reddit Atom (`&amp;`)** — first external link extraction fails or scrapes wrong URL → Task 4 entity test.
4. **`media:thumbnail` as qualified name `media:thumbnail` vs local `thumbnail`** — thumbnail always nil if only one form handled → Task 2 tests cover both attribute styles.
5. **Memberwise init break** — adding `thumbnailURL` must not break existing `MMArticle(...)` call sites in Madrid/cache tests → Task 1 uses defaulted `var` and full build.
6. **Reddit 429 on multi-feed refresh** — serial tight loop of 2+ Reddit feeds → Task 7 spaces Reddit refreshes by 1s.

---

## File Map

### New Files (3)

| File | Responsibility |
|------|---------------|
| `Glance/Core/Utilities/RedditLinkResolver.swift` | Pure helpers: is-reddit-host, external href extraction, comments URL |
| `Glance/GlanceTests/RedditLinkResolverTests.swift` | Resolver unit tests |
| `Glance/GlanceTests/GenericRSSClientTests.swift` | Atom/RSS parse + thumbnail + CustomRSSFeed decode + Reddit feed URL tests |

### Modified Files (9)

| File | Change |
|------|--------|
| `Glance/Core/Network/ManagingMadridClient.swift` | `MMArticle.thumbnailURL: String? = nil` |
| `Glance/Core/Network/GenericRSSClient.swift` | Parse `media:thumbnail` / content `<img>`; expose parse-from-data for tests |
| `Glance/Settings/SettingsStore.swift` | `CustomRSSFeed.showThumbnails` + resilient `Codable` |
| `Glance/Settings/AddRSSFeedSheet.swift` | Segmented RSS/Reddit mode, URL builder, thumbnail toggle |
| `Glance/Features/CustomRSS/CustomRSSArticleView.swift` | Option B scrape target, Open comments, hero thumbnail |
| `Glance/Features/CustomRSS/CustomRSSCardView.swift` | Row thumbnails + Reddit accent |
| `Glance/Features/CustomRSS/CustomRSSDetailView.swift` | Row thumbnails |
| `Glance/Features/Pulse/PulseStore.swift` | 1s delay between Reddit feed refreshes in bulk loop |
| `Glance/Glance.xcodeproj/project.pbxproj` | Register 3 new files in correct groups + Sources phases |

---

### Task 1: MMArticle.thumbnailURL + CustomRSSFeed.showThumbnails

**Files:**
- Modify: `Glance/Core/Network/ManagingMadridClient.swift:7-16`
- Modify: `Glance/Settings/SettingsStore.swift:196-208`
- Test: `Glance/GlanceTests/GenericRSSClientTests.swift` (create — feed decode tests only in this task; parse tests added in Task 2)

**Interfaces:**
- Consumes: existing `MMArticle`, `CustomRSSFeed` initializers used across app
- Produces:
  - `MMArticle.thumbnailURL: String?` (default `nil`, last memberwise parameter)
  - `CustomRSSFeed.showThumbnails: Bool` (init default `true`; decode default `true` when key absent)
  - `CustomRSSFeed(name:url:isEnabled:)` and `CustomRSSFeed(name:url:isEnabled:showThumbnails:)` both valid

- [ ] **Step 1: Write failing decode test for CustomRSSFeed**

Create `Glance/GlanceTests/GenericRSSClientTests.swift`:

```swift
import Testing
@testable import Glance
import Foundation

@Suite("CustomRSSFeed Codable")
struct CustomRSSFeedCodableTests {
    @Test("Missing showThumbnails decodes as true")
    func missingShowThumbnailsDefaultsTrue() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111","name":"Old","url":"https://example.com/rss","isEnabled":true}
        """.data(using: .utf8)!
        let feed = try JSONDecoder().decode(CustomRSSFeed.self, from: json)
        #expect(feed.showThumbnails == true)
    }

    @Test("showThumbnails false is preserved")
    func showThumbnailsFalsePreserved() throws {
        let json = """
        {"id":"22222222-2222-2222-2222-222222222222","name":"NoThumb","url":"https://example.com/rss","isEnabled":true,"showThumbnails":false}
        """.data(using: .utf8)!
        let feed = try JSONDecoder().decode(CustomRSSFeed.self, from: json)
        #expect(feed.showThumbnails == false)
    }

    @Test("Init defaults showThumbnails to true")
    func initDefaultsShowThumbnails() {
        let feed = CustomRSSFeed(name: "N", url: "https://example.com/rss")
        #expect(feed.showThumbnails == true)
    }

    @Test("MMArticle thumbnailURL defaults to nil")
    func mmArticleThumbnailDefaultsNil() {
        let article = MMArticle(
            id: "1", title: "T", url: "https://example.com/1", published: "",
            author: "", category: "", content: "", scrapedContent: ""
        )
        #expect(article.thumbnailURL == nil)
    }
}
```

- [ ] **Step 2: Register test file in pbxproj and run test (expect compile fail)**

Add `GenericRSSClientTests.swift` to `project.pbxproj` following the `CardOrderTests.swift` pattern (4 insertions):

1. **PBXBuildFile** (near line 16): `XXXXXXXXXXXXXXXXXXXXXXXX /* GenericRSSClientTests.swift in Sources */ = {isa = PBXBuildFile; fileRef = YYYYYYYYYYYYYYYYYYYYYYYY /* GenericRSSClientTests.swift */; };`
2. **PBXFileReference**: `YYYYYYYYYYYYYYYYYYYYYYYY /* GenericRSSClientTests.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GenericRSSClientTests.swift; sourceTree = "<group>"; };`
3. **GlanceTests group** `0D77CB325514E74F6F1C281B` children (near `CardOrderTests.swift` line ~309)
4. **Test Sources phase** `15A885ECB27CC8627B5F3B25` files (near `CardOrderTests.swift in Sources` line ~794)

Use unique 24-hex IDs not already in the file (e.g. `A1B2C3D400010001R0000001` style following existing custom IDs). For app-target files use Utilities group `D1E2F3A4B5C6D7E8F9A0B1D2` and app Sources phase `EBCDFE4FC64A11F71EA4B02E` (HTMLStripper pattern).

Run:

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/GenericRSSFeedCodableTests 2>&1 | tail -40
```

Expected: FAIL — `showThumbnails` not found on `CustomRSSFeed`; `thumbnailURL` not found on `MMArticle`.

- [ ] **Step 3: Add MMArticle.thumbnailURL**

In `ManagingMadridClient.swift`, replace the struct:

```swift
struct MMArticle: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let url: String
    let published: String
    let author: String
    let category: String
    let content: String
    var scrapedContent: String
    var thumbnailURL: String? = nil
}
```

- [ ] **Step 4: Add CustomRSSFeed.showThumbnails with resilient Codable**

In `SettingsStore.swift`, replace `CustomRSSFeed`:

```swift
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
```

- [ ] **Step 5: Run full unit test bundle + build**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests 2>&1 | tail -30
```

Expected: PASS (all existing suites still pass — defaulted `thumbnailURL` keeps Madrid/cache call sites compiling).

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Network/ManagingMadridClient.swift Glance/Settings/SettingsStore.swift Glance/GlanceTests/GenericRSSClientTests.swift Glance/Glance.xcodeproj/project.pbxproj
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add thumbnailURL to MMArticle and showThumbnails to CustomRSSFeed"
```

---

### Task 2: GenericRSSClient thumbnail parsing

**Files:**
- Modify: `Glance/Core/Network/GenericRSSClient.swift`
- Test: `Glance/GlanceTests/GenericRSSClientTests.swift`

**Interfaces:**
- Consumes: `MMArticle.thumbnailURL` from Task 1
- Produces:
  - `GenericRSSClient.parseFeedInfo(from: Data) -> (title: String, articles: [MMArticle])` — internal, no network, for tests
  - `GenericRSSClient.parseArticles(from: Data) -> [MMArticle]` — internal, no network, for tests
  - Each `MMArticle.thumbnailURL` set from `media:thumbnail` @url, else `media:content` @url (image), else first non-`data:` `<img src>` in content

- [ ] **Step 1: Write failing parse tests**

Append to `GenericRSSClientTests.swift`:

```swift
@Suite("GenericRSS parse")
struct GenericRSSParseTests {
    private let client = GenericRSSClient()

    private func atomFixture(thumbnailAttribute: String?, contentHTML: String) -> Data {
        let thumb = thumbnailAttribute.map { "    <media:thumbnail \($0)/>\n" } ?? ""
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:media="http://search.yahoo.com/mrss/">
          <title>r/Technology</title>
          <entry>
            <author><name>/u/reuters</name></author>
            <category term="technology"/>
            <content type="html">\(contentHTML)</content>
            <published>2026-09-24T01:03:08+00:00</published>
            <link rel="alternate" href="https://www.reddit.com/r/technology/comments/abc123/example/"/>
            <title>Example post title</title>
        \(thumb)  </entry>
        </feed>
        """
        return xml.data(using: .utf8)!
    }

    @Test("Captures media:thumbnail url into thumbnailURL")
    func capturesMediaThumbnail() {
        let data = atomFixture(
            thumbnailAttribute: #"url="https://external-preview.redd.it/thumb.jpg""#,
            contentHTML: "submitted by /u/x"
        )
        // fixture emits: <media:thumbnail url="https://external-preview.redd.it/thumb.jpg"/>
        let (title, articles) = client.parseFeedInfo(from: data)
        #expect(title.contains("Technology") || title == "r/Technology")
        #expect(articles.count == 1)
        #expect(articles.first?.thumbnailURL == "https://external-preview.redd.it/thumb.jpg")
        #expect(articles.first?.title == "Example post title")
        #expect(articles.first?.author == "/u/reuters")
        #expect(articles.first?.url == "https://www.reddit.com/r/technology/comments/abc123/example/")
        #expect(articles.first?.published == "2026-09-24T01:03:08+00:00")
    }

    @Test("Entry without thumbnail leaves thumbnailURL nil")
    func noThumbnailNil() {
        let data = atomFixture(thumbnailAttribute: nil, contentHTML: "plain body")
        let articles = client.parseArticles(from: data)
        #expect(articles.first?.thumbnailURL == nil)
    }

    @Test("Falls back to first img src in content")
    func fallsBackToContentImg() {
        let data = atomFixture(
            thumbnailAttribute: nil,
            contentHTML: #"<p>hi</p><img src="https://example.com/pic.png" alt="x">"#
        )
        let articles = client.parseArticles(from: data)
        #expect(articles.first?.thumbnailURL == "https://example.com/pic.png")
    }

    @Test("Skips data URI img")
    func skipsDataUriImg() {
        let data = atomFixture(
            thumbnailAttribute: nil,
            contentHTML: #"<img src="data:image/png;base64,AAAA"><img src="https://example.com/real.jpg">"#
        )
        let articles = client.parseArticles(from: data)
        #expect(articles.first?.thumbnailURL == "https://example.com/real.jpg")
    }

    @Test("Parses classic RSS item with enclosure-style media content")
    func parsesRSSItemMediaContent() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
          <channel>
            <title>Feed</title>
            <item>
              <title>RSS title</title>
              <link>https://example.com/post</link>
              <pubDate>Wed, 24 Sep 2026 00:00:00 GMT</pubDate>
              <description>body</description>
              <media:content url="https://example.com/m.jpg" type="image/jpeg"/>
            </item>
          </channel>
        </rss>
        """
        let articles = client.parseArticles(from: xml.data(using: .utf8)!)
        #expect(articles.first?.thumbnailURL == "https://example.com/m.jpg")
        #expect(articles.first?.title == "RSS title")
    }
}
```

- [ ] **Step 2: Run tests to verify fail**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/GenericRSSParseTests 2>&1 | tail -40
```

Expected: FAIL — no `parseFeedInfo(from: Data)` / `parseArticles(from: Data)`; or `thumbnailURL` always nil.

- [ ] **Step 3: Expose data-parse APIs and implement thumbnail capture**

In `GenericRSSClient`, add:

```swift
func parseArticles(from data: Data) -> [MMArticle] {
    GenericRSSParser().parse(data: data)
}

func parseFeedInfo(from data: Data) -> (title: String, articles: [MMArticle]) {
    let (title, articles) = GenericRSSParser().parseWithFeedTitle(data: data)
    return (title, articles)
}
```

In `GenericRSSItem`, add `var thumbnailURL: String?`.

In `GenericRSSParser.didStartElement`, after existing link/title handling:

```swift
let local = (qName as NSString?)?.localName ?? elementName
if current != nil,
   (elementName == "media:thumbnail" || local == "thumbnail"),
   let url = attributeDict["url"],
   !url.isEmpty {
    current?.thumbnailURL = url
}
if current?.thumbnailURL == nil,
   (elementName == "media:content" || (local == "content" && namespaceURI?.contains("mrss") == true)),
   let url = attributeDict["url"],
   !url.isEmpty {
    current?.thumbnailURL = url
}
```

Do not treat Atom/RSS `<content>` / `<description>` body elements as media:content — only qualified `media:content` or MRSS-namespace `content`.

In `didEndElement` for `description`/`summary`/`content`/`content:encoded`, after assigning `item.content`, if `item.thumbnailURL == nil`, extract first img:

```swift
if item.thumbnailURL == nil {
    item.thumbnailURL = Self.firstImageURL(in: item.content)
}
```

Add helper on `GenericRSSParser`:

```swift
static func firstImageURL(in html: String) -> String? {
    let pattern = #"<img[^>]+src="([^"]+)""#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
    let range = NSRange(html.startIndex..., in: html)
    for match in regex.matches(in: html, options: [], range: range) {
        guard let srcRange = Range(match.range(at: 1), in: html) else { continue }
        let src = String(html[srcRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        if src.isEmpty || src.lowercased().hasPrefix("data:") { continue }
        if let decoded = src.removingPercentEncoding ?? Optional(src) {
            return decoded.replacingOccurrences(of: "&amp;", with: "&")
        }
        return src.replacingOccurrences(of: "&amp;", with: "&")
    }
    return nil
}
```

In the `entry`/`item` end-element where `MMArticle` is constructed, pass:

```swift
thumbnailURL: item.thumbnailURL
```

- [ ] **Step 4: Run parse tests**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/GenericRSSParseTests 2>&1 | tail -30
```

Expected: PASS

- [ ] **Step 5: Run full test bundle**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests 2>&1 | tail -20
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Network/GenericRSSClient.swift Glance/GlanceTests/GenericRSSClientTests.swift
git commit -m "feat: parse media thumbnails into MMArticle.thumbnailURL"
```

---

### Task 3: Reddit feed URL builder

**Files:**
- Modify: `Glance/Settings/AddRSSFeedSheet.swift` (add static builder + tests in GenericRSSClientTests)
- Test: `Glance/GlanceTests/GenericRSSClientTests.swift`

**Interfaces:**
- Consumes: nothing new
- Produces: `AddRSSFeedSheet.redditFeedURL(subreddit:sort:) -> String` (static, pure)

- [ ] **Step 1: Write failing URL builder tests**

Append to `GenericRSSClientTests.swift`:

```swift
@Suite("Reddit feed URL")
struct RedditFeedURLTests {
    @Test("Normalizes r/technology + hot")
    func normalizesRPrefix() {
        let url = AddRSSFeedSheet.redditFeedURL(subreddit: "r/technology", sort: "hot")
        #expect(url == "https://www.reddit.com/r/technology/hot.rss")
    }

    @Test("Bare subreddit name")
    func bareSubreddit() {
        let url = AddRSSFeedSheet.redditFeedURL(subreddit: "technology", sort: "hot")
        #expect(url == "https://www.reddit.com/r/technology/hot.rss")
    }

    @Test("Trims whitespace and leading slash variants")
    func trimsInput() {
        let url = AddRSSFeedSheet.redditFeedURL(subreddit: "  /r/selfhosted/  ", sort: "new")
        #expect(url == "https://www.reddit.com/r/selfhosted/new.rss")
    }

    @Test("Sort top includes day window")
    func topSortIncludesDay() {
        let url = AddRSSFeedSheet.redditFeedURL(subreddit: "technology", sort: "top")
        #expect(url == "https://www.reddit.com/r/technology/top.rss?t=day")
    }
}
```

- [ ] **Step 2: Run tests (expect fail)**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/RedditFeedURLTests 2>&1 | tail -20
```

Expected: FAIL — `redditFeedURL` not found.

- [ ] **Step 3: Implement static builder on AddRSSFeedSheet**

Add to `AddRSSFeedSheet` (near top of struct):

```swift
static let redditSorts = ["hot", "new", "top", "rising"]

static func redditFeedURL(subreddit: String, sort: String) -> String {
    var name = subreddit.trimmingCharacters(in: .whitespacesAndNewlines)
    while name.hasPrefix("/") || name.hasPrefix("r/") {
        if name.hasPrefix("/") {
            name.removeFirst()
        }
        if name.hasPrefix("r/") {
            name.removeFirst(2)
        }
    }
    name = name.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let safeSort = redditSorts.contains(sort) ? sort : "hot"
    var url = "https://www.reddit.com/r/\(name)/\(safeSort).rss"
    if safeSort == "top" {
        url += "?t=day"
    }
    return url
}
```

- [ ] **Step 4: Run URL tests**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/RedditFeedURLTests 2>&1 | tail -20
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Glance/Settings/AddRSSFeedSheet.swift Glance/GlanceTests/GenericRSSClientTests.swift
git commit -m "feat: add Reddit feed URL builder"
```

---

### Task 4: RedditLinkResolver

**Files:**
- Create: `Glance/Core/Utilities/RedditLinkResolver.swift`
- Test: `Glance/GlanceTests/RedditLinkResolverTests.swift`

**Interfaces:**
- Consumes: `MMArticle` (Task 1)
- Produces:

```swift
enum RedditLinkResolver {
    static func isRedditHost(_ host: String) -> Bool
    static func isRedditPermalink(_ urlString: String) -> Bool
    static func externalURL(fromContent content: String) -> URL?
    static func commentsURL(for article: MMArticle) -> URL?
    static func scrapeTarget(for article: MMArticle) -> URL?
}
```

Semantics:

- `isRedditHost`: true for `reddit.com`, `www.reddit.com`, `old.reddit.com`, `np.reddit.com`, `new.reddit.com`, `redd.it`, `redditmedia.com`, `redditimage.com` (case-insensitive; also matches suffix `.reddit.com` subdomains via `host == "reddit.com" || host.hasSuffix(".reddit.com") || host == "redd.it" || host == "www.redd.it"`).
- `isRedditPermalink`: valid URL and `isRedditHost(host)`.
- `externalURL`: scan `content` for `href="..."` or `href='...'`; replace `&amp;` → `&`; first absolute http(s) URL with non-Reddit host.
- `commentsURL`: `URL(string: article.url)` if `isRedditPermalink(article.url)`, else nil.
- `scrapeTarget(for:)`:
  1. If `externalURL(fromContent:)` non-nil → that URL.
  2. Else if article.url is **not** Reddit permalink → `URL(string: article.url)`.
  3. Else nil (self/text Reddit post: do not scrape).

- [ ] **Step 1: Write failing tests**

Create `Glance/GlanceTests/RedditLinkResolverTests.swift`:

```swift
import Testing
@testable import Glance
import Foundation

@Suite("RedditLinkResolver")
struct RedditLinkResolverTests {
    private func article(url: String, content: String) -> MMArticle {
        MMArticle(
            id: url, title: "T", url: url, published: "",
            author: "", category: "", content: content, scrapedContent: ""
        )
    }

    @Test("Recognizes reddit hosts")
    func redditHosts() {
        #expect(RedditLinkResolver.isRedditHost("www.reddit.com"))
        #expect(RedditLinkResolver.isRedditHost("old.reddit.com"))
        #expect(RedditLinkResolver.isRedditHost("reddit.com"))
        #expect(RedditLinkResolver.isRedditHost("redd.it"))
        #expect(!RedditLinkResolver.isRedditHost("example.com"))
        #expect(!RedditLinkResolver.isRedditHost("notreddit.com"))
    }

    @Test("isRedditPermalink true for comments URL")
    func permalinkTrue() {
        #expect(RedditLinkResolver.isRedditPermalink("https://www.reddit.com/r/technology/comments/abc/title/"))
        #expect(RedditLinkResolver.isRedditPermalink("https://old.reddit.com/r/x/comments/1/"))
        #expect(!RedditLinkResolver.isRedditPermalink("https://example.com/article"))
        #expect(!RedditLinkResolver.isRedditPermalink("not a url"))
    }

    @Test("Extracts first external href from link post content")
    func extractsExternalHref() {
        let content = """
        <div>submitted by <a href="/u/x">/u/x</a> <a href="https://www.reuters.com/article?utm=1&amp;x=2">[link]</a> <a href="https://www.reddit.com/r/technology/comments/abc/t/">[comments]</a></div>
        """
        let url = RedditLinkResolver.externalURL(fromContent: content)
        #expect(url?.host == "www.reuters.com")
        #expect(url?.query?.contains("utm=1") == true)
        #expect(url?.query?.contains("x=2") == true)
    }

    @Test("Self post with no external href returns nil")
    func selfPostNil() {
        let content = "<div class=\"md\"><p>Just a text post with a <a href=\"https://www.reddit.com/r/foo\">reddit link</a></p></div>"
        #expect(RedditLinkResolver.externalURL(fromContent: content) == nil)
    }

    @Test("Skips relative hrefs")
    func skipsRelative() {
        let content = #"<a href="/r/technology">sub</a><a href="https://blog.example.com/post">ext</a>"#
        let url = RedditLinkResolver.externalURL(fromContent: content)
        #expect(url?.host == "blog.example.com")
    }

    @Test("scrapeTarget nil for reddit self post")
    func scrapeTargetSelfPost() {
        let a = article(
            url: "https://www.reddit.com/r/technology/comments/abc/self/",
            content: "<p>hello world no external link</p>"
        )
        #expect(RedditLinkResolver.scrapeTarget(for: a) == nil)
    }

    @Test("scrapeTarget prefers external over reddit permalink")
    func scrapeTargetPrefersExternal() {
        let a = article(
            url: "https://www.reddit.com/r/technology/comments/abc/link/",
            content: #"<a href="https://www.nytimes.com/2026/09/story">[link]</a>"#
        )
        #expect(RedditLinkResolver.scrapeTarget(for: a)?.host == "www.nytimes.com")
    }

    @Test("scrapeTarget uses article url for non-reddit feeds")
    func scrapeTargetNonReddit() {
        let a = article(
            url: "https://example.com/blog/post",
            content: "<p>body</p>"
        )
        #expect(RedditLinkResolver.scrapeTarget(for: a)?.absoluteString == "https://example.com/blog/post")
    }

    @Test("commentsURL only for reddit permalinks")
    func commentsURL() {
        let reddit = article(url: "https://www.reddit.com/r/x/comments/1/t/", content: "")
        let blog = article(url: "https://example.com/a", content: "")
        #expect(RedditLinkResolver.commentsURL(for: reddit) != nil)
        #expect(RedditLinkResolver.commentsURL(for: blog) == nil)
    }
}
```



- [ ] **Step 2: Register in pbxproj; run tests (expect fail)**

Add `RedditLinkResolver.swift` to main target Utilities group `D1E2F3A4B5C6D7E8F9A0B1D2` (next to `HTMLStripper.swift` line ~520) + app Sources phase `EBCDFE4FC64A11F71EA4B02E` (near `HTMLStripper.swift in Sources` ~line 867); add `RedditLinkResolverTests.swift` to GlanceTests group `0D77CB325514E74F6F1C281B` + test Sources phase `15A885ECB27CC8627B5F3B25`.

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/RedditLinkResolverTests 2>&1 | tail -30
```

Expected: FAIL — type `RedditLinkResolver` not found.

- [ ] **Step 3: Implement RedditLinkResolver**

Create `Glance/Core/Utilities/RedditLinkResolver.swift`:

```swift
import Foundation

enum RedditLinkResolver {
    static func isRedditHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "reddit.com" || h.hasSuffix(".reddit.com") { return true }
        if h == "redd.it" || h.hasSuffix(".redd.it") { return true }
        if h == "redditmedia.com" || h.hasSuffix(".redditmedia.com") { return true }
        if h == "redditimage.com" || h.hasSuffix(".redditimage.com") { return true }
        return false
    }

    static func isRedditPermalink(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host else { return false }
        return isRedditHost(host)
    }

    static func externalURL(fromContent content: String) -> URL? {
        let pattern = #"href\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(content.startIndex..., in: content)
        for match in regex.matches(in: content, options: [], range: range) {
            guard let rawRange = Range(match.range(at: 1), in: content) else { continue }
            var href = String(content[rawRange])
                .replacingOccurrences(of: "&amp;", with: "&")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if href.hasPrefix("/") || href.hasPrefix("#") { continue }
            guard href.hasPrefix("http://") || href.hasPrefix("https://"),
                  let url = URL(string: href),
                  let host = url.host,
                  !isRedditHost(host) else { continue }
            return url
        }
        return nil
    }

    static func commentsURL(for article: MMArticle) -> URL? {
        guard isRedditPermalink(article.url), let url = URL(string: article.url) else { return nil }
        return url
    }

    static func scrapeTarget(for article: MMArticle) -> URL? {
        if let external = externalURL(fromContent: article.content) {
            return external
        }
        if isRedditPermalink(article.url) {
            return nil
        }
        return URL(string: article.url)
    }
}
```

- [ ] **Step 4: Run resolver tests**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests/RedditLinkResolverTests 2>&1 | tail -30
```

Expected: PASS

- [ ] **Step 5: Full test bundle + build**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests 2>&1 | tail -20
cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -15
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Utilities/RedditLinkResolver.swift Glance/GlanceTests/RedditLinkResolverTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add RedditLinkResolver for external scrape targets"
```

---

### Task 5: CustomRSSArticleView Option B + hero thumbnail

**Files:**
- Modify: `Glance/Features/CustomRSS/CustomRSSArticleView.swift`

**Interfaces:**
- Consumes: `RedditLinkResolver.scrapeTarget(for:)`, `RedditLinkResolver.commentsURL(for:)`, `MMArticle.thumbnailURL`, `ArticleScraper.scrape(urlString:)`
- Produces: article open behavior — scrape only non-nil target; primary CTA + optional Open comments; hero image when thumbnail present

- [ ] **Step 1: Replace scrape decision and CTA in CustomRSSArticleView**

Full target structure for the changed parts (keep intelligence/raw cards as-is):

```swift
import SwiftUI

struct CustomRSSArticleView: View {
    let article: MMArticle
    let feedName: String

    @State private var scrapedContent = ""
    @State private var isScraping = false
    @State private var scrapeError: String?

    private var scrapeTarget: URL? {
        RedditLinkResolver.scrapeTarget(for: article)
    }

    private var commentsURL: URL? {
        RedditLinkResolver.commentsURL(for: article)
    }

    private var primaryArticleURL: URL? {
        if scrapeTarget != nil { return scrapeTarget }
        if let comments = commentsURL { return comments }
        return URL(string: article.url)
    }

    private var displayContent: String {
        if !scrapedContent.isEmpty {
            return scrapedContent
        }
        return HTMLStripper.stripMedia(from: article.content)
    }

    private var sourceDomain: String? {
        primaryArticleURL?.host
    }

    private var isRedditOnly: Bool {
        RedditLinkResolver.isRedditPermalink(article.url) && scrapeTarget == nil
    }

    private var thumbnailURL: URL? {
        guard let s = article.thumbnailURL, let u = URL(string: s) else { return nil }
        return u
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let thumbnailURL {
                    heroImage(thumbnailURL)
                }

                Text(article.title)
                    .font(Theme.Fonts.manrope(26, weight: .heavy))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.author.isEmpty || !article.published.isEmpty {
                    HStack(spacing: 0) {
                        if !article.author.isEmpty { Text(article.author) }
                        if !article.author.isEmpty && !article.published.isEmpty { Text(" · ") }
                        if !article.published.isEmpty { Text(article.published) }
                    }
                    .font(Theme.Fonts.manrope(13, weight: .regular))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .accessibilityElement(children: .combine)
                    .padding(Theme.cardPadding)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }

                if isScraping {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading article\u{2026}")
                            .font(Theme.Fonts.manrope(14))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                } else if !scrapedContent.isEmpty {
                    ArticleIntelligenceCard(
                        content: scrapedContent,
                        type: .generic,
                        accentColor: Theme.Colors.accent
                    )

                    RawArticleCard(headerTitle: "FULL ARTICLE") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(displayContent.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                                let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    Text(trimmed)
                                        .font(Theme.Fonts.manrope(17, weight: .regular))
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                        .lineSpacing(5)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .textSelection(.enabled)
                    }
                } else if !article.content.isEmpty {
                    ArticleIntelligenceCard(
                        content: HTMLStripper.stripMedia(from: article.content),
                        type: .generic,
                        accentColor: Theme.Colors.accent
                    )

                    RawArticleCard(headerTitle: isRedditOnly ? "REDDIT POST" : "FULL ARTICLE") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                Text(paragraph)
                                    .font(Theme.Fonts.manrope(17, weight: .regular))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .textSelection(.enabled)
                    }
                }

                if let scrapeError {
                    Text(scrapeError)
                        .font(Theme.Fonts.manrope(13))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.top, 8)
                }

                if let primaryArticleURL {
                    Link(destination: primaryArticleURL) {
                        HStack {
                            Text(primaryCTALabel)
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                    }
                    .padding(.top, 24)
                }

                if let commentsURL, primaryArticleURL?.absoluteString != commentsURL.absoluteString {
                    Link(destination: commentsURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Open comments")
                        }
                        .font(Theme.Fonts.manrope(13, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                    }
                    .accessibilityLabel("Open Reddit comments")
                }
            }
            .padding(.horizontal, Theme.cardPadding)
            .padding(.bottom, 100)
        }
        .glanceBackground()
        .scrollIndicators(.hidden)
        .navigationTitle(feedName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArticleBody()
        }
    }

    private var primaryCTALabel: String {
        if isRedditOnly {
            return "Open on Reddit"
        }
        if let domain = sourceDomain, scrapeTarget != nil {
            return "Read on \(domain)"
        }
        if RedditLinkResolver.isRedditPermalink(article.url) {
            return "Open on Reddit"
        }
        return "Read on \(sourceDomain ?? feedName)"
    }

    private func heroImage(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Theme.Colors.canvasDeep)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .accessibilityHidden(true)
    }

    private func loadArticleBody() async {
        guard scrapedContent.isEmpty else { return }
        guard let target = scrapeTarget else {
            scrapeError = nil
            isScraping = false
            return
        }
        isScraping = true
        scrapeError = nil
        do {
            scrapedContent = try await ArticleScraper().scrape(urlString: target.absoluteString)
            if scrapedContent.isEmpty {
                scrapeError = "Could not load full article"
            }
        } catch {
            scrapeError = "Could not load full article"
        }
        isScraping = false
    }

    private var paragraphs: [String] {
        HTMLStripper.stripMedia(from: article.content)
            .components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
```

Secondary comments link (already in the body above): show **Open comments** only when `commentsURL != nil` and `primaryArticleURL` differs from it (external article is primary; self posts use primary = comments).

- [ ] **Step 2: Verify CachedAsyncImage initializer signature**

`CachedAsyncImage(url:) { image in ... } placeholder: { ... }` is the real API (see `CachedShimmerImage` in `Glance/DesignSystem/CachedAsyncImage.swift:103-107`). Match that call shape in `heroImage`.

- [ ] **Step 3: Build app target**

```bash
cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Manual smoke (simulator)**

- Launch app → Settings → add a temporary Custom RSS feed pointing at `https://www.reddit.com/r/technology/hot.rss` (or finish Task 6 first if preferred sequential).
- Open a link post: expect external scrape or graceful "Could not load full article" without scraping reddit.com chrome.
- Open a self/text post: expect REDDIT POST body from RSS, no long scrape spinner failure for reddit.com.
- Open comments path present when primary is external.

- [ ] **Step 5: Commit**

```bash
git add Glance/Features/CustomRSS/CustomRSSArticleView.swift
git commit -m "feat: scrape external articles for Reddit posts with comments link"
```

---

### Task 6: AddRSSFeedSheet Reddit mode + thumbnail toggle

**Files:**
- Modify: `Glance/Settings/AddRSSFeedSheet.swift`

**Interfaces:**
- Consumes: `AddRSSFeedSheet.redditFeedURL` (Task 3), `validateFeed()` existing, `CustomRSSFeed(name:url:isEnabled:showThumbnails:)` (Task 1)
- Produces: UI modes `rss` / `reddit`; `addFeed()` persists `showThumbnails`

- [ ] **Step 1: Add mode state and Reddit fields**

Extend state:

```swift
private enum FeedSourceMode: String, CaseIterable, Identifiable {
    case rss = "RSS URL"
    case reddit = "Reddit"
    var id: String { rawValue }
}

@State private var sourceMode: FeedSourceMode = .rss
@State private var subredditText = ""
@State private var redditSort = "hot"
@State private var showThumbnails = true
```

- [ ] **Step 2: Add segmented picker + Reddit form above URL section**

Replace/augment body content:

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("SOURCE")
        .font(Theme.Fonts.manrope(10, weight: .bold))
        .foregroundStyle(Theme.Colors.textMuted)
        .tracking(1.2)

    Picker("Source", selection: $sourceMode) {
        ForEach(FeedSourceMode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
        }
    }
    .pickerStyle(.segmented)
}
```

When `sourceMode == .reddit`, show subreddit + sort + thumbnail toggle; hide raw URL field. When `.rss`, show existing `urlSection` only.

Reddit fields:

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("SUBREDDIT")
        .font(Theme.Fonts.manrope(10, weight: .bold))
        .foregroundStyle(Theme.Colors.textMuted)
        .tracking(1.2)

    HStack(spacing: 8) {
        Text("r/")
            .font(Theme.Fonts.manrope(13))
            .foregroundStyle(Theme.Colors.textMuted)
        TextField("technology", text: $subredditText)
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

        Button {
            Task { await validateFeed() }
        } label: {
            Text("Fetch")
                .font(Theme.Fonts.manrope(13, weight: .medium))
                .foregroundStyle(subredditText.isEmpty ? Theme.Colors.textMuted : Theme.Colors.accent)
        }
        .disabled(subredditText.isEmpty || validationState == .loading)
    }

    Picker("Sort", selection: $redditSort) {
        ForEach(Self.redditSorts, id: \.self) { sort in
            Text(sort).tag(sort)
        }
    }
    .pickerStyle(.segmented)
}
```

Also when mode changes, reset `validationState = .idle` via `.onChange(of: sourceMode)`.

Thumbnail toggle (show in both modes after successful validation, with name section):

```swift
private var thumbnailToggleSection: some View {
    HStack {
        VStack(alignment: .leading, spacing: 2) {
            Text("Show thumbnails")
                .font(Theme.Fonts.manrope(14, weight: .medium))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Display post images on the card")
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        Spacer()
        Toggle("", isOn: $showThumbnails)
            .labelsHidden()
    }
    .padding(12)
    .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
}
```

Include `thumbnailToggleSection` inside the `if case .success` block alongside name/toggle sections.

- [ ] **Step 3: Wire validateFeed to Reddit URL**

```swift
private var effectiveFeedURL: String {
    switch sourceMode {
    case .rss:
        return urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    case .reddit:
        return Self.redditFeedURL(subreddit: subredditText, sort: redditSort)
    }
}

private func validateFeed() async {
    let trimmed = effectiveFeedURL
    guard !trimmed.isEmpty else { return }
    validationState = .loading
    let client = GenericRSSClient()
    do {
        let info = try await client.fetchFeedInfo(from: trimmed)
        guard !info.articles.isEmpty else {
            validationState = .error("No articles found in this feed.")
            return
        }
        validationState = .success(title: info.title, articles: info.articles)
        if feedName.isEmpty {
            feedName = defaultFeedName(from: info.title)
        }
    } catch {
        validationState = .error("Could not fetch feed. Check the URL and try again.")
    }
}

private func defaultFeedName(from title: String) -> String {
    switch sourceMode {
    case .reddit:
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("/r/") { t = String(t.dropFirst(3)) }
        if t.lowercased().hasPrefix("r/") { t = String(t.dropFirst(2)) }
        return t.isEmpty ? "r/\(subredditText)" : "r/\(t)"
    case .rss:
        return title
    }
}
```

- [ ] **Step 4: Wire addFeed to effective URL + showThumbnails**

```swift
private func addFeed() {
    guard case .success = validationState else { return }
    let nameToUse = feedName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !nameToUse.isEmpty else { return }
    let feed = CustomRSSFeed(
        name: nameToUse,
        url: effectiveFeedURL,
        isEnabled: isEnabled,
        showThumbnails: showThumbnails
    )
    var updated = feeds
    updated.append(feed)
    feeds = updated
    settingsStore.appendFeedToCardOrder(feed)
    dismiss()
}
```

`canAdd` already requires non-empty `feedName`; `validateFeed` prefills it.

- [ ] **Step 5: Build**

```bash
cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Manual smoke**

- Settings → Providers → Add RSS Feed → Reddit → `r/technology` → Fetch → success titles/articles → name `r/technology` → Show thumbnails on → Add.
- Card appears on Pulse; order key `custom:<uuid>`.
- Repeat for `selfhosted`.

- [ ] **Step 7: Commit**

```bash
git add Glance/Settings/AddRSSFeedSheet.swift
git commit -m "feat: add Reddit mode to add feed sheet with thumbnail toggle"
```

---

### Task 7: Card + detail thumbnails, Reddit accent, refresh spacing

**Files:**
- Modify: `Glance/Features/CustomRSS/CustomRSSCardView.swift`
- Modify: `Glance/Features/CustomRSS/CustomRSSDetailView.swift`
- Modify: `Glance/Features/Pulse/PulseStore.swift:156-165`

**Interfaces:**
- Consumes: `MMArticle.thumbnailURL`, `CustomRSSFeed.showThumbnails` / `url` via `settingsStore`
- Produces: visual thumbnails gated by feed flag; Reddit SF symbol accent; spaced multi-Reddit refresh

- [ ] **Step 1: CardView — feed lookup + helpers**

Replace feed URL helper with full feed:

```swift
private var feed: CustomRSSFeed? {
    settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == feedID })
}

private var feedURL: String? { feed?.url }

private var showThumbnails: Bool { feed?.showThumbnails ?? true }

private var isRedditFeed: Bool {
    guard let host = feedURL.flatMap({ URL(string: $0)?.host }) else { return false }
    return RedditLinkResolver.isRedditHost(host)
}

private var headerSymbol: String {
    isRedditFeed ? "bubble.left.and.bubble.right" : "dot.rss"
}
```

Change header `Image(systemName: "dot.rss")` to `Image(systemName: headerSymbol)`.

- [ ] **Step 2: CardView — thumbnail row**

In `articleList` rows, leading thumbnail when enabled:

```swift
HStack(spacing: 10) {
    if showThumbnails, let thumb = article.thumbnailURL, let url = URL(string: thumb) {
        articleThumb(url, size: CGSize(width: 48, height: 48))
    }
    VStack(alignment: .leading, spacing: 2) {
        // existing title + author VStack
    }
    Spacer()
    Image(systemName: "arrow.up.right")
        .font(.caption)
        .foregroundStyle(Theme.Colors.textMuted)
}
```

Add shared view helper in same file (or small private view):

```swift
private func articleThumb(_ url: URL, size: CGSize) -> some View {
    CachedAsyncImage(url: url) { image in
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    } placeholder: {
        Rectangle().fill(Theme.Colors.canvasDeep)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
    .accessibilityHidden(true)
}
```

(If `CachedAsyncImage` API differs — Task 5 step 2 — match that.)

- [ ] **Step 3: DetailView — thumbnails**

Same pattern in `CustomRSSDetailView` row: leading thumb 56×40 when `showThumbnails` and thumbnail present. DetailView currently only has `feedName` + `articles` — **does not have feedID**.

Check navigation: `PulseView` pushes `CustomRSSFeedRef(feedID:feedName:)` → detail gets only name/articles.

Options:
1. Pass `showThumbnails` through `CustomRSSDetailView` from PulseView using settings lookup.
2. Read settings inside detail: `@State private var settingsStore = SettingsStore()` then find feed by name (fragile).
3. Add `showThumbnails: Bool` to `CustomRSSDetailView` init.

**Do (3):** change `CustomRSSDetailView` to:

```swift
struct CustomRSSDetailView: View {
    let feedName: String
    let articles: [MMArticle]
    var showThumbnails: Bool = true
    ...
}
```

In `PulseView` navigationDestination for `CustomRSSFeedRef`:

```swift
let showThumbs = settingsStore.customRSSFeeds.first(where: { $0.id.uuidString == ref.feedID })?.showThumbnails ?? true
CustomRSSDetailView(feedName: ref.feedName, articles: articles, showThumbnails: showThumbs)
```

Row uses same `articleThumb` logic (duplicate small helper or extract `ArticleThumbnailView` into `CustomRSSFeedRef.swift` / new tiny file — **prefer private helper duplicated lightly** to avoid extra pbxproj file; or put `ArticleThumbnailView` in `CustomRSSCardView.swift` as package-visible struct in same file and use from Detail only if same module — Detail can use `ArticleThumbnailView` if defined internal in CardView file).

Define in `CustomRSSCardView.swift`:

```swift
struct ArticleThumbnailView: View {
    let urlString: String?
    let size: CGSize
    var body: some View {
        if let s = urlString, let url = URL(string: s) {
            CachedAsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Theme.Colors.canvasDeep)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
            .accessibilityHidden(true)
        }
    }
}
```

Use `ArticleThumbnailView(urlString: article.thumbnailURL, size: CGSize(width: 48, height: 48))` when `showThumbnails`.

- [ ] **Step 4: PulseView detail destination update**

Modify `Glance/Features/Pulse/PulseView.swift` CustomRSSFeedRef destination as in step 3.

- [ ] **Step 5: PulseStore Reddit refresh spacing**

```swift
private func isRedditFeedURL(_ urlString: String) -> Bool {
    guard let host = URL(string: urlString)?.host else { return false }
    return RedditLinkResolver.isRedditHost(host)
}

func refreshCustomRSS() async {
    let feeds = settingsStore.customRSSFeeds.filter(\.isEnabled)
    for (index, feed) in feeds.enumerated() {
        if index > 0, isRedditFeedURL(feeds[index - 1].url), isRedditFeedURL(feed.url) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        await refreshCustomRSS(feedID: feed.id.uuidString)
    }
    let activeIDs = Set(feeds.map(\.id.uuidString))
    for key in customRSSCards.keys where !activeIDs.contains(key) {
        customRSSCards.removeValue(forKey: key)
    }
}
```

- [ ] **Step 6: Build + full tests**

```bash
cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -15
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests 2>&1 | tail -20
```

Expected: PASS

- [ ] **Step 7: Manual smoke**

- Two Reddit feeds refresh without immediate 429 (1s gap).
- Thumbnails visible on card + detail when toggle on; hidden when feed.showThumbnails false (edit in Providers or construct feed).
- Reddit card header uses bubble symbol.

- [ ] **Step 8: Commit**

```bash
git add Glance/Features/CustomRSS/CustomRSSCardView.swift Glance/Features/CustomRSS/CustomRSSDetailView.swift Glance/Features/Pulse/PulseView.swift Glance/Features/Pulse/PulseStore.swift
git commit -m "feat: show Reddit post thumbnails and space Reddit refreshes"
```

---

### Task 8: Full verification and pbxproj audit

**Files:**
- Audit: all files from File Map

**Interfaces:**
- Consumes: Tasks 1–7
- Produces: green build, green tests, registered new sources

- [ ] **Step 1: Confirm pbxproj registrations**

```bash
rg -n "RedditLinkResolver.swift|RedditLinkResolverTests.swift|GenericRSSClientTests.swift" Glance/Glance.xcodeproj/project.pbxproj
```

Expected: each name appears at least twice (file ref + build file) and once in a Sources phase (actually 3+ occurrences: PBXBuildFile, PBXFileReference, group, sources = 4 per app/test file).

- [ ] **Step 2: Full clean build**

```bash
cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' clean build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Full unit tests**

```bash
cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:GlanceTests 2>&1 | tail -30
```

Expected: All tests PASS including `RedditLinkResolverTests`, `GenericRSSParseTests`, `RedditFeedURLTests`, `CustomRSSFeedCodableTests`.

- [ ] **Step 4: Spec success-criteria checklist**

- [ ] Add subreddit via Reddit mode without pasting full URL
- [ ] Cards render titles/authors/dates; thumbnails when present and enabled
- [ ] Detail list matches Custom RSS UX
- [ ] Link post → external scrape or graceful fallback; self post → RSS body
- [ ] Open comments reaches reddit.com
- [ ] No new secrets/hosts beyond reddit + article domains
- [ ] Unit tests green; xcodebuild green

- [ ] **Step 5: Final commit if any audit fixes**

```bash
git add -A
git status
git commit -m "chore: register reddit provider files and verify build"
```

Only if there are uncommitted audit fixes; otherwise skip empty commit.

---

## Self-Review notes (plan author)

1. **Spec coverage:** Task 1 (model fields), 2 (thumbnail parse), 3+6 (Reddit sheet/URL), 4 (resolver), 5 (Option B + hero), 7 (row thumbs, accent, 1s spacing), 8 (verify). Spec optional top `?t=day` included in URL builder. Custom decode default true in Task 1. Non-goals untouched.
2. **Placeholders:** No TBD/TODO; all steps have code or exact commands. CachedAsyncImage API confirmed against `CachedShimmerImage` call site.
3. **Type consistency:** `redditFeedURL(subreddit:sort:)`, `RedditLinkResolver.scrapeTarget(for:)`, `thumbnailURL`, `showThumbnails`, `ArticleThumbnailView(urlString:size:)` used consistently across tasks.
4. **Review Focus:** each of 6 items has an owning task test or build step (legacy decode T1, no-reddit scrape T4, entities T4, media name forms T2, memberwise T1 build, 429 spacing T7 manual).
5. **Broken intermediate edit:** Task 2 media:content snippet consolidated into one correct block; fixture emits proper self-closing `<media:thumbnail .../>`.
6. **pbxproj:** Concrete group IDs and Sources phase IDs documented for both targets.
