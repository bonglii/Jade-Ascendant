# Library and Lin Yue polish — 2026-10-14

Scope approved by the user: retire Astral Resonance Bell, combine equipment encyclopedia and Skill Book into the approved Library, polish the protagonist's authored movement comprehensively.

## Lin Yue

- Generated identity-consistent 2D drawings: three directional walk sources (left mirrors right), idle breathing/blink, four-frame hurt, eight-frame kneeling defeat. Packed 72 independent runtime cels into three compact atlases; 96px cells, 8px safety gutters, boot baseline 82px. Raw sources are under `.gdignore` and not loaded in combat. The technical packer and hash/bounds manifest are reproducible.
- Distance-driven eight-pose walk: 112px per full cycle, phase retained across direction changes. Actual `move_and_slide` travel selects poses; held input against collision settles to idle. Idle and hurt have authored timing. Hurt never changes movement speed, collision or attacks.
- Removed competing full-body squash, rotation, shader hem deformation and ordinary walk ghosts. Subtle outline and pooled footfall cues accompany the actual drawn poses. Existing set/cultivation/weapon presentations retain their own effects.
- The health owner retains all defeat/revive behavior. A short-lived visual copy plays the kneeling defeat while the live body is hidden. Damage/stat/save/balance values are unchanged.

## Library

- Existing Home Skill Book entry becomes Library; Equipment and Skills tabs. Equipment grid has five columns, query/category/rarity filtering, ownership indicators, compact selected-item preview and scrollable details. All 56 active equipment, 11 four-piece sets and all 18 run skills remain discoverable.
- Actual catalog data supplies rarity colors, stats, set bonuses, signature effects, unlocks and synergy requirements. Concept image example text is not gameplay authority. HERO remains the loadout/upgrade surface; Library is read-only.
- Generated archive background, carved jade button art already shipped in the account gate, embedded licensed serif headings. Scroll/click handling uses the existing mobile touch guard.
- The inherited skill reader keeps dynamic descriptions for the equipped starter and exact resonance requirements. Runtime scene path remains stable for existing navigation/cache references.

## Bell retirement and saves

- Bell disappears from public equipment IDs, backpack listings, new gacha/forge, rate-up validation and new dashboard gifts. A minimal retired definition and legacy combat assets remain for historical saves, existing receipts and an already-running checkpoint.
- Next-run Bell slot is cleared; counts, stars and permanent levels remain archived instead of being erased or converted into an unrelated item. An existing active run can finish/Continue its frozen loadout. New runs cannot equip/ascend/level the retired item.
- Backend public snapshots remove Bell even from previously published banners. Bell-only banners fall back to the default banner; mixed banners keep their active featured items. Dashboard catalog version 4 contains 56 active items. No database migration/deletion is required. Existing mail grants are immutable.
- Deploy the player-identity Worker update separately with the included deploy launcher to apply the dashboard/banner allowlist change. No local remote deployment, main change or paid-gate activation is part of this package.

## Validation

Godot 4.7.2 Linux fixtures: main Library/Lin Yue suite, actual wall collision, all animation bounds, compact detail layouts at 320×568, 390×844, 648×1152 and 896×504; combat skill regression; remaining Arsenal integration. Node identity/mail/pavilion/announcement tests. Native OpenGL renders and a controlled walk-cycle capture are reviewed separately. This is not an Android device/FPS or Windows PowerShell execution claim.

## Lessons / recovery

- A session resumed from an older scratch snapshot. Recover the authoritative checkpoint and persisted generated assets before continuing; never infer that missing local work means the user's project rolled back. Commit/package intermediate completed work to avoid relying on transient scratch alone.
- Do not print imagegen result objects or base64 payloads; expose small metadata or the generated image helper only.
- A fresh Godot import must complete before scene tests start. A test launched before import produced missing-resource errors; those are not evidence of client defects. Use bounded test processes and require final import completion.
- Programmatic `LineEdit.text` does not imitate typing/text_changed. Search fixtures must explicitly refresh after assigning text; actual user typing keeps its signal path.

Final transport: strict apply found two trailing spaces in the embedded font license; whitespace was normalized without changing license wording. Check the produced binary patch on a clean index, including reverse/already-installed detection.
