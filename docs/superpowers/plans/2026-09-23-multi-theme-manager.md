# Multi-Theme Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Multi-theme manager with 16 themes — existing look as Default, Glance Web theme (colors + JetBrains Mono + 11–17px scale + 5px radii), 14 Glance web presets (shared Glance typography/metrics, colors-only; 3 force light), Settings theme grid, zero `Theme.*` call-site churn.

**Architecture:** Plain-data `ThemeDefinition` registry + `@Observable ThemeManager.shared` + static `Theme` façade reading the manager. Each theme owns color tokens, typography (family + FontRole table + size clamp), metrics, and optional `colorSchemeOverride`. Presets derive `ThemeColors` from HSL inputs via a pure function.

**Tech Stack:** SwiftUI, Observation (`@Observable`), `Color(light:dark:)`, UserDefaults persistence, JetBrains Mono TTFs, Swift Testing

**Spec:** `docs/superpowers/specs/2026-09-23-multi-theme-manager-design.md`

## Global Constraints

- Swift 6 strict concurrency; `@Observable` (not `ObservableObject`)
- All styling through `Theme.Colors.*`, `Theme.Fonts.*`, `Theme.Radius.*` — no new raw hex at call sites
- No inline comments
- File naming after primary type; DesignSystem root under `Glance/DesignSystem/`
- New Swift + font files **must** be added to `project.pbxproj` (groups: DesignSystem `FF8C64998CBA4B846369C9DE`, Fonts `D0A107ABCEA2817678E3DFC5`, Sources phase `FE86DACADCCAC95C40100576` peer entries); `git add -f` for pbxproj if gitignored
- Build before every commit: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build`
- Default visuals must be pixel-identical to current asset-catalog colors
- Preset ids stay exact kebab-case YAML names; display names are title-case labels only

## Theme inventory (16)

| # | id | Notes |
|---|-----|-------|
| 0 | `default` | Existing Manrope tokens; `colorSchemeOverride = nil` |
| 1 | `glanceWeb` | Glance Web palette + JetBrains Mono + 5px; adaptive; name kept |
| 2 | `teal-city` | preset dark, contrast 1.1 |
| 3 | `catppuccin-frappe` | preset dark, contrast 1.2 |
| 4 | `catppuccin-macchiato` | preset dark, contrast 1.2 |
| 5 | `catppuccin-mocha` | preset dark, contrast 1.2 |
| 6 | `camo` | preset dark, contrast 1.2 |
| 7 | `gruvbox-dark` | preset dark, default contrast |
| 8 | `kanagawa-dark` | preset dark, contrast 1.2 |
| 9 | `tucan` | preset dark, default contrast |
| 10 | `dracula` | preset dark, contrast 1.2 |
| 11 | `shades-of-purple` | preset dark, contrast 1.2 |
| 12 | `neon-pink` | preset dark, contrast 1.5 |
| 13 | `catppuccin-latte` | **force light**, contrast 1.0 |
| 14 | `peachy` | **force light**, contrast 1.1, textSat 0.5 |
| 15 | `zebra` | **force light**, default contrast |

All Glance-family themes (#1–15) share `GlanceWebTypography` (JetBrains Mono, 11–17, size clamp) and `GlanceWebMetrics` (radii 5, cardPadding 15, spacing 12).

## File Map

### New Files (10)

| File | Responsibility |
|------|----------------|
| `Glance/DesignSystem/ThemeDefinition.swift` | `FontRole`, `ThemeColors`, `ThemeTypography`, `ThemeMetrics`, `ThemeDefinition` (+ `colorSchemeOverride`) |
| `Glance/DesignSystem/ThemeManager.swift` | `@Observable` selection, UserDefaults, `current` resolution |
| `Glance/DesignSystem/ThemeRegistry.swift` | `all` (16), `defaultID` |
| `Glance/DesignSystem/Themes/DefaultTheme.swift` | Default tokens (current values) |
| `Glance/DesignSystem/Themes/GlanceWebTheme.swift` | Glance Web tokens + shared typography/metrics constants |
| `Glance/DesignSystem/Themes/GlancePreset.swift` | `HSL`, `GlancePreset`, `deriveThemeColors` |
| `Glance/DesignSystem/Themes/GlancePresetThemes.swift` | 14 `GlancePreset` values + factory |
| `Glance/GlanceTests/ThemeManagerTests.swift` | Registry + manager + derivation tests |
| `Glance/Resources/Fonts/JetBrainsMono-*.ttf` | Regular, Medium, SemiBold, Bold, ExtraBold, Black (downloaded) |

### Modified Files (5)

| File | Change |
|------|--------|
| `Glance/DesignSystem/Theme.swift` | Façade over `ThemeManager.shared`; move `FontRole` out; keep FlowLayout/shimmer/helpers |
| `Glance/App/GlanceApp.swift` | Warm-up, `effectiveScheme` honors `colorSchemeOverride`, `.environment(ThemeManager.shared)` |
| `Glance/Settings/SettingsView.swift` | Theme grid picker in Appearance |
| `Glance/Resources/Info.plist` | Append JetBrains Mono to `UIAppFonts` |
| `Glance/Glance.xcodeproj/project.pbxproj` | PBXFileReference + group children + PBXBuildFile + Sources/Resources phases for all new files |

---

### Task 1: Token Types + HSL Derivation Primitives

**Files:**
- Create: `Glance/DesignSystem/ThemeDefinition.swift`, `Glance/DesignSystem/Themes/GlancePreset.swift`

**Interfaces:**
- Consumes: existing `FontRole` (move from `Theme.swift`)
- Produces: `ThemeColors`, `ThemeTypography`, `ThemeMetrics`, `ThemeDefinition`, `FontRole`, `HSL`, `GlancePreset`, `deriveThemeColors`

- [ ] **Step 1: Write failing tests** in `ThemeManagerTests.swift` (create file):

```swift
import Testing
import SwiftUI
@testable import Glance

@Suite("ThemeDefinition")
struct ThemeDefinitionTests {
    @Test func defaultMetricsMatchLegacy() {
        let m = DefaultTheme.make().metrics
        #expect(m.radiusSmall == 8)
        #expect(m.radiusMedium == 12)
        #expect(m.radiusCard == 20)
        #expect(m.radiusHero == 28)
        #expect(m.radiusSheet == 32)
        #expect(m.cardPadding == 16)
        #expect(m.spacing == 12)
        #expect(m.cornerRadius == 20)
        #expect(ThemeDefinitionHelper.isNilOverride(DefaultTheme.make()))
    }

    @Test func glanceMetricsUseWebRadius() {
        let m = GlanceWebTheme.make().metrics
        #expect(m.radiusSmall == 5)
        #expect(m.radiusCard == 5)
        #expect(m.cardPadding == 15)
        #expect(m.spacing == 12)
    }

    @Test func glanceTypeScaleClampsTo11Through17() {
        let t = GlanceWebTheme.sharedTypography
        #expect(t.scale(for: .display).size == 17)
        #expect(t.scale(for: .body).size == 13)
        #expect(t.scale(for: .badge).size == 11)
        #expect(t.mappedSize(40) == 17)
        #expect(t.mappedSize(8) == 11)
        #expect(t.mappedSize(14) == 14)
        #expect(t.family == "JetBrains Mono")
    }

    @Test func glanceCardAccentCollapse() {
        let c = GlanceWebTheme.make().colors
        let primaryDark = c.accent.darkDescription
        #expect(c.cardAmber.darkDescription == primaryDark)
        #expect(c.cardEmerald.darkDescription == primaryDark)
        #expect(c.cardCyan.darkDescription == primaryDark)
        #expect(c.cardRose.darkDescription == c.error.darkDescription)
        #expect(c.success.darkDescription == primaryDark)
    }
}

enum ThemeDefinitionHelper {
    static func isNilOverride(_ t: ThemeDefinition) -> Bool {
        t.colorSchemeOverride == nil
    }
}

@Suite("HSL Derivation")
struct HSLDerivationTests {
    @Test func parsesSpaceSeparatedHSL() {
        let hsl = HSL(parsing: "225 14 15")
        #expect(hsl?.hue == 225)
        #expect(hsl?.saturation == 14)
        #expect(hsl?.lightness == 15)
    }

    @Test func darkPresetMapsBackgroundToCanvasAndPrimaryToAccent() {
        let preset = GlancePreset(
            id: "fixture", name: "Fixture", isLight: false,
            background: HSL(hue: 240, saturation: 0, lightness: 16),
            primary: HSL(hue: 43, saturation: 50, lightness: 70),
            positive: nil, negative: nil,
            contrastMultiplier: 1.2, textSaturationMultiplier: 1.0
        )
        let colors = GlancePreset.deriveThemeColors(from: preset)
        #expect(colors.accent.hexDescription.hasPrefix("#"))
        #expect(colors.success == colors.accent)
        #expect(colors.error == colors.accent)
        #expect(colors.cardRose == colors.error)
        #expect(colors.cardAmber == colors.accent)
    }

    @Test func explicitNegativeDoesNotAliasPrimary() {
        let preset = GlancePreset(
            id: "dracula", name: "Dracula", isLight: false,
            background: HSL(hue: 231, saturation: 15, lightness: 21),
            primary: HSL(hue: 265, saturation: 89, lightness: 79),
            positive: HSL(hue: 135, saturation: 94, lightness: 66),
            negative: HSL(hue: 0, saturation: 100, lightness: 67),
            contrastMultiplier: 1.2, textSaturationMultiplier: 1.0
        )
        let colors = GlancePreset.deriveThemeColors(from: preset)
        #expect(colors.error != colors.accent)
        #expect(colors.success != colors.accent)
    }

    @Test func lightPresetForcesLightOverride() {
        let themes = GlancePresetThemes.makeDefinitions()
        let latte = themes.first { $0.id == "catppuccin-latte" }
        #expect(latte?.colorSchemeOverride == .light)
        let peachy = themes.first { $0.id == "peachy" }
        #expect(peachy?.colorSchemeOverride == .light)
        let zebra = themes.first { $0.id == "zebra" }
        #expect(zebra?.colorSchemeOverride == .light)
        let dracula = themes.first { $0.id == "dracula" }
        #expect(dracula?.colorSchemeOverride == nil)
    }

    @Test func contrastMultiplierIncreasesTextLuminanceGap() {
        let base = GlancePreset(
            id: "a", name: "A", isLight: false,
            background: HSL(hue: 240, saturation: 20, lightness: 15),
            primary: HSL(hue: 40, saturation: 50, lightness: 70),
            positive: nil, negative: nil,
            contrastMultiplier: 1.0, textSaturationMultiplier: 1.0
        )
        var high = base
        high = GlancePreset(
            id: "b", name: "B", isLight: false,
            background: base.background, primary: base.primary,
            positive: nil, negative: nil,
            contrastMultiplier: 1.5, textSaturationMultiplier: 1.0
        )
        let c1 = GlancePreset.deriveThemeColors(from: base)
        let c2 = GlancePreset.deriveThemeColors(from: high)
        #expect(c2.textPrimary.relativeLuminance > c1.textPrimary.relativeLuminance)
    }
}
```

(`darkDescription` / `hexDescription` / `relativeLuminance`: fileprivate helpers via `UIColor` resolved color.)

- [ ] **Step 2: Implement `ThemeDefinition.swift`**

```swift
import SwiftUI

enum FontRole: String, CaseIterable, Sendable {
    case display, title1, title2, title3, headline, body, callout, footnote, caption1, caption2, badge
}

struct ThemeColors: Sendable {
    let canvas, canvasDeep, surface1, surface2, surface3: Color
    let borderSubtle, borderStrong: Color
    let textPrimary, textSecondary, textMuted: Color
    let accent, error, success, warning: Color
    let cardAmber, cardRose, cardEmerald, cardCyan: Color
    let starGold, tierPurple: Color
}

struct ThemeTypography: Sendable {
    let family: String
    let roles: [FontRole: (size: CGFloat, weight: Font.Weight)]
    let sizeBounds: ClosedRange<CGFloat>

    func scale(for role: FontRole) -> (size: CGFloat, weight: Font.Weight) {
        roles[role] ?? (13, .regular)
    }

    func mappedSize(_ requested: CGFloat) -> CGFloat {
        min(max(requested, sizeBounds.lowerBound), sizeBounds.upperBound)
    }

    func font(for role: FontRole) -> Font {
        let r = scale(for: role)
        return Font.custom(family, size: r.size).weight(r.weight)
    }

    func custom(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom(family, size: mappedSize(size)).weight(weight)
    }
}

struct ThemeMetrics: Sendable {
    let radiusSmall, radiusMedium, radiusCard, radiusHero, radiusSheet: CGFloat
    let cornerRadius, cardPadding, spacing: CGFloat
}

struct ThemeDefinition: Identifiable, Sendable {
    let id: String
    let name: String
    let previewSwatches: [Color]
    let colors: ThemeColors
    let typography: ThemeTypography
    let metrics: ThemeMetrics
    let colorSchemeOverride: ColorScheme?
}
```

- [ ] **Step 3: Implement `GlancePreset.swift`** — `HSL` (hue/saturation/lightness Doubles + `parsing: String`), `rgb` conversion, `GlancePreset` struct, `deriveThemeColors(from:)` implementing the spec tables (dark + light branches, contrast + textSaturation multipliers). Use plain `Color(red:green:blue:)` for derived preset colors (single-mode).

- [ ] **Step 4: Register both files in pbxproj** (DesignSystem + Themes groups + Sources), `git add -f` pbxproj if needed.
- [ ] **Step 5: Tests fail until Default/GlanceWeb/preset factories exist** — proceed to Task 2 before claiming green for suite that references them.

---

### Task 2: Registry, Manager, Default + Glance Themes + Façade

**Files:**
- Create: `Glance/DesignSystem/ThemeManager.swift`, `Glance/DesignSystem/ThemeRegistry.swift`, `Glance/DesignSystem/Themes/DefaultTheme.swift`, `Glance/DesignSystem/Themes/GlanceWebTheme.swift`, `Glance/DesignSystem/Themes/GlancePresetThemes.swift`
- Modify: `Glance/DesignSystem/Theme.swift` (façade), `Glance/App/GlanceApp.swift` (warm-up + effectiveScheme + environment)

**Interfaces:**
- Consumes: `ThemeDefinition` tokens, `GlancePreset`
- Produces: `ThemeManager.shared.current`, `ThemeRegistry.all` (16)

- [ ] **Step 1: Write failing manager tests** (append to `ThemeManagerTests.swift`):

```swift
@Suite("ThemeRegistry")
struct ThemeRegistryTests {
    @Test func containsAllSixteenIdsInOrder() {
        let ids = ThemeRegistry.all.map(\.id)
        #expect(ids == [
            "default", "glanceWeb",
            "teal-city", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha",
            "camo", "gruvbox-dark", "kanagawa-dark", "tucan", "dracula",
            "shades-of-purple", "neon-pink", "catppuccin-latte", "peachy", "zebra"
        ])
        #expect(ThemeRegistry.all.count == 16)
    }

    @Test func sharedTypographyOnAllGlanceFamily() {
        for theme in ThemeRegistry.all where theme.id != "default" {
            #expect(theme.typography.family == "JetBrains Mono")
            #expect(theme.metrics.radiusCard == 5)
            #expect(theme.metrics.cardPadding == 15)
        }
        #expect(ThemeRegistry.all[0].typography.family == "Manrope")
    }

    @Test func lightOverridesOnlyThreePresets() {
        let forced = ThemeRegistry.all.filter { $0.colorSchemeOverride == .light }.map(\.id)
        #expect(forced == ["catppuccin-latte", "peachy", "zebra"])
    }
}

@Suite("ThemeManager")
@MainActor
struct ThemeManagerTests {
    @Test func selectPersistsAndFallsBack() {
        let defaults = UserDefaults.standard
        let key = "themeID"
        let previous = defaults.string(forKey: key)
        defer {
            if let previous { defaults.set(previous, forKey: key) } else { defaults.removeObject(forKey: key) }
        }
        defaults.removeObject(forKey: key)
        let manager = ThemeManager()
        #expect(manager.current.id == ThemeRegistry.defaultID)
        manager.select(id: "dracula")
        #expect(manager.current.id == "dracula")
        #expect(defaults.string(forKey: key) == "dracula")
        manager.select(id: "doesNotExist")
        #expect(manager.current.id == ThemeRegistry.defaultID)
    }
}
```

- [ ] **Step 2: Implement ThemeManager**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class ThemeManager {
    static let shared = ThemeManager()
    private static let storageKey = "themeID"

    private var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: Self.storageKey) }
    }

    var current: ThemeDefinition {
        ThemeRegistry.all.first { $0.id == selectedID } ?? ThemeRegistry.all[0]
    }

    init() {
        selectedID = UserDefaults.standard.string(forKey: Self.storageKey) ?? ThemeRegistry.defaultID
        if ThemeRegistry.all.first(where: { $0.id == selectedID }) == nil {
            selectedID = ThemeRegistry.defaultID
        }
    }

    func select(id: String) {
        guard id != selectedID else { return }
        selectedID = id
    }
}
```

- [ ] **Step 3: Implement ThemeRegistry**

```swift
enum ThemeRegistry {
    static let defaultID = "default"
    static let all: [ThemeDefinition] = [
        DefaultTheme.make(),
        GlanceWebTheme.make()
    ] + GlancePresetThemes.makeDefinitions()
}
```

- [ ] **Step 4: Implement DefaultTheme** — copy exact hex from spec table; `Color(light:dark:)` pairs; family `"Manrope"`; `sizeBounds: 8...40`; `FontRole` sizes identical to current `Theme.Fonts.scale`; metrics from current `Theme.Radius` + padding/spacing; swatches green accent `#069669`/`#4EDEA3`, textPrimary, canvas; `colorSchemeOverride = nil`.
  - Explicit success `#069669`/`#34D399`, warning `#B45309`/`#F5A623`, canvasDeep `#EDF1F5`/`#0A0E18`, starGold `#B77305`/`#FACC33`, tierPurple `#6B3DCC`/`#A87AFF` as currently hard-coded.

- [ ] **Step 5: Implement GlanceWebTheme** — palette from spec (dual light/dark table as `Color(light:dark:)`); family `"JetBrains Mono"` (space); `sharedTypography` + `sharedMetrics` static lets reused by presets; `sizeBounds: 11...17`; metrics all radii 5, cardPadding 15, spacing 12; success/warning/cardAmber/Emersed/Cyan/starGold/tierPurple aliased to accent pairs; cardRose = error; swatches `#D9C38C`, `#151519`, `#E87D7D`; `colorSchemeOverride = nil`.

- [ ] **Step 6: Implement GlancePresetThemes** — 14 `GlancePreset` entries with exact ids and HSL inputs from spec table; `makeDefinitions()` maps each to `ThemeDefinition` using `deriveThemeColors`, `GlanceWebTheme.sharedTypography/Metrics`, display names title-case, `colorSchemeOverride = .light` iff `isLight`.

- [ ] **Step 7: Rewrite Theme.swift façade** — remove `enum Colors` stored values / `enum Radius` / `enum Fonts` bodies; replace with:

```swift
enum Colors {
    static var canvas: Color { ThemeManager.shared.current.colors.canvas }
    static var canvasDeep: Color { ThemeManager.shared.current.colors.canvasDeep }
    // … every existing public member, one-liners
}
enum Radius {
    static var small: CGFloat { ThemeManager.shared.current.metrics.radiusSmall }
    static var medium: CGFloat { ThemeManager.shared.current.metrics.radiusMedium }
    static var card: CGFloat { ThemeManager.shared.current.metrics.radiusCard }
    static var hero: CGFloat { ThemeManager.shared.current.metrics.radiusHero }
    static var sheet: CGFloat { ThemeManager.shared.current.metrics.radiusSheet }
}
static var cornerRadius: CGFloat { ThemeManager.shared.current.metrics.cornerRadius }
static var cardPadding: CGFloat { ThemeManager.shared.current.metrics.cardPadding }
static var spacing: CGFloat { ThemeManager.shared.current.metrics.spacing }
enum Fonts {
    static func scale(_ role: FontRole) -> Font { ThemeManager.shared.current.typography.font(for: role) }
    static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        ThemeManager.shared.current.typography.custom(size, weight: weight)
    }
    static func hankenGrotesk(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        ThemeManager.shared.current.typography.custom(size, weight: weight)
    }
}
```

  - Move `FontRole` out of `Theme.swift` into `ThemeDefinition.swift`; delete duplicate.
  - Keep `FlowLayout`, shimmer, helpers, `_ThemePreview` if present.
  - Port `scaledSize` Dynamic Type helper so Default still scales; apply consistently in façade/typography `custom` as today.

- [ ] **Step 8: GlanceApp** — `_ = ThemeManager.shared` warm-up; compute `effectiveScheme` (override first, else existing colorScheme setting) for `.preferredColorScheme`; `.environment(ThemeManager.shared)` on root view.

- [ ] **Step 9: Build**; fix until green. Run Theme* tests.

---

### Task 3: JetBrains Mono Fonts

**Files:**
- Create: `Glance/Resources/Fonts/JetBrainsMono-Regular.ttf` … `-Black.ttf`
- Modify: `Glance/Resources/Info.plist`, `project.pbxproj`

**Interfaces:**
- Consumes: `GlanceWebTheme.sharedTypography` family string
- Produces: registered UIAppFonts

- [ ] **Step 1: Download** JetBrains Mono release zip from `https://github.com/JetBrains/JetBrainsMono/releases` (pin a release tag). Extract Regular, Medium, SemiBold, Bold, ExtraBold, Black into `Glance/Resources/Fonts/`.
- [ ] **Step 2: Info.plist** — add six `JetBrainsMono-*.ttf` paths under `UIAppFonts` (same style as existing Manrope entries).
- [ ] **Step 3: pbxproj** — file refs with `lastKnownFileType = file`, children under Fonts group `D0A107ABCEA2817678E3DFC5`, **no** PBXBuildFile Sources entry (fonts are resources; mirror how Manrope is bundled).
- [ ] **Step 4: Build** and confirm no “font not found” — smoke-check `UIFont(name: "JetBrains Mono", size: 13) != nil` in a temp test or UI.

---

### Task 4: Settings Theme Grid Picker

**Files:**
- Modify: `Glance/Settings/SettingsView.swift`

**Interfaces:**
- Consumes: `ThemeRegistry`, `ThemeManager`
- Produces: Appearance section UI

- [ ] **Step 1:** After colorScheme options row, add section label `THEME` (match `APPEARANCE` eyebrow style) + wrapped grid:

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
    ForEach(ThemeRegistry.all) { theme in
        themeCard(theme)
    }
}
```

- [ ] **Step 2:** `themeCard` — VStack: name (caption1, title-case), HStack of 3 circle swatches; selected → accent stroke + `fontWeight(.semibold)`; light badge when `colorSchemeOverride == .light`; tap → `withAnimation { manager.select(id: theme.id) }`. Use `@Environment(ThemeManager.self)` (injected in Task 2 Step 8).
- [ ] **Step 3: Build.**

---

### Task 5: Verification + Commit Prep

- [ ] **Step 1:** Full `xcodebuild` build; run test bundle (ThemeManagerTests + existing).
- [ ] **Step 2:** Simulator: Settings → Appearance — all 16 cards; Default vs Glance Web dark + light; light presets force light; dark preset under System light still shows preset tokens; relaunch persistence; Default matches pre-change.
- [ ] **Step 3:** Compare Glance Web to `http://192.168.1.100:8982/home` (canvas, accent tan, mono, 5px radius). Spot-check `dracula` and `catppuccin-latte` vs glance theme picker if reachable.
- [ ] **Step 4:** `git status` / `git diff` review; stage only intended files (`-f` pbxproj, fonts, new Swift); **commit only if user asked**.

## Commit Strategy

1. `feat: add theme definition tokens and registry`
2. `feat: add glance web theme and font assets`
3. `feat: add glance preset themes`
4. `feat: add settings theme picker`

Or one commit if user prefers. Do not commit secrets; use `git add -f` only for pbxproj when required.

## Risks / Mitigations

| Risk | Mitigation |
|------|------------|
| Observation not tracking static façade | Reads of `ThemeManager.shared` happen in view body; verified in Task 4 live switch |
| JetBrains Mono family name mismatch | Confirm post-install PostScript/family name with UIFont in tests |
| pbxproj corruption | Manual edits only; never Python pbxproj libs (AGENTS) |
| Default visual drift | Hex table copied from colorsets in Task 2 Step 4; side-by-side check Task 5 |
| Tuple `roles` Sendable warnings | Use struct fields or `[(FontRole, CGFloat, FontWeight)]` as needed |
| HSL derivation ≠ glance CSS | Fixture tests against `glanceWeb` hex table; contrast unit tests |
| Light preset tokens unreadable under dark scheme | `colorSchemeOverride = .light` forces scheme in GlanceApp |
