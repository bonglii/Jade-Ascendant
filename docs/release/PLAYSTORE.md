# Jade Ascendant — current Play release handoff

Updated 25 October 2026. This replaces the obsolete offline-only/no-server/no-backup checklist. Read the current checkpoint and exact AAB evidence first; repository template versions are not the version installed through Play.

## Established release flow

1. Apply the latest portable batch; wait for every triggered workflow on the printed exact Git SHA to pass.
2. Close older Godot windows. Use `backend\player_identity\export_production.cmd` so the approved native candidate and source metadata are installed for the export session. Keep the terminal open and close that editor after exporting. If interrupted, run `recover_production_export.cmd` before another export; never erase its receipt manually.
3. Set the next unused Play version code in that editor and export a signed release AAB with **Export With Debug unchecked**. Do not replace the owner's local signing/version/export presets from a historical repository sample.
4. Upload that AAB. Confirm package `com.yungdevstudio.jadeascendant`, its actual version code, source SHA/native target in Settings support, Play App Signing identity and SDK/manifest findings.
5. Briefly verify the affected feature on the Play-installed build, saved progress after restart, ads and reward delivery. Reuse already-passed unchanged payment evidence; do not make repeat real-money purchases merely to satisfy an old checklist.
6. Review Console setup, pre-launch report and actual track eligibility. This source audit does not grant production access or replace Google review. Where the 12-tester requirement applies, it is **closed testing**, with 12 opted-in testers continuously for 14 days; an internal email list is insufficient. Retain actual feedback and fixes, not invented test reports.

## Current account, save and payment behavior

- Guest play and optional Google/Firebase sign-in exist. Permanent ordinary progression is stored locally by installation. Changing Google accounts does not automatically switch all local progression.
- Optional account-owned Cloud backup covers nine permanent domains, with explicit first save/restore, revisions and protected automatic updates. Run checkpoints and device settings are not part of it. Do not promise automatic cross-device continuation of an active run.
- Public UID belongs to the verified server account; nickname is display metadata. Paid Jade, paid gear, event authority and purchase recovery are server-owned, not restored by editing a local backup.
- Six Jade consumables use live Google Play product details. The production backend verifies purchases, credits idempotently, recovers interrupted delivery and reconciles Play voids/refunds. Pending/failed checkout must not grant Jade. Preserve all nine existing live protection gates; a refund hold is not solved by disabling them.
- Real non-tester purchase and restart were already reported successful by the owner. That evidence is distinct from a new AAB's build identity and new device observations.

## Ads, notifications and public pages

- Optional rewarded ads use separate Dice, Pavilion, Revive and General placements with applicable UMP consent. Rewards follow the actual placement's local or server-signed verification path; SDK callbacks alone do not authorize server-owned Dice/Trials bonuses.
- Android update notifications use an installation preference and FCM topic subscription after permission. Do not claim a notification was delivered merely because the dashboard accepted a send.
- Privacy policy: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/privacy-policy.html
- Account deletion: https://jade-ascendant-player.jade-ascendant-studio.workers.dev/account-deletion.html
- Support: yungdevstudio@gmail.com. Deletion is a verified support request, not an instant erase button. Check that both public pages work without an admin login and reflect the current generated policy before submitting their URLs.
- Optional telemetry remains subject to its existing rollout gate. Do not enable it as part of this cosmetic batch.

## Console facts the owner still verifies

Store listing/screenshots, target audience, content rating, ads declaration, Data safety (including actual Ads/Firebase/FCM SDK flows), App access/reviewer instructions, privacy/deletion URLs, country/device availability, IAP availability, signing identity and policy/pre-launch warnings. Use the uploaded AAB and current live Console; do not copy answers from obsolete local-only documentation.

Official references:
- https://support.google.com/googleplay/android-developer/answer/14151465
- https://support.google.com/googleplay/android-developer/answer/9859348
- https://firebase.google.com/docs/cloud-messaging/topic-messaging

No source-only audit can guarantee zero bugs, production approval or a release date.
