# Celestial Returning Glaive

Incremental base: `22c007f4910f0a7059635b5fb26029d7fa67d065`, after Jade Binding Chain R2. Main/production and parked IAP unchanged.

## Gameplay

Legendary permanent armament `celestial_returning_glaive`, initial★1→★5 through existing ownership/ascension. Chapter3 Stage5 unlock, price1100, forge220, damage+8%, crit+2%. Run refinement remains Lv.1–7 with base damage10 +5 per level; internal Spirit Sword checkpoint key intentionally unchanged. The equipped active-run snapshot chooses a distinct starter weapon subclass; changing hub equipment cannot alter a saved run.

Flight:0.46s outbound piercing,0.24s endpoint spin, then a580px/s homing return to the current player's position. Lv.3 adds52px mirrored crescent curvature; Lv.5 launches two opposite-path discs with0.16s stagger; Lv.7 adds a58-radius ring only on a real catch. A return that expires or loses its player cannot grant a catch ring. Per-enemy/per-disc/per-phase hit ledger prevents repeated spin damage. Collision is swept along movement segments in bounded25ms simulation steps. Normal320px/boss230px reach is enforced on every hit and inherited from WeaponManager exports.

Single-disc outbound/spin/return multipliers:80%/30%/100% of rolled base damage. Twin-disc multipliers per disc:55%/20%/75%; Lv.7 catch ring35%. All hits use PlayerStats, equipment and enemy reduction logic, with actual critical feedback. Returning Dao Resonance reuses the existing selected starter resonance: an outbound critical empowers only the first returning hit by+40% base damage per disc. It creates no extra projectile and cannot recurse. New weapon is deliberately a positional piercing alternative; final broad economy/combat tuning remains the planned audit.

Cooldown2.1s; floor1.75s. Each disc including stagger expires at3.4s, bounding active projectiles to four for one armament. Trails retain12 points, hit flashes retain at most6, pause freezes flight clocks. Reduced Effects keeps phase readability and removes extra glow/rotation.

## Presentation

One original ImageGen treasure asset is shared between equipment icon, actual spinning projectile and interactive Hero preview: antique gold, turquoise jade, Chinese cloud engraving, three crescent blades. Source PNG unchanged;512px import with mipmaps (~1.33MiB RGBA mip chain). Prompts/SHA256/path in `assets/vfx/returning_glaive/asset_sources.json`. Existing curated sword/chain sound palette reused. Turquoise departure and gold return trails expose phase without covering boss telegraphs. Native review corrected small-sprite texture aliasing.

Hero's44px PREVIEW control opens a responsive demonstration with a position slider and Lv.1/3/5/7 cycle button. Slider controls the return endpoint. Refinement choices, resonance, Skill Book search/descriptions, player cast cue and live stats name the actual armament. No baked labels/stars in the art.

## Dashboard and old APKs

Reviewed catalog now contains42 permanent equipment entries. Mail and banner admins may send/feature the glaive after redeploy. Existing rates/pity/Fate guarantees and paid features unchanged. New client adds `X-Jade-Returning-Glaive: v1` while retaining jade-chain-v1/gifts-v2. Old and intermediate APKs do not see or reserve unknown glaive gifts; filter precedes pagination. Server tests prove immutable receipt replay and allow old chain gifts unchanged. Unknown banner equipment continues to be rejected by old clients.

## Verification

Godot4.7.2:66 focused flight/UI checks;9 real save/Continue checks across separate processes;59 chain regression checks;9 chain restart checks;67 Pavilion banner checks;62 mail gift checks. Node:52 identity/mail/banner tests. Total324 checks/tests passed. Preview bounds verified320×568,390×844,648×1152. Actual native OpenGL game renders inspected before and after mip filtering;8-second gameplay video includes real input-driven player movement and return flights.

Existing headless Dummy shader and fixture shutdown resource warnings remain; these are not described as fixed. Android APK/device performance and Windows PowerShell cannot execute in this Linux environment. Source-only scope excludes secrets, old mutable publisher files, shared LESSONS.md and unrelated mirror-bracer changes.

## Install and publish

Apply `Jade-Ascendant-Returning-Glaive.patch` after Jade Binding Chain R2 using git apply --check first. Let Godot import the new texture and re-export/install Android. Run `backend\player_identity\deploy_pavilion.cmd` for the reviewed dashboard catalog/icon. No new database migration beyond existing Pavilion schema is needed. Send one glaive through mail, claim it and equip in HERO; start a new Trial (Continue preserves the previous saved armament).

`backend\player_identity\publish_returning_glaive.cmd` uses the absolute SystemRoot PowerShell path, checks the authorized checkpoint branch/remote/reviewed files/tests, then normal-pushes and prints the real GitHub commit URL only after remote-SHA verification. GitHub integration write access remains blocked in this session; no new published commit is claimed.

Packaging validation must apply against divergent LESSONS.md and old publisher/configuration files and compare all resulting reviewed bytes with the working files. Lessons delivered separately in `RETURNING_GLAIVE_LESSONS_2026-10-13.md`.
