# Legacy equipment art refresh — 2026-10-13

Base snapshot: `4fd2983236a819bd7282c3ee1ad53bda6a20fe64` (after Returning Glaive).

## Result

40 original equipment images replaced: 8 armaments, 8 robes, 8 bracers, 8 boots, 8 pendants. Consistent xianxia/wuxia materials, ornament, readable silhouettes, transparent cutouts. Jade Binding Chain and Celestial Returning Glaive are excluded and byte-identical to the base.

Inventory, pavilion, forge, mail, skill book, level-up starter/resonance choices and dashboard use the reviewed catalog icons. The eight original equipped weapons render their own art through the original Spirit Sword projectile. Other equipment changes only its displayed image; no armor/player reskin is introduced.

Original generated PNGs and prompt/SHA provenance are in `assets/ui/equipment/imperial_v3`. Native Godot compilation creates centered 256 px inventory icons, with swords diagonal in the square; combat uses horizontal source textures. Import limits and mipmaps cap runtime texture size. Dashboard ships the compact compiled icons rather than full-resolution source art.

No gameplay changes: stats, rarity, stars, level caps, milestones, rates, pity, economy, attack logic, speed, lifetime, piercing and hitboxes are preserved. No server schema, auth, reward semantics, ad or IAP changes.

## Validation

- 180 focused Godot checks: 40 client/admin icon routes and bounds, both excluded weapons, all 8 actual projectile sprites, unchanged motion, hitboxes, damage, piercing, repeat-hit guard and fallback.
- 52 Node tests; 59 binding-chain, 66 returning-glaive, 67 pavilion-banner, 62 mail-gift checks. Total 486 passing assertions/tests.
- Static comparisons: 11 protected files byte-identical; Spirit Sword source exactly matches base after removing three presentation insertions; mail catalog metadata identical after removing icon_source; 40 original generated PNG hashes match provenance.
- Native engine previews: complete 40-item grid, 8 actual equipped projectile bodies, production Hero equipment screen. Android export/device validation remains on the user's Windows machine.
- Binary patch checked/applied on clean base and shared-document/publisher divergence fixture. Patch excludes shared lessons, prior publishers and unrelated mirror-edge asset changes.

## Windows use

Apply the patch after Returning Glaive with `git apply --check`, then `git apply`. Open Godot so new textures import, then export/install Android. Deploy dashboard icons using `backend\player_identity\deploy_pavilion.cmd`. No database migration.

Publish using `backend\player_identity\publish_equipment_art.cmd`; it preserves protected branches, validates Node tests, pushes the checkpoint without force and prints a GitHub commit URL only after remote SHA verification. The assistant environment cannot authenticate GitHub writes, so no publication is claimed here.
