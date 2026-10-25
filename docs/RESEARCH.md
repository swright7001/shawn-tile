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
