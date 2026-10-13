# Balance audit lessons — 2026-10-13

- Legendary rarity pity is not the same as a target-item deadline. Initial simulation incorrectly assumed five copies within250 pulls and failed; inspecting pity reset after off-target Legendary showed the correct fixed-target theoretical bound495. Use the actual sampler and verify both guarantees before disclosure/cadence claims.
- First-copy forge explicitly rejects owned items. Do not assume a stone/fragment shop can supply duplicate ascension materials. Inspect gates as well as catalog prices.
- Include login, daily, idle and repeat-clear sources; clearly mark which are omitted from a steady-state model. UI meditation grants Spirit Stone, not jade.
- Compare actual contacts/ticks, not projectile/blade count times damage. Shared cooldowns, boss modifiers, crowd status caps and intentional floor limits alter effective damage.
- Audit exports must use an isolated profile, compare owner snapshots, restore RNG, and only publish new output on a successful run. Proposed tuning stays separate from measured current behavior.
