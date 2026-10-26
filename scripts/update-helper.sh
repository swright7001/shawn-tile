#!/bin/bash
# Detached, unprivileged installation helper. Arguments are never evaluated as code.
set -euo pipefail
parent_pid="${1:?parent pid required}"
stage="${2:?staging folder required}"
destination="${3:?app path required}"
[[ "$parent_pid" =~ ^[0-9]+$ && "$destination" == /*.app && "$stage" == "$(dirname "$destination")"/.shawn-tile-update-* ]] || exit 64
stage_name="${stage##*/}"
[[ "$stage_name" =~ ^\.shawn-tile-update-[A-Fa-f0-9-]{36}$ ]] || exit 64
candidate="$stage/Shawn Tile.app"
[[ ! -L "$stage" && ! -L "$candidate" && ! -L "$destination" ]] || exit 65
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$candidate/Contents/Info.plist")
old_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$destination/Contents/Info.plist")
[[ "$bundle_id" == com.shawnwright.ShawnTile && "$old_id" == "$bundle_id" ]] || exit 66
backup=""
moved_old=false
relaunch=false
recover() {
    local result=$?
    if [[ "$result" != 0 ]]; then
        if [[ "$moved_old" == true && ! -e "$destination" && -d "$backup" ]]; then /bin/mv "$backup" "$destination"; fi
        if [[ "$relaunch" == true && -d "$destination" && "${TILE_UPDATE_TESTING:-0}" != 1 ]]; then /usr/bin/open "$destination" --args --settings || true; fi
    fi
}
trap recover EXIT
# Give the app time to unregister hotkeys and restore any Focus geometry.
for ((attempt=0; attempt<120; attempt++)); do
    if ! /bin/kill -0 "$parent_pid" 2>/dev/null; then break; fi
    /bin/sleep 0.25
done
if /bin/kill -0 "$parent_pid" 2>/dev/null; then echo 'Update cancelled: the old app is still running.'; exit 67; fi
relaunch=true
/usr/bin/codesign --verify --deep --strict "$candidate"
backup="$destination.backup-$(/bin/date +%Y%m%d%H%M%S)-$$"
[[ ! -e "$backup" ]] || exit 69
/bin/mv "$destination" "$backup"
moved_old=true
# Fault injection is used only by the disposable installer checks.
if [[ "${TILE_UPDATE_TEST_FAIL:-0}" == 1 ]] || ! /bin/mv "$candidate" "$destination"; then
    echo 'Update failed. Restoring the previous version.'
    exit 68
fi
moved_old=false
echo 'Update installed. Previous version retained as a backup.'
if [[ "${TILE_UPDATE_TESTING:-0}" != 1 ]]; then /usr/bin/open "$destination" --args --settings; fi
# Remove only our exact helper file and now-empty staging directory.
/bin/rm -f "$stage/update-helper.sh"
/bin/rmdir "$stage" 2>/dev/null || true
