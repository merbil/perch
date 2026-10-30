#!/bin/zsh
# Builds Perch.app (universal) and packs it into a drag-to-install DMG:
#   scripts/make-dmg.sh   →   build/Perch-<version>.dmg
# The app is signed with the local "Glow Local Signing" certificate (shared with Glow), not an Apple Developer ID,
# so on other Macs the first launch needs System Settings → Privacy & Security → "Open Anyway".
# A release is never ad-hoc signed: without that certificate this stops, because an app with a
# different signature would lose its permissions and could not be verified against earlier releases.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="Glow Local Signing"
LEAF_HASH="f519ee135554c4396e21cd5dc913182af45381e5"     # the certificate every release so far is signed with
if ! security find-identity -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""; then
  echo "ERROR: the \"$IDENTITY\" signing identity is missing (new Mac, or locked keychain?). Not building a release." >&2
  exit 1
fi

scripts/build-app.sh
codesign --verify --strict build/Perch.app
REQUIREMENT=$(codesign -d -r- build/Perch.app 2>&1)
if ! grep -q "H\"$LEAF_HASH\"" <<<"$REQUIREMENT"; then
  echo "ERROR: build/Perch.app's designated requirement doesn't contain the expected certificate hash $LEAF_HASH:" >&2
  echo "$REQUIREMENT" >&2
  exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
DMG="build/Perch-$VERSION.dmg"
STAGE=$(mktemp -d)

cp -R build/Perch.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/First launch – read me.txt" <<'TXT'
Installing Perch

1. Drag Perch onto the Applications folder.
2. Open Perch from Applications.
3. macOS says Perch "can't be opened" (it isn't from an identified developer). Click Done.
4. Open System Settings → Privacy & Security, scroll down, and click "Open Anyway" next to
   the message about Perch. Confirm with your password. You only do this once.
5. Equaliser bars with a bird appear in your menu bar. Play something in Spotify and
   allow Perch to control it when macOS asks.

More: https://github.com/merbil/perch
TXT

rm -f "$DMG"
hdiutil create -volname "Perch $VERSION" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$DMG" >/dev/null
rm -rf "$STAGE"
codesign --force --sign "$IDENTITY" "$DMG"
codesign --verify --strict "$DMG"
shasum -a 256 "$DMG"
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
