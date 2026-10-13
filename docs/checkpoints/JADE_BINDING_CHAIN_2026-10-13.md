# Jade Binding Chain — permanent armament

Patch base: `8ad5a67408a2b4b0e4877376ed665a5d1bfebe5c` (working tree after Event Identities).
Apply after the Event Identities patch. This is an incremental patch, not a full checkout.

## Behavior

Legendary gold armament, initially ★1 and ascended through the existing ★5 system. Existing ownership, five slots, ascension multipliers/costs, active-run snapshot and checkpoint schema remain authoritative. Unlock gate Chapter 3 Stage 5 matches Nine Heavens Star Sword; price1100, forge220, damage bonus8%, critical chance2%. No extra paid acquisition or IAP changes.

Equipping `jade_binding_chain` selects a real starter weapon subclass. The internal `Spirit Sword` checkpoint key preserves old saves; public level-up, resonance, Skill Book and live stats identify the chain. All other armaments retain their current attacks.

Attack:0.22s seal anticipation, binding chip, then primary knot detonation at0.82s and other knots staggered by0.10s. Selects actual nearby enemies once per cast, never duplicated targets. Targets:2/3/4/5 at run Lv.1/3/5/7; radius80/92/104/116. Standard refinement damage10 +5 per level remains compatible with checkpoint restoration. Primary receives30% chip +150% detonation of rolled base damage; secondary receives20% +80%. Damage follows PlayerStats, crits and enemy reductions. Critical resonance adds one40% knot to a nearby unbound enemy, at most once per cast and never recursive.

Walking, frenzy, dash and boss strafe use one pause-aware movement modifier. Normal slow40%, bosses12%, duration0.72s; authored speed/AI/attack timers/collision never overwritten. Repeated bindings refresh the strongest modifier without stacking. Dead/freed or out-of-reach targets cannot receive delayed damage; actual reach320px normal/230px boss. Cooldown1.8s with1.25s floor, which bounds overlapping maximum-level casts to two and preserves readable phases. Long slow chains cannot immobilize bosses.

## Presentation and assets

Two original transparent ImageGen assets, emerald jade / antique gold: equipment treasure icon and ornate ground seal. Source PNG bytes preserved, SHA256/prompts in `assets/vfx/jade_binding/asset_sources.json`. Both imports capped at512px (~2MiB combined RGBA texture memory). Shared deterministic vector renderer draws articulated jade links, gold fittings, endless knots and sequential localized shock rings. Existing chain sound variants reused. Reduced Effects removes extra rays/rotation and gives a static UI demonstration while actual phase/damage timing remains unchanged.

Hero detail includes a44px PREVIEW button and an animated, responsive attack explanation. No generated text, stars or UI were baked into equipment assets. Native gameplay video shows the actual Godot level and real damage callbacks, not a mockup.

## Dashboard and compatibility

Reviewed mail/banner catalog contains41 equipment IDs, including this armament and its icon. Existing rates, pity and Fate guarantees unchanged; banner admins can select it explicitly after redeploy. Old APKs reject an unknown banner safely. New client advertises `X-Jade-Equipment-Catalog: jade-chain-v1` in addition to the existing gift capability. Chain mails are filtered before pagination and cannot reserve a claim for older APKs; immutable reward receipts/replay protection remain intact.

## Validation

Godot4.7.2 native checks:59 focused gameplay/UI checks;9 checkpoint checks across two separate processes;67 banner regression checks;61 mail-gift regression checks. Node:50 identity/mail/banner tests. Total246 assertions/tests passed. Real enemy movement verified at80→48→80 without rewriting base speed. Actual checkpoint write/Continue restores Lv.5 /30 damage /four bindings despite next-run hub change. Mobile preview fits320×568,390×844,648×1152. Native OpenGL/Xvfb renders checked for Hero, preview, binding and detonation;8-second actual gameplay capture produced.

Headless existing level shader/Dummy-renderer and fixture shutdown resource warnings remain; these are not claimed fixed by this weapon patch. Windows PowerShell and Android APK cannot execute here. Windows launcher uses the absolute SystemRoot PowerShell path; Android device performance/touch is the final device check. Broad HP/damage/economy and ads audit remains the separate planned phase.

## Windows

1. Apply `Jade-Ascendant-Jade-Binding-Chain-R2.patch` with `git apply --check` first.
2. Open Godot and let the two textures import; re-export/install Android.
3. Run `backend\player_identity\deploy_pavilion.cmd` to deploy the new dashboard catalog and icon. No new database migration is needed beyond the existing Pavilion deployment.
4. Send one chain via dashboard mailbox (new APK required), claim it and equip in HERO. A running checkpoint keeps its original armament; start a new Trial to use the newly equipped chain.
5. Publish using `backend\player_identity\publish_jade_chain.cmd`. It targets only the authorized checkpoint branch, checks reviewed files/tests, pushes normally and verifies the remote SHA before printing the real GitHub commit URL.

GitHub integration write access was previously rejected403; no new remote commit is claimed. Main/production, protected secrets, parked billing paths, existing old publisher files and unrelated mirror-bracer changes are excluded from this incremental patch.

## R2 packaging correction

Shared `docs/checkpoints/LESSONS.md` is excluded from the incremental patch. New lessons are in `JADE_BINDING_CHAIN_LESSONS_2026-10-13.md`. Gameplay and assets remain identical; old mutable publisher and shared lesson divergence are verified independently.
