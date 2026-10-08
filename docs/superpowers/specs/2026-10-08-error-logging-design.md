# Error Logging and Diagnostics Design

Date: 2026-10-08
Status: Draft for review

## Problem

Glance has no way for a user to report *why* something failed. Debug output is 18
ad-hoc `print()` / `NSLog()` calls scattered across `Glance/Core/Network` and three
features. They vanish on relaunch, are invisible in the UI, cannot be copied, and
cannot be attached to a bug report. When a card renders "something went wrong" the
user has no evidence to hand.

Worse, the errors that *are* surfaced are degraded on the way up.
`IntelligenceRouter.mapCloudError` (`Glance/Core/Intelligence/IntelligenceRouter.swift:161`)
falls through to `error.localizedDescription` for anything that is not an
`unauthorized` or `rateLimited` case. `GlanceError`
(`Glance/Shared/Enums.swift:10`) has no `LocalizedError` conformance, so that
branch produces Foundation's default text —
`The operation couldn't be completed. (GlanceError.networkUnavailable error 0.)` —
which names neither the domain nor the cause.

## Goal

Capture every in-app error to a capped on-disk file. Expose it in Settings behind a
row the user can tap. Let the user copy or share a markdown report sized for pasting
into an AI agent for root-cause analysis.

Non-goals: crash reporting, remote telemetry, log upload, a query language.

## Approach

A new `Glance/Core/Logging/` subsystem, plus a shared `HTTPTransport` so failure
instrumentation has exactly one home instead of fourteen.

Two decisions shape the rest:

- **Capture where the error still has identity.** A shared transport constructs
  `GlanceError` from HTTP status codes and records before any client maps it. Since
  every client today re-throws `GlanceError` untouched
  (`catch let error as GlanceError { throw error }`), the transport sees the original
  error, not a lossy re-wrap.
- **Reads come from memory; the file is durability.** `AppLog` holds entries
  newest-first as authoritative state. The viewer never touches disk.

## Components

### `LogEntry.swift`

`struct LogEntry: Codable, Sendable, Identifiable`

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Stable across edits so `ForEach` diffs correctly |
| `timestampMs` | `Int64` | `Date.now.millisecondsSinceEpoch` |
| `level` | `LogLevel` | `.error` (default) / `.warning` / `.info` |
| `subsystem` | `String` | `"github"`, `"openrouter"`, `"cache"` |
| `message` | `String` | One line, human-readable |
| `detail` | `String?` | Error identity, request host, retry state |

Timestamps are `Int64`, not `Date`. This matches `CacheEnvelope.timestampMs`
(`Glance/Core/Cache/CacheEnvelope.swift:4`) and means no `JSONEncoder` /
`JSONDecoder` date strategy can ever disagree — a mismatched pair yields a
permanently empty log with no error and no warning. Human-readable times are
rendered at display time via `TimeFormat.formatDate`.

### `LogLevel.swift`

Enum plus a `minimumLevel` threshold held by `AppLog`. Errors capture by default;
`info` requires opt-in from the viewer. The field is retained now so that diagnostic
context can be added later without a schema migration.

### `Error+LogDetail.swift`

`var logDetail: String?` on `Error`, with the `NSError` identity guard. A pure-Swift
error bridged to `NSError` yields the module name as `domain` and declaration order
as `code`. Absent detail reads as "not captured"; a fabricated one is worse than
nothing, because it looks like identity.

```swift
var logDetail: String? {
    guard type(of: self) is NSError.Type else { return nil }
    let e = self as NSError
    return "\(e.domain)/\(e.code) \(e.localizedDescription)"
}
```

`GlanceError` gets a **concrete** `logDetail` via an exhaustive `switch` over its ten
cases (`"keyMissing: exaKey"`, `"httpStatus: 401"`, …). This is the fix for the
`localizedDescription` degradation above, and because it is pure and exhaustive it is
directly testable.

### `LogStore.swift`

`actor`. `init(directory: URL = .applicationSupport, fileName: String = "glance-log.jsonl")`.

Dependency injection mirrors `CacheStore.init(userDefaults:)`
(`Glance/Core/Cache/CacheStore.swift:10`) so tests isolate storage. This is the app's
**first** `FileManager` usage anywhere — the directory is created with
`withIntermediateDirectories`.

Responsibilities and the constraints they satisfy:

- **Newline on every write path.** `append` writes `record + "\n"`. The cap-trim
  rewrite path does too. Without it, the first trim produces one undecodable run of
  `}{}{}` and `load()` silently returns empty while the in-memory mirror keeps
  working — which looks fine until relaunch loses everything.
- **Line-by-line decode with `compactMap`.** A crash mid-write or a hand edit costs one
  entry, not the whole document.
- **Never re-read the file to count.** Trimming on every write makes each write O(n);
  500 records per launch would decode 125,000 lines. The count is held in memory and a
  rewrite happens only once the cap is known exceeded.
- **Trim after appending.** Otherwise every subsequent record rewrites the file.
- **Cap both surfaces, drop oldest.** `mirror.removeLast(excess)` and
  `entries.suffix(cap)` for the rewrite.

Cap default: 500 entries.

### `AppLog.swift`

`actor`, `static let shared`.

This is a **deliberate deviation** from the app's DI convention (`@Environment` for
three types, `@State` construction for the rest). Threading a logger through
session → client factory → HTTP client leaves holes exactly where failures originate,
and a logger unavailable at a call site is a logger that does not exist. The deviation
is documented at the declaration so it does not drift back.

- Holds `mirror` newest-first as authoritative state.
- Lazily `load()`s from `LogStore` on first touch. This reconciles durability with the
  read path: after a cold start the mirror is empty, so *something* must read once, but
  opening the viewer still never touches disk.
- Every write is `try? store.append(entry)`. A log write must never propagate into the
  operation being logged, or a logging failure presents as a product failure.
- Exposes `snapshot()` for the viewer and `clear()` for the destructive action.
- `LogStore` never logs, so there is no recursion path.

### `LogExport.swift`

`[LogEntry] -> String`, built as an explicit string rather than a template plus a
hand-rolled formatter.

```markdown
# Glance error report
Glance 1.4.2 (build 9) · iOS 26.5 · iPhone17,2
Window: 2026-10-08 14:02:10 → 14:31:55
Showing newest 200 of 412 entries (12 errors)

## Summary
- github: 5 errors (last: HTTP 403 from api.github.com)
- openrouter: 4 errors (last: decode failed)

## Timeline (newest first)
[14:31:55] ERROR  github      HTTP 403 from api.github.com
    detail: retryAfter=nil
```

Header and summary are what make it usable for RCA: an agent receives the app version
and a per-subsystem failure count without parsing every line. The summary groups by
subsystem and reports the most recent message, not a raw histogram.

**Truncation:** newest 200 entries, with the total count stated in the header. A full
dump is a 200KB paste that degrades the analysis; the stated count tells the reader
what it is not seeing.

App version comes from `AppVersion.current` (`Glance/Shared/AppVersion.swift`), already
used by `AboutSection.swift:60`.

### `URLRedactor.swift`

`Glance/Core/Network/URLRedactor.swift`. Turns a request URL into a loggable
description: `endpoint.host` plus an optional caller-supplied non-identifying hint.

Rule 12 is a mechanical audit, not a judgement call, because these reports get pasted
into public bug trackers:

- **Never the full path.** Path components can carry container UUIDs — LiveActivity
  containers in particular.
- **Never a query string.** Tokens ride in queries.
- **Verify `userinfo` rejection rather than assuming it.** If `url.user` or
  `url.password` is non-nil the entry drops the path entirely and logs the host alone,
  rather than trusting a `lastPathComponent` strip to have removed the credentials.

### `HTTPTransport.swift`

`Glance/Core/Network/HTTPTransport.swift`. A `Sendable` struct wrapping a session.

**Absorbs:** request execution, session creation, `HTTPURLResponse` casting,
status-code → `GlanceError` mapping, and `AppLog.record` on every failure.

**Does not absorb:** retry, backoff, `Retry-After` handling. Clients differ today —
`OpenRouterClient` retries 429s with a capped backoff and treats 401/403 specially
(`OpenRouterClient.swift:166`), `GitHubClient` reads `Retry-After` on 403
(`GitHubClient.swift:198`), `GitHubTrendingClient` does no retry at all
(`GitHubTrendingClient.swift:25`). Centralizing that policy would silently change
network behavior. Retry stays in the client, which configures the transport.

Mapping is pure and separately testable, and it is the single place the status
vocabulary lives — today it is duplicated across clients with slight differences
(`GitHubTrendingClient` maps 429 but not 401, `GitHubClient` treats 403 as rate-limit,
`OpenRouterClient` treats it as unauthorized):

| Status | `GlanceError` |
|---|---|
| 401, 403 | `.unauthorized` |
| 429 | `.rateLimited(retryAfter:)` |
| other non-2xx | `.httpStatus(code)` |
| non-HTTP response | `.networkUnavailable` |

Instrumentation records at the transport's failure seam, before any client maps the
error. `mapCloudError` stays where it is — it is a display concern, and nothing logs
downstream of it.

### Migration

All 14 clients migrate, in dependency order, each one's `print()` / `NSLog()` calls
deleted as it converts so the end state has zero ad-hoc logging in
`Glance/Core/Network` and exactly one instrumentation point.

| Order | Client | Note |
|---|---|---|
| 1 | `GitHubTrendingClient` | Cleanest; already session-injected |
| 2 | `GitHubClient` | 10 prints to delete |
| 3 | `SportsDBClient` | 3 prints |
| 4 | `OpenRouterClient` + `OpenRouterModels` | Retry preserved |
| 5 | `GeminiClient` | See below |
| 6 | `ManagingMadridClient` | |
| 7 | `ExaClient`, `ExaEnhancedClient`, `ScrapedDuckClient` | |
| 8 | `GenericRSSClient` | |
| 9 | `ArticleScraper` | Last; currently leaks full URLs into error strings |

`GitHubTrendingClient` goes first because it is the only client with an injectable
`session: URLSession = .shared` init and existing tests
(`GlanceTests/GitHubTrendingClientTests.swift`) — it proves the transport design
before the other 13 depend on it.

### Non-throwing failures

`GeminiClient.generate` never throws; every failure is `return nil`
(`GeminiClient.swift:47,56`). `OpenRouterModels` swallows decode errors into a
`loadError` string (`OpenRouterModels.swift:265`), and `MadridPipeline` prints and
swallows (`:123`). No `catch`-based tap can see these.

Signatures are left alone. An explicit error entry is recorded at the swallow site,
including enough context (which model, which prompt, which feed) for RCA. Making these
throw would touch AI-feature call sites and break degradation that is intentional.

## Data flow

```
failure
  └─> HTTPTransport catch
        └─> AppLog.record(level:.error, subsystem:, message:, detail: error.logDetail)
              ├─> mirror.insert(0, entry)        // authoritative, newest-first
              ├─> mirror.removeLast(excess)     // if over cap
              └─> try? store.append(entry)       // durability only, never throws
```

Mapping happens *after* recording, at the display layer:

```
catch {
    AppLog.shared.record(...)            // original error, full identity
    state = .failed(mapper(error))       // lossy, display-only
}
```

The mirror never blocks the operation being logged.

## UI

`Glance/Settings/DiagnosticsSection.swift`, inserted between `CacheSection` and the
`Divider()` + `AboutSection` in `SettingsView.swift:15-20`, so `ABOUT` stays last.

Structure follows `SettingsView`: a `ScrollView` of hand-built sections, **not** a
`List`. `SectionHeader("DIAGNOSTICS")` plus a `SettingsRow` showing
`"\(count) entries · \(errorCount) errors"`.

The row pushes the viewer with the destination-closure `NavigationLink` form copied
from `OpenRouterModelPicker.swift:29-55` (hand-drawn `chevron.right`,
`.buttonStyle(.plain)`, `canvasDeep` fill, `borderSubtle` stroke). No
`navigationDestination` registration is needed — `SettingsView` already sits inside
`NavigationStack(path: $bindable.settingsPath)`.

### `LogViewerView.swift`

A `List`-based viewer modelled on `OpenRouterModelListView`
(`OpenRouterModelPicker.swift:87-149`), which already covers loading, error, empty,
search, and refresh: `.listStyle(.insetGrouped)`,
`.navigationBarTitleDisplayMode(.inline)`, `.searchable`, `.refreshable`.

Rows show time (`TimeFormat.formatDate`), a level-tinted badge, subsystem, message,
and detail as a secondary line. Timestamps are relative-ized for recency in the row
subtitle via `TimeFormat.age`, matching `CacheSection.swift:123`.

Toolbar: copy (`UIPasteboard.general.string`, with the existing
`UIImpactFeedbackGenerator(style: .medium)` idiom), share (`ShareLink(item:)` — not a
fourth hand-rolled `UIActivityViewController` presentation), and clear (destructive
`.alert` confirm, matching `CacheSection.swift:41-48`).

The viewer loads once in `.task`. It is a **snapshot**, not a live view; live-updating
while open is a deliberate deferral, not an oversight. No view is added to
`AppState`, which holds navigation state only.

## Testing

Follows `GlanceTests` conventions — `import Testing`, `@Suite`, `#expect`, and
`private func makeStore()` isolation. Because `LogStore` is file-backed rather than
`UserDefaults`-backed, isolation uses a unique temporary directory per test. This
matches the reasoning behind the `suiteName:` convention in
`docs/known-issues/test-suite-stall.md`: shared backing storage across actor
instances caused a 10-minute stall.

`Glance/GlanceTests/LogStoreTests.swift`
- Round trip append → load
- Newline present on the **trim** path (regression test for rule 3)
- A corrupt line drops only that entry
- Cap enforced, oldest dropped, both mirror and file
- No file re-read for counting
- Every write path ends with a terminator

`Glance/GlanceTests/LogEntryTests.swift`
- `GlanceError.logDetail` for each case
- `logDetail` returns nil for a pure-Swift error (the NSError-identity guard)

`Glance/GlanceTests/LogExportTests.swift`
- Header, summary counts, and truncation notice
- Timestamp formatting

`Glance/GlanceTests/HTTPTransportTests.swift`
- Status → `GlanceError` mapping per row
- A failing request records exactly one entry carrying the original error identity

`Glance/GlanceTests/URLRedactionTests.swift`
- `userinfo` rejection is verified rather than assumed
- Container-UUID path components never reach an entry

**Rule 9 test:** assert the log file resolves under Application Support, never
Documents. Nothing in the app walks the documents tree today (zero `FileManager`
usage repo-wide), but a `.jsonl` there would become user-visible content if a
scanner ever lands.

## Project registration

New `.swift` files must be added to `Glance/Glance.xcodeproj/project.pbxproj` — git
tracking alone does not compile them. Confirm with `plutil -lint` and grep each new
filename for exactly 4 hits. `.gitignore` blocks `*.xcodeproj`, so stage with
`git add -f`.

Note: `GitHubTrendingClientTests.swift` currently has zero hits in `project.pbxproj`
and is silently not compiled. It is not in scope here, but it means the transport's
first migration target has no live test coverage until that gap is closed.

## Risks

- **Transport migration touches all networking.** Mitigated by keeping retry policy in
  clients and by ordering `GitHubTrendingClient` first with its existing test suite.
- **Status mapping is not uniform today**, so centralizing it changes behavior at some
  call sites: `GitHubTrendingClient` maps 429 but not 401/403
  (`GitHubTrendingClient.swift:25-40`), while `GitHubClient` treats 403 as
  `rateLimited` (`GitHubClient.swift:196`) and `OpenRouterClient` treats 403 as
  `unauthorized` (`OpenRouterClient.swift:189`). The transport's table makes
  `GitHubTrendingClient`'s 403 case flip from `.networkError` to `.unauthorized`. This
  is intended — the duplicate tables are why the error messages are inconsistent — and
  each client's affected test is updated in the same change.
- **`articleURL` redaction** — `ArticleScraper` currently puts full URLs in error
  strings (`ArticleScraper.swift:14`). Migrating it removes that leak.
- **Log growth on disk** during heavy use. Bounded by the 500-entry cap and one
  rewrite per cap crossing.
- **`AppLog.shared` is a process-wide singleton**, so tests cannot swap in a fake log
  store. Tests target `LogStore` and `LogExport` directly, which is where the
  file-format rules live; anything needing a fake logger would require injecting a
  `LogStoring` protocol, which is deliberately out of scope until a case for it exists.