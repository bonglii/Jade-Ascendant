# Refund polling release bridge — operational boundary

## What this development batch actually implements

Source-only integration over checkpoint `54168ac936acfdde380336687ba307172e168659`:

- `src/play_api.mjs`: the original Google Play client now exposes `listVoidedPurchasesPageRC7()` using the **same private service-account OAuth** mechanism as purchase verification and consumption; the fixed API adapter still bounds sizes, uses the in-app-only `type=0`, requests quantity-based partial refunds, and validates the host.
- `src/worker_scheduled_refund_rc11.mjs`: fail-closed `scheduled()` bridge to `runRefundCronJobRC7`. A disabled flag performs no work; a failed Play page/D1 operation propagates as a failed invocation, never as a green status.
- `src/worker_entry_rc10.mjs`: candidate-only Worker entrypoint now exports `fetch` and `scheduled`; `fetch` behavior is unchanged.
- `tests/worker_refund_schedule_rc11.test.mjs`: tests private OAuth with a temporary RSA key, scheduled orchestration, real SQLite-backed refund/hold/watermark, and partial-page failures.

The scheduling bridge **does not** change live `wrangler.toml`. The current production entry still points to `src/index.mjs` and has no cron trigger; nothing runs on the remote Worker because of this development package. This is intentional.

## Deployment prerequisites (NOT executed)

1. Integrate/resolve source conflicts against the actual Windows worktree; confirm every required `*.mjs` and migration in the overlay exists in one build. Check all trusted canonical summon changes against locally modified files. No force-overwrites.
2. Apply production D1 migrations `0002` through `0009` only after a private backup and explicit authorization, in their proper order. Do not execute them in this batch.
3. Validate `PLAY_SERVICE_ACCOUNT_JSON` access rights for the *real* Google Play Android Publisher API; the service-account JSON remains a Worker secret only.
4. Verify Pub/Sub RTDN signed delivery, Google Play list pagination, overlapping backfill, monitor alerts, and incident/hold release policy.
5. Only AFTER the above, configure the **candidate** Worker entrypoint and a reviewed hourly Cron Trigger (example `[triggers] crons=["0 * * * *"]`); explicitly gate job with `JADE_REFUND_CRON_JOB_RC7_ENABLED=true` after D1 and Play verification. Do not switch production Worker entrypoint or enable this gate as a part of this source package.
6. Do NOT treat `JADE_REFUND_RECONCILIATION_READY=true` as a substitute for evidence of fresh polling: the wallet credit guard checks the actual D1 watermark within a 2-hour window; stale/missing watermark fails closed.
7. Before enabling paid spend, separately verify refund freshness protection for **paid summon and equipment runtime**, not just wallet credits. Refund hold checks alone cannot substitute for monitoring freshness while notifications are unavailable.

## Remaining release blockers

- Independent **authoritative combat battle adjudicator** that issues receipts. Existing `VictoryManager` and `JourneyManager` persist client/offline progression and are NOT trusted proof of stages.
- Full Godot/Android transport, gameplay paid equipment cutover, recovery, and store purchase sandbox integration. Overlay contains contracts but not one compiled integrated Android build.
- Real RTDN/Google Play connection, D1 migration/deploy, alerts, two-device and refund sandbox QA, controlled activation with approval.

## What the 74/74 tests prove (and what they do not)

Test suite includes Google Play gateway mock RSA OAuth + Cloudflare D1-shaped SQLite adapter, refund reconciliation, wallet guard, signed RTDN test vectors and cron bridge. It verifies expected local logic under the mocks. It does **not** prove real remote Worker deployment, Android integration, Google Play API reachability, genuine RTDN delivery, live refund settlement, or production readiness.

## Important lessons

- A `scheduled()` method that is never selected by `wrangler.main` or never attached to a Cron Trigger is NOT an operational refund job.
- A backend function requiring an injected adapter is NOT integrated until the real service-account OAuth factory is wired.
- Real `D1Result.results` shapes matter; avoid over-optimistic mocked returns.
- Keep all production flags OFF and never merge paid and legacy save semantics just to make a test pass.

No user Windows files touched. No Git commits or pushes. No remote D1, Worker, Play Console or secrets touched.
