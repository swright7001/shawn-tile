# Updates and release notes

Install 0.4.1 once if you are using an older version. Then use Check for Updates
in Shawn Tile's menu or General settings. Automatic checks run daily and can be
turned off. A newer stable release shows a banner, feature summary and full notes.
Update & Restart starts the download and installation. It never installs in the
background without that button press.

The updater uses the public latest-release API for this repository over normal
HTTPS. No login, token, telemetry or custom server is involved. GitHub may still
see ordinary request information such as the IP address. Release metadata and
check preferences are cached locally in the app's defaults domain.

## Download and installation checks

The update archive must be the universal ZIP named for the reviewed version.
Its URL must belong to this project's release, and the GitHub API must provide
its SHA-256 digest. Re-check metadata at installation time so stale/cached notes
cannot authorize a different release. Redirects stay on the expected GitHub
release hosts. Metadata is limited to 2 MiB, ZIPs to 64 MiB and declared extracted
contents to 128 MiB. Reject unsafe paths, duplicate entries, symlinks, special
files, encrypted/split/ZIP64 archives and malformed directory structures before
calling the system extractor.

The trust root is this project's GitHub release account and HTTPS connection.
The digest checks downloaded bytes against GitHub; it is not an independent
publisher signature. Strict code signature checks then verify bundle integrity,
app identity and expected version. Release notes display as inert text.

The candidate is staged beside the installed app before quitting. An
unprivileged helper keeps the original as a dated backup, renames the new bundle
into place, and relaunches it. Replacement failure restores the original path.
Cancellation before handoff leaves the installed bundle unchanged. Read-only DMG,
translocated, or unwritable installations must be moved to a writable Applications
folder first. ~/Applications works without an administrator installation helper.
No TCC, Gatekeeper, quarantine or general trust setting is changed.

## Accessibility and local signing

A public ad hoc build can require Accessibility to be granted again after a
replacement. The update review shows this limitation. Each Mac makes its own
permission decision. If the setting is already on but the new app is not trusted,
remove the stale entry and add the exact installed app again.

If this Mac has the configured local certificate from [LOCAL-SIGNING.md](LOCAL-SIGNING.md),
the updater verifies the current identity and signs the staged update with that
same certificate and app identifier. Signing failure stops the update; it never
silently changes a configured installation to ad hoc signing. Key material stays
in Keychain and configuration stays outside the bundle. A missing signing
configuration for an existing certificate-signed installation is an error.

Keep a normal backup of the Mac and Keychain. Never share the private signing key
with friends or put it in public releases. Each Mac can use its own certificate.

## Publishing an update

Build and test the universal app, then package a public ad hoc release with the
matching version. Publish a stable GitHub release with the universal ZIP, DMG,
SHA256SUMS and human-readable feature notes. The app uses the release body's text
for the banner and notes, and GitHub's asset digest for archive verification.
Incomplete/draft/prerelease releases are not offered. An installed app never
accepts an equal or older version.

Executed checks and deployment details are maintained in ../VERIFICATION.md.
