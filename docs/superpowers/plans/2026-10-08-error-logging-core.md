# Error Logging Core and Diagnostics UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture in-app errors to a capped on-disk JSONL file, expose them in Settings behind a row, and copy or share a markdown report sized for pasting into an AI agent for root-cause analysis.

**Architecture:** `LogStore` is an `actor` owning the file — its only job is durability. `AppLog` is a singleton `actor` holding entries newest-first in memory as the authoritative state; reads never touch disk. `LogExport` turns entries into a markdown RCA report. Two SwiftUI views in Settings: a row with counts, and a list viewer loaded once as a snapshot.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Testing (`import Testing`), Foundation `FileManager`/`JSONEncoder`, Xcode project manual registration.

**Spec:** `docs/superpowers/specs/2026-10-08-error-logging-design.md`

## Global Constraints

- Build: `cd Glance && xcodebuild -project Glance.xcodeproj -scheme Glance -destination 'platform=iOS Simulator,id=4ABF9BBF-AB35-4739-B282-0EE19B2CE023,OS=26.5' CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"`
- Test one suite at a time: `scripts/test-area.sh LogStore` (~20s). **Never** run `make test-full`, `make test-quick`, or a bare `xcodebuild test` — the full suite stalls ~10min.
- `CODE_SIGNING_ALLOWED=NO` is mandatory; the local team has no valid certificate, so a provisioning error is not a code error.
- No comments in code. Names must be self-documenting.
- Styling only via `Theme.Colors.*`, `Theme.Fonts.manrope(_)`, `Theme.Radius.*`.
- `@Observable` (never `ObservableObject`) for view models; `@MainActor` on any view model.
- **Every new `.swift` file must be registered in `Glance/Glance.xcodeproj/project.pbxproj`** or it is silently not compiled. `.gitignore` blocks `*.xcodeproj`, so stage with `git add -f Glance/Glance.xcodeproj/project.pbxproj`.
- Timestamps in persisted models are `Int64` millisecond values from `Date.now.millisecondsSinceEpoch` (`Glance/Shared/Extensions.swift:5`) — never `Date`. This is the `CacheEnvelope` convention and it means no JSON date-strategy mismatch is possible.
- Persisted logs live under Application Support, never Documents.
- Entry cap is **500**. Export shows newest **200** and states the total.
- Commit messages: imperative, lowercase, no period.

### Xcode project registration (repeats in every task that adds files)

For each new file, make **four** edits to `Glance/Glance.xcodeproj/project.pbxproj`. Generate one fresh 24-uppercase-hex ID per file, e.g. `7A1C0001000000000000E001` (file reference) and `7A1C0002000000000000E001` (build file). Do **not** use a Python `pbxproj`/`xcodeproj` library — they corrupt the file. Use `sed`/manual edit.

1. `PBXBuildFile` section — add next to any existing entry:
   `7A1C0002000000000000E001 /* LogStore.swift in Sources */ = {isa = PBXBuildFile; fileRef = 7A1C0001000000000000E001 /* LogStore.swift */; };`
2. `PBXFileReference` section:
   `7A1C0001000000000000E001 /* LogStore.swift */ = {isa = PBXFileReference; explicitFileType = sourcecode.swift; path = LogStore.swift; sourceTree = "<group>"; };`
3. `PBXGroup` `children` for the parent group — add the file reference line.
4. `PBXSourcesBuildPhase` `files` for the **Glance** target (`EBCDFE4FC64A11F71EA4B02E`, line ~876) — add the build-file line.

**Which sources phase to use — do not guess.** There are three, and picking the wrong one compiles nothing while looking correct:

| Phase ID | Target |
|---|---|
| `EBCDFE4FC64A11F71EA4B02E` | **Glance** (app) — production files |
| `15A885ECB27CC8627B5F3B25` | **GlanceTests** — unit test files |
| `3DBB368CD5652076C0E21630` | **GlanceUITests** — UI test files |

New test files use the same four edits, but the parent group is `GlanceTests` (`path = GlanceTests;`) and the sources phase is `15A885ECB27CC8627B5F3B25`. Confirm by checking that a neighbouring test file such as `CacheStoreTests.swift` appears in that phase's `files` list.

**Existing parent group IDs** (add new files to these rather than creating groups, unless stated):

| Group | ID | Path |
|---|---|---|
| `Core` | `912CA63D0B9F8BB79753CF7F` | `Core` |
| `Network` | `18FEA4FE7CA2EB551AA1EB0B` | `Network` |
| `Settings` | see `path = Settings;` | `Settings` |
| `GlanceTests` | see `path = GlanceTests;` | `GlanceTests` |

Verify after editing:
```bash
plutil -lint Glance/Glance.xcodeproj/project.pbxproj
cd Glance && rg -c "LogStore.swift" Glance.xcodeproj/project.pbxproj   # expect 4
```
Then run the build command from Global Constraints and confirm `BUILD SUCCEEDED`.

## Review Focus

The spec states intent, not every input. These five are the inputs a user will actually hit that no task's happy-path test covers; each has a test pinned to its owning task below.

1. **A corrupt or half-written final line.** A crash mid-append leaves a truncated JSON line. Expect: every other entry still loads, the log viewer still opens.
2. **A device clock moving backwards** (timezone change, NTP correction) makes `timestampMs` non-monotonic. Expect: entries keep log order; nothing sorts wrongly or gets dropped as "oldest".
3. **`clear()` racing a `record()`** at app background. Expect: no crash, no thrown error into the caller, and no resurrection of cleared entries from a stale in-memory count.
4. **Zero entries.** A fresh install with the viewer as the first thing opened. Expect: a proper empty state, not a blank list and not a crash on an empty array's `first`/`last`.
5. **An entry whose `message` contains a newline or a very long URL.** Expect: one log line stays one list row and one markdown line — the report must not be corrupted by a multi-line message.

---

### Task 1: LogEntry and LogLevel

**Files:**
- Create: `Glance/Core/Logging/LogLevel.swift`
- Create: `Glance/Core/Logging/LogEntry.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `enum LogLevel: String, Codable, Sendable, CaseIterable, Comparable` with cases `error`, `warning`, `info`
  - `struct LogEntry: Codable, Sendable, Identifiable, Equatable` with `id: UUID`, `timestampMs: Int64`, `level: LogLevel`, `subsystem: String`, `message: String`, `detail: String?`
  - `LogEntry.init(id: UUID = UUID(), timestampMs: Int64 = Date.now.millisecondsSinceEpoch, level: LogLevel = .error, subsystem: String, message: String, detail: String? = nil)`
  - `LogEntry.displayTimestamp: Date` computed from `timestampMs`
  - `LogLevel.label: String` returning `"ERROR"` / `"WARNING"` / `"INFO"` (uppercase — used verbatim in the markdown report)

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/LogEntryTests.swift`:

```swift
import Testing
@testable import Glance
import Foundation

@Suite("LogEntry")
struct LogEntryTests {
    @Test("Round trips through JSON with Int64 timestamp")
    func roundTrip() throws {
        let entry = LogEntry(
            timestampMs: 1_758_000_000_000,
            level: .warning,
            subsystem: "github",
            message: "HTTP 403",
            detail: "retryAfter=nil"
        )
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(LogEntry.self, from: data)
        #expect(decoded.timestampMs == 1_758_000_000_000)
        #expect(decoded.level == .warning)
        #expect(decoded.subsystem == "github")
        #expect(decoded.message == "HTTP 403")
        #expect(decoded.detail == "retryAfter=nil")
        #expect(decoded.id == entry.id)
    }

    @Test("Level ordering puts error above warning above info")
    func levelOrder() {
        #expect(LogLevel.error < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.info)
    }

    @Test("Level labels are uppercase for the report")
    func labels() {
        #expect(LogLevel.error.label == "ERROR")
        #expect(LogLevel.warning.label == "WARNING")
        #expect(LogLevel.info.label == "INFO")
    }

    @Test("Unknown keys from another build decode fine")
    func unknownKeys() throws {
        let json = #"{"id":"E0F4A1B2-C3D4-4E5F-8A9B-0C1D2E3F4A5B","timestampMs":1,"level":"error","subsystem":"s","message":"m","futureField":true}"#
        let entry = try JSONDecoder().decode(LogEntry.self, from: Data(json.utf8))
        #expect(entry.subsystem == "s")
    }

    @Test("displayTimestamp converts millis to a Date")
    func displayTimestamp() {
        let entry = LogEntry(timestampMs: 0, subsystem: "s", message: "m")
        #expect(entry.displayTimestamp.timeIntervalSince1970 == 0)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh LogEntry`
Expected: FAIL — `cannot find 'LogEntry' in scope` (the suite is discovered by the `struct …Tests` grep even though the type does not exist).

- [ ] **Step 3: Implement `LogLevel.swift`**

Create `Glance/Core/Logging/LogLevel.swift`:

```swift
import Foundation

enum LogLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case error
    case warning
    case info

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    var rank: Int {
        switch self {
        case .error: 0
        case .warning: 1
        case .info: 2
        }
    }

    var label: String {
        rawValue.uppercased()
    }
}
```

- [ ] **Step 4: Implement `LogEntry.swift`**

Create `Glance/Core/Logging/LogEntry.swift`:

```swift
import Foundation

struct LogEntry: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let timestampMs: Int64
    let level: LogLevel
    let subsystem: String
    let message: String
    let detail: String?

    init(
        id: UUID = UUID(),
        timestampMs: Int64 = Date.now.millisecondsSinceEpoch,
        level: LogLevel = .error,
        subsystem: String,
        message: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestampMs = timestampMs
        self.level = level
        self.subsystem = subsystem
        self.message = message
        self.detail = detail
    }

    var displayTimestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000)
    }
}
```

- [ ] **Step 5: Register both files in the Xcode project**

Apply the four `pbxproj` edits from Global Constraints for `LogLevel.swift` and `LogEntry.swift`. Both belong to a **new** `Logging` group nested under `Core` (`912CA63D0B9F8BB79753CF7F`, whose `children` are `Cache`, `Network`, `Intelligence`, `Time`, `Utilities`). Create the group with `path = Logging;` and add it to `Core`'s children, then add the two file references to the `Logging` group's children. Files on disk go in `Glance/Core/Logging/`.

Verify: `plutil -lint` passes, `rg -c "LogEntry.swift" Glance.xcodeproj/project.pbxproj` returns 4, and the build command reports `BUILD SUCCEEDED`.

- [ ] **Step 6: Run the test to verify it passes**

Run: `scripts/test-area.sh LogEntry`
Expected: PASS — 5 tests.

- [ ] **Step 7: Commit**

```bash
git add Glance/Core/Logging Glance/GlanceTests/LogEntryTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add LogEntry and LogLevel"
```

---

### Task 2: Error logDetail

**Files:**
- Create: `Glance/Core/Logging/Error+LogDetail.swift`
- Modify: none

**Interfaces:**
- Consumes: `GlanceError` (`Glance/Shared/Enums.swift:10`), from Task 1's project registration pattern
- Produces:
  - `extension Error { var logDetail: String? }` — returns `"\(domain)/\(code) \(localizedDescription)"` when the concrete error type is an `NSError` subclass, otherwise `nil`
  - `extension GlanceError { var logDetail: String }` — a stable, non-empty string for all ten cases, never falling back to `localizedDescription`

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/ErrorLogDetailTests.swift`:

```swift
import Testing
@testable import Glance
import Foundation

private struct PureSwiftFailure: Error {}

@Suite("Error logDetail")
struct ErrorLogDetailTests {
    @Test("Pure Swift errors report no detail rather than a fabricated one")
    func pureSwift() {
        let error: Error = PureSwiftFailure()
        #expect(error.logDetail == nil)
    }

    @Test("GlanceError never falls back to localizedDescription")
    func glanceErrorNeverUsesLocalizedDescription() {
        let cases: [GlanceError] = [
            .keyMissing("exaKey"),
            .networkError("boom"),
            .rateLimited(retryAfter: 30),
            .decodingError("bad json"),
            .networkUnavailable,
            .httpStatus(503),
            .decodingFailed,
            .unauthorized,
            .cacheMiss("key"),
            .notConfigured("gemini"),
        ]
        for error in cases {
            let detail = (error as Error).logDetail
            #expect(detail != nil)
            #expect(detail?.isEmpty == false)
            #expect(detail?.contains("couldn't be completed") == false)
        }
    }

    @Test("Each GlanceError case keeps its identity")
    func identityPreserved() {
        #expect(GlanceError.keyMissing("exaKey").logDetail.contains("exaKey"))
        #expect(GlanceError.httpStatus(503).logDetail.contains("503"))
        #expect(GlanceError.rateLimited(retryAfter: 30).logDetail.contains("30"))
        #expect(GlanceError.unauthorized.logDetail.lowercased().contains("unauthorized"))
        #expect(GlanceError.notConfigured("gemini").logDetail.contains("gemini"))
    }

    @Test("Rate limited with no retry-after still reports identity")
    func rateLimitedNilRetryAfter() {
        let detail = GlanceError.rateLimited(retryAfter: nil).logDetail
        #expect(detail.isEmpty == false)
        #expect(detail.lowercased().contains("rate"))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh ErrorLogDetail`
Expected: FAIL — `value of type 'Error' has no member 'logDetail'`.

- [ ] **Step 3: Implement `Glance/Core/Logging/Error+LogDetail.swift`**

Create the file with two extensions. For `Error`:

```swift
extension Error {
    var logDetail: String? {
        guard type(of: self) is NSError.Type else { return nil }
        let error = self as NSError
        return "\(error.domain)/\(error.code) \(error.localizedDescription)"
    }
}
```

The guard is the whole point: a pure-Swift error bridged to `NSError` yields the module name as `domain` and declaration order as `code`. Absent detail reads as "not captured"; a fabricated one is worse than nothing because it looks like identity.

For `GlanceError`, write an exhaustive `switch` over all ten cases returning a stable string — `"keyMissing: exaKey"`, `"networkError: boom"`, `"rateLimited retryAfter=30"` (or `"rateLimited"` when nil), `"decodingError: bad json"`, `"networkUnavailable"`, `"httpStatus: 503"`, `"decodingFailed"`, `"unauthorized"`, `"cacheMiss: key"`, `"notConfigured: gemini"`. Because `GlanceError` has no `LocalizedError` conformance, its `Error.logDetail` would otherwise produce Foundation's default `The operation couldn't be completed. (GlanceError.networkUnavailable error 0.)`, which names neither domain nor cause.

- [ ] **Step 4: Register the file in the Xcode project**

Four `pbxproj` edits per Global Constraints, into the `Logging` group created in Task 1. Verify `plutil -lint` and a 4-hit grep, then build to confirm `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `scripts/test-area.sh ErrorLogDetail`
Expected: PASS — 4 tests.

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Logging/Error+LogDetail.swift Glance/GlanceTests/ErrorLogDetailTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: capture error identity in logDetail"
```

---

### Task 3: LogStore — capped JSONL file

**Files:**
- Create: `Glance/Core/Logging/LogStore.swift`
- Create: `Glance/GlanceTests/LogStoreTests.swift`

**Interfaces:**
- Consumes: `LogEntry` from Task 1
- Produces:
  - `actor LogStore` with `nonisolated let fileURL: URL`, `init(directory: URL? = nil, fileName: String = "glance-log.jsonl", cap: Int = 500)`
  - `func load() throws -> [LogEntry]` — **oldest-first**, decoded line-by-line with `compactMap`, trimmed to the newest `cap`
  - `func append(_ entry: LogEntry) throws` — appends `record + "\n"`, trims to cap *after* appending, rewriting only on a cap crossing
  - `func clear() throws` — empties memory, count, and the file
  - `private(set) var rewrites: Int` — incremented on each cap-trim rewrite; test-visible counter for the "never re-read the file to count" rule

`directory: nil` resolves to `<Application Support>/Glance`. The test in Review Focus row 4 (rule 9) asserts the resolved path is under Application Support and not Documents.

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/LogStoreTests.swift` with `@Suite("LogStore") struct LogStoreTests` and a `private func makeStore(cap: Int = 3) -> LogStore` that returns `LogStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("test.LogStore.\(UUID().uuidString)", isDirectory: true), cap: cap)`. Isolation per test is mandatory — shared backing storage across actor instances is what caused the 10-minute full-suite stall documented in `docs/known-issues/test-suite-stall.md`.

Add a `private func lines(_ store: LogStore) async throws -> [String]` helper returning `String(contentsOf: store.fileURL, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: true).map(String.init)`.

Tests, all `async throws`:

| Test | Asserts |
|---|---|
| `roundTrip` | Append `"m0"`, `"m1"`; `load()` returns 2, in that order, oldest-first |
| `missingFile` | `load()` on a fresh store returns empty — no throw |
| `newlineOnEveryPath` | After 5 appends with `cap: 2`, the file text `hasSuffix("\n")` and every line independently `JSONDecoder().decode`s to a `LogEntry` |
| `trimPathStaysDecodable` | With `cap: 2`, 6 appends leave exactly 2 lines, containing `"m4"` and `"m5"` |
| `capDropsOldest` | `cap: 3`, 10 appends → `load().map(\.message) == ["m7","m8","m9"]` |
| `rewriteCount` | `cap: 3`, 9 appends → `await store.rewrites == 2` |
| `corruptLineIsolated` | See below |
| `truncatedFinalLine` | See below |
| `nonMonotonicTimestamps` | Clock moving backwards preserves insertion order |
| `clearResets` | `clear()` empties; a later append yields only the new message |
| `applicationSupportLocation` | See below |
| `countIsNotReread` | See below |

`corruptLineIsolated` — append two good entries, then `FileHandle(forWritingTo: store.fileURL)`, `seekToEnd()`, write `{"timestampMs":4,"trunc` + `"\n"`, then a valid encoded `LogEntry` + `"\n"`, close. Assert `load()` returns 3 entries, `["good1","good2","good3"]`. This is Review Focus row 1.

`truncatedFinalLine` — append `"intact"`, then append raw bytes `{"timestampMs":2,"messa` with **no** trailing newline to simulate a crash mid-write. Assert `load().map(\.message) == ["intact"]`.

`applicationSupportLocation` — `LogStore().fileURL.path` contains `"Application Support"`, `hasSuffix("glance-log.jsonl")`, and does **not** start with `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path`. This pins rule 9.

`countIsNotReread` — with `cap: 4`: 4 appends → `rewrites == 0`; then 36 more → `rewrites == 9`; `lines(store).count == 4`. This is the rule-6 regression test: if the count were re-read per write, `rewrites` would be far higher.

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh LogStore`
Expected: FAIL — `cannot find 'LogStore' in scope`.

- [ ] **Step 3: Implement `Glance/Core/Logging/LogStore.swift`**

Create `actor LogStore`:

```swift
actor LogStore {
    nonisolated let fileURL: URL
    private let cap: Int
    private var entries: [LogEntry] = []
    private var loaded = false
    private(set) var rewrites = 0

    init(
        directory: URL? = nil,
        fileName: String = "glance-log.jsonl",
        cap: Int = 500
    ) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Glance", isDirectory: true)
        self.fileURL = base.appendingPathComponent(fileName)
        self.cap = cap
        try? FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: true
        )
    }
}
```

This is the app's first `FileManager` usage anywhere, so the `createDirectory` call is net-new and needs `withIntermediateDirectories: true`.

`ensureLoaded() throws` runs `load()`'s body when `loaded == false`. `append(_:)` is `try ensureLoaded()`, then appends, then **trims after appending** and only rewrites when over cap — trimming first would rewrite the file on every subsequent record:

```swift
func append(_ entry: LogEntry) throws {
    try ensureLoaded()
    entries.append(entry)
    guard entries.count > cap else { return }
    entries = Array(entries.suffix(cap))
    try rewrite()
    rewrites += 1
}
```

`rewrite()` writes `entries.map { encode($0) + "\n" }` joined with no extra separator — **the trailing `\n` on the last record is what rule 3 is about**. Omitting it produces one undecodable run of `}{}{}` on the first trim, and `load()` then silently returns empty while the in-memory copy keeps working, which looks fine until relaunch loses everything.

`load()` returns **oldest-first** and decodes line-by-line:

```swift
func load() throws -> [LogEntry] {
    loaded = true
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
        entries = []
        return []
    }
    let text = try String(contentsOf: fileURL, encoding: .utf8)
    let decoder = JSONDecoder()
    entries = text
        .split(separator: "\n", omittingEmptySubsequences: true)
        .compactMap { try? decoder.decode(LogEntry.self, from: Data($0.utf8)) }
        .suffix(cap)
    return entries
}
```

`compactMap` is the point: one corrupt line — a crash mid-write, a hand edit — costs one entry instead of the whole document. `.suffix(cap)` drops oldest-first, keeping the newest.

`clear()` empties `entries`, writes an empty file, and leaves `loaded == true` so a stale count can never resurrect cleared entries.

- [ ] **Step 4: Register the file in the Xcode project**

Four `pbxproj` edits per Global Constraints into the `Logging` group. Verify `plutil -lint`, 4-hit grep, and `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `scripts/test-area.sh LogStore`
Expected: PASS — 12 tests. If `countIsNotReread` or `rewriteCount` fail, the trim is happening before the append or on every write rather than once per cap crossing.

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Logging/LogStore.swift Glance/GlanceTests/LogStoreTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add capped JSONL LogStore"
```

---

### Task 4: AppLog — the in-memory mirror

**Files:**
- Create: `Glance/Core/Logging/AppLog.swift`

**Interfaces:**
- Consumes: `LogEntry`, `LogLevel` (Task 1), `LogStore` (Task 3), `Error.logDetail` (Task 2)
- Produces:
  - `actor AppLog` with `static let shared: AppLog`
  - `init(store: LogStore = .shared, cap: Int = 500)`
  - `func record(_ level: LogLevel = .error, subsystem: String, message: String, detail: String? = nil)` — **non-throwing**, never propagates a storage failure into the operation being logged
  - `func record(_ level: LogLevel = .error, subsystem: String, message: String, error: Error)` — convenience overload that fills `detail` from `error.logDetail`
  - `func snapshot() -> [LogEntry]` — **newest-first**
  - `func clear()` — non-throwing
  - `func setMinimumLevel(_ level: LogLevel)` — drives the viewer's debug toggle
  - `var count: Int` and `var errorCount: Int` for the Settings row

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/AppLogTests.swift` with `@Suite("AppLog") struct AppLogTests` and `private func makeLog(cap: Int = 500) -> (AppLog, LogStore)` returning `(AppLog(store: LogStore(directory: <unique temp dir>, cap: cap), cap: cap), store)`. Also declare `private struct SampleFailure: Error {}` at file scope — a pure-Swift error with no `NSError` backing.

Tests, all `async`:

| Test | Asserts |
|---|---|
| `newestFirst` | Two records → `snapshot().map(\.message) == ["second","first"]` |
| `errorOverload` | Recording with `GlanceError.httpStatus(503)` → `snapshot().first?.detail?.contains("503") == true` |
| `errorOverloadPureSwift` | Recording with `SampleFailure()` → `detail == nil` |
| `durableAcrossInstances` | Record into one `AppLog`, then build a second `AppLog` over the same `LogStore` → its `snapshot().map(\.message) == ["persisted"]`. This pins the cold-start lazy load |
| `mirrorCap` | `cap: 2`, three records → `["c","b"]` |
| `threshold` | `setMinimumLevel(.warning)`, then record `.error` and `.info` → only the error survives |
| `defaultThreshold` | Without calling `setMinimumLevel`, `.error` survives and `.info` does not |
| `errorCount` | One `.error` + one `.warning` → `count == 2`, `errorCount == 1` |
| `clearBoth` | After `clear()`, `count == 0`, `try await store.load().isEmpty`, and a later record yields only `["new"]`. This is Review Focus row 3 |

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh AppLog`
Expected: FAIL — `cannot find 'AppLog' in scope`.

- [ ] **Step 3: Implement `Glance/Core/Logging/AppLog.swift`**

Create `actor AppLog`. This is a **deliberate deviation** from the app's DI convention (`@Environment` for three types, `@State` construction for the rest) — thread a short comment at the `static let shared` declaration recording that, so it does not drift back.

```swift
actor AppLog {
    // Deliberate deviation from the app's DI convention: threading a logger
    // through session → client factory → transport leaves holes exactly where
    // failures originate, and a logger unavailable at a call site is a logger
    // that does not exist.
    static let shared = AppLog()

    private let store: LogStore
    private let cap: Int
    private var mirror: [LogEntry] = []
    private var loaded = false
    private var minimumLevel: LogLevel = .error

    init(store: LogStore = .shared, cap: Int = 500) {
        self.store = store
        self.cap = cap
    }
}
```

`record(_:subsystem:message:error:)` captures `error.logDetail` **before** any mapping happens downstream, then delegates to `record(_:subsystem:message:detail:)`. Order matters: a mapper that keeps only `localizedDescription` destroys domain/code/userInfo, so recording downstream yields "something went wrong" for every distinct cause.

`record(_:subsystem:message:detail:)` must never throw:

```swift
func record(_ level: LogLevel = .error, subsystem: String, message: String, detail: String? = nil) {
    guard level >= minimumLevel else { return }
    if loaded == false {
        mirror = ((try? store.load()) ?? []).reversed()
        loaded = true
    }
    let entry = LogEntry(level: level, subsystem: subsystem, message: message, detail: detail)
    mirror.insert(entry, at: 0)
    if mirror.count > cap { mirror.removeLast(mirror.count - cap) }
    try? store.append(entry)
}
```

`try?` on the append is not defensive sloppiness — a log write must never propagate into the operation being logged, or a logging failure presents to the user as the product failing. The lazy `load` reconciles durability with the read path: after a cold start the mirror is empty, so something must read once, but opening the viewer still never touches disk. `LogStore.load()` returns oldest-first, hence `.reversed()`.

`snapshot()` returns `mirror` (already newest-first). `clear()` sets `mirror = []`, leaves `loaded == true`, and calls `try? store.clear()`. `setMinimumLevel(_:)` assigns the threshold.

- [ ] **Step 4: Register the file in the Xcode project**

Four `pbxproj` edits per Global Constraints into the `Logging` group. Verify `plutil -lint`, 4-hit grep, and `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `scripts/test-area.sh AppLog`
Expected: PASS — 9 tests. If `durableAcrossInstances` fails, `record` is not doing the lazy load before inserting.

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Logging/AppLog.swift Glance/GlanceTests/AppLogTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add AppLog in-memory mirror over LogStore"
```

---

### Task 5: LogExport markdown RCA report

**Files:**
- Create: `Glance/Core/Logging/LogExport.swift`
- Create: `Glance/GlanceTests/LogExportTests.swift`

**Interfaces:**
- Consumes: `LogEntry`, `LogLevel` (Task 1), `AppVersion` (`Glance/Shared/AppVersion.swift`, `.current`, `.display` → `"1.4.2 (build 9)"`)
- Produces:
  - `enum LogExport` with `static func markdown(entries: [LogEntry], appVersion: AppVersion, device: String, maxEntries: Int = 200) -> String`
  - `static var currentDevice: String` returning `"iOS 26.5 · iPhone17,2"` from `UIDevice.current`
  - `static func sanitize(_ text: String) -> String` — collapses newlines and carriage returns to spaces so one entry stays one report line

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/LogExportTests.swift` with `@Suite("LogExport") struct LogExportTests`, `private let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.4.2", "CFBundleVersion": "9"])`, and a `private func entry(_:subsystem:level:detail:ts:)` helper defaulting `subsystem` to `"github"`, `level` to `.error`, `ts` to `1_758_000_000_000`. Every test calls `LogExport.markdown(entries:appVersion:device:)` with `device: "d"` unless noted.

| Test | Asserts |
|---|---|
| `header` | With two entries → contains `"# Glance error report"`, `"1.4.2 (build 9)"` (from `AppVersion.display`), and `"iOS 26.5 · iPhone17,2"` when that is the passed device |
| `summaryGroupsBySubsystem` | Entries `("old 403", ts 1)`, `("latest 500", ts 3)`, `("decode failed", subsystem: "openrouter", ts 2)` → contains `"github: 2 errors (last: latest 500)"` and `"openrouter: 1 error (last: decode failed)"`. Note the singular — this pins the pluralization |
| `emptyExport` | `markdown(entries: [], …)` → contains `"# Glance error report"` and `"0 entries"`. Review Focus row 4 |
| `truncationNotice` | 250 entries, `maxEntries: 200` → contains `"newest 200 of 250"`; count lines containing `"ERROR"` == 200 |
| `noNoticeWhenComplete` | 1 entry → text does **not** contain `"newest"` |
| `timeline` | Two entries ts 1 and ts 2 → the `"older"` occurrence appears at a higher string index than `"newer"`; text contains `"detail: retryAfter=nil"` |
| `sanitizesNewlines` | Message `"first line\nsecond line\nthird"` → text contains `"first line second line third"` and does not contain `"second line\n"`. Review Focus row 5 |
| `omitsMissingDetail` | Entry with `detail: nil` → text does not contain `"detail:"` |

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh LogExport`
Expected: FAIL — `cannot find 'LogExport' in scope`.

- [ ] **Step 3: Implement `Glance/Core/Logging/LogExport.swift`**

Create `enum LogExport` as a namespace of static functions — no instances.

`sanitize(_:)` replaces `\n` and `\r` with a space and collapses runs of whitespace, so one log entry can never break the report's line structure. This is Review Focus row 5.

`markdown(entries:appVersion:device:maxEntries:)` builds the report by appending into a `[String]` joined with `"\n"`. Structure, in order:

1. `# Glance error report`
2. Version/device line: `"\(appVersion.display) · \(device)"` — use `AppVersion.display`, which already formats `"1.4.2 (build 9)"`.
3. Window line: `"Window: \(oldest.displayTimestamp) → \(newest.displayTimestamp)"`, or `"Window: —"` when `entries.isEmpty`.
4. Count line: `"<shown> entries, <errorCount> errors"`, plus `" (showing newest \(shown) of \(entries.count))"` **only when** `entries.count > maxEntries`.
5. `## Summary` — group by subsystem, one line each, sorted by count descending then name; the format is `"<subsystem>: <n> error(s) (last: <most recent message>)"` using `LogLevel.label` semantics for capitalization.
6. `## Timeline (newest first)` — for each entry, one line
   `"[<HH:mm:ss>] <LABEL padded to 7> <subsystem padded to 10> <sanitized message>"`, then, only when `detail != nil`, an indented second line `"    detail: \(sanitize(detail))"`.

Take the newest `maxEntries` entries first (`entries` arrives newest-first, so `prefix(maxEntries)`), and derive the summary from **the shown subset** so the counts never disagree with the timeline. Format timestamps with a fixed `HH:mm:ss` `DateFormatter` at `en_US_POSIX` with the current `TimeZone` — a fixed locale keeps the agent's parse stable.

`currentDevice` reads `UIDevice.current.systemVersion` and `UIDevice.current.model`. Import `UIKit` for it.

- [ ] **Step 4: Register the file in the Xcode project**

Four `pbxproj` edits per Global Constraints into the `Logging` group. Verify `plutil -lint`, 4-hit grep, and `BUILD SUCCEEDED`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `scripts/test-area.sh LogExport`
Expected: PASS — 8 tests. If `summaryGroupsBySubsystem` fails on `"1 error"` versus `"1 errors"`, singular/plural is not being handled.

- [ ] **Step 6: Commit**

```bash
git add Glance/Core/Logging/LogExport.swift Glance/GlanceTests/LogExportTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add markdown RCA report export"
```

---

### Task 6: Diagnostics section and log viewer

**Files:**
- Create: `Glance/Settings/DiagnosticsSection.swift`
- Create: `Glance/Settings/LogViewerView.swift`
- Modify: `Glance/Settings/SettingsView.swift:15-20` (insert the section between `CacheSection` and the `Divider()` + `AboutSection`)
- Create: `Glance/GlanceTests/LogViewerModelTests.swift`

**Interfaces:**
- Consumes: `AppLog.snapshot()`, `AppLog.count`, `AppLog.errorCount`, `AppLog.clear()`, `AppLog.setMinimumLevel(_:)` (Task 4); `LogEntry` (Task 1); `LogExport.markdown(entries:appVersion:device:maxEntries:)` and `LogExport.currentDevice` (Task 5)
- Produces:
  - `@MainActor @Observable final class LogViewerModel` with `entries: [LogEntry]`, `query: String`, `minimumLevel: LogLevel`, `isLoading: Bool`, `init(log: AppLog = .shared)`, `func load() async`, `func clear() async`, `func exportText() -> String`, `var filteredEntries: [LogEntry]`
  - `struct DiagnosticsSection: View` with `init(model: LogViewerModel)`
  - `struct LogViewerView: View` with `init(model: LogViewerModel)`

- [ ] **Step 1: Write the failing test**

Create `Glance/GlanceTests/LogViewerModelTests.swift` with `@Suite("LogViewerModel") @MainActor struct LogViewerModelTests` and `private func makeModel(cap: Int = 500) -> (LogViewerModel, LogStore)` returning `(LogViewerModel(log: AppLog(store: LogStore(directory: <unique temp dir>, cap: cap), cap: cap)), store)`.

Tests, all `async`:

| Test | Asserts |
|---|---|
| `load` | Two records → `model.entries.map(\.message) == ["second","first"]`, `isLoading == false` |
| `emptyState` | `load()` on an empty log → `entries.isEmpty` and `filteredEntries.isEmpty`, no crash. Review Focus row 4 |
| `search` | Two entries; `query = "403"` → 1 result; `query = "openrouter"` → 1 result |
| `export` | `exportText()` contains `"# Glance error report"`, the message, and the detail string |
| `clear` | After `clear()`, `entries.isEmpty` |
| `levelForwarding` | Setting `model.minimumLevel = .info` then recording `.info` → `load()` yields 1 entry |

- [ ] **Step 2: Run the test to verify it fails**

Run: `scripts/test-area.sh LogViewerModel`
Expected: FAIL — `cannot find 'LogViewerModel' in scope`.

- [ ] **Step 3: Implement `LogViewerModel` in `LogViewerView.swift`**

Put the model in `LogViewerView.swift`, above the view — the file owns "what the viewer shows", mirroring how `OpenRouterModelsLoader` lives beside `OpenRouterModelListView` in `OpenRouterModelPicker.swift`.

```swift
@MainActor
@Observable
final class LogViewerModel {
    private let log: AppLog
    private(set) var entries: [LogEntry] = []
    var query = ""
    var minimumLevel: LogLevel = .error {
        didSet { Task { await log.setMinimumLevel(minimumLevel) } }
    }
    private(set) var isLoading = false

    init(log: AppLog = .shared) { self.log = log }
}
```

`load()` sets `isLoading`, awaits `log.snapshot()`, clears `isLoading`. The viewer is a **snapshot** loaded once in `.task` — live-updating while open is a deliberate deferral, not an oversight.

`filteredEntries` matches `query` case-insensitively against both `message` and `subsystem`, returning `entries` when `query` is empty.

`exportText()` returns `LogExport.markdown(entries: entries, appVersion: .current, device: LogExport.currentDevice)`.

`clear()` awaits `log.clear()` then reloads.

- [ ] **Step 4: Implement `LogViewerView` in the same file**

Model it on `OpenRouterModelListView` (`Glance/Settings/OpenRouterModelPicker.swift:87-149`), the app's one existing `List`-based collection viewer, which already solves loading, error, empty, search, and refresh:

- `List { ForEach(model.filteredEntries) { row($0) } }` with `.listStyle(.insetGrouped)`, `.navigationTitle("Error Logs")`, `.navigationBarTitleDisplayMode(.inline)`
- `.searchable(text: $model.query, prompt: "Search logs")` — requires `@Bindable var model` on the view
- `.overlay { if model.isLoading && model.entries.isEmpty { ProgressView() } }`
- Empty state: when `model.entries.isEmpty`, show a `GlanceEmptyView` (`Glance/DesignSystem/Components.swift:87`) with a title like "No errors recorded" — **not** a blank list, and never index into an empty array
- `row(_:)` — `HStack` with a level-tinted badge using `Theme.Colors.cardEmerald` for `.error`, `Theme.Colors.cardAmber` for `.warning`, `Theme.Colors.textMuted` for `.info`; message in `Theme.Fonts.manrope(13)`; a second line with `"HH:mm:ss · subsystem"` using `TimeFormat.formatDate`; detail as a third line in `Theme.Colors.textMuted`, `.lineLimit(2)`
- Toolbar items: **Copy** writes `model.exportText()` to `UIPasteboard.general.string` preceded by `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` (the existing idiom, e.g. `Glance/Features/Pulse/PulseView.swift:75`); **Share** uses `ShareLink(item: model.exportText())` — do **not** add a fourth hand-rolled `UIActivityViewController` presentation; **Clear** shows a destructive `.alert` confirm matching `CacheSection.swift:41-48`

- [ ] **Step 5: Implement `DiagnosticsSection` in `Glance/Settings/DiagnosticsSection.swift`**

Follow `SettingsView`'s actual structure — a `ScrollView` of hand-built sections, **not** a `List`:

```swift
struct DiagnosticsSection: View {
    let model: LogViewerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("DIAGNOSTICS")
            NavigationLink {
                LogViewerView(model: model)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Error Logs")
                            .font(Theme.Fonts.manrope(14))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(subtitle)
                            .font(Theme.Fonts.manrope(11))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                .padding(12)
                .background(Theme.Colors.canvasDeep, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
```

`subtitle` is `"\(model.entries.count) entries · \(errorCount) errors"`. The destination-closure `NavigationLink` form is copied from `OpenRouterModelPicker.swift:29-55`; no `navigationDestination` registration is needed because `SettingsView` already sits inside `NavigationStack(path: $bindable.settingsPath)` (`Glance/App/ContentView.swift:22`).

- [ ] **Step 6: Wire the section into `SettingsView`**

In `Glance/Settings/SettingsView.swift`, add `@State private var logViewerModel = LogViewerModel()` alongside the existing `@State private var cacheStore` / `settingsStore` (lines 4-5), and insert `DiagnosticsSection(model: logViewerModel)` **after** `CacheSection(...)` and **before** the `Divider()` + `AboutSection()`, so `ABOUT` stays last. Do not add anything to `AppState` — it holds navigation state only.

- [ ] **Step 7: Register the three files in the Xcode project**

Three sets of four `pbxproj` edits per Global Constraints: `DiagnosticsSection.swift` and `LogViewerView.swift` into the `Settings` group; `LogViewerModelTests.swift` into the `GlanceTests` group plus the `15A885ECB27CC8627B5F3B25` (GlanceTests) sources phase. Verify `plutil -lint`, a 4-hit grep per filename, and `BUILD SUCCEEDED`.

- [ ] **Step 8: Run the test to verify it passes**

Run: `scripts/test-area.sh LogViewerModel`
Expected: PASS — 6 tests.

- [ ] **Step 9: Build the app**

Run the Global Constraints build command.
Expected: `BUILD SUCCEEDED`. A `@Bindable` error means the view needs `@Bindable var model: LogViewerModel`; a missing-registration error means step 7's fourth edit was missed.

- [ ] **Step 10: Commit**

```bash
git add Glance/Settings Glance/GlanceTests/LogViewerModelTests.swift
git add -f Glance/Glance.xcodeproj/project.pbxproj
git commit -m "feat: add diagnostics log viewer to settings"
```

---

## Not in this plan

Plan B — `HTTPTransport`, `URLRedactor`, and migrating all 14 clients — is specified in the design doc but deliberately separated. Until it lands, capture is limited to whatever calls `AppLog.record`, which after this plan is nothing in production code. The viewer and export are fully functional against manually recorded entries; the wiring that makes them fill with real failures is Plan B.