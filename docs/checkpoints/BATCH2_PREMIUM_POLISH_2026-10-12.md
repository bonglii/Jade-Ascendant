# Batch 2: tutorial, Lin Yue, and Chapter 1–3 boss presentation

Dependency: apply Batch 1 first (local base `1e507c3`). This batch closes presentation work for backlog items #14, #15, and #16, pending Android device review.

## Visible changes

- Five illustrated tutorial pages, larger typography, progress markers, adaptive cards, modal backdrop, and a compact gameplay objective. Stage 1–1 Pause includes Tutorial Guide for players who already completed onboarding; reviewing it preserves save completion, level, and XP.
- Lin Yue receives a silhouette rim shader, stronger sprite scale, movement/cast poses, foot shadow, bounded trails and footstep accents, and feedback from actual damage. Existing character art, paid auras, and cultivation layers remain in use.
- All 16 boss encounters across Chapters 1–3 receive realm/stage presentation profiles, body ornamentation, arrival/cast/phase feedback, readable themed boss headers, and visual defeat remnants. Crimson attack styling now receives its correct presentation theme.
- Realm-colored projectiles, attack-radius telegraph markings, lightning branches, and shockwave accents follow actual attack timing. Reduced Effects suppresses trails and reduces motion/drawing frequency. Additional hostile visual nodes are capped at 64.

## Validation

- Godot 4.7.2 isolated runtime smoke test: 472 checks, zero assertion failures. Includes tutorial progression and optional review, pause ownership, player damage feedback, all 16 bosses, unsupported profiles, visual limits, and reduced effects.
- Source parity review: 51 untouched combat functions; boss/attack exported values and player controller remain unchanged. HP, damage, collision, rewards, movement authority, attack timers, and tutorial progression requirements were not rebalanced.
- Real OpenGL Compatibility rendering inspected before/after tutorial and staged Chapter 1–3 boss/attack presentations. The comparison fixtures use the first chapter arena; they do not represent Chapter 2–3 map redesigns.
- No GDScript or shader errors in the final game render. The baseline shutdown diagnostic (four ObjectDB instances and two resources) remains; this batch does not claim to fix it.
- Android touch, GPU performance, and device layout remain to be reviewed on the user's phone. Desktop rendering and runtime checks do not establish mobile FPS.

## Delivery and next work

GitHub publication remains unavailable: git credentials are absent and the connected integration denies tree creation. The deliverable is a locally validated patch, not a published branch.

Next backlog group: player ID, profile, and name (#7 + #17). HP/economy/damage/VFX/weapon balance assessment and additional ads remain queued after the requested backlog. Production/main and parked IAP work are outside this batch.
