# Multi-Theme Manager — Design Spec

**Date:** 2026-09-23
**Status:** Approved (brainstorming + v2 expansion complete)
**Scope:** Extensible multi-theme system; existing look as Default; Glance Web theme; 14 Glance web presets; Settings picker

---

## Overview

Replace the single hard-coded `Theme` design system with a multi-theme manager. The current Manrope/green-accent look becomes the **Default** theme (unchanged visuals). A **Glance Web** theme matches the self-hosted Glance web app (`http://192.168.1.100:8982`, `glanceapp/glance`, theme key `default`). Fourteen additional presets ported from Glance web `theme.presets` share Glance Web typography/metrics and override colors only. Future themes register in one array append.

**Decisions (user-confirmed):**
- Architecture: `@Observable` ThemeManager + plain-data `ThemeDefinition` registry + static `Theme` façade (zero call-site churn)
- Glance-family accents: collapse iOS card colors to primary/negative/positive (Default keeps 4 card accents)
- Picker: Settings → Appearance, alongside Dark/Light/System; wrapped grid for 16 themes
- Glance match scope: colors + font + radius + full type scale
- Font: full JetBrains Mono switch under all Glance-family themes (Default stays Manrope)
- **v2:** All 14 presets share Glance Web typography + metrics (colors only vary)
- **v2:** Presets with `light: true` (latte, peachy, zebra) **force light appearance** via `colorSchemeOverride`
- **v2:** Preset ids/names kept exactly as YAML (kebab-case id; display name title-cased)
- **v2:** `glanceWeb` built through the same HSL → tokens pipeline as presets so it matches the preset model

---

## Architecture

### Token model (plain data, 2026 consensus)

- **`ThemeColors`** — named semantic slots; each value is a light/dark pair (`Color(light:dark:)`, iOS 17+; deployment target 26.0), or a single resolved color when the theme forces an appearance.
- **`ThemeTypography`** — font family name + `FontRole` size/weight table + size mapper for oversized call sites.
- **`ThemeMetrics`** — corner radii, card padding, spacing.
- **`ThemeDefinition`** — `id`, display `name`, `previewSwatches: [Color]` (3), three token groups, `colorSchemeOverride: ColorScheme?`. `Sendable`.
- **`ThemeRegistry`** — `static let all: [ThemeDefinition]`; order = picker order. Default first / id `"default"`.

### ThemeManager

- `@Observable @MainActor final class ThemeManager`
- Singleton `ThemeManager.shared` (matches `CacheStore.shared` / `NetworkMonitor.shared` pattern)
- Persists `selectedThemeID` in `UserDefaults` key `"themeID"` (default `"default"`)
- Resolves `current: ThemeDefinition` from registry; unknown id falls back to Default
- Existing appearance preference `"colorScheme"` (`dark`/`light`/`system`) stays in `GlanceApp`; ThemeManager does not own it — but `GlanceApp` applies `current.colorSchemeOverride` first when non-nil

### Static façade (backward compatibility)

`Theme` remains the only API views touch:

- `Theme.Colors.*`, `Theme.Radius.*`, `Theme.cardPadding`, `Theme.spacing`, `Theme.cornerRadius`
- `Theme.Fonts.scale(_:)`, `Theme.Fonts.manrope(_:weight:)`, `Theme.Fonts.hankenGrotesk(_:weight:)`

All become computed properties/functions that read `ThemeManager.shared.current`. Observation tracks reads during view `body` evaluation → live restyle on switch. **No mass call-site edits.**

`Theme.Fonts.manrope` keeps its name as a compatibility wrapper; under Glance-family themes it returns JetBrains Mono at the theme’s mapped size. Rename to a neutral name is out of scope.

### Hard-coded semantic colors

`Theme.Colors.success`, `.warning`, `.canvasDeep`, `.starGold`, `.tierPurple` move from inline `UIColor { traits }` into `ThemeColors` so every theme defines them.

### Light/dark orthogonality (Default + glanceWeb)

Theme choice is independent of Dark/Light/System. Each `ThemeDefinition` carries both appearances; `Color(light:dark:)` resolves from the interface style that `preferredColorScheme` drives.

### Forced appearance (light presets)

When `colorSchemeOverride == .light`, `GlanceApp.preferredColorScheme` uses `.light` regardless of the user’s Dark/Light/System setting. Dark presets leave override `nil` (tokens are dark-fixed but scheme preference still follows user setting — dark tokens under light scheme remain valid because preset colors are single-variant resolved for their mode).

Preset color tokens are constructed as **single-mode resolved colors** (not light/dark pairs) for forced-light themes; for dark presets, tokens are dark values rendered as `Color(light:dark:)` with dark on both sides **or** plain `Color` with dark RGB — pick plain `Color` for presets to avoid double-resolution surprises. Default + glanceWeb keep true light/dark pairs.

---

## Default theme (existing values, no visual change)

Color slots keep current asset-catalog / hardcoded values:

| Slot | Light | Dark |
|------|-------|------|
| canvas | `#E9EDF2` | `#0B0E17` |
| surface1 | `#FFFFFF` | `#131720` |
| surface2 | `#FFFFFF` | `#1A1F2E` |
| surface3 | `#E2E8F0` | `#222840` |
| borderSubtle | `#D5DCE5` | `#1E2435` |
| borderStrong | `#CBD5E1` | `#2A3048` |
| textPrimary | `#0F172A` | `#F2F4F8` |
| textSecondary | `#475569` | `#8B92AA` |
| textMuted | `#64748B` | `#4A5168` |
| accent | `#069669` | `#4EDEA3` |
| error | `#DC2626` | `#FFB4AB` |
| success | `#069669` | `#34D399` |
| warning | `#B45309` | `#F5A623` |
| cardAmber | `#B45309` | `#F5A623` |
| cardRose | `#E11D48` | `#FB7185` |
| cardEmerald | `#069669` | `#34D399` |
| cardCyan | `#0991B2` | `#22D3EE` |
| starGold | `#B77305` | `#FACC33` |
| tierPurple | `#6B3DCC` | `#A87AFF` |
| canvasDeep | `#EDF1F5` | `#0A0E18` |

**Typography:** family `"Manrope"`, existing `FontRole` scale (display 40 black → badge 10 black), `scaledSize` Dynamic Type factor unchanged.

**Metrics:** small 8, medium 12, card 20, hero 28, sheet 32; `cornerRadius` 20; `cardPadding` 16; `spacing` 12.

**Preview swatches:** accent green, textPrimary, canvas.

**colorSchemeOverride:** `nil`.

---

## Glance Web theme (from live CSS + theme picker)

Source: bundle CSS `:root` defaults + `default` / `default-light` presets. Dark is primary; light is the `default-light` preset.

### Colors

| Slot | Dark | Light |
|------|------|-------|
| canvas | `#151519` | `#F1F1F4` |
| surface1 | `#17171C` | `#F3F3F6` |
| surface2 | `#1E1E24` | `#E9E9EF` |
| surface3 | `#232329` | `#E5E5EB` |
| borderSubtle | `#1E1E24` | `#E5E5EB` |
| borderStrong | `#31313A` | `#CECED9` |
| textPrimary | `#D6D6DC` (highlight 85%) | `#21212B` |
| textSecondary | `#8B8B9C` (base 58%) | `#5D5D79` |
| textMuted | `#525260` (subdue 35%) | `#9A9AB1` |
| accent / primary | `#D9C38C` `hsl(43,50%,70%)` | `#001A99` `hsl(230,100%,30%)` |
| error / negative | `#E87D7D` `hsl(0,70%,70%)` | `#D92626` `hsl(0,70%,50%)` |
| success / positive | `= accent` (web positive=primary) | `= accent` |
| warning | `= accent` | `= accent` |
| canvasDeep | `#1E1E24` | `#E5E5EB` |
| cardAmber | `= accent` | `= accent` |
| cardEmerald | `= accent` | `= accent` |
| cardCyan | `= accent` | `= accent` |
| cardRose | `= error` | `= error` |
| starGold | `= accent` | `= accent` |
| tierPurple | `= accent` | `= accent` |

Secondary text note: web also has `text-paragraph` `#B5B5C0` / light `#3C3C4E` — optional; not required for iOS slots above.

**Preview swatches:** `#D9C38C`, `#151519`, `#E87D7D` (mirrors web theme-picker button).

**colorSchemeOverride:** `nil` (adaptive).

**id:** `glanceWeb` (kept). Built through the same `GlancePreset` builder as the 14 presets where possible (hand hex table is the fixture for derivation tests).

### Typography (shared by all Glance-family themes)

- Family: `"JetBrains Mono"` (bundle Regular, Medium, SemiBold, Bold, ExtraBold, Black — SIL OFL, JetBrains GitHub releases)
- Ligatures off equivalent: use font as-is; no code change required beyond family
- Line height ≈ 1.6: apply `.lineSpacing` on body roles where cheap; full per-view audit out of scope
- **Type scale (web rem × 10):**

| Role | Size | Weight |
|------|------|--------|
| display | 17 | black |
| title1 | 17 | bold |
| title2 | 16 | bold |
| title3 | 15 | semibold |
| headline | 14 | semibold |
| body | 13 | regular |
| callout | 12 | medium |
| footnote | 12 | regular |
| caption1 | 11 | medium |
| caption2 | 11 | bold |
| badge | 11 | black |

- **Size mapper** for direct `manrope(n)` call sites (n often 20–40): clamp into 11…17: `n >= 17 → 17`; `n <= 11 → 11`; else `n`
- Weight: pass through `.weight` as today; JetBrains Mono has matching faces for regular/medium/semibold/bold/heavy→ExtraBold/Black

### Metrics (shared by all Glance-family themes)

All radii → **5**; `cardPadding` → **15**; `spacing` → **12** (web widget gap 23 is inter-column, not card padding — do not use 23 for card spacing).

---

## Glance web presets (v2 — 14 additional themes)

YAML source (Glance `theme.presets`). Field format: `H S L` space-separated (hue 0–360, sat 0–100, light 0–100), e.g. `background-color: 225 14 15` → `HSL(225, 14%, 15%)`.

### Registry order and ids

| # | id | display name | light | contrast | textSat |
|---|-----|--------------|-------|----------|---------|
| 0 | `default` | Default | — | — | — |
| 1 | `glanceWeb` | Glance Web | — | — | — |
| 2 | `teal-city` | Teal City | no | 1.1 | — |
| 3 | `catppuccin-frappe` | Catppuccin Frappe | no | 1.2 | — |
| 4 | `catppuccin-macchiato` | Catppuccin Macchiato | no | 1.2 | — |
| 5 | `catppuccin-mocha` | Catppuccin Mocha | no | 1.2 | — |
| 6 | `camo` | Camo | no | 1.2 | — |
| 7 | `gruvbox-dark` | Gruvbox Dark | no | — | — |
| 8 | `kanagawa-dark` | Kanagawa Dark | no | 1.2 | — |
| 9 | `tucan` | Tucan | no | — | — |
| 10 | `dracula` | Dracula | no | 1.2 | — |
| 11 | `shades-of-purple` | Shades of Purple | no | 1.2 | — |
| 12 | `neon-pink` | Neon Pink | no | 1.5 | — |
| 13 | `catppuccin-latte` | Catppuccin Latte | **yes** | 1.0 | — |
| 14 | `peachy` | Peachy | **yes** | 1.1 | 0.5 |
| 15 | `zebra` | Zebra | **yes** | — | — |

### Preset color inputs

| id | background | primary | positive | negative |
|----|------------|---------|----------|----------|
| teal-city | `225 14 15` | `157 47 65` | (→primary) | (→primary) |
| catppuccin-frappe | `229 19 23` | `222 74 74` | `96 44 68` | `359 68 71` |
| catppuccin-macchiato | `232 23 18` | `220 83 75` | `105 48 72` | `351 74 73` |
| catppuccin-mocha | `240 21 15` | `217 92 83` | `115 54 76` | `347 70 65` |
| camo | `186 21 20` | `97 13 80` | (→primary) | (→primary) |
| gruvbox-dark | `0 0 16` | `43 59 81` | `61 66 44` | `6 96 59` |
| kanagawa-dark | `240 13 14` | `51 33 68` | (→primary) | `358 100 68` |
| tucan | `50 1 6` | `24 97 58` | (→primary) | `209 88 54` |
| dracula | `231 15 21` | `265 89 79` | `135 94 66` | `0 100 67` |
| shades-of-purple | `243 33 25` | `50 100 49` | `98 82 71` | `12 77 52` |
| neon-pink | `240 27 11` | `321 100 71` | `165 78 51` | `360 100 71` |
| catppuccin-latte | `220 23 95` | `220 91 54` | `109 58 40` | `347 87 44` |
| peachy | `28 40 77` | `155 100 20` | (→primary) | `0 100 60` |
| zebra | `0 0 95` | `0 0 10` | (→primary) | `0 90 50` |

`contrast-multiplier` defaults to 1.0 when omitted. `text-saturation-multiplier` defaults to 1.0 (only peachy sets 0.5).

### HSL → ThemeColors derivation

**Dark preset (`light == false`):**

| Slot | Rule |
|------|------|
| `canvas` | `background` |
| `canvasDeep` | darken canvas −6% L (clamp ≥ 2%) |
| `surface1` | lighten canvas +2% L |
| `surface2` | +4% L |
| `surface3` | +7% L |
| `borderSubtle` | = surface2 |
| `borderStrong` | lighten canvas +12% L |
| `accent` | `primary` |
| `success` | `positive ?? primary` |
| `error` | `negative ?? primary` |
| `warning` | `primary` |
| `cardAmber`, `cardEmerald`, `cardCyan`, `starGold`, `tierPurple` | = accent (primary) |
| `cardRose` | = error (negative ?? primary) |
| `textPrimary` | near-white on dark: L = min(92, bgL + 70 × contrast), S scaled by `textSaturationMultiplier` |
| `textSecondary` | textPrimary luminance × ~0.78 × contrast factor |
| `textMuted` | textPrimary luminance × ~0.52 × contrast factor |

**Light preset (`light == true`):** invert surface direction (surfaces darker than canvas), text near-black from `background` with contrast multiplier; accent/success/error rules unchanged.

`contrast-multiplier` (1.0–1.5) scales the luminance gap between text and canvas so high-contrast presets (neon-pink 1.5) stay readable. `text-saturation-multiplier` scales H/S of the three text roles only.

**Preview swatches:** background, primary, negative-or-primary (3 circles).

**Typography/metrics:** shared Glance Web constants (`GlanceWebTypography.shared`, `GlanceWebMetrics.shared`).

**colorSchemeOverride:** `.light` for latte/peachy/zebra; `nil` for all other presets.

### GlancePreset model

```swift
struct GlancePreset: Sendable {
    let id: String
    let name: String
    let isLight: Bool
    let background: HSL
    let primary: HSL
    let positive: HSL?
    let negative: HSL?
    let contrastMultiplier: Double
    let textSaturationMultiplier: Double
}
```

`deriveThemeColors(from:isLight:) -> ThemeColors` is a pure function (unit-testable). `GlanceWebTheme.make()` may hand-author the dual light/dark table **or** derive from a synthetic dark+light preset pair and assert equality with the hex fixture table.

---

## Appearance application

```swift
// GlanceApp
var effectiveScheme: ColorScheme? {
    if let override = ThemeManager.shared.current.colorSchemeOverride { return override }
    return preferredFromColorSchemeSetting  // existing dark/light/system logic
}
.preferredColorScheme(effectiveScheme)
```

Switching to `catppuccin-latte` forces light even if System is dark; switching back to `default` restores the user’s colorScheme setting.

---

## Settings UI

In `SettingsView.appearanceSection`, below the Dark/Light/System row:

- Section label `THEME` (match `APPEARANCE` eyebrow style)
- **Wrapped `LazyVGrid`** (3 columns) of theme cards for all 16 — not a horizontal strip (16 cards need vertical reachability)
- Card: theme `name`, three swatch circles (`previewSwatches`), selected state (accent stroke / fill like `appearanceOption`)
- Light-preset cards show a small “light” badge when `colorSchemeOverride != nil`
- Tap → `ThemeManager.shared.select(id:)` (or Environment manager) with `withAnimation`
- Theme picker does not replace colorScheme control; colorScheme still applies when override is nil

Inject manager: `.environment(ThemeManager.shared)` at App root if using `@Environment(ThemeManager.self)` in Settings.

---

## Files

### New

| File | Responsibility |
|------|----------------|
| `Glance/DesignSystem/ThemeDefinition.swift` | `FontRole`, `ThemeColors`, `ThemeTypography`, `ThemeMetrics`, `ThemeDefinition`, `colorSchemeOverride` |
| `Glance/DesignSystem/ThemeManager.swift` | `@Observable` selection + persistence |
| `Glance/DesignSystem/ThemeRegistry.swift` | `all` (16), default id |
| `Glance/DesignSystem/Themes/DefaultTheme.swift` | Default `ThemeDefinition` |
| `Glance/DesignSystem/Themes/GlanceWebTheme.swift` | Glance Web tokens + shared typography/metrics |
| `Glance/DesignSystem/Themes/GlancePreset.swift` | `GlancePreset`, HSL, `deriveThemeColors` |
| `Glance/DesignSystem/Themes/GlancePresetThemes.swift` | 14 preset definitions + `makeDefinitions()` |
| `Glance/GlanceTests/ThemeManagerTests.swift` | Registry/manager/preset/derivation tests |
| `Glance/Resources/Fonts/JetBrainsMono-*.ttf` | 6 weights |

### Modified

| File | Change |
|------|--------|
| `Glance/DesignSystem/Theme.swift` | Façade → `ThemeManager.shared`; remove local color/font/radius constants (keep FlowLayout, shimmer, helpers); move `FontRole` out |
| `Glance/App/GlanceApp.swift` | Manager warm-up; `effectiveScheme` honors `colorSchemeOverride`; `.environment(ThemeManager.shared)` |
| `Glance/Settings/SettingsView.swift` | Theme grid picker in Appearance |
| `Glance/Resources/Info.plist` | Add JetBrains Mono `UIAppFonts` entries |
| `Glance/Glance.xcodeproj/project.pbxproj` | Register new Swift files + fonts + test file (**manual edit; `git add -f`**) |

### Unchanged call sites

All existing `Theme.*` usages (~100+ across features) remain as-is.

---

## Non-goals

- Downloading / remote themes
- Renaming `manrope()` API
- Perfect 1.6 line-height audit on every Text
- Changing Default theme visuals
- Web-only tokens (popover, progress bars) as first-class iOS slots unless already mapped above
- Per-preset custom typography or radii

---

## Verification

1. Unit: `ThemeManagerTests` — registry count == 16; ids exact; select persists; unknown id → default; light ids have `.light` override; HSL parse fixture; positive/negative fallbacks; contrast ordering; `glanceWeb` hex fixture match; Glance accent aliases equal primary/error.
2. Build: `xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build`
3. Manual: Settings → Appearance — all 16 selectable; Default vs Glance Web dark+light; light presets force light; relaunch retains selection; Default looks identical to pre-change; compare Glance Web to `http://192.168.1.100:8982/home`; spot-check `dracula` and `catppuccin-latte`.
