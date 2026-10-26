# Shawn Tile

Follow PROJECT.md, SPEC.md and docs/RESEARCH.md. Keep behavior specifications and actual checks current in VERIFICATION.md. Do not add proprietary reference code/assets or raw website captures.

Native Swift app, no dependencies beyond Apple frameworks. `swift run TileCoreChecks` runs checks without requiring full Xcode/XCTest. `scripts/build.sh` builds both architectures, packages the app and uses the configured local Keychain identity, or signs ad hoc when none is configured. `scripts/package.sh` creates distributable archives. Initial automatic tiling stays off until the user enables it.

Preserve the public Accessibility API boundary and metadata-only filtering; do not add private APIs, screenshot/keyboard recording, or network calls without a task requiring them. Never weaken OS permission or Gatekeeper controls.

Preserve the persistent local signing identity across updates. Never regenerate the key silently or replace a configured identity with ad hoc signing on failure. Local certificates and private keys stay outside this repository. See docs/LOCAL-SIGNING.md.
