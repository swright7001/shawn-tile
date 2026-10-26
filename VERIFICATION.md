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

### 0.3: editable shortcuts

Pure checks passed **15 scenarios / 2,773 assertions**, including unique action
IDs and default combinations, unsupported keys/modifiers, duplicate conflicts,
disabled actions and saved preference round trips. The native editor was
exercised in an isolated preference domain: custom Shift modifier saved and
displayed, disabling displayed Disabled, duplicate Focus/Pause keys were rejected
in the sheet, and per-action/global defaults restored the original binding.

The keyboard fixture suite passed **83 checks, zero failures** against five
disposable child-process windows (PID 35014). All 15 exclusive registrations
succeeded. Discrete Carbon hotkey events exercised each handler and verified
capacity, Focus bounds/restoration, float preservation/re-tiling, stack cycling,
previous/next activation, primary placement, all four directional swaps, and
pause/resume. Additional checks verified custom registration, release of the old
combination, rejection and rollback of a deliberately reserved shortcut,
unchanged preferences on duplicate rejection, disabling/stale-event rejection,
reloading saved custom bindings and defaults, and resolving two startup conflicts
one at a time. These are handler/real-window checks, not physical keyboard input.

Initial fixture failures exposed transient AX/CG geometry disagreement during
our own resizing. Discovery could drop IDs and undo Focus before metadata
settled. A bounded 600 ms discovery grace period now preserves the known set
while commands still apply immediately. The full keyboard fixture suite above
passed after that correction.

The existing real-window layout regression suite also passed **18 checks, zero
failures** after the discovery correction (fixture PID 35042). This covered
closing, minimizing/restoring, constrained window sizes, adaptive stacking,
spacing reduction and re-expansion. The command-line test process had existing
Accessibility authorization; no new grant was requested for these fixture runs.

Targeted native UI automation did not trigger global shortcuts in either the
old app or the isolated preview. These attempts do not establish physical-key
delivery. The Carbon handler checks above must not be described as physical
keypress tests. The user subsequently reported no visible change from physical
Control-Option-P with the application event target, and again after an installed
candidate used the Carbon dispatcher target. The user then clarified that input
arrived through Screen Sharing from another Mac. Changing Pause to
Control-Shift-Command-P in the native editor produced a successful physical-key
test: the user confirmed it paused, and the app's native state showed Automatic
tiling off plus Last shortcut: Pause / resume. The changed binding was also read
back from the saved app preferences. The precise interception of the original
combination was not established; the target change alone did not resolve it.

Both release architectures built successfully for 0.3.0. Signing the final
bundle reused the configured identity without another prompt. The strict
certificate-pinned continuity check passed against the installed 0.2.1 bundle.
Installed 0.3.0 through the staged installer and confirmed the launched native
app retained Accessibility and resumed adaptive tiling. No permission entry was
changed. The installed Keyboard tab lists all 15 editable default bindings and
reports successful registration. A physical Control-Option-P check was requested
separately from the targeted automation attempts, with the successful remote
session result above. The final version offers the tested modifier combination
as an optional Screen Sharing preset for all 15 actions.

Final preset/dispatcher checks passed **16 scenarios / 2,805 assertions** and
**89 keyboard fixture checks, zero failures** (fixture PID 36635 only). This
repeated every action and rollback scenario at the dispatcher target, registered
all Screen Sharing combinations and exercised pause/resume under the preset.
Both release architectures built again; final local signing reused the same
identity without a prompt and the staged update installed successfully.
The native relaunched app preserved the saved custom Pause binding and its
Accessibility grant. Applied Screen Sharing preset in Keyboard settings: all
15 rows changed to Control-Shift-Command, registration remained successful,
and Automatic tiling was enabled again.

Delivery: independent CI passed tests, universal build, packaging and artifact
upload for source 72e4273:
https://github.com/swright7001/shawn-tile/actions/runs/40256461800.
The local extracted public ZIP passed strict signature, version 0.3.0, ad hoc
signing and both-architecture checks. DMG/ZIP SHA-256 checks passed. Published
v0.3.0 with the DMG, ZIP and SHA256SUMS; unauthenticated GitHub release metadata
confirmed all three assets and SHA-256 digests matching the local packages:
https://github.com/swright7001/shawn-tile/releases/tag/v0.3.0.

### 0.4.1: explicit layout selection and in-app updates

The screenshot report was reproduced by source inspection: fitting could change
an explicit Grid/Rows selection to another arrangement, and portrait fixed
geometry also ignored explicit choices. Grid, Rows and Columns now retain their
shape. Auto is the explicit mode for alternate arrangements and is the default
for new settings. Existing stored layout choices migrate unchanged. Four-tile
Grid tries complete-stack slot permutations with the primary fixed before
lowering count. Layout changes re-measure window constraints.

Pure layout/shortcut/update/archive checks passed **3,691 assertions**. Added
coverage includes explicit shapes on both orientations, constrained stack count,
mixed Grid minimums, stable preference migration, semantic version ordering,
stable-release filtering, canonical repository asset URLs, missing/wrong digests,
oversized metadata/assets, unsafe redirects, checksum/size failures, ZIP traversal,
symlinks, unsupported entries and truncation.

Real disposable-window checks passed **15 layout-mode checks** (PID 46022),
including repeated Grid/Rows/Columns changes, constrained Grid/Rows stacking,
Auto fallback, mixed-size Grid rebalancing and recovery. The existing **18 AX
regression checks passed** (PID 46113). The **89 keyboard fixture checks passed**
(PID 43153) after the layout-mode change. These fixtures only managed their
child process, not the ordinary desktop. Physical portrait/multi-display tests
remain a gap; those orientations are covered by pure checks.

Disposable updater checks passed **23 checks**. Real packaged ZIP extraction and
strict verification succeeded. Both configured local-certificate and public ad
hoc copies installed through the helper. The previous bundle was retained on
success. Injected replacement failure restored the exact prior app directory and
original path. Wrong checksum/size, wrong app version and a mismatched configured
identity were rejected with the installed copy intact. Cancellation prevented
preparation and terminated a running preparation child process promptly.

Installed a locally signed 0.4.0 pilot without changing Accessibility. Its native
UI showed a real four-tile Grid, changed to two horizontal Rows with the same
current apps, and changed back to Grid. Fitting remains subject to app minimums.
The banner and full release notes were visually checked in an isolated synthetic
preview; installation was disabled there. Normal mode's real GitHub check
returned "You're up to date (0.4.0)" against the then-current 0.3.0 public release.
The final public 0.4.1 update and in-app restart are recorded below when executed.

### 0.4.2: update restart handoff

The first real 0.4.0-to-0.4.1 attempt downloaded the public archive, verified it,
and preserved the local signer, but the running app did not exit while its
SwiftUI notes sheet was active. The helper timed out after 30 seconds and left
the installed 0.4.0 bundle intact. The install log confirmed that safe refusal.
0.4.1 was marked prerelease and removed as latest before further distribution.

The handoff now leaves the SwiftUI action, closes the app's own sheet, flushes
preferences, restores Focus, unregisters app resources, and ends its own process
after the user has chosen Update & Restart. The native smoke check deliberately
holds the notes sheet active: it passed menu/hotkey checks and exited normally in
3.9 seconds. Final 0.4.2 packages built for both architectures and repeated all
23 installer checks successfully. Real public-release retry is recorded below.

Final source `89ed389929c725755ec089805ff7a50eb40a0c2e` passed independent
CI, including tests, universal build, packaging and the installer fixture:
https://github.com/swright7001/shawn-tile/actions/runs/40261724686.
Published stable v0.4.2 with universal DMG, ZIP and SHA256SUMS. Unauthenticated
GitHub latest-release metadata confirmed v0.4.2, three assets, and all three
SHA-256 digests matching the local files:
https://github.com/swright7001/shawn-tile/releases/tag/v0.4.2.

Executed the real in-app update from the patched, locally signed 0.4.0 pilot.
Check for Updates offered the public 0.4.2 release and its actual feature notes.
Update & Restart downloaded the public ZIP, verified and locally signed it,
exited the running app, replaced it and reopened settings. The installer log
reported success and retention of the previous version as a backup. The installed
Info.plist is version 0.4.2, build 5. Strict signing-continuity checks passed
against the pre-update snapshot with the same certificate-pinned requirement.

The restarted native UI showed the successful-update banner, Automatic tiling
enabled and no Accessibility warning. Saved Grid, maximum four tiles, 10-point
spacing and automatic fitting survived. The Keyboard tab retained all saved
bindings, including Control-Shift-Command-P and the custom Command-arrow swaps,
and reported successful macOS registration. Rows visibly used two horizontal
tiles with the current apps' size constraints. Grid was restored after this
check. No permission reset or signing approval was needed during the real update.
Physical remote keystrokes were not repeated in this release check; prior user
confirmation and the keyboard fixture results remain the delivery evidence.


### 0.4.3: recovering compatible stacks after Rows

The final 0.4.2 desktop check exposed a remaining case: after Rows collapsed six
windows into two stacks, Grid could stay at two tiles even though four had fit
before. Retrying measurements did not restore the count. Whole-stack permutations
cannot separate incompatible members created by collapse.

The planner now retains existing stacks first, then tries bounded regrouping
before lowering count. The primary window stays in slot zero. Added a six-window
minimum-size regression covering Grid, Rows and repeated recovery, bounds,
complete membership and minimum sizes. Pure checks passed **3,966 assertions**.
The expanded native suite passed **21 layout-mode checks, zero failures** against
fixture PID 50830, including repeated six-window Grid/Rows transitions. Ordinary
desktop tiling was paused during the fixture run. Both architectures built and
the candidate retained the configured local signing requirement.

The existing real-window regression suite also passed **18 checks, zero failures**
against fixture PID 50879 after regrouping was added.

The packaged public 0.4.3 ZIP passed **23 installer checks**, strict signature,
universal architecture, Info.plist version/build (0.4.3/6), exact helper-resource
and package checksum checks. An initial keyboard rerun encountered two expected
Screen Sharing registration conflicts because the paused installed app still
owned those combinations. Closed that copy and reran in isolation: **89 checks,
zero failures**, fixture PID 51354. No shortcut code change was required.

Source `d39596ece61ae260e3ae620b84e26b371803bcc6` passed independent CI:
https://github.com/swright7001/shawn-tile/actions/runs/40263083632.
Published stable v0.4.3, then verified unauthenticated latest-release metadata
and matching SHA-256 digests for all three public assets:
https://github.com/swright7001/shawn-tile/releases/tag/v0.4.3.

Executed a second real public update, 0.4.2 to 0.4.3, through Check for Updates,
release notes, and Update & Restart. The installed app is 0.4.3/build 6; the
installer log reports successful replacement and backup retention. Strict
certificate-pinned continuity passed against the pre-update 0.4.2 snapshot.
No Accessibility reset or Keychain approval was needed.

On the actual six-window desktop, the restarted app showed four Grid tiles.
Changed to Rows, which used two horizontal tiles for these apps' minimum sizes,
then back to Grid: **four tiles recovered**, without Tidy or another restart.
The saved maximum remained four and preferred spacing ten. The successful-update
banner remained visible, Automatic tiling was on, and the Keyboard tab retained
all saved bindings and reported successful macOS registration. Left the app on
Grid with automatic fitting enabled. Physical portrait/multi-display hardware and
new physical remote keystrokes remain the previously documented verification
gaps; no claim is made that bounded regrouping finds every possible partition.

## Stack-collapse repair candidate — 2026-10-26 (issue #2)

Environment: MacBook, macOS 27.0.1 (26A434), one 1440×870-point usable display.
Built using the installed Command Line Tools with
`DEVELOPER_DIR=/Library/Developer/CommandLineTools`; full Xcode's pending license
was not accepted or changed.

- Baseline pure suite: 3,966 assertions passed.
- New delayed-feedback regression with the extracted original learning rule:
  failed, learning 900×600 from a still-changing response instead of no bound.
- `swift run TileCoreChecks` after the fix: 3,979 assertions passed, including
  delayed responses, stable constraints, lowered bounds, missing/failed samples,
  position/smaller-size mismatch reporting and planner integration.
- Native `--resize-feedback-test`: five disposable windows animate through
  intermediate sizes; original WindowManager failed (exit 1), fixed manager
  passed (exit 0), preserving four Grid tiles and matching actual frames.
- Native `--layout-mode-test`: 21 checks passed. Its fixed 2.1-second waits were
  insufficient for the now-confirmed multi-pass learner; checks poll actual
  outcomes up to seven seconds, covering the nine-pass/6.3-second limit.
- Native `--integration-test`: 18 checks passed, including automatic collapse,
  recovery, focus/restore, exclusions, gap reduction and actual frame geometry.
- `swift build` and `git diff --check` passed.

Native fixtures manage only their child PID. The installed app was paused while
running them. A passing fixture establishes the delayed-response defect and fix;
it does not prove ChatGPT's real minimum dimensions or solve every laptop layout.
Live pilot and distribution status are recorded below when completed.
- Native `--keyboard-test`: 89 checks passed after quitting the installed copy.
  An initial run with that copy merely paused failed registration because its
  global hotkeys were still registered; the conflicting copy was quit and the
  isolated suite rerun successfully.
- Release compilation succeeded. Signing the bundle inside the File Provider
  workspace initially failed on `com.apple.FinderInfo`; copied the generated
  bundle without extended attributes to a temporary staging directory and ran
  the existing signing script. Ad-hoc signing and strict verification passed.
  No local signing identity was configured or substituted.

### Real desktop pilot

Ran the signed release candidate with the installed copy quit, using Auto,
maximum 3 tiles and 4-point spacing. The candidate still settled to one tile,
three sharing windows and two frame mismatches. Its new explanation reported:
Arc 717×386, ChatGPT 1432×630, Tailscale 890×566 and Telegram 380×584 points
(learned accepted dimensions, not independently verified hard minimums).
Thus the confirmed delayed-feedback fix is **not sufficient to claim the user's
ChatGPT case resolved**. Direct computer-use access to ChatGPT was denied by the
host; no alternate UI automation was used to bypass that denial. Manual resizing
is requested to distinguish an actual app minimum from ignored AX resize writes.
The public issue stays open pending that compatibility investigation.

## Follow-up after manual narrow-window confirmation — 2026-10-26

Shawn confirmed that ChatGPT can be made narrower than half the display by hand.
The earlier full-width accepted frame is not a verified width minimum.

Added pre-request axis comparisons and a bounded size-only responsiveness probe
(up to 32 points, within display dimensions), followed by one size-only retry.
An unchanged/unresponsive axis cannot become a new inferred minimum. A responding
probe permits learning genuine limits even when the window starts at its minimum.
Pending probes/retries stop on pause, Focus, generation changes and mouse drags.

- Pure checks: 3,983 assertions passed, including ignored width with accepted
  height, correcting stale bounds, responsive genuine minima and planner shape.
- Expanded native resize regression: delayed clients retain four tiles; clients
  ignoring the first width write recover through retry; clients ignoring every
  width write keep four planned tiles and report unmatched frames. All passed
  in debug and final release builds.
- Native layout modes: 21 checks passed.
- Native integration: 18 checks passed. The initial unchanged-axis-only approach
  failed two genuine-minimum checks and was corrected with responsiveness probes.
  One subsequent run failed initial fixture discovery; a standalone rerun passed
  all 18 checks without weakening assertions or changing its timeouts.
- Final release build and staged ad-hoc signature verification passed.

### Updated real desktop pilot

The release candidate now reports three planned tiles (one shared), rather than
one tile with three sharing windows. One window still fails frame verification;
new per-app mismatch reporting identifies **ChatGPT**. This is partial progress,
not proof of a working ChatGPT tile. Tiling was paused again. The user confirmed
manual width reduction; manual height reduction is now being checked separately.
The public issue and PR remain open/draft; the installed release is unchanged.

### Cold-start and ambiguous-height follow-up

A fresh installed launch exposed a remaining real mismatch: ChatGPT requested
890×274 at (546,34), observed 890×600 at the same origin. The user confirmed that
manual width reduction works but manual half-height reduction does not.

Responsiveness probes now wait 350 ms before reading their result and another
350 ms after restoring the requested size. Stable unresolved overflow can try a
compatible Auto orientation, zero spacing for full-display constraints, and fewer
tiles down to two, without saving ambiguous dimensions as minimums or changing
preferences. Explicit layouts keep their shape. An alternate orientation cannot
force one tile if the preferred plan still has multiple tiles. Animated responses
cannot trigger this fallback. Pending explanations clear during a new fitting
cycle, and remaining mismatches include requested/observed geometry.

New fixture coverage includes an app already at its true minimum that ignores
small height-growth probes, permanently ignored width writes, and Auto recovery
to full-width rows. The initial count-fallback prototype interrupted animations;
the existing delayed fixture caught it, and stable-sample gating corrected it.
The full-height integration case required orientation/spacing trials rather than
inventing a minimum from an unresponsive full-display-sized probe.

Tests allow bounded asynchronous convergence: nine probe-bearing passes can take
9.45 seconds, so the layout/Auto fallback assertions allow 10.5 seconds while
checking actual outcomes. The close-window integration check waits two seconds
instead of 0.8 because discovery may be deferred through a 1.05-second probe.
Initial fixture-discovery and intermediate timing failures are not counted as
passes. Native suites must run with the installed copy quit (not merely paused);
isolated final results are recorded below.

Final isolated run: 3,983 pure assertions, 18 integration checks, 21 layout-mode
checks and all expanded delayed/retried/ambiguous/ignored-write native checks
passed. Final optimized release compilation and staged signature verification
passed. Local candidate version is 0.4.3, build 10 (not a public release).

### Retaining a verified arrangement

The installed pilot subsequently oscillated between attempted layouts. A verified
fallback is now retained across size-only updates, cleared by Tidy/settings or
window/display membership changes. The discovery deadline advances after the
last probe/retry write so CG visibility metadata can catch up with AX geometry.
A new fixture subscribes to effective tile counts and asserts that late resizing
does not restart the rejected four-tile layout after two tiles were verified.

The expanded resize fixture passed, including that non-oscillation assertion.
The 18 integration and 21 layout checks passed on the same implementation; pure
checks remain 3,983. Fixture startup now waits for five discoverable child windows
within a bounded eight-second readiness period rather than assuming startup
finishes in two seconds. Geometry assertions are unchanged. A transient mid-run
zero-window result was also observed; the expanded fixture passed on standalone
rerun, and failure diagnostics now record only that fixture PID's AX/CG geometry
and hidden state. Do not describe this as comprehensive long-run validation.
