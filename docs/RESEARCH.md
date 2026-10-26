# Evidence record — 2026-10-25

Target: Shoji 1.0 public website and web demo, https://shojimac.com/ (the user supplied a ref query). Investigation scope: public documentation and disposable browser interaction with demo windows. No native download, paid access, binary disassembly, source-map inspection, private account, or license bypass.

## Questions and findings

| Question | Finding | Classification | Limits |
| --- | --- | --- | --- |
| Core workflow? | Public guide describes automatic placement of ordinary resizable windows, clockwise grid order, columns, portrait rows, capacity 1–4. | Observed documentation; native behavior remains a vendor claim | Native app not run |
| Overflow behavior? | REA clicked Tile My Windows, then Open a new Files window. The accessible page exposed Files controls plus two stack controls and an overflow message. | Observed browser demo | No inference of native internals or timing |
| App controls? | Docs describe per-display settings, pause, focus, exclusions, shortcuts and app window constraints. | Observed documentation | Full feature equivalence not established |
| Multi-display semantics? | Public laptop guide and keyboard reference differ about moving into a full display (stay versus configurable swap/stack). | Observed conflict | Our v1 avoids directional cross-display moves |
| Implementation choice? | AppKit + Accessibility can supply public window position/size APIs; Carbon registers discrete hotkeys. | Design decision from Apple APIs | Actual apps impose size and permission restrictions |

Sources consulted:
- https://shojimac.com/docs/guide/how-tiling-works/
- https://shojimac.com/docs/guide/stacks/
- https://shojimac.com/docs/reference/keyboard-shortcuts/
- https://shojimac.com/docs/use-cases/laptop-and-display/
- https://developer.apple.com/documentation/applicationservices/1460434-axuielementsetattributevalue
- Apple framework headers provided by the installed macOS SDK.

## REA provenance

Connected REA tool: `capture_browser_scenario`; provider `rea-playwright-browser-scenario` version 1; Chromium 156.0.8078.48 from installed Brave. New temporary headless profile, 1280×720, en-US, UTC, reduced motion, service workers blocked. Owned browser processes reported terminated after each capture. Network bodies and headers were not selected. No unrelated browser state was read.

- Initial capture: `ev_4913bcd84d1c15183f0acf7db996c4ee7f4c5b905eab436ffad5047ce2db49e0`. Navigation + 1500 ms wait; DOM and accessibility requested. Full DOM includes delivered webpage markup/inline bootstrap text; no target code was incorporated into our implementation.
- Demo interaction: `ev_a9acd02d1681c9b902a342916557054f3ea4c0ece95fbccd8340a167eb6cdae9`. Declared clicks for tiling and an extra Files window with an 800 ms settle. Accessibility requested after each action, page-errors selected. All declared steps completed; capture reported complete within selected sections. Accessible stack controls establish demo state, not exact pixel placement.

Full raw captures are retained locally outside the deliverable at `../.research/shawn-tile/{homepage,demo}-evidence.json`. They are deliberately excluded from the repository and installation bundle. This record contains references and original paraphrases only.

## Implementation provenance

All application code, tests, icon geometry, documentation and scripts were authored for Shawn Tile. Apple frameworks are system dependencies; no external packages. No Shoji branding, screenshots, media, code, or binary ships in this project. The behavior specification is original wording. No restricted implementation investigation or independent/clean-room implementation requirement was established; no claim of enforced clean-room separation is made.

Unknowns: native Shoji behavior beyond public descriptions, long-session CPU/memory, physical multi-display/Space edge cases, other Mac's OS/hardware, Apple Developer signing availability. Our software's execution record is in VERIFICATION.md.

## 0.3 shortcut API investigation

Reviewed the installed Apple SDK CarbonEvents.h contracts for exclusive hotkey
registration, application targets and the toolbox dispatcher. Cross-checked
dispatcher usage against the HotKey author's controller:
https://github.com/soffes/HotKey/blob/master/Sources/HotKey/HotKeysController.swift.
This was an API usage check. No library dependency or source was incorporated.
The app's binding model, editor, registration transactions and fixture checks
were authored here. Physical testing through Screen Sharing established that
Control-Shift-Command-P reached the app when the original Control-Option-P did
not. The particular source of interception was not established. See executed
checks and limits in VERIFICATION.md.

## 0.4 layout and updater investigation

The user's screenshot showed explicit Grid selected with a column arrangement.
Inspection established that the planner tried alternate arrangements whenever
fitting was enabled, and fixed geometry also imposed rows on portrait displays.
The original implementation now distinguishes Auto from explicit shape choices.
Mixed minimum-size fixtures also established the need to rebalance four Grid
stack groups before lowering count. No new reference-product code was consulted.

Updater API references were GitHub's release-asset digest documentation and
Apple URLSession redirect/delegate documentation:
- https://docs.github.com/en/rest/releases/assets
- https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/
- https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate

The native updater, bounded ZIP-directory validator, installation helper and
checks were authored here using Apple frameworks and built-in macOS tools.
Source authentication depends on this project's GitHub release account and TLS;
archive digests and strict signatures provide additional integrity checks.
Execution evidence and remaining limits are in VERIFICATION.md.

## MacBook stack-collapse investigation — 2026-10-26

Public 0.4.3 on a 1440×870-point usable display reported one tile with three
stacked windows after a clean reinstall. The user reported GPT not fitting the
grid and Tidy producing an overlapping layout. Accessibility was granted; this
is separate from issue #1. The precise GPT client minimum is not established.

Static inspection showed a single 350 ms response was learned as a minimum,
and minimums only increased. A pure delayed-response regression failed with
the extracted original learning rule (900×600 learned instead of no bound).
An isolated native fixture animates AX resizing through intermediate dimensions.
It failed against the original WindowManager and passed after stable-sample
confirmation. This establishes a reproducible failure mechanism, not that all
user-reported overlap has this cause. No external implementation was consulted.

Follow-up: Shawn confirmed that ChatGPT can be resized manually to less than half
his display's width while tiling is paused. The observed 1432-point width is
therefore not a demonstrated hard minimum. The precise AX failure is still
unconfirmed. Two identical samples cannot distinguish an ignored axis from a
minimum; compare each axis with its pre-request value before learning it. A
single size-only retry after an unchanged first sample avoids simultaneously
rewriting position, without restarting an animation already making progress.
Public Rectangle documentation was consulted for general minimum-size context
(https://github.com/rxhanson/Rectangle); no implementation code was copied.

A later manual check confirmed that ChatGPT cannot shrink below half the screen's
height. Detailed live diagnostics exposed the specific miss: a requested
890×274 frame at (546,34), observed 890×600 at the same origin. The width and
position were accepted; the short height was not. An unchanged response to a small
height probe remains ambiguous, so do not require that probe to succeed before
trying a larger-cell arrangement. Add bounded, temporary count fallback down to
two tiles, then verify actual frames. No new permanent bound is inferred from
that ambiguity, and the user's maximum remains unchanged.
