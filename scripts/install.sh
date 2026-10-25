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
mkdir -p "$HOME/Applications"
if [[ -e "$TILE_DEST" ]]; then
  TILE_BACKUP="$TILE_DEST.backup-$(date +%Y%m%d%H%M%S)"
  mv "$TILE_DEST" "$TILE_BACKUP"
  printf 'Previous version saved to %s\n' "$TILE_BACKUP"
fi
ditto "$TILE_SOURCE" "$TILE_DEST"
open "$TILE_DEST" --args --settings
printf 'Installed to %s\nEnable Shawn Tile in Privacy & Security > Accessibility, then turn on Automatic tiling.\n' "$TILE_DEST"
