# Batch 1 — Mailbox + Skill Book

Date: 12 October 2026
Branch: `checkpoint/iap-fasttrack-20261010`
Patch base: local `ca8da04` (Seven Days Login patch applied).

## Authorized grouping and follow-up

Developer approved batching related work, starting with #22 Mailbox and #20 Skill Book, and requested efficient execution with minimal commentary. #6/#12 were confirmed safe on device. #9 implementation is complete; its device confirmation has not been supplied in this thread.

After the remaining development backlog is completed, developer requests an assessment of HP, economy, damage, VFX, weapons and related balance, plus additional advertising integration. Keep that follow-up after the backlog; do not introduce ad placements or rebalance combat in this batch. IAP remains parked.

## Mailbox (#22)

- Adds DELETE MESSAGE, enabled only for notices without attachments or rewards already claimed. Unclaimed attachments cannot be lost through deletion.
- Stores deletion tombstones in the existing Pavilion ledger. Claim markers are retained; deleted IDs cannot replay rewards or resurrect on restart.
- New catalog deliveries need new immutable mail IDs. This remains the existing local catalog; no server inbox/admin/reward endpoint is introduced.
- Opening the inbox marks only the displayed letter read. Other letters keep unread status until selected.
- Home badge counts each letter needing attention once (unread or unclaimed). A read/unclaimed reward plus a different unread notice correctly counts as two letters.
- Selection, empty state, scroll preservation and delete availability refresh from LiveOpsManager.
- Mail reward mutations have an in-flight lock. Reentrant mail/login claims, reads/deletion ledger writes and activity updates cannot overwrite the current mail transaction's snapshot during reward callbacks.
- Catalog integrity audits explicitly include deleted letters; restart audits still validate the full catalog rather than treating hidden letters as missing definitions.

## Skill Book (#20)

- Home live-ops rail includes SKILL BOOK (scroll the rail if needed). It opens a standalone safe-area-aware page with Home/Android Back navigation.
- Lists all 18 run upgrades, using existing skill artwork and jade/gold UI styles.
- Provides search and All/Weapons/Passives/Synergies filters, readable descriptions and requirements for all three resonances.
- Names/descriptions/icons/order/weapon and resonance classification and six prerequisite levels move into `scripts/data/skill_catalog.gd`. LevelUp delegates to the same catalog; descriptions and requirements cannot drift independently between the book and upgrade menu.
- Documents temporary run skills versus permanent HERO equipment. Synergies still need to be selected from an eligible level-up offer; meeting prerequisites is not presented as an automatic unlock.
- No damage, health, stat increments, drop rates, upgrade effects or weapon behavior are changed.

## Validation

Official Godot `4.7.2.stable.official.ed1daf0bf`, isolated caches/user saves, actual managers and scenes.

- `tests/mailbox_skill_book_smoke.gd`: 153 assertions, 0 failures. Includes deletion policy, exact reward delta, duplicate/reentrant denial, read-only rejection, persistence, badge/read state, all 18 entries/assets, all filters, search/empty results, width containment at 648/720/1080 px windows, and Home → Skill Book → Home navigation.
- Separate process mail restart: 3 assertions, 0 failures (`-- --verify-mail-restart`).
- New catalog letter fixture in a disposable project: PASS; old deleted letters remain hidden/claimed, new immutable ID is unread and selectable. No fixture content is shipped.
- Seven Days Login regression after shared-ledger guard changes: 364 assertions, 0 failures.
- 65 unchanged LevelUp function bodies match the prior source byte-for-byte after whitespace trimming. Original name/description bodies match their shared catalog copies. Six prerequisite values remain unchanged.
- Actual rendered screenshots inspected using Godot OpenGL compatibility with software rendering/Xvfb: Mailbox, Skill Book overview, three synergy cards, and Home. Text/controls fit at 648×1152; no clipping or overlap observed in the new controls. This is desktop rendering QA, not a physical Android pass.
- `git diff --check` and patch apply checks pass.

The expanded tests can emit shutdown cleanup diagnostics (4 ObjectDB instances/2 resources still in use). Running the same login regression against the preceding source produces the same diagnostics. This baseline cleanup issue is recorded; assertion success is not a claim of a completely warning-free full-game run. No GDScript parse/runtime exceptions in final regression logs.

Run test scripts only in a disposable QA project with user:// isolated before autoload initialization. The Batch 1 test requires its data path to contain `jade_batch1_qa`; use a fresh directory for the main run and reuse it for `--verify-mail-restart`. QA-only Firebase UID resolution and disabled editor plugins are not production project edits.

## Delivery and next batch

Changes are committed locally. GitHub remains read-only for this session (terminal lacks push credentials; integration denied writes with 403), so no published commit URL is claimed. `Jade-Ascendant-Batch1.patch` applies after the earlier Login Cycle patch; check before applying, and do not use --reject/force to ignore conflicts.

No main/production/backend changes. Physical Android approval of new Mailbox/Skill Book controls remains pending.

Next authorized batch: #14 tutorial + #15 main character + #16 boss Stage 1–3; begin with asset/animation/VFX audits and preserve combat readability/performance.
