# Madrid Match Timeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the stale last-match bug by using `eventsround.php` instead of `eventslast.php`, and add a connected vertical timeline showing 2 past matches (with scores) and 3 upcoming fixtures (scores hidden).

**Architecture:** Add a new `eventsRound()` API method, introduce `MatchTimelineItem` model, update `MadridPipeline` to fetch round-based data, and replace the hero sections in `MadridHubView` with a connected vertical timeline component.

**Tech Stack:** Swift, SwiftUI, TheSportsDB free API (key "123")

**Spec:** `docs/superpowers/specs/2026-09-16-madrid-match-timeline-design.md`

## Global Constraints

- TheSportsDB free tier key "123" is embedded in URL paths (no auth headers)
- Rate limit: sequential calls with 600ms delays between API requests
- La Liga league ID: `4335`, Real Madrid team ID: `133738`
- Season format: `"2026-2027"` (rolls over in July)
- Existing code uses `Theme.Colors`, `Theme.Fonts.manrope()`, `Theme.cardPadding`, `Theme.cornerRadius`

---

### Task 1: Add `eventsRound()` to SportsDBClient

**Files:**
- Modify: `Glance/Core/Network/SportsDBClient.swift:136-175`

**Interfaces:**
- Produces: `func eventsRound(leagueID: String, round: String, season: String) async throws -> [SDBEvent]`

- [ ] **Step 1: Add the new API method to SportsDBClientProtocol**

In `Glance/Core/Network/SportsDBClient.swift`, add to the protocol at line 141:

```swift
protocol SportsDBClientProtocol: Sendable {
    func searchTeam(name: String) async throws -> SDBTeam?
    func lastEvents(teamID: String) async throws -> [SDBEvent]
    func nextEvents(teamID: String) async throws -> [SDBEvent]
    func leagueTable(leagueID: String, season: String) async throws -> [SDBStanding]
    func eventsRound(leagueID: String, round: String, season: String) async throws -> [SDBEvent]
}
```

- [ ] **Step 2: Implement `eventsRound()` in SportsDBClient**

After the `leagueTable` method (around line 175), add:

```swift
func eventsRound(leagueID: String, round: String, season: String) async throws -> [SDBEvent] {
    var components = URLComponents(string: "\(SportsDB.baseURL)/eventsround.php")!
    components.queryItems = [
        URLQueryItem(name: "l", value: leagueID),
        URLQueryItem(name: "r", value: round),
        URLQueryItem(name: "s", value: season)
    ]
    let response: SDBEventsResponse = try await get(url: components.url!, label: "eventsround")
    return response.events ?? []
}
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Core/Network/SportsDBClient.swift
git commit -m "feat: add eventsRound() API method to SportsDBClient"
```

---

### Task 2: Add MatchTimelineItem model

**Files:**
- Modify: `Glance/Features/Madrid/MadridModels.swift`

**Interfaces:**
- Produces: `MatchTimelineItem` struct with all required fields
- Produces: Updated `MadridData` with `matchTimeline: [MatchTimelineItem]`

- [ ] **Step 1: Add MatchTimelineItem struct**

At the end of `Glance/Features/Madrid/MadridModels.swift` (before the closing of the file), add:

```swift
struct MatchTimelineItem: Codable, Sendable, Equatable, Identifiable {
    let id: String
    let opponent: String
    let opponentBadge: String?
    let rmBadge: String?
    let homeScore: Int?
    let awayScore: Int?
    let datetime: String
    let competition: String
    let venue: String
    let isFinished: Bool
    let result: String? // "W", "D", "L"
    let round: String?
    let isHome: Bool
}
```

- [ ] **Step 2: Update MadridData to include matchTimeline**

In `MadridModels.swift`, update the `MadridData` struct to add the new property. Keep `lastMatch` and `fixture` for backward compatibility with the glance card:

```swift
struct MadridData: Codable, Sendable, Equatable {
    let fixture: Fixture?
    let lastMatch: LastMatch?
    let matchTimeline: [MatchTimelineItem]
    let schedule: [ScheduleItem]
    let form: [String]
    let standing: StandingInfo?
    let standingText: String
    let intel: String
    let headToHead: String?
    let articles: [ExaArticle]
    let mmArticles: [MMArticle]
    let source: String
    let timestamp: Date
}
```

- [ ] **Step 3: Fix all MadridData initializer call sites**

Search for all places that create `MadridData` and add `matchTimeline: []` as a default. These are in:
- `Glance/Features/Madrid/MadridPipeline.swift` (in `refresh()` around line 70)
- `Glance/Features/Madrid/MadridPipeline.swift` (in `refreshWithExaFallback()` around line 136)

In each, add `matchTimeline: [],` after `lastMatch:`:

```swift
let data = MadridData(
    fixture: nextFixture,
    lastMatch: lastMatch,
    matchTimeline: [],
    schedule: [],
    // ... rest unchanged
)
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Glance/Features/Madrid/MadridModels.swift Glance/Features/Madrid/MadridPipeline.swift
git commit -m "feat: add MatchTimelineItem model and update MadridData"
```

---

### Task 3: Add current round calculation to SportsDB

**Files:**
- Modify: `Glance/Core/Network/SportsDBClient.swift:5-20`

**Interfaces:**
- Produces: `SportsDB.currentRound(date:)` static method returning `Int`

- [ ] **Step 1: Add currentRound() to SportsDB enum**

In `Glance/Core/Network/SportsDBClient.swift`, add after the `currentSeason()` method (around line 19):

```swift
/// Current La Liga round number. Season starts ~Aug 20, one round per week.
static func currentRound(date: Date = Date.now) -> Int {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    let startYear = month >= 7 ? year : year - 1
    // La Liga typically starts last week of August
    let seasonStart = calendar.date(from: DateComponents(year: startYear, month: 8, day: 20)) ?? date
    let days = calendar.dateComponents([.day], from: seasonStart, to: date).day ?? 0
    let round = (days / 7) + 1
    return max(1, min(round, 38)) // La Liga has 38 rounds
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Core/Network/SportsDBClient.swift
git commit -m "feat: add currentRound() calculation to SportsDB"
```

---

### Task 4: Add parseMatchTimeline to MadridPipeline

**Files:**
- Modify: `Glance/Features/Madrid/MadridPipeline.swift`

**Interfaces:**
- Consumes: `SDBEvent` array from API
- Produces: `[MatchTimelineItem]` sorted by date

- [ ] **Step 1: Add parseMatchTimeline static method**

In `Glance/Features/Madrid/MadridPipeline.swift`, add after the `parseNextFixture` method (around line 233):

```swift
static func parseMatchTimeline(
    recentEvents: [SDBEvent],
    nextEvents: [SDBEvent],
    teamID: String
) -> [MatchTimelineItem] {
    var items: [MatchTimelineItem] = []

    // Last 2 finished matches (from recentEvents, most recent first)
    let finished = recentEvents.filter { $0.isFinished }.prefix(2)
    for event in finished {
        guard let item = timelineItem(from: event, teamID: teamID) else { continue }
        items.append(item)
    }

    // Next 3 upcoming matches (from nextEvents)
    let upcoming = nextEvents.filter { $0.isNotStarted || $0.strStatus == "NS" }.prefix(3)
    for event in upcoming {
        guard let item = timelineItem(from: event, teamID: teamID) else { continue }
        items.append(item)
    }

    return items
}

private static func timelineItem(from event: SDBEvent, teamID: String) -> MatchTimelineItem? {
    let isHome = event.idHomeTeam == teamID
    let opponent = isHome ? event.strAwayTeam : event.strHomeTeam
    let badges = Self.badges(for: event)
    let datetime = event.strTimestamp
        ?? (event.dateEvent.map { "\($0)T\(event.strTime ?? "00:00:00")" })
        ?? event.dateEvent
        ?? ""

    let homeScore = event.intHomeScore
    let awayScore = event.intAwayScore
    let isFinished = event.isFinished

    var result: String? = nil
    if isFinished, let h = homeScore, let a = awayScore {
        let rmGoals = isHome ? h : a
        let oppGoals = isHome ? a : h
        if rmGoals > oppGoals { result = "W" }
        else if rmGoals == oppGoals { result = "D" }
        else { result = "L" }
    }

    return MatchTimelineItem(
        id: event.idEvent,
        opponent: opponent,
        opponentBadge: badges.opponent,
        rmBadge: badges.rm,
        homeScore: homeScore,
        awayScore: awayScore,
        datetime: datetime,
        competition: event.strLeague,
        venue: event.strVenue ?? "",
        isFinished: isFinished,
        result: result,
        round: event.intRound.map { "R\($0)" },
        isHome: isHome
    )
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Madrid/MadridPipeline.swift
git commit -m "feat: add parseMatchTimeline() to MadridPipeline"
```

---

### Task 5: Update pipeline refresh to use eventsround

**Files:**
- Modify: `Glance/Features/Madrid/MadridPipeline.swift:36-91`

**Interfaces:**
- Consumes: `eventsRound()` from Task 1, `parseMatchTimeline()` from Task 4
- Produces: Updated `MadridData` with populated `matchTimeline`

- [ ] **Step 1: Update refresh() to fetch round data and build timeline**

Replace the refresh method body in `MadridPipeline.swift`. The key change is fetching current + previous round for recent matches, and using `eventsnext` for upcoming:

```swift
func refresh(settings: SettingsStore, force: Bool = false) async -> MadridRefreshResult {
    let rssURL = await settings.madridRSSURL
    let teamID = await settings.madridTeamID
    let leagueID = await settings.madridLeagueID

    do {
        // 1. Fetch next events (upcoming fixtures) — this API is reliable
        let nextEvents = try await sportsDB.nextEvents(teamID: teamID)

        try? await Task.sleep(for: .milliseconds(600))

        // 2. Fetch round data for recent matches (more up-to-date than eventslast)
        let currentRound = SportsDB.currentRound()
        var recentEvents: [SDBEvent] = []

        // Fetch current round and previous round to get last 2 finished matches
        for round in [currentRound, currentRound - 1].sorted() {
            guard round >= 1 else { continue }
            if let roundEvents = try? await sportsDB.eventsRound(
                leagueID: leagueID,
                round: String(round),
                season: SportsDB.currentSeason()
            ) {
                recentEvents.append(contentsOf: roundEvents)
            }
            try? await Task.sleep(for: .milliseconds(600))
        }

        // 3. Fallback: if round data didn't yield finished matches, try eventslast
        if recentEvents.filter({ $0.isFinished }).isEmpty {
            if let lastEvents = try? await sportsDB.lastEvents(teamID: teamID) {
                recentEvents = lastEvents
            }
        }

        try? await Task.sleep(for: .milliseconds(600))

        // 4. Fetch league table
        let table = try await sportsDB.leagueTable(
            leagueID: leagueID, season: SportsDB.currentSeason()
        )

        // 5. Derive data
        let matchTimeline = Self.parseMatchTimeline(
            recentEvents: recentEvents,
            nextEvents: nextEvents,
            teamID: teamID
        )

        // Keep backward-compat fields from timeline
        let lastMatch = matchTimeline.first(where: { $0.isFinished }).flatMap { Self.convertToLastMatch($0) }
        let nextFixture = matchTimeline.first(where: { !$0.isFinished }).flatMap { Self.convertToFixture($0) }

        let form = Self.parseForm(from: recentEvents.filter { $0.isFinished })
        let standing = Self.parseStanding(from: table, teamID: teamID)

        let exaArticles = await fetchExaArticles()
        let mmArticles = (try? await madridClient.fetchArticles(rssURL: rssURL)) ?? []

        let data = MadridData(
            fixture: nextFixture,
            lastMatch: lastMatch,
            matchTimeline: matchTimeline,
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

- [ ] **Step 2: Add backward-compat conversion helpers**

After the `parseMatchTimeline` method, add:

```swift
/// Convert MatchTimelineItem to LastMatch for backward compatibility with glance card
static func convertToLastMatch(_ item: MatchTimelineItem) -> LastMatch? {
    guard item.isFinished, let h = item.homeScore, let a = item.awayScore else { return nil }
    return LastMatch(
        opponent: item.opponent,
        score: LastMatch.LastMatchScore(home: h, away: a),
        competition: item.competition,
        venue: item.venue,
        datetime: item.datetime,
        status: "FT",
        scorers: [],
        cards: [],
        round: item.round,
        rmBadge: item.rmBadge,
        opponentBadge: item.opponentBadge
    )
}

/// Convert MatchTimelineItem to Fixture for backward compatibility with glance card
static func convertToFixture(_ item: MatchTimelineItem) -> Fixture? {
    let score: Fixture.Score?
    if let h = item.homeScore, let a = item.awayScore {
        score = Fixture.Score(home: h, away: a)
    } else {
        score = nil
    }
    return Fixture(
        opponent: item.opponent,
        datetime: item.datetime,
        stadium: item.venue,
        competition: item.competition,
        venue: item.venue,
        scores: score,
        rmBadge: item.rmBadge,
        opponentBadge: item.opponentBadge
    )
}
```

- [ ] **Step 3: Update refreshWithExaFallback to include matchTimeline**

In the `refreshWithExaFallback` method, update both `MadridData` initializations to include `matchTimeline: []`:

```swift
let data = MadridData(
    fixture: parsed.fixture,
    lastMatch: nil,
    matchTimeline: [],
    schedule: parsed.schedule,
    // ... rest unchanged
)
```

And the degraded case:
```swift
return .degraded(
    data: MadridData(
        fixture: nil, lastMatch: nil, matchTimeline: [], schedule: [], form: [],
        // ... rest unchanged
    ),
    reason: "No results"
)
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Glance/Features/Madrid/MadridPipeline.swift
git commit -m "feat: update pipeline to use eventsround for last match data"
```

---

### Task 6: Build MatchTimelineView

**Files:**
- Create: `Glance/Features/Madrid/MatchTimelineView.swift`

**Interfaces:**
- Consumes: `[MatchTimelineItem]`
- Produces: SwiftUI View

- [ ] **Step 1: Create the MatchTimelineView file**

Create `Glance/Features/Madrid/MatchTimelineView.swift`:

```swift
import SwiftUI

struct MatchTimelineView: View {
    let items: [MatchTimelineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            Text("MATCH TIMELINE")
                .font(Theme.Fonts.manrope(10, weight: .bold))
                .foregroundStyle(Theme.Colors.cardAmber)
                .tracking(1.2)
                .padding(.bottom, 16)

            // Timeline
            HStack(alignment: .top, spacing: 16) {
                // Connector line + dots
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        // Dot
                        Circle()
                            .fill(dotColor(for: item))
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .fill(Theme.Colors.surface1)
                                    .frame(width: 6, height: 6)
                            )

                        // Line (except after last item)
                        if index < items.count - 1 {
                            Rectangle()
                                .fill(Theme.Colors.textMuted.opacity(0.3))
                                .frame(width: 2)
                                .frame(minHeight: 80)
                        }
                    }
                }

                // Match cards
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        matchCard(item)
                            .padding(.bottom, index < items.count - 1 ? 16 : 0)
                    }
                }
            }
        }
    }

    // MARK: - Match Card

    private func matchCard(_ item: MatchTimelineItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Teams row
            HStack(alignment: .center, spacing: 12) {
                // Real Madrid
                VStack(spacing: 4) {
                    teamBadge(url: item.rmBadge, fallback: "RM", size: 40)
                    Text("Real Madrid")
                        .font(Theme.Fonts.manrope(9))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                // Score or vs
                if item.isFinished, let h = item.homeScore, let a = item.awayScore {
                    VStack(spacing: 2) {
                        Text("\(h) - \(a)")
                            .font(Theme.Fonts.manrope(20, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                } else {
                    Text("vs")
                        .font(Theme.Fonts.manrope(14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                // Opponent
                VStack(spacing: 4) {
                    teamBadge(url: item.opponentBadge, fallback: String(item.opponent.prefix(3)).uppercased(), size: 40)
                    Text(item.opponent)
                        .font(Theme.Fonts.manrope(9))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // Info row
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.competition)
                    if let round = item.round {
                        Text("·")
                        Text(round)
                    }
                }
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)

                if let date = MadridPipeline.looseDateParse(item.datetime) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        Text(TimeFormat.istDate(date))
                    }
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                }

                if !item.venue.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns")
                        Text(item.venue)
                    }
                    .font(Theme.Fonts.manrope(11))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
                }
            }

            // Result badge or countdown
            if item.isFinished, let result = item.result {
                resultBadge(result)
            } else if let date = MadridPipeline.looseDateParse(item.datetime) {
                let countdown = TimeFormat.countdownTo(date)
                if !countdown.isEmpty {
                    Text(countdown)
                        .font(Theme.Fonts.manrope(11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.cardAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.cardAmber.opacity(0.15), in: .capsule)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func teamBadge(url: String?, fallback: String, size: CGFloat) -> some View {
        Group {
            if let urlString = url, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(fallback)
                        .font(Theme.Fonts.manrope(14, weight: .bold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            } else {
                Text(fallback)
                    .font(Theme.Fonts.manrope(14, weight: .bold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(width: size, height: size)
                    .background(Theme.Colors.surface2, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: size, height: size)
    }

    private func resultBadge(_ result: String) -> some View {
        Text(result)
            .font(Theme.Fonts.manrope(11, weight: .bold))
            .foregroundStyle(resultColor(result))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(resultColor(result).opacity(0.15), in: .capsule)
    }

    private func resultColor(_ result: String) -> Color {
        switch result {
        case "W": return Theme.Colors.success
        case "D": return Theme.Colors.warning
        case "L": return Theme.Colors.error
        default: return Theme.Colors.textMuted
        }
    }

    private func dotColor(for item: MatchTimelineItem) -> Color {
        if item.isFinished {
            switch item.result {
            case "W": return Theme.Colors.success
            case "D": return Theme.Colors.warning
            case "L": return Theme.Colors.error
            default: return Theme.Colors.textMuted
            }
        }
        return Theme.Colors.cardAmber
    }
}

#Preview {
    MatchTimelineView(items: [
        MatchTimelineItem(
            id: "1", opponent: "Elche", opponentBadge: nil, rmBadge: nil,
            homeScore: 2, awayScore: 3, datetime: "2026-09-15T19:30:00Z",
            competition: "La Liga", venue: "Estadio Martínez Valero",
            isFinished: true, result: "W", round: "R6", isHome: false
        ),
        MatchTimelineItem(
            id: "2", opponent: "Rayo Vallecano", opponentBadge: nil, rmBadge: nil,
            homeScore: 4, awayScore: 1, datetime: "2026-09-12T19:00:00Z",
            competition: "La Liga", venue: "Santiago Bernabéu",
            isFinished: true, result: "W", round: "R5", isHome: true
        ),
        MatchTimelineItem(
            id: "3", opponent: "Atlético Madrid", opponentBadge: nil, rmBadge: nil,
            homeScore: nil, awayScore: nil, datetime: "2026-09-20T14:15:00Z",
            competition: "La Liga", venue: "Riyadh Air Metropolitano",
            isFinished: false, result: nil, round: "R7", isHome: false
        ),
    ])
    .padding()
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Madrid/MatchTimelineView.swift
git commit -m "feat: add MatchTimelineView vertical timeline component"
```

---

### Task 7: Integrate timeline into MadridHubView

**Files:**
- Modify: `Glance/Features/Madrid/MadridHubView.swift:116-148`

**Interfaces:**
- Consumes: `MatchTimelineView` from Task 6, `matchTimeline` from `MadridData`

- [ ] **Step 1: Replace madridSections to use timeline**

In `MadridHubView.swift`, replace the `madridSections` method:

```swift
private func madridSections(_ data: MadridData) -> some View {
    VStack(alignment: .leading, spacing: 20) {
        // 1. Match Timeline (replaces lastMatchHero + nextMatchHero)
        if !data.matchTimeline.isEmpty {
            MatchTimelineView(items: data.matchTimeline)
        }

        // 2. Form strip
        if !data.form.isEmpty {
            formSection(data)
        }

        // 3. Standing card
        if let standing = data.standing {
            standingCard(standing)
        }

        // 4. Managing Madrid articles
        if !data.mmArticles.isEmpty {
            mmArticlesSection(data.mmArticles)
        }

        // 5. Related articles (Exa)
        if !data.articles.isEmpty {
            exaArticlesSection(data.articles)
        }
    }
}
```

- [ ] **Step 2: Remove the old lastMatchHero and nextMatchHero methods**

Delete the `lastMatchHero(_:)` method (lines 152-282) and the `nextMatchHero(_:)` method (lines 286-383) from `MadridHubView.swift`. These are replaced by `MatchTimelineView`.

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Features/Madrid/MadridHubView.swift
git commit -m "feat: integrate MatchTimelineView into MadridHubView"
```

---

### Task 8: Add unit tests for timeline parsing

**Files:**
- Modify: `Glance/Core/Network/SportsDBClient.swift` (add memberwise init to SDBEvent)
- Modify: `GlanceTests/MadridPipelineTests.swift`

**Interfaces:**
- Consumes: `parseMatchTimeline()` from Task 4

- [ ] **Step 1: Add memberwise initializer to SDBEvent for testing**

In `Glance/Core/Network/SportsDBClient.swift`, add after the `flexibleInt` method (around line 80):

```swift
/// Memberwise initializer for testing
init(
    idEvent: String, strEvent: String, strLeague: String,
    strSeason: String?, strTimestamp: String?,
    dateEvent: String?, strTime: String?,
    strHomeTeam: String, strAwayTeam: String,
    idHomeTeam: String?, idAwayTeam: String?,
    strVenue: String?, intRound: String?,
    strStatus: String?, intHomeScore: Int?, intAwayScore: Int?,
    strHomeTeamBadge: String?, strAwayTeamBadge: String?,
    strPostponed: String?
) {
    self.idEvent = idEvent
    self.strEvent = strEvent
    self.strLeague = strLeague
    self.strSeason = strSeason
    self.strTimestamp = strTimestamp
    self.dateEvent = dateEvent
    self.strTime = strTime
    self.strHomeTeam = strHomeTeam
    self.strAwayTeam = strAwayTeam
    self.idHomeTeam = idHomeTeam
    self.idAwayTeam = idAwayTeam
    self.strVenue = strVenue
    self.intRound = intRound
    self.strStatus = strStatus
    self.intHomeScore = intHomeScore
    self.intAwayScore = intAwayScore
    self.strHomeTeamBadge = strHomeTeamBadge
    self.strAwayTeamBadge = strAwayTeamBadge
    self.strPostponed = strPostponed
}
```

- [ ] **Step 2: Add test for parseMatchTimeline**

In `GlanceTests/MadridPipelineTests.swift`, add:

```swift
@Test("parseMatchTimeline returns last 2 finished and next 3 upcoming")
func parseMatchTimeline_basic() {
    let teamID = "133738"

    let finished1 = SDBEvent(
        idEvent: "1", strEvent: "Elche vs Real Madrid", strLeague: "La Liga",
        strSeason: "2026-2027", strTimestamp: "2026-09-15T19:30:00Z",
        dateEvent: "2026-09-15", strTime: "19:30:00",
        strHomeTeam: "Elche", strAwayTeam: "Real Madrid",
        idHomeTeam: "134384", idAwayTeam: "133738",
        strVenue: "Estadio Martínez Valero", intRound: "6",
        strStatus: "FT", intHomeScore: 2, intAwayScore: 3,
        strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
    )

    let finished2 = SDBEvent(
        idEvent: "2", strEvent: "Real Madrid vs Rayo Vallecano", strLeague: "La Liga",
        strSeason: "2026-2027", strTimestamp: "2026-09-12T19:00:00Z",
        dateEvent: "2026-09-12", strTime: "19:00:00",
        strHomeTeam: "Real Madrid", strAwayTeam: "Rayo Vallecano",
        idHomeTeam: "133738", idAwayTeam: "133728",
        strVenue: "Santiago Bernabéu", intRound: "5",
        strStatus: "FT", intHomeScore: 4, intAwayScore: 1,
        strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
    )

    let upcoming1 = SDBEvent(
        idEvent: "3", strEvent: "Atlético Madrid vs Real Madrid", strLeague: "La Liga",
        strSeason: "2026-2027", strTimestamp: "2026-09-20T14:15:00Z",
        dateEvent: "2026-09-20", strTime: "14:15:00",
        strHomeTeam: "Atlético Madrid", strAwayTeam: "Real Madrid",
        idHomeTeam: "133729", idAwayTeam: "133738",
        strVenue: "Riyadh Air Metropolitano", intRound: "7",
        strStatus: "NS", intHomeScore: nil, intAwayScore: nil,
        strHomeTeamBadge: nil, strAwayTeamBadge: nil, strPostponed: "no"
    )

    let recentEvents = [finished1, finished2]
    let nextEvents = [upcoming1]

    let timeline = MadridPipeline.parseMatchTimeline(
        recentEvents: recentEvents,
        nextEvents: nextEvents,
        teamID: teamID
    )

    #expect(timeline.count == 3)
    #expect(timeline[0].opponent == "Elche")
    #expect(timeline[0].isFinished == true)
    #expect(timeline[0].result == "W")
    #expect(timeline[0].homeScore == 2)
    #expect(timeline[0].awayScore == 3)
    #expect(timeline[0].isHome == false)

    #expect(timeline[1].opponent == "Rayo Vallecano")
    #expect(timeline[1].isFinished == true)
    #expect(timeline[1].result == "W")
    #expect(timeline[1].isHome == true)

    #expect(timeline[2].opponent == "Atlético Madrid")
    #expect(timeline[2].isFinished == false)
    #expect(timeline[2].result == nil)
    #expect(timeline[2].homeScore == nil)
    #expect(timeline[2].isHome == false)
}

@Test("parseMatchTimeline handles empty events")
func parseMatchTimeline_empty() {
    let timeline = MadridPipeline.parseMatchTimeline(
        recentEvents: [],
        nextEvents: [],
        teamID: "133738"
    )
    #expect(timeline.isEmpty)
}
```

- [ ] **Step 3: Run the tests**

Run: `xcodebuild test -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:GlanceTests 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add Glance/Core/Network/SportsDBClient.swift GlanceTests/MadridPipelineTests.swift
git commit -m "test: add unit tests for parseMatchTimeline"
```

---

### Task 9: Update hub hero section to use timeline data

**Files:**
- Modify: `Glance/Features/Madrid/MadridHubView.swift:8-82`

**Interfaces:**
- Consumes: `matchTimeline` from `MadridData`

- [ ] **Step 1: Update hero section to pull from timeline**

In `MadridHubView.swift`, the hero section (lines 8-82) currently references `heroData.fixture` and `heroData.lastMatch`. Update it to pull from `matchTimeline` if the old fields are nil:

```swift
// Hero section
let heroData: MadridData? = {
    if case .ready(let data, _) = store.madrid { return data }
    if case .stale(let data, _) = store.madrid { return data }
    return nil
}()
if let heroData {
    ZStack(alignment: .topLeading) {
        LinearGradient(
            colors: [Theme.Colors.cardAmber.opacity(0.3), Theme.Colors.canvas],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))

        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("REAL MADRID")
                    .font(Theme.Fonts.scale(.title1))
                    .foregroundStyle(Theme.Colors.cardAmber)

                if let standing = heroData.standing {
                    Text(standing.badge != nil ? "La Liga" : "")
                        .font(Theme.Fonts.scale(.callout))
                        .foregroundStyle(Theme.Colors.textMuted)
                }

                // Show next match score from timeline if available
                if let nextMatch = heroData.matchTimeline.first(where: { !$0.isFinished }),
                   let h = nextMatch.homeScore, let a = nextMatch.awayScore {
                    Text("\(h) - \(a)")
                        .font(Theme.Fonts.scale(.display))
                        .foregroundStyle(Theme.Colors.textPrimary)
                } else if let fixture = heroData.fixture,
                          let scores = fixture.scores {
                    Text("\(scores.home) - \(scores.away)")
                        .font(Theme.Fonts.scale(.display))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                if let standing = heroData.standing {
                    HStack(spacing: 16) {
                        statItem(label: "PTS", value: "\(standing.points)")
                        statItem(label: "W", value: "\(standing.won)")
                        statItem(label: "L", value: "\(standing.lost)")
                    }
                }
            }

            Spacer()

            VStack(spacing: 8) {
                let badgeURLString = heroData.matchTimeline.first?.rmBadge ?? heroData.fixture?.rmBadge ?? heroData.lastMatch?.rmBadge ?? "https://upload.wikimedia.org/wikipedia/en/5/56/Real_Madrid_CF.svg"
                if let url = URL(string: badgeURLString) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Text("RM")
                            .font(Theme.Fonts.manrope(24, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                    }
                    .frame(width: 100, height: 100)
                }

                if let standing = heroData.standing,
                   let badgeURL = standing.badge, let url = URL(string: badgeURL) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        EmptyView()
                    }
                    .frame(width: 36, height: 36)
                }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, Theme.cardPadding)
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Madrid/MadridHubView.swift
git commit -m "feat: update hero section to use timeline data"
```

---

### Task 10: Full build and test verification

- [ ] **Step 1: Clean build**

Run: `xcodebuild clean build -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 2: Run all tests**

Run: `xcodebuild test -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 3: Final commit with all changes**

```bash
git add -A
git commit -m "feat: Madrid match timeline with eventsround API fix

- Fix stale last match bug by using eventsround.php instead of eventslast.php
- Add MatchTimelineItem model and parseMatchTimeline() parser
- Add MatchTimelineView vertical connected timeline component
- Show last 2 finished matches with scores and next 3 upcoming fixtures
- Replace separate lastMatchHero and nextMatchHero sections
- Add unit tests for timeline parsing"
```
