# Cloud Account-Bound Read Client Contract — E3C-A

Status: pre-activation production-shaped client contract / QA proof only.

E3C-A defines the device-side contract that a future approved account-bound read endpoint and native bridge must satisfy. It intentionally does **not** activate networking, native bridge methods, Settings UI, backend callable exports, Firebase deployment, candidate staging, restore execution, or cloud mutation.

## Why E3C is split

The currently locked server transport is emulator-only and reads synthetic Gate 6 QA collections. The current production native bridge exposes only the previously approved read-only capabilities callable. Inventing production collection names or silently exporting a new callable here would cross the E4 deployment/approval boundary.

Therefore:

- **E3C-A** locks the reusable production-shaped client transport/state contract.
- **E3C-B** may later add the fixed native callable method and physical-device proof after E3C-A is locked.
- **E4** remains the approval boundary for the real backend source, callable export/deployment, packaged release AAR replacement, and production enablement.

## Manual request contract

A read begins only through an explicit manual call to `begin_manual_request(authenticated_uid)`.

The emitted command is fixed:

- action: `REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT`
- client payload: `{}`
- no UID argument
- no revision argument
- no digest argument
- no economy/purchase values
- no restore operation claim
- no automatic boot/sign-in request

The authenticated UID is retained only as an in-memory binding so an asynchronous native result can be rejected if the account changes.

## Future production transport envelope

A successful future native read must deliver exactly one JSON envelope containing:

- `ok=true`
- `code=ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY`
- transport contract version 1
- authenticated owner binding
- positive remote revision
- canonical SHA-256 digest
- exactly the eight permanent domains
- the full permanent draft
- server revision verification
- server freshness verification
- explicit restore decision required
- `restore_allowed=false`
- `cloud_mutation_enabled=false`

The account-bound client contract revalidates the full permanent snapshot contract and recomputes the canonical digest before accepting the transport.

## UI-safe boundary

`get_safe_status()` exposes only payload-free metadata:

- masked owner display
- remote revision
- abbreviated digest
- capture timestamp
- domain count
- server verification flags
- explicit-decision-required flag

It never exposes the full UID, full digest, `draft`, domain payloads, candidate paths, review bindings, or any execution authority.

## Internal raw handoff

A validated raw transport may leave the object only through `take_validated_transport_for_internal_handoff(current_authenticated_uid)`.

That operation:

1. rechecks the live account binding;
2. is available only after full transport validation;
3. is one-shot;
4. clears the in-memory raw transport immediately;
5. marks the result `internal_only=true`, `ui_safe=false`, and `raw_payload_included=true`;
6. still keeps upload, restore, cloud mutation, and production execution disabled.

E3C-A itself never stages candidates and never calls E1, E2, the registered restore engine, SaveManager, Firebase, Firestore, HTTP, or a native singleton.

## Fail-closed states

- `ENDPOINT_NOT_ENABLED`: future native layer reports the callable is not deployed/enabled.
- `NO_SNAPSHOT`: authenticated account has no approved current snapshot.
- `UNAVAILABLE`: auth/App Check/network/native availability prevents a read.
- `ERROR_FAIL_CLOSED`: unknown status, account change, malformed transport, owner mismatch, invalid digest/domain set, missing server verification, or unsafe flags.

No failure state performs a retry automatically and none can trigger restore.

## Explicitly still locked

E3C-A does not approve or implement:

- Firebase production callable export/deployment;
- production Firestore collection/schema choices;
- production Cloud Save upload/write;
- automatic restore or cloud-wins;
- packaged release AAR replacement;
- native account-bound snapshot method;
- production Settings restore UI;
- candidate staging to registered save paths;
- E2 production execution.
