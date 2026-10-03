# Account-Bound Read Transport QA

Status: QA-only / read-only / no deploy.

This phase bridges the already-reviewed eight-domain server snapshot model toward a production-shaped transport boundary without enabling production Cloud Save.

## Locked safety boundary

- Owner identity comes only from Firebase-style authenticated Google account context.
- Client request data must be an empty object; owner UID, revision, digest, currency, purchase token, restore flags and operation claims are rejected.
- The server transaction reads the account head and the exact snapshot referenced by the current head revision.
- Missing current snapshot fails closed. Older history is never substituted.
- Reconciliation/economy hold fails closed.
- The strict eight-domain v2 contract is revalidated before transport.
- Raw Pavilion `iap:` grant IDs are rejected by the full snapshot contract.
- Head digest and immutable snapshot digest must both equal the canonical eight-domain digest.
- The transport record keeps `restore_allowed=false` and `cloud_mutation_enabled=false`.
- Applying a staged snapshot remains a separate explicit local restore decision.

## Intentionally not implemented

- No export from `backend/cloud_save/functions/index.mjs`.
- No Firebase production deployment.
- No production Firestore reads or writes.
- No upload/write endpoint.
- No automatic restore or cloud-wins policy.
- No Android bridge yet; that belongs to the next transport-to-Godot staging subphase after this contract is green.
