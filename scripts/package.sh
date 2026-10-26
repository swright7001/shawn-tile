#!/bin/bash
set -euo pipefail
TILE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TILE_ROOT"
TILE_VERSION="${TILE_VERSION:-0.2.1}"
[[ -d 'dist/Shawn Tile.app' ]] || scripts/build.sh
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
