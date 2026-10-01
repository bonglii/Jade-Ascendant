# Jade Ascendant — Cloud Save Gate 3: Snapshot Versioning & Local Integrity

**Gate status:** implementation and regression candidate; `PERIKSA_GAME` on the new patch must be confirmed by CI. **NOT a cloud backup, cryptographic authorization, or deployed server.** Source authority: `qa/cloud-save-gate2-ci`, commit `ed67cb0268f50fe03c3c4b716587fc73a6d69ee0` at audit time.

## Scope and source dependencies

- `scripts/managers/cloud_save_snapshot_contract.gd`: enforces snapshot format v1, *exactly six* permanent candidate domains, SaveManager domain schema versions, allowed fields, integrity of local inventory/equipment relationships, JSON shape and bounded size. It does **not** approve economy claims.
- `scripts/managers/cloud_save_manifest_inspector.gd`: metadata-only Firestore document validation; does **not** establish freshness, existence of payload bytes, or restore eligibility.
- `scripts/managers/cloud_save_economy_consistency.gd`: six-domain candidate is **not transaction-closed**; Pavilion and Idle Cultivation are omitted but share local transaction boundaries with included domains.
- `tests/cloud_save_server_reference_model.gd`: existing synthetic ledger/server-revision CAS tests; not production server authority.
- This pass adds `scripts/managers/cloud_save_snapshot_integrity.gd` and extends `tests/phase0_smoke.gd`. No existing gameplay script or Autoload is modified.

## What the local proof does

`build_local_proof(candidate, expected_uid)` first calls the existing strict snapshot contract, then returns **ephemeral, local-only** SHA-256 commitments. The v1 proof is bound to:

1. `integrity_format_version=1`, `digest_algorithm=SHA-256`, `canonical_encoding=godot_4_7_sorted_json_v1`;
2. `snapshot_format_version=1`, account UID, and **untrusted draft** revision (the placeholder has no server authority);
3. SHA-256 of the whole structurally valid candidate (including UID, local time and domain/schema data);
4. six individual domain SHA-256 values covering `{domain_id, schema_version, payload}`.

The encoder uses Godot 4.7's `JSON.stringify(value, "", true, true)`: sorted dictionary keys, full float precision, UTF-8 string hashing. **A future backend must independently specify/test exact canonical bytes and digest vectors** or store hashes created by the backend itself. The format is pinned: modifying encoding, domain set, digest semantics or schema demands a new version and migration policy rather than quietly changing the v1 interpretation.

`inspect_local_proof(candidate, expected_uid, proof)` fails closed on a malformed/future proof, owner mismatch, unsafe schema/format, domain-set mismatch, edited domain contents, altered revision or timestamp. Dictionary insertion order does not change its digest; order of arrays does. It neither reads files nor writes disk.

`inspect_manifest_alignment(candidate, expected_uid, proof, manifest)` additionally requires a locally matching proof plus a valid six-domain read-only manifest with equal owner, schemas, revision, and timestamp. This is **only a metadata comparison**: even a perfectly matching manifest is not proof of a current server snapshot.

Each success and rejection explicitly returns `upload_allowed=false`, `restore_allowed=false`, `economy_verified=false`, and `server_verified=false`. A success means *local bytes/data are internally consistent*; there is no keyed HMAC, server signature, independent entitlement ledger or verified receipt. **A malicious client can rewrite Spirit Stones, then compute an equally valid hash**. Smoke tests prove that this still cannot authorize cloud upload or restore.

## Regression matrix

- Structural candidate generates a full+six-domain proof without modifying input; unordered JSON object keys produce the same commitment.
- Valid compatible proof passes local integrity while retaining all cloud locks.
- Modifying earned currency, timestamps, draft revision, or ordered arrays invalidates a previously created proof.
- An attacker recomputing a proof on a forged (but structurally valid) balance is still economically unverified and cannot upload/restore.
- Unknown proof version, digest algorithm, encoding, future snapshot format/domain version, missing/extra domain hashes, malformed hash, foreign owner, premium Pavilion addition and unsafe UID all reject.
- Manifest alignment is rejected for stale/different revision, changed time, foreign UID, missing inventory domain, unknown domain version, future manifest version, and empty document; matching metadata never certifies server freshness.
- All test fixtures are synthetic in memory; `phase0_smoke.gd` remains the existing isolated CI entrypoint.

## Explicit blockers before production Cloud Save

- Backend-owned complete **eight-domain** reconciled snapshot; six-domain preview cannot be used as a real account backup.
- Server-side purchase validation and append-only durable token/grant ledger; trusted UID from verified Auth context, not JSON fields.
- Strict server-issued monotonic revision/CAS, multi-device conflict and offline-play reconciliation, refund and chargeback policy.
- Atomic local restore with recovery backup, rollback tests and player consent.
- Signed or backend-attested integrity: client SHA-256 is not a MAC or authenticity proof. Firestore read-only Rules remain unchanged; do not enable `create`, `update`, `delete`, or auto-restore.
- Native Android authentication and billing need separate device QA; headless CI is neither purchase verification nor a release gate.

## Delivery rules

Send replacement ZIP with only new/changed files under top-level `jade-ascendant/`. Extract to `D:\Godot\project\` (Replace). Stage the explicit paths only, run `git diff --cached --check`, and commit/push **only to `qa/cloud-save-gate2-ci`** after review. Verify the GitHub Actions run associated with the new commit, not an earlier green badge. `main` remains untouched.
