# Crowd performance pass 1 — 2026-10-13

Google login is deliberately skipped per user instruction; menu performance is acceptable on their phone. This pass optimizes combat queries and prepares meaningful on-device profiling without changing population, HP, damage, XP, attack cadence, collision radius, enemy AI or assets.

Changes:
- Nearest-target lookup rejects out-of-range candidates before dynamic is_dead/method checks. Existing ordering, dead/queued exclusion, ties and boss range remain.
- Returning Glaive adds an exact padded segment bounding box before narrow collision checks, skips a phase hit already recorded, and uses squared distance comparisons. Live positions/group membership are read at the time of query; no delayed spatial cache or disabled physics.
- Existing debug CombatPerf remains every 12 active seconds. New CrowdPerf adds bounded wall-frame mean/P95/max, >33.33ms and >50ms counts, process/physics mean and physics maximum, plus latest draw calls/collision pairs/hostile group count. Pause/unpause clears the wall-clock baseline to avoid counting deliberate pause as a stutter. No player IDs/tokens are logged.
- Frame storage caps at 4096 samples. Mean/max/counts cover the entire window; if over capacity P95 covers the most recent 4096. Process and physics are engine CPU monitor values; draw calls are not GPU duration. Hostile count is only enemy_attack group membership, not an authoritative count of every projectile kind.

Evidence:
- 278 new checks passed: 805 candidates across 90 deterministic swept/point queries, reference contact ordering, same-phase repeat protection, old/new nearest target equivalence, exact tangent/boundary fixtures and bounded statistics/reset.
- On the fixed 805-candidate microbenchmark, status reads fell from 805 to 2; 100 sweeps measured 103250 us before and 18363 us after. This benchmark measures a controlled query workload, not overall gameplay FPS or Android latency.
- Returning Glaive: 66 checks; Mastery: 65 checks; premium combat: 472 checks. Total with new tests: 881 checks passed. Expected negative victory-fixture diagnostics remain in the Mastery suite.
- Native X11/OpenGL software-rendered Stage 1 probe with 120 live actors produced CombatPerf/CrowdPerf and completed without script errors. Its FPS is not a phone/laptop performance claim. The isolated probe freezes attack timers to avoid level-up pause, prevents death, and never ships artificial health/spawn settings. Native render was inspected.

Player follow-up: import and re-export a debug Android build, play the same stage/loadout until enemies are crowded, then collect at least 3 paired CombatPerf/CrowdPerf samples (roughly 36 active seconds). From the project run backend/player_identity/collect_crowd_performance.cmd. The collector reads existing logcat; it does not clear logs or modify the phone. Need real phone data before deciding whether the remaining cost is physics, scripts or rendering, or claiming a device FPS improvement.

No backend deployment. The protected publish_crowd_performance.cmd publishes the checkpoint and prints a verified GitHub commit link; main and parked IAP remain unchanged.
