# Cultivation performance — 2026-10-13

Device baseline supplied by player: first entry load-ready 1215 ms / complete 1743 ms; subsequent entries 49–51 ms / 503–547 ms. Load-ready is elapsed since transition start, including the outgoing veil; it is not isolated disk/network time. The remainder includes construction, layout, frame scheduling and the incoming fade.

Changes:
- Retain Cultivation's PackedScene in the existing bounded, idle-only hub prewarm, before Trials and optional Pavilion art. Requests still share ResourceLoader's existing threaded request; gameplay releases the hub cache.
- Build all mastery choices before reveal. Resize adjusts existing grid columns only; neither height nor width rebuilds choices or changes font sizes.
- Keep initial body transparent during two layout frames; reveal at final scale with a short alpha-only fade. Remove the old 20px entry movement. Detached deferred intro/result work exits safely.
- Create the hidden breakthrough result modal only upon its first use, then reuse it. Its existing compact scroll body, actions and intentional result effects remain.
- Add `Menu scene ready: <path> | build <ms>` for construction timing, alongside existing cumulative load-ready and total transition logs.

Validation:
- New performance/presentation smoke: 68 checks passed headless and 68 checks passed native X11/OpenGL. Covers first visible text geometry, fixed fonts, stable choice identity during repeated resize, current state refresh, three widths, first/repeated lazy modal, unchanged save/economy, and departure during pending intro/result.
- Mastery regression: 65 checks passed. Its deliberately invalid victory fixtures still emit expected missing reward source diagnostics.
- Existing menu/touch regression: 33 checks passed.
- Native Cultivation, compact phone and result modal renders inspected. No new assets or visual redesign.
- Probe: unused entry tree reduced from 203 to 155 descendant nodes. Normal entry already showed one stable mastery identity before this change; repeated entry rebuild loops were not proven as the original primary latency cause.

Device latency is not yet verified after export. Prewarm helps once idle loading finishes; an immediate tap may still await the in-flight load. No guaranteed phone millisecond target is claimed. On-device follow-up should compare first/warm `load ready`, `scene ready build`, and total on the same phone.

Apply the incremental patch after the preceding Cultivation and menu-performance patches; re-import in Godot and re-export Android. No backend deployment. Publisher `backend/player_identity/publish_cultivation_performance.cmd` publishes only the authorized checkpoint and prints the verified commit URL. Main and parked IAP remain protected.
