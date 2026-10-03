# Jade Ascendant — Cloud Restore UX Integration QA (Subphase E3B)

**Status while this patch is unverified:** HOLD
**Authority:** QA-only presentation integration above locked E3A.
**Production Firebase deploy / production restore:** NOT authorized.

## Purpose

E3B proves that the locked E3A restore UX state model can drive a real Godot modal/control surface without giving that surface save, network, or restore execution authority.

The surface consumes only the safe E3A view model. It renders masked owner identity, reviewed revision, abbreviated digest, informational snapshot time, aggregate counts, and eight safe per-domain states. It never renders raw save payload, full authenticated UID, candidate paths, `review_id`, local fingerprint, or full remote digest.

## Authority chain

```text
E1 safe review metadata
        ↓
E3A locked presenter/state model
        ↓
E3B QA-only Godot modal/control surface
        ↓
command_requested(command)
        ↓
external QA harness only
```

E3B does **not** call E1, E2, the registered restore engine, SaveManager, Firebase, Firestore, GoogleAccountManager, or the native Android bridge.

## Explicit restore interaction

```text
REVIEW_READY
  ├─ KEEP LOCAL
  │    └─ emits explicit KEEP_LOCAL decision command
  │
  └─ RESTORE CLOUD
       └─ RESTORE_CONFIRMATION_REQUIRED
            ├─ CANCEL -> REVIEW_READY
            └─ CONFIRM RESTORE
                 └─ emits RESTORE_CLOUD command bound by E3A
```

One RESTORE CLOUD tap never emits a mutation command.

After an externally supplied bound E2-style result:

```text
APPLIED_PENDING_CONFIRMATION
  ├─ KEEP RESTORED -> emits CONFIRM resolution command
  └─ ROLL BACK     -> emits ROLLBACK resolution command
```

The modal cannot be dismissed while state is `RESTORE_CONFIRMATION_REQUIRED`, `EXECUTING`, or `APPLIED_PENDING_CONFIRMATION`.

## Production boundary

This patch intentionally does **not** wire the surface into Settings, the Google Account card, an Android debug bridge, or a live account-bound endpoint. E3A remains CI/editor-only and locked. E3B is also CI/editor-only through disposable-runner environment gates.

A later phase may decide how a production-facing Settings/account entry point receives safe reviewed metadata. That requires a separate approval and must not weaken E1/E2/registered-restore authority boundaries.

## Acceptance evidence

E3B can be classified `PASS / LOCKED` only after its exact commit SHA has:

- source-boundary test PASS;
- official Godot 4.7.2 verification PASS;
- project import PASS;
- `JADE_CLOUD_RESTORE_UX_INTEGRATION_QA_TOTAL: <n> checks; 0 failures`;
- `JADE_CLOUD_RESTORE_UX_INTEGRATION_QA_PASS`;
- all other workflows triggered for the same exact SHA completed successfully.

Physical Android destructive restore QA is not required for E3B because this subphase changes no Android bridge, restore engine, bootstrap, process lifecycle, candidate semantics, or registered save mutation path.
