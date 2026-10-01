/**
 * Gate 6B — TEST-ONLY eight-domain revision/CAS Firestore Emulator model.
 * This is deliberately NOT imported by the deployed Firebase callable.
 * A fake reconciled fixture is minted only inside this isolated test process;
 * neither a client boolean nor a device SHA-256 is an authority.
 */
import { assertGate5EmulatorOnly } from "../economy/firestore_gate5_emulator_model.mjs";
import {
  inspectFullPermanentDraft,
  hashFullDraftForQa,
  PERMANENT_DOMAIN_IDS,
  FULL_DRAFT_VERSION,
} from "./full_permanent_draft_v2.mjs";

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const SYNTHETIC = new WeakMap();
const accountDoc = (db, uid) => db.collection("gate6_qa_accounts_v1").doc(uid);
const snapshotDoc = (db, uid, revision) => accountDoc(db, uid)
  .collection("qa_snapshots").doc(`rev_${String(revision).padStart(14, "0")}`);
const ok = (code, fields = {}) => Object.freeze({ ok: true, code, ...fields });
const no = code => Object.freeze({ ok: false, code });
const revisionNumber = n => Number.isSafeInteger(n) && n >= 0;

/** The only way to create a QA-only synthetic proof. Cannot serialize to JSON. */
export function mintSyntheticServerReconciledFixture(draft, ownerUid) {
  assertGate5EmulatorOnly();
  const inspection = inspectFullPermanentDraft(draft, ownerUid);
  if (!inspection.valid) return no(inspection.reason);
  const proof = Object.freeze({ test_fixture_only: true });
  const copy = structuredClone(draft);
  SYNTHETIC.set(proof, Object.freeze({
    ownerUid,
    digest: hashFullDraftForQa(copy),
    capturedAtUnix: copy.captured_at_unix,
    domainVersions: copy.domain_schema_versions,
    domains: copy.domains,
  }));
  return proof;
}

export async function seedGate6EmulatorAccount(db, ownerUid) {
  assertGate5EmulatorOnly();
  if (typeof ownerUid !== "string" || !UID.test(ownerUid)) return no("INVALID_OWNER");
  try {
    await accountDoc(db, ownerUid).create({
      revision: 0, economyHold: false, headDigest: null, domainCount: 0,
    });
    return ok("QA_ACCOUNT_SEEDED");
  } catch {
    return no("QA_ACCOUNT_SEED_FAILED");
  }
}

/** Test-only reconciliation hold injection. Never exposed through a callable. */
export async function setGate6SyntheticReconciliationHold(db, ownerUid) {
  assertGate5EmulatorOnly();
  if (typeof ownerUid !== "string" || !UID.test(ownerUid)) return no("INVALID_OWNER");
  await accountDoc(db, ownerUid).update({ economyHold: true });
  return ok("QA_RECONCILIATION_HOLD_SET");
}

/**
 * Atomically advance a server revision and create an IMMUTABLE QA snapshot.
 * Simulated authentication is supplied by the test, not Android Firebase Auth.
 * NEVER accept a client payload/flag as syntheticProof in real integration.
 */
export async function commitGate6SyntheticSnapshot(db, {
  authenticatedUid, ownerUid, expectedRevision, syntheticProof,
} = {}) {
  assertGate5EmulatorOnly();
  if (typeof authenticatedUid !== "string" || !UID.test(authenticatedUid)) return no("UNAUTHENTICATED");
  if (typeof ownerUid !== "string" || !UID.test(ownerUid)
      || ownerUid !== authenticatedUid) return no("FOREIGN_ACCOUNT");
  if (!revisionNumber(expectedRevision)) return no("INVALID_EXPECTED_REVISION");
  if (!syntheticProof || typeof syntheticProof !== "object"
      || !SYNTHETIC.has(syntheticProof)) return no("NO_SERVER_RECONCILIATION");
  const fact = SYNTHETIC.get(syntheticProof);
  if (fact.ownerUid !== ownerUid) return no("PROOF_ACCOUNT_MISMATCH");
  try {
    return await db.runTransaction(async tx => {
      const aRef = accountDoc(db, ownerUid);
      const old = await tx.get(aRef);
      if (!old.exists) return no("ACCOUNT_NOT_FOUND");
      const current = old.data();
      if (current?.economyHold !== false) return no("ECONOMY_RECONCILIATION_HOLD");
      if (!revisionNumber(current.revision)) return no("INVALID_SERVER_REVISION");
      if (current.revision !== expectedRevision) return no("REVISION_CONFLICT");
      if (current.revision >= Number.MAX_SAFE_INTEGER) return no("REVISION_OVERFLOW");
      if (current.headDigest === fact.digest) return no("NO_STATE_CHANGE");
      const nextRevision = current.revision + 1;
      const domainVersions = structuredClone(fact.domainVersions);
      const domains = structuredClone(fact.domains);
      tx.create(snapshotDoc(db, ownerUid, nextRevision), {
        revision: nextRevision,
        draftVersion: FULL_DRAFT_VERSION,
        domainCount: PERMANENT_DOMAIN_IDS.length,
        domainIds: [...PERMANENT_DOMAIN_IDS],
        domainSchemaVersions: domainVersions,
        domains,
        syntheticDigest: fact.digest,
        // Client clock is a preview hint only; never use as server issuance time.
        untrustedCapturedAtUnix: fact.capturedAtUnix,
        qaOnly: true,
      });
      tx.update(aRef, {
        revision: nextRevision,
        headDigest: fact.digest,
        domainCount: PERMANENT_DOMAIN_IDS.length,
      });
      return ok("SYNTHETIC_SNAPSHOT_COMMITTED", {
        revision: nextRevision, domain_count: PERMANENT_DOMAIN_IDS.length,
      });
    });
  } catch {
    return no("EMULATOR_TRANSACTION_UNAVAILABLE");
  }
}
