# AGENTS.md

## Project Overview

Glance is a zero-backend iOS intelligence dashboard built with SwiftUI. It aggregates multiple data sources (Real Madrid, Pokémon GO, GitHub Trending, AI Intel, Custom RSS) into a unified card-based feed.

## Architecture Conventions

- **Feature-first organization** — Each data source lives in `Glance/Features/<Feature>/`
- **Pipeline pattern** — Each feature has a `<Feature>Pipeline.swift` that fetches, caches, and returns typed models
- **Core services** — Shared infrastructure in `Glance/Core/` (Network, Cache, Intelligence, Time)
- **Design system** — All styling through `Theme` enum in `Glance/DesignSystem/Theme.swift`
- **No storyboards** — Entirely SwiftUI, no Interface Builder files

## Code Style

- **Swift 5.9+** with strict concurrency (`Sendable`, actors)
- **`@Observable` macro** — Use for view models and stores (not `ObservableObject`)
- **`@Environment`** — Use `@Environment(AppState.self)` for dependency injection
- **Naming** — Files named after their primary type (`PulseView.swift`, `MadridPipeline.swift`)
- **No comments** — Code should be self-documenting; avoid inline comments
- **Theme access** — Always use `Theme.Colors.*`, `Theme.Fonts.*`, `Theme.Radius.*`

## Networking

- All API clients are in `Glance/Core/Network/`
- Use `URLSession` with async/await
- Return typed models, throw `GlanceError` on failure
- API keys stored in Keychain via `KeychainStore`

## Intelligence Routing

The `IntelligenceRouter` actor routes through multiple backends:
1. Apple Foundation Models (on-device, preferred)
2. Gemini API (cloud fallback)
3. Graceful degradation (return nil if both unavailable)

## Releasing

```bash
brew install zsign                                     # one-time
scripts/release.sh patch                               # 1.2 -> 1.2.1
scripts/release.sh minor|2.0.0                         # other bumps
```

Cuts a version end to end: bumps `Glance/Resources/Info.plist` (the app target uses this file with
`GENERATE_INFOPLIST_FILE = NO`, so it is the single source of truth for version and bundle id), builds
and ad-hoc signs the IPA, tags, publishes, regenerates `apps.json`, then downloads the published asset
back and compares SHA-256. Each version gets its own tag and a `Glance-<version>.ipa` asset so a
version's download URL cannot change after the fact.

`apps.json` (SideStore source) is **generated from the built IPA** — version, size and downloadURL are
read out of the product, never hand-typed. `version` there must equal `CFBundleShortVersionString`
exactly or SideStore silently stops offering updates. SideStore displays the *first* entry in
`versions[]` as latest regardless of version number, so that array is kept reverse-chronological.
It validates against https://raw.githubusercontent.com/SideStore/sidestore-source-types/main/schema.json
— note `versions[]` is required and the old top-level `version`/`downloadURL` fields are deprecated.

- **Never sign twice, and clear `.zsign_cache` first.** zsign caches per-file signature data in the CWD;
  a stale entry makes it emit `Info.plist=not bound` and the bundle fails verification with
  `invalid Info.plist`. This only triggers when the build changes the plist — i.e. on a version bump —
  so it looks like an intermittent release failure. `scripts/build-ipa.sh` clears the cache and uses
  `zsign -f`. All Info.plist edits must happen **before** signing; mutating it after cannot be repaired
  by re-signing.
- The IPA is ad-hoc signed with **no entitlements** (no app extensions, no app groups, default keychain).
  Do not hand-write `application-identifier` / `keychain-access-groups` — `codesign` does not expand
  `$(AppIdentifierPrefix)`, so they embed literally and iOS rejects the install.
- Verify the packaged IPA, not just the `.app` (recompression must not disturb the signature), and
  confirm the SHA-256 of the asset downloaded back from the release. A `gh release upload` has silently
  no-opped before.

## Testing

- Unit tests in `Glance/GlanceTests/`
- UI tests in `Glance/GlanceUITests/`
- Test file naming: `<Feature>Tests.swift`

## Git Conventions

- Branch naming: `feat/`, `fix/`, `chore/`
- Commits: imperative mood, lowercase, no period (`feat: add match timeline`)
- No secrets, API keys, or `.env` files in commits

## Build & Run

- **Simulator**: `iPhone 17 Pro Max` (iOS 26.5), id `4ABF9BBF-AB35-4739-B282-0EE19B2CE023` — this is the device that is actually **booted** on this machine. Use it so `xcodebuild` reuses it instead of paying a cold boot.
  - Verify before trusting any destination: `xcrun simctl list devices booted`
  - `iPhone 17 Pro` (id `C9F6FBC3-2E5D-4CF4-BB12-129357E0F3C2`) is also installed but is in **Shutdown** state.
- **Build** (`CODE_SIGNING_ALLOWED=NO` is required, see pitfalls):
  ```bash
  cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance \
    -destination 'platform=iOS Simulator,id=4ABF9BBF-AB35-4739-B282-0EE19B2CE023,OS=26.5' \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
  ```

### Test loop — use the script

```bash
scripts/test-area.sh --list          # available suite names
scripts/test-area.sh Madrid          # one suite  (~30s)
scripts/test-area.sh Madrid PoGo     # several suites
scripts/test-area.sh --no-build Madrid   # skip build-for-testing
make test-quick                      # unit tests only, no network (~30s)
make test-full                       # all suites including network (~5min)
```

The script resolves shorthand prefixes (`Madrid` → `MadridPipelineTests`), rejects ambiguous ones
(`Theme` matches three suites) and unknown ones, then runs `build-for-testing` followed by
`test-without-building` against the booted simulator. **Scope to the suite you are changing.**

### Performance

| Scope | Time |
|---|---|
| Single suite (e.g. Madrid) | ~20s |
| Cache suites combined | ~36s (was 10m24s — stall fixed) |
| Full `-only-testing:GlanceTests` | ~10min (known stall) |

The 10-min full-suite stall was caused by `CacheStoreTests` + `CacheTTTests` sharing
`UserDefaults.standard` across `CacheStore` actor instances. Fixed by injecting
isolated `UserDefaults(suiteName:)` into each test suite.

The full-suite stall still exists for other suites — use `make test-quick` or
`scripts/test-area.sh` to scope your runs.

Equivalent by hand, when you need the raw output:
```bash
cd Glance
xcodebuild build-for-testing -project Glance.xcodeproj -scheme Glance \
  -destination 'platform=iOS Simulator,id=4ABF9BBF-AB35-4739-B282-0EE19B2CE023,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|TEST BUILD"

xcodebuild test-without-building -project Glance.xcodeproj -scheme Glance \
  -destination 'platform=iOS Simulator,id=4ABF9BBF-AB35-4739-B282-0EE19B2CE023,OS=26.5' \
  CODE_SIGNING_ALLOWED=NO -only-testing:GlanceTests/MadridPipelineTests 2>&1 \
  | grep -E "Test case .*(passed|failed)|TEST EXECUTE"
```

## Test Performance

- **Scope your test runs.** A scoped run is ~20–30s; the full suite stalls ~10min. Always
  use `scripts/test-area.sh <Suite>` for the area you're changing.
- **Do not pass `-parallel-testing-enabled NO`.** It fails outright against the shared
  booted device (`Failed to install or launch the test runner … Busy / preflight checks`)
  and burns the same 10min in retry backoff.
- **Do not trust per-test durations in the `.xcresult` bundle** — they measure slot time on a
  shared clone, not CPU, and are inflated by an order of magnitude. Trust the runner output.
- **Known pre-existing failures (as of 2026-09-30, verified on a clean checkout of `main`)** — do not
  attribute these to your change without re-verifying:
  `CardOrderTests.appendRemoveFeed`, `ArticleSummaryAccumulatorTests.parsesLabelContentShape`,
  `KeychainStoreTests.roundTrip` (fails `-34018`, missing entitlement), `PoGoPipelineTests.smartCountdownOngoing`,
  `CacheTTTests.customRSSDefaultTTL`.
  To confirm a failure is pre-existing: `git stash push --include-untracked -- Glance/`, re-run the failing
  suites, then `git stash pop`.
- `CacheStoreTests.customRSSRoundTrip` fails only inside full/parallel runs and passes in isolation —
  likely parallel-run interference, not a real regression. Unconfirmed.

Full measured timings and the open 10-minute full-suite stall are documented in
[`docs/known-issues/test-suite-stall.md`](docs/known-issues/test-suite-stall.md).

## graphify

- Use `/graphify` to build/query a knowledge graph of the codebase for architecture understanding, code review, and feature planning
- Graph output lives in `graphify-out/` (gitignored)
- Commit hook auto-rebuilds graph after each `git commit`

## Common Build Pitfalls

- **Xcode project registration** — New `.swift` files must be added to `project.pbxproj`. Git tracking alone is not enough — Xcode only compiles files registered in the project. The `.gitignore` blocks `*.xcodeproj` changes, so use `git add -f` when committing pbxproj updates.
- **Array literal vs type annotation** — `var parts: [value1, value2]` is a type annotation (invalid). Use `var parts = [value1, value2]` for array literals. This is a silent syntax error that was committed 3 times in this session.
- **Foundation Models `PartiallyGenerated` optionality** — When using `session.streamResponse(to:generating:)`, `partial.content` is non-optional but nested properties like `.sections` are optional. Individual properties within `PartiallyGenerated<T>` (e.g. `section.title`, `section.content`) are also optional. Use `guard let` or `?.` on nested properties, not on `.content` itself.
- **Actor-isolated method calls** — `IntelligenceRouter` is an actor. Calling any method on it requires `await`, even if the return is an `AsyncStream` — the actor hop still needs to be awaited.
- **Xcode group path resolution** — Xcode resolves file paths relative to the parent group's `path`. Files must be placed on disk at the path the group expects. For example, the `Shared` group has `path = Shared` (root of Glance target), not `Features/Shared/`.
- **Build before committing** — Always run `xcodebuild build` before committing. Errors introduced in one commit cascade through subsequent commits, making diagnosis harder.
- **Avoid pbxproj Python libraries** — The `pbxproj` and `xcodeproj` Python packages corrupt the project file when adding files. Edit `project.pbxproj` manually or use Xcode directly. Plain `sed`/scripted line insertion is fine; always confirm with `plutil -lint Glance/Glance.xcodeproj/project.pbxproj` and by grepping each new filename (expect exactly 4 hits: build file, file ref, group child, Sources phase).
- **Code signing is not configured for this machine** — the `ATIFKHAN` team has no valid iOS Development certificate and the installed runtimes are iOS 26.5/27.0, so any build without `CODE_SIGNING_ALLOWED=NO` fails on provisioning, not on your code. Don't read a provisioning error as a compile error.
- **`@Observable` stores passed into sub-views need `@Bindable`** — a `let settingsStore: SettingsStore` does not give you `$settingsStore`. Either declare `@Bindable var settingsStore: SettingsStore` on the child view, or shadow with `@Bindable var x = x` inside `body` (which does *not* reach sibling computed properties).
- **Foundation Models `modelNotReady` state** — `SystemLanguageModel.default.isAvailable` returns `true` when Apple Intelligence is enabled, even if the safety sub-model (`instruct_300m.safety`) isn't downloaded. Use `SystemLanguageModel.default.availability` for a full check. The `modelNotReady` state is transient — it resolves after the model downloads (~1.6 GB). Always check availability before calling `streamResponse(to:generating:)` or `respond(to:generating:)`.
