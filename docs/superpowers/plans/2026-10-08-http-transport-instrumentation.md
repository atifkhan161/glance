# HTTP Transport and Client Instrumentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce one shared HTTP transport that owns status-code mapping and error recording, and migrate all 14 network clients to it, deleting every ad-hoc `print()`/`NSLog()` on the way — so every network failure in the app lands in the log with its original error identity intact.

**Architecture:** `HTTPTransport` is a `Sendable` struct wrapping a `URLSession`. It absorbs request execution, session construction, `HTTPURLResponse` casting, status→`GlanceError` mapping, and `AppLog.record` on failure. It deliberately does **not** absorb retry or backoff — clients differ today and centralizing that would silently change network behavior. Recording happens at the transport's failure seam, *before* any client maps the error, so the log holds the original error rather than a lossy re-wrap.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Testing, Foundation `URLSession`, Xcode project manual registration.

**Spec:** `docs/superpowers/specs/2026-10-08-error-logging-design.md`

**Prerequisite:** Plan A (`docs/superpowers/plans/2026-10-08-error-logging-core.md`) must be complete. This plan consumes `AppLog.record(_:subsystem:message:detail:)`, `AppLog.record(_:subsystem:message:error:)`, and `LogEntry`.

## Global Constraints

- Build: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,id=4ABF9BBF-AB35-4739-B282-0EE19B2CE023,OS=26.5' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"`
- Test one suite at a time: `scripts/test-area.sh HTTPTransport`. **Never** run `make test-full`, `make test-quick`, or a bare `xcodebuild test` — the full suite stalls ~10min.
- `CODE_SIGNING_ALLOWED=NO` is mandatory.
- No comments in code. Styling only via `Theme.*`. `@Observable` never `ObservableObject`.
- **Every new `.swift` file must be registered in `Glance/Glance.xcodeproj/project.pbxproj`** (four edits per file; see Plan A's Global Constraints for the exact pattern). `.gitignore` blocks `*.xcodeproj` — stage with `git add -f`.
- Commit messages: imperative, lowercase, no period.
- **Delete each client's `print()`/`NSLog()` calls as you migrate it.** The end state is zero ad-hoc logging in `Glance/Core/Network`. Leaving prints behind means the same failure is reported twice.

### Known pre-existing failures — do not attribute these to your change

`CardOrderTests.appendRemoveFeed`, `ArticleSummaryAccumulatorTests.parsesLabelContentShape`, `KeychainStoreTests.roundTrip`, `PoGoPipelineTests.smartCountdownOngoing`, `CacheTTTests.customRSSDefaultTTL`. To confirm a failure is pre-existing: `git stash push --include-untracked -- Glance/`, re-run, then `git stash pop`.

## Review Focus

Inputs and conditions the spec does not spell out, most likely to bite first.

1. **A `GlanceError` that is re-thrown, not converted.** Recording inside a `catch let error as GlanceError { throw error }` branch double-reports. Expect exactly one entry per failure.
2. **`ArticleScraper` leaking full URLs.** It currently puts complete URLs into error strings. Expect: after migration no entry contains a full path or query.
3. **A client whose session is injected by a test.** `GitHubTrendingClientTests` passes its own `URLSession`. Expect: a failing test request still records, but the transport must not require a real network round-trip to construct.
4. **`GeminiClient` returning `nil` on every failure.** No `catch` exists to tap. Expect: an entry recorded at the `return nil` site naming the model.
5. **`ArticleScraper.scrape` throwing with no wrapping at all.** Expect: its error still reaches `AppLog` with domain/code intact rather than being flattened to a string.

---

### Task 1: Register the dormant GitHubTrendingClientTests

**Files:**
- Modify: `Glance/Glance.xcodeproj/project.pbxproj` (register `Glance/GlanceTests/GitHubTrendingClientTests.swift`, which exists on disk with zero hits)

**Interfaces:**
- Consumes: nothing
- Produces: a compiling `GitHubTrendingClientTests` suite, addressable as `scripts/test-area.sh GitHubTrendingClientTests`

**Why first:** this file exists on disk but has no `pbxproj` entry, so it is silently not compiled. It is the test suite for this plan's first migration target — registering it now means every later task is verified against a suite that actually runs.

- [ ] **Step 1: Confirm the gap**

```bash
cd Glance && rg -c "GitHubTrendingClientTests" Glance.xcodeproj/project.pbxproj
```
Expected: exit 1, no output.

- [ ] **Step 2: Confirm the suite is currently invisible to the test runner**

Run: `scripts/test-area.sh --list | rg GitHubTrending`
Expected: the struct **is** listed (the script greps source text, not the project file) — proving the script's discovery and the compiler's disagree, which is exactly the hazard.

- [ ] **Step 3: Add the four pbxproj entries**

Per Plan A's Global Constraints: one `PBXBuildFile` entry, one `PBXFileReference`, one line in the `GlanceTests` group's `children`, and one line in the `15A885ECB27CC8627B5F3B25` (GlanceTests) sources phase. Production files use `EBCDFE4FC64A11F71EA4B02E` and the `Network` group `18FEA4FE7CA2EB551AA1EB0B`.

Verify:
```bash
plutil -lint Glance.xcodeproj/project.pbxproj
rg -c "GitHubTrendingClientTests.swift" Glance.xcodeproj/project.pbxproj   # expect 4
```

- [ ] **Step 4: Run the suite**

Run: `scripts/test-area.sh GitHubTrendingClientTests`
Expected: PASS. If it fails on network access, note it — this suite scrapes live GitHub HTML, so a network failure is environmental, not a regression.

- [ ] **Step 5: Commit**

```bash
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "fix: register GitHubTrendingClientTests in the Xcode project"
```

---

### Task 2: URLRedactor

**Files:**
- Create: `Glance/Core/Network/URLRedactor.swift`
- Create: `Glance/GlanceTests/URLRedactorTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum URLRedactor` with `static func describe(_ url: URL, hint: String? = nil) -> String`
  - Returns `"\(host) / \(hint)"` when a hint is supplied, `"\(host)"` otherwise, and `"\(host) (path redacted)"` when the URL carries userinfo
  - `static func hasUserinfo(_ url: URL) -> Bool`

**Why:** log entries get pasted into public bug trackers. Never log a full path (container UUIDs live there), never a query string (tokens ride in queries), and **verify** userinfo rejection rather than assuming a `lastPathComponent` strip removed credentials.

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/URLRedactorTests.swift`:

```swift
import Testing
@testable import Glance
import Foundation

@Suite("URLRedactor")
struct URLRedactorTests {
    @Test("Plain URL reduces to host")
    func hostOnly() {
        let url = URL(string: "https://api.github.com/search/repositories")!
        #expect(URLRedactor.describe(url) == "api.github.com")
    }

    @Test("Hint is appended, path is dropped")
    func hintAppended() {
        let url = URL(string: "https://api.github.com/search/repositories?q=glance")!
        #expect(URLRedactor.describe(url, hint: "github search") == "api.github.com / github search")
    }

    @Test("Query strings never appear")
    func queryDropped() {
        let url = URL(string: "https://api.exa.ai/search?token=SECRET&query=news")!
        let described = URLRedactor.describe(url, hint: "exa")
        #expect(described.contains("SECRET") == false)
        #expect(described.contains("query=") == false)
    }

    @Test("Container UUID path components never appear")
    func containerUUIDDropped() {
        let url = URL(string: "https://example.com/LiveContainer/1F2E3D4C-5B6A-7988-9A0B-1C2D3E4F5A6B/feed")!
        let described = URLRedactor.describe(url, hint: "activity")
        #expect(described.contains("1F2E3D4C-5B6A-7988-9A0B-1C2D3E4F5A6B") == false)
        #expect(described == "example.com / activity")
    }

    @Test("Userinfo is detected and the path is dropped entirely")
    func userinfoRedacted() {
        let url = URL(string: "https://user:hunter2@example.com/private/path")!
        #expect(URLRedactor.hasUserinfo(url))
        let described = URLRedactor.describe(url, hint: "private")
        #expect(described == "example.com (path redacted)")
        #expect(described.contains("hunter2") == false)
        #expect(described.contains("private") == false)
    }

    @Test("A URL with no host does not crash")
    func noHost() {
        let url = URL(string: "file:///tmp/x")!
        #expect(URLRedactor.describe(url).isEmpty == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh URLRedactor`
Expected: FAIL — `cannot find 'URLRedactor' in scope`.

- [ ] **Step 3: Implement `Glance/Core/Network/URLRedactor.swift`**

Create `enum URLRedactor` with two static functions:

- `hasUserinfo(_:)` returns `url.user != nil || url.password != nil`.
- `describe(_:hint:)` returns `guard let host = url.host, !host.isEmpty else { return "unknown host" }`; if `hasUserinfo(url)` it returns `"\(host) (path redacted)"` and drops the hint entirely — a URL carrying credentials is not made safe by a hint, and the hint caller may itself be sensitive; otherwise it returns `hint.map { "\(host) / \($0)" } ?? host`.

Never return anything derived from `url.path` or `url.query` in the non-userinfo branch. The test pins both.

- [ ] **Step 4: Register the file in the Xcode project**

Four `pbxproj` edits into the existing `Network` group (`18FEA4FE7CA2EB551AA1EB0B`). Verify `plutil -lint`, 4-hit grep, and `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `scripts/test-area.sh URLRedactor`
Expected: PASS — 6 tests.

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Network/URLRedactor.swift Glance/GlanceTests/URLRedactorTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add URLRedactor for log-safe request identity"
```

---

### Task 3: HTTPTransport

**Files:**
- Create: `Glance/Core/Network/HTTPTransport.swift`
- Create: `Glance/GlanceTests/HTTPTransportTests.swift`

**Interfaces:**
- Consumes: `AppLog.record(_:subsystem:message:error:)` (Plan A), `URLRedactor` (Task 2), `GlanceError` (`Glance/Shared/Enums.swift:10`)
- Produces:
  - `struct HTTPTransport: Sendable` with
    - `init(session: URLSession? = nil, subsystem: String)`
    - `static func makeSession() -> URLSession` — 15s request/resource timeouts, `waitsForConnectivity = false`, TLS 1.2 floor, copied from `GitHubTrendingClient.swift:8-17`
    - `func data(for request: URLRequest, hint: String? = nil) async throws -> (Data, HTTPURLResponse)`
    - `func bytes(for request: URLRequest, hint: String? = nil) async throws -> (URLSession.AsyncBytes, HTTPURLResponse)`
    - `func execute(_ request: URLRequest, hint: String? = nil) async throws -> (Data, HTTPURLResponse)` — the shared validation and recording path that `data(for:hint:)` funnels into; `bytes(for:hint:)` duplicates only the session call and response casting, then delegates validation and recording to a shared private helper so recording cannot fork
  - `enum HTTPStatusMapper` with `static func error(for http: HTTPURLResponse) -> GlanceError?` — returns `nil` for 2xx

**Mapping table** (this is the whole point of centralizing; the clients do not agree today):

| Status | `GlanceError` |
|---|---|
| 401, 403 | `.unauthorized` |
| 429 | `.rateLimited(retryAfter:)` — parsed from the `Retry-After` header, `nil` if absent or unparseable |
| other non-2xx | `.httpStatus(code)` |
| non-`HTTPURLResponse` | `.networkUnavailable` |

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/HTTPTransportTests.swift` with `@Suite("HTTPTransport") struct HTTPTransportTests` and a `private func makeResponse(_ status: Int, headers: [String: String] = [:]) -> HTTPURLResponse` helper building a response against `https://api.github.com/`, plus a `private func retryAfter(of response: HTTPURLResponse) -> Double?` helper that pattern-matches the `.rateLimited` case from `HTTPStatusMapper.error(for:)` and calls `Issue.record("expected rateLimited")` when the case does not match.

Also declare `private enum HTTPTransportProtocolStub` in the same file with `static func ok() async throws -> (Data, HTTPURLResponse)` returning `Data("{}".utf8)` paired with a hand-built 200 response — this keeps the success path testable with no network.

Tests:

| Test | Asserts |
|---|---|
| `success` | The stub's `data.count > 0` and `response.statusCode == 200` |
| `statusMapping` | `HTTPStatusMapper.error(for:)` equals `.unauthorized` for 401 and 403, `.rateLimited(retryAfter: nil)` for 429, `.httpStatus(503)` for 503, `.httpStatus(500)` for 500 |
| `successMapsToNil` | Returns `nil` for 200 and 204 |
| `retryAfterParsed` | A 429 with header `"Retry-After": "30"` → `retryAfter(of:) == 30` |
| `retryAfterUnparseable` | A 429 with the HTTP-date form `"Wed, 21 Oct 2026 07:28:00 GMT"` → `retryAfter(of:) == nil`. Parsing `Double` only is deliberate; a date-form header yields `nil` rather than a crash |
| `recordsOnce` | A request to a 503 endpoint either throws a `GlanceError` or succeeds; the test asserts no hang and no double-throw. Counting entries requires reading `AppLog.shared.snapshot()`, so assert the throw type only, and leave the "exactly one entry" guarantee to the Task 8 grep in step 5 |
| `constructibleOffline` | `HTTPTransport(session: nil, subsystem: "github").subsystem == "github"` — no network round-trip to build. Review Focus row 3 |
| `sessionPolicy` | `HTTPTransport.makeSession().configuration` has `timeoutIntervalForRequest == 15`, `timeoutIntervalForResource == 15`, `waitsForConnectivity == false` |

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh HTTPTransport`
Expected: FAIL — `cannot find 'HTTPTransport' in scope`.

- [ ] **Step 3: Implement `Glance/Core/Network/HTTPTransport.swift`**

```swift
import Foundation

enum HTTPStatusMapper {
    static func error(for http: HTTPURLResponse) -> GlanceError? {
        let status = http.statusCode
        guard !(200 ..< 300).contains(status) else { return nil }
        switch status {
        case 401, 403:
            return .unauthorized
        case 429:
            return .rateLimited(retryAfter: retryAfter(http))
        default:
            return .httpStatus(status)
        }
    }

    static func retryAfter(_ http: HTTPURLResponse) -> Double? {
        guard let raw = http.value(forHTTPHeaderField: "Retry-After") else { return nil }
        return Double(raw)
    }
}

struct HTTPTransport: Sendable {
    let subsystem: String
    private let session: URLSession

    init(session: URLSession? = nil, subsystem: String) {
        self.session = session ?? Self.makeSession()
        self.subsystem = subsystem
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false
        if #available(iOS 16.0, *) {
            config.tlsMinimumSupportedProtocolVersion = .TLSv12
        }
        return URLSession(configuration: config)
    }
}
```

`execute(_:hint:)` is the single validation and recording path. It performs the session call, casts to `HTTPURLResponse` (throwing `.networkUnavailable` and recording if that fails), asks `HTTPStatusMapper.error(for:)` for a `GlanceError`, and if non-`nil` records it and throws. `data(for:hint:)` and `bytes(for:hint:)` both funnel through equivalent validation so `URLSession.AsyncBytes` support does not fork the recording logic.

**Recording is `try`-free and happens exactly once**, at the point the `GlanceError` is constructed — never in a `catch let error as GlanceError { throw error }` branch, which would double-report:

```swift
private func record(_ error: Error, request: URLRequest, hint: String?) {
    Task {
        await AppLog.shared.record(
            .error,
            subsystem: subsystem,
            message: "\(URLRedactor.describe(request.url ?? fallbackURL, hint: hint)): \(error.logDetail ?? "failed")",
            detail: error.logDetail
        )
    }
}
```

Wrap the message description in a local computed string so the host is reduced by `URLRedactor` before it reaches the log — never interpolate `request.url?.absoluteString` or `request.url?.path`.

The transport contains **no retry loop**. `OpenRouterClient` retries 429s with a capped backoff, `GitHubClient` reads `Retry-After` on 403, `GitHubTrendingClient` does not retry at all. Centralizing that would silently change network behavior, so each client keeps its own policy and only its transport call is replaced.

- [ ] **Step 4: Register both files in the Xcode project**

`HTTPTransport.swift` into the `Network` group; `HTTPTransportTests.swift` into `GlanceTests` plus the **GlanceTests** sources phase. Verify `plutil -lint`, a 4-hit grep per filename, and `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `scripts/test-area.sh HTTPTransport`
Expected: PASS — 8 tests. Seven are offline. `recordsOnce` makes a real request; if the sandbox has no network it must still pass, because it asserts only the thrown type rather than a recorded entry.

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Network/HTTPTransport.swift Glance/GlanceTests/HTTPTransportTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add shared HTTPTransport with status mapping and error recording"
```

---

### Task 4: Migrate GitHubTrendingClient — the proving ground

**Files:**
- Modify: `Glance/Core/Network/GitHubTrendingClient.swift:19-54`
- Test: `Glance/GlanceTests/GitHubTrendingClientTests.swift` (already compiling after Task 1)

**Interfaces:**
- Consumes: `HTTPTransport(session:subsystem:)`, `HTTPTransport.data(for:hint:)` (Task 3)
- Produces: `GitHubTrendingClient.init(session: URLSession? = nil)` — the parameter type widens from non-optional `URLSession` to optional so `nil` can build the default session; existing call sites passing an explicit session keep compiling

**Why first:** this is the only client with an injectable session and a test suite, so it validates the transport design before 13 more clients depend on it.

- [ ] **Step 1: Run the existing suite to establish a baseline**

Run: `scripts/test-area.sh GitHubTrendingClientTests`
Expected: PASS (Task 1 made it compile). Record the result so a later failure is attributable.

- [ ] **Step 2: Replace the hand-rolled validation with the transport**

In `GitHubTrendingClient`, replace `private static let defaultSession` and the `guard let http` / 429 / non-200 block (lines 8-17 and 38-50) with a stored `private let transport: HTTPTransport`, initialized from the injected session with `subsystem: "github"`. `fetchTrending(since:)` then becomes: build the `URLRequest` unchanged → `let (data, _) = try await transport.data(for: request, hint: "trending \(since)")` → keep the UTF-8 decode guard (`.decodingError`) and the `parseTrendingHTML` call untouched.

The URL construction and `guard let url = URL(string:)` stay as they are; that guard throws `.networkError("Invalid trending URL")` before the transport is involved.

**Behavior change to accept deliberately:** the transport maps 401/403 to `.unauthorized`, where this client previously produced `.networkError("GitHub returned 403")`. Centralizing the table is exactly why the error messages are inconsistent today; update this client's affected test assertion in the same change and note it in the commit body.

- [ ] **Step 3: Build**

Run the Global Constraints build command.
Expected: `BUILD SUCCEEDED`. A `URLSession?` mismatch at an existing call site means that call site passes a non-optional session — that still compiles, since a non-optional value satisfies an optional parameter.

- [ ] **Step 4: Run the suite**

Run: `scripts/test-area.sh GitHubTrendingClientTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Glance/Core/Network/GitHubTrendingClient.swift Glance/GlanceTests/GitHubTrendingClientTests.swift
git commit -m "refactor: route GitHubTrendingClient through HTTPTransport"
```

---

### Task 5: Migrate GitHubClient and SportsDBClient

**Files:**
- Modify: `Glance/Core/Network/GitHubClient.swift:8-17` (session), `:161-227` (request path), and its 10 `print()` calls
- Modify: `Glance/Core/Network/SportsDBClient.swift:252,259,264` (3 prints)
- Test: existing `Glance/GlanceTests/GitHubPipelineTests.swift`

**Interfaces:**
- Consumes: `HTTPTransport` (Task 3)
- Produces: no new public types; both clients keep their existing protocols and initializers

- [ ] **Step 1: Establish baselines**

Run: `scripts/test-area.sh GitHubPipeline`
Expected: PASS.

- [ ] **Step 2: Migrate GitHubClient**

Replace `private static let session` with a stored `transport` built as
`HTTPTransport(session: session, subsystem: "github")`. In the request path, replace the `guard let http`, the 403→`rateLimited`, and the non-200→`networkError` block with `let (data, _) = try await transport.data(for: request, hint: "search")`.

Keep `GitHubClient`'s `Retry-After` read for 403 in the **client**, because its retry policy stays there — but note the transport now classifies 403 as `.unauthorized`, so the client's own 403 branch becomes dead. Delete the client-side 403 branch rather than leaving unreachable code, and update any test asserting `GlanceError.rateLimited` for a 403.

**Delete all 10 `print()` calls** in this file. Do not port them to `AppLog` — success milestones are not captured at the default `.error` threshold, and the transport's single `record()` is the intended instrumentation point. A `catch let error as GlanceError { throw error }` passthrough must stay silent; that is exactly the double-report case in Review Focus row 1.

- [ ] **Step 3: Migrate SportsDBClient**

Same treatment with `subsystem: "sportsdb"`. Delete its 3 prints.

- [ ] **Step 4: Build**

Run the Global Constraints build command.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the suite**

Run: `scripts/test-area.sh GitHubPipeline`
Expected: PASS.

- [ ] **Step 6: Verify no ad-hoc logging remains in these two files**

```bash
cd Glance && rg -n "print\(|NSLog" Core/Network/GitHubClient.swift Core/Network/SportsDBClient.swift
```
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add Glance/Core/Network/GitHubClient.swift Glance/Core/Network/SportsDBClient.swift
git commit -m "refactor: route GitHub and SportsDB clients through HTTPTransport"
```

---

### Task 6: Migrate OpenRouter, Gemini, and Madrid clients

**Files:**
- Modify: `Glance/Core/Network/OpenRouterClient.swift:99-125` (`complete`), `:166-202` (`openStream`), and its `NSLog` sites
- Modify: `Glance/Core/Network/GeminiClient.swift:47-48,56` (the `return nil` paths), `:97` (`NSLog`)
- Modify: `Glance/Core/Network/ManagingMadridClient.swift`
- Test: existing `Glance/GlanceTests/OpenRouterStreamDecoderTests.swift`, `MadridPipelineTests`, `IntelligenceRouterTests`

**Interfaces:**
- Consumes: `HTTPTransport.data(for:hint:)`, `HTTPTransport.bytes(for:hint:)` (Task 3), `AppLog.record` (Plan A)
- Produces: no new public types

**The special cases in this task:**

`OpenRouterClient` has a retry loop with a capped backoff around `openStream`. That loop stays in the client — the transport has no retry. Keep `catch is CancellationError { throw CancellationError() }` intact: cancellation must not be recorded as a failure.

`GeminiClient.generate` **never throws** — every failure is `return nil`. No `catch`-based tap can see it, so record explicitly at each `return nil` with `AppLog.shared.record(.error, subsystem: "gemini", message: "...", detail: nil)`, naming the model so the RCA payload identifies which model failed. Leave the signature alone; `IntelligenceRouter` depends on the `nil` return for graceful degradation.

`ManagingMadridClient` is a plain migration.

**Delete the `NSLog` sites** in this group (`IntelligenceRouter.swift:132,152`, `FoundationModelsClient.swift:97`, `OpenRouterClient`) — but read them first. `IntelligenceRouter.swift:132` logs streaming latency metrics that are genuinely diagnostic, not error output. Those belong at `.info` level, which is above the default `.error` threshold, so they stay out of the report until the viewer toggle enables them. Convert them to `AppLog.shared.record(.info, ...)` rather than deleting outright.

- [ ] **Step 1: Establish baselines**

Run: `scripts/test-area.sh OpenRouterStreamDecoder MadridPipeline IntelligenceRouter`
Expected: PASS, noting any pre-existing failures from the Known Pre-existing Failures list.

- [ ] **Step 2: Migrate OpenRouterClient**

Replace the session with `HTTPTransport(session: nil, subsystem: "openrouter")`. Replace the status-validation block in `openStream` with a `transport.bytes(for:hint:)` call; keep the retry loop, `Self.maxAttempts`, `Self.maxRetryAfter`, and `Self.retryAfterSeconds(http:)` as client logic. The 401/403→`unauthorized` and 429→`rateLimited` decisions now come from `HTTPStatusMapper`; delete the client's duplicate branches but keep the backoff `Task.sleep` and `continue`.

- [ ] **Step 3: Migrate GeminiClient, instrumenting the nil returns**

Replace the session with `HTTPTransport(session: nil, subsystem: "gemini")` for its request path. Add an explicit `AppLog.shared.record(.error, subsystem: "gemini", message: "generation returned nil", detail: modelIdentifier)` at each of the two `return nil` sites. Convert the `NSLog` at `:97` to a `.info` record or delete it.

- [ ] **Step 4: Migrate ManagingMadridClient**

Straightforward transport swap, `subsystem: "madrid"`. No prints to remove.

- [ ] **Step 5: Convert IntelligenceRouter's NSLog sites to `.info` records**

In `IntelligenceRouter.swift:132,152` and `FoundationModelsClient.swift:97`, replace `NSLog` with `AppLog.shared.record(.info, subsystem: "intelligence", message: ...)`. Do **not** change `mapCloudError` — it is a display concern, and nothing logs downstream of it, which is what keeps the log free of lossy `localizedDescription` text.

- [ ] **Step 6: Build**

Run the Global Constraints build command.
Expected: `BUILD SUCCEEDED`. An actor-isolation error means an `await` is missing on the `AppLog` call; `AppLog` is an actor even though `record` is non-throwing.

- [ ] **Step 7: Run the suites**

Run: `scripts/test-area.sh OpenRouterStreamDecoder MadridPipeline IntelligenceRouter`
Expected: PASS, with only known pre-existing failures.

- [ ] **Step 8: Commit**

```bash
git add Glance/Core/Network Glance/Core/Intelligence
git commit -m "refactor: route OpenRouter, Gemini, and Madrid clients through HTTPTransport"
```

---

### Task 7: Migrate the remaining clients and swallow sites

**Files:**
- Modify: `Glance/Core/Network/ExaClient.swift`, `ExaEnhancedClient.swift`, `ScrapedDuckClient.swift`, `GenericRSSClient.swift`, `ArticleScraper.swift`
- Modify: `Glance/Core/Network/OpenRouterModels.swift:265` (decode error → `loadError` string)
- Modify: `Glance/Features/Madrid/MadridPipeline.swift:123` (print + swallow)
- Modify: `Glance/Features/Pulse/PulseStore.swift:229`
- Modify: `Glance/Features/SmartSearch/QuickSearchView.swift:214-215,232`

**Interfaces:**
- Consumes: `HTTPTransport` (Task 3), `AppLog.record` (Plan A)
- Produces: no new public types

**The special cases:**

`ArticleScraper.scrape` throws with **no wrapping and no retry**, and leaks the full URL into its error string (`:14`). After migration the error carries domain/code intact, and no entry contains a full path or query — Review Focus rows 2 and 5.

The three swallow sites listed above each need an explicit `AppLog.record(.error, ...)` at the point the failure is absorbed, with enough context for RCA (which feed, which card, which search). `OpenRouterModels.swift:265` swallows a decode error into `loadError`; `MadridPipeline.swift:123` prints and swallows; `PulseStore.swift:229` and `QuickSearchView.swift` interpolate the error into a display string via `localizedDescription`. In every case, record **before** the display mapping — a mapper that keeps only `localizedDescription` destroys domain/code/userInfo, so recording downstream yields "something went wrong" for every distinct cause.

Also update `QuickSearchView`'s two `localizedDescription` call sites to use `error.logDetail ?? error.localizedDescription` so the user-visible text stops showing `The operation couldn't be completed. (GlanceError.networkUnavailable error 0.)`.

- [ ] **Step 1: Establish baselines**

Run: `scripts/test-area.sh CustomRSS MadridPipeline AiIntelPipeline`
Expected: PASS, noting pre-existing failures.

- [ ] **Step 2: Migrate the four straightforward clients**

`ExaClient` (`subsystem: "exa"`), `ExaEnhancedClient` (`"exa"`), `ScrapedDuckClient` (`"duckduckgo"`), `GenericRSSClient` (`"rss"`). Replace each session with a transport and its status-validation block with a transport call. Pass a `hint` naming the operation, e.g. `"search"` or `"feed \(feedID)"`.

- [ ] **Step 3: Migrate ArticleScraper last**

`subsystem: "scraper"`. Keep its throw-without-wrapping shape but ensure the transport has recorded the error before it propagates. Verify no full URL reaches an error string.

- [ ] **Step 4: Instrument the swallow sites**

Add `AppLog.record(.error, subsystem:, message:, error: error)` at each of the five sites listed in Files. For `PulseStore.swift:229`, use `subsystem: "pulse"`; for `MadridPipeline.swift:123`, `"madrid"`; for `OpenRouterModels.swift:265`, `"openrouter"`; for `QuickSearchView`, `"search"`.

- [ ] **Step 5: Build**

Run the Global Constraints build command.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Verify the network layer is now print-free**

```bash
cd Glance && rg -n "print\(|NSLog" Core/Network/
```
Expected: no output. This is the end state the spec calls for — zero ad-hoc logging in `Glance/Core/Network` and exactly one instrumentation point.

- [ ] **Step 7: Run the suites**

Run: `scripts/test-area.sh CustomRSS MadridPipeline AiIntelPipeline`
Expected: PASS, with only known pre-existing failures.

- [ ] **Step 8: Commit**

```bash
git add Glance/Core/Network Glance/Features
git commit -m "refactor: route remaining clients through HTTPTransport and log swallow sites"
```

---

### Task 8: End-to-end verification

**Files:**
- Modify: none — verification only

**Interfaces:**
- Consumes: everything from Tasks 1-7

- [ ] **Step 1: Build the app**

Run the Global Constraints build command.
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Run every suite touched by this plan**

Run: `scripts/test-area.sh HTTPTransport URLRedactor GitHubTrendingClientTests GitHubPipeline CustomRSS MadridPipeline AiIntelPipeline OpenRouterStreamDecoder IntelligenceRouter LogEntry LogStore AppLog ErrorLogDetail LogExport LogViewerModel`
Expected: PASS. Any failure must be checked against the Known Pre-existing Failures list before being attributed to this work.

- [ ] **Step 3: Verify no secrets reach the log format**

```bash
cd Glance && rg -n "absoluteString|\.path\b" Core/Network/HTTPTransport.swift Core/Network/URLRedactor.swift
```
Expected: no output — neither file interpolates a full URL or path into a log message.

- [ ] **Step 4: Verify the transport contains no retry logic**

```bash
cd Glance && rg -n "maxAttempts|Task.sleep|for attempt" Core/Network/HTTPTransport.swift
```
Expected: no output. Retry belongs to clients.

- [ ] **Step 5: Verify every network failure path reaches AppLog**

Confirm each of the 14 clients calls `transport.data(for:` or `transport.bytes(for:` rather than `session.data(for:` directly:

```bash
cd Glance && rg -n "session\.data\(for:|session\.bytes\(for:|\.shared\.data\(for:" Core/Network/
```
Expected: no output outside `HTTPTransport.swift`.

- [ ] **Step 6: Confirm the app shows the log end-to-end**

Install and launch on the booted simulator, open Settings, confirm a `DIAGNOSTICS` section with an `Error Logs` row appears between `CACHE` and `ABOUT`, that the subtitle reads `"0 entries · 0 errors"` on a fresh launch, and that tapping it opens an empty-state viewer. Trigger a failure by disabling network and pulling to refresh on a card, then confirm the entry count increments and the entry appears newest-first. Confirm Copy places the markdown report on the pasteboard and it begins `# Glance error report`.

```bash
xcrun simctl list devices booted   # confirm the destination id before launching
```

- [ ] **Step 7: Commit any verification-driven fixes**

If steps 1-6 required changes, commit them as a follow-up with a specific message describing what the verification caught. If nothing needed changing, do not create an empty commit.