# Shawn Tile behavior specification — 0.2

Personal and shareable macOS 13+ menu bar window manager, implemented in Swift using public AppKit and Accessibility APIs. Initial state is paused; the user enables automatic tiling after granting Accessibility. No remote service, license check, screenshots, key logging, or saved titles.

## Layout and automatic fitting

- Settings and the menu show each connected display. Preferred Grid, Columns, or Rows, maximum 1–4 tiles, 0–32 point gaps, and Automatically fit windows persist per display UUID.
- Automatic fitting defaults on, including when loading preferences created by 0.1. The tile count is a ceiling. It does not shrink the user's saved preference when only fewer tiles currently fit.
- Try the preferred arrangement with equal shares. When an app accepts a larger dimension than requested, remember that dimension as a minimum for that window and adjust split ratios to satisfy all members of each stack. Do not infer minimums from a failed AX write or from an arbitrary starting window size.
- Try alternate grid/column/row arrangements at the same count before lowering the effective number of tiles. Prefer portrait rows, but allow another arrangement when it fits more windows.
- If fewer tiles fit, merge excess windows into stacks; all stack members share a frame that meets their combined minimum requirements. A larger display, closing restrictive windows, or newly opened smaller windows can promote stacks back into separate tiles without changing the saved maximum.
- Wait 350 ms after applying frames to measure app acceptance. Retry only when a minimum increases, with at most nine passes per layout change. Keep discovery and retry state on the main thread. Ignore intermediate sizing changes while fitting, and discard stale checks when focus/layout changes invalidate them.
- Recheck when a managed window's accepted size changes after settling. Tidy now clears session minimums and retries, allowing app constraints that have become smaller to be rediscovered. Minimums are window-specific, in memory only, and removed when windows leave the managed set.
- If a learned minimum exceeds the entire usable display, leave that window at its accepted size, centered, and report that it is too large. It does not force every other window to float. No layout can satisfy an app's minimum larger than its screen.
- Automatically fit windows can be turned off for exact fixed layouts. Grid order is clockwise from the primary at top-left. Floating/manual exclusions retain their existing meaning.

## Existing interactions

- Only visible, resizable standard windows on the active macOS Space are managed. Skip dialogs, sheets, panels, minimized/fullscreen windows, hidden applications, our windows, and excluded bundle IDs.
- Preserve discovered order and tile membership where possible. A new window fills a free tile, otherwise shares the focused tile. Focus changes alone do not reorder tiles.
- Reconcile on app/window lifecycle, workspace/display changes and settled size changes; a 1.5-second fallback handles missing AX notifications. Do not apply while the mouse is down, paused, or permission is missing.
- Focus expands the active managed window; toggling back restores saved geometry. Closing that window, pausing, excluding or floating clears Focus safely. Directional swapping uses actual fitted frames, including unequal splits and alternate arrangements.
- Control–Option–Command + 1–4 sets the maximum on the active display. Control–Option + Z toggles Focus; F floats; grave cycles stack; brackets cycle windows; arrows swap neighboring tiles; Return makes primary; P pauses. Registration failures appear in Settings.
- Settings offers per-app exclusions, restoration of positions from before enabling, and launch at login. Quitting restores Focus only; ordinary tiled positions remain.

## Packaging and acceptance

Universal arm64 + x86_64 app, ZIP, SHA-256 and DMG; install to ~/Applications without sudo. Include build/install scripts and CI. Personal ad hoc signing is not Apple notarization; each Mac grants its own Accessibility permission. Replacing a build can invalidate its prior grant; document recovery rather than bypassing macOS checks.

Acceptance: pure planner tests verify bounds, non-overlap, minimums for every stack member, asymmetric splits, alternate layouts, automatic collapse/recovery, oversized-window isolation and preference migration. Real AX fixture tests impose window minimum sizes, verify automatic stacking without changing capacity, and reopen small replacements to verify automatic expansion. Native startup and both architectures must still build and run covered checks. Record actual coverage in VERIFICATION.md.

## Limits

No private Space identifiers, Stage Manager coordination, dragged split resizing, modifier-drag swaps, hover controls, thumbnails, dimming/privacy overlays or update service. Space membership uses public on-screen window metadata. Display settings persist; live stacks and minimums are rediscovered after restart/Space changes. Learned bounds may require Tidy now if an existing app lowers its minimum without producing a size-change event. Unsupported or slow AX clients can still reject operations; retries remain bounded.
