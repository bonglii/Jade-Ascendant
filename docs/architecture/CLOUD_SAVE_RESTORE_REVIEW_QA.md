# Cloud Save — Restore Review Contract QA (Subphase E1)

Status: **QA ONLY / REVIEW-ONLY / NO PRODUCTION RESTORE**

This layer sits between the already-locked account-bound candidate staging path and any future restore execution UI. It deliberately does **not** call the backup vault, write barrier, registered-path restore engine, Firebase, Android native bridge, or any production UI.

## Purpose

A cloud candidate must not become a restore action merely because it is valid. Before any mutation is even eligible, the client needs a reviewed decision model that can tell the player what was verified without exposing raw save payloads or silently preferring cloud state.

The E1 contract therefore produces only:

- verified owner binding plus a masked owner display string;
- remote revision;
- remote snapshot digest;
- remote capture timestamp;
- exact permanent domain count (`8`);
- one safe state for each domain: `SAME`, `DIFFERENT`, `LOCAL_MISSING`, or `LOCAL_INVALID`;
- counts/lists of same, changed, missing, and invalid domains;
- an opaque local-state fingerprint and review id for future stale-review detection;
- explicit decision options: `KEEP_LOCAL` or `RESTORE_CLOUD`;
- whether the current eight local primaries and optional backup sidecars are valid enough for the already-locked durable preimage backup stage;
- whether any per-domain `.tmp` / `.rollback` artifact makes that future preimage source unsafe.

It never returns raw domain dictionaries, inventory contents, economy values, grant identifiers, or local per-file hashes as UI data.

## Fail-closed rules

The review rejects:

- foreign authenticated owners;
- a candidate record that has not already passed controlled-transfer inspection;
- mismatched revision/digest between the inspected record and durable candidate manifest;
- candidate paths outside the exact immutable ready directory;
- candidate schema/hash/size/content mismatches;
- any candidate set that fails the full eight-domain snapshot contract or canonical digest recomputation;
- any incoming flag that claims restore/upload/cloud-mutation authority;
- a permanent registry other than the locked eight domains.

Local missing or invalid primaries do **not** make the review disappear. They are surfaced as safe status values, while `preimage_source_files_ready=false` and `execution_preconditions_met=false` ensure a later execution layer remains blocked until a durable preimage can be guaranteed. E1 never claims to have checked transient gameplay/write-barrier guards; `preimage_runtime_guards_checked=false` is explicit.

## Authority boundary

Every successful review still returns:

- `restore_allowed=false`;
- `upload_allowed=false`;
- `cloud_mutation_enabled=false`;
- `execution_allowed=false`;
- `execution_preconditions_met=false`;
- `preimage_runtime_guards_checked=false`;
- `preimage_backup_required=true`;
- `decision_required=true`.

No production scene, autoload, settings screen, or account card references this QA manager. The dedicated workflow intentionally does **not** arm Gate 9 or registered-restore environment variables.

## Exit criteria for E1

E1 may be called PASS / LOCKED only when the dedicated workflow proves on Godot 4.7.2 that:

1. exact reviewed candidate metadata is preserved;
2. local-vs-cloud domain status is deterministic;
3. full local primary + sidecar fingerprints remain byte-identical across review;
4. foreign owner, unsafe flags, digest mismatch, and candidate path escape fail closed;
5. missing/invalid local primaries are surfaced while future execution is blocked;
6. no raw save payload appears in the review result;
7. all existing cloud/save regressions remain green on the same exact commit.

Passing E1 does **not** authorize production restore. The next step is Subphase E2: an explicit decision coordinator that revalidates the review, captures the durable preimage first, invokes the already-locked transactional restore engine, and presents explicit confirm/rollback semantics. Production Firebase deployment remains a separate approval boundary.
