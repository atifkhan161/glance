# Glance Fixes & Enhancements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the card refresh bug, display cache timestamps, update hero section layouts, remove unused compact mode, and add per-card visibility toggles.

**Architecture:** Changes span 5 files: PulseStore (refresh logic), GlanceCardView (card UI + refresh button), SettingsStore (new toggle properties), SettingsView (toggle UI), MadridHubView + PoGoHubView (hero section updates). No new files needed — all changes are modifications to existing code.

**Tech Stack:** SwiftUI, @Observable, UserDefaults for persistence, CacheStore actor for cache metadata.

**Spec:** N/A — design was agreed upon in conversation (see brainstorming output above).

---

## Global Constraints

- iOS 17+ deployment target (existing project)
- SwiftUI with @Observable macro (no Combine)
- CacheStore is an actor — all cache access is async
- CardState enum: `.loading`, `.ready(data:age:)`, `.stale(data:age:)`, `.degraded(data:age:reason:)`, `.error(message:)`, `.offline(data:age:)`, `.keyMissing(keyName:)`
- TimeFormat.age(from:) returns strings like "5m ago", "2h ago", "3d ago"
- Theme.Fonts.manrope() for all typography, Theme.Colors for colors
- Theme.cardPadding = 16, Theme.Radius.card = 16, Theme.Radius.hero = 28

---

## Task 1: Fix Card Refresh Button (force: true)

**Root cause:** The card header refresh button at `GlanceCardView.swift:660` calls `store.refresh(card)` with default `force: false`. Since cache TTL is 24h, `cache.isValid()` returns `true` and the refresh silently returns early with no network call.

**Files:**
- Modify: `Glance/Features/Pulse/GlanceCardView.swift:596-600` (error retry)
- Modify: `Glance/Features/Pulse/GlanceCardView.swift:657-660` (card header refresh)

**Interfaces:**
- Consumes: `PulseStore.refreshCard(_ card: CardID)` which calls `refresh(card, force: true)`
- Produces: Card refresh buttons now force a network fetch

- [ ] **Step 1: Fix error retry button**

In `GlanceCardView.swift`, line 598, change:
```swift
Task { await store.refresh(card) }
```
to:
```swift
Task { await store.refreshCard(card) }
```

- [ ] **Step 2: Fix card header refresh button**

In `GlanceCardView.swift`, line 660, change:
```swift
Task { await store.refresh(card) }
```
to:
```swift
Task { await store.refreshCard(card) }
```

- [ ] **Step 3: Fix MadridHubView error retry**

In `MadridHubView.swift`, line 607, change:
```swift
Task { await store.refresh(.madrid) }
```
to:
```swift
Task { await store.refreshCard(.madrid) }
```

- [ ] **Step 4: Fix PoGoHubView error retry**

In `PoGoHubView.swift`, line 401, change:
```swift
Task { await store.refresh(.pogo) }
```
to:
```swift
Task { await store.refreshCard(.pogo) }
```

- [ ] **Step 5: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Glance/Features/Pulse/GlanceCardView.swift Glance/Features/Madrid/MadridHubView.swift Glance/Features/PoGo/PoGoHubView.swift
git commit -m "fix: force card refresh buttons to bypass cache validity check"
```

---

## Task 2: Display Per-Card Cache Age in GlanceCardView

**Files:**
- Modify: `Glance/Features/Pulse/GlanceCardView.swift:629-671` (CardHeaderView)

**Interfaces:**
- Consumes: `CardState.age` computed property (already exists)
- Produces: `CardHeaderView` shows "Updated Xm ago" text below the badge

- [ ] **Step 1: Add age text to CardHeaderView**

In `GlanceCardView.swift`, replace the `CardHeaderView` body (lines 642-671) with:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack {
            Circle()
                .fill(card.accentColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            GlanceBadge(text: card.badgeLabel, color: card.accentColor)

            Spacer()

            if let age = currentAge {
                StatusDot(ageText: age, showLabel: false)
            }

            Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                Task { await store.refreshCard(card) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .accessibilityLabel("Refresh \(card.badgeLabel)")
        }

        if let age = currentAge {
            Text("Updated \(age)")
                .font(Theme.Fonts.manrope(11))
                .foregroundStyle(Theme.Colors.textMuted)
        }
    }
    .padding(.horizontal, Theme.cardPadding)
    .padding(.top, Theme.cardPadding)
    .padding(.bottom, 8)
}
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Pulse/GlanceCardView.swift
git commit -m "feat: display per-card cache age timestamp on Glance feed"
```

---

## Task 3: Remove Compact Mode Toggle

**Files:**
- Modify: `Glance/Settings/SettingsStore.swift:15-18` (remove compactMode property)
- Modify: `Glance/Settings/SettingsView.swift:136-148` (remove compact mode toggle row)

**Interfaces:**
- Consumes: `SettingsStore.compactMode` property (to be removed)
- Produces: No compact mode in UI or store

- [ ] **Step 1: Remove compactMode from SettingsStore**

In `SettingsStore.swift`, delete lines 15-18:
```swift
    var compactMode: Bool {
        get { defaults.bool(forKey: "compactMode") }
        set { defaults.set(newValue, forKey: "compactMode") }
    }
```

- [ ] **Step 2: Remove compact mode toggle from SettingsView**

In `SettingsView.swift`, delete the compact mode HStack block (lines 136-148):
```swift
                HStack {
                    Text("Compact Mode")
                        .font(Theme.Fonts.manrope(14))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { settingsStore.compactMode },
                        set: { settingsStore.compactMode = $0 }
                    ))
                    .labelsHidden()
                }
                .padding(12)
                .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Settings/SettingsStore.swift Glance/Settings/SettingsView.swift
git commit -m "refactor: remove unused compact mode toggle from settings"
```

---

## Task 4: Add Card Visibility Toggles to Settings

**Files:**
- Modify: `Glance/Settings/SettingsStore.swift` (add 4 visibility properties)
- Modify: `Glance/Settings/SettingsView.swift` (add CARD VISIBILITY section)

**Interfaces:**
- Consumes: `SettingsStore` for reading toggle state
- Produces: `SettingsStore.showMadrid`, `.showPoGo`, `.showGithub`, `.showAiIntel` (all `Bool`, default `true`)

- [ ] **Step 1: Add visibility properties to SettingsStore**

In `SettingsStore.swift`, after the `leadCard` property (line 13), add:

```swift
    var showMadrid: Bool {
        get { defaults.object(forKey: "showMadrid") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showMadrid") }
    }

    var showPoGo: Bool {
        get { defaults.object(forKey: "showPoGo") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showPoGo") }
    }

    var showGithub: Bool {
        get { defaults.object(forKey: "showGithub") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showGithub") }
    }

    var showAiIntel: Bool {
        get { defaults.object(forKey: "showAiIntel") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showAiIntel") }
    }
```

Note: Using `defaults.object(forKey:) as? Bool ?? true` instead of `defaults.bool(forKey:)` because `bool(forKey:)` returns `false` for unset keys, but we want defaults to be `true`.

- [ ] **Step 2: Add CARD VISIBILITY section to SettingsView**

In `SettingsView.swift`, in the `body` computed property (line 13-23), add `cardVisibilitySection` after `displaySection`:

```swift
            displaySection
            cardVisibilitySection
            cacheSection
```

Then add the new section method after `displaySection`:

```swift
    // MARK: - Card Visibility Section

    private var cardVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("CARD VISIBILITY")

            VStack(spacing: 8) {
                cardToggle("Real Madrid", isOn: Binding(
                    get: { settingsStore.showMadrid },
                    set: { settingsStore.showMadrid = $0 }
                ))
                cardToggle("Pokémon GO", isOn: Binding(
                    get: { settingsStore.showPoGo },
                    set: { settingsStore.showPoGo = $0 }
                ))
                cardToggle("GitHub Trending", isOn: Binding(
                    get: { settingsStore.showGithub },
                    set: { settingsStore.showGithub = $0 }
                ))
                cardToggle("AI Intel", isOn: Binding(
                    get: { settingsStore.showAiIntel },
                    set: { settingsStore.showAiIntel = $0 }
                ))
            }
        }
    }

    private func cardToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.manrope(14))
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(12)
        .background(Theme.Colors.surface1, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Settings/SettingsStore.swift Glance/Settings/SettingsView.swift
git commit -m "feat: add per-card visibility toggles in settings"
```

---

## Task 5: Filter Cards in PulseView Based on Visibility Settings

**Files:**
- Modify: `Glance/Features/Pulse/PulseView.swift:9-13` (sortedCards computed property)

**Interfaces:**
- Consumes: `SettingsStore.showMadrid`, `.showPoGo`, `.showGithub`, `.showAiIntel`
- Produces: `sortedCards` filtered by visibility settings

- [ ] **Step 1: Update sortedCards to filter hidden cards**

In `PulseView.swift`, replace the `sortedCards` computed property (lines 9-13) with:

```swift
    private var sortedCards: [CardID] {
        var visible: [CardID] = []
        if settingsStore.showMadrid { visible.append(.madrid) }
        if settingsStore.showPoGo { visible.append(.pogo) }
        if settingsStore.showGithub { visible.append(.github) }
        if settingsStore.showAiIntel { visible.append(.aiIntel) }
        guard let lead = CardID(rawValue: settingsStore.leadCard),
              visible.contains(lead) else { return visible }
        return [lead] + visible.filter { $0 != lead }
    }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Pulse/PulseView.swift
git commit -m "feat: filter cards on Glance feed based on visibility settings"
```

---

## Task 6: Update MadridHubView Hero with Large Logo on Left

**Files:**
- Modify: `Glance/Features/Madrid/MadridHubView.swift:10-71` (hero section)

**Interfaces:**
- Consumes: `data.fixture?.rmBadge` or `data.lastMatch?.rmBadge` for badge URL
- Produces: Hero with large badge on left, stats/text on right

- [ ] **Step 1: Restructure hero to show large badge on left**

In `MadridHubView.swift`, replace the hero section (lines 10-71) with:

```swift
            if case .ready(let data, _) = store.madrid, let standing = data.standing {
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

                            Text(standing.badge != nil ? "La Liga" : "")
                                .font(Theme.Fonts.scale(.callout))
                                .foregroundStyle(Theme.Colors.textMuted)

                            if let fixture = data.fixture,
                               let scores = fixture.scores {
                                Text("\(scores.home) - \(scores.away)")
                                    .font(Theme.Fonts.scale(.display))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }

                            HStack(spacing: 16) {
                                statItem(label: "PTS", value: "\(standing.points)")
                                statItem(label: "W", value: "\(standing.won)")
                                statItem(label: "L", value: "\(standing.lost)")
                            }
                        }

                        Spacer()

                        // Large badge on the right
                        VStack(spacing: 8) {
                            if let rmBadgeURL = data.fixture?.rmBadge ?? data.lastMatch?.rmBadge,
                               let url = URL(string: rmBadgeURL) {
                                CachedAsyncImage(url: url) { image in
                                    image.resizable().scaledToFit()
                                } placeholder: {
                                    EmptyView()
                                }
                                .frame(width: 100, height: 100)
                            }

                            if let badgeURL = standing.badge, let url = URL(string: badgeURL) {
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

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Madrid/MadridHubView.swift
git commit -m "feat: add large Real Madrid badge to hub hero section"
```

---

## Task 7: Update PoGoHubView Hero with Large Pokemon Image on Left

**Files:**
- Modify: `Glance/Features/PoGo/PoGoHubView.swift:19-66` (hero section)

**Interfaces:**
- Consumes: `priority.image` for Pokemon sprite URL
- Produces: Hero with large Pokemon image on left, stats on right

- [ ] **Step 1: Restructure hero to show large Pokemon image on left**

In `PoGoHubView.swift`, replace the hero section (lines 19-66) with:

```swift
            if let priority = priorityRaid {
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Theme.Colors.cardRose.opacity(0.3), Theme.Colors.canvas],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(minHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero))

                    HStack(alignment: .top, spacing: 16) {
                        // Large Pokemon image on the left
                        if let spriteURL = priority.image, let url = URL(string: spriteURL) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                EmptyView()
                            }
                            .frame(width: 140, height: 140)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("POKÉMON GO")
                                .font(Theme.Fonts.scale(.title1))
                                .foregroundStyle(Theme.Colors.cardRose)

                            Text(priority.name)
                                .font(Theme.Fonts.scale(.title3))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .lineLimit(2)

                            BadgePill(text: tierBadgeText(priority), color: Theme.Colors.cardRose)

                            if let cp = priority.combatPower,
                               let normal = cp.normal,
                               let min = normal.min, let max = normal.max {
                                Text("CP \(formatCP(min)) – \(formatCP(max))")
                                    .font(Theme.Fonts.scale(.display))
                                    .foregroundStyle(Theme.Colors.textPrimary)
                            }
                        }
                    }
                    .padding(Theme.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Theme.cardPadding)
            }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/PoGo/PoGoHubView.swift
git commit -m "feat: add large Pokemon image to hub hero section"
```

---

## Task 8: Fix Hero Sections to Persist During Refresh

**Root cause:** Both hub view hero sections use `if case .ready(...)` guards, which fail during `.stale` state (when refresh is in progress), causing the hero to disappear and reappear.

**Files:**
- Modify: `Glance/Features/Madrid/MadridHubView.swift:10` (hero guard)
- Modify: `Glance/Features/PoGo/PoGoHubView.swift:12-13` (priorityRaid computed)

**Interfaces:**
- Consumes: `CardState` which can be `.ready` or `.stale` during refresh
- Produces: Hero persists during `.stale` transition

- [ ] **Step 1: Fix MadridHubView hero guard**

In `MadridHubView.swift`, line 10, change:
```swift
            if case .ready(let data, _) = store.madrid, let standing = data.standing {
```
to:
```swift
            if case .ready(let data, _) = store.madrid,
               let standing = data.standing {
                // Also show during stale (refresh in progress)
```

Wait — the issue is that during `.stale`, the `if case .ready` fails. We need to accept both `.ready` and `.stale`. Replace line 10 with:

```swift
            let heroData: MadridData? = {
                if case .ready(let data, _) = store.madrid { return data }
                if case .stale(let data, _) = store.madrid { return data }
                return nil
            }()
            if let heroData, let standing = heroData.standing {
```

- [ ] **Step 2: Fix PoGoHubView priorityRaid computed**

In `PoGoHubView.swift`, replace lines 11-14:
```swift
    private var priorityRaid: PoGoRaid? {
        guard case .ready(let data, _) = store.pogo else { return nil }
        return data.mega ?? data.fiveStar ?? data.shadow
    }
```
with:
```swift
    private var priorityRaid: PoGoRaid? {
        let data: PoGoData? = {
            if case .ready(let d, _) = store.pogo { return d }
            if case .stale(let d, _) = store.pogo { return d }
            return nil
        }()
        guard let data else { return nil }
        return data.mega ?? data.fiveStar ?? data.shadow
    }
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Glance/Features/Madrid/MadridHubView.swift Glance/Features/PoGo/PoGoHubView.swift
git commit -m "fix: keep hero sections visible during refresh (stale state)"
```

---

## Task 9: Add Visual Refresh Indicator on Cards

**Files:**
- Modify: `Glance/Features/Pulse/GlanceCardView.swift:3-46` (body + overlay)

**Interfaces:**
- Consumes: `isStaleOrDegraded` computed property (already exists)
- Produces: `ProgressView` overlay on cards during refresh

- [ ] **Step 1: Add ProgressView overlay for stale state**

In `GlanceCardView.swift`, in the `body` computed property, after the `.overlay(...)` for the border (line 37), add a new overlay:

```swift
        .overlay(alignment: .topTrailing) {
            if isStaleOrDegraded {
                ProgressView()
                    .tint(card.accentColor)
                    .padding(8)
                    .transition(.opacity)
            }
        }
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Glance/Features/Pulse/GlanceCardView.swift
git commit -m "feat: show loading spinner on cards during refresh"
```

---

## Summary

| Task | Description | Files Modified |
|------|-------------|----------------|
| 1 | Fix refresh buttons to force bypass cache | GlanceCardView, MadridHubView, PoGoHubView |
| 2 | Display per-card cache age on Glance feed | GlanceCardView |
| 3 | Remove compact mode toggle | SettingsStore, SettingsView |
| 4 | Add card visibility toggles | SettingsStore, SettingsView |
| 5 | Filter cards based on visibility | PulseView |
| 6 | Large Real Madrid badge in hub hero | MadridHubView |
| 7 | Large Pokemon image in hub hero | PoGoHubView |
| 8 | Fix hero sections during refresh | MadridHubView, PoGoHubView |
| 9 | Add refresh spinner on cards | GlanceCardView |

**Total files modified:** 6 (GlanceCardView, PulseView, SettingsStore, SettingsView, MadridHubView, PoGoHubView)
