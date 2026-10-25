# Shawn Tile behavior specification

Personal macOS 13+ menu bar window manager, implemented in Swift using public AppKit and Accessibility APIs. Initial state is paused; the user enables automatic tiling after granting Accessibility. No remote service, license check, screenshots, key logging, or saved titles.

## Required interactions

- Settings and the menu show each connected display. Grid, Columns, or Rows, capacity 1–4, and 0–32 point gaps persist per display UUID.
- Grid: one fills; two split vertically; three put the first on the left and two on the right; four use clockwise order from top left. Portrait displays use rows.
- Only visible, resizable standard windows on the active macOS Space are managed. Skip dialogs, sheets, panels, minimized/fullscreen windows, hidden applications, our windows, and excluded bundle IDs.
- Preserve discovered order. A new window fills a free tile, otherwise shares the focused tile; all members get identical bounds. Closing/minimizing/hiding removes a member and compacts empty tiles. Increasing capacity promotes overflow into empty tiles. Focus changes alone never reorder tiles.
- Reconcile on app/window lifecycle, workspace and display changes; a low frequency fallback handles applications with missing Accessibility notifications. Do not apply while the mouse is down, paused, or permission is missing.
- Focus expands a selected managed window within its display; toggling back restores saved geometry. Closing that window clears Focus. Pausing, excluding, or floating clears Focus safely.
- Control–Option–Command + 1–4 sets active display capacity. Control–Option + Z toggles Focus; F floats; grave cycles stack; brackets cycle windows; arrows swap with the nearest occupied tile; Return makes primary; P pauses. Failures to register a shortcut appear in Settings.
- Settings offers per-app exclusions, restore positions from before enabling, and launch at login. Before quitting, restore Focus only; ordinary tiled positions remain.
- A resizable window that rejects target bounds is left at its accepted geometry; show an aggregate warning. No endless retry. Do not claim learned minimum-size layout negotiation.

## Packaging and acceptance

Build an ad hoc signed universal app (arm64 + x86_64), ZIP, SHA-256, and DMG; install to ~/Applications without sudo. Include local build/install scripts and CI. No notarization claim. A Mac may require Open Anyway. Each Mac grants its own Accessibility permission.

Tests must cover geometry across negative display origins/portrait, no overlap, stack overflow/removal/promotion, coordinate conversion, and deterministic swapping. Build both architectures and exercise actual app startup, settings, and permission behavior. Actual cross-app manipulation needs the app's Accessibility grant; document any blocked acceptance checks.

## Deliberate first-version limits

No private Space identifiers, Stage Manager coordination, dragged split resizing, modifier-drag swaps, hover controls, window thumbnails, dimming/privacy overlays, or automatic update service. Space membership is derived from the current on-screen window list; disconnected/Space-switched windows are rediscovered. Display settings persist, live stack assignments do not survive restart/Space switches. Settings have no dependencies beyond Apple frameworks.
