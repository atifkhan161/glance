#!/usr/bin/env bash
# Cut a Glance release: bump the version, build the IPA, tag, publish, and
# update the SideStore source so in-app updates work.
#
#   scripts/release.sh 1.2.1
#   scripts/release.sh patch      # 1.2.0 -> 1.2.1
#   scripts/release.sh minor      # 1.2.1 -> 1.3.0
#   scripts/release.sh major      # 1.2.1 -> 2.0.0
#
# Every asset goes on its own immutable tag (v1.2.1) and is named
# Glance-<version>.ipa, so a version's downloadURL can never silently change.
#
# apps.json is generated from the real IPA metadata - version, size, and
# downloadURL are read out of the build, never typed by hand. That is the whole
# point: a hand-maintained version string drifting from CFBundleShortVersionString
# is why SideStore updates silently stop appearing.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${GLANCE_REPO:-atifkhan161/glance}"
PLIST="$ROOT/Glance/Resources/Info.plist"
APPS_JSON="$ROOT/apps.json"

# The build script names the asset Glance-v<version>-unsigned.ipa. We want a
# clean per-version name, so rename it rather than changing build-ipa.sh's
# output convention.

command -v zsign >/dev/null || { echo "zsign not found - brew install zsign" >&2; exit 1; }
command -v gh >/dev/null || { echo "gh not found - brew install gh" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh not authenticated" >&2; exit 1; }

# ---------------------------------------------------------------- version arg

read_version() { /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST"; }
read_build()   { /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST"; }

bump() { # bump <part> <current>
  local part="$1" cur="$2"
  local maj min pat
  maj="$(cut -d. -f1 <<<"$cur")"
  min="$(cut -d. -f2 <<<"$cur")"
  pat="$(cut -d. -f3 <<<"$cur")"
  # Treat 1.2 as 1.2.0 so a patch bump is well defined.
  [[ -z "$pat" ]] && pat=0
  case "$part" in
    patch) echo "$maj.$min.$((pat + 1))" ;;
    minor) echo "$maj.$((min + 1)).0" ;;
    major) echo "$((maj + 1)).0.0" ;;
    *) echo "$part" ;;   # already an explicit version
  esac
}

ARG="${1:-}"
[[ -n "$ARG" ]] || { echo "usage: $(basename "$0") <version|patch|minor|major>" >&2; exit 2; }

case "$ARG" in
  patch|minor|major) VERSION="$(bump "$ARG" "$(read_version)")" ;;
  [0-9]*.[0-9]*)    VERSION="$ARG" ;;
  *) echo "unrecognised version argument: $ARG" >&2; exit 2 ;;
esac

CURRENT="$(read_version)"
BUILD="$(read_build)"
[[ "$VERSION" == "$CURRENT" ]] && { echo "already at $VERSION" >&2; exit 2; }
if [[ "$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)" != "$VERSION" ]]; then
  echo "refusing to go backwards: $CURRENT -> $VERSION" >&2
  exit 2
fi

NEW_BUILD=$((BUILD + 1))
TAG="v$VERSION"
ASSET="Glance-$VERSION.ipa"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"
RELEASE_DATE="$(date -u +%Y-%m-%d)"

echo "==> $CURRENT (build $BUILD)  ->  $VERSION (build $NEW_BUILD)"
echo "    tag      : $TAG"
echo "    asset    : $ASSET"
echo "    download : $DOWNLOAD_URL"

# ------------------------------------------------------------- 1. bump + commit

echo "==> bumping version in Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

git add "$PLIST"
git commit -m "chore: bump version to $VERSION (build $NEW_BUILD)"

# ------------------------------------------------------------------ 2. build

echo "==> building and signing the IPA"
rm -rf "$ROOT/Glance/build"
"$ROOT/scripts/build-ipa.sh"

BUILT_IPA="$(find "$ROOT/Glance/build/ipa" -maxdepth 1 -name 'Glance-*.ipa' | head -1)"
[[ -n "$BUILT_IPA" ]] || { echo "no IPA produced by build-ipa.sh" >&2; exit 1; }
RELEASE_DIR="$ROOT/Glance/build/release"
mkdir -p "$RELEASE_DIR"
cp "$BUILT_IPA" "$RELEASE_DIR/$ASSET"

STAGED="$RELEASE_DIR/$ASSET"
SIZE="$(stat -f%z "$STAGED")"
SHA="$(shasum -a 256 "$STAGED" | cut -d' ' -f1)"

# The app target's real bundle id, read from the built product.
BUILT_APP="$(find "$ROOT/Glance/build" -maxdepth 6 -path "*Release-iphoneos/Glance.app" | head -1)"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$BUILT_APP/Info.plist")"
MIN_IOS="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$BUILT_APP/Info.plist")"

echo "    bundle id : $BUNDLE_ID"
echo "    size      : $SIZE bytes"
echo "    sha256    : $SHA"

# ------------------------------------------------------------- 3. apps.json

echo "==> writing apps.json"
python3 - "$APPS_JSON" "$BUNDLE_ID" "$VERSION" "$RELEASE_DATE" "$DOWNLOAD_URL" "$SIZE" "$MIN_IOS" <<'PY'
import json, os, sys, urllib.parse

path, bundle_id, version, date, url, size, min_ios = sys.argv[1:8]
size = int(size)

repo = os.environ.get("GLANCE_REPO", "atifkhan161/glance")
raw = f"https://raw.githubusercontent.com/{repo}/main/logos/export/logo-1024.png"

# Preserve versions already listed, newest first, then add ours at the front.
# SideStore shows the FIRST entry as "latest" regardless of version, so order
# is load-bearing.
existing = []
if os.path.exists(path):
    try:
        existing = json.load(open(path)).get("apps", [{}])[0].get("versions", [])
    except Exception:
        existing = []

ours = {
    "version": version,
    "date": date,
    "downloadURL": url,
    "size": size,
    "minOSVersion": min_ios,
    "localizedDescription": "Personal intelligence dashboard aggregating Real Madrid, Pokémon GO, GitHub Trending, AI intel and custom RSS into one card feed.",
}
versions = [ours] + [v for v in existing if v.get("version") != version]

doc = {
    "name": "Glance",
    "identifier": f"{bundle_id}.source",
    "sourceURL": f"https://raw.githubusercontent.com/{repo}/main/apps.json",
    "apps": [{
        "name": "Glance",
        "bundleIdentifier": bundle_id,
        "developerName": "Atif Khan",
        "subtitle": "Your feeds, one dashboard",
        "iconURL": raw,
        "tintColor": "#F5A524",
        "localizedDescription": (
            "A personal intelligence dashboard for iOS. Aggregates Real Madrid fixtures and "
            "match timeline, Pokémon GO raids and events, GitHub Trending, AI/ML news with "
            "on-device summaries, and any custom RSS feed into a single dark-mode card feed."
        ),
        "permissions": [
            {"type": "network", "usageDescription": "Fetches your feeds, fixtures and articles."},
            {"type": "background-fetch", "usageDescription": "Refreshes feeds in the background so data stays current."},
        ],
        "versions": versions,
    }],
    "news": [{
        "title": f"Glance {version}",
        "caption": f"Version {version} is available.",
        "date": date,
        "identifier": f"glance-{version}",
        "appID": bundle_id,
        "notify": True,
    }],
}

with open(path, "w") as fh:
    json.dump(doc, fh, indent=2)
    fh.write("\n")
print(f"    {len(versions)} version(s) listed, newest first")
PY

git add "$APPS_JSON"
git commit -m "chore: advertise $VERSION in SideStore source"

git push origin main

# ---------------------------------------------------------------- 4. publish

echo "==> tagging $TAG"
git tag -a "$TAG" -m "Glance $VERSION"
git push origin "$TAG"

echo "==> publishing release $TAG"
NOTES="$ROOT/Glance/build/release-notes.md"
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$STAGED" --clobber
else
  gh release create "$TAG" \
    --title "Glance $VERSION" \
    --notes "$(cat <<EOF
Personal intelligence dashboard for iOS.

\`$ASSET\` is ad-hoc signed but not certificate-signed, and carries no entitlements.
SideStore re-signs it with your Apple ID at install time.

- Version: \`$VERSION\` (build $NEW_BUILD)
- Bundle ID: \`$BUNDLE_ID\`
- Minimum iOS: $MIN_IOS
- SHA256: \`$SHA\`

Install: add \`https://raw.githubusercontent.com/$REPO/main/apps.json\` as a
SideStore source, or follow the README.
EOF
)" \
    "$STAGED"
fi

# ----------------------------------------------------------------- 5. verify

echo "==> verifying the published asset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
( cd "$TMP" && gh release download "$TAG" --repo "$REPO" -p "$ASSET" )
REMOTE_SHA="$(shasum -a 256 "$TMP/$ASSET" | cut -d' ' -f1)"
[[ "$REMOTE_SHA" == "$SHA" ]] || { echo "published asset differs from local build" >&2; exit 1; }
unzip -q "$TMP/$ASSET" -d "$TMP/x"
codesign --verify --deep --strict "$TMP/x/Payload/Glance.app"
echo "    asset matches local build and verifies"
echo
echo "==> published"
echo "    https://github.com/$REPO/releases/tag/$TAG"
echo "    source: https://raw.githubusercontent.com/$REPO/main/apps.json"
