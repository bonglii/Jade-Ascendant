# Jade Ascendant — Safe transactional / reversible restore path (synthetic disk stage)

Authority audited before this patch: `qa/cloud-save-gate2-ci` at `2cdbaf3de96a811c0b6c7f61ae9529dc21636935`.

This stage is deliberately **QA-only / NO PRODUCTION RESTORE / NO DEPLOY / NO CLIENT TRANSFER**. It does not wire a restore button, Firebase callable, automatic sync, SaveManager production restore entry point, or real-player save mutation.

## Why a separate durable restore protocol is required

`SaveManager.write_save_batch()` is a roll-forward gameplay transaction: its journal stores final target values and startup recovery completes those writes. That is correct for idempotent local commits but is the wrong failure semantic for a cloud restore, where the complete pre-restore account state must remain recoverable after any partial write.

Gate 7 already proved the state-machine invariants in RAM. Gate 9A provides a durable eight-domain preimage vault. Gate 9B prevents normal SaveManager writers from racing a maintenance operation. The missing building block is a durable restore intent whose restart recovery can determine disk state without trusting an ambiguous progress counter.

## Locked transaction model

The synthetic engine uses an immutable durable intent plus marker files:

1. `PREPARED`: candidate and Gate 9A preimage are validated; intent is durable; no primary has been touched.
2. `COMMITTING`: commit marker is durable before the first primary rename.
3. `APPLIED_PENDING_CONFIRMATION`: all eight live primaries exactly match the candidate hashes; the Gate 9A vault is retained.
4. `CONFIRMED`: same-account explicit confirmation succeeded; the vault is still retained here and only becomes eligible for a later retention policy.
5. `ROLLED_BACK`: all eight live primaries exactly match the pre-restore hashes.

There is intentionally no per-domain `last_completed_index` authority. A process can die after a rename but before an index update. On restart, the engine instead compares all eight live primary hashes with the immutable intent:

- all eight candidate hashes -> promote to `APPLIED_PENDING_CONFIRMATION`;
- any partial/missing state after commit started -> restore all eight preimages from the Gate 9A vault;
- any state that cannot be proven from the intent/vault -> fail closed.

## Disk replacement primitive

Each synthetic primary replacement uses a transaction-specific staging sidecar:

`primary -> .restore.rollback`

`.restore.tmp -> primary`

and verifies the final SHA-256 before deleting the temporary rollback sidecar. Recovery does not depend on that sidecar: the Gate 9A ready vault is the account-level durable preimage authority.

Rollback itself is idempotent and uses a separate recovery staging/discard pair. If a future QA process dies during rollback, the same immutable vault can be replayed again on the next restart.

## Fault matrix required before this stage can PASS

Critical process-restart points:

- after durable intent, before commit marker;
- after commit marker, before first domain;
- after candidate temp write;
- after primary -> restore rollback rename;
- after candidate -> primary rename;
- after each completed domain;
- after all eight primaries but before applied marker;
- after applied marker;
- during rollback temp write;
- during rollback target -> discard rename;
- during rollback preimage -> primary rename;
- after rollback cleanup.

The first implementation should exercise the highest-risk cross-process points on Windows CI. The matrix must be expanded before any production SaveManager adapter is introduced, and Android destructive QA remains mandatory afterward.

## Safety boundaries

- test-only namespace remains `user://jade_gate9_qa/`;
- the production SaveManager registry is read only for domain metadata;
- no production save path is accepted by the synthetic API;
- checkpoint is excluded;
- the Gate 9A ready vault remains intact through apply, restart recovery, rollback and confirmation;
- confirmation does not delete the vault;
- `upload_allowed=false` and `restore_allowed=false` remain explicit outputs;
- production Cloud Save upload/restore, automatic sync, live Firestore writes and live Play purchase handling remain locked.

## Exit criteria for this stage

This stage may be called PASS only when the real Godot disk/restart runner proves no mixed eight-domain state survives recovery at the tested fault boundaries, manual rollback exactly restores the preimage, confirmation is same-account and durable, existing Gate 9A/9B remain green, Gates 5–8 remain green, and `PERIKSA_GAME` remains green on the same commit.

Passing this stage still does **not** authorize production restore. The next integration step is a separately reviewed SaveManager-owned privileged restore adapter plus Android destructive lifecycle testing.
