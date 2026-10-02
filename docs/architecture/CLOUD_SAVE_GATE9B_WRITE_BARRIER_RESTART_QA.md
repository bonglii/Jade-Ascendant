# Jade Ascendant — Gate 9B: Save write barrier + process-restart safety QA (Spark)

**Audited GitHub authority:** `bonglii/Jade-Ascendant`, branch `qa/cloud-save-gate2-ci`, commit `3a76e1e981f601d6f4161f2ea07827f012324d8f`.

Gate 9A proved that an isolated Godot 4.7.2 runner can create and verify a complete local eight-domain pre-restore vault without modifying source saves (`74 checks; 0 failures`, `JADE_GATE9_DISK_VAULT_PASS`). Gate 9B closes the next race: SaveManager writers must not change any primary, checkpoint, recovery target or transaction journal while a production pre-restore backup is being sealed.

This patch remains **Spark / NO DEPLOY / NO RESTORE**. It does not add a callable, Firestore rule, Firebase credential, billing dependency, upload route, restore route, UI button, automatic backup, purchase grant, or cloud mutation.

## SaveManager barrier

`SaveManager` now owns one process-local maintenance barrier with an exact owner token and reason. `begin_save_write_barrier()` refuses invalid tokens, an existing barrier, an in-flight batch, or a pending transaction. Only the exact owner can release it.

While active:

- `write_save_data()` fails before touching a domain.
- `write_save_batch()` fails before creating/replacing `transaction.journal`.
- `delete_active_run_save()` and `reset_active_run_saves()` fail before removing checkpoint artifacts.
- `recover_save_from_backup()` cannot rewrite a primary.
- recovery-on-read is disabled: a corrupt primary is reported rather than silently repaired from `.backup` while the barrier is held.
- `is_progress_read_only()` returns true, so existing higher-level economy/gameplay guards also stop progress mutations.

The barrier is intentionally **runtime-only**. A read-only backup should never leave a durable lock that can brick a player's next launch. A future actual restore will require a separate durable restore journal before the first local write; Gate 9B does not pretend that an in-memory barrier is sufficient for restore crash atomicity.

## Vault integration

The disconnected `CloudLocalBackupVault.prepare_local_pre_restore_backup()` now:

1. performs the existing identity, active-run, checkpoint, transaction and integrity preflight;
2. acquires an owner-scoped SaveManager barrier;
3. rechecks identity/gameplay/integrity under that exact barrier;
4. hashes and copies the eight permanent primaries plus existing `.backup` sidecars;
5. requires the same barrier owner immediately before the pending directory can become `ready_*`;
6. releases the barrier on every normal return from the copy operation.

If the barrier cannot be acquired, changes owner, or cannot be released, the operation fails closed. The resulting vault still reports `upload_allowed=false` and `restore_allowed=false`.

## CI / restart evidence

The Gate 9 Windows workflow keeps the existing real-file Gate 9A test and adds a separate `gate9_write_barrier_qa.gd` runner.

The **arm** process acquires the barrier, confirms all SaveManager mutation entry points are blocked, verifies progression/checkpoint fingerprints are unchanged, rejects a competing owner, writes only its own QA marker, and intentionally exits without releasing the barrier.

A second independent **verify** process must start with no barrier owner, reacquire/release a new barrier normally, then delete only its own QA marker. Expected markers:

- `JADE_GATE9_WRITE_BARRIER_ARM_PASS`
- `JADE_GATE9_WRITE_BARRIER_RESTART_PASS`

This proves process restart cannot inherit a stale process-local barrier. It is **not** an Android kill-9/fsync durability claim and is not a real restore test.

## Still required after Gate 9B

1. **Gate 9C — durable restore journal / whole-account rollback:** write a reviewed restore intent before touching any permanent primary; restore eight domains under one barrier; recover deterministically after process death at every rename phase; preserve the Gate 9A vault until explicit success confirmation.
2. **Android destructive QA:** debug-only disposable account/save fixtures, app process kill during every restore phase, relaunch recovery, offline interruption, storage pressure and upgrade-from-old-save cases.
3. **Restore UX:** explicit local-vs-cloud comparison, identity confirmation, no automatic first-login overwrite, active-run refusal, and user-visible rollback/failure state.
4. **Live trust gates:** Blaze test environment later, real Firebase Auth + App Check, server revision freshness, Google Play Developer API purchase verification/refund reconciliation, least-privilege IAM, budgets/alerts and reviewed Firestore rules.

**Gate 9B PASS criteria:** the new source-boundary tests pass, both Gate 9B process markers appear on the same commit, Gate 9A real disk vault remains green, `PERIKSA_GAME` remains `JADE_PHASE0_PASS`, Gates 5–8 Firestore regression remains green, and Firebase Auth/Functions emulator regression remains green. Passing Gate 9B does **not** authorize cloud upload, restore, or production deployment.
