# Jade Ascendant - IAP FastTrack handoff (2026-10-10)

This is a Git checkpoint, NOT a production release and NOT authorization to enable IAP.
The checkpoint includes current tracked edits and deletions (including release documents), and selected new source and tests. It excludes local secrets, private backups, save data, logs and temporary QA files.

## Confirmed status
- Remote production Worker is M10; IAP and paid wallet read remain disabled.
- Production D1 has `0001_iap_ledger.sql`; migrations `0002`-`0004` remain unapplied. A private D1 export backup was reported PASS; it is not in Git.
- M11-M14 source stages were reported PASS; M13 R1 backend 167/167 PASS.
- FastTrack RC1 local stage PASS: backend 184/184, Godot 15/15, Android Gradle/JUnit PASS.
- RC2 loadout is source-only, 200/200 backend tests in assistant environment, not installed or deployed. RC2 wrangler flag placement needs correction. Do not assume RC2 is included.

## Safety
- Godot SECURE_PURCHASE_ACTIVATION_APPROVED=false.
- Cloudflare JADE_IAP_BACKEND_ENABLED=false and paid wallet / recovery / purchase-v2 gates remain false.
- Keep hybrid wallet: earned/legacy jade and existing saves offline; purchased jade, paid items, and paid spending server-authoritative.
- Do not trust offline progression for paid summon eligibility. Do not duplicate paid items into inventory.save/equipment.save.
- Remaining work: trusted progression, paid item delivery and loadout integration, idempotent recovery, refund handling, real Play sandbox purchase and security checks.
- Never run production D1 migrations, deploy new Worker traffic, enable purchases, alter player saves, or merge/push more commits without user approval.

## Next conversation
Resume from this branch. Integrate RC2 and related work as ONE batch, minimizing repeated QA. Preserve save compatibility. Audit only risk-bearing changes.
User prefers CMD instructions, links for each Git commit, and requests for action only when necessary.