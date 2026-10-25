# Executed verification — 2026-10-25

Environment: this Mac, macOS 27.0.1 (26A434), arm64; Apple Swift 6.3 from Command Line Tools; SDK 26.4; one virtual 1920×1080 display with usable AX bounds (0,30,1920,1050). No full Xcode installation. ARM and Intel binaries compile with a macOS 13 deployment target; older macOS/Intel execution has not been tested.

| Criterion | Executed check | Result |
| --- | --- | --- |
| Layout bounds/no overlap | `swift run TileCoreChecks`; grid/columns/rows, 1–4 tiles, gaps 0/10/32, landscape/portrait/negative coordinates, golden frames | PASS; 6 scenarios, 1,203 assertions |
| Stack semantics | Same executable: focused overflow, close/removal, capacity reduction/promotion, stable order, swap and cycle | PASS |
| Both architectures | `scripts/build.sh`; compile arm64 and x86_64, combine with lipo | PASS; `lipo -archs` reports x86_64 arm64 |
| Real window discovery and isolation | Packaged executable `--integration-test`; launches five disposable standard resizable windows in a child PID; manager restricted to that PID; separate temporary preferences | PASS; all other desktop apps excluded |
| Real layout positions | Five fixture AX windows produce exactly three unique target frames matching TileCore; capacity four promotes overflow | PASS |
| Real Focus | Active-window lookup selects requested fixture; ordinary `toggleFocus()` expands it; restore returns exact prior bounds | PASS |
| Lifecycle reflow | Close, minimize, restore a fixture window; read actual AX/CG state; allow two seconds for minimize/restore animation | PASS |
| Pre-tiling restore | Restore tracked original geometry and confirm automatic tiling pauses | PASS |
| Real integration total | Final packaged binary; fixture PID 24167 | PASS; 11 checks, zero failures; fixtures terminated and temporary preferences removed |
| Native startup/settings/menu | Packaged executable `--smoke-test`; separate temporary preference domain; visible settings, populated menu | PASS; one display, settings visible, 14 menu items |
| Shortcut registration and event handling | Smoke check registers 15 global bindings; posts a discrete Carbon hotkey event to the main event queue; capacity changes from 3 to 1 through the real handler | PASS; zero registration failures, event status 0, observed capacity 1 |
| Installed app UI | Install under ~/Applications, launch with Launch Services, inspect native AX tree and screenshot; Keyboard tab; change capacity via native picker from 3 to 4 and back | PASS; preview and controls update |
| Permission boundary | Installed app launched separately from trusted command runner | PASS; reports missing app-specific Accessibility, keeps auto-tiling disabled and offers settings link |
| Distribution integrity | `codesign --verify --deep --strict`; ZIP extraction, compare executable SHA-256; readonly DMG mount and verify contained app; `shasum -a 256 -c SHA256SUMS` | PASS; see terminal execution record; MIT license and installation guide included |
| Scripts | `bash -n scripts/*.sh` | PASS |

The initial XCTest route could not run because this Command Line Tools installation has no XCTest module. Tests were converted to a standalone executable; they were not silently skipped. Early integration runs exposed fixture focus/timing assumptions and test-runner shutdown issues. The final run exercises the normal active-window focus path and waits for macOS minimize animation, with process-isolated cleanup.

## Remaining checks and limits

- The installed app still needs its own Accessibility grant from Shawn. The trusted command-runner test does not establish that a separately launched app inherits this permission. No TCC database or OS permission setting was changed.
- CUA-synthesized global key chords did not change the installed app's layout. Registration and a discrete Carbon event through the real event queue pass; physical keyboard delivery, Secure Input behavior and collisions with Shawn's other utilities remain to verify. No claim of physical shortcut verification is made.
- No physical second display, unplug/replug, actual macOS Space switching, Stage Manager, login-service registration, long-session performance, or broad collection of third-party apps was tested. Negative coordinates and portrait layouts are covered synthetically.
- No Intel hardware or macOS 13 host execution. Both code slices are compiled and bundled.
- Ad hoc signature verified; Developer ID signing/notarization was not performed. Gatekeeper acceptance on the other Mac remains a user-side install step.
- Apps can reject small sizes. Fixed split geometry reports constraints; it does not negotiate learned minimum sizes. Dialog/panel filtering follows AX subroles and public current-screen metadata.
- Public reference demo behavior is distinct from native Shoji; no full parity claim.
- GitHub Actions independently passed on macOS 15: layout/state checks, universal build, package, and artifact upload. Run: https://github.com/swright7001/shawn-tile/actions/runs/40246784375 (source b904402fcac33e4129355467a799014156f2d03f). This still does not test physical Intel hardware or app permissions on another Mac.

## Reproduce

```sh
swift run TileCoreChecks
./scripts/build.sh
'dist/Shawn Tile.app/Contents/MacOS/ShawnTile' --diagnostics
'dist/Shawn Tile.app/Contents/MacOS/ShawnTile' --integration-test
'dist/Shawn Tile.app/Contents/MacOS/ShawnTile' --smoke-test
./scripts/package.sh
(cd dist && shasum -a 256 -c SHA256SUMS)
```

Quit an installed copy before the smoke run so it does not occupy this app's global shortcuts. The real AX test requires Accessibility for its launch context; it reports SKIP otherwise. It never enables automation for ordinary apps. Installer: `scripts/install.sh`; second Mac: use the release DMG and docs/INSTALL.txt.

## Delivery

Private repository: https://github.com/swright7001/shawn-tile. Source tag v0.1.0 and published release: https://github.com/swright7001/shawn-tile/releases/tag/v0.1.0. DMG, ZIP and SHA256SUMS uploaded successfully; GitHub asset SHA-256 digests match the locally verified archives. Installed final app at `~/Applications/Shawn Tile.app`; native setup UI visibly shows the permission requirement and automatic tiling off. No OS permission was granted automatically.
