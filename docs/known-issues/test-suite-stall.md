# Full test suite stalls ~10 minutes — RESOLVED

Status: **Fixed 2026-09-30.** The stall was caused by `CacheStoreTests` and
`CacheTTTests` sharing `UserDefaults.standard` across separate `CacheStore`
actor instances, triggering a deadlock/contention pattern when both suites
ran together.

## Fix applied

- `CacheStore` now accepts a `userDefaults: UserDefaults` parameter
  (defaults to `.standard` for production code)
- Both cache test suites now use isolated `UserDefaults(suiteName:)`
  instances, eliminating cross-suite contention

## Verified results

| Invocation | Before | After |
|---|---|---|
| `CacheStoreTests` alone | 32s | 20s |
| `CacheTTTests` alone | (not measured) | 18s |
| `CacheStoreTests` + `CacheTTTests` | **10m24s** | **36s** |

## Pre-existing failures (unchanged)

- `CacheTTTests.customRSSDefaultTTL` — known failure, not related to stall

## Remaining concern

Full `-only-testing:GlanceTests` still takes ~10min (other suites may have
similar issues). The scoped loop (`scripts/test-area.sh`) remains the
recommended workflow.
