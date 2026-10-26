# Shawn Tile behavior specification: 0.4.1

Personal and shareable macOS 13+ menu bar window manager, implemented in Swift using public AppKit and Accessibility APIs. Initial state is paused; the user enables automatic tiling after granting Accessibility. No license check, screenshots, key logging, or saved titles. The optional updater contacts this project’s GitHub releases.

## Layout and automatic fitting

- Settings and the menu show each connected display. Auto, Grid, Columns, or Rows, maximum 1–4 tiles, 0–32 point preferred gaps, and Automatically fit windows persist per display UUID.
- Automatic fitting defaults on, including when loading preferences created by 0.1. The tile count is a ceiling. It does not shrink the user's saved preference when only fewer tiles currently fit.
- Try the preferred arrangement with equal shares. When an app accepts a larger dimension than requested, remember that dimension as a minimum for that window and adjust split ratios to satisfy all members of each stack. Do not infer minimums from a failed AX write or from an arbitrary starting window size.
- Grid, Columns and Rows preserve the selected shape on landscape and portrait displays. Only Auto tries other arrangements before lowering tile count; its initial preference is Grid on landscape and Rows on portrait. Existing explicit layout preferences migrate unchanged. New installations default to Auto.
- Before reducing a four-tile Grid, try reordering complete stacks across the non-primary slots. Keep the primary at slot zero, preserve existing order when it fits, and keep each stack intact. Clear learned bounds when settings change so a prior arrangement does not permanently constrain the new one.
- If no arrangement fits at the preferred spacing, reduce gaps to the largest whole-point value that fits, down to zero, before lowering tile count. Classify oversized windows against the entire usable display, not a padded box. Keep the preferred spacing saved so it returns when room permits.
- If fewer tiles fit, merge excess windows into stacks; all stack members share a frame that meets their combined minimum requirements. A larger display, closing restrictive windows, or newly opened smaller windows can promote stacks back into separate tiles without changing the saved maximum.
- Wait 350 ms after applying frames to measure app acceptance. Retry only when a minimum increases, with at most nine passes per layout change. Keep discovery and retry state on the main thread. Ignore intermediate sizing changes while fitting, and discard stale checks when focus/layout changes invalidate them.
- Recheck when a managed window's accepted size changes after settling. Tidy now clears session minimums and retries, allowing app constraints that have become smaller to be rediscovered. Minimums are window-specific, in memory only, and removed when windows leave the managed set.
- If a learned minimum exceeds the entire usable display, leave that window at its accepted size, centered, and report that it is too large. It does not force every other window to float. No layout can satisfy an app's minimum larger than its screen.
- Automatically fit windows can be turned off for exact fixed layouts. Grid order is clockwise from the primary at top-left. Floating/manual exclusions retain their existing meaning.

## Existing interactions

- Only visible, resizable standard windows on the active macOS Space are managed. Skip dialogs, sheets, panels, minimized/fullscreen windows, hidden applications, our windows, and excluded bundle IDs.
- Preserve discovered order and tile membership where possible. A new window fills a free tile, otherwise shares the focused tile. Focus changes alone do not reorder tiles.
- Reconcile on app/window lifecycle, workspace/display changes and settled size changes; a 1.5-second fallback handles missing AX notifications. Do not apply while the mouse is down, paused, or permission is missing.
- After our own geometry writes, defer window rediscovery for 600 ms so AX
  bounds and CG visibility metadata can settle. During that interval, new
  commands still arrange the known window set immediately. This preserves IDs
  and Focus across rapid capacity changes and restores; discovery resumes after
  movement settles.
- Focus expands the active managed window; toggling back restores saved geometry. Closing that window, pausing, excluding or floating clears Focus safely. Directional swapping uses actual fitted frames, including unequal splits and alternate arrangements.
- Control–Option–Command + 1–4 sets the maximum on the active display. Control–Option + Z toggles Focus; F floats; grave cycles stack; brackets cycle windows; arrows swap neighboring tiles; Return makes primary; P pauses. Registration failures appear in Settings.
- Keyboard settings lists all 15 actions separately. Edit a binding by choosing
  Control, Option, Shift, Command and a supported key, or disable it. Include
  Control or Command. Key labels describe US keyboard positions. Save applies
  immediately and persists locally; Cancel changes nothing. Per-action Use
  Default and Restore Defaults are available.
- A Screen Sharing preset applies Control-Shift-Command with each action's
  default key, including P for pause. It is optional, validated like other edits,
  persists locally, and can be customized or reset to the original defaults.
- Reject duplicate enabled combinations before changing registrations. Register
  exclusively so another owner's shortcut cannot silently suppress delivery.
  If a new binding is unavailable, restore the previous registrations and leave
  saved preferences unchanged. Existing unavailable shortcuts can be fixed one
  at a time. Show any registration or rollback errors. Disabled actions release
  their combination and ignore stale Carbon events. No event tap, Input
  Monitoring, or ordinary keystroke recording is added.
- Install and register discrete Carbon hotkey events at the toolbox dispatcher
  target so their delivery is independent of application menu event handling.
- Settings offers per-app exclusions, restoration of positions from before enabling, and launch at login. Quitting restores Focus only; ordinary tiled positions remain.

## Packaging and acceptance

Universal arm64 + x86_64 app, ZIP, SHA-256 and DMG; install to ~/Applications without sudo. Include build/install scripts and CI. Personal ad hoc signing is not Apple notarization; each Mac grants its own Accessibility permission. Replacing a build can invalidate its prior grant; document recovery rather than bypassing macOS checks.

Acceptance: pure planner tests verify bounds, non-overlap, minimums for every stack member, asymmetric splits, alternate layouts, automatic collapse/recovery, oversized-window isolation and preference migration. Real AX fixture tests impose window minimum sizes, verify automatic stacking without changing capacity, and reopen small replacements to verify automatic expansion. Native startup and both architectures must still build and run covered checks. Record actual coverage in VERIFICATION.md.

## Limits

No private Space identifiers, Stage Manager coordination, dragged split resizing, modifier-drag swaps, hover controls, thumbnails, or dimming/privacy overlays. Space membership uses public on-screen window metadata. Display settings persist; live stacks and minimums are rediscovered after restart/Space changes. Learned bounds may require Tidy now if an existing app lowers its minimum without producing a size-change event. Unsupported or slow AX clients can still reject operations; retries remain bounded.

## Persistent local update identity

Optional free local signing reuses a user-created code-signing certificate from
the login Keychain. Require both `com.shawnwright.ShawnTile` and the exact leaf
certificate fingerprint in the signed designated requirement. No identifier-only
requirement, hash-only build pin, general root trust override, or TCC modification.
Local metadata contains only the public fingerprint; key material stays in
Keychain. Once configured, builds and scripted installs must reuse that identity
and fail if it is unavailable. Stage and sign updates before moving the installed
app. One initial permission refresh is required when migrating from ad hoc; verify
retention across two distinct signed bundles before claiming the issue is fixed.
Public CI stays ad hoc unless an identity is explicitly provided.


## In-app updates

- Default-on daily checks use the public GitHub latest stable release API for
  swright7001/shawn-tile. General offers an opt-out and Check for Updates;
  the menu has a manual check. Offline automatic failures stay quiet. Cache
  release metadata and the last successful check locally. No account or token.
- A newer stable semantic version with an uploaded universal ZIP and SHA-256
  digest produces an in-app banner, feature summary, full notes and Update &
  Restart. Never download/install automatically. Notes render as inert text.
- Re-fetch the canonical metadata before installation and require it to match
  the reviewed release. Require HTTPS, pinned GitHub repository URLs, bounded
  redirect hosts, response sizes, archive checksum, ZIP directory safety,
  expected app identifier/version, supported macOS minimum and strict signature.
- Reject traversal, symlink/special-file entries, encryption, split/ZIP64
  archives and oversized extraction. No external package/runtime is required.
- Prepare on the destination volume before quitting. Reuse the configured
  local certificate with an explicit leaf-pinned requirement; signing errors
  fail without fallback. Public ad hoc copies can update without local setup,
  with a visible note that macOS may require Accessibility again. A certificate
  installation without its configuration is not silently replaced with ad hoc.
- A detached unprivileged helper waits for exit, verifies again, retains a backup,
  replaces the app and reopens it. Recover the original path on replacement
  failure. Reject read-only/translocated installs and unwritable destinations
  before quit. Never change TCC, Gatekeeper, certificate trust or quarantine.
- Cancel stops downloads/preparation, including a running signing process. On
  successful restart, show the completed version and features. Preferences and
  signing configuration remain outside the replaced bundle.
