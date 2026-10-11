# Jade Ascendant — Playtest path: purchase-verified paid-only summon (STAGING)

**SOURCE ONLY. NOT INSTALLED. NOT A PRODUCTION ACTIVATION.**

## Product decision / why it reduces release risk

The existing Journey and Victory managers finish a battle offline and persist
`journey.save`. That file is not a server-authenticated battle receipt. Treating
its contents as authoritative would let modified device state unlock paid
spending. Building a full server-side battle simulation is a major gameplay
rearchitecture and is not a small IAP integration.

For the **separate paid-only summon action**, propose a product rule: a Firebase
account that has a confirmed, consumed Google Play purchase **already credited
by the trusted server wallet** can use the paid-only action, regardless of
its local Story progress. Normal/offline summon and all story gates remain
unchanged. This is a design choice, **not** an assertion that stages were cleared.

The paid-only resolver receives a **server-only boolean**. The HTTP request
contract still accepts **only** `{request_id, pull_count}`. No client field
can request or forge purchase eligibility. The curated pool comprises the
pinned chapter-0 pool plus stage 1-5 equipment, leaving canonical stage keys
unchanged. All later chapter-stage equipment still requires authoritative
progression, and the paid-only pool's catalog/rates need explicit design QA.

## Atomic enforcement

* Pre-check uses primary-consistent D1 read of `iap_wallet_events_v1` for a
  `play_credit` event owned by the signed-in Firebase account.
* The D1 canonical compare-and-swap repeats that predicate **in the same D1
  transactional batch** as wallet debit, canonical pity/inventory change,
  immutable outcome and request-index record.
* The existing refund hold predicate is applied regardless of which unlock
  policy is in effect. A false condition forces revision `-1`, violating
  the existing canonical table CHECK and rolling back the whole batch.
* Missing/invalid/pending purchase, unknown account, stale revision, held
  refund account, insufficient balance and broken database all fail closed.
* Existing saves and normal summon remain untouched; no stage completion
  marker is written as part of paid summon.
* `JADE_PAID_SUMMON_PURCHASE_UNLOCK_ENABLED` is **false** by default, and
  the Worker backend, paid summon write and refund readiness gates must
  independently be `true` before the policy can ever run.

## Source changes staged in this package

`backend/monetization/cloudflare/src/verified_purchase_unlock_rc14.mjs`
adds the verified credit read and atomic predicate. The reviewed, preflight-
only-by-default source integrator:

`patches/rc14_purchase_unlock_integration.py`

will edit `summon_canonical_stage.mjs`, `paid_summon_write_route_rc.mjs`,
`summon_trusted_resolver_stage.mjs`, and `wrangler.toml` **only** on the pinned
checkpoint with already installed RC3+RC5 source and unique expected anchors.
The changes are not applied to the user checkout, and the script is not a
standalone full IAP installer. No commits, deployments or D1 migrations.

## Focused verification, October 10, 2026

* Node 7/7 tests: purchase credit identity, fail closed, approval gates,
  provenance and refund separation.
* SQLite 6/6 invariants: valid credit, missing credit, other account,
  refund hold, stale CAS and patch-anchor checks. SQLite tests use a minimal
  harness, **not** Cloudflare production or the full canonical resolver.
* JS syntax and Python integrator compile pass locally.

## Remaining hard gates before charging real customers

1. Merge source patches with real Windows project and rebuild Android AAR/APK.
2. Confirm player-facing paid-only pool and game-economy disclosure; no
   confusion with offline stage-locked summon; verify rates and pity.
3. Deploy locked Worker to a non-production environment and migrate **staging**
   D1; run physical Play license-testing purchase and 2-device recovery.
4. Verify Google Play RTDN, refund sync, interrupted purchase and pending
   consumption states, with operational alarms and rollback procedure.
5. Only then backup production D1 and approve timed/migrated rollout;
   the release owner must approve turning IAP gates ON.

**Do NOT run `rc14_purchase_unlock_integration.py --apply` yet.** Existing user
checkout has RC2.1 FIX2 only confirmed, not RC3/RC5. Additional staging
integrations must be consolidated before any Windows-side installation.
