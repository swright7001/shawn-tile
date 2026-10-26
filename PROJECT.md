# REA project template: original content creation tools

Use this template for REA-assisted projects in this workspace. Copy it into each new project as `PROJECT.md`, fill in the brief, and maintain the evidence, specification, and verification records as work progresses.

Working sequence: **define → investigate → specify → build → verify → demonstrate**.

## 1. Project brief

- Project name: Shawn Tile
- Intended user: Shawn Wright, on his Macs
- Content creation problem: keep editor, terminal, browser and studio windows arranged without repeated dragging.
- Desired outcome: native offline tiling app and repeatable installation from Shawn’s GitHub repository.
- One feature to investigate first: automatic tiling and overflow stacking.
- Reference app, website, artifact, or public specification: Shoji public website, docs and interactive demo.
- Target version, URL, or artifact digest: Shoji 1.0, https://shojimac.com/, observed 2026-10-25.
- Intended use: personal and public sharing; original source and installers available under the MIT License.
- Success criteria: runnable native app, per-display layouts/stacks/focus/exclusions, passing geometry/state checks, universal install packages.
- Out of scope: proprietary implementation/asset reuse, dimming/presentation modes, drag split editing, native Shoji parity; see SPEC.md.

Prefer a small, useful feature over an entire product reconstruction. Define observable acceptance criteria before implementation.

## 2. Scope and source record

- Source and how it was obtained: public website read through web tools and REA disposable-browser scenarios.
- Basis for examining this target: user supplied target URL and asked to use REA to build a personal alternative.
- Relevant license, terms, or reuse permissions: reference remains proprietary; no reference code or assets distributed. Original deliverable uses MIT.
- Allowed operations: public documentation and disposable public demo interaction (tile/open simulated windows).
- Allowed accounts, endpoints, files, and output locations: public shojimac.com; own shawn-tile/ project; raw captures in sibling .research/shawn-tile/.
- Original or licensed assets and dependencies available for our build: original Swift code/geometric icon; system Apple frameworks.
- Any specific unresolved restriction that affects the planned work: native cross-app execution requires app-specific Accessibility permission.

Start with public documentation, public specifications, open-source examples, or observable behavior when they answer the question. Add deeper analysis only when needed. Inspect only the selected target and use disposable profiles or test data when runtime work could affect state.

Do not bypass payment, licensing, authentication, DRM, or other access controls. Do not transfer proprietary code, branding, media, credentials, or private captured data into the new tool without applicable rights. REA's license does not grant rights to a target or its output.

Resolve material scope questions before dependent operations. Routine authorized work does not require repeated confirmation.

## 3. Investigation and evidence

Record one question at a time:

| Question | Observation | Evidence location | Classification | Limits / next check |
| --- | --- | --- | --- | --- |
| | | | observed / derived / inferred / unknown | |

For each investigation, retain:

- Target identity and version or digest.
- REA version, tool, relevant options, and provider if applicable.
- Evidence IDs, source locations, screenshots, or capture paths.
- Inputs and conditions needed to reproduce the observation.
- Incomplete coverage, exclusions, and conflicting results.

Separate observed behavior from static relationships and hypotheses. A viral post is a lead to verify. A missing result is not proof that a feature is absent. Avoid collecting unrelated account or browser data.

## 4. Behavior specification — `SPEC.md`

Describe the required behavior in our own words:

- User goal and interaction sequence.
- Inputs, outputs, and supported formats.
- State transitions and relevant timing.
- Edge cases, failures, cancellation, and recovery.
- Performance and accessibility requirements where relevant.
- Test examples and observable acceptance criteria.
- Deliberate differences and improvements in our version.
- Unknowns and assumptions that still need testing.

Keep the specification focused on behavior. Do not paste proprietary implementation, decompiled code, or protected assets into it.

### When independent implementation is required

Decide this before exposing an implementation agent to restricted source material. Use a fresh implementation context and an environment that enforces filesystem and network restrictions. Give it only the reviewed behavior specification, allowed public references, and permitted assets. Restrict access to the target, investigation records, decompiled output, and investigation chat history.

A different folder, another chat, or a specification written by the same source-exposed agent does not establish enforced separation. Record the actual restrictions and their limits; do not label work a clean-room implementation merely because this template was followed. Separation does not itself establish legal clearance.

## 5. Original implementation

- Implementation location: Sources/TileCore and Sources/ShawnTile.
- Language and framework: Swift, SwiftUI, AppKit, ApplicationServices, Carbon, ServiceManagement.
- Components we will write: layout/stack engine, AX adapter, observer manager, native UI, hotkeys, packaging and verification.
- Dependencies, licenses, and required notices: Apple system frameworks only; original code MIT; see LICENSE.
- Asset provenance: procedural original blue/cyan tile icon, generated by scripts/icon.swift.
- Design and branding choices: Shawn Tile, dark navy settings, cyan tiles; independent of Shoji.
- Data storage and external services: local UserDefaults; ephemeral window state; no application network requests.
- Estimated operating costs or resource constraints: no service costs; macOS 13+, AX permission, apps may reject sizes.

Build from the behavior specification using original code and design plus appropriately licensed components. Keep target artifacts and research output outside the deliverable. Preserve existing user work and keep changes reviewable.

## 6. Verification — `VERIFICATION.md`

| Acceptance criterion | Check performed | Expected | Actual | Result / evidence |
| --- | --- | --- | --- | --- |
| | | | | |

Verify the complete user workflow with representative inputs and important edge cases. Where appropriate, compare output quality, timing, format compatibility, and failure behavior with the recorded observations.

Record commands or manual checks actually performed, the environment, results, and remaining gaps. Test comparisons themselves where a faulty comparator could hide failure. Passing tests demonstrate the covered behavior; they do not prove complete equivalence, security, or permission to distribute.

## 7. Demonstration and content

Use this teaching sequence for an article, video, or build-in-public demonstration:

1. The practical problem and intended result.
2. The reference and precise investigation question.
3. The evidence and what it establishes.
4. The behavior specification and our design decisions.
5. The original tool in use.
6. Verification, limitations, and reproducible next steps.

Use our own wording, examples, recordings, visuals, and conclusions. Attribute external research. Distinguish our reproduced results from third-party claims. State costs and prerequisites instead of promising that everything is free. Check rights before publishing target screenshots, code excerpts, recordings, or other third-party material.

## Completion record

- Deliverable and launch instructions: universal app, ZIP and DMG under dist/ and GitHub Releases; see README.md and docs/INSTALL.txt.
- Verified user workflow: layout/stacks, real disposable-window reflow and focus, native settings, installation and permission gating; VERIFICATION.md.
- Known limitations: app-specific grant still required; no physical multi-display/Intel/older-OS/long-run tests; physical hotkeys pending; see VERIFICATION.md.
- Dependencies and asset notices: original code and icon MIT; Apple system frameworks; no reference assets/code.
- Evidence and verification locations: docs/RESEARCH.md and VERIFICATION.md; raw public demo captures retained outside deliverable.
- Next useful improvement: pilot on Shawn’s other Mac, validate physical hotkeys and display/Space transitions.

## Starter instruction

> Follow the workspace REA project template for this content creation tool: [idea]. Begin by defining one feature, the reference target, the permitted investigation scope, and observable acceptance criteria. Use the least invasive evidence source that answers the question. Record observations, inferences, and unknowns. Write a behavior specification, implement an original version with permitted components and assets, and verify the actual user workflow. If independent implementation is required, establish and record enforced separation before exposing the builder to restricted research material. Keep the work reviewable and report remaining gaps.

## References

- Inspiration: [codila's REA article](https://x.com/0xcodila/status/2109623431763292649). This template adapts the investigation/specification/build/verification approach; it does not adopt unverified examples or blanket claims.
- [REA responsible-use guidance](https://github.com/morluto/rea/blob/main/DISCLAIMER.md).
- [REA guidance on implementation-environment separation](https://github.com/morluto/rea/blob/main/docs/installation.md#limit-rea-to-one-project-or-agent-profile).
- [U.S. Copyright Office: ideas, methods, and expression](https://www.copyright.gov/circs/circ33.pdf).

## Working record

Define/investigate/specify/build completed. See docs/RESEARCH.md for evidence, SPEC.md for acceptance and deliberate limits, and VERIFICATION.md for executed checks. No native reference artifact acquired.

Demonstrate: installed native Settings viewed with CUA; tile picker changed 3 → 4 → 3. Real AX integration completed 11 checks against disposable windows. Repository default: private swright7001/shawn-tile because the workspace had no remote and no destination reply arrived.

Public-sharing update: Shawn requested public access so friends can download and install the app. Repository and release made public; no raw research captures or local preferences included.

## 0.2 adaptive fitting update

User requested automatic layout changes around app size limits instead of manual
tile-count changes. Original adaptive planner uses observed accepted dimensions,
unequal splits, alternate orientations, stack collapse/recovery and oversized
window isolation. Preferences migrate with fitting enabled; observed minimums
remain in session memory. No additional reference research or proprietary code.
See current SPEC.md and the 0.2 checks in VERIFICATION.md.

## Free local signing update

User requested stable Accessibility permission across updates and chose a free
local solution. Prepare one reusable code-signing identity in the user's login
Keychain, certificate-pinned app requirements, signing continuity checks and
staged installs. No private key in the repo, no Apple enrollment, no general
certificate trust changes, and no Gatekeeper/TCC bypass. See docs/LOCAL-SIGNING.md
and actual results in VERIFICATION.md.

## Customizable keyboard shortcuts

User requested live shortcut testing and editable bindings. Define all 15
existing actions as saved preferences with per-action editing, disabling,
duplicate detection and defaults. Investigate the existing Carbon registrations
and installed Apple SDK contracts, then verify handler dispatch, actual fixture
window effects, persistence and conflict rollback. No additional reference-product
research or proprietary material is required. Native keypress delivery is a
separate check from posting Carbon handler events. Record actual results and
remaining limits in VERIFICATION.md.

Delivered 0.3.0 with editable persistent shortcuts, conflict rollback, optional
Screen Sharing preset, and stable Focus during geometry changes. Verified a
physical remote Pause shortcut, all 15 action handlers and saved custom bindings;
installed with the existing local identity and published the universal release.
Executed counts, CI and release provenance are recorded in VERIFICATION.md.
