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

ENTITLEMENTS="$STAGE/entitlements.plist"
cat > "$ENTITLEMENTS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>get-task-allow</key>
	<true/>
	<key>keychain-access-groups</key>
	<array>
		<string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
	</array>
	<key>application-identifier</key>
	<string>$(AppIdentifierPrefix)$(CFBundleIdentifier)</string>
</dict>
</plist>
PLIST

cd "$ROOT/Glance"

echo "==> building Release for generic/platform=iOS"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD" || true

APP="$DERIVED/Build/Products/Release-iphoneos/Glance.app"
[[ -d "$APP" ]] || { echo "build produced no $APP" >&2; exit 1; }

echo "==> ad-hoc signing (fakesign)"
codesign --force --sign - --timestamp=none --entitlements "$ENTITLEMENTS" "$APP" 2>&1 | tail -1

# An armv7 UIRequiredDeviceCapabilities entry (a common leftover in Info.plist)
# makes iOS reject the install outright, so normalise it to the real arch.
if /usr/libexec/PlistBuddy -c "Print :UIRequiredDeviceCapabilities" "$APP/Info.plist" 2>/dev/null | grep -q armv7; then
  echo "==> removing stale armv7 from UIRequiredDeviceCapabilities"
  /usr/libexec/PlistBuddy -c "Delete :UIRequiredDeviceCapabilities" "$APP/Info.plist"
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")"
OUT="$ROOT/Glance/build/Glance-v$VERSION-unsigned.ipa"

echo "==> packaging $OUT"
rm -f "$OUT"
mkdir -p "$STAGE/ipa/Payload"
cp -R "$APP" "$STAGE/ipa/Payload/"
( cd "$STAGE/ipa" && zip -qry "$OUT" Payload )

echo
echo "    bundle id   : $BUNDLE_ID"
echo "    version     : $VERSION ($BUILD)"
echo "    min iOS     : $(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$APP/Info.plist")"
echo "    arch        : $(lipo -info "$APP/Glance" | sed 's/.*architecture: //')"
echo "    signature   : $(codesign -dv "$APP" 2>&1 | grep -o 'flags=.*' | head -1)"
echo "    size        : $(du -h "$OUT" | cut -f1)"
echo "    sha256      : $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
