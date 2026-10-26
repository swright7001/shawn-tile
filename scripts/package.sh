#!/bin/bash
set -euo pipefail
TILE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TILE_ROOT"
[[ -d 'dist/Shawn Tile.app' ]] || scripts/build.sh
TILE_BUILT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' 'dist/Shawn Tile.app/Contents/Info.plist')"
TILE_VERSION="${TILE_VERSION:-$TILE_BUILT_VERSION}"
[[ "$TILE_VERSION" == "$TILE_BUILT_VERSION" ]] || { echo 'Package version must match the built app.' >&2; exit 1; }
lipo 'dist/Shawn Tile.app/Contents/MacOS/ShawnTile' -verify_arch arm64 x86_64
codesign --verify --deep --strict 'dist/Shawn Tile.app'
TILE_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/shawn-tile.XXXXXX")"
trap 'rm -rf "$TILE_STAGE"' EXIT
ditto 'dist/Shawn Tile.app' "$TILE_STAGE/Shawn Tile.app"
ln -s /Applications "$TILE_STAGE/Applications"
cp docs/INSTALL.txt "$TILE_STAGE/READ ME FIRST.txt"
ditto -c -k --sequesterRsrc --keepParent 'dist/Shawn Tile.app' "dist/ShawnTile-$TILE_VERSION-universal.zip"
hdiutil create -volname 'Shawn Tile' -srcfolder "$TILE_STAGE" -ov -format UDZO "dist/ShawnTile-$TILE_VERSION-universal.dmg" >/dev/null
(cd dist && shasum -a 256 "ShawnTile-$TILE_VERSION-universal.zip" "ShawnTile-$TILE_VERSION-universal.dmg" > SHA256SUMS)
printf 'Packages created in %s/dist\n' "$TILE_ROOT"
