# API-Football Integration for Real Madrid

**Date:** 2026-09-11
**Status:** Approved
**Scope:** Replace Exa-based fixture scraping with structured API-Football data for the Madrid feature

---

## 1. Problem

The current Madrid feature uses Exa (web scraping) to find fixture/form data, then regex-parses free-text results in `MadridFixtureParser.swift`. This is fragile — opponents, scores, and form dots are extracted via text patterns that break when website formats change.

## 2. Goal

Use the structured API-Football v3 API to fetch reliable match data. Keep Exa for related articles. Keep ManagingMadridClient for RSS articles. Add API key storage in Settings.

---

## 3. API-Football Details

- **Base URL:** `https://v3.football.api-sports.io`
- **Real Madrid team ID:** `541`
- **La Liga league ID:** `140`
- **Champions League league ID:** `2`
- **Auth header:** `x-apisports-key: <key>`
- **Free tier:** 100 requests/day (sufficient with 24h caching)

### Endpoints Used

| Endpoint | Params | Returns |
|----------|--------|---------|
| `/fixtures?team=541&last=5` | team, last | Last 5 results with scores, venues, events |
| `/fixtures?team=541&next=1` | team, next | Next fixture with date/time, venue |
| `/standings?league=140&season=2026` | league, season | La Liga table — RM position, pts, GD, W/D/L |

**Quota cost:** 3 calls per refresh. With 24h cache = 3 calls/day.

---

## 4. Constants

```swift
enum FootballAPI {
    static let baseURL = "https://v3.football.api-sports.io"
    static let realMadridID = 541
    static let laLigaID = 140
    static let championsLeagueID = 2
    static let currentSeason = 2026
}
```

---

## 5. Files to Create

### 5.1 `Core/Network/APIFootballClient.swift`

Protocol + struct following the `ExaClient`/`ManagingMadridClient` pattern:

```swift
protocol APIFootballClientProtocol: Sendable {
    func lastFixtures(teamID: Int, last: Int, apiKey: String) async throws -> [APIFixture]
    func nextFixtures(teamID: Int, next: Int, apiKey: String) async throws -> [APIFixture]
    func standings(leagueID: Int, season: Int, apiKey: String) async throws -> APIStandingsResponse
}

struct APIFootballClient: APIFootballClientProtocol, Sendable {
    func lastFixtures(teamID: Int, last: Int, apiKey: String) async throws -> [APIFixture]
    func nextFixtures(teamID: Int, next: Int, apiKey: String) async throws -> [APIFixture]
    func standings(leagueID: Int, season: Int, apiKey: String) async throws -> APIStandingsResponse
}
```

- Retry on 429 with exponential backoff (same pattern as ExaClient)
- Rate limit: max 1 call per second (API-Football requirement)
- Uses `URLSession.shared`

### 5.2 `Features/Madrid/APIFootballModels.swift`

Decodable response structs:

```swift
// MARK: - Fixtures Response
struct APIFixturesResponse: Codable {
    let response: [APIFixture]
}

struct APIFixture: Codable {
    let fixture: APIFixtureInfo
    let league: APILeague
    let teams: APITeams
    let goals: APIGoals
    let score: APIScore
}

struct APIFixtureInfo: Codable {
    let id: Int
    let date: String           // ISO 8601
    let status: APIStatus
    let venue: APIVenue?
}

struct APIStatus: Codable {
    let short: String          // "FT", "NS", "1H", "2H", etc.
    let long: String           // "Match Finished", "Not Started"
}

struct APIVenue: Codable {
    let name: String?
    let city: String?
}

struct APILeague: Codable {
    let id: Int
    let name: String           // "La Liga"
    let round: String?         // "Regular Season - 28"
}

struct APITeams: Codable {
    let home: APITeam
    let away: APITeam
}

struct APITeam: Codable {
    let id: Int
    let name: String
    let logo: String
    let winner: Bool?
}

struct APIGoals: Codable {
    let home: Int?
    let away: Int?
}

struct APIScore: Codable {
    let halftime: APIGoals?
    let fulltime: APIGoals?
    let penalty: APIGoals?
}

// MARK: - Standings Response
struct APIStandingsResponse: Codable {
    let response: [APIStandingsLeague]
}

struct APIStandingsLeague: Codable {
    let league: APIStandingsInfo
}

struct APIStandingsInfo: Codable {
    let id: Int
    let name: String
    let standings: [[APIStandingRow]]
}

struct APIStandingRow: Codable {
    let rank: Int
    let team: APITeam
    let points: Int
    let goalsDiff: Int
    let all: APIStandingStats
    let won: Int
    let draw: Int
    let lose: Int
}

struct APIStandingStats: Codable {
    let played: Int
    let win: Int
    let draw: Int
    let lose: Int
    let goals: APIGoals
}

// MARK: - Events (scorers, cards)
struct APIEvent: Codable {
    let time: APIEventTime
    let team: APITeam
    let player: APIEventPlayer?
    let type: String            // "Goal", "Card"
    let detail: String          // "Normal Goal", "Yellow Card"
}

struct APIEventTime: Codable {
    let elapsed: Int
    let extra: Int?
}

struct APIEventPlayer: Codable {
    let id: Int?
    let name: String?
}
```

### 5.3 `Features/Madrid/MadridFixtureDetail.swift`

Optional: a detail view for tapping into a specific last match. Shows full event list (goals, cards, substitutions). Can be added later — not required for MVP.

---

## 6. Files to Modify

### 6.1 `Features/Madrid/MadridModels.swift`

Add new model types and extend `MadridData`:

```swift
struct MadridData: Codable, Sendable, Equatable {
    let fixture: Fixture?              // next fixture (existing)
    let lastMatch: LastMatch?          // NEW — last completed match
    let schedule: [ScheduleItem]       // keep
    let form: [String]                 // keep (W/D/L + score)
    let standing: StandingInfo?        // NEW — structured standing
    let standingText: String           // keep — fallback text
    let intel: String                  // keep
    let headToHead: String?            // keep
    let articles: [ExaArticle]         // keep — related articles
    let mmArticles: [MMArticle]        // keep — Managing Madrid
    let source: String                 // keep
    let timestamp: Date                // keep
}

// NEW
struct LastMatch: Codable, Sendable, Equatable {
    let opponent: String
    let score: Score
    let competition: String
    let venue: String
    let datetime: String
    let status: String                 // "FT", "AET", "PEN"
    let scorers: [MatchEvent]         // goals
    let cards: [MatchEvent]           // yellow/red cards
    let round: String?
}

struct MatchEvent: Codable, Sendable, Equatable {
    let minute: Int
    let player: String
    let type: String                   // "goal", "yellowCard", "redCard"
    let detail: String                 // "Normal Goal", "Own Goal", "Penalty"
    let team: String                   // "home" or "away"
}

struct Score: Codable, Sendable, Equatable {
    let home: Int
    let away: Int
}

struct StandingInfo: Codable, Sendable, Equatable {
    let rank: Int
    let points: Int
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
}
```

### 6.2 `Features/Madrid/MadridPipeline.swift`

Major changes:

1. **Add `APIFootballClient` dependency** (alongside existing Exa and ManagingMadrid)
2. **Fetch from API-Football** for match data (replaces Exa parsing for fixtures)
3. **Keep Exa** for related articles only
4. **Keep ManagingMadridClient** for MM articles

```swift
struct MadridPipeline: Sendable {
    private let footballClient: any APIFootballClientProtocol
    private let exa: any ExaClientProtocol
    private let madridClient: any ManagingMadridClientProtocol
    private let keychain: KeychainStore
    private let cache: CacheStore

    func refresh(force: Bool = false) async -> MadridRefreshResult {
        // 1. Load API-Football key
        guard let apiKey = keychain.load(forKey: "keys_football") else {
            // Fall back to Exa-only mode
            return await refreshWithExa()
        }

        // 2. Fetch from API-Football (3 calls, sequential to respect rate limit)
        async let lastFixtures = footballClient.lastFixtures(
            teamID: FootballAPI.realMadridID, last: 5, apiKey: apiKey
        )
        async let nextFixture = footballClient.nextFixtures(
            teamID: FootballAPI.realMadridID, next: 1, apiKey: apiKey
        )
        async let standings = footballClient.standings(
            leagueID: FootballAPI.laLigaID, season: FootballAPI.currentSeason, apiKey: apiKey
        )

        let (lastResults, nextResults, standingsResponse) = await (lastFixtures, nextFixture, standings)

        // 3. Parse results into MadridData
        let lastMatch = parseLastMatch(from: lastResults)
        let form = parseForm(from: lastResults)
        let standing = parseStanding(from: standingsResponse)
        let nextFixtureParsed = parseNextFixture(from: nextResults)

        // 4. Fetch Exa for related articles (unchanged)
        async let exaTask = fetchExaArticles()

        // 5. Fetch MM articles (unchanged)
        async let mmTask = madridClient.fetchArticles()

        // 6. Combine
        let data = MadridData(
            fixture: nextFixtureParsed,
            lastMatch: lastMatch,
            schedule: [],
            form: form,
            standing: standing,
            standingText: formatStandingText(standing),
            intel: generateIntel(nextFixtureParsed, lastMatch),
            headToHead: nil,
            articles: await exaTask,
            mmArticles: await mmTask,
            source: "api-football",
            timestamp: Date.now
        )

        await cache.save("cache_madrid", envelope: CacheEnvelope(data: data, ttlMs: 24 * 3_600_000))
        return .ready(data: data)
    }
}
```

**Key changes:**
- Remove `parseFixture(from: [ExaResult])` call (old regex parsing)
- Remove `IntelligenceRouter.enrichMadrid` call (was enriching Exa text)
- Add `parseLastMatch`, `parseForm`, `parseStanding`, `parseNextFixture` helpers
- Exa is only used for related articles now

### 6.3 `Settings/SettingsStore.swift`

Add `footballAPIKey` property:

```swift
@Observable
@MainActor
final class SettingsStore {
    var exaAPIKey: String = ""
    var geminiAPIKey: String = ""
    var footballAPIKey: String = ""    // NEW
    var selectedModel: String = "gemini-3.6-flash"

    func loadFromKeychain() {
        exaAPIKey = ""
        geminiAPIKey = ""
        footballAPIKey = ""
        selectedModel = defaults.string(forKey: "gemini_model") ?? "gemini-3.6-flash"
    }

    func saveToKeychain() {
        // ... existing exa/gemini saves ...
        if !footballAPIKey.isEmpty {
            try? keychain.save(footballAPIKey, forKey: "keys_football")
        }
    }

    func existingKey(for service: String) -> String? {
        let keyMap = ["Exa": "keys_exa", "Gemini": "keys_gemini", "Football": "keys_football"]
        guard let key = keyMap[service] else { return nil }
        // ... existing masking logic ...
    }
}
```

### 6.4 `Settings/SourcesView.swift`

Add API-Football key section (same pattern as Exa/Gemini):

```swift
// After Gemini section, before model picker:
keySection(
    title: "API-FOOTBALL KEY",
    key: "Football",
    value: $store.footballAPIKey,
    isSecure: !showFootballKey,
    toggle: { showFootballKey.toggle() },
    status: footballStatus,
    link: "https://dashboard.api-football.com/register"
)

// Add computed property:
private var footballStatus: KeyStatus {
    if store.footballAPIKey.isEmpty {
        return store.existingKey(for: "Football") != nil ? .fromEnv : .missing
    }
    return .configured
}
```

### 6.5 `Features/Pulse/GlanceCardView.swift`

Update `madridContent` to show:
- **Last match score** (if no upcoming fixture) or **next fixture** (if upcoming)
- **Form dots** from structured data
- **Standing text** from `StandingInfo`

```swift
private func madridContent(_ data: MadridData) -> some View {
    VStack(alignment: .leading, spacing: Theme.spacing) {
        // Priority: next fixture > last match
        if let fixture = data.fixture {
            nextMatchCard(fixture)
        } else if let lastMatch = data.lastMatch {
            lastMatchCard(lastMatch)
        }

        // Form dots
        if !data.form.isEmpty {
            formStrip(data.form)
        }

        // Standing
        if let standing = data.standing {
            standingLine(standing)
        }

        // MM articles (top 3)
        ForEach(data.mmArticles.prefix(3)) { article in
            mmArticleRow(article)
        }
    }
}
```

### 6.6 `Features/Madrid/MadridHubView.swift`

Restructure sections:

```swift
private func madridSections(_ data: MadridData) -> some View {
    VStack(alignment: .leading, spacing: 20) {
        // 1. Last Match (with scorers + cards)
        if let lastMatch = data.lastMatch {
            lastMatchHero(lastMatch)
        }

        // 2. Next Match
        if let fixture = data.fixture {
            nextMatchHero(fixture)
        }

        // 3. Form strip
        if !data.form.isEmpty {
            formSection(data)
        }

        // 4. Standing card
        if let standing = data.standing {
            standingCard(standing)
        }

        // 5. Managing Madrid articles
        if !data.mmArticles.isEmpty {
            mmArticlesSection(data.mmArticles)
        }

        // 6. Related articles (Exa)
        if !data.articles.isEmpty {
            exaArticlesSection(data.articles)
        }
    }
}
```

**New UI sections:**

#### Last Match Hero
```
┌─ LAST MATCH ─────────────────────────┐
│ La Liga · Matchday 28                │
│                                      │
│  [RM]  2 - 1  [ATM]                 │
│                                      │
│ 🏟️ Cívitas Metropolitano            │
│ ⚽ Mbappé 23', Vinícius 67'         │
│ 🟨 Camavinga 55'                    │
│ ✅ FT                                │
└──────────────────────────────────────┘
```

#### Standing Card
```
┌─ LA LIGA ────────────────────────────┐
│ 1st  Real Madrid                    │
│ P28  W21 D5 L2  GD +42  68pts      │
└──────────────────────────────────────┘
```

---

## 7. Data Flow Diagram

```
┌─────────────────────────────────────────────┐
│              MadridPipeline                  │
│                                              │
│  ┌──────────────┐   ┌──────────────────┐    │
│  │ APIFootball  │   │ ExaClient        │    │
│  │ Client       │   │ (articles only)  │    │
│  │              │   │                  │    │
│  │ /fixtures    │   │ search("Real     │    │
│  │  ?last=5     │   │  Madrid news")   │    │
│  │  ?next=1     │   │                  │    │
│  │ /standings   │   └──────────────────┘    │
│  └──────┬───────┘                            │
│         │                                    │
│         ▼                                    │
│  ┌──────────────┐   ┌──────────────────┐    │
│  │ Parse into   │   │ ManagingMadrid   │    │
│  │ MadridData   │   │ Client (RSS)     │    │
│  │              │   │                  │    │
│  │ lastMatch    │   │ fetchArticles()  │    │
│  │ fixture      │   │                  │    │
│  │ form         │   └──────────────────┘    │
│  │ standing     │                            │
│  └──────┬───────┘                            │
│         │                                    │
│         ▼                                    │
│  ┌──────────────┐                            │
│  │ CacheStore   │                            │
│  │ 24h TTL      │                            │
│  └──────────────┘                            │
└─────────────────────────────────────────────┘
```

---

## 8. Fallback Behavior

| Condition | Behavior |
|-----------|----------|
| No `keys_football` in keychain | Fall back to Exa-only mode (current behavior). Show "API key missing" in Sources. |
| API-Football rate limited (429) | Retry with backoff. If all retries fail, use cached data. |
| API-Football returns empty | Show "No data" state, keep cached data if available |
| Exa key missing | Related articles section hidden, match data still works |
| MM RSS fails | MM articles section hidden, match data still works |

---

## 9. Keychain Keys

| Key | Service | Purpose |
|-----|---------|---------|
| `keys_football` | API-Football | New — API key for match data |
| `keys_exa` | Exa | Existing — kept for related articles |
| `keys_gemini` | Gemini | Existing — unchanged |

---

## 10. Caching Strategy

- **Cache key:** `cache_madrid` (same as current)
- **TTL:** 24 hours (3 calls/day is well within free tier)
- **Stale data:** Show with "stale" badge while refreshing
- **Offline:** Show last cached data with "offline" badge

---

## 11. UI Summary

### Pulse Card (compact)
- Next fixture OR last result (priority: next > last)
- Form strip: 5 W/D/L dots with scores
- Standing: "1st · 68pts · W21 D5 L2 · GD +42"
- Top 3 MM articles

### Hub View (full)
1. Last Match — score, scorers, cards, venue, status
2. Next Match — countdown, venue, competition
3. Form — 5 result dots with scores
4. Standing — rank, P/W/D/L, GD, points
5. Managing Madrid — RSS articles (unchanged)
6. Related Articles — from Exa (unchanged)

---

## 12. Out of Scope (Future)

- Detailed match statistics (possession, shots, passes)
- Head-to-head history endpoint
- Lineups and formations
- Player ratings
- Multiple league support (Champions League standings)
- Live match tracking

---

## 13. Implementation Order

1. Create `APIFootballModels.swift` (data structures)
2. Create `APIFootballClient.swift` (network layer)
3. Add `footballAPIKey` to `SettingsStore` + `SourcesView`
4. Update `MadridModels.swift` (add `LastMatch`, `StandingInfo`)
5. Update `MadridPipeline.swift` (fetch from API-Football, keep Exa/MM)
6. Update `GlanceCardView.swift` (card layout)
7. Update `MadridHubView.swift` (hub layout)
8. Test with real API key
