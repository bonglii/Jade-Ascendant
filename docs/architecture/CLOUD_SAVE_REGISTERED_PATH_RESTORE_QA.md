# Cloud Save — Registered Save Path Restore QA

Status: **DISPOSABLE-RUNNER QA ONLY / NO PRODUCTION RESTORE**

This layer is the bridge between the already-passed synthetic transactional restore protocol and a future production restore coordinator. It intentionally targets the exact eight permanent file paths returned by `SaveManager`, but only when all of the following are true:

- the process is an editor binary (`OS.has_feature("editor")`),
- `JADE_GATE9_TEST_ONLY=1`,
- `JADE_REGISTERED_RESTORE_TEST_ONLY=1`,
- `JADE_REGISTERED_RESTORE_ACK=DISPOSABLE_RUNNER_ONLY`.

Therefore Android debug/release exports and production release exports fail closed even if environment variables are supplied.

## What this proves

- the exact eight registered permanent primaries can be frozen behind the global SaveManager write barrier;
- a durable local preimage can be captured before mutation;
- candidate promotion can target the actual `SaveManager.get_save_path()` files;
- process restart can deterministically resolve partial commits to either the complete candidate or the complete preimage;
- rollback can itself be interrupted and later resumed;
- manual rollback after an applied state is restart-safe;
- existing `.backup` sidecars are not rotated or overwritten by cloud restore maintenance;
- active-run checkpoint presence and ordinary SaveManager transaction activity remain hard stops.

## What this does NOT prove or enable

- no Firebase deployment;
- no cloud-to-device transfer;
- no production restore UI;
- no automatic sync;
- no startup production recovery hook;
- no Android lifecycle / kill-process durability evidence;
- no permission to merge the QA branch to `main`;
- no production `restore_allowed=true` or `upload_allowed=true` path.

## Exit criteria for this layer

The dedicated GitHub Actions workflow must pass source-boundary checks, real Godot 4.7.2 import, exact registered-path apply/rollback/confirm restart tests, critical commit fault injection, interrupted rollback recovery, and interrupted manual rollback recovery. Existing Gate 9, PERIKSA_GAME, Gate 4.1 and Gates 5–8 must remain green on the same commit before the next integration step is accepted.
