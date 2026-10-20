# Board polish and actionable notifications — 2026-10-20

Base: `e2b980c6e095fbcfaf85d972b1baa3c496a059aa`.

## Delivery scope

- Shared action-dot policy on all five bottom navigation destinations, Home All Events and profile milestone, event hub cards, board daily missions/milestones, event claim controls, Pavilion free gifts/meditation, and mailbox claim actions. Existing unread mail and individual Hero upgrade indicators are preserved. No red dots merely for visiting a shop, spending currency, or watching an optional ad. Claimed, inactive and expired actions clear their indicator; event milestones retain the server's three-day grace. Dots stay within their control and normal canvas stacking.
- Board walking: 0.28 seconds per intermediate tile, 0.34 seconds for the last tile, plus 0.22 seconds landing. Smooth interpolation, stable feet, directional authored frames, no second procedural leg displacement. Reduced motion retains readable movement. No roll input during travel or landing. Destination selection waits until arrival.
- Board pawn uses the existing approved Lin Yue source illustrations, repacked at 192px per frame instead of scaling 96px combat textures. Four directions, authored walk and idle frames, 16px transparent gutters and a stable 164px feet baseline. Combat/player source assets stay unchanged. The reproducible art packer is included; players/installers need not run Python.
- Board dragon gate icons keep their aspect ratio, gain restrained painted halo accents; temple, landing and foot aura presentation use existing premium artwork. Board layout is retained, with room above the first row for the larger pawn.
- Every board popup uses the transparent Imperial material frame. Popup buttons use matching material instead of the old RGB atlas matte. A softer jade scrim retains modal focus. Repeated mission/shop/info/reward taps reuse one open sheet; Pavilion target/rates/history sheets are guarded against repeated creation and rapid category rebuilds.
- Notification education popup is removed. At the first safe Home opportunity, the existing native Android enable/permission route is called directly, once. Prior denial/opt-out remains respected; Settings provides the explicit retry/system-settings route. Android controls whether its system dialog can appear. Existing FCM subscription, privacy preference, delivery and native binary remain unchanged.
- Two existing board positions (displayed tiles 10 and 18) each add one Pavilion Seal on the first landing for that owner/event; later visits retain normal supplies. Maximum two additional seals per event, not per day. Existing 24/48/72 milestones, paid packages, die odds, daily dice and ad caps remain unchanged. Grants use the existing atomic server state + outbox + immutable request receipt, and arrive in Mailbox.

## Celestial Event preview gate

The spacious Celestial Event redesign was generated and shown in chat. It is a concept preview, not a screenshot of implemented code. The hub's existing layout/artwork are intentionally retained until the user's ACC. Only its actionable dots are wired in this batch. No example preview prices, rewards or progress numbers are introduced into the economy.

## Deployment and export

The package launcher resumes installation, isolated QA, unchanged native candidate verification, checkpoint publish, one IAP Worker deployment, and one owned release AAB export. There is **no SQL migration**, profile Worker deployment, notification broadcast, purchase or automatic event reschedule. Existing live IAP gates and production DNS/TLS policies are preserved. An interrupted stage is recorded; rerun the same launcher. Unrelated work and export presets are not staged or overwritten.

The installed native bridge keeps a closed root response envelope. New board presentation metadata is normalized under `state.board_rewards` at the HTTP boundary, including stored action replays; neither native allowlist nor durable receipt bytes are loosened or changed. Legacy clients retain valid responses. New AAB metadata requires presentation 4 and board-polish revision 1, matching the verifier.

## Validation

Desktop Godot checks use isolated save directories and strict shadowed-base-member warnings. Runtime checks cover travel/landing and wraparound, action dots and claim grace, 100 repeated opens of each critical sheet, small portrait/landscape popup bounds, direct native notification calls with denial/opt-out controls, and every pawn frame's alpha gutter. SQLite service and HTTP tests cover seal caps, owner isolation, reads that never grant, idempotent replay, concurrent revision races, closed native envelope, existing ad SSV/bonus/production routes. Existing native candidate hash and all recorded native inputs are verified without rebuilding Gradle.

These are desktop/runtime and in-memory server fixture checks. The package has not itself been installed, deployed, exported or published from the Windows PC here. Android OS permission appearance, final on-device feel and live backend rollout remain verified by the normal user-run launcher/device flow; no phone measurements or new real purchases are claimed.
