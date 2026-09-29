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

## Testing

- Unit tests in `Glance/GlanceTests/`
- UI tests in `Glance/GlanceUITests/`
- Test file naming: `<Feature>Tests.swift`

## Git Conventions

- Branch naming: `feat/`, `fix/`, `chore/`
- Commits: imperative mood, lowercase, no period (`feat: add match timeline`)
- No secrets, API keys, or `.env` files in commits

## Build & Run

- **Simulator**: `iPhone 17 Pro` (iOS 26.5), id `C9F6FBC3-2E5D-4CF4-BB12-129357E0F3C2`
  - `iPhone 17 Pro Max` is referenced in older docs but is **not installed** on this machine. Check with `xcodebuild -project Glance.xcodeproj -scheme Glance -showdestinations` before trusting a destination name.
- **Build** (working invocation — `CODE_SIGNING_ALLOWED=NO` is required, see pitfalls):
  ```bash
  cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance \
    -destination 'platform=iOS Simulator,id=C9F6FBC3-2E5D-4CF4-BB12-129357E0F3C2,OS=26.5' \
    CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
  ```
- **Test**:
  ```bash
  cd Glance && xcodebuild test -project Glance.xcodeproj -scheme Glance \
    -destination 'platform=iOS Simulator,id=C9F6FBC3-2E5D-4CF4-BB12-129357E0F3C2,OS=26.5' \
    CODE_SIGNING_ALLOWED=NO -only-testing:GlanceTests 2>&1 | tail -30
  ```

## Test Performance

- A full `-only-testing:GlanceTests` run takes **~70s wall clock but only ~10s of CPU**. Individual tests are sub-0.05s. The time is almost entirely simulator boot + clone, not test execution — so a slow run is not a hung run. Watch for `Testing started completed` in the log.
- `IntelligenceRouterTests` are the slowest real tests at ~3.5s each (they exercise model availability paths).
- Scope with `-only-testing:GlanceTests/<SuiteName>` while iterating; the full run adds no signal for a single-suite change.
- **Known pre-existing failures (as of 2026-09-29, present on a clean checkout of `main`)** — do not attribute these to your change without re-verifying:
  `CardOrderTests.appendRemoveFeed`, `ArticleSummaryAccumulatorTests.parsesLabelContentShape`, `KeychainStoreTests.roundTrip`, `PoGoPipelineTests.smartCountdownOngoing`, `CacheTTTests.customRSSDefaultTTL`.
  To confirm a failure is pre-existing: `git stash push --include-untracked -- Glance/`, re-run the failing suites, then `git stash pop`.
- `GitHubTrendingClientTests.trendingReposHaveDescriptions` makes a **real network call** to github.com and will fail or hang offline. Treat it as a network smoke test, not a unit test.

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
