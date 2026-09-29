#!/usr/bin/env bash
# Run only the test suites for the area you're working in.
#
#   scripts/test-area.sh Madrid              # one suite
#   scripts/test-area.sh Madrid PoGo Cache   # several suites
#   scripts/test-area.sh --list              # available suite names
#   scripts/test-area.sh --no-build Madrid   # skip build-for-testing
#
# Builds once, then reuses that build for every later run. A scoped run is
# ~20-30s; a full -only-testing:GlanceTests run is ~10min. Scope while iterating.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Glance/Glance.xcodeproj"
SCHEME="Glance"
TEST_TARGET="GlanceTests"

# The already-booted simulator. Override with GLANCE_SIM_ID.
SIM_ID="${GLANCE_SIM_ID:-4ABF9BBF-AB35-4739-B282-0EE19B2CE023}"
SIM_OS="${GLANCE_SIM_OS:-26.5}"
DESTINATION="platform=iOS Simulator,id=$SIM_ID,OS=$SIM_OS"

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

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") [--no-build] <Suite> [Suite...]" >&2
  echo >&2
  echo "available suites:" >&2
  list_suites | sed 's/^/  /' >&2
  exit 2
fi

# Accept "Madrid" as shorthand for "MadridPipelineTests" when unambiguous.
# Echoes the resolved name, or nothing if unresolvable. Never exits, so it is
# safe to call in a command substitution.
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

# Resolve every name up front and abort on the first bad one. An unresolved name
# must never reach xcodebuild: a bare "-only-testing:GlanceTests/" would
# silently run the whole suite.
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

if [[ $DO_BUILD -eq 1 ]]; then
  echo "==> build-for-testing ($DESTINATION)"
  xcodebuild build-for-testing \
    -project "$PROJECT" -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|warning: .*deprecat|TEST BUILD" || true
fi

echo "==> test-without-building: ${FLAGS[*]}"
exec xcodebuild test-without-building \
  -project "$PROJECT" -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  "${FLAGS[@]}" 2>&1 | grep -E "Test case .*(passed|failed)|error:|TEST EXECUTE"
