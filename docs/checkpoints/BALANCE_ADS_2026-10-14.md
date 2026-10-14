# Balance and rewarded ads — 2026-10-14

Base: checkpoint/iap-fasttrack-20261010 / 9bbc4635876065212534015b9bbaa7b82c083e0d.

- Read-only export now covers all 26 encounters (Chapter 1 includes stage 6), 42 equipment, 8 sets, 32 weapon milestone rows. Instantiates the actual level_1 override off-tree: starting HP100, not the PlayerHealth fallback10. Player wallet/progression/loadout snapshots remain unchanged; sampler RNG restored.
- Body Refinement adds/heals 5 HP instead of 2; Blood Qi heals 2 instead of 1. Existing kill thresholds, equipment bonuses and max-health clamp retained. Choice effect strings derive from production constants.
- Pavilion optional rewarded ad grants one Seal: daily cap1, active-day-cycle cap7 (was3). Existing counters/IDs remain intact. Active days require all daily quests claimed; not seven calendar days. Daily policy uses UTC buckets.
- AdMob earned/dismiss/failure callbacks bind the exact show request ID. Stale callbacks cannot credit, close or destroy a subsequent ad. Duplicate earned credits once. Dismiss drains already queued callbacks for the same request before finalization; no earned means no payout. This is SDK callback/local durable policy protection, not activated server-side SSV.
- Existing UMP, debug test unit, release production-ID guards and load retry retained. Safe numeric load error/status traces added; Pavilion describes configuration/network/no-fill hints. Read-only USB diagnostic launcher does not clear logs or modify device settings.
- PowerShell launcher uses native SystemRoot executable and ExecutionPolicy Bypass. Publisher uses explicit fetch refspec, authorized branch/origin, scoped staging, ancestry/outgoing guards, no force push and verifies remote SHA before printing GitHub URL.
- No weapon damage, boss HP, rates/pity, summon prices, paid wallet/IAP gates, Google login or assets changed.

Validation: BALANCE_ADS_SMOKE 27 checks; COMBAT_SKILL_POLISH_QA 261 checks; SKILL_REFINEMENT_SMOKE 268 checks. Runtime audit exports 26/42/32 with PLAYER_STATE_UNCHANGED. Godot4.7.2 Linux headless. Baseline shutdown ObjectDB/resource warnings remain. Windows launchers source-reviewed; native Android SDK/ad availability not tested in this executor. Test debug APK on a phone before claiming live ads.

Recovery note: temporary QA tree and unpersisted Balance patch were lost across session interruption. Recovered authoritative current GitHub checkpoint into a separate worktree and rebuilt/retested this package. Earlier combat implementation already exists in GitHub. Fresh export replaces lost raw audit output; earlier damage-fixture notes are explicitly distinguished in the report.

Official ad callback reference: https://developers.google.com/admob/android/rewarded
