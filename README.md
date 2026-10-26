# Shawn Tile

A native, offline window manager for macOS. Open an app and it joins your layout. Extra windows share a tile instead of squeezing the whole desktop.

Original Swift software inspired by the public behavior of [Shoji](https://shojimac.com/). No Shoji code, assets, branding, or native binary included.

- Grid, columns, and rows, with one to four tiles per display
- Automatic fitting: adjust splits and spacing, try another arrangement, and stack when fewer tiles fit
- Per-display spacing, maximum tile count, and settings
- Overflow stacks and keyboard window switching
- Customizable shortcuts, disable individual actions, and restore defaults
- Focus and restore, float windows, swap tiles, make primary
- App exclusions, pause/resume, restore pre-tiling positions
- Native menu bar controls and settings, optional open at login
- Apple Silicon and Intel; macOS 13 Ventura or newer
- No account, telemetry, subscriptions, or application network traffic

## Install

Download the universal DMG or ZIP from [Releases](https://github.com/swright7001/shawn-tile/releases/latest). Open the DMG, drag **Shawn Tile.app** to Applications, and launch it. A personal ad hoc signed build can require **System Settings → Privacy & Security → Open Anyway**. The build is not Apple notarized.

In the app, open permission settings and enable **Shawn Tile** under **Accessibility** (Device Control & Data Access on newer macOS). Then switch on **Automatic tiling**. Each Mac needs its own permission. Use the rectangle icon in your menu bar for controls.

Full installation, update, and uninstall instructions: [docs/INSTALL.txt](docs/INSTALL.txt).

## Build and install from source

Install Apple's Command Line Tools (`xcode-select --install`) if Swift is missing. No Homebrew or third-party packages required. With this repo cloned:

```sh
swift run TileCoreChecks
./scripts/build.sh
./scripts/install.sh
```

`build.sh` produces a universal app (ad hoc signed until local signing is configured) in `dist/Shawn Tile.app`. `install.sh` copies it into `~/Applications`, preserves an existing version as a dated backup, and opens Settings. Quit the app before updating.

```sh
./scripts/package.sh
```

Packaging creates a DMG, ZIP and SHA-256 sums in `dist/`. Copy the DMG to your other Mac. To verify a download, run `shasum -a 256 -c SHA256SUMS` beside both packages. GitHub Actions also builds installable artifacts for `main`, PRs, tags and manual runs. CI artifacts are under the workflow run's Artifacts section; releases are separate.

For a host-only development build, run `./scripts/build.sh native`. Do not use its result for a universal release. To sign with an existing Developer ID instead, set `TILE_SIGN_IDENTITY`; notarization is a separate process and is not automated here. Ad hoc app updates can require re-granting Accessibility. For free local updates that retain one signer identity, follow [Local signing](docs/LOCAL-SIGNING.md). After setup, local builds and scripted installs reuse the Keychain certificate; the first switch needs one Accessibility refresh.

## Keyboard

| Keys | Action |
| --- | --- |
| Control–Option–Command + 1–4 | Set active display maximum tile count |
| Control–Option + Z | Focus / restore |
| Control–Option + F | Float / tile active window |
| Control–Option + grave | Next in stack |
| Control–Option + [ / ] | Previous / next window |
| Control–Option + arrows | Swap neighboring tiles |
| Control–Option + Return | Make primary |
| Control–Option + P | Pause / resume |

These are the defaults. Open **Settings → Keyboard** and click an action's
shortcut to change its modifiers and key, or disable it. Save applies immediately
and remembers your choice across restarts. Use Default resets that action;
Restore Defaults resets all 15 actions. Include Control or Command. Key labels
use US keyboard positions. Duplicate and unavailable combinations show an error;
a failed edit keeps the previous working bindings.

Shortcuts use registered macOS hotkeys with exclusive registration. Settings
reports conflicts. It does not monitor ordinary typed keys. Window selection
from the menu uses app names and transient IDs so titles need not be read.

## Boundaries

Pause while using Stage Manager or another tiling manager. Standard resizable windows on the active Space are eligible; sheets, dialogs, fullscreen/minimized windows, hidden apps, and exclusions are skipped. With automatic fitting on (the default), Shawn Tile learns dimensions your windows reject, adjusts split ratios and arrangements, reduces gaps only as needed, and stacks windows if fewer tiles fit. The saved tile count is a maximum. Closing restrictive windows or adding display space restores more tiles automatically. Tidy now clears learned bounds and retries. Bounds stay in memory for the current windows; a window larger than the entire usable display is centered and reported separately. Turn off Automatically fit windows for fixed layouts.

This first version does not implement dimming/privacy modes, thumbnail switchers, hover bars, mouse modifier-drag swaps, shared split resizing, cross-display directional shortcuts, or automatic updates. Moving a window to another display by dragging is detected. Display settings persist, but live stack membership is rediscovered on Space changes and restart. A display is identified by its system UUID.

The app keeps local preferences in `com.shawnwright.ShawnTile` (display layouts, exclusions, shortcut bindings, enabled/onboarding flags). Window geometry/references are kept in memory for restoration; window titles, documents, and screenshots are not read or saved. A 1.5-second reconciliation fallback complements Accessibility and workspace events.

## REA project records

- [PROJECT.md](PROJECT.md): project brief and provenance
- [SPEC.md](SPEC.md): behavior and acceptance
- [docs/RESEARCH.md](docs/RESEARCH.md): evidence IDs and observed/claimed boundaries
- [VERIFICATION.md](VERIFICATION.md): checks actually executed and remaining gaps

Original code, scripts, and geometric icon: MIT, © 2026 Shawn Wright. Apple frameworks are system dependencies. Independent of and unaffiliated with Shoji and the REA engine.
