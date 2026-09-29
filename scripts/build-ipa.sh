#!/usr/bin/env bash
# Build Glance and package an unsigned (fakesigned) IPA for sideloading.
#
#   scripts/build-ipa.sh
#
# Output: Glance/build/Glance-<version>-unsigned.ipa
#
# The IPA is ad-hoc signed ("fakesigned"), NOT signed with an Apple certificate.
# That is deliberate: AltStore/SideStore/LiveContainer all re-sign the app with
# the user's own Apple ID, so a real signature here would only be discarded.
#
# An entirely UNSIGNED app does not work though - SideStore's resign pipeline
# requires a signed input and fails with a bundle-id mismatch on a blank one.
# So we ad-hoc sign before packaging, which is what SideStore's own CI does
# (make fakesign -> make ipa).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Glance/Glance.xcodeproj"
SCHEME="Glance"
DERIVED="$ROOT/Glance/build/ipa"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Signature: ad-hoc only, with NO entitlements.
#
# Two things this must get right, both learned the hard way:
#
# 1. The app cannot be shipped completely unsigned. SideStore/AltStore re-sign
#    from an already-signed input; a blank app fails with "bundleid does not
#    match with the specified".
#
# 2. Do NOT hand-write application-identifier / keychain-access-groups. Those
#    contain Xcode placeholders like $(AppIdentifierPrefix) and `codesign` does
#    not expand them, so they get embedded literally and iOS rejects the install
#    with "The keychain access group '$(AppIdentifierPrefix)$(CFBundleIdentifier)'
#    does not contain a Team ID prefix."
#
# Glance needs no entitlements of its own: no app extensions, no app groups, and
# KeychainStore uses the default keychain (no kSecAttrAccessGroup). The user's
# sideloader adds whatever it needs when it re-signs with their Apple ID.
#
# We sign with zsign rather than `codesign` because zsign reallocates the
# embedded CodeSignature space (it reported "No enough CodeSignature space
# (now: 16368, need: 64519)"). Without that, SideStore's ldit/ldid path can hit
# an `_assert()` and fail the install outright. zsign is what SideStore,
# LiveContainer and Feather use, so matching it avoids a whole class of problems.

cd "$ROOT/Glance"

command -v zsign >/dev/null || {
  echo "zsign not found - install with: brew install zsign" >&2
  exit 1
}

echo "==> building Release for generic/platform=iOS"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" || true

APP="$DERIVED/Build/Products/Release-iphoneos/Glance.app"
[[ -d "$APP" ]] || { echo "build produced no $APP" >&2; exit 1; }

# An armv7 UIRequiredDeviceCapabilities entry (a common leftover in Info.plist)
# makes iOS reject the install outright, so normalise it to the real arch.
if /usr/libexec/PlistBuddy -c "Print :UIRequiredDeviceCapabilities" "$APP/Info.plist" 2>/dev/null | grep -q armv7; then
  echo "==> removing stale armv7 from UIRequiredDeviceCapabilities"
  /usr/libexec/PlistBuddy -c "Delete :UIRequiredDeviceCapabilities" "$APP/Info.plist"
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")"

# zsign works on a folder and re-signs in place.
echo "==> ad-hoc signing with zsign (no entitlements)"
zsign -a "$APP" 2>&1 | grep -iE "space|sign|error" | tail -3

# Verify the signature on the .app BEFORE packaging, so a bad one fails here
# rather than on someone's phone.
codesign --verify --deep --strict "$APP" \
  || { echo "ad-hoc signature failed verification" >&2; exit 1; }

echo "==> packaging"
rm -f "$DERIVED/Glance-v$VERSION-unsigned.ipa"
mkdir -p "$STAGE/ipa/Payload"
cp -R "$APP" "$STAGE/ipa/Payload/"
# zsign leaves the tree in place; compress from the staged copy.
( cd "$STAGE/ipa" && zip -qry "$DERIVED/Glance-v$VERSION-unsigned.ipa" Payload )
OUT="$DERIVED/Glance-v$VERSION-unsigned.ipa"

# Re-verify the signature after zipping: recompression must not disturb it.
VERIFY="$STAGE/verify"
mkdir -p "$VERIFY"
( cd "$VERIFY" && unzip -q "$OUT" )
codesign --verify --deep --strict "$VERIFY/Payload/Glance.app" \
  || { echo "signature broke during packaging" >&2; exit 1; }

echo
echo "    bundle id   : $BUNDLE_ID"
echo "    version     : $VERSION ($BUILD)"
echo "    min iOS     : $(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$APP/Info.plist")"
echo "    arch        : $(lipo -info "$APP/Glance" | sed 's/.*architecture: //')"
echo "    signature   : $(codesign -dv "$APP" 2>&1 | grep -o 'CodeDirectory.*location=embedded')"
echo "    entitlements: $(codesign -d --entitlements - --xml "$APP" 2>/dev/null | plutil -p - 2>/dev/null | tr -d '\n' | head -c 40 || echo none)"
echo "    size        : $(du -h "$OUT" | cut -f1)"
echo "    sha256      : $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
