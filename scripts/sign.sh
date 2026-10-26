#!/bin/bash
set -euo pipefail
TILE_APP="${1:?Usage: scripts/sign.sh /path/to/Shawn Tile.app [--local]}"
TILE_MODE="${2:-auto}"
TILE_CONFIG="$HOME/Library/Application Support/Shawn Tile/Signing/identity.json"
TILE_BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$TILE_APP/Contents/Info.plist")"
[[ "$TILE_BUNDLE" == com.shawnwright.ShawnTile ]] || { echo 'Refusing to sign an unrelated app.' >&2; exit 1; }
TILE_LOCAL=false
if [[ "$TILE_MODE" == --local || ( -z "${TILE_SIGN_IDENTITY+x}" && -f "$TILE_CONFIG" ) ]]; then
  TILE_IDENTITY="$(python3 - "$TILE_CONFIG" <<'PY'
import json,pathlib,re,sys
p=pathlib.Path(sys.argv[1]); data=json.loads(p.read_text())
value=data.get('identity','')
if not re.fullmatch('[0-9A-Fa-f]{40}',value) or data.get('bundle_identifier')!='com.shawnwright.ShawnTile':
 raise SystemExit('Invalid local signing configuration; refusing an ad hoc fallback.')
print(value.upper())
PY
)"
  TILE_LOCAL=true
else
  TILE_IDENTITY="${TILE_SIGN_IDENTITY:--}"
fi
if [[ "$TILE_LOCAL" == true ]]; then
  # Pin both the app identity and the actual signer. Never use an identifier-only requirement.
  TILE_REQUIREMENT="designated => identifier \"com.shawnwright.ShawnTile\" and certificate leaf = H\"$TILE_IDENTITY\""
  # A pre-signed local update needs verification only, not another private-key operation.
  if python3 - "$TILE_APP" "$TILE_IDENTITY" <<'PYVERIFY'
import re,subprocess,sys
app,identity=sys.argv[1:]
expected='identifier "com.shawnwright.ShawnTile" and certificate leaf = H"'+identity+'"'
r=subprocess.run(['/usr/bin/codesign','-d','-r-',app],capture_output=True,text=True)
m=re.search(r'(?m)^#?\s*designated =>(.+)$',r.stdout+'\n'+r.stderr)
if not m or m.group(1).strip().lower()!=expected.lower():
 raise SystemExit(1)
r=subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict','--test-requirement','='+expected,app],capture_output=True)
raise SystemExit(r.returncode)
PYVERIFY
  then
    printf 'Existing local signature verified: %s\n' "$TILE_IDENTITY"
    exit 0
  fi
  codesign --force --sign "$TILE_IDENTITY" --timestamp=none --identifier com.shawnwright.ShawnTile --requirements "=$TILE_REQUIREMENT" "$TILE_APP"
  codesign --verify --deep --strict --test-requirement "=identifier \"com.shawnwright.ShawnTile\" and certificate leaf = H\"$TILE_IDENTITY\"" "$TILE_APP"
  printf 'Signed with persistent local identity: %s\n' "$TILE_IDENTITY"
else
  codesign --force --sign "$TILE_IDENTITY" --identifier com.shawnwright.ShawnTile "$TILE_APP"
  codesign --verify --deep --strict "$TILE_APP"
  printf 'Signed with identity: %s\n' "$TILE_IDENTITY"
fi
