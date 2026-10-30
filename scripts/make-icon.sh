#!/bin/zsh
# Renders the app icon from the code (Views/Logo.swift) into Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
SET="build/AppIcon.iconset"
rm -rf "$SET"; mkdir -p "$SET"
.build/debug/Perch --icon build/AppIcon-1024.png
for size in 16 32 128 256 512; do
  sips -z $size $size build/AppIcon-1024.png --out "$SET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double build/AppIcon-1024.png --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
