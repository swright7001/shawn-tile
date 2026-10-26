#!/bin/bash
set -euo pipefail
TILE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TILE_SOURCE="${1:-$TILE_ROOT/dist/Shawn Tile.app}"
TILE_DEST="$HOME/Applications/Shawn Tile.app"
if [[ ! -d "$TILE_SOURCE" ]]; then "$TILE_ROOT/scripts/build.sh"; fi
if pgrep -x ShawnTile >/dev/null; then
  echo 'Quit Shawn Tile from its menu before installing an update.' >&2; exit 1
fi
codesign --verify --deep --strict "$TILE_SOURCE"
TILE_BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$TILE_SOURCE/Contents/Info.plist")"
[[ "$TILE_BUNDLE" == com.shawnwright.ShawnTile ]] || { echo 'Refusing to install an unrelated app.' >&2; exit 1; }
mkdir -p "$HOME/Applications"
TILE_STAGE="$(mktemp -d "$HOME/Applications/.shawn-tile-install.XXXXXX")"
trap 'python3 - "$TILE_STAGE" <<"PY"
import pathlib,shutil,sys
p=pathlib.Path(sys.argv[1])
if p.exists() and p.parent == pathlib.Path.home()/"Applications" and p.name.startswith(".shawn-tile-install."):
 shutil.rmtree(p)
PY' EXIT
ditto "$TILE_SOURCE" "$TILE_STAGE/Shawn Tile.app"
if [[ -f "$HOME/Library/Application Support/Shawn Tile/Signing/identity.json" ]]; then
  "$TILE_ROOT/scripts/sign.sh" "$TILE_STAGE/Shawn Tile.app" --local
fi
codesign --verify --deep --strict "$TILE_STAGE/Shawn Tile.app"
if [[ -e "$TILE_DEST" ]]; then
  TILE_BACKUP="$TILE_DEST.backup-$(date +%Y%m%d%H%M%S)"
  mv "$TILE_DEST" "$TILE_BACKUP"
  printf 'Previous version saved to %s\n' "$TILE_BACKUP"
fi
mv "$TILE_STAGE/Shawn Tile.app" "$TILE_DEST"
open "$TILE_DEST" --args --settings
printf 'Installed to %s\nThe first switch to a local identity needs an Accessibility grant; later updates reuse it.\n' "$TILE_DEST"
