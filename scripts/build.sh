#!/bin/bash
set -euo pipefail
TILE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TILE_ROOT"
TILE_VERSION="${TILE_VERSION:-0.2.1}"
TILE_ARCH="${1:-universal}"
TILE_APP="$TILE_ROOT/dist/Shawn Tile.app"
mkdir -p "$TILE_APP/Contents/MacOS" "$TILE_APP/Contents/Resources"
if [[ "$TILE_ARCH" == universal ]]; then
  swift build -c release --triple arm64-apple-macosx13.0
  swift build -c release --triple x86_64-apple-macosx13.0
  lipo -create .build/arm64-apple-macosx/release/ShawnTile .build/x86_64-apple-macosx/release/ShawnTile -output "$TILE_APP/Contents/MacOS/ShawnTile"
else
  swift build -c release
  cp .build/release/ShawnTile "$TILE_APP/Contents/MacOS/ShawnTile"
fi
cat > "$TILE_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ShawnTile</string>
<key>CFBundleIdentifier</key><string>com.shawnwright.ShawnTile</string>
<key>CFBundleName</key><string>Shawn Tile</string>
<key>CFBundleDisplayName</key><string>Shawn Tile</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$TILE_VERSION</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Shawn Wright. MIT License.</string>
</dict></plist>
PLIST
swift scripts/icon.swift "$TILE_ROOT/dist/AppIcon.iconset"
iconutil -c icns "$TILE_ROOT/dist/AppIcon.iconset" -o "$TILE_APP/Contents/Resources/AppIcon.icns"
cp LICENSE "$TILE_APP/Contents/Resources/LICENSE"
codesign --force --sign "${TILE_SIGN_IDENTITY:--}" --identifier com.shawnwright.ShawnTile "$TILE_APP"
codesign --verify --deep --strict "$TILE_APP"
printf 'Built %s\n' "$TILE_APP"
