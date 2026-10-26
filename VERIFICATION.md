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

Public repository: https://github.com/swright7001/shawn-tile. Source tag v0.1.0 and published release: https://github.com/swright7001/shawn-tile/releases/tag/v0.1.0. DMG, ZIP and SHA256SUMS uploaded successfully; GitHub asset SHA-256 digests match the locally verified archives. Installed final app at `~/Applications/Shawn Tile.app`; native setup UI visibly shows the permission requirement and automatic tiling off. No OS permission was granted automatically.

Public-sharing verification: unauthenticated GitHub API requests returned HTTP 200 for the repository (`private: false`) and latest release, listing the DMG, ZIP and SHA256SUMS. Friends can access the source and installers without a GitHub account.

## Permission mismatch investigation

User reported an enabled System Settings entry while the installed app remained
blocked. Read-only native inspection confirmed both states. Restarting the same
installed executable did not resolve it. A focused com.apple.TCC log query then
reported “Failed to match existing code requirement” for Shawn Tile and the
Accessibility service, with different stored and installed ad hoc code hashes.
This establishes a stale build-specific grant for this incident, rather than
an absent Settings toggle. The installed binary was not rebuilt or replaced.
Recovery instructions now explain removing the stale entry and explicitly
re-adding the exact installed app. During diagnosis no grant or TCC database was modified. After explicit user
authorization and user-completed macOS authentication, the stale Settings entry
was removed and the exact installed app was added again using System Settings.
The app then showed six eligible windows, no permission warning, and an enabled
Automatic tiling control. Automatic tiling was switched on and the native UI
confirmed it running, reporting three app-imposed size constraints. The installed
binary was not changed, and all other app permissions were left unchanged.

## Version 0.2 — adaptive fitting

The earlier fixed-split/minimum-size limitations describe 0.1. Version 0.2 adds
an original size-aware planner and observed-size feedback through the existing
public Accessibility APIs. No new permission or data collection category.

- `swift run TileCoreChecks`: **11 scenarios, 2,712 assertions passed**. Includes
  asymmetric splits, alternate orientation before collapse, automatic stack
  collapse and recovery, every stack member's minimum, no overlapping tiles,
  portrait/negative origins, oversized-window isolation, fixed-mode fallback and
  migration of old preference JSON with fitting enabled.
- Real packaged app `--integration-test`: **16 checks passed** against a child
  process only. Existing discovery/focus/lifecycle checks still pass. Changing
  test windows to minimums over half the usable screen caused an automatic single
  stack while the configured maximum stayed four. Accepted frames stayed inside
  the screen. Closing those restrictive windows and creating four small windows
  restored four distinct tiles automatically.
- `scripts/build.sh`: arm64 and x86_64 release builds passed with no warnings.
- Packaged app `--smoke-test`: settings visible, menu has 14 items, zero shortcut
  registration failures; Carbon event status 0, handler changes test capacity to 1.
- `scripts/package.sh`: version 0.2.0 universal DMG, ZIP and SHA256SUMS produced.
  Both architecture slices verified; strict app signature and extracted ZIP
  signature passed; extracted executable SHA-256 equals the source executable;
  both archive checksums passed.

Minimums are learned only from successful resize operations whose accepted
bounds exceed requested bounds. They are not exact platform-provided minimum
metadata, and may become conservative if an app's constraints change. Tidy now
clears learned minimums. Actual AX rejection beyond size constraints can still
remain; retries are bounded to nine passes per layout update. Physical multiple
monitors, older OS/Intel runtime, and a broad matrix of third-party apps remain
outside this check set. Source and behavior changes are recorded in SPEC.md.

0.2 delivery: public latest release is v0.2.0; unauthenticated GitHub release
metadata lists all three assets with SHA-256 digests matching the verified local
files. GitHub Actions independently passed layout/state tests, both architecture
builds, packaging and artifact upload for source 7b19b8a:
https://github.com/swright7001/shawn-tile/actions/runs/40250552010.
The final packaged executable also repeated all 16 real-window checks with zero
failures (isolated fixture PID 28088). Installation to ~/Applications completed;
the existing 0.1 grant must be refreshed because this build has a new ad hoc
signature. User explicitly authorized installation and the permission refresh.

### 0.2.1 — automatic spacing fallback

Live installation exposed a boundary case: one of Shawn's windows fitted with
zero spacing, but 0.2.0 classified it as too large for its padded tile area.
Reducing spacing through the native UI removed the warning. The planner now
checks oversized windows against the full usable display and, when no arrangement
fits preferred gaps, searches for the largest whole-point spacing that works
before lowering tile count. The saved preferred spacing remains unchanged.
Regression checks cover a 990-point minimum on a 1000-point display with a
preferred 20-point gap (fits using 5), a full-height minimum (fits with zero gap),
and a true minimum beyond screen height (remains an explicit float).

Final 0.2.1 checks: **12 scenarios / 2,726 assertions passed**, plus **18 real AX
checks passed** (isolated fixture PID 28763). New native checks impose full-height
window minimums, verify four distinct tiles remain possible using automatic gap
reduction, and confirm the saved gap remains 10. Both architecture release builds
passed. Packaging, architecture verification, strict source/extracted ZIP
signatures, executable identity and DMG/ZIP SHA-256 checks passed.

0.2.1 live pilot: user authorized installation and the final signature-specific
Accessibility refresh. Re-added the exact installed ~/Applications/Shawn Tile.app
through System Settings; other grants were unchanged. Restored preferred spacing
to 10 via the native UI and enabled Automatic tiling with Automatically fit
windows checked. After learning, the installed app reported **3 tiles, 2 stacked**
for five eligible windows, with **no remaining constraint/oversized warning**.
The preview showed automatically selected unequal columns while the saved layout
remained Grid, maximum tiles remained 3, and preferred spacing remained 10.
This confirms the fitting and automatic gap fallback on the user's current
single-display desktop, in addition to the isolated fixtures. The public latest
release is v0.2.1 and all uploaded asset digests match the verified local packages.

0.2.1 independent CI passed tests, universal build, packaging and artifact upload
for source 191e17d: https://github.com/swright7001/shawn-tile/actions/runs/40250983058.
Native smoke check also passed: visible settings, 14 menu items, zero shortcut
registration failures, successful Carbon test event and expected capacity change.

### Persistent local signing: installed update verified

Created one reusable Code Signing identity in the login Keychain with explicit
user approval. No private key was exported, no general trust override was added,
and no Gatekeeper or TCC database bypass was used. Local configuration contains
public identity metadata only and has mode 0600 in a mode 0700 directory.

Two copies of the 0.2.1 bundle were signed with the same certificate-pinned
designated requirement. Their Info.plist build numbers are 1 and 2, producing
different code-directory hashes. These are distinct signed bundles, not different
Swift implementations. Both strict signature verification and the shared
requirement continuity check passed. Reusing a correctly signed bundle skips
another private-key signing operation. Ad hoc continuity and an unrelated app
identifier were rejected; an unavailable explicit identity failed without an
ad hoc fallback. Shell syntax, Python compilation and diff whitespace checks passed.
The updated build script also completed both release architectures with explicit
ad hoc signing, and TileCoreChecks repeated all 12 scenarios / 2,726 assertions.

Installed build 1 at the normal ~/Applications/Shawn Tile.app path, refreshed
only Shawn Tile's Accessibility grant through System Settings with user approval,
and confirmed the native app recognized seven eligible windows. Quit it and
installed build 2 through the staged installer. No Accessibility setting was
changed after that update. The relaunched app still recognized seven windows,
accepted Automatic tiling, and settled at **3 tiles, 4 stacked** with automatic
fitting checked and preferred spacing 10. This verifies retained permission on
this Mac across the signed-bundle update.

Keychain authorization for signing is separate from Accessibility. Signing both
test bundles succeeded, but persistent Always Allow authorization was not
confirmed. Future fresh signatures may still request Keychain approval. Public
ad hoc downloads must use the local scripted installer to preserve this identity;
Finder replacement bypasses that signing step. Other Macs need their own setup.

Independent GitHub CI passed layout/state checks, universal build, packaging and
artifact upload for source 47c1f11:
https://github.com/swright7001/shawn-tile/actions/runs/40254064383.
