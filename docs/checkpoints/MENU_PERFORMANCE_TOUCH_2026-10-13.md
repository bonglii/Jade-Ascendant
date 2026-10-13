# Menu performance and touch — 2026-10-13

## Implementation
- TrialsHallOverlay marks production ownership before parent scene ready. Legacy Daily/Achievement card generation and hidden Daily offer polling skip only for production. Legacy fallback remains usable by removing ownership.
- Visible section builds incrementally: two new cards or four milliseconds per batch, yielding the frame. Epoch plus node/tree-lifetime guards cancel stale tab/scene work. Loading copy remains until complete; controls survive later refresh.
- Background prewarm now includes both Trials scenes ahead of heavy Hero/Pavilion. It retains at most the five configured hub PackedScene paths (textures share existing resources) and existing gameplay-entry eviction remains intact.
- Deferred MobileTouchPresentationGuard follows buttons, dynamic popup controls and themes. Touch hover equals normal, hover-pressed retains actual pressed skin, actual disabled state stays unchanged. Theme refresh is coalesced. Mouse hover remains unchanged before touch, custom nav/meridian obey the same policy and touch release removes stale button focus.
- Guest entry is enabled during anonymous identity startup, without interrupting real native Google sign-in/link/sign-out or changing identity binding. Entry/Settings status accurately labels initialization and Google linking.
- Account latency logs contain operation and elapsed time only. No tokens/UIDs. Transport, Firebase native implementation, timeout policy, server and parked IAP remain unchanged.

## Evidence and limits
- Single desktop cold probe before: Daily first-ready 637871 us with four old cards plus both production sections; Achievement 459865 us with 39 duplicate legacy records.
- Initial after probe: Daily 300963 us, zero legacy cards; Achievement 99630 us, zero legacy cards. Final after probe varied to 304800/165327 us. Filesystem/runtime scheduling affect samples. These are desktop scene-ready timings, not full-list completion times or guaranteed Android figures.
- 33 focused real-scene checks passed. HERO loadout/profile regression: 627 checks passed. Login-cycle/regression reward ledger: 364 checks passed. Total 1024, zero failures in final runs.
- Native X11 render checked, including scene exit during background construction; no script errors in final native run. Existing teardown resource-leak warnings are not a device/release pass.
- Native Google provider latency and enemy-crowd profiling remain open under backlog 1B. No enemy count, damage, skill probability, drops, mailbox, artwork or ads was changed in this batch.

## Windows use
Apply after previous Cultivation/Combat Notices patches:

```bat
git apply --check "D:\Godot\tools\Jade-Ascendant-Menu-Performance-Touch.patch" && git apply "D:\Godot\tools\Jade-Ascendant-Menu-Performance-Touch.patch"
backend\player_identity\publish_menu_performance.cmd
```

Open Godot/import, then re-export Android. No backend deployment.
After reproducing a slow login, optional collection:

```bat
backend\player_identity\collect_account_latency.cmd
```

Collector uses adb from PATH or existing D:\Godot tools locations and prints only ACCOUNT_LATENCY lines. It never clears logcat or collects token/UID data. Publisher protects the checkpoint branch/main and prints the real commit URL only after verifying remote SHA. Session GitHub writing is still unavailable; publication is not claimed here.
