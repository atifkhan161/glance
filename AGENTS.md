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
