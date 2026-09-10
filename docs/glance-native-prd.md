# Glance — Native iOS PRD (Swift Port)

**Date:** 2026-09-10
**Author:** Atif Ahmed Khan
**Status:** Draft v1 — porting spec for a Swift-only iOS rebuild
**Source of truth for behavior:** this repo's `src/` (the Capacitor web app it ports).
Key behavior files: `src/state.js`, `src/cache.js`, `src/modules/*.js`,
`src/api/*.js`, `src/pages/*.js`, `src/components/*.js`, `ios/App/App/Plugins/*.swift`.
Design tokens: `src/styles/main.css` (`@theme` block). Sample API payloads:
`docs/api-responses/`. Product background: `docs/2026-09-08-glance-design.md`.

> **Purpose of this document:** describe *what Glance does* — screens, data
> flows, business rules, states, and contracts — precisely enough that a
> Swift-only iOS app (SwiftUI + FoundationModels + URLSession, no web view)
> can be built to parity. It deliberately omits web-only mechanics (hash
> router, service worker, Capacitor bridge, Tailwind classes) except where
> they imply behavior the native app must reproduce.

---

## 1. Product Overview

**Glance** is a zero-backend personal intelligence dashboard. It aggregates
four data streams into four accent-coded cards on one home screen ("Pulse"):

| # | Card | Accent | Data pipeline (raw → intelligence) |
|---|------|--------|------------------------------------|
| 1 | **Real Madrid** | Amber `#F59E0B` | Exa web search + Managing Madrid RSS → fixture parsed locally → form/standing/intel enriched by on-device AI or Gemini |
| 2 | **Pokémon GO** | Rose `#F43F5E` | ScrapedDuck JSON (raids + events) → priority pick by on-device AI or Gemini |
| 3 | **GitHub Trending** | Emerald `#10B981` | GitHub REST search (`topic:llm + topic:ai`) → star-velocity computed vs prior cache — **no AI involved** |
| 4 | **AI Intel** | Cyan `#06B6D4` | Exa web search → 2–3 structured briefs by on-device AI or Gemini |

Core principles the port must preserve:

1. **Cache-paint-then-revalidate.** Launch paints instantly from the local
   cache; each card refreshes in the background when its TTL has expired.
   The app is fully usable offline using last-known data.
2. **Per-card independence.** Each card fetches, fails, refreshes, and shows
   its age independently. One card's failure never blanks or blocks another.
3. **Graceful degradation ladder (AI features):** on-device AI → Gemini cloud
   → raw-data fallback. A card shows *something useful* at every rung; it is
   never empty because AI is unavailable.
4. **User-supplied API keys.** Exa and Gemini keys are entered by the user on
   the Sources screen and stored on-device only. They are never hardcoded,
   committed, or bundled.
5. **Attribution.** The PoGo surface must always display
   `"Data from ScrapedDuck / LeekDuck.com"`.

### 1.1 App identity

- User-facing name: **Glance** (everywhere: nav title, app icon name, About).
- Bundle ID (existing Capacitor shell): `com.atifkhan.glance`.
- Version: `0.1.0`. Theme / background color: `#0F131D`.
- App icons already exist: `docs/glance AppIcons /Assets.xcassets/AppIcon.appiconset/`
  (iOS) and `docs/glance AppIcons /android/` (Android) — reuse for the native target.

---

## 2. Information Architecture & Navigation

The web app has 13 routes; the native app maps them 1:1 onto a tab bar plus a
navigation stack. (Web uses hash routes like `#/raids/:name`; native should
use `UINavigationController` push or `NavigationStack` — route strings below
are given only as stable screen IDs.)

### 2.1 Tab bar (4 tabs, always visible, floating pill dock)

| Tab | Screen | Purpose |
|-----|--------|---------|
| Pulse | Home dashboard | The 4 cards, each independently refreshing |
| Explore | Placeholder | Static stub: title "Explore" + "Coming Soon". **Out of scope for v1** — ship the stub as-is |
| Sources | API keys + AI status | Exa/Gemini key entry, Gemini model picker, on-device AI status |
| Settings | Cache + About | Per-card cache ages, Clear All Cache, About block |

Tab icons (web uses Feather-style stroke icons): activity/pulse line, compass,
envelope/key, gear. Active tab gets a pill highlight + soft emerald glow.

### 2.2 Navigation-stack screens (pushed from cards)

| Screen ID | Pushed from | Content |
|-----------|-------------|---------|
| `madrid-hub` | Real Madrid card tap ("View hub") | Next match hero, fixtures timeline, UCL draw, form, intel, Managing Madrid news |
| `mm/:id` | Madrid hub news row | Full Managing Madrid article body |
| `madrid/:id` | (legacy Exa-article route; keep reading the article via `mm/:id` — Exa article detail may be dropped in native) | Exa article w/ highlights |
| `pogo` (PoGo hub) | Pokémon GO card tap | Raid list w/ tier tabs, events list, priority callout |
| `raids/:name` | PoGo hub raid row (`name` slugified: lowercase, non-`[a-z0-9]` → `-`) | Raid boss detail |
| `events/:id` | PoGo hub event row (`eventID`) | Event detail |
| `github` (GitHub hub) | GitHub card tap | Sortable repo list + quota footer |
| `repo/:name` | GitHub hub repo row (repo `name` slugified as above) | Repo detail |
| `article/:id` | AI Intel card item tap (URL last path segment, or slugified headline) | AI news article detail |

All stack screens have a Back affordance and extra bottom padding so content
clears the floating tab bar.

### 2.3 Global chrome (persistent header)

A sticky header above all content shows:

- App logo (rounded 9pt tile) with a **live pulse dot** (small emerald dot,
  pulsing animation) overlaid at its corner.
- Title **"Glance"** + subtitle `"Updated {age}"`, where `{age}` is the
  **freshest (minimum) cache age across the four cards**
  (`just now`, `5m ago`, `3h ago`).
- **Global sync button** (refresh icon; spins while syncing): force-refreshes
  **all four cards in parallel**, then re-renders.
- **Profile/shortcut button** (person icon): deep-links to the Sources tab.
---

## 3. Data Layer

### 3.1 The card pipeline pattern

Every AI-assisted card follows the same pipeline. Port it as a reusable
generic flow, not four bespoke implementations:

```
1. RAW FETCH    call raw source(s) in parallel (Exa, RSS, ScrapedDuck…)
2. PARSE / PICK local deterministic transform (fixture parser, boss picks)
3. ENRICH       on-device AI first → Gemini cloud fallback → raw fallback
4. PERSIST      write result envelope to cache; publish to UI
```

`force` flag: manual refresh (per-card button, global sync) **bypasses all
read caches** but still writes results back.

### 3.2 Cache model

Port as a generic typed envelope (Codable):

```swift
struct CacheEnvelope<T: Codable>: Codable {
    var timestampMs: Int64      // Date.now ms at write
    var ttlMs: Int64?           // nil = permanent (API keys, model choice)
    var data: T
}
var isExpired: Bool { ttlMs.map { nowMs - timestampMs > $0 } ?? false }
```

Cache keys (keep the exact string keys — the Capacitor build's `Preferences`
store already uses them, so keeping them preserves user data across the
Capacitor → native migration):

| Key | Content | TTL |
|-----|---------|-----|
| `cache_madrid` | Madrid card payload (§4.1) | 24 h |
| `cache_pogo` | PoGo card payload (§4.2) | 24 h |
| `cache_github` | GitHub card payload (§4.3) | 24 h |
| `cache_aiintel` | AI Intel payload (§4.4) | 24 h |
| `cache_scrapedd` | Raw `{ raids, events }` ScrapedDuck bundle | 30 min |
| `cache_github_raw` | Raw GitHub search result (pre-velocity) | 24 h |
| `cache_exa_<hash>` | Per-query Exa results | 24 h |
| `gemini_<hash>` | Per-prompt Gemini structured result (**prompt-only hash** — stable across refetches) | 24 h |
| `keys_exa` / `keys_gemini` | `{ value: String }` | **permanent** |
| `gemini_model` | `{ value: String }` selected model id | **permanent** |

> Web note, ported as guidance: storage must survive app restarts
> (web used `UserDefaults`-equivalent persistent storage with an in-memory
> overlay). **Improvement for native:** store `keys_*` in the **Keychain**,
> not `UserDefaults` — the web app's plaintext-key trade-off is documented as
> tech debt, not a requirement.

App launch sequence: **hydrate cache → paint all cards from cache instantly →
background-refresh any card whose entry is missing or expired** (parallel,
`async let` / task group; failures are per-card).

### 3.3 API keys & Sources-screen behavior

- Two keys: **Exa** (powers Madrid + AI Intel raw search) and **Gemini**
  (cloud fallback for all three AI enrichments).
- Optional compile-time prefill (web used `VITE_*` env vars): if a bundled
  key exists it counts as "From .env"; user-entered keys otherwise.
  Display masked (`ab12••••wxyz`, ≤8 chars → `••••••••`).
- Status per key: `From .env` / `Configured ✓` / `Missing`.
- Save writes both keys permanently; empty fields leave existing values.
- Show/hide toggle on the inputs; footer note: "Keys are stored locally on
  your device. Never committed to git." plus "Get Exa key →" (`https://exa.ai`)
  and "Get Gemini key →" (`https://aistudio.google.com/apikey`) links.
- **Key-missing UX:** any card needing a missing key renders a `key-missing`
  state (amber "Key Missing" pill + "Configure in Sources" link) — never an
  error, never blank.
- Gemini model picker (radio list, persists to `gemini_model`):
  `gemini-3.6-flash` (default, "Stable, free tier"),
  `gemini-3.7-flash` ("Stable, newer"),
  `gemini-3.8-flash` ("Latest (intro pricing)").
- On-device AI status card (see §5.1): badge `Active` (emerald) or a reason
  label (`iOS 26+ required` / `Apple Intelligence off` / `Device not
  supported` / `Unavailable`) + "Re-check availability" button + explainer
  ("Apple Foundation Models — zero cost, offline, private").
---

## 4. Feature Specs (the four cards)

### 4.1 Card 1 — Real Madrid (amber)

**Raw inputs (fetched in parallel):**

1. Exa search, query `"Real Madrid next match fixture upcoming schedule"`.
2. Managing Madrid Atom feed: `GET https://www.managingmadrid.com/rss/index.xml`,
   parse first **10** `<entry>` items →
   `{ title, url (link href), published, author (author>name), category, content (content ?? summary as HTML) }`.

**Local fixture parser** (runs on Exa highlights text; works with zero AI):

- Date parsing handles: ISO-8601 tokens, `"Sep 8, 7:00 PM UTC"`,
  `"Sep 8, 2026, 19:00"`, `"Tuesday 8 September"`, `8/9/26`; month-name map;
  `CEST = UTC+2`, `CET = UTC+1`.
- Opponent normalization map (excerpt — port the full table from
  `src/modules/madrid.js` `CLUB_NORMALISE`): inter/internazionale → Inter
  Milan, rayo → Rayo Vallecano, atlético variants, villarreal, etc.
- Stadium regex (Bernabéu variants / `Estadio …`); competition regex
  (UEFA Champions League / La Liga / Copa del Rey).
- Output: `fixture { opponent, datetime (UTC ISO), stadium, competition, venue }`.

**Enrichment** (native §5.2 first, Gemini fallback with schema §5.3, else none):
`{ form[≤5] (strings like "W 2-0"), standing (one line), intel (2 sentences),
head_to_head (optional, e.g. "13 previous meetings") }`.

**Merge rule:** use the enriched fixture only if it has a valid `opponent`,
else the parsed fixture; same for schedule. `status = fixture ? ready : degraded`.
Persisted payload:
`{ fixture, schedule, form, standing, intel, head_to_head, articles, mmArticles, source }`
where `articles` = Exa results mapped to
`{ title, url, publishedDate, highlights, image }`.

**Pulse card body:** crest-vs-opponent hero (Real Madrid crest:
`https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg`; opponent
initials tile fallback), `competition · 🏟 stadium`, IST date line
`📅 {date} · {time} IST` + countdown chip `⏳ {in 2d 4h}`, score line when
present, form dots, standing, intel teaser, recent-headline rows. Source
footer: `⚡ On-device` (emerald) or `☁ Gemini`.

**Madrid hub (`madrid-hub`):** NEXT MATCH hero (crests, opponent, comp/stadium,
IST date, countdown, scores) · UPCOMING FIXTURES vertical timeline ·
GROUP STAGE DRAW two-column Home/Away (parsed from article text; known UCL
opponents include Leipzig, PSV, LASK home / Roma, AEK Athens, Arsenal,
Shakhtar away — port the detection lists) · FORM & STANDING (W/D/L dots +
standing + head-to-head) · TACTICAL INTEL (amber left-border quote) ·
LATEST FROM MANAGING MADRID (up to 10 rows: title 2-line clamp,
`author · category · date`, external-link icon → `mm/:id`).

**Article (`mm/:id`):** title, category pill, author, date, HTML body with
**media stripped** (remove `img, figure, blockquote, iframe, .twitter-tweet,
script`), styled prose (headings, lists, bold, amber links), "Open on
Managing Madrid" button (in-app browser / Safari).

### 4.2 Card 2 — Pokémon GO (rose)

**Raw inputs (parallel GET, no auth, CORS-free JSON):**

- `https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.json`
- `https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.json`

Shapes (fixtures in `docs/api-responses/raids.json`, `events.json`):
raid = `{ name, tier ("1-Star Raids"|"3-Star"|"5-Star"|"Mega Raids"),
canBeShiny, types[{name,image}], combatPower{normal{…},boosted{…}},
boostedWeather[{name,image}], image }`;
event = `{ eventID, name, eventType, heading, link, image, start, end,
extraData{ raidbattles{bosses[],shinies[]}, communityday{spawns[],bonuses[],
bonusDisclaimers[],specialresearch[{tasks[],rewards[]}]}, spotlight{list|name,bonus} } }`.

**Local picks:** drop events with `end` in the past; `fiveStar` = first
non-Shadow 5★, `mega` = first Mega, `shadow` = first Shadow 5★; each pick →
`{ name, maxCp, cpNormal, cpBoosted, weaknesses (type names), image,
canBeShiny, types, boostedWeather }`.

**Priority sentence:** native (§5.2) → Gemini prompt
`"Based on current Pokemon GO raids and events, suggest the top priority
target for a trainer to focus on this week. Be brief."` over
`{ fiveStar, shadow, mega, events: [names] }` → ultimate fallback:
`"Focus on {boss} raids this week."` (or `"Check active raids in-game for
current priority."` when no boss known).
Persisted: `{ raids, events, fiveStar, mega, shadow, targetPriority,
credit: "Data from ScrapedDuck / LeekDuck.com", source }`.

**Pulse card body:** 5★ vs Shadow dual tiles (image, name, ✨ if shiny,
CP range, countdown-to-rotation chip from most-urgent event), upcoming-events
rows (name + heading pill + ends-in chip), 🎯 priority callout, mandatory
credit footer.

**PoGo hub (`pogo`):** tier tab filter `All | 1★ | 3★ | 5★ | Mega | Shadow`
(with counts; Shadow = 5★ names starting with "Shadow"); raid rows (artwork,
name + ✨, tier stars / MEGA / SHADOW badge, type icons, `CP a–b ⬆c–d`,
shiny + weather-boost lines) → `raids/:name`; UPCOMING EVENTS section →
`events/:id`; TARGET PRIORITY panel; credit footer.

**Raid detail:** hero (artwork, name, tier pill, shiny pill), Types chips,
Combat Power panel (Catch CP Normal vs Weather Boosted + explainer caption),
Weather Boost chips. **Event detail:** hero (image, name, type pill, date
range, source link), Raid Bosses grid (name + shiny tag), Shiny Variants,
Community-Day Featured Spawns / Bonuses (+ disclaimers) / Special Research
steps (`☐ task → reward` rows + step rewards), Spotlight Hour (bonus + mons).
Both carry a developer-style "Raw API Data" collapsible — native may keep
this as a debug-only (`#DEBUG`) section.
---

### 4.3 Card 3 — GitHub Trending (emerald, no AI)

**Fetch:** `GET https://api.github.com/search/repositories` with
`q=topic:llm+topic:ai+created:>{7-days-ago YYYY-MM-DD}&sort=stars&order=desc`.
No auth. `403` = rate-limited → surface rate-limit error (read `retry-after`).
Record `x-ratelimit-remaining`. Take top **10** (`TOP_N_REPOS` constant —
design spec default is 3; code ships 10; keep a constant so it's tunable).

**Velocity:** compare each repo's `stargazers_count` against the previously
persisted card payload (`cache_github.repos[].stars` by `full_name`); positive
delta ⇒ `velocity` pill `+N`. First sync shows no pills (nothing to compare).
This is intentionally *not* a true 24 h delta — document as approximate.

**Repo model (port all fields):** `fullName, name, description, language,
stars, forks, issues (open_issues_count), watchers, pushedAt, createdAt,
hasWiki, hasPages, hasDiscussions, topics[], license?.name, ownerLogin,
ownerAvatar, url (html_url), homepage, velocity?, raw?`.
Persisted: `{ repos, totalCount, rateLimitRemaining }`.

**Pulse card body:** top repos (avatar, `owner/name` truncate, `★ 1.2k`,
`+N` velocity pill, language dot + color, `pushed today/yesterday/Nd ago`).
Language colors (port map): TypeScript `#3178C6`, JavaScript `#F1E05A`,
Python `#3572A5`, Go `#00ADD8`, Rust `#DEA584`, Java `#B07219`, C++
`#F34B7D`, Swift `#F05138`, Kotlin `#A97BFF`, Dart `#00B4AB`, Shell
`#89E051`, Lua `#000080`, fallback `#64748B`.

**GitHub hub:** sort segmented control Stars (default) / Fresh
(`pushedAt` desc) / Hot (`velocity` desc); header count
`"{totalCount} match this week"`; rows as on card + description (2-line) +
topic chips; footer `"GitHub API · {N} requests remaining this hour"`.
**Repo detail:** avatar + name + owner, `Pushed {rel} · Created {date}`,
4-stat grid (Stars / Forks / Issues / Watchers, tabular numerals), pills
(language, license, Wiki, Pages, Discussions, 🌐 Homepage), Topics chips,
"Open on GitHub →" button.

### 4.4 Card 4 — AI Intel (cyan)

**Raw:** Exa search `"latest AI LLM breakthroughs, open source releases,
frontier lab announcements"` → articles:
`{ title, url, publishedDate, author, highlights, source (URL hostname), image }`.

**Structure** (native §5.2 → Gemini §5.3 → degraded): **2–3 items** of
`{ tag: "FRONTIER LABS" | "OPEN WEIGHTS", headline, bullets[], benchmarks[] }`.
Tag rule: OpenAI / Anthropic / Google DeepMind / Meta ⇒ FRONTIER LABS, else
OPEN WEIGHTS. **Join by index** with Exa articles for `url, publishedDate,
author, source, image` (+ `title=headline`, `highlights=bullets`) — the model
**must never invent URLs**. Degraded fallback: first 3 Exa articles tagged
OPEN WEIGHTS with `bullets=[highlights[0]]`, `status=degraded`.
Persisted: `{ items, articles, source }`.

**Pulse card body:** items with tag pill (frontier = distinct styling),
headline, 1–2 bullets, benchmark chips; tap → `article/:id`.
**Article detail:** hero image, headline, tag pill, source · author · date,
BENCHMARKS chips, Key Points list, "Full Coverage" expandable (extra
highlights), "Read original article" button.
---

## 5. Intelligence Layer (Swift-native spec)

The current app already runs this hybrid on-device: the Capacitor plugin
(`ios/App/App/Plugins/NativeIntelligence.swift` + `Models.swift`) wraps
**Apple Foundation Models** (`LanguageModelSession`, `@Generable` structs)
with Gemini REST as fallback. **A Swift-only app deletes the bridge and calls
Foundation Models directly** — reuse the prompts and `@Generable` models
verbatim (copy `Models.swift`: `RealMadridEnrichment`, `PoGoPriority`,
`AiIntelItem(s)` with their `@Guide` descriptions).

### 5.1 Availability check

`SystemLanguageModel.default.availability` → `available` boolean + reason.
Map to UI: `available` ⇒ "Active"; else one of `iOS 26+ required`
(`osBelow26`), `Apple Intelligence off`, `Device not supported`,
`frameworkMissing`/`bridge-error` ⇒ "Unavailable". Cache the verdict for the
session; Sources "Re-check" invalidates it. Requires iOS 26+, Apple
Intelligence enabled, eligible device. Truncate every prompt payload to
**6,000 chars**.

### 5.2 Native prompts & contracts (exact behavior to reproduce)

| Method | Prompt (verbatim) | Returns |
|--------|-------------------|---------|
| `processRealMadrid(snippets)` | `"Extract Real Madrid enrichment (recent form results, La Liga standing, tactical intel summary, head-to-head record) from these snippets: {snippets}"` | `{ form[≤5], standing, intel, head_to_head }` |
| `processPoGo(snippets)` | `"From these Pokemon GO raid/event snippets, write one sentence naming the top priority raid target and why: {snippets}"` | `{ priority }` |
| `processAiIntel(snippets)` | `"Read these technology news summaries and for each one, classify it as coming from a major research lab or an open-source community project. Return 2-3 items with a short headline and 1-2 bullet points summarizing the key detail. Snippets: {snippets}"` | `{ items[{ tag, headline, bullets, benchmarks }] }` |

JS normalization after resolve (port): Madrid keeps only enrichment keys
(fixture/schedule come from the local parser — see §4.1 merge rule); PoGo
accepts `priority ?? raw ?? ""`; AI Intel coerces any tag ≠ `FRONTIER LABS`
to `OPEN WEIGHTS` and caps at 3 items.

### 5.3 Gemini REST fallback (URLSession)

- Endpoint: `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}`
- Body: `{ contents: [{ parts: [{ text: "{prompt}\n\nReturn JSON matching this schema hint:\n{schema}\n\nRaw data:\n{payload}" }] }], generationConfig: { responseMimeType: "application/json" } }`
  — **`responseMimeType: application/json` is mandatory**; never rely on the prompt alone.
- Schemas: Madrid `{ fixture{opponent,datetime,stadium,competition,scores?}, schedule[], form[], standing, intel, head_to_head? }`; AI Intel `{ items[{tag,headline,bullets,benchmarks?}] }`; PoGo = free-text sentence (tolerate `{priority}` / `{raw}` / raw string).
- **Retry ladder:** `429` → exponential backoff 1 s / 2 s / 4 s; `503` → wait
  5 s / 15 s / 45 s; bad JSON → retry once, then `{ raw: text }`; `429/403`
  after retries → return `null` so the caller takes the degraded path (§4.x).
  Missing key → throw `key-missing` (card state, not crash).
- Limits to respect in UX copy/scheduling: free tier ≈ 15 req/min, 1,500/day;
  TTLs + prompt-hash caching already minimize calls — keep them.

### 5.4 Exa REST (URLSession — no CORS concept natively)

- `POST https://api.exa.ai/search`, headers `x-api-key: {key}`,
  `Content-Type: application/json`; body `{ query, type: "auto", contents: { highlights: true } }`.
- Map results → `{ title, url, text, highlights[], image?, publishedDate?, source? }`.
  Missing key → `key-missing`; non-native-web `native-required` state does
  **not** exist natively — delete it (web-only: Exa is unreachable from mobile
  browsers due to CORS, hence the Capacitor HTTP bridge; `URLSession` has no
  such restriction).
---

## 6. Card States & Failure UX (every card implements all of these)

| State | Trigger | UI |
|-------|---------|----|
| `loading` | No cache + fetch in flight | Shimmer skeleton (3 shimmering lines) |
| `ready` | Fresh or cached data painted | Full body + age timestamp (`5m ago`) |
| `stale` | Cache present but TTL-expired (painted while refetching) | Ready UI (optionally dimmed/"syncing" affordance) |
| `degraded` | Fetch/parse partially failed, raw fallback used | Ready UI on raw data + source footer shows no AI badge |
| `error` | Total failure, no cache | "Something went wrong. Tap refresh to try again." + retry |
| `offline` | No connectivity, cache shown | "Offline · Showing cached data" pill |
| `key-missing` | Key required but absent | Amber "Key Missing" pill + "Configure in Sources" link |
| `native-required` | **Web-only — do not port** | (Exa-over-CORS limitation; gone natively) |

Rules: per-card refresh button (spins/disabled while its card loads);
timestamps use `formatAge` (`just now` <60 s, `Nm ago` <60 m, `Nh ago`,
`Nd ago` beyond); metric numerals use tabular figures; broken remote images
fall back to an initials tile (never a broken-image icon or empty gap).

---

## 7. Time Formatting (port `src/utils/time.js` semantics)

- **Madrid kickoff — IST:** all fixture datetimes stored UTC ISO, **displayed
  in Asia/Kolkata**: `"Tue, Sep 8 · 12:30 AM IST"` + day label
  Today/Tomorrow/date. (Use `TimeZone(identifier: "Asia/Kolkata")` +
  relative-day check in that zone.)
- `countdownTo`: future → `"in 40m"`, `"in 5h 12m"`, `"in 2d 4h"`,
  `"starting now"` (<1 m); past/invalid → `""`.
- `endsIn(end)`: `"Ends in 6h"`, `"Ends in 40m"`, `"Ends tomorrow"`,
  `"Ends in Nd"`; past → `""`.
- **Urgent-event pick** (PoGo countdown chip): ending-soonest *active* event;
  else starting-soonest *future* event; else first event.
- `relativeTime` (repos): `today` / `yesterday` / `Nd ago`.
- `formatDate`: `"Sep 8"`. `formatStars`: `12400 → "12.4k"`.
- `readTime` (article meta, optional): `words/200 → "N min read"`.
---

## 8. Design System — Obsidian Pulse (SwiftUI mapping)

Authoritative values: `src/styles/main.css` `@theme`. Visual reference:
`docs/glance_dashboard_mockup/screen.png` (+ `DESIGN.md`, `code.html`).

**Palette (asset catalog):**

| Token | Hex | Usage |
|-------|-----|-------|
| `canvas` | `#0F131D` | App background |
| `canvasDeep` | `#0A0E18` | Input fields, deep recess |
| `surface…Highest` | `#171B26 → #313540` | Layered surfaces |
| `textPrimary / Secondary / Muted` | `#F8FAFC / #94A3B8 / #64748B` | Text hierarchy |
| `primary` | `#4EDEA3` | Brand/active-tab tint |
| `primaryDim` | `#10B981` | Links, secondary actions |
| `amber / rose / emerald / cyan` | `#F59E0B / #F43F5E / #10B981 / #06B6D4` | Card accents: Sports / Gaming / Engineering / AI |
| `error` | `#FFB4AB` | Destructive |
| `borderSubtle` | `#334155` | Hairlines |

> `cyan #06B6D4` intentionally overrides the older blue `#3B82F6` in
> `docs/design.md` — cyan wins.

**Card anatomy (build one `GlanceCard` view, parameterize accent):**
20pt corner radius; "liquid glass" = diagonal white→transparent gradient
overlay + `ultraThinMaterial`-style blur (≈24pt, saturated) + 1pt
top-highlight border + deep drop shadow; per-accent top-sheen tint +
press state scale 0.985; header row = badge pill + age + actions
(external-link, refresh); optional "View hub ›" footer for hub-linked cards;
optional source footer.
Badges: `Sports` (amber, Real crest logo), `Gaming` (rose), `Engineering`
(emerald), `AI Intel` (cyan) — uppercase 10pt/700/tracked pill, logo-leading
where applicable.

**Typography:** Display/headlines/metrics → **Manrope**
(Bold 28/34, SemiBold 22/28, ExtraBold metric 32/36, tight tracking);
body/labels → **Hanken Grotesk** (Regular 16/22 + 13/18, SemiBold 13/16
labels). Bundle both fonts or map to SF Pro fallback. Metrics always
tabular (`monospacedDigit`).
---

**Motion & chrome:** ambient per-accent glow behind cards (low-alpha,
large-radius shadow); pulse-dot ping (2 s); skeleton shimmer (1.5 s);
press states everywhere; honor Reduce Motion (`accessibilityReduceMotion`);
safe-area insets (notch + home indicator) with ≈96pt bottom clearance for
the floating dock; pull-to-refresh optional (buttons are the contract).

---

## 9. API Contract Summary (for the networking layer)

| Source | Request | Auth | Limits / notes |
|--------|---------|------|----------------|
| Exa Search | `POST api.exa.ai/search` `{query, type:"auto", contents:{highlights:true}}` | `x-api-key` header | Paid/free-tier — key required |
| Managing Madrid | `GET managingmadrid.com/rss/index.xml` (Atom) | none | Fair use; tolerate shape drift |
| ScrapedDuck | `GET raw.githubusercontent.com/bigfoott/ScrapedDuck/data/{raids,events}.json` | none | Fair use; tolerant mapping; **credit required** |
| GitHub REST | `GET api.github.com/search/repositories?q=topic:llm+topic:ai+created:>{date}&sort=stars&order=desc` | none | 60 req/h unauthenticated; honor `retry-after`, show quota |
| Gemini | `POST generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key=` + JSON-mode body | `key` query param | 15 RPM / 1,500 RPD free; retry ladder §5.3 |
| Foundation Models | `LanguageModelSession` (iOS 26+) | none — on-device | Availability gate §5.1; 6k-char cap |
---

## 10. Swift Port Mapping (suggested, non-binding)

| Web (`src/`) | Native equivalent |
|--------------|-------------------|
| `cache.js` | `CacheStore` actor: `UserDefaults` envelopes (Codable) + Keychain for `keys_*`; `hydrate()` at launch |
| `state.js` (4 modules + refresh orchestration) | `Observable` `PulseStore` holding 4 card states; `refreshAll()` via task group |
| `api/exa.js, gemini.js, github.js, scrapedd.js, managing-madrid.js` | `ExaClient, GeminiClient (retry ladder), GitHubClient, ScrapedDuckClient, ManagingMadridClient (XMLParser)` — `async/await` + `URLSession` |
| `api/native-intelligence.js` + `ios/.../Plugins/*.swift` | Delete bridge; call `LanguageModelSession` + copied `@Generable` models directly |
| `modules/*.js` + `transforms.js` | `MadridPipeline, PoGoPipeline, GitHubPipeline, AiIntelPipeline` (pure functions, unit-testable) + fixture parser port |
| `utils/time.js` | `TimeFormat` (`DateFormatter`/`RelativeDateTimeFormatter`, IST `TimeZone`) |
| `pages/pulse.js` + `components/card,badge,header,nav` | `PulseView, GlanceCard, Badge, GlanceHeader, DockTabBar` (SwiftUI) |
| `pages/*-hub/detail, sources, settings` | One `View` per screen in §2.2; `SourcesView` (secure fields + model picker), `SettingsView` |
| `pages/explore.js` | Static stub view |
| `public/manifest.json`, icons | Xcode target config + existing `AppIcon.appiconset` |

**Delete, do not port:** hash router, service worker, Capacitor config/plugin
list, `native-required` state, dev-proxy code paths, gesture hacks, web font
loading.

---

## 11. Out of Scope for v1 (ship stubs or omit)

- Explore page (stub: title + "Coming Soon").
- Push notifications, widgets, Siri/Shortcuts, Watch app.
- football-data.org structured scores (queued v1.1 in design spec).
- True 24 h GitHub star deltas (velocity stays approximate).
- Android port (existing Capacitor shell remains the Android story).

---

## 12. Acceptance Checklist (parity gate for the native build)

- [ ] Cold launch paints all 4 cards from cache with zero network.
- [ ] Each card refreshes independently; global sync refreshes all in parallel.
- [ ] Airplane-mode launch shows cached data + Offline pill; no blanks/crashes.
- [ ] Missing Exa key → Madrid + AI Intel show Key-Missing; missing Gemini key
      → AI features degrade to raw (never error).
- [ ] On-device AI path (eligible iOS 26 device, prompts §5.2) produces
      form/standing/intel, priority sentence, 2–3 tagged briefs; disabling it
      falls back to Gemini, then raw.
- [ ] Madrid hub shows fixture, timeline, draw, form, intel, 10 MM articles;
      article body renders stripped of media with working outbound link.
- [ ] PoGo hub tabs filter correctly; raid/event details render all sections;
      credit line visible on card + hub.
- [ ] GitHub hub sorts 3 ways; velocity pills appear after 2nd sync; quota
      footer accurate; repo detail stats correct.
- [ ] AI article detail shows benchmarks, key points, full coverage, source link.
- [ ] Sources persists keys across restarts (Keychain), model choice persists,
      native status re-check works.
- [ ] Settings cache ages accurate; Clear Cache forces refetch, keeps keys.
- [ ] Dark-only Obsidian theme, correct accents/fonts/radii, safe-area clean
      on notched devices, Reduce Motion honored.
- [ ] No API keys in source, logs, or the binary's plaintext resources.

---

*End of native PRD v1. Open questions for the Swift build: minimum iOS
version if Foundation Models is optional (suggest iOS 17 + graceful
`frameworkMissing` path vs iOS 26-only target); Keychain vs Keychain+biometric
for API keys; SwiftUI minimum-version vs UIKit for the dock/tab chrome.*
