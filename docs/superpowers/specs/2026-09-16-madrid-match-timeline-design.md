# Madrid Match Timeline — Design Spec

## Problem

1. **Bug**: The `eventslast.php` endpoint in TheSportsDB free tier is stale — it doesn't reflect the most recent match (Elche 2-3 Real Madrid, Sep 15). The `eventsround.php` endpoint is up-to-date and should be used instead.

2. **Missing feature**: No timeline view of past and upcoming matches. Currently shows a single "Last Match Hero" and "Next Match Hero" separately.

## Goal

Replace the separate last match and next match hero sections with a connected vertical timeline showing **2 past finished matches** (with scores) and **3 upcoming fixtures** (scores hidden).

## Design

### Data Model

**New struct `MatchTimelineItem`** in `MadridModels.swift`:

```swift
struct MatchTimelineItem: Codable, Sendable, Equatable, Identifiable {
    let id: String          // event ID from API
    let opponent: String
    let opponentBadge: String?
    let rmBadge: String?
    let homeScore: Int?
    let awayScore: Int?
    let datetime: String
    let competition: String
    let venue: String
    let isFinished: Bool
    let result: String?     // "W", "D", "L" — nil for upcoming
    let round: String?
    let isHome: Bool        // whether RM is the home team
}
```

**Updated `MadridData`**:
- Remove: `lastMatch: LastMatch?`, `fixture: Fixture?`
- Add: `matchTimeline: [MatchTimelineItem]`
- Keep `LastMatch` and `Fixture` structs for backward compatibility with the glance card

### API Layer

**New method in `SportsDBClient`**:
```swift
func eventsRound(leagueID: String, round: String, season: String) async throws -> [SDBEvent]
```
Calls: `eventsround.php?l={leagueID}&r={round}&s={season}`

**Current round calculation** in `SportsDB`:
- La Liga season starts ~Aug 20
- Each round is ~1 week
- Round = `(daysSinceAug20 / 7) + 1`, clamped to valid range

### Pipeline Changes (`MadridPipeline.swift`)

In `refresh()`:
1. Fetch current round number
2. Fetch current round and previous round via `eventsRound()`
3. Filter for Real Madrid matches → take last 2 finished
4. Fetch `nextEvents` → take next 3 upcoming
5. Merge into `matchTimeline` array (sorted by date, past first)
6. Fall back to `eventslast` if round fetch fails

New static method: `parseMatchTimeline(lastEvents:nextEvents:teamID:)` that:
- Filters `lastEvents` for finished RM matches, takes last 2
- Filters `nextEvents` for upcoming RM matches, takes next 3
- Converts `SDBEvent` → `MatchTimelineItem`
- Sorts by datetime ascending

### Visual Design — Connected Timeline

**Layout**: Vertical stack with a connecting line and dots on the left side.

```
     ● ──── LAST MATCHES
     │
┌──────────────────────────────┐
│  [RM]   2 - 3   [Elche]    │
│  La Liga · R6 · Sep 15      │
│  Estadio Martínez Valero    │
│  ● W                         │
└──────────────────────────────┘
     │
     ●
     │
┌──────────────────────────────┐
│  [RM]   4 - 1   [Rayo]     │
│  La Liga · R5 · Sep 12      │
│  Santiago Bernabéu          │
│  ● W                         │
└──────────────────────────────┘
     │
     ● ──── UPCOMING
     │
┌──────────────────────────────┐
│  [RM]   vs   [Atlético]    │
│  La Liga · R7                │
│  Sep 20 · 16:15              │
│  Riyadh Air Metropolitano   │
│  ● In 4 days                 │
└──────────────────────────────┘
     │
     ●
     │
┌──────────────────────────────┐
│  [RM]   vs   [Team 2]      │
│  ...                         │
└──────────────────────────────┘
```

**Connector line**: 2pt width, `Theme.Colors.textMuted` at 0.3 opacity, runs vertically on the left side.

**Dots**: 8pt filled circles on the line. Color: green for W, amber for D, red for L, amber for upcoming.

**Match card**: Padded card with `Theme.Colors.surface1` background and rounded corners. Contains:
- Team badges (40pt each) with "vs" or score in between
- Competition + round + date
- Venue
- Result badge (W/D/L capsule) or countdown for upcoming

### Files Modified

| File | Change |
|---|---|
| `Glance/Core/Network/SportsDBClient.swift` | Add `eventsRound()` method |
| `Glance/Features/Madrid/MadridModels.swift` | Add `MatchTimelineItem`, update `MadridData` |
| `Glance/Features/Madrid/MadridPipeline.swift` | Add round fetching, `parseMatchTimeline()`, update `refresh()` |
| `Glance/Features/Madrid/MadridHubView.swift` | New `matchTimelineView()`, remove old hero sections |
| `Glance/Features/Pulse/GlanceCardView.swift` | Minimal — keep using `fixture`/`lastMatch` from timeline data |
| `GlanceTests/MadridPipelineTests.swift` | Add timeline parsing tests |

### Testing

- Unit test `parseMatchTimeline()` with mock events
- Verify Elche 2-3 is picked from round data (not stale `eventslast`)
- Verify upcoming matches don't show scores
- Snapshot tests for timeline view (if available)
