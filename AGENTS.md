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

- **Simulator**: iPhone 17 Pro Max
- **Build command**: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build`

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
- **Avoid pbxproj Python libraries** — The `pbxproj` and `xcodeproj` Python packages corrupt the project file when adding files. Edit `project.pbxproj` manually or use Xcode directly.
- **Foundation Models `modelNotReady` state** — `SystemLanguageModel.default.isAvailable` returns `true` when Apple Intelligence is enabled, even if the safety sub-model (`instruct_300m.safety`) isn't downloaded. Use `SystemLanguageModel.default.availability` for a full check. The `modelNotReady` state is transient — it resolves after the model downloads (~1.6 GB). Always check availability before calling `streamResponse(to:generating:)` or `respond(to:generating:)`.
