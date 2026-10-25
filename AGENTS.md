# Shawn Tile

Follow PROJECT.md, SPEC.md and docs/RESEARCH.md. Keep behavior specifications and actual checks current in VERIFICATION.md. Do not add proprietary reference code/assets or raw website captures.

Native Swift app, no dependencies beyond Apple frameworks. `swift run TileCoreChecks` runs checks without requiring full Xcode/XCTest. `scripts/build.sh` builds both architectures, packages the app and signs ad hoc. `scripts/package.sh` creates distributable archives. Initial automatic tiling stays off until the user enables it.

Preserve the public Accessibility API boundary and metadata-only filtering; do not add private APIs, screenshot/keyboard recording, or network calls without a task requiring them. Never weaken OS permission or Gatekeeper controls.
