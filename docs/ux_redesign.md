# Glance — UX Redesign Proposal

> A design evolution for the Glance personal intelligence dashboard, grounded in the current codebase and inspired by the best native iOS apps shipping in 2025–26.

---

## 1. Executive Summary

Glance is already a technically strong app — a dark-first, card-based intelligence dashboard with a custom floating tab bar, four well-defined data streams, and solid accessibility foundations. What it lacks is **visual personality, spatial hierarchy, and moments of delight**.

This redesign targets three goals:

1. **Elevate the Pulse feed** from a plain list of cards into a living dashboard that feels alive.
2. **Deepen each hub view** with hero sections, better data density, and opinionated typography.
3. **Adopt Apple's Liquid Glass language** for navigation chrome while keeping the dark, focused aesthetic the app already has.

---

## 2. Design Inspiration

### Linear — Luminance Stacking & Information Density
Linear's dark-first system uses *luminance stacking* to express depth: surfaces get progressively lighter as they elevate, with no drop shadows. Hairline 1px borders replace heavy outlines. Every element earns its place; nothing is decorative. Applied to Glance: cards should feel like elevated panels floating off a near-black canvas, not boxes with thick colored borders.

### Vercel — Ink-over-canvas, Zero Decoration
Vercel's Geist system strips everything back to content. No gradients on content surfaces, no brand colours except at one decisive interaction point. Status indicators use semantic colour only. The key lesson: **the data is the design** — let match scores, star counts, and AI headlines be the visual stars, not the chrome around them.

### iOS 26 Liquid Glass
Apple's new material for navigation — translucent, refracting, alive during interactions — is the right home for Glance's floating dock. The dock already uses `.ultraThinMaterial`; the redesign upgrades it to a proper Liquid Glass surface using `glassEffect()`, adds morph-on-select animations, and lets the tab bar adapt its tint to the active card's accent colour (emerald for Pulse, amber for Madrid, etc.).

### Fantastical & Cardhop — Opinionated but Functional
The Flexibits apps demonstrate that productivity apps can have strong visual identity without sacrificing information density. Key patterns: a bold hero section at the top of every detail view, tight typographic rhythm with one display-weight number as the visual anchor, and subtle but distinct colour per entity type.

### Apollo for Reddit — Card Polish & Gesture Vocabulary
Apollo set the gold standard for card-based iOS feeds: clean media previews, swipe-to-action on rows, contextual long-press menus, and pull-to-refresh with a custom indicator. Applied to Glance: the repo rows in GitHubHub and raid cards in PoGoHub should support swipe actions and long-press context menus, matching the gesture vocabulary iOS users already know.

### Craft / Bear — Typography as Information Architecture
Both apps treat font weight and size as the primary navigation signal. Headline → sub-label → body → caption is a strict hierarchy enforced at every level. No reliance on boxes or borders — whitespace and type weight do all the work.

---

## 3. Current State Audit

### What Works
- Custom floating pill dock — distinctive and purposeful.
- `CardState<T>` state machine — skeleton → stale → ready transitions are well-structured.
- Four clear accent colours (amber, rose, emerald, cyan) — strong semantic identity per stream.
- Manrope font family — warm, geometric, readable at small sizes.
- Accessibility groundwork (reduce motion, labels, traits) — keep all of this.
- Cache-then-revalidate pattern — perceived performance is already excellent.

### Pain Points

| Area | Current Issue | Impact |
|------|--------------|--------|
| Pulse feed | All four cards are visually identical rectangles — no hierarchy, no visual weight differentiation | Medium |
| Card headers | Icon + badge + age pill + refresh button are crowded into one HStack | High |
| Hub views | All hub views use `.navigationBarTitleDisplayMode(.large)` plain title — no hero identity | Medium |
| Floating dock | Only `.ultraThinMaterial` — no Liquid Glass adaptation, no accent tint shift | Medium |
| Skeleton loading | Three identical grey rectangles don't match the actual card layout shapes | Low |
| Settings | Branding header + appearance + cache all in one undifferentiated scroll | Low |
| Empty/error states | Centred icon + two lines of text — functional but forgettable | Low |
| Typography scale | Sizes jump from 10pt badges to 32pt score — no mid-range hierarchy | Medium |
| Card footer | "View hub" chevron link is small and low-contrast | Low |

---

## 4. Redesign Principles

**P1 — Content First, Chrome Last**  
Accent colours and bold type carry the UI. Borders, backgrounds, and decoration recede. The match score or AI headline is the biggest thing on screen — not the section label.

**P2 — One Hero Per Screen**  
Every screen has exactly one full-bleed or large-format hero section at the top. Everything else is secondary. This creates immediate visual anchoring.

**P3 — Luminance Stacking for Depth**  
`canvas` → `surface1` → `surface2` → `surface3` should form a clear brightness ladder. Cards on the feed are `surface1`. Nested tiles inside hub sections are `surface2`. Active/selected states are `surface3`.

**P4 — Motion with Purpose**  
Transitions signal state change. A card going from `.loading` → `.ready` should do a gentle reveal, not just appear. Tab switches should morph the dock indicator smoothly. Reduce motion is always respected.

**P5 — Liquid Glass for Navigation Only**  
Liquid Glass (iOS 26 `glassEffect()`) stays on the navigation layer: the floating dock, toolbar backgrounds, and the navigation bar. Content surfaces stay matte/dark. This preserves the clear hierarchy Apple recommends.

**P6 — Gestural Completeness**  
Every list row should have a swipe action (at minimum: refresh the specific item). Long-press brings a context menu. Pull-to-refresh uses a custom indicator styled with the stream's accent colour.

---

## 5. Visual Identity Updates

### 5.1 Color Palette Refinement

Keep the four semantic card accent colours. Refine the base palette:

```
canvas:      #0B0E17  (current ~#0F131D, slightly cooler)
surface1:    #131720  (card backgrounds — slightly lighter than canvas)
surface2:    #1A1F2E  (nested tiles, active rows)
surface3:    #222840  (selected/hover states)
borderSubtle:#1E2435  (hairline dividers — 1px only)
borderStrong:#2A3048  (card outlines when needed)

textPrimary: #F2F4F8  (slightly warmer white)
textSecondary:#8B92A8 (reduced contrast to create clear hierarchy)
textMuted:   #4A5168  (timestamps, captions — clearly receded)

cardAmber:   #F59E0B  (keep — Real Madrid)
cardRose:    #F43F5E  (keep — Pokémon GO)
cardEmerald: #10B981  (keep — GitHub / Pulse)
cardCyan:    #06B6D4  (keep — AI Intel)

error:       #EF4444
success:     #22C55E
warning:     #EAB308
```

### 5.2 Typography Scale

Replace the ad-hoc size values scattered across the codebase with a named scale:

| Role | Size | Weight | Font | Usage |
|------|------|--------|------|-------|
| `display` | 40pt | ExtraBold | Manrope | Match scores, big stats |
| `title1` | 28pt | Bold | Manrope | Hub hero headlines |
| `title2` | 22pt | Bold | Manrope | Section titles |
| `title3` | 18pt | SemiBold | Manrope | Card headlines |
| `headline` | 16pt | SemiBold | Manrope | Primary card body |
| `body` | 14pt | Regular | Manrope | General body text |
| `callout` | 13pt | Medium | Manrope | Source labels, metadata |
| `footnote` | 12pt | Regular | Manrope | Secondary metadata |
| `caption1` | 11pt | Medium | Manrope | Captions, pill labels |
| `caption2` | 10pt | Bold | Manrope | Section headers (tracked +1.2pt) |
| `badge` | 10pt | ExtraBold | Manrope | Badges (tracked +1.5pt, all caps) |

Add `Theme.Fonts.scale(_ role:)` as a single lookup function to replace the scattered `manrope(_ size:, weight:)` calls.

### 5.3 Corner Radius System

```
cornerRadius.small  = 8    // inner chips, toggles
cornerRadius.medium = 12   // sort controls, pills
cornerRadius.card   = 20   // cards (keep existing)
cornerRadius.hero   = 28   // hero panels
cornerRadius.sheet  = 32   // bottom sheets
```

---

## 6. Component Redesigns

### 6.1 Floating Dock → Liquid Glass Dock

**Current:** `.ultraThinMaterial` capsule with `.stroke(borderSubtle)`.

**Proposed:**
- Migrate to `glassEffect(in: .capsule)` (iOS 26) as the primary material.
- The glow on the Pulse tab is good — generalize it: the capsule gets a soft inner glow in the active tab's accent colour (4pt blur, 0.25 opacity), not just for Pulse.
- On tab switch, the selected indicator pill morphs with `.matchedGeometryEffect` for a smooth position transition.
- Add haptic feedback on every tab tap (currently only on refresh).
- Shrink inactive tab labels to 9pt and expand active label to 11pt (subtle but signals selection).
- The dock should auto-hide after 3 seconds of scroll and reappear on scroll stop or tap — like the keyboard-aware hidden behaviour browsers use.

```swift
// Conceptual direction (not final code)
.background(
    Capsule()
        .glassEffect()
        .innerGlow(color: selectedTab.accentColor, radius: 4, opacity: 0.25)
)
.animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedTab)
```

### 6.2 GlanceCardView — Restructured Layout

**Current:** Header (icon + badge + age + refresh) → Body → Footer (source + "View hub")

**Proposed:**
```
┌─────────────────────────────────────┐
│ ● MADRID              ↻    2m ago  │  ← accent dot instead of SF Symbol
│─────────────────────────────────────│
│                                     │
│   [Card-specific hero content]      │  ← more vertical breathing room
│                                     │
│─────────────────────────────────────│
│ via apple           View hub  ›     │
└─────────────────────────────────────┘
```

Changes:
- Replace the SF Symbol icon with an 8pt filled circle in the card's accent colour (like a status dot — more elegant, less icon soup).
- Move the age pill to the trailing side of the header row, aligned with refresh button.
- The refresh button becomes a small `arrow.clockwise` without a surrounding tap zone — tap the age pill itself to refresh (larger tap target, single action area).
- The "View hub" link becomes a full-width tappable footer row with a subtle `chevron.right` that uses the card's accent colour, increasing tap target from ~80pt to full card width.
- Add a 1px `borderSubtle` stroke to each card via `.overlay(RoundedRectangle(cornerRadius: 20).stroke(borderSubtle, lineWidth: 1))` — invisible in most contexts but prevents cards from bleeding into the canvas.

### 6.3 Pulse Feed — Variable Card Heights & Priority Ordering

**Current:** Four identical-sized cards in a fixed `ForEach` order.

**Proposed:**
- Cards are ordered by data freshness and relevance. The card with the most recently updated data or an active live event (e.g. match in progress) floats to the top automatically.
- The "lead card" — whichever is first — gets **16pt more vertical padding** and a slightly **larger headline size** to signal priority.
- Add a `pinnedCard` concept: if Real Madrid is in a live match, the Madrid card gets a `LIVE` pulsing badge and renders at 1.15× height.
- Cards animate their position changes with `.animation(.spring(response: 0.5, dampingFraction: 0.8), value: cardOrder)`.

### 6.4 Hub View Heroes

Every hub detail view should open with a distinct hero section instead of just a large navigation title.

**Madrid Hub:**
```
┌──────────────────────────────────┐
│  [amber gradient band, 180pt]    │
│                                  │
│  Real Madrid    RM badge (64pt) │
│  La Liga · 2nd  ·  38pts        │
│                                  │
│  LAST RESULT: W  3–1  vs Barça  │ ← large display-weight score
└──────────────────────────────────┘
```
- Full-bleed amber-tinted gradient panel using the club badge as a blurred background image.
- The score uses `display` size (40pt ExtraBold) — it's the most important data point.
- Next match shows as a bottom-attached pill inside the hero: "Next: Sat 14 Sep · Bernabéu".

**Pokémon GO Hub:**
- Rose-tinted hero with the priority Pokémon's sprite as the background (blurred + darkened).
- Large "5★ RAID" type badge front and centre.
- CP range displayed in `display` size.

**GitHub Hub:**
- Remove the current plain header HStack. Replace with a 3-column stat strip:
  `[N repos] · [Top velocity: +M ⭐] · [N hrs ago]`  
  Rendered in a frosted `surface2` pill row, not free-floating text.
- The sort control becomes a segmented pill with a morphing underline indicator instead of a filled-background toggle.

**AI Intel Hub:**
- Cyan-tinted hero with a rotating set of 3–4 keyword tags from the current articles (FRONTIER LABS, OPEN WEIGHTS, etc.) rendered as floating chips.
- No need for the current `HubSectionCard` wrapper — each article becomes a standalone card with the same visual grammar as the Pulse feed cards.

### 6.5 SkeletonView — Per-Card Skeletons

Replace the generic three-rectangle skeleton with card-specific skeleton layouts:

- **Madrid skeleton**: Two wide rectangles (score row) + three narrower rows (scorers) + a strip of 5 small squares (form).
- **PoGo skeleton**: A tall hero rectangle + 5 medium rows.
- **GitHub skeleton**: A stat strip + 6 repo row shapes (avatar circle + two lines).
- **AI Intel skeleton**: 3 article card shapes (tag chip + headline + two bullet lines).

All shimmer animations stay. This removes the jarring mismatch between skeleton and actual content.

### 6.6 Source/Age Indicators

**Current:** Age rendered as a text string coloured green/amber/red.

**Proposed:**
- Replace with a `StatusDot` component: a 6pt filled circle in the appropriate colour, with the age text trailing it.
- Green `●` for < 5min. Amber `●` for < 30min. Red `●` for stale. Grey `●` for offline.
- This is scannable at a glance without reading the timestamp.
- AI source indicator (`via apple` / `via gemini` / `via fallback`) gets a matching SF Symbol prefix: `brain.head.profile` for Apple Intelligence, `sparkles` for Gemini, `doc.text` for raw fallback.

---

## 7. Screen-by-Screen Redesign

### 7.1 Pulse Feed

```
Navigation bar: inline "Glance" + PulseDot (keep) + refresh button (keep)

ScrollView:
  ┌── Lead Card (first by freshness) ─────────────────┐
  │  Slightly taller, 22pt headline, top of stack     │
  └────────────────────────────────────────────────────┘
  
  ┌── Card 2 ──────────────────────────────────────────┐
  │  Standard height, 16pt headline                    │
  └────────────────────────────────────────────────────┘
  
  ┌── Card 3 ──────────────────────────────────────────┐
  └────────────────────────────────────────────────────┘
  
  ┌── Card 4 ──────────────────────────────────────────┐
  └────────────────────────────────────────────────────┘
  
  [Bottom padding for dock: 100pt, keep]

Changes:
- `.background(surface1)` → add `.overlay(strokeBorder)` per card.
- Card-to-card spacing: 12pt → 10pt (tighter feed, more content visible).
- Card corner radius: 16pt → 20pt (already Theme.cornerRadius, fix PulseView inconsistency).
- Horizontal padding: 12pt → 16pt (match card internal padding for alignment).
```

### 7.2 Madrid Hub

```
hero(fullBleed, height: 220pt)
  ├── blurred badge background
  ├── club name (title1, bold)
  ├── standing subtitle (callout, muted)
  └── score hero (display, bold) OR next match pill

Section: FORM (W/D/L tiles, keep design, increase tile size to 36pt)
Section: LA LIGA (standing table card — add position indicator bar)
Section: MANAGING MADRID (article rows with thumbnail if available)
Section: RELATED ARTICLES (Exa results, same pattern)
```

### 7.3 Pokémon GO Hub

```
hero(fullBleed, height: 200pt)
  ├── priority mon sprite (blurred bg)
  ├── raid tier badge (large, rose-tinted)
  └── CP range (display, bold)

HStack tier filter: pill segments (not scroll tabs)
  → [All] [1★] [3★] [5★] [Mega] [Shadow]
  → morphing selected indicator (matchedGeometryEffect)

Raid list: standard card rows with:
  → leading: type colour dot (12pt) + name
  → trailing: best CP number (callout, bold)
  → swipe right: "Mark as done" (dismisses from list)

Events section: timeline-style vertical list
  → date pill on the left, event name + countdown on the right
```

### 7.4 GitHub Hub

```
Stat strip (frosted surface2 pill, full-width):
  [47 repos] · [Hot: +312 ⭐ this week] · [2h ago]

Sort control: 3-option morphing segment (matchedGeometryEffect underline)

Repo rows:
  ├── owner avatar (28pt circle, keep CachedAsyncImage)
  ├── repo full name (headline, bold) + language dot
  ├── description (body, 2-line limit)
  └── star count (callout) + velocity badge (+N, emerald if hot)

  → swipe left: open in browser
  → long press: copy URL / share sheet

Rate limit footer: keep, style as caption2, muted, centred
```

### 7.5 AI Intel Hub

```
Hero strip (cyan-tinted, 140pt):
  → floating keyword chips rotating from article tags
  → "AI INTEL" label (badge font)
  → source line "via Exa + Apple Intelligence" (caption2)

Article cards (standalone, not nested in HubSectionCard):
  ├── tag badge (FRONTIER LABS / OPEN WEIGHTS)
  ├── headline (title3, semibold, 3-line limit)
  ├── 2 bullet points (body, secondary)
  ├── benchmark pills (keep)
  └── source + date footer (caption1, muted)

  → tap: push to AiIntelArticleView (keep)
  → long press: share headline + URL
```

### 7.6 Sources / API Keys

**Rename tab**: "Keys" → "Sources" (already the accessibility label; match the tab short label to it)

```
NavigationBar: "Data Sources"

Section: ON-DEVICE AI
  ├── Status indicator (large icon: brain.head.profile + status dot)
  └── "Apple Intelligence available" / "Unavailable on this device"

Section: EXA SEARCH
  ├── Key field (keep secure + eye toggle)
  ├── Status badge
  └── Get key link (small, muted)

Section: GEMINI
  ├── Key field
  ├── Model picker → inline 3-option segmented control (not radio buttons)
  └── Status badge

CTA: "Save Keys" button — full-width, emerald fill, at the bottom
```

### 7.7 Settings

```
Header: Keep branding block (good design, keep it)

Section: APPEARANCE
  → 3-option selector (keep layout, refine selection border to 2px with glow)

Section: CACHE
  → Per-card rows with StatusDot age indicator (not plain text)
  → "Clear All" → destructive button at bottom, not inline

Section: DISPLAY
  → NEW: "Lead Card" picker — allow user to pin one card to always appear first
  → NEW: "Compact Mode" toggle — reduce card padding to 12pt for denser feed

Section: ABOUT
  → App version + build number
  → Link: "Privacy Policy", "Contact"
  → "Built with ♥ and Apple Intelligence"
```

---

## 8. Motion & Animation

### 8.1 Card State Transitions

| Transition | Current | Proposed |
|-----------|---------|----------|
| loading → ready | instant switch | `.opacity` + `.scale(0.97 → 1.0)` over 0.3s |
| ready → stale | no visual change | subtle desaturation of age dot to amber |
| stale → ready | instant | same as loading → ready |
| error appear | instant | gentle `.move(edge: .bottom)` + fade in |

### 8.2 Tab Switching

- Tab content: `.transition(.asymmetric(insertion: .opacity, removal: .opacity))` — keep.
- Dock indicator: use `matchedGeometryEffect(id: "dockPill", in: dockNamespace)` for a morphing pill that slides to the active tab.
- Dock accent glow: currently only on Pulse — generalize with `tab.accentColor.opacity(0.3)`.

### 8.3 Pull-to-Refresh

Replace the default `ProgressView` spinner with a custom refresh indicator:
- A 20pt pulsing ring in the stream's accent colour.
- On release: the ring fills solid, then shrinks to 0 as content begins loading.
- This mirrors the `PulseDot` animation already in the codebase — reuse the component.

### 8.4 Card Entrance

The existing `.cardEntrance(index:)` modifier is good. Refine it:
- Stagger delay: 0.08s per card index (current is fine).
- Scale range: 0.96 → 1.0 (current) → tighten to 0.98 → 1.0 for subtlety.
- On hub views, section cards should also entrance-animate with a 0.05s stagger.

---

## 9. Accessibility

All changes maintain and extend the existing accessibility foundation:

- `StatusDot` includes `.accessibilityLabel("Fresh, updated 2 minutes ago")` etc.
- Hero sections use `.accessibilityElement(children: .contain)` with a combined label.
- Variable card height (lead card being taller) is a purely visual change — the VoiceOver reading order remains top-to-bottom.
- The auto-hiding dock behaviour is disabled when VoiceOver is active — always visible.
- All new animations respect `@Environment(\.accessibilityReduceMotion)`.
- New swipe actions include `.accessibilityLabel` and `.accessibilityHint`.
- Liquid Glass dock maintains sufficient contrast for the tab labels against the glass material in both light and dark modes.

---

## 10. Implementation Roadmap

Ordered by impact-to-effort ratio, safe to implement one phase at a time.

### Phase 1 — Quick Wins (1–2 days)
1. Fix the `cornerRadius` inconsistency in `PulseView` (16 → 20).
2. Update horizontal padding in `PulseView` (12 → 16).
3. Add 1px `borderSubtle` stroke overlay to each `GlanceCardView`.
4. Replace the generic `SkeletonView` with per-card skeleton layouts.
5. Add `StatusDot` component and replace the text-only age indicators.
6. Generalize the dock accent glow to all tabs (not just Pulse).

### Phase 2 — Typography & Spacing (2–3 days)
7. Define `Theme.Fonts.scale(_ role:)` and migrate all font calls in the codebase.
8. Refine the colour palette values (canvas, surfaces, text hierarchy).
9. Apply the named corner radius constants throughout.
10. Tighten card-to-card spacing from 16pt to 10pt.

### Phase 3 — Hero Sections (3–4 days)
11. Add hero section to `MadridHubView` (gradient band + display-weight score).
12. Add hero section to `PoGoHubView` (sprite bg + tier badge).
13. Replace GitHub stats HStack with the frosted stat strip.
14. Replace AI Intel `HubSectionCard` wrapper with standalone article cards + hero strip.

### Phase 4 — Dock & Navigation (2–3 days)
15. Migrate floating dock to `glassEffect()` (requires iOS 26 target).
16. Add `matchedGeometryEffect` morphing indicator to dock.
17. Implement dock auto-hide on scroll.

### Phase 5 — Motion & Interaction (3–4 days)
18. Upgrade card state transition animations.
19. Build custom pull-to-refresh indicator.
20. Add swipe actions to repo rows and raid rows.
21. Add long-press context menus (share, refresh) across all list rows.
22. Add lead card elevation (first card gets extra padding + larger headline).

### Phase 6 — Settings & Sources Polish (1–2 days)
23. Redesign SourcesView with section headers and full-width Save CTA.
24. Add "Lead Card" picker and "Compact Mode" toggle to SettingsView.
25. Replace radio-style model picker with inline segmented control.

---

## 11. Design Decisions Not Made

Items left intentionally out of scope for this proposal:

- **Onboarding flow** — The app has no onboarding. Adding one is a separate product decision; the current "go to Sources and add your keys" implicit flow works for the technical audience this app targets.
- **Widgets** — The card-based data model maps naturally to WidgetKit, but this is a separate surface with its own design requirements.
- **Light mode** — The app has a light mode toggle but the design is dark-first. A full light mode audit would be a separate phase.
- **iPad layout** — `Info.plist` locks to portrait-only. If that changes, a column layout for the Pulse feed would be needed.
- **App icon** — The `bolt.fill` SF Symbol on an emerald background is functional. A custom icon would improve App Store presence but is out of scope here.

---

## 12. Reference Design Vocabulary

Quick reference for use when implementing:

```
Surface layer:     canvas < surface1 < surface2 < surface3
Navigation chrome: Liquid Glass (glassEffect)
Content borders:   1px borderSubtle only
Accent colours:    4 semantics (amber/rose/emerald/cyan) + accent for CTAs
Font family:       Manrope throughout (Hanken Grotesk reserved for display-scale)
Radius rhythm:     8 → 12 → 20 → 28 → 32 (small to sheet)
Motion feel:       spring(response: 0.3–0.4, dampingFraction: 0.75–0.8)
Status signals:    StatusDot (6pt coloured circle) for freshness
AI source:         SF Symbol prefix (brain / sparkles / doc.text)
```

---

*Research sources: [Linear redesign blog](https://linear.app/blog/how-we-redesigned-the-linear-ui), [Vercel Geist design system](https://vercel.com/geist/colors), [Apple WWDC 2025 — Build a SwiftUI app with Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/323), [iOS 26 Liquid Glass reference](https://github.com/conorluddy/LiquidGlassReference), [SaaS dashboard design examples 2026](https://adminlte.io/blog/saas-dashboard-design-examples/), [Apple HIG design system breakdown](https://superdesign.dev/blog/apple-design-system)*

---

## 13. Article & Detail View Redesign (Read-Friendly)

This section covers all five detail screens that users read through at length. The goal is a calm, low-fatigue reading experience — inspired by how Bear, Reeder, and Apple News handle long-form content.

---

### 13.1 Shared Reading Principles (apply to all five views)

These rules apply globally across every detail/article screen:

**Line length control — max readable width**
All prose content is constrained to a comfortable column width. On a standard iPhone (390pt wide) with 20pt side padding, this gives ~350pt of text. No change needed for short metadata rows, but body paragraphs get an explicit `.frame(maxWidth: 640)` + `.frame(maxWidth: .infinity)` combo so they don't stretch unnaturally on wider devices (iPad, large iPhone in landscape).

**Body text size and weight**
Current body text across article views is 13–15pt Regular in `textSecondary`. For sustained reading this is too small and too low-contrast. New standard:
- Body/article text: **17pt Regular**, `textPrimary` (not secondary)
- Supporting callouts (author, date, source): **13pt Regular**, `textMuted`
- Section labels: keep existing 10pt ExtraBold tracked caps

**Line spacing**
SwiftUI's default line spacing for Manrope at 17pt feels tight. Add `.lineSpacing(5)` to all body `Text` blocks. This gives ~1.4× line height — the sweet spot for dark-background reading (Bear uses 1.4–1.5×).

**Paragraph spacing**
The Madrid article view currently renders the entire stripped article as one `Text` block. Paragraphs are separated with `\n\n`. This looks like a wall of text. Instead, split the content on `\n\n`, render each paragraph as its own `Text` view with 12pt `spacing` between them in the `VStack`. Empty paragraphs are filtered out.

**Horizontal padding**
Current padding is `Theme.cardPadding` (16pt) throughout. Article reading zones get **20pt horizontal padding** — a small but meaningful increase that moves the text edge away from the screen edge, reducing the visual noise of the bezel.

**Background**
Keep `Theme.canvas`. Do not introduce a sepia or warm tint — it goes against the dark-first identity. The reading comfort comes from line spacing and contrast, not a colour shift.

**Navigation title**
All detail views currently show `.navigationBarTitleDisplayMode(.inline)` with generic titles like "Article" or "AI Intel". Replace with the content's own title truncated to one line, or a category label (e.g. "Managing Madrid", "AI Intel", "GitHub"). This gives the back-navigation a meaningful label.

**Bottom padding**
Keep `.padding(.bottom, 100)` for dock clearance.

**Scroll indicators**
All detail views: `.scrollIndicators(.hidden)` — indicators add visual clutter during reading.

---

### 13.2 MadridArticleView

**Current issues:**
- The entire article body is a single monolithic `Text` block — no paragraph breaks visually, reads like a wall.
- Body font is 15pt `textSecondary` — too dim and slightly small for sustained reading.
- No visual separator between the metadata row (author/date) and the article body.
- The "Open on Managing Madrid" CTA is inlined with no visual breathing room at the end.
- Navigation title says "Article" — meaningless as a back-button label.

**Proposed changes:**

```
NavigationTitle: "Managing Madrid"  (category label, not article title)

Layout (top to bottom, 20pt horizontal padding):

1. CATEGORY BADGE
   → keep existing amber capsule pill, no change

2. ARTICLE TITLE
   → font: 26pt ExtraBold Manrope (up from 22pt Bold)
   → foreground: textPrimary
   → lineSpacing: 3 (tighter — this is a headline, not prose)
   → fixedSize(horizontal: false, vertical: true)

3. METADATA ROW (author · date)
   → single HStack, separated by "·" middot instead of two separate HStacks
   → font: 13pt Regular, textMuted
   → accessibilityElement(children: .combine)
   → NO SF Symbol icons — they add noise without meaning at this size

4. HAIRLINE DIVIDER
   → 1pt height, borderSubtle colour, full-width
   → 4pt top/bottom spacing (tighter than current Divider default)

5. ARTICLE BODY
   → split content string on "\n\n" → [String]
   → filter out strings that are whitespace-only
   → render each as its own Text view in a VStack(spacing: 14)
   → font: 17pt Regular Manrope
   → foreground: textPrimary  ← was textSecondary
   → lineSpacing: 5
   → fixedSize(horizontal: false, vertical: true)
   → selectable text: .textSelection(.enabled)  ← NEW — lets users copy quotes

6. READ ORIGINAL CTA
   → full-width, amber-tinted, keep current shape
   → add 24pt top spacing before it (visual paragraph break before the action)
   → button label: "Read on Managing Madrid  ↗" (clearer than "Open on...")
```

**stripMedia helper:** Keep the existing HTML stripping logic. No changes needed there — it already handles the common cases well.

---

### 13.3 AiIntelArticleView

**Current issues:**
- Hero image clips at 200pt height with `.scaledToFill` — important content is cropped unpredictably.
- Metadata row packs source + author + date into one `HStack` with SF Symbol icons — crowded at 12pt.
- Benchmarks section appears before "Key Points" — wrong reading order (headline → key points → then benchmarks as supplementary data).
- Numbered key points use a left-aligned `Text("\(index+1)")` in a 20pt-wide frame — looks awkward, not like a natural reading list.
- Full Coverage is behind a tap-to-expand toggle — fine, but the toggle button itself is small and ambiguous.
- Body highlights use `"• \(highlight)"` string prefix — functional but not as readable as a proper indented list.

**Proposed changes:**

```
NavigationTitle: "AI Intel"

Layout:

1. HERO IMAGE (if present)
   → height: 220pt (up from 200)
   → scaledToFill with .clipped() stays — but add a bottom gradient overlay
     (surface1 → clear, 60pt tall) so the tag badge below doesn't clash visually
   → if no image: no placeholder box — just skip cleanly

2. TAG BADGE
   → keep BadgePill, no change

3. HEADLINE
   → font: 26pt ExtraBold Manrope (up from 22pt Bold)
   → foreground: textPrimary
   → lineSpacing: 3
   → fixedSize vertical

4. METADATA ROW
   → single line: "source  ·  author  ·  date"
   → no SF Symbol icons
   → font: 13pt Regular, textMuted
   → if any field is empty, skip it (no dangling middots)

5. HAIRLINE DIVIDER (same as Madrid)

6. KEY POINTS  ← moved before benchmarks
   → section header: "KEY POINTS" (tracked caps, textMuted)
   → each bullet: VStack row with:
       - leading: filled circle 6pt in cardCyan  (not a number — cleaner)
       - text: 16pt Regular, textPrimary, lineSpacing: 4
   → item spacing: 14pt in the VStack

7. BENCHMARKS (if present)  ← moved after key points
   → section header: "BENCHMARKS" in cardCyan
   → FlowLayout of capsule pills — keep existing style
   → add .accessibilityLabel("Benchmark: \(bench)") per pill

8. FULL COVERAGE (expandable)
   → toggle button: replace the "FULL COVERAGE ▾" HStack with a full-width
     surface1 rounded button: "Show full coverage  ▾" / "Hide  ▴"
     → font: 13pt SemiBold, accent colour
     → background: surface1, cornerRadius: 12
     → height: 44pt (proper tap target)
   → expanded content: each highlight as its own Text view
     → font: 15pt Regular, textSecondary, lineSpacing: 4
     → no bullet prefix — clean paragraph style

9. READ ORIGINAL CTA
   → same pattern as Madrid: full-width, cyan-tinted, 24pt top spacing
   → label: "Read original  ↗"
```

---

### 13.4 RepoDetailView

This is not a reading-heavy view — it's data-heavy. The goals here are **scannability** and **data clarity**, not long-form reading comfort. Different set of changes.

**Current issues:**
- The stats grid (`LazyVGrid` 4 columns) renders icon + number + label in a very small tile — numbers are 16pt in a `surface1` box, feels cramped.
- The owner avatar + repo name header doesn't have enough vertical breathing room.
- The description text is 13pt `textSecondary` and is limited to 3 lines — on the detail view it should show in full.
- The pills scrollview (language, license, wiki, pages) has no section label, so context is unclear.
- Topics section uses a plain "TOPICS" label and works fine — no change needed.

**Proposed changes:**

```
NavigationTitle: keep repo.fullName (already correct)
NavigationBarTitleDisplayMode: .inline (keep)

Layout:

1. REPO HEADER
   → owner avatar: keep 48pt circle
   → repo name: keep 18pt Bold — but split into:
       - owner name: 13pt Regular, textMuted  (on its own line above)
       - repo name: 20pt Bold, textPrimary     (clearer visual hierarchy)
   → description: REMOVE lineLimit(3) — show full description on detail view
     → font: 15pt Regular, textSecondary, lineSpacing: 4

2. DATE ROW
   → keep as-is, just remove SF Symbol icons to reduce noise
   → "Pushed 3 days ago  ·  Created Jul 2010"  (middot separator)

3. STATS GRID
   → increase stat number size from 16pt → 22pt Bold monospacedDigit
   → increase tile vertical padding from 12pt → 16pt
   → icon size: .font(.system(size: 14)) instead of default title3
   → label: keep 10pt textMuted

4. VELOCITY PILL
   → keep exact design — it's already well done

5. ATTRIBUTES ROW  ← rename from "pills"
   → add section header: "ATTRIBUTES" (tracked caps, textMuted)
   → make it a FlowLayout instead of horizontal scroll — avoids the hidden-content problem

6. TOPICS
   → no change — already well designed

7. README TEASER  ← NEW (future placeholder, no data today)
   → commented-out section with a TODO note for when readme fetching is added

8. OPEN ON GITHUB CTA
   → same full-width pattern, 24pt top spacing
   → label: "Open on GitHub  ↗" (keep)
```

---

### 13.5 RaidDetailView

Data-focused view, not long-form reading. Focus: **visual punch and scan speed**.

**Current issues:**
- The Pokémon sprite renders with `scaledToFit` inside a 200pt frame — small sprites have lots of dead space around them.
- Name and shiny badge sit on the same HStack line — crowded when the name is long.
- The tier badge is orphaned below the name row with no alignment context.
- CP section renders two `VStack`s side by side with no visual container — they float on the canvas.
- No clear visual hierarchy between the combat power numbers and their labels.

**Proposed changes:**

```
NavigationTitle: raid.name (already correct)

Layout:

1. HERO SECTION  ← redesigned
   → full-width surface1 panel, cornerRadius: 20, height: 240pt
   → sprite centered in the panel with scaledToFit, max height 160pt
     (removes dead space; sprite never clips)
   → TIER BADGE overlaid at top-left corner of the panel (padding 12pt)
   → SHINY BADGE overlaid at top-right corner (✨ Shiny, rose capsule)

2. NAME ROW (below hero panel)
   → raid.name: 26pt ExtraBold, textPrimary
   → shiny indicator moved to hero overlay (see above)

3. TYPES
   → section header: "TYPE" (tracked caps)
   → keep type pill row — increase pill height slightly (padding .vertical: 6)

4. COMBAT POWER  ← redesigned
   → section header: "COMBAT POWER" (tracked caps)
   → replace the free-floating HStack with a surface1 card (HubSectionCard pattern):
       Left column: "Normal"  label (12pt, textMuted) + CP range (24pt Bold, textPrimary)
       Right column: "Weather Boosted" label + CP range (24pt Bold, cardRose)
       Divider line between columns
   → this gives the numbers the prominence they deserve

5. WEATHER BOOST
   → keep existing style, no change

6. NO external link CTA  ← Pokémon raid has no external URL in the model
```

---

### 13.6 EventDetailView

**Current issues:**
- Hero image uses `scaledToFit` without a fixed height — on very wide/short images it could render tiny.
- Title and type badge are in a `VStack` but the date range (`start → end`) is on the same HStack as the type badge, making both feel cramped.
- The `heading` field (the event description) is only 14pt `textSecondary` — this is the primary readable content on this screen, it should be bigger.
- The CTA ("View on LeekDuck") has no top spacing.

**Proposed changes:**

```
NavigationTitle: event.eventType  (e.g. "Community Day" — more useful back-label than the full name)

Layout:

1. HERO IMAGE (if present)
   → fixed height: 220pt, scaledToFill + .clipped()
   → bottom fade gradient overlay (surface1 → .clear, 80pt) so title below reads cleanly
   → if no image: compact placeholder panel (100pt, surface1 tint, event type label centred)

2. EVENT NAME
   → 26pt ExtraBold, textPrimary, lineSpacing: 3
   → fixedSize vertical — full name visible, no truncation

3. META ROW  ← redesigned
   → type badge: keep rose capsule pill
   → date range: separate line below the badge row
     "15 Sep 2026  →  17 Sep 2026"
     font: 14pt Regular, textMuted, with a calendar SF Symbol prefix

4. DESCRIPTION (heading field)
   → the event heading is the main readable content — treat it like body copy:
     font: 17pt Regular, textPrimary, lineSpacing: 5
   → fixedSize vertical
   → add a hairline divider above it (same pattern as Madrid/AiIntel)

5. VIEW ON LEEKDUCK CTA
   → full-width rose-tinted button, 24pt top spacing
   → label: "View on LeekDuck  ↗"
```

---

### 13.7 Summary of Reading-Specific Changes

| Change | Affected views | Rationale |
|--------|---------------|-----------|
| Body text: 17pt Regular, `textPrimary` | Madrid, AiIntel (highlights), EventDetail (heading) | Minimum comfortable size for sustained reading; full contrast |
| `lineSpacing(5)` on prose | Madrid, AiIntel, Event | ~1.4× line height — prevents eye-strain on dark bg |
| Paragraph splitting (per-`Text` VStack) | Madrid | Removes wall-of-text effect |
| `.textSelection(.enabled)` | Madrid body | Users quote and share article snippets |
| Remove SF Symbol icons from metadata rows | All | Reduces clutter at small sizes; middot separator is cleaner |
| 20pt horizontal padding | All | Moves text away from screen edge |
| `.scrollIndicators(.hidden)` | All | Cleaner reading experience |
| Description: no `lineLimit` | RepoDetail, EventDetail | Detail views should show full content |
| Bigger headline: 26pt ExtraBold | Madrid, AiIntel, Event, Raid | Creates strong visual anchor at top of reading flow |
| Hero gradient overlay | AiIntel, Event | Prevents busy images fighting with title text |
| CTA spacing: 24pt before action button | All | Clear visual separation between content and action |
| Navigation title as category label | Madrid, AiIntel | Meaningful back-button label |
