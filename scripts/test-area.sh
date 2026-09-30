#!/usr/bin/env bash
# Run only the test suites for the area you're working in.
#
#   scripts/test-area.sh Madrid              # one suite
#   scripts/test-area.sh Madrid PoGo Cache   # several suites
#   scripts/test-area.sh --list              # available suite names
#   scripts/test-area.sh --no-build Madrid   # skip build-for-testing
#   scripts/test-area.sh --all               # run every suite
#
# Builds once, then reuses that build for every later run. A scoped run is
# ~3s warm, ~20s cold. The full suite stalls ~10min if run as one target —
# scope to the suite you're changing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Glance/Glance.xcodeproj"
SCHEME="Glance"
TEST_TARGET="GlanceTests"

SIM_ID="${GLANCE_SIM_ID:-4ABF9BBF-AB35-4739-B282-0EE19B2CE023}"
SIM_OS="${GLANCE_SIM_OS:-26.5}"
DESTINATION="platform=iOS Simulator,id=$SIM_ID,OS=$SIM_OS"

log() { echo "[$(date +%H:%M:%S)] $*" >&2; }

boot_sim() {
  local state
  state="$(xcrun simctl list devices booted 2>/dev/null | grep "$SIM_ID" || true)"
  if [[ -n "$state" ]]; then
    log "simulator already booted"
    return 0
  fi
  log "booting simulator $SIM_ID"
  xcrun simctl boot "$SIM_ID" 2>&1 || true
  for _ in $(seq 1 30); do
    if xcrun simctl list devices booted 2>/dev/null | grep -q "$SIM_ID"; then
      log "simulator ready"
      return 0
    fi
    sleep 1
  done
  log "WARNING: simulator did not boot in time"
}

list_suites() {
  grep -rhoE 'struct [A-Za-z0-9_]+Tests' "$ROOT/Glance/GlanceTests" \
    | awk '{print $2}' | sort -u
}

if [[ "${1:-}" == "--list" ]]; then
  list_suites
  exit 0
fi

DO_BUILD=1
if [[ "${1:-}" == "--no-build" ]]; then
  DO_BUILD=0
  shift
fi

# Default: run all suites when no args given (whole-target).
if [[ $# -eq 0 ]]; then
  set -- $(list_suites)
fi

# Accept "Madrid" as shorthand for "MadridPipelineTests" when unambiguous.
resolve_suite() {
  local want="$1" matches count
  if list_suites | grep -qx "$want"; then
    echo "$want"
    return 0
  fi
  matches="$(list_suites | grep "^${want}" || true)"
  count="$(grep -c . <<<"$matches" || true)"
  if [[ "$count" == "0" ]]; then
    echo ""
    return 0
  fi
  if [[ "$count" == "1" ]]; then
    echo "$matches"
    return 0
  fi
  echo "$count|$matches"
}

FLAGS=()
for suite in "$@"; do
  resolved="$(resolve_suite "$suite")"
  if [[ -z "$resolved" ]]; then
    echo "unknown suite: $suite" >&2
    echo "run '$(basename "$0") --list' to see available suites" >&2
    exit 2
  fi
  if [[ "$resolved" == *"|"* ]]; then
    echo "ambiguous suite prefix: $suite -> ${resolved#*|}" >&2
    exit 2
  fi
  FLAGS+=("-only-testing:$TEST_TARGET/$resolved")
done

cd "$ROOT/Glance"

boot_sim

BUILD_SEC=0
if [[ $DO_BUILD -eq 1 ]]; then
  log "==> build-for-testing ($DESTINATION)"
  T0=$(date +%s)
  xcodebuild build-for-testing \
    -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | grep --line-buffered -E "error:|warning: .*deprecat|TEST BUILD" || true
  BUILD_SEC=$(( $(date +%s) - T0 ))
  log "build done in ${BUILD_SEC}s"
fi

log "==> test-without-building: ${FLAGS[*]}"
T0=$(date +%s)
TMPFILE=$(mktemp /tmp/test-results.XXXXXX.txt)
xcodebuild test-without-building \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  "${FLAGS[@]}" > "$TMPFILE" 2>&1
grep -E "Test case .*(passed|failed)|error:|TEST EXECUTE" "$TMPFILE" || true
TEST_SEC=$(( $(date +%s) - T0 ))
log "tests done in ${TEST_SEC}s (build: ${BUILD_SEC}s, total: $((BUILD_SEC + TEST_SEC))s)"
rm -f "$TMPFILE"