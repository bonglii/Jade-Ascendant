# HERO rework lessons

- The user explicitly changed the rule to four NON-WEAPON pieces. Do not retain a five-piece denominator or add new weapons to armor sets. Rarity and star rank remain separate, and permanent weapon levels differ from run refinement.
- Four-piece catalog changes affect callers beyond HERO: default Pavilion featured pool previously reused set members. Preserve its separately featured sword so the rate-up UI does not silently lose a weapon. A 701-check reveal regression caught this coupling.
- A debug build is not evidence that weapons are disposable QA grants. MainMenu cleanup formerly removed whole weapon IDs on first debug Home load. Limit that cleanup to a dedicated armament QA data directory so legitimate copies cannot be lost.
- ScrollContainer may clamp requested width to its child's old minimum. During resize, compute page/card width from the safe host rather than the already-clamped scroll width, then set scroll size after rebuilding. Verify five columns and navigation bounds at 320 px.
- Never mix spaces into an existing tab-indented GDScript. QA subclasses with autoload dependencies must be loaded after startup; use a separate fixture rather than top-level inheritance that compiles before singleton initialization.
- Reuse original generated art for runtime. Inspect native screenshots, not imagegen concepts, before declaring the interface implemented. Keep detail metadata understandable: show SENJATA/JUBAH, not internal slot IDs.
- Retain identical duplicate counts in the shared grant preview; do not keep an old shard-conversion loop. Ascension must preserve one owned copy and commit inventory/equipment together. Do not reverse old shard conversions or discard historical stars.
- Snapshot tests need a real checkpoint. A snapshot saved without its checkpoint is correctly discarded on restart. Verify actual checkpoint -> hub edits -> separate-process Continue.
- DOT uses one bounded enemy child, cannot proc itself, and must not steal pending critical-hit feedback. Recheck passive ownership at tick time rather than scanning set catalog for every enemy every frame.
- Shared LESSONS.md and earlier publishers stay out of incremental patches. New lessons/publisher files avoid repeat git-apply context failures. Art-only/client-only changes need no unrelated schema deployment.
