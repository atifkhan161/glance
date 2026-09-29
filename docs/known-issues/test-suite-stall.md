# Full test suite stalls ~10 minutes — open investigation

Status: **root cause unknown.** Reproduced on a clean checkout of `main`, so it is not
caused by any local change. Not currently blocking work — the scoped test loop in
`AGENTS.md` avoids it entirely.

## Symptom

Any test run that includes both `CacheStoreTests` and `CacheTTTests` lands at
**10:22–10:24 wall clock**. One log showed `619.880 elapsed`. The time is not test
execution:

| Signal | Value |
|---|---|
| Wall clock | 10m24s |
| CPU (user + sys) | ~1.3s total |
| Sum of all 158 test cases | 4.354s |
| A single serial run's own report | "Test run with 154 tests in 24 suites … after 4.354 seconds" |

A fixed ~10-minute wall time with ~0% CPU is a timeout or retry loop, not work.

## Bisection

| Invocation | Wall clock |
|---|---|
| `MadridPipelineTests` alone | 19s |
| 3 suites together | 24s |
| `IntelligenceRouterTests` alone | 25s |
| `GitHubTrendingClientTests` alone | ~25s |
| `CacheStoreTests` alone | 32s |
| **`CacheStoreTests` + `CacheTTTests`** | **10m24s** |
| Full `-only-testing:GlanceTests` | 10m24s |

So the trigger is the *combination* of the two cache suites, not either alone. The
network-dependent suite is not implicated — it completes in ~25s.

## Things already ruled out

- **Not the build.** `build-for-testing` incremental is 13s, and
  `test-without-building` on the full suite is *still* 10m24s.
- **Not CPU-bound.** ~1.3s of CPU across 10.5 minutes.
- **Not per-suite overhead.** 1 suite and 3 suites both cost ~23s. The ~22s is fixed
  setup (clone + install + launch), not scaling with suite count.
- **Not caused by a dirty working tree.** Reproduced with changes stashed.
- **Not a networking wait.** No `Task.sleep` in the test sources.

## Lead

Both cache suites exercise `CacheStore` concurrently. Prime suspects:

- A shared-cache or actor deadlock that only manifests when the two suites interleave
  (e.g. `CacheStore.hydrate()` racing an eviction pass).
- A retry/backoff loop in the cache eviction path.
- Cross-suite state — `CacheStore` is process-wide, and the two suites may be writing
  the same keys under different `defaultTTLs`.

`CacheTTTests` also contains `customRSSDefaultTTL`, which is a *known* pre-existing
failure. Worth checking whether the stall correlates with the failure path rather than
the suite.

## Next steps

1. Narrow within `CacheTTTests` — run individual test cases via
   `-only-testing:GlanceTests/CacheTTTests/<testName>` to find the specific case that
   triggers the stall.
2. Repeat with only `CacheStoreTests` + the single offending `CacheTTTests` case.
3. Attach a debugger or add signposts around `CacheStore` eviction/hydrate and look for
   a blocked actor.
4. Check for a test-runner timeout being hit: 10m is suspiciously round. Confirm whether
   something external caps the run and retries.

## Workaround meanwhile

Use the scoped loop. It never hits the stall:

```bash
scripts/test-area.sh Madrid
```
