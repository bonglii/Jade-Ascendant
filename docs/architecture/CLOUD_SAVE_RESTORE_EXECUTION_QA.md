# Cloud Save — Explicit Restore Execution QA (Subphase E2)

Status: **DISPOSABLE-RUNNER QA ONLY / NO PRODUCTION RESTORE / NO DEPLOY**

Subphase E1 proved a read-only review contract. E2 adds the next authority boundary:
an explicit reviewed decision can enter the already locked registered-path restore
engine only after the review is revalidated against current disk state and a
durable preimage has been captured.

This layer is deliberately not wired to Settings, startup, Android production
exports, Firebase, or any automatic sync path.

## Authority order

The only accepted restore execution sequence is:

1. rebuild the E1 review from the durable candidate set and current local files;
2. require the presented `review_id`, local fingerprint, remote revision and
   remote digest to match that rebuilt review;
3. accept exactly one explicit decision:
   - `KEEP_LOCAL` — terminal no-op, no backup and no save mutation;
   - `RESTORE_CLOUD` — continue only when the local source files are safe;
4. copy the already-reviewed candidate bytes only into the registered restore
   harness's QA candidate namespace;
5. call the locked registered-path restore engine to capture a durable preimage;
6. rebuild E1 review again and require the same review/fingerprint after backup;
7. write a QA-only durable execution intent that binds the exact `review_id`;
8. call the locked registered-path restore engine;
9. require `APPLIED_PENDING_CONFIRMATION`;
10. accept exactly one explicit terminal resolution:
    - `CONFIRM`;
    - `ROLLBACK`.

The coordinator never calls a public SaveManager write API and never writes a
registered live save path itself. All live mutation remains owned by
`cloud_registered_path_restore_qa.gd`.

## Fail-closed cases

E2 rejects execution when, among other cases:

- the account owner is invalid;
- the decision or terminal resolution is unknown;
- the presented review is stale or tampered;
- the local fingerprint changes after review;
- E1 reports missing, invalid, unsettled, or unsafe preimage source files;
- all eight local domains already match the reviewed cloud candidate;
- candidate handoff cannot be verified byte-for-byte;
- durable preimage capture fails;
- local state changes between preimage capture and apply;
- the execution intent cannot be persisted;
- the restore engine does not reach `APPLIED_PENDING_CONFIRMATION`;
- a terminal decision is attempted with the wrong `review_id`;
- rollback is requested after confirmation, or confirmation after rollback.

## Durable binding

A QA-only execution session lives under:

`user://jade_restore_execution_qa/`

Its intent records the account owner, review id, local-state fingerprint,
candidate ready path, remote revision/digest, domain count, and the explicit
`RESTORE_CLOUD` decision. This record is not cloud authorization and cannot
enable production restore.

The registered-path restore engine remains the authority for its own durable
transaction phases and preimage vault.

## Still locked

Passing E2 does **not** authorize:

- production Firebase deployment;
- production Cloud Save reads/writes;
- automatic restore or cloud-wins;
- a production restore button;
- release-build restore;
- Google Play production verification;
- deletion of the retained restore vault;
- merge to `main`.

Every result continues to expose:

- `upload_allowed=false`;
- `restore_allowed=false`;
- `cloud_mutation_enabled=false`;
- `production_execution_allowed=false`.

Those flags mean the QA proof does not grant production authority, even when the
disposable runner intentionally exercises the locked restore engine.

## Exit criteria

E2 may be marked PASS / LOCKED only when, on the exact same commit:

- source-boundary tests prove the coordinator is QA-only and disconnected;
- E1 and registered-path source boundaries allow exactly this coordinator as
  their sole script-level bridge;
- Godot 4.7.2 imports the production project;
- the E2 runner proves:
  - `KEEP_LOCAL` mutates zero live bytes;
  - stale/tampered review rejection occurs before backup/mutation;
  - durable preimage precedes restore apply;
  - apply reaches `APPLIED_PENDING_CONFIRMATION`;
  - wrong review id cannot resolve the transaction;
  - explicit rollback restores the exact preimage;
  - explicit confirm keeps the exact candidate state;
  - existing `.backup` sidecars remain byte-identical;
  - terminal decisions release the SaveManager write fence;
  - same terminal confirmation is idempotent and opposite terminal decisions
    are rejected;
- the dedicated marker is emitted:

`JADE_CLOUD_RESTORE_EXECUTION_QA_PASS`

All previously locked cloud/save regressions must remain green on the same SHA.
