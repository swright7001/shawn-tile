# Free local signing for repeatable updates

Ad hoc signatures identify a particular build. A reusable signing certificate
lets macOS identify Shawn Tile by its bundle identifier and signing key instead.
This is a local development setup, not Apple Developer ID or notarization.

## One-time setup

1. In Keychain Access, choose Certificate Assistant, then Create a Certificate.
2. Name it `Shawn Tile Local Development`, choose Self Signed Root and Code
   Signing, and override defaults if you want a longer validity period.
3. Keep Key Usage restricted to Digital Signature and Extended Key Usage to Code
   Signing. Save to the login keychain. No general certificate trust override,
   new system root, TLS trust, or Gatekeeper change is required by this workflow.
4. In the repository, run:

   ```sh
   ./scripts/configure-local-signing.py
   ```

5. When codesign asks to use this specific signing key, approve it in macOS.
   Choose Always Allow if you want future local builds to sign without another
   signing-key prompt. Never paste your Keychain password into a chat or script.
6. Quit Shawn Tile and install through `scripts/install.sh`. Switching from the
   old ad hoc signature to this certificate requires one Accessibility refresh:
   remove the old app entry and re-add the exact installed app in System Settings.

The configuration stores only the public certificate fingerprint and app bundle
identifier under `~/Library/Application Support/Shawn Tile/Signing/identity.json`.
The private key remains in Keychain. Do not delete or recreate it between updates.
Keep a normal encrypted Mac/Keychain backup. A new certificate or a different
bundle identifier is a new app identity and can require a new permission grant.

## Future local updates

```sh
./scripts/build.sh
# Quit the running app, then:
./scripts/install.sh
```

Once configured, build and install automatically reuse the same identity. The
installer verifies the incoming app, copies it into a temporary staging folder,
locally signs and verifies it, and only then backs up and replaces the installed
copy. A missing or unusable configured key causes signing to fail; it does not
silently fall back to an ad hoc identity.

For a downloaded update from this project's releases, extract the app and use:

```sh
./scripts/install.sh '/path/to/Shawn Tile.app'
```

Use updates you trust from the project's release workflow. The script verifies
bundle integrity and the expected bundle identifier before re-signing, but an
ad hoc source signature is not publisher authentication. Do not use this script
to grant the existing app's privileges to unreviewed or unrelated software.

Dragging a public ad hoc release directly over the local installation bypasses
this signing step and can make the permission prompt return. Public GitHub CI
has no access to your local private key. Another Mac can set up its own local
identity and use the same install workflow. Never distribute the private key to
friends or put it in GitHub secrets for this local setup.

To explicitly produce an ad hoc build for the public development artifacts:

```sh
TILE_SIGN_IDENTITY=- ./scripts/build.sh
```

## Verify signing continuity

```sh
./scripts/check-signing-continuity.py '/path/to/old.app' '/path/to/new.app'
```

Both app bundles must have valid strict signatures and the same designated
requirement, pinned to the expected app identifier and exact signing certificate.
The check rejects identifier-only and ad hoc requirements. It proves signing
continuity; actual permission retention must also be tested by updating the
installed app and checking its native Accessibility status.

Apple references:
- https://developer.apple.com/library/archive/technotes/tn2206/_index.html
- https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html
- https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/RequirementLang/RequirementLang.html
