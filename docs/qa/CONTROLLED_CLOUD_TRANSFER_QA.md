# Controlled Cloud Transfer QA

Status: **STAGING-ONLY QA**. Production cloud upload/restore, automatic sync, cloud-wins replacement, Firebase production writes and QA-to-main merge remain locked.

This phase begins only after the registered-path transactional restore engine passed the physical Android destructive suite (10/10 cases, 110 checks) at `f20a694fb2af143f31a8225760aff144bfdd8013`.

## Purpose

Prove the boundary immediately before the locked restore engine:

1. Receive an already reviewed, account-bound eight-domain snapshot record.
2. Revalidate owner, revision, full snapshot structure and canonical SHA-256 digest.
3. Serialize each permanent domain into isolated candidate save files under `user://jade_controlled_transfer_qa/`.
4. Reopen and verify the durable candidate set without touching registered player saves.
5. Require an explicit decision before any mutation.
6. Copy the verified candidate bytes into the existing registered-path QA harness and exercise apply -> pending confirmation -> explicit rollback.

The restore engine itself is not modified by this phase.

## Exact permanent domains

The candidate set must contain exactly:

- achievements
- daily_quests
- equipment
- idle_cultivation
- inventory
- journey
- pavilion
- progression

`checkpoint` remains active-run state and is never transferable.

## Safety properties

- No production scene or autoload references the candidate stager.
- The stager is editor + GitHub Actions + explicit environment-gate only.
- No Firebase, Firestore, HTTP, Google account or Play API call exists in the stager.
- No registered `user://<domain>.save` path is accepted or constructed by the stager.
- Candidate serialization uses a separate QA namespace.
- A reviewed record must still carry `restore_allowed=false` and `cloud_mutation_enabled=false`.
- Raw `iap:` Play-token material in Pavilion `processed_grant_ids` is rejected before serialization.
- The local app catalogue is checked so an older client fails closed on unknown inventory/equipment IDs.
- The full eight-domain digest is recalculated before staging and again after reopening the durable files.
- A fixed synthetic fixture must produce the same canonical SHA-256 in Godot as the reviewed backend JavaScript hashing model.
- Candidate staging mutates zero primary save files.
- Before any restore mutation, the existing registered-path harness creates the durable preimage vault and acquires the SaveManager write fence.
- Applied state remains pending explicit confirmation; this QA chooses explicit rollback.
- Existing `.backup` sidecars must remain byte-identical.

## CI PASS marker

The disposable runner must end with:

```text
JADE_CONTROLLED_TRANSFER_CANDIDATE_QA_PASS
```

The workflow intentionally performs no Firebase deployment, no production cloud read, no production cloud write and no Android player-save replacement.

## Next boundary after PASS

Only after this staging gate is locked should a separately reviewed production read adapter be considered. That adapter must obtain the snapshot from a trusted Firebase-authenticated server boundary, preserve exact owner/revision/digest binding, and feed the already-tested candidate stager path. It still must not enable automatic cloud-wins behavior or production upload.
