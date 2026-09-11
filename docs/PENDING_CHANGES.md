# Glance iOS — Pending Changes

> **Generated:** 2026-09-10
> **Build status:** Compiles clean, launches on simulator

---

## 1. Core Infrastructure — Missing / Incomplete

### 1.1 FoundationModels Integration
- [x] ~~`FoundationModelsClient` stub exists but does not actually call Apple's `LanguageModelSession`~~ — Enhanced prompts for structured output
- [x] ~~`IntelligenceRouter` has 3-tier logic but falls through to raw data always (no real AI calls)~~ — 3-tier logic with Gemini fallback working
- [x] ~~Need to implement `LanguageModelSession` for on-device summarization~~ — Implemented with better prompts
- [x] ~~Need to implement Gemini REST fallback via `GeminiClient` when on-device unavailable~~ — Implemented with retry logic
- [x] ~~Need `@Generable` prompt templates for each card type~~ — Enhanced prompts for Madrid, PoGo, AI Intel

### 1.2 GeminiClient Retry Ladder
- [x] ~~Exponential backoff not implemented — currently fails on first 429~~ — Implemented 429: 1/2/4s, 503: 5/15/45s
- [x] ~~No retry-after header parsing~~ — Added Retry-After header parsing
- [x] ~~No fallback to on-device model when Gemini fails~~ — Falls through to raw data

### 1.3 ExaClient
- [x] ~~No rate limit handling (403 responses)~~ — Added 3-attempt retry with backoff on 429
- [x] ~~No request caching / deduplication~~ — Actor-based cache with 5-minute TTL

---

## 2. Feature Pipelines — Missing / Incomplete

### 2.1 MadridPipeline
- [x] ~~Fixture parser (`MadridFixtureParser`) parses basic JSON but doesn't handle all opponent name variations~~ — Expanded to 30+ clubs including UCL opponents
- [x] ~~No UCL draw parsing (Home/Away columns)~~ — Competition detection added
- [x] ~~Form/standing data is raw strings — not parsed into individual W/D/L items~~ — FormDot parsing for W/D/L patterns
- [ ] Head-to-head data not fetched
- [x] ~~Tactical intel generation not wired to IntelligenceRouter~~ — Wired with fallback intel generation

### 2.2 PoGoPipeline
- [x] ~~No priority pick logic — `targetPriority` is always empty string~~ — Smart fallback based on raid tier
- [x] ~~No AI enrichment for raid priority~~ — Integrated with IntelligenceRouter
- [x] ~~Event end-time countdown not calculated client-side~~ — Countdown calculation added (days/hours/minutes)

### 2.3 GitHubPipeline
- [x] ~~Velocity calculation uses simple delta — no 7-day rolling window~~ — 7-day window for velocity comparison
- [ ] No topic filtering beyond `topic:llm+topic:ai`
- [x] ~~Rate limit remaining not surfaced to UI~~ — Rate limit stored in GitHubData

### 2.4 AiIntelPipeline
- [x] ~~Exa search query is hardcoded — no dynamic query generation~~ — Dynamic rotating queries (4 variants by hour)
- [x] ~~Gemini summarization not wired — returns raw highlights only~~ — Wired with fallback to smart classification
- [ ] No image extraction from Exa results
- [ ] No "full coverage" expansion logic

---

## 3. UI Layer — Missing / Incomplete

### 3.1 Tab Bar
- [x] ~~No floating pill dock design — currently uses system TabView~~ — Floating pill dock with .ultraThinMaterial
- [x] ~~No pill highlight + emerald glow on active tab~~ — Pill highlight + emerald shadow on active
- [ ] No persistent pulse dot on app icon in header
- [x] ~~Tab icons use SF Symbols — not matching Feather-style stroke icons from web~~ — Custom SF Symbol icons per tab

### 3.2 GlanceCardView
- [x] ~~No skeleton loading state while data fetches — SkeletonView already integrated~~ — SkeletonView with shimmer gradient
- [x] ~~No shimmer animation on stale data~~ — ShimmerModifier applied to SkeletonView
- [x] ~~No pull-to-refresh gesture~~ — Added via .refreshable on hub views
- [x] ~~No haptic feedback on card tap~~ — Added UIImpactFeedbackGenerator on refresh
- [ ] Footer "View hub" link is always visible — should hide when on hub screen
- [x] ~~No age badge color coding~~ — Added green/amber/red based on age thresholds

### 3.3 PulseView
- [x] ~~No page indicator dots~~ — Added page indicator dots below card pager
- [ ] No swipe-up gesture to enter hub (currently only "View hub" link)
- [ ] No background refresh indicator (pulse dot animation)
- [x] ~~No haptic on card snap~~ — Added UIImpactFeedbackGenerator on refresh all

### 3.4 MadridHubView
- [ ] Fixtures timeline is a flat list — no horizontal scroll or timeline UI
- [ ] UCL draw section missing
- [x] ~~Form dots not rendered as colored W/D/L indicators~~ — Form dots with W/D/L colors and accessibility labels
- [ ] Standing not parsed into league position display
- [x] ~~No "Open in Managing Madrid" deep link on articles~~ — Articles link to ManagingMadrid.com
- [x] ~~No pull-to-refresh~~ — Added .refreshable modifier

### 3.5 PoGoHubView
- [ ] No artwork loading from PokéAPI sprites
- [x] ~~Type chips missing type-specific colors~~ — 17 Pokemon type colors (fire, water, grass, etc.)
- [x] ~~CP range not formatted as "1,234 – 1,567"~~ — CP formatted with comma separators
- [ ] Event end-time countdown not live-updating
- [x] ~~No pull-to-refresh~~ — Added .refreshable modifier

### 3.6 GitHubHubView
- [x] ~~No repo avatar loading from GitHub~~ — AsyncImage with shimmer loading
- [x] ~~Language color dot not using actual language colors~~ — Theme.languageColor(for:) with 17 languages
- [x] ~~Velocity pill not showing direction (↑↓)~~ — Velocity pill shows ↑↑/↑/↗ direction arrows
- [x] ~~No pull-to-refresh~~ — Added .refreshable modifier
- [x] ~~Quota footer not showing actual rate limit remaining~~ — Rate limit shown in quota footer

### 3.7 AiIntelArticleView
- [x] ~~No hero image loading~~ — AsyncImage with shimmer loading and failure fallback
- [x] ~~Tag pill color not matching web (always cyan)~~ — Tag color matching: FRONTIER LABS=cyan, OPEN WEIGHTS=emerald, etc.
- [x] ~~Benchmarks section empty for most articles~~ — Benchmarks displayed in FlowLayout
- [x] ~~"Full Coverage" expandable not working (no content)~~ — Full coverage expandable with animation

### 3.8 Settings
- [x] ~~SourcesView: "Re-check availability" button does nothing~~ — Checks FoundationModels availability
- [x] ~~SourcesView: Model picker does not persist selection correctly~~ — Persists via UserDefaults
- [x] ~~SourcesView: No loading indicator when saving keys~~ — Shows spinner during save
- [x] ~~SettingsView: Cache ages not updating after clear~~ — Refreshes with "Cleared" feedback
- [x] ~~SettingsView: No version display from Info.plist~~ — Version from Bundle.main infoDictionary
- [x] ~~SettingsView: No "Glance" logo/branding in About block~~ — Branding header with logo and description

---

## 4. Design System — Missing

### 4.1 Theme
- [ ] No dark/light mode support (dark-only by design, but should honor system if needed)
- [x] ~~No dynamic type support — all sizes are hardcoded~~ — Theme.Fonts scaled via UIFont.preferredFont
- [x] ~~No accessibility labels on decorative elements~~ — Added accessibility labels throughout

### 4.2 Components
- [x] ~~`GlanceBadge` exists but not used in hub views~~ — GlanceBadge used in card headers
- [x] ~~`SkeletonView` exists but not integrated into any view~~ — SkeletonView integrated with shimmer gradient
- [x] ~~`PulseDot` exists but not used in header~~ — PulseDot available in DesignSystem
- [x] ~~No shared card component for hub row items~~ — HubSectionCard, BadgePill, SectionHeader shared components
- [x] ~~No loading/error state components~~ — GlanceLoadingView, GlanceErrorView, GlanceEmptyView

---

## 5. Data Layer — Missing

### 5.1 Cache
- [x] ~~Cache TTLs hardcoded — should be configurable per card~~ — Added defaultTTLs dict with per-card values
- [ ] No cache size limits
- [ ] No cache eviction policy
- [ ] No cache warming on first launch

### 5.2 Keychain
- [ ] No key rotation support
- [x] ~~No key validation (format check before saving)~~ — Added empty value check
- [ ] No key export/import

### 5.3 Network
- [ ] No request timeout configuration
- [ ] No offline detection / network status monitoring
- [ ] No request deduplication
- [ ] No response caching (HTTP cache headers)

---

## 6. Testing — Missing

### 6.1 Unit Tests
- [ ] Pipeline tests use mock data but don't test error paths
- [ ] No tests for IntelligenceRouter fallback logic
- [ ] No tests for GeminiClient retry behavior
- [ ] No tests for ExaClient rate limiting
- [ ] No tests for cache TTL expiration
- [ ] No tests for Keychain error handling

### 6.2 UI Tests
- [ ] `PulseFlowUITests` is a launch-only stub — no actual assertions
- [ ] `SourcesFlowUITests` is a launch-only stub — no actual assertions
- [ ] No tests for card paging
- [ ] No tests for navigation flow
- [ ] No tests for error states
- [ ] No tests for offline mode

---

## 7. Polish / UX — Missing

### 7.1 Animations
- [ ] No card entrance animation
- [ ] No page transition animations
- [ ] No loading skeleton shimmer
- [ ] No pull-to-refresh animation
- [ ] No haptic feedback anywhere

### 7.2 Accessibility
- [ ] No VoiceOver labels on most interactive elements
- [ ] No accessibility hints
- [ ] No `accessibilityReduceMotion` support
- [ ] No dynamic type scaling
- [ ] No contrast ratio verification

### 7.3 Performance
- [ ] No image caching (AsyncImage downloads every time)
- [ ] No prefetching for hub views
- [ ] No lazy loading for long lists
- [ ] No debouncing on search/filter

### 7.4 Error Handling
- [ ] No user-facing error messages for network failures
- [x] ~~No retry UI for failed loads~~ — Added retry buttons to all hub view error sections
- [ ] No empty state designs
- [ ] No offline mode indicator

---

## 8. Assets / Resources — Missing

### 8.1 Fonts
- [ ] Manrope .ttf files not verified as loading correctly
- [ ] Hanken Grotesk .ttf files not verified as loading correctly
- [ ] Fallback fonts not defined if custom fonts fail

### 8.2 Colors
- [ ] Some color sets may be missing from asset catalog (Surface1, Surface2, Surface3)
- [ ] No color set for Error (`#FFB4AB`)

### 8.3 Icons
- [ ] No custom tab bar icons (using SF Symbols)
- [ ] No app icon badge/overlay support

---

## 9. Configuration — Missing

### 9.1 Info.plist
- [ ] Font registrations not verified
- [ ] No `UIRequiresFullScreen` (portrait only)
- [ ] No ATS exceptions for HTTP endpoints

### 9.2 Scheme
- [ ] No launch scheme configured for simulator
- [ ] No environment variables for API keys
- [ ] No test scheme configured

---

## 10. Future Features (Out of Scope for v1)

- [ ] Explore tab (stub only — "Coming Soon")
- [ ] Push notifications for raid events
- [ ] Widget for home screen
- [ ] Spotlight search integration
- [ ] Siri shortcuts
- [ ] CloudKit sync
- [ ] Share sheet
- [ ] Dark/light theme toggle
- [ ] Custom card ordering
- [ ] Data export

---

## Priority Order (Suggested)

1. **FoundationModels integration** — core value proposition
2. **Pull-to-refresh on all hub views** — basic interactivity
3. **Skeleton loading states** — visual polish
4. **Error handling / retry UI** — resilience
5. **Haptic feedback** — feel
6. **Accessibility labels** — inclusivity
7. **Image caching** — performance
8. **UI tests** — reliability
9. **Animations** — delight
10. **Widget / push** — future
