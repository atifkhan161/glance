# Glance iOS — Pending Changes

> **Generated:** 2026-09-10
> **Build status:** Compiles clean, launches on simulator

---

## 1. Core Infrastructure — Missing / Incomplete

### 1.1 FoundationModels Integration
- [ ] `FoundationModelsClient` stub exists but does not actually call Apple's `LanguageModelSession`
- [ ] `IntelligenceRouter` has 3-tier logic but falls through to raw data always (no real AI calls)
- [ ] Need to implement `LanguageModelSession` for on-device summarization
- [ ] Need to implement Gemini REST fallback via `GeminiClient` when on-device unavailable
- [ ] Need `@Generable` prompt templates for each card type (Madrid tactical intel, PoGo priority, AI Intel briefs)

### 1.2 GeminiClient Retry Ladder
- [ ] Exponential backoff not implemented — currently fails on first 429
- [ ] No retry-after header parsing
- [ ] No fallback to on-device model when Gemini fails

### 1.3 ExaClient
- [ ] No rate limit handling (403 responses)
- [ ] No request caching / deduplication

---

## 2. Feature Pipelines — Missing / Incomplete

### 2.1 MadridPipeline
- [ ] Fixture parser (`MadridFixtureParser`) parses basic JSON but doesn't handle all opponent name variations
- [ ] No UCL draw parsing (Home/Away columns)
- [ ] Form/standing data is raw strings — not parsed into individual W/D/L items
- [ ] Head-to-head data not fetched
- [ ] Tactical intel generation not wired to IntelligenceRouter

### 2.2 PoGoPipeline
- [ ] No priority pick logic — `targetPriority` is always empty string
- [ ] No AI enrichment for raid priority
- [ ] Event end-time countdown not calculated client-side

### 2.3 GitHubPipeline
- [ ] Velocity calculation uses simple delta — no 7-day rolling window
- [ ] No topic filtering beyond `topic:llm+topic:ai`
- [ ] Rate limit remaining not surfaced to UI

### 2.4 AiIntelPipeline
- [ ] Exa search query is hardcoded — no dynamic query generation
- [ ] Gemini summarization not wired — returns raw highlights only
- [ ] No image extraction from Exa results
- [ ] No "full coverage" expansion logic

---

## 3. UI Layer — Missing / Incomplete

### 3.1 Tab Bar
- [ ] No floating pill dock design — currently uses system TabView
- [ ] No pill highlight + emerald glow on active tab
- [ ] No persistent pulse dot on app icon in header
- [ ] Tab icons use SF Symbols — not matching Feather-style stroke icons from web

### 3.2 GlanceCardView
- [ ] No skeleton loading state while data fetches
- [ ] No shimmer animation on stale data
- [ ] No pull-to-refresh gesture
- [ ] No haptic feedback on card tap
- [ ] Footer "View hub" link is always visible — should hide when on hub screen
- [ ] No age badge color coding (green < 5min, amber < 30min, red > 30min)

### 3.3 PulseView
- [ ] No page indicator dots
- [ ] No swipe-up gesture to enter hub (currently only "View hub" link)
- [ ] No background refresh indicator (pulse dot animation)
- [ ] No haptic on card snap

### 3.4 MadridHubView
- [ ] Fixtures timeline is a flat list — no horizontal scroll or timeline UI
- [ ] UCL draw section missing
- [ ] Form dots not rendered as colored W/D/L indicators
- [ ] Standing not parsed into league position display
- [ ] No "Open in Managing Madrid" deep link on articles
- [ ] No pull-to-refresh

### 3.5 PoGoHubView
- [ ] No artwork loading from PokéAPI sprites
- [ ] Type chips missing type-specific colors
- [ ] CP range not formatted as "1,234 – 1,567"
- [ ] Event end-time countdown not live-updating
- [ ] No pull-to-refresh

### 3.6 GitHubHubView
- [ ] No repo avatar loading from GitHub
- [ ] Language color dot not using actual language colors
- [ ] Velocity pill not showing direction (↑↓)
- [ ] No pull-to-refresh
- [ ] Quota footer not showing actual rate limit remaining

### 3.7 AiIntelArticleView
- [ ] No hero image loading
- [ ] Tag pill color not matching web (always cyan)
- [ ] Benchmarks section empty for most articles
- [ ] "Full Coverage" expandable not working (no content)

### 3.8 Settings
- [ ] SourcesView: "Re-check availability" button does nothing
- [ ] SourcesView: Model picker does not persist selection correctly
- [ ] SourcesView: No loading indicator when saving keys
- [ ] SettingsView: Cache ages not updating after clear
- [ ] SettingsView: No version display from Info.plist
- [ ] SettingsView: No "Glance" logo/branding in About block

---

## 4. Design System — Missing

### 4.1 Theme
- [ ] No dark/light mode support (dark-only by design, but should honor system if needed)
- [ ] No dynamic type support — all sizes are hardcoded
- [ ] No accessibility labels on decorative elements

### 4.2 Components
- [ ] `GlanceBadge` exists but not used in hub views
- [ ] `SkeletonView` exists but not integrated into any view
- [ ] `PulseDot` exists but not used in header
- [ ] No shared card component for hub row items
- [ ] No loading/error state components

---

## 5. Data Layer — Missing

### 5.1 Cache
- [ ] Cache TTLs hardcoded — should be configurable per card
- [ ] No cache size limits
- [ ] No cache eviction policy
- [ ] No cache warming on first launch

### 5.2 Keychain
- [ ] No key rotation support
- [ ] No key validation (format check before saving)
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
- [ ] No retry UI for failed loads
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
