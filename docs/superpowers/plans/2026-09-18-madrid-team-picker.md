# Madrid Team Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hardcoded team/league ID text fields with a single dropdown picker of the top 20 Champions League teams, storing the team ID locally for easy configuration.

**Architecture:** Static lookup data in a new `FootballData.swift` file. `SettingsStore` gains a `madridSelectedTeamIndex` property that auto-syncs `madridTeamID` and `madridLeagueID`. `ProviderView` replaces two text fields with one `Picker`. `MadridPipeline` internal parsing helpers accept `teamID` parameter instead of using hardcoded `SportsDB.realMadridID`.

**Tech Stack:** Swift 5.9+, SwiftUI, thesportsdb.com free API

**Spec:** docs/superpowers/specs/2026-09-11-api-football-madrid-design.md

## Global Constraints

- Swift 5.9+ with strict concurrency (`Sendable`, actors)
- `@Observable` macro for view models and stores
- `@Environment(AppState.self)` for dependency injection
- All styling through `Theme` enum
- No storyboards — entirely SwiftUI
- API keys stored in Keychain via `KeychainStore`

---

### Task 1: Create FootballData.swift with static team lookup

**Files:**
- Create: `Glance/Features/Madrid/FootballData.swift`

**Interfaces:**
- Produces: `FootballTeam` struct, `topChampionsLeagueTeams` array, helper functions `teamByID()` and `teamIndexByID()`

- [ ] **Step 1: Write FootballData.swift**

```swift
import Foundation

struct FootballTeam: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let leagueID: String
    let leagueName: String
    let country: String
}

enum FootballData {
    static let topChampionsLeagueTeams: [FootballTeam] = [
        FootballTeam(id: "133738", name: "Real Madrid", leagueID: "4335", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "133739", name: "Barcelona", leagueID: "4335", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "133729", name: "Atletico Madrid", leagueID: "4335", leagueName: "La Liga", country: "Spain"),
        FootballTeam(id: "133613", name: "Manchester City", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133602", name: "Liverpool", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133604", name: "Arsenal", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133616", name: "Tottenham Hotspur", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133612", name: "Manchester United", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133610", name: "Chelsea", leagueID: "4328", leagueName: "Premier League", country: "England"),
        FootballTeam(id: "133664", name: "Bayern Munich", leagueID: "4331", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "133650", name: "Borussia Dortmund", leagueID: "4331", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "133666", name: "Bayer Leverkusen", leagueID: "4331", leagueName: "Bundesliga", country: "Germany"),
        FootballTeam(id: "133681", name: "Inter Milan", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133676", name: "Juventus", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133667", name: "AC Milan", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133670", name: "Napoli", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "134782", name: "Atalanta", leagueID: "4332", leagueName: "Serie A", country: "Italy"),
        FootballTeam(id: "133714", name: "Paris Saint-Germain", leagueID: "4334", leagueName: "Ligue 1", country: "France"),
        FootballTeam(id: "133707", name: "Marseille", leagueID: "4334", leagueName: "Ligue 1", country: "France"),
        FootballTeam(id: "134108", name: "Benfica", leagueID: "4344", leagueName: "Primeira Liga", country: "Portugal"),
    ]

    static func team(byID id: String) -> FootballTeam? {
        topChampionsLeagueTeams.first { $0.id == id }
    }

    static func teamIndex(byID id: String) -> Int? {
        topChampionsLeagueTeams.firstIndex { $0.id == id }
    }
}
```

- [ ] **Step 2: Verify file compiles**

Run: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20`
Expected: Build succeeds (or only unrelated errors)

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Madrid/FootballData.swift
git commit -m "feat: add FootballData static lookup for top Champions League teams"
```

---

### Task 2: Add madridSelectedTeamIndex to SettingsStore

**Files:**
- Modify: `Glance/Settings/SettingsStore.swift`

**Interfaces:**
- Consumes: `FootballData.topChampionsLeagueTeams`
- Produces: `madridSelectedTeamIndex` property that syncs with `madridTeamID`

- [ ] **Step 1: Add madridSelectedTeamIndex to SettingsStore**

Insert after `madridLeagueID` (line 50):

```swift
    var madridSelectedTeamIndex: Int {
        get { defaults.integer(forKey: "madrid_selected_team_index") }
        set { defaults.set(newValue, forKey: "madrid_selected_team_index") }
    }

    var madridSelectedTeam: FootballTeam {
        get {
            let index = madridSelectedTeamIndex
            guard index < FootballData.topChampionsLeagueTeams.count else {
                return FootballData.topChampionsLeagueTeams[0]
            }
            return FootballData.topChampionsLeagueTeams[index]
        }
        set {
            madridSelectedTeamIndex = newValue.id
            madridTeamID = newValue.id
            madridLeagueID = newValue.leagueID
        }
    }
```

Wait — `UserDefaults` stores `Int` for `madridSelectedTeamIndex`, but we need to store the team ID to survive app updates if the array order changes. Let me reconsider: store the team ID string instead, and compute the index from it. This is more robust.

Revised approach — store `madridTeamID` string (already exists), and compute the index from `FootballData.teamIndex(byID:)`. No new UserDefaults key needed.

Update `madridSelectedTeam` to read from `madridTeamID`:

```swift
    var madridSelectedTeam: FootballTeam {
        get {
            FootballData.team(byID: madridTeamID) ?? FootballData.topChampionsLeagueTeams[0]
        }
        set {
            madridTeamID = newValue.id
            madridLeagueID = newValue.leagueID
        }
    }
```

- [ ] **Step 2: Verify compilation**

Run: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Glance/Settings/SettingsStore.swift
git commit -m "feat: add madridSelectedTeam computed property to SettingsStore"
```

---

### Task 3: Replace TEAM ID and LEAGUE ID text fields with team picker

**Files:**
- Modify: `Glance/Settings/ProviderView.swift`

**Interfaces:**
- Consumes: `SettingsStore.madridSelectedTeam`, `FootballData.topChampionsLeagueTeams`
- Produces: `Picker` dropdown replacing two `ProviderInput` text fields

- [ ] **Step 1: Replace TEAM ID and LEAGUE ID inputs with Picker**

In `ProviderView.body`, replace the `inputs` array for the Real Madrid card:

Before:
```swift
ProviderCard(
    title: "Real Madrid",
    icon: "sportscourt",
    isOn: $settingsStore.showMadrid,
    inputs: [
        ProviderInput(label: "RSS URL", placeholder: "https://...", binding: $settingsStore.madridRSSURL),
        ProviderInput(label: "TEAM ID", placeholder: "133738", binding: $settingsStore.madridTeamID),
        ProviderInput(label: "LEAGUE ID", placeholder: "4335", binding: $settingsStore.madridLeagueID),
    ]
)
```

After:
```swift
ProviderCard(
    title: "Real Madrid",
    icon: "sportscourt",
    isOn: $settingsStore.showMadrid,
    inputs: [
        ProviderInput(label: "RSS URL", placeholder: "https://...", binding: $settingsStore.madridRSSURL),
    ]
)

Picker("Team", selection: Binding(
    get: { settingsStore.madridSelectedTeam },
    set: { settingsStore.madridSelectedTeam = $0 }
)) {
    ForEach(FootballData.topChampionsLeagueTeams) { team in
        Text(team.name).tag(team)
    }
}
.labelsHidden()
```

Wait — `ProviderCard` takes `inputs: [ProviderInput]` and renders text fields. We can't mix a `Picker` inside `ProviderCard` without modifying it. Options:
1. Add a `Picker` input type to `ProviderInput`/`ProviderCard`
2. Place the `Picker` outside `ProviderCard` but inside the same card visual
3. Keep the text fields but add a dropdown toggle

The cleanest approach: modify `ProviderCard` to accept an optional `pickerInput` parameter, or restructure the Real Madrid section to use a custom layout.

Actually, the simplest approach that follows existing patterns: modify `ProviderCard` to support either a text field or a picker. But that adds complexity.

Better approach: Don't use `ProviderCard` for the Real Madrid team selection. Instead, replicate the card styling directly in the Real Madrid section, replacing the `inputs` array with a custom view that includes the RSS URL text field plus the team picker.

Let me restructure: The Real Madrid `ProviderCard` will keep only the RSS URL input, and we'll add a separate `Picker` below it, styled with the same card background and padding.

Actually, the cleanest minimal change: Add a `pickerInput` property to `ProviderInput` that makes it render a `Picker` instead of a `TextField`.

Revised `ProviderInput`:
```swift
struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
    var pickerBinding: Binding<FootballTeam>? = nil
    var pickerView: ((Binding<FootballTeam>) -> some View)? = nil
}
```

This is getting complex. Let me take the simpler route: just add the `Picker` directly in the `ProviderCard` after the text inputs, using a new `inputs` variant.

Simplest approach that works with existing code: Replace the two text field inputs with a single custom view that includes both the RSS URL field and the team picker, rendered as part of the card content.

Actually, the cleanest minimal change: modify `ProviderCard` to accept an optional `pickerContent` view that renders below the inputs. Or even simpler — just add the `Picker` directly in the `ProviderView` after the `ProviderCard`, using the same card styling.

Let me go with the simplest approach: modify the Real Madrid `ProviderCard` to only show the RSS URL, and add a separate styled `Picker` below it (not inside the card). This is the minimal change that achieves the goal.

Actually, the most minimal and cleanest approach: just replace the TEAM ID and LEAGUE ID `ProviderInput` entries with a single entry that has a custom view. Let me modify `ProviderInput` to support a custom content view.

Final approach: Add a `content` closure parameter to `ProviderInput` that renders custom content instead of a text field. This is the most flexible and minimal change.

```swift
struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
    var content: ((Binding<String>) -> AnyView)? = nil
}
```

Hmm, `AnyView` is ugly. Let me think about this differently.

The simplest approach that doesn't require modifying `ProviderInput` or `ProviderCard`: Just add the `Picker` as a separate element in the `VStack` after the `ProviderCard`. It will look slightly different but will be functional and clean.

Let me go with this approach. In `ProviderView`, after the Real Madrid `ProviderCard`, add a styled `Picker` section:

```swift
// Team picker
VStack(alignment: .leading, spacing: 12) {
    HStack {
        Image(systemName: "sportscourt")
            .font(.title3)
            .foregroundStyle(Theme.Colors.accent)
        Text("Real Madrid")
            .font(Theme.Fonts.manrope(16, weight: .bold))
            .foregroundStyle(Theme.Colors.textPrimary)
        Spacer()
        Toggle("", isOn: $settingsStore.showMadrid)
            .labelsHidden()
    }

    if settingsStore.showMadrid {
        VStack(spacing: 10) {
            // RSS URL
            VStack(alignment: .leading, spacing: 4) {
                Text("RSS URL")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)

                TextField("https://...", text: $settingsStore.madridRSSURL)
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
            }

            // Team picker
            VStack(alignment: .leading, spacing: 4) {
                Text("TEAM")
                    .font(Theme.Fonts.manrope(10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .tracking(1.2)

                Picker("Team", selection: Binding(
                    get: { settingsStore.madridSelectedTeam },
                    set: { settingsStore.madridSelectedTeam = $0 }
                )) {
                    ForEach(FootballData.topChampionsLeagueTeams) { team in
                        Text(team.name).tag(team)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
            }
            .padding(10)
            .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
.padding(Theme.cardPadding)
.background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
```

Wait, this duplicates the card styling logic from `ProviderCard`. That's not DRY. Let me reconsider.

Actually, the cleanest approach is to modify `ProviderCard` to support a `pickerInput` parameter. This way we keep the card component reusable and the Real Madrid configuration stays in one place.

Let me modify `ProviderInput` and `ProviderCard`:

```swift
struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
    var pickerItems: [(String, FootballTeam)] = []
    var onPick: ((FootballTeam) -> Void)? = nil
}
```

No, this is getting messy. Let me take the truly simplest approach:

**Just replace the two `ProviderInput` entries with a single custom entry that renders a picker.** Modify `ProviderInput` to have an optional `pickerBinding` that, when set, renders a `Picker` instead of a `TextField`.

Here's the cleanest implementation:

```swift
struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
    var pickerTeam: Binding<FootballTeam>? = nil
}
```

Then in `ProviderCard`, in the `ForEach(inputs)` loop, check if `pickerTeam` is set and render a `Picker` instead of a `TextField`.

This is the minimal change. Let me write this out.

In `ProviderCard`, inside the `ForEach(inputs)` loop, after the `TextField` block, add:

```swift
if let pickerTeam = input.pickerTeam {
    Picker(input.label, selection: pickerTeam) {
        ForEach(FootballData.topChampionsLeagueTeams) { team in
            Text(team.name).tag(team)
        }
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .tint(Theme.Colors.accent)
} else {
    // existing TextField code
}
```

Hmm, but this changes the `ProviderCard` behavior for all providers. That's fine — the `pickerTeam` binding is `nil` by default, so existing providers are unaffected.

Let me finalize the plan with this approach.

- [ ] **Step 1: Modify ProviderInput to support team picker**

Add `pickerTeam` property to `ProviderInput`:

```swift
struct ProviderInput: Identifiable {
    let id = UUID()
    let label: String
    let placeholder: String
    let binding: Binding<String>
    var pickerTeam: Binding<FootballTeam>? = nil
}
```

- [ ] **Step 2: Update ProviderCard to render Picker when pickerTeam is set**

In `ProviderCard.body`, inside the `ForEach(inputs)` loop, replace the `TextField` block with conditional rendering:

```swift
ForEach(inputs) { input in
    VStack(alignment: .leading, spacing: 4) {
        Text(input.label)
            .font(Theme.Fonts.manrope(10, weight: .bold))
            .foregroundStyle(Theme.Colors.textMuted)
            .tracking(1.2)

        if let pickerTeam = input.pickerTeam {
            Picker("", selection: pickerTeam) {
                ForEach(FootballData.topChampionsLeagueTeams) { team in
                    Text(team.name).tag(team)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(Theme.Colors.accent)
        } else {
            TextField(input.placeholder, text: input.binding)
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
        }
    }
}
```

- [ ] **Step 3: Update ProviderView Real Madrid card**

Replace the Real Madrid `ProviderCard` inputs:

```swift
ProviderCard(
    title: "Real Madrid",
    icon: "sportscourt",
    isOn: $settingsStore.showMadrid,
    inputs: [
        ProviderInput(label: "RSS URL", placeholder: "https://...", binding: $settingsStore.madridRSSURL),
        ProviderInput(label: "TEAM", placeholder: "", binding: .constant(""), pickerTeam: Binding(
            get: { settingsStore.madridSelectedTeam },
            set: { settingsStore.madridSelectedTeam = $0 }
        )),
    ]
)
```

- [ ] **Step 4: Verify compilation**

Run: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Glance/Settings/ProviderView.swift
git commit -m "feat: replace team/league ID text fields with team picker dropdown"
```

---

### Task 4: Fix MadridPipeline hardcoded teamID references

**Files:**
- Modify: `Glance/Features/Madrid/MadridPipeline.swift`

**Interfaces:**
- Consumes: Configurable `teamID` from `SettingsStore` (already passed to `refresh()`)
- Produces: Parsing helpers that use `teamID` parameter instead of `SportsDB.realMadridID`

**Problem:** `badges(for:)`, `parseLastMatch(from:)`, `parseNextFixture(from:)`, `parseForm(from:)` use hardcoded `SportsDB.realMadridID` instead of the configurable `teamID`. This breaks if a user selects a different team.

- [ ] **Step 1: Update badges(for:) to accept teamID**

Change signature and body:
```swift
private static func badges(for match: SDBEvent, teamID: String) -> (rm: String?, opponent: String?) {
    let isHome = match.idHomeTeam == teamID
    return isHome
        ? (match.strHomeTeamBadge, match.strAwayTeamBadge)
        : (match.strAwayTeamBadge, match.strHomeTeamBadge)
}
```

- [ ] **Step 2: Update parseLastMatch(from:) to accept teamID**

Change signature and body:
```swift
static func parseLastMatch(from events: [SDBEvent], teamID: String) -> LastMatch? {
    guard let match = events.first(where: { $0.isFinished }) else { return nil }
    let isHome = match.idHomeTeam == teamID
    ...
    let badges = Self.badges(for: match, teamID: teamID)
    ...
}
```

- [ ] **Step 3: Update parseNextFixture(from:) to accept teamID**

Change signature and body:
```swift
static func parseNextFixture(from event: SDBEvent?, teamID: String) -> Fixture? {
    guard let match = event else { return nil }
    let isHome = match.idHomeTeam == teamID
    ...
    let badges = Self.badges(for: match, teamID: teamID)
    ...
}
```

- [ ] **Step 4: Update parseForm(from:) to accept teamID**

Change signature and body:
```swift
static func parseForm(from events: [SDBEvent], teamID: String) -> [FormEntry] {
    let finished = events.filter { $0.isFinished }.prefix(5)
    return finished.map { match in
        let isHome = match.idHomeTeam == teamID
        ...
    }
}
```

- [ ] **Step 5: Update all call sites in refresh()**

In `refresh()`, update the calls:
```swift
let lastMatch = matchTimeline.first(where: { $0.isFinished }).flatMap { Self.convertToLastMatch($0) }
let nextFixture = matchTimeline.first(where: { !$0.isFinished }).flatMap { Self.convertToFixture($0) }
let form = Self.parseForm(from: madridRecentEvents, teamID: teamID)
```

Wait — `parseForm(from:)` is called with `madridRecentEvents` which already filters by `teamID`. The `parseForm` function needs the `teamID` parameter to determine home/away. Let me check the current call site:

Line 91: `let form = Self.parseForm(from: madridRecentEvents)`

This needs to become: `let form = Self.parseForm(from: madridRecentEvents, teamID: teamID)`

And in `parseMatchTimeline`, the `badges` call needs `teamID`:
Line 288: `guard let item = timelineItem(from: event, teamID: teamID)` — already passes `teamID` ✓
Line 308: `let badges = Self.badges(for: event)` — needs `teamID` parameter

Wait, let me re-read the `timelineItem` function. It already uses `teamID` for `isHome` but calls `Self.badges(for: event)` without `teamID`. Need to fix that too.

- [ ] **Step 6: Update timelineItem to pass teamID to badges**

```swift
private static func timelineItem(from event: SDBEvent, teamID: String) -> MatchTimelineItem? {
    let isHome = event.idHomeTeam == teamID
    let opponent = isHome ? event.strAwayTeam : event.strHomeTeam
    let badges = Self.badges(for: event, teamID: teamID)
    ...
}
```

- [ ] **Step 7: Verify compilation**

Run: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20`
Expected: Build succeeds

- [ ] **Step 8: Commit**

```bash
git add Glance/Features/Madrid/MadridPipeline.swift
git commit -m "fix: use configurable teamID in parsing helpers instead of hardcoded SportsDB.realMadridID"
```

---

### Task 5: Build and verify

**Files:** All modified files

- [ ] **Step 1: Full build**

Run: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -30`
Expected: Build succeeds with no errors

- [ ] **Step 2: Run existing tests**

Run: `cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 3: Manual verification**

1. Open app in Simulator
2. Go to Settings > Providers
3. Verify Real Madrid card shows TEAM dropdown with 20 team names
4. Select a different team (e.g., Barcelona)
5. Verify the card updates with Barcelona's data
6. Verify the default (Real Madrid) still works

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: configurable team selection for Real Madrid provider"
```