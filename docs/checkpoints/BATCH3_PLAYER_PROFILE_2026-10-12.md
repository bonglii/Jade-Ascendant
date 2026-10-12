# Batch 3: public player UID, name, and profile

Backlog #7 + #17. Patch base: Batch 2 local commit `a97d8b4`.

## Behavior

- A cryptographically generated 128-bit public UID is committed to `user://player_profile.save` before the UI exposes it. UID format: `JA-XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX`.
- Profile shows player name and UID, includes Copy UID, and supports inline Edit / Save / Cancel. Names accept 3–20 Unicode characters, start with a letter or number, and permit letters, combining marks, numbers, spaces, periods, underscores, apostrophes, and hyphens. Control/invisible/bidi characters and markup delimiters are rejected. Ordinary spaces are normalized; names do not claim global uniqueness.
- Player name updates the profile header; Lin Yue remains the character. New identity controls include English and Indonesian copy. Long names are constrained, stats remain scrollable, and the sheet follows the existing Home safe-area bounds.
- UID survives restart, rename, Google account UI changes, and new-run reset. Atomic SaveManager writes and backups protect the profile. Failed writes preserve the current name; corrupt/future profiles do not silently generate replacement UIDs. A validated backup can recover a corrupt or missing primary.
- Existing saves gain the separate profile file. Player progress, currency, equipment, and rewards are not migrated into it or reset.

## Identity boundary

This UID identifies this device's local profile. It is not a Firebase UID, access credential, proof of reward ownership, or registered server account. Signing into Google does not change it or activate Cloud Save. Clearing all local data or moving to another device without this profile file creates a different profile.

SaveManager adds a `local_profile` scope. The locked eight-domain permanent cloud contract remains unchanged. Firebase, Google authentication, monetization, IAP, and production/main are untouched. Server registration and authenticated public-UID mapping for targeted mail belong to Batch 4; client-entered UID alone must never authorize mail claims or rewards.

## Validation

- Godot 4.7.2 real runtime: 527 checks, zero failures. Covers name validation, 200 independent generated IDs, rename persistence, write barriers, reentrant callbacks, new-run reset, corruption/backup/future-version/interrupted-write cases, unchanged gameplay save bytes, and the real Home profile UI.
- Actual second process: 9 checks, zero failures for UID/name persistence.
- First launch over legacy progression and existing inventory: 10 checks, zero failures. Preserved 123456 Spirit Stones, vitality/sword/swift upgrades 4/3/2, and 17 refinement shards.
- Real OpenGL Compatibility render: 7 checks, zero failures. Inspected profile, editor, invalid input, maximum-width name, Indonesian controls, and shorter portrait layout. Verified exact clipboard content and the full UID fitting its label.
- Final runtime has no GDScript errors. The pre-existing shutdown diagnostic (four ObjectDB instances and two resources) remains in the UI smoke run.
- Android native keyboard, touch behavior, and physical notch placement still require phone review. Desktop rendering does not establish those device results.

## Delivery

Local commit and validated binary git patch only; GitHub writes remain unavailable. Apply after Batch 2. In Home, open Profile → Edit / Copy.

Next: Batch 4 admin dashboard and targeted mail/reward workflow (#13 + #23). The broader HP/economy/damage/VFX/weapon audit and additional ads remain scheduled after the backlog.
