# Migration Plan: API-Football → API-Sports (thesportsdb.com)

**Date:** 2026-09-11
**Status:** Planned
**Scope:** Replace API-Football v3 data source with API-Sports (thesportsdb.com) free tier due to API-Football free tier restrictions

---

## 1. Classification

**Path: Architectural** — This is a new project/subsystem change that restructures how components fit together. The existing Madrid feature code must be understood, API-Sports documentation explored, and a migration strategy designed before any implementation begins.

**Why not Spike?** — This is not a quick feasibility question; it's a planned replacement of a data source affecting multiple files.

**Why not Bounded?** — This touches multiple independent subsystems (network layer, models, pipeline, UI, settings) and cannot be scoped to a single file.

---

## 2. Current State (What Exists)

### 2.1 Files Already Explored

| File | Purpose | Key Findings |
|------|---------|--------------|
| `Glance/Features/Madrid/MadridModels.swift` | Data models (`MadridData`, `Fixture`, `ScheduleItem`, `ExaArticle`) | Has `fixture`, `schedule`, `form`, `standing`, `intel`, `mmArticles`, `articles` |
| `Glance/Features/Madrid/MadridPipeline.swift` | Data fetching orchestration | Uses ExaClient (web scraping), ManagingMadridClient (RSS), `parseFixture(from:)` regex parser |
| `Glance/Features/Pulse/GlanceCardView.swift` | Pulse card UI | `madridContent()` shows next fixture, form dots, standing text, MM articles |
| `Glance/Features/Madrid/MadridHubView.swift` | Hub view UI | 6 sections: Last Match, Next Match, Form, Standing, MM Articles, Related Articles |
| `Glance/Settings/SettingsStore.swift` | API key storage | Has `exaAPIKey`, `geminiAPIKey`, `selectedModel`; `loadFromKeychain()`/`saveToKeychain()` |
| `Glance/Settings/SourcesView.swift` | Settings UI | Key sections for Exa + Gemini; "Save Keys" button |
| `Glance/Core/Network/APIFootballClient.swift` | Network layer (new) | Not yet in Xcode project; would add `lastFixtures/nextFixtures/standings` |
| `Glance/Glance.xcodeproj/project.pbxproj` | Xcode project | File references need adding for new files |

### 2.2 Data Flow (Existing)

```
MadridPipeline
  ├─ ExaClient → search("Real Madrid fixture schedule") → regex parse → lastMatch + form
  ├─ ManagingMadridClient → /rss/index.xml → MMArticles
  └─ CacheStore → 24h TTL, key "cache_madrid"
```

**Problem:** Exa web-scraping is fragile; regex parsing of free-text results breaks when website formats change.

### 2.3 API-Football Limitations (Why Migrate)

| Constraint | Detail |
|------------|--------|
| Free tier `last` parameter | Not available |
| Free tier `next` parameter | Not available |
| Free tier seasons | Only 2022-2024 |
| Workaround | Fetch all fixtures, filter client-side |

---

## 3. Target API: API-Sports (thesportsdb.com)

### 3.1 Free Tier Details

| Property | Value |
|----------|-------|
| **API Key** | `123` (hardcoded, no auth header needed) |
| **Base URL** | `https://www.thesportsdb.com/api/v1/json/123/` |
| **Rate Limit** | Check https://www.thesportsdb.com/documentation#rate_limit |
| **Response Format** | JSON directly (no headers needed) |

### 3.2 Key Endpoints

| Endpoint | Purpose | Example |
|----------|---------|---------|
| `/searchteams.php?t=Real%20Madrid` | Find team ID by name | Returns team object with `id: "541"` |
| `/lookupteams.php?id=541` | Get team details by ID | Roster, stadium, basic info |
| `/fixtures.php?id=541` | Get all fixtures for team | Returns array; filter client-side |
| `/teams.php?id=541` | Get team standing/statistics | Position, W/D/L, goals |

### 3.3 Free Tier Limitations

- No `last`/`next` query parameters
- Must filter fixtures client-side by status
- Standings from `/teams.php` may be limited
- May need competition filtering for fixtures

---

## 4. Migration Scope

### 4.1 Files to Modify (Read-Only Plan — No Edits)

| File | Change Type | Impact |
|------|-------------|--------|
| `MadridModels.swift` | Add API-Sports types | New structs for team/fixture/standing responses |
| `MadridPipeline.swift` | Rewrite `refresh()` | Client-side filtering; new network calls |
| `GlanceCardView.swift` | Minor UI adjustments | Match data format from API-Sports |
| `MadridHubView.swift` | Minor UI adjustments | Match data format from API-Sports |
| `SportsDBClient.swift` | **New file** | Network layer for API-Sports |
| `Settings/SettingsStore.swift` | Remove `footballAPIKey` | Free tier needs no key |
| `Settings/SourcesView.swift` | Remove API-Football section | Replace with info or remove |
| `Xcode project.pbxproj` | Add new file references | Build system update |

### 4.2 Files That Stay Unchanged

- `Glance/Features/Madrid/MadridArticleView.swift` — RSS articles unchanged
- `Glance/Features/Madrid/ManagingMadridClient.swift` — RSS unchanged
- `Glance/Features/Pulse/PulseStore.swift` — card state machine unchanged
- `Glance/Features/Pulse/GlanceCardView.swift` — form/standing text rendering may need format adjustments
- `Glance/Features/MadrichFixtureParser.swift` — can be removed or kept as fallback

---

## 5. Detailed Design

### 5.1 New: `SportsDBClient.swift`

```swift
struct SportsDBClient: Sendable {
    // Free tier: key=123 is implicit, no header needed
    
    func searchTeam(name: String) async throws -> APISTeam?
    // GET /api/v1/json/123/searchteams.php?t=Real%20Madrid
    
    func getTeamDetail(id: String) async throws -> APISTeamDetail
    // GET /api/v1/json/123/lookupteams.php?id=541
    
    func getFixtures(teamID: String) async throws -> [APIFixture]
    // GET /api/v1/json/123/fixtures.php?id=541
    // Returns ALL fixtures; client filters by status
    
    func getTeamStanding(teamID: String) async throws -> APISStanding?
    // GET /api/v1/json/123/teams.php?id=541
}
```

**Key Design Decisions:**
- No `apiKey` parameter — free tier key `123` is implicit in URL path
- `getFixtures` returns ALL fixtures; client filters for last/next
- Rate limits likely more generous than API-Football's 100/day

### 5.2 Updated Models: `MadridModels.swift`

**New Types:**
```swift
struct APIDeTeam: Codable {
    let teams: [APISTeam]
}

struct APISTeam: Codable {
    let id: String
    let strTeam: String
    let strTeamBadge: String?
    let strStadium: String?
    let strStadiumCapacity: String?
}

struct APIFixture: Codable {
    let idFixture: String
    let strDate: String
    let strStatus: String       // "Match Finished", "Not Started", etc.
    let strHomeTeam: String
    let strAwayTeam: String
    let intHomeGoals: String?
    let intAwayGoals: String?
    let strCompetition: String
    let strLeague: String
}

struct APISStanding: Codable {
    let intRank: String?
    let intPosition: String?
    let intPoints: String?
    let intGoalsDiff: String?
    let intPlayedGames: String?
    let intWon: String?
    let intDraw: String?
    let intLost: String?
    let strGoalsFor: String?
    let strGoalsAgainst: String?
}
```

**Updated `MadridData`:**
- Keep existing properties
- `fixture`: `Fixture?` — now from API-Sports format
- `lastMatch`: `LastMatch?` — parsed from filtered fixtures
- `standing`: `StandingInfo?` — from `/teams.php` or derived
- `standingText`: `String` — formatted from standing data

### 5.3 Updated Pipeline: `MadridPipeline.swift`

**New `refresh()` Flow:**

```swift
func refresh(force: Bool = false) async -> MadridRefreshResult {
    // 1. Search for Real Madrid team
    let team = try? await sportsDBClient.searchTeam(name: "Real Madrid")
    guard let teamID = team?.id else { return await refreshWithExaFallback() }
    
    // 2. Fetch ALL fixtures for that team
    let allFixtures = try? await sportsDBClient.getFixtures(teamID: teamID)
    
    // 3. Client-side filtering
    let finishedFixtures = allFixtures?
        .filter { $0.strStatus.contains("Finished") }
        .prefix(5)
    
    let upcomingFixtures = allFixtures?
        .filter { $0.strStatus.contains("Not Started") }
    
    let nextFixture = upcomingFixtures?.first
    
    // 4. Fetch team details for standing
    let teamDetail = try? await sportsDBClient.getTeamDetail(id: teamID)
    let standing = extractStanding(from: teamDetail)
    
    // 5. Fetch Exa articles (unchanged)
    let exaArticles = await fetchExaArticles()
    let mmArticles = try? await madridClient.fetchArticles()
    
    // 5. Combine
    let data = MadridData(
        fixture: parseNext(from: nextFixture),
        lastMatch: parseLast(from: finishedFixtures),
        form: computeForm(from: finishedFixtures),
        standing: standing,
        standingText: formatStanding(standing),
        intel: generateIntel(...),
        articles: exaArticles,
        mmArticles: mmArticles,
        source: "api-sports",
        timestamp: Date.now
    )
    
    await cache.save("cache_madrid", ttlMs: 24 * 3_600_000)
    return .ready(data: data)
}
```

**Filtering Logic:**
```swift
// Finished: status contains "Finished" or "FT" or "AET" or "PEN"
let isFinished = { $0.strStatus.contains("Finished") || 
                   $0.strStatus == "FT" || 
                   $0.strStatus == "AET" || 
                   $0.strStatus == "PEN" }

// Not Started: status contains "Not Started" or "NS" or "TBD"
let isUpcoming = { $0.strStatus.contains("Not Started") || 
                   $0.strStatus == "NS" || 
                   $0.strStatus == "TBD" }
```

### 5.4 Settings Changes: Minimal

**What Changes:**
- `SettingsStore.footballAPIKey` becomes unused
- Can be removed or kept for future premium tier
- `SourcesView` API-Football section removed or repurposed

**What Stays:**
- `exaAPIKey` — still needed for Exa related articles
- `geminiAPIKey` — still needed
- `loadFromKeychain()`/`saveToKeychain()` — unchanged

**Optional:** Remove `footballAPIKey` entirely; add a note in Sources explaining API-Sports uses key `123` implicitly.

### 5.5 UI Impact

**Card (`GlanceCardView.swift`):**
- Same structure: next fixture / last match > form strip > standing > MM articles
- Data format changes: team names, badge URLs, standing text format
- May need `cachedAsyncImage` URL changes (different logo hosts)

**Hub (`MadridHubView.swift`):**
- Same 6-section structure
- Last Match Hero: score from `intHomeGoals`/`intAwayGoals` vs previous `scores.home`/`scores.away`
- Standing Card: position/W/D/L/GD/Points from API-Sports `/teams.php`
- Form strip: derived from `strForm` or client-filtered finished fixtures

**Visual Preserve:**
- Same card dimensions/colors
- Same interaction patterns
- Same navigation destinations

### 5.6 Data Flow Comparison

| Aspect | API-Football (Old) | API-Sports (New) |
|--------|-------------------|------------------|
| **Auth** | `x-apisports-key` header | Implicit `123` in URL |
| **Calls per refresh** | 3 (last+next+standings) | 3 (team+fixtures+teamDetail) |
| **Last 5 filtering** | API `last` param | Client-side status filter |
| **Next fixture** | API `next` param | Client-side status filter |
| **Standings** | `/standings?league=140&season=` | `/teams.php?id=541` |
| **Rate limit** | 100/day free tier | Likely more generous |
| **Response format** | Nested objects | Flat JSON, direct property access |

---

## 6. Migration Roadmap

### Phase 1: Exploration (1 day)
- [ ] Test API-Sports key `123` with:
  - `https://www.thesportsdb.com/api/v1/json/123/searchteams.php?t=Real%20Madrid`
  - `https://www.thesportsdb.com/api/v1/json/123/lookupteams.php?id=541`
  - `https://www.thesportsdb.com/api/v1/json/123/fixtures.php?id=541`
  - `https://www.thesportsdb.com/api/v1/json/123/teams.php?id=541`
- [ ] Document response formats for each endpoint
- [ ] Confirm client-side filtering logic works with real data

### Phase 2: Client Implementation (2 days)
- [ ] Create `SportsDBClient.swift` with 4 methods
- [ ] Add API-Sports model types to `MadridModels.swift`
- [ ] Rewrite `MadridPipeline.swift` `refresh()` with new flow
- [ ] Remove API-Football client dependency (or keep for fallback)

### Phase 3: UI Verification (1 day)
- [ ] Build and run on simulator
- [ ] Verify Last Match shows correct data
- [ ] Verify Next Match shows correct data (or "no upcoming")
- [ ] Verify Standing displays position/W/D/L/GD/Points
- [ ] Verify Form strip shows correct W/D/L
- [ ] Verify MM articles still load (Exa unchanged)
- [ ] Verify Related articles still load (Exa unchanged)

### Phase 4: Cleanup (1 day)
- [ ] Remove API-Football client if fully replaced
- [ ] Remove `footballAPIKey` from Settings UI
- [ ] Update spec document
- [ ] Run full test suite
- [ ] Fix any decoding/model mismatches

### Phase 5: Polish (Optional)
- [ ] Add error states ("No data available", "Refresh to try again")
- [ ] Add caching strategy tweaks if needed
- [ ] Consider premium tier upgrade path

---

## 7. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API-Sports response format differs from expected | Medium | Medium | Add debug logging; flexible `CodingKeys`; decode with `Any` first |
| Client-side filtering misses matches | Low | High | Test with full 38-match season; keep API-Football as fallback initially |
| Standing data unavailable from `/teams.php` | Medium | Medium | Derive from fixtures stats; show "data unavailable" gracefully |
| Free tier rate limits change | Low | High | Monitor; add fallback to API-Football if key obtained later |
| Exa/ManagingMadrid integrations break | None | None | Keep completely untouched; verify independently |
| Xcode project build fails | Medium | Moderate | Add file references carefully; build test after each change |

---

## 8. Success Criteria

- [ ] App builds successfully with new `SportsDBClient`
- [ ] Last 5 match results display correctly (from API-Sports client filtering)
- [ ] Next fixture displays correctly (or graceful "no upcoming" message)
- [ ] League standing displays position, played, W/D/L, GD, Points
- [ ] Form strip shows W/D/L with scores from last finished matches
- [ ] Managing Madrid articles still load (Exa unchanged)
- [ ] Related articles (Exa) still load
- [ ] App refresh works without crashes
- [ ] No API key prompts (free tier `123` works implicitly)
- [ ] No compile warnings or errors

---

## 9. User Decision Points

The user needs to confirm:

1. **API-Sports key validity**: Test the 4 endpoints with key `123` and share response formats
2. **Migration scope**: 
   - Full migration (replace API-Football entirely)
   - Hybrid (API-Sports primary, API-Football fallback)
   - Keep API-Football if key becomes available
3. **UI prioritization**: Any UI changes preferred over others?
4. **Test confirmation**: Should I verify the test suite passes after changes?

---

## 10. Next Steps

**Since I'm in read-only plan mode, the user needs to:**

1. **Test API-Sports endpoints** with key `123` and share the JSON responses
2. **Confirm migration approach** (full, hybrid, or keep API-Football)
3. **Provide go-ahead** to proceed with implementation phase

**Once confirmed, the implementation steps would be:**
1. Create `SportsDBClient.swift`
2. Update `MadridModels.swift` with API-Sports types
3. Rewrite `MadridPipeline.swift` 
4. Update Settings (remove footballAPIKey UI)
5. Update Xcode project references
6. Build and verify
7. Test on simulator

Would you like me to:
- Refine any section of this plan?
- Wait for your API-Sports exploration results?
- Proceed with a specific phase?
- Something else?