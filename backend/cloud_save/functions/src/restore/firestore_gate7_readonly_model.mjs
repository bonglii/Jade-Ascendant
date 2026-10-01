/**
 * Gate 7 — test-only read-only latest snapshot preflight against the Firestore
 * Emulator. Uses the Gate 6 QA collection; NEVER writes, deploys, restores,
 * grants rewards or reads production. No real Firebase Auth is asserted here.
 */
import { assertGate5EmulatorOnly } from "../economy/firestore_gate5_emulator_model.mjs";
import {
  FULL_DRAFT_VERSION, PERMANENT_DOMAIN_IDS,
  inspectFullPermanentDraft, hashFullDraftForQa,
} from "../snapshot/full_permanent_draft_v2.mjs";

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const validRev = n => Number.isSafeInteger(n) && n > 0;
const no = code => Object.freeze({ ok: false, code });
const goodUid = uid => typeof uid === "string" && UID.test(uid);
const accountDoc = (db, uid) => db.collection("gate6_qa_accounts_v1").doc(uid);
const snapshotDoc = (db, uid, n) => accountDoc(db, uid).collection("qa_snapshots")
  .doc(`rev_${String(n).padStart(14, "0")}`);

/**
 * A single consistent Firestore transaction READS the head and exact latest
 * snapshot. Its result is only a test fixture for the sandbox; no real
 * authorization is conferred by the returned plain object.
 */
export async function reviewGate7LatestSyntheticSnapshot(db, {
  authenticatedUid, ownerUid, expectedRevision,
} = {}) {
  assertGate5EmulatorOnly();
  if (!goodUid(authenticatedUid)) return no("UNAUTHENTICATED");
  if (!goodUid(ownerUid) || ownerUid !== authenticatedUid) return no("FOREIGN_ACCOUNT");
  if (!validRev(expectedRevision)) return no("INVALID_EXPECTED_REVISION");
  try {
    return await db.runTransaction(async tx => {
      const a = await tx.get(accountDoc(db, ownerUid));
      if (!a.exists) return no("ACCOUNT_NOT_FOUND");
      const head = a.data();
      if (head?.economyHold !== false) return no("ECONOMY_RECONCILIATION_HOLD");
      if (!validRev(head?.revision) || head.revision !== expectedRevision) {
        return no("SERVER_REVISION_CHANGED");
      }
      if (head.domainCount !== PERMANENT_DOMAIN_IDS.length) return no("DOMAIN_SET_INCOMPLETE");
      const s = await tx.get(snapshotDoc(db, ownerUid, expectedRevision));
      if (!s.exists) return no("SNAPSHOT_NOT_FOUND");
      const payload = s.data();
      if (payload?.qaOnly !== true || payload?.revision !== expectedRevision
        || payload?.draftVersion !== FULL_DRAFT_VERSION
        || payload?.domainCount !== PERMANENT_DOMAIN_IDS.length
        || JSON.stringify(payload?.domainIds) !== JSON.stringify(PERMANENT_DOMAIN_IDS)) {
        return no("INVALID_SNAPSHOT_METADATA");
      }
      const draft = {
        draft_snapshot_version: payload.draftVersion,
        owner_uid: ownerUid,
        captured_at_unix: payload.untrustedCapturedAtUnix,
        domain_schema_versions: payload.domainSchemaVersions,
        domains: payload.domains,
      };
      const checked = inspectFullPermanentDraft(draft, authenticatedUid);
      if (!checked.valid) return no("INVALID_SNAPSHOT_CONTENT");
      const digest = hashFullDraftForQa(draft);
      if (head.headDigest !== digest || payload.syntheticDigest !== digest) {
        return no("SNAPSHOT_DIGEST_MISMATCH");
      }
      return Object.freeze({
        ok: true, code: "QA_LATEST_SNAPSHOT_REVIEWED", qaOnly: true,
        ownerUid, revision: expectedRevision, digest, draft: structuredClone(draft),
        restore_allowed: false, cloud_mutation_enabled: false,
      });
    });
  } catch {
    return no("EMULATOR_READ_UNAVAILABLE");
  }
}
