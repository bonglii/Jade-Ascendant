# Jade Ascendant — Cloud Restore UX Presenter QA (Subphase E3A)

**Status target:** QA-only contract. E1 and E2 remain locked authorities.
**Production deploy:** not authorized.
**Production UI wiring:** not part of E3A.

## Purpose

E3A adds a pure presentation/state contract between the already-reviewed restore metadata and a future user-facing Settings/account flow. It does not read candidate files, read or write registered saves, capture a backup, call restore authority, perform network I/O, or deploy Firebase resources.

The presenter consumes only safe review metadata: masked owner display, revision, digest metadata, capture timestamp, eight domain status values, summary counts, opaque binding values, and safety flags. Raw save payloads, full account UID, candidate paths, economy values, inventory contents, and grant identifiers are rejected or never rendered.

## Locked authority boundaries

- E1 remains the authority for safe restore review semantics.
- E2 remains the authority for execution-time revalidation and explicit restore execution.
- The registered restore engine remains the only disk mutation authority.
- E3A only formats safe metadata and sequences explicit user intent.
- No existing E1, E2, registered-restore, Settings, account-card, or project-autoload file is modified by E3A.

## State model

`NO_CANDIDATE`
→ `REVIEW_READY`
→ user may choose **KEEP LOCAL**, or choose **RESTORE CLOUD**
→ restore choice enters `RESTORE_CONFIRMATION_REQUIRED` with **no execution command**
→ explicit second confirmation emits a review-bound `SUBMIT_REVIEW_DECISION` command
→ a validated E2 applied result enters `APPLIED_PENDING_CONFIRMATION`
→ user must explicitly choose **KEEP RESTORED** or **ROLLBACK**
→ terminal state is `USER_CONFIRMED_RESTORED` or `USER_ROLLED_BACK`

Any binding or safety mismatch enters `ERROR_FAIL_CLOSED`. No automatic restore, automatic confirmation, cloud-wins default, or timestamp-based freshness decision exists.

## Safe view model

The view may display:

- masked account identity only;
- remote revision;
- abbreviated digest only;
- snapshot capture timestamp as informational metadata only;
- exact domain count of 8;
- safe per-domain status: `SAME`, `DIFFERENT`, `LOCAL_MISSING`, `LOCAL_INVALID`;
- summary counts;
- explicit action availability for the current state.

The copy deliberately avoids treating capture time as evidence that one copy should win. The timestamp note instructs the user to compare domain status before choosing.

## Restore action guard

The restore choice is shown only when the reviewed metadata reports:

- at least one `DIFFERENT` domain;
- zero local preimage issues;
- all preimage source files ready.

This is only a UX guard. It is not restore authorization. E2 must still revalidate the review, local fingerprint, candidates, backup, runtime guards, and execution intent before mutation.

## E3B handoff

E3B may wire the presenter into the existing Settings/Google account card and reuse current modal/overlay styling. The UI controller must route presenter commands to E2 without adding a second save writer or restore implementation.

E3B must also define restart/resume presentation for any durable E2 session that is already `APPLIED_PENDING_CONFIRMATION` before production-facing UI can be considered complete.

## Still prohibited

- Firebase production restore deployment;
- production cloud write enablement;
- automatic or silent restore;
- cloud-wins behavior;
- full UID display;
- raw save payload rendering;
- direct UI save writes;
- merging QA to `main` by default.
