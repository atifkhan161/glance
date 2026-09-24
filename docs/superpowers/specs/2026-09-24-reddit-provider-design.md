# Reddit Provider Design

**Date:** 2026-09-24
**Status:** Design approved in chat; awaiting written-spec review
**Scope:** Add a Reddit subreddit provider to Glance iOS, modeled on glanceapp/glance `type: reddit` widgets, reusing the existing Custom RSS stack with Reddit-aware article opening (Option B) and thumbnail support.

## Intent

Display subreddit post feeds (e.g. r/technology, r/selfhosted) on the Pulse home feed with the same card, hub/detail, and article navigation as Custom RSS. Zero backend, no Reddit API keys, no OAuth. Align with web Glance config intent:

```yaml
- type: reddit
  subreddit: technology
  show-thumbnails: true
- type: reddit
  subreddit: selfhosted
  show-thumbnails: true
```

## Research conclusions (verified 2026-09-24)

| Access path | Status |
|-------------|--------|
| `https://www.reddit.com/r/{sub}/hot.rss` (and `/new.rss`, `/top.rss?t=...`, `/rising.rss`) | Works, no auth: HTTP 200, Atom XML, ~25 entries |
| Anonymous `.json` listings | Blocked (403 / network-security). Web Glance needs JS challenge (`loid` cookie) plus uTLS fingerprinting: not practical on iOS `URLSession` |
| OAuth Reddit API | Out of scope (keys, Responsible Builder Policy) |
| Rate limits | Aggressive (often ~1 req/min bursts return 429). 24h cache TTL plus manual refresh is acceptable for a handful of subreddits |

Feed contents verified:

- Atom `entry` elements provide: `title`, `link` (Reddit comments permalink), `author/name` (`/u/...`), `published` / `updated`, `content` (HTML).
- Self/text posts include full body text in `content` (hundreds to thousands of characters).
- Link posts often include `media:thumbnail` and thin content shaped like `submitted by /u/... [link] [comments]`, where `[link]` is an anchor to the external article.
- No upvote scores, comment counts, or flairs in RSS.

Web Glance reference: `internal/glance/widget-reddit.go` (fetches `.json` with browser UA, loid challenge, optional OAuth; shows score, comments, thumbnail, flair; skips stickied/pinned).

## Design decision

**Reuse Custom RSS end to end.** Reddit feeds are `CustomRSSFeed` rows whose `url` is a subreddit RSS URL. No new pipeline, no new `CardID`, no new navigation destinations.

**Option B:** When opening a Reddit link post, scrape the external article URL extracted from RSS content instead of the Reddit comments permalink. Self/text posts render RSS content directly (no scrape of reddit.com).

**Thumbnails:** Parse `media:thumbnail` (or first content image) into `MMArticle.thumbnailURL` and show them when `showThumbnails` is enabled (default true; Reddit add-sheet toggle mirrors Glance `show-thumbnails`).

## Architecture

```
AddRSSFeedSheet (Reddit mode)
  -> CustomRSSFeed(url: https://www.reddit.com/r/{sub}/{sort}.rss, showThumbnails: true)
  -> GenericRSSPipeline + CacheStore (existing customRSSFreshTTL = 24h)
  -> PulseStore.customRSSCards -> CustomRSSCardView
  -> CustomRSSDetailView -> CustomRSSArticleView
       scrape target = RedditLinkResolver.externalURL(article) ?? article.url
```

Existing pieces reused unchanged:

- `SettingsStore.customRSSFeeds` + `appendFeedToCardOrder` / `removeFeedFromCardOrder`
- `CardID` / `custom:` card order keys
- `GenericRSSPipeline` refresh / loadCached / cache key
- `PulseStore` custom RSS card state machine (loading / ready / stale / offline / error)
- `CustomRSSCardView`, `CustomRSSDetailView`, `CustomRSSArticleView` navigation refs
- Settings cache clear rows for custom feeds

## Components

### 1. AddRSSFeedSheet: Reddit mode

- Segmented control: **RSS URL** | **Reddit**.
- Reddit mode fields:
  - Subreddit (accepts `technology` or `r/technology`; normalize by stripping `r/` prefix, trimming, lowercasing for URL path as Reddit is case-insensitive for path purposes; keep display name as entered or as feed title).
  - Sort picker: `hot` (default), `new`, `top`, `rising`. For `top`, optionally append `?t=day` (default day) if exposed; minimum bar is sort path segment only.
- Builds `https://www.reddit.com/r/{sub}/{sort}.rss`.
- Reuses existing `validateFeed()` via `GenericRSSClient.fetchFeedInfo`.
- Default feed name: validated feed title if present (often `/r/Technology` style); user can override.
- Thumbnail toggle: **Show thumbnails**, default on; stored on `CustomRSSFeed.showThumbnails`.
- RSS URL mode: unchanged behavior; `showThumbnails` defaults true.

### 2. MMArticle.thumbnailURL

```swift
var thumbnailURL: String? = nil
```

- Property default `nil` keeps existing memberwise call sites compiling (Swift includes defaulted parameters as optional arguments).
- Optional field: older `CacheEnvelope<[MMArticle]>` JSON without the key decodes as nil (`decodeIfPresent` behavior for optionals).

### 3. GenericRSSClient parsing

For each Atom `entry` / RSS `item`:

1. Prefer `media:thumbnail` attribute `url` (namespace `http://search.yahoo.com/mrss/`).
2. Else `media:content` attribute `url` when type is image.
3. Else first `<img src="...">` inside `content` / `description` / `content:encoded` (skip `data:` URIs).
4. Else nil.

Parser must capture element/attribute on `didStartElement` for namespaced names (XMLParser may report `media:thumbnail` as qualified name depending on namespace processing; handle both `media:thumbnail` and local name if needed).

Feed title extraction for Reddit remains as today (used for validation success label).

### 4. CustomRSSFeed.showThumbnails

```swift
struct CustomRSSFeed: Codable, Identifiable, Hashable {
  let id: UUID
  var name: String
  var url: String
  var isEnabled: Bool
  var showThumbnails: Bool  // default true in memberwise/init default
}
```

- Init default `showThumbnails: true` so existing decodes that lack the key need care: `Codable` synthesized decode fails if key missing and property non-optional without custom `init(from:)`.
- **Requirement:** custom `init(from: decoder)` or optional-backed property so legacy persisted feeds (UserDefaults JSON without the key) still decode. Prefer explicit `init(from:)` that uses `decodeIfPresent(Bool.self, forKey: .showThumbnails) ?? true`.
- `encode(to:)` can synthesize or include the key.

### 5. RedditLinkResolver (new)

```swift
enum RedditLinkResolver {
  static func isRedditPermalink(_ urlString: String) -> Bool
  static func externalURL(fromContent content: String, fallback: String) -> URL?
  static func commentsURL(for article: MMArticle) -> URL?
}
```

Behavior:

- `isRedditPermalink`: host is `reddit.com`, `www.reddit.com`, `old.reddit.com`, `np.reddit.com`, `redd.it`, `redditmedia.com` (path-based links to comments count as reddit).
- `externalURL`: scan `content` for `href="..."` (HTML-escaped amp; handled); first absolute http(s) URL whose host is **not** Reddit; return nil if none.
- Self posts: content is body text without external hrefs -> nil.
- `commentsURL`: valid URL string of `article.url` when it is a Reddit permalink; else nil.

Pure functions; unit-testable without network.

### 6. CustomRSSArticleView (Option B)

Scrape decision on `.task`:

```
if let external = RedditLinkResolver.externalURL(fromContent: article.content, fallback: article.url),
   !RedditLinkResolver.isRedditPermalink(external.absoluteString) {
  scrape external
} else if RedditLinkResolver.isRedditPermalink(article.url) {
  // self/text post or no external link: do not scrape reddit.com
  scrapedContent stays empty; show stripped article.content
} else {
  scrape article.url  // non-Reddit custom feeds unchanged
}
```

UI:

- Body: existing intelligence card + full article when scrape succeeds; when scrape skipped/failed and `article.content` non-empty, existing content path (already implemented).
- Primary CTA:
  - External article scraped or external URL present: `Read on {domain}` -> external URL.
  - Reddit-only (self post or scrape failed with no external): `Open on Reddit` or `Open comments` -> `article.url`.
- Secondary when both exist: `Open comments` link to Reddit permalink (small text link under body or in metadata row).
- Optional hero: if `article.thumbnailURL` loads, show image at top (max height ~200, clipped, rounded) before title or after metadata; skip for empty nil.

### 7. CustomRSSCardView and CustomRSSDetailView thumbnails

- When `feed.showThumbnails` is true and `article.thumbnailURL` is non-nil:
  - Leading `AsyncImage` frame approx 48x48 (card rows) / 56x40 (detail rows), `cornerRadius` small, placeholder `Theme.Colors.canvasDeep`.
  - `frame(minWidth:)` fixed so titles do not jump when image loads.
- Show at most first N rows with images (N=5 matches current card `prefix(5)`); do not special-case further.
- When `showThumbnails` false: omit image views entirely.
- When thumbnail nil: no spacer (use existing text-only layout) OR fixed zero-width; prefer conditional layout so self posts stay clean.

### 8. Reddit accent (optional polish, include)

- Detect Reddit feed: host of `feed.url` is reddit.com / redd.it.
- Card header: keep structure; optionally use SF symbol `bubble.left.and.bubble.right` and/or a distinct accent from existing Theme colors only (`Theme.Colors.cardAmber` etc.). Do not invent Theme keys.
- Footer `via` domain will already show `www.reddit.com`.

## Data flow

1. User adds Reddit feed in Settings -> validates Atom -> persists `CustomRSSFeed` + card order.
2. Pulse `loadFromCache` hydrates `customRSSCards` from `CacheStore.customRSSKey(feedID:)`.
3. Stale/missing cache triggers `refreshCustomRSS(feedID:)` -> `GenericRSSPipeline.refresh` -> network fetch Atom -> parse to `[MMArticle]` including thumbnails -> save envelope. When refreshing multiple enabled Reddit feeds in one pass, space requests lightly (e.g. 1s `Task.sleep`) to reduce 429 risk.
4. Card renders list; tap opens `CustomRSSFeedRef` detail; row tap opens `CustomRSSArticleRef`.
5. Article view resolves scrape target via `RedditLinkResolver`; scrapes external article when applicable.

## Error handling

| Case | Behavior |
|------|----------|
| HTTP 429 / network fail on refresh | Existing: empty -> `.error` or keep fallback `.offline` with last data |
| Validation fail in sheet | Existing error UI in `AddRSSFeedSheet` |
| External scrape non-2xx / decode fail | `scrapeError` message; fall back to RSS `content` body; comments link still available |
| Thumbnail load fail | `AsyncImage` placeholder; no error chrome |
| Reddit permalink scraped accidentally | Prevented by resolver: skip scrape when only Reddit URL |

## Non-goals

- Reddit OAuth or `.json` client
- Scores, comment counts, flairs, awards
- True multi-image galleries or video players
- Separate `RedditPipeline` or `CardID.reddit`
- Proxy / request-url-template equivalents from web Glance
- Changing global Custom RSS TTL (remains 24h)

## Testing

Unit tests (GlanceTests):

1. `RedditLinkResolverTests`
   - External href in link-post content selected; Reddit host rejected.
   - Self-post content without hrefs -> nil.
   - `isRedditPermalink` true for www/old/redd.it; false for example.com.
   - HTML entity `&amp;` in href decoded.
2. `GenericRSSClientTests` (fixture Atom string, no network)
   - `media:thumbnail` url captured into `thumbnailURL`.
   - Entry without thumb -> nil.
   - Fallback first img in content.
   - Existing fields: title, author, published, link still populated.
3. `CustomRSSFeed` decode
   - JSON without `showThumbnails` decodes as true.
   - JSON with false preserved.
4. Feed URL builder
   - `r/technology` + hot -> `https://www.reddit.com/r/technology/hot.rss`
   - `technology` normalized.

Manual / UI:

- Add r/technology and r/selfhosted; appear in card order; pull-to-refresh.
- Open self/text post: body from RSS without scrape error dominating UI.
- Open link post: external article body; Open comments opens reddit.com.
- Toggle showThumbnails off: rows text-only.
- Kill network: stale card + retry.

## Files touched

| File | Change |
|------|--------|
| `Glance/Core/Network/ManagingMadridClient.swift` | `MMArticle.thumbnailURL: String?` |
| `Glance/Core/Network/GenericRSSClient.swift` | Parse media thumbnail / content img |
| `Glance/Settings/SettingsStore.swift` | `CustomRSSFeed.showThumbnails` + resilient Codable |
| `Glance/Settings/AddRSSFeedSheet.swift` | Reddit mode UI, URL builder, thumbnail toggle |
| `Glance/Core/Utilities/RedditLinkResolver.swift` | **new** |
| `Glance/Features/CustomRSS/CustomRSSArticleView.swift` | Option B scrape target, comments link, hero thumb |
| `Glance/Features/CustomRSS/CustomRSSCardView.swift` | Row thumbnails; optional Reddit accent |
| `Glance/Features/CustomRSS/CustomRSSDetailView.swift` | Row thumbnails |
| `Glance/GlanceTests/RedditLinkResolverTests.swift` | **new** |
| `Glance/GlanceTests/GenericRSSClientTests.swift` | **new** fixtures |
| `Glance.xcodeproj/project.pbxproj` | Register new files; `git add -f` if gitignored |

## Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Reddit 429 | 24h TTL; serial refresh already; do not fetch multiple Reddit feeds in tight loop without small delay if easy (optional `Task.sleep` between Reddit refreshes) |
| External sites block scraper | Same as existing RSS article view failure; fallback content |
| Legacy feed JSON missing new key | Custom decode with default true |
| Thumbnail layout jank | Fixed image frame; placeholder color |
| Rate limit during validation + first refresh | Validate once in sheet; rely on cache afterward |

## Success criteria

- User can add subreddit `technology` and `selfhosted` via Reddit mode without pasting URLs.
- Both cards render on Pulse with titles, authors, dates; thumbnails when available and enabled.
- Detail list matches Custom RSS UX.
- Link posts open external article content when scrapeable; self posts show RSS body.
- Comments always reachable via Reddit permalink.
- No new secrets; no new network hosts required beyond reddit.com and article domains.
- Unit tests for resolver, thumbnail parsing, and feed decode pass; full `xcodebuild` succeeds.
