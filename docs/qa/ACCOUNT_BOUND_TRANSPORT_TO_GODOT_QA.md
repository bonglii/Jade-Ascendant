# Account-Bound Transport -> Godot Candidate QA

Status: QA-only / disposable CI / no deploy / no restore.

This subphase proves that the exact current account-bound record produced by the localhost Firestore emulator can cross a serialized transport boundary and become durable isolated Godot candidate files without modifying registered player-save primaries.

## Flow

1. A localhost DEMO Firestore emulator is seeded only with synthetic Gate 6 QA state.
2. The already-reviewed account-bound read transport derives owner from synthetic Firebase-style auth context and reads the exact current revision.
3. The transport record is serialized as one short-lived GitHub Actions artifact.
4. A separate Windows job downloads exactly that one artifact.
5. A QA-only Godot adapter validates the complete transport envelope, server revision/freshness flags, exact 8-domain set, owner binding, digest, and full local snapshot contract.
6. Only after that validation does the adapter normalize the record into the already-locked controlled-transfer stager input shape.
7. The existing controlled-transfer stager revalidates draft and digest and writes candidates under its isolated QA namespace.
8. The runner proves registered permanent primaries are unchanged before, during, after reopen, and after QA candidate cleanup.

## Locked boundaries

- No production callable export.
- No Firebase deployment.
- No production Firestore reads or writes.
- No cloud upload/write endpoint.
- No client-supplied owner authority.
- No raw Play token transfer.
- No automatic restore.
- No cloud-wins rule.
- No transactional restore engine invocation in this workflow.
- `restore_allowed=false` and `cloud_mutation_enabled=false` remain mandatory.
- The existing controlled-transfer stager and registered restore engine are not modified by this patch.

## PASS marker

`JADE_ACCOUNT_BOUND_TRANSPORT_TO_CANDIDATE_QA_PASS`

This proves transport -> Godot candidate staging only. It does not prove an Android network bridge or production restore authorization.
