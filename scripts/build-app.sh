#!/bin/zsh
# Builds Perch.app from the Swift package.
#   scripts/build-app.sh            → build/Perch.app
#   scripts/build-app.sh --install  → also copies it to /Applications and opens it
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/Perch.app"

# Universal binary (Apple Silicon + Intel), one build folder per architecture.
swift build -c release --triple arm64-apple-macosx14.0 --scratch-path .build/release-arm64
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/release-x86_64
ARM="$(swift build -c release --triple arm64-apple-macosx14.0 --scratch-path .build/release-arm64 --show-bin-path)/Perch"
X86="$(swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/release-x86_64 --show-bin-path)/Perch"
BIN="build/Perch-universal"
mkdir -p build
lipo -create "$ARM" "$X86" -output "$BIN"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Perch"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# A stable signing identity keeps the "control Spotify" permission across rebuilds.
# Uses a "Perch Local Signing" certificate, else Glow's, else ad-hoc.
IDENTITY=""
for candidate in "Perch Local Signing" "Glow Local Signing"; do
  if security find-identity -p codesigning 2>/dev/null | grep -q "\"$candidate\""; then
    IDENTITY="$candidate"; break
  fi
done
if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --entitlements Resources/Perch.entitlements \
    --sign "$IDENTITY" --identifier com.merterbil.perch "$APP"
  echo "Signed with \"$IDENTITY\""
else
  codesign --force --options runtime --entitlements Resources/Perch.entitlements --sign - "$APP"
  echo "Signed ad-hoc (the Spotify permission resets after each rebuild)"
fi
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x Perch 2>/dev/null || true
  sleep 1
  rm -rf /Applications/Perch.app
  cp -R "$APP" /Applications/
  open /Applications/Perch.app
  echo "Installed to /Applications and launched."
fi
