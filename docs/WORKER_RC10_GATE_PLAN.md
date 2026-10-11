# Stage-only Worker entrypoint (source exists; not active)

The current `wrangler.toml` still points at `src/index.mjs` and all existing gates
remain false. The new `src/worker_entry_rc10.mjs` COMPOSES, rather than edits,
that existing handler and forwards payment/legacy routes unchanged. Its extra
paths are independently gated:

- `POST /v1/rtdn/voids`: signed Google Play OIDC Pub/Sub push. Requires
  `JADE_IAP_BACKEND_ENABLED=true`, `JADE_REFUND_RTDN_PUSH_RC9_ENABLED=true`,
  `JADE_RTDN_PUSH_AUDIENCE`, `JADE_RTDN_PUSH_EMAIL`,
  `JADE_RTDN_PUSH_SUBSCRIPTION`, working D1 and real Pub/Sub delivery.
- `GET /v1/wallet/trusted-progress`: authentic Firebase client READ ONLY.
  `JADE_TRUSTED_PROGRESSION_READ_ENABLED=true` gate, no stage issuance route.
- `GET /v1/wallet/summon-recovery-index`: account-scoped committed IDs only,
  `JADE_SUMMON_RECOVERY_INDEX_READ_ENABLED=true` gate.
- `GET/POST /v1/wallet/paid-loadout`: own server-owned equipment only,
  gated by `JADE_PAID_LOADOUT_READ_ENABLED`, `JADE_PAID_LOADOUT_WRITE_ENABLED`,
  `JADE_REFUND_RECONCILIATION_READY`, and parent IAP gate for writes.

All gates default to DISABLED even if their vars are absent. Do not switch
`main` to this file or set any flag as part of this package. Untrusted device
stage claims cannot be sent to this Worker to issue stages; the new RC10 signed
stage receipt processor is internal-only and requires genuine game-server
combat replay attestation.

`JADE_REFUND_RECONCILIATION_READY=true` must not be asserted until true Play
RTDN + overlapped Voided Purchases polling/backfill, monitoring, and debt policy
are verified. The scheduled() handler is NOT wired because access-token refresh
and schedule/backlog monitoring are still release blockers.

No production deploy, migration, purchase grant, activation, or Git write.
