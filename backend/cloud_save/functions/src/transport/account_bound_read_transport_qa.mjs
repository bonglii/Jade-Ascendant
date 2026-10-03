/**
 * Trusted/account-bound READ transport boundary — QA ONLY.
 *
 * Production-shaped invariants:
 * - owner is derived only from Firebase callable auth context;
 * - client payload is empty (no owner/revision/digest/currency/token claims);
 * - one Firestore transaction reads account head + EXACT current snapshot;
 * - no history fallback when the current snapshot is missing;
 * - reconciliation/economy hold refuses transport;
 * - strict eight-domain validation and digest binding run before bytes leave server;
 * - response never enables upload, mutation, automatic restore, or cloud-wins.
 *
 * This module is deliberately NOT exported by functions/index.mjs and is guarded
 * to the localhost/demo Firestore emulator. It is not a production deployment.
 */
import { assertGate5EmulatorOnly } from "../economy/firestore_gate5_emulator_model.mjs";
import {
  FULL_DRAFT_VERSION,
  PERMANENT_DOMAIN_IDS,
  inspectFullPermanentDraft,
  hashFullDraftForQa,
} from "../snapshot/full_permanent_draft_v2.mjs";

export const ACCOUNT_BOUND_READ_TRANSPORT_VERSION = 1;

const UID = /^[A-Za-z0-9_-]{1,128}$/;
const SHA256 = /^[0-9a-f]{64}$/;
const validRev = n => Number.isSafeInteger(n) && n > 0;
const no = code => Object.freeze({
  ok: false,
  code,
  transport_contract_version: ACCOUNT_BOUND_READ_TRANSPORT_VERSION,
  restore_allowed: false,
  cloud_mutation_enabled: false,
});
const plain = value => value !== null && typeof value === "object" && !Array.isArray(value)
  && (Object.getPrototypeOf(value) === Object.prototype || Object.getPrototypeOf(value) === null);
const accountDoc = (db, uid) => db.collection("gate6_qa_accounts_v1").doc(uid);
const snapshotDoc = (db, uid, revision) => accountDoc(db, uid).collection("qa_snapshots")
  .doc(`rev_${String(revision).padStart(14, "0")}`);

function deriveGoogleLinkedUid(request) {
  const auth = request?.auth;
  if (!auth || typeof auth !== "object" || typeof auth.uid !== "string" || !UID.test(auth.uid)) {
    return null;
  }
  const firebase = auth.token?.firebase;
  if (!plain(firebase) || firebase.sign_in_provider !== "google.com") return null;
  const google = firebase.identities?.["google.com"];
  if (!Array.isArray(google) || google.length === 0
      || !google.every(value => typeof value === "string" && value.length > 0)) return null;
  return auth.uid;
}

function emptyClientPayload(data) {
  return plain(data) && Reflect.ownKeys(data).length === 0;
}

/**
 * QA-only production-shaped read boundary. The request shape mirrors Firebase
 * onCall, but this is invoked only by emulator tests and is not a callable route.
 */
export async function readCurrentAccountBoundSnapshotForQa(db, request = {}) {
  assertGate5EmulatorOnly();
  const authenticatedUid = deriveGoogleLinkedUid(request);
  if (!authenticatedUid) return no("UNAUTHENTICATED_GOOGLE_ACCOUNT");
  if (!emptyClientPayload(request.data)) return no("UNSUPPORTED_CLIENT_PAYLOAD");

  try {
    return await db.runTransaction(async tx => {
      const accountRef = accountDoc(db, authenticatedUid);
      const account = await tx.get(accountRef);
      if (!account.exists) return no("ACCOUNT_NOT_FOUND");

      const head = account.data();
      if (head?.economyHold !== false) return no("ECONOMY_RECONCILIATION_HOLD");
      if (!validRev(head?.revision)) return no("CURRENT_REVISION_UNAVAILABLE");
      if (head.domainCount !== PERMANENT_DOMAIN_IDS.length) return no("DOMAIN_SET_INCOMPLETE");
      if (typeof head.headDigest !== "string" || !SHA256.test(head.headDigest)) {
        return no("CURRENT_DIGEST_INVALID");
      }

      // Critical rule: derive the revision from the account head read above.
      // Never accept a client revision and never search/fallback through history.
      const currentRevision = head.revision;
      const snapshot = await tx.get(snapshotDoc(db, authenticatedUid, currentRevision));
      if (!snapshot.exists) return no("CURRENT_SNAPSHOT_NOT_FOUND");
      const payload = snapshot.data();

      if (payload?.qaOnly !== true
          || payload?.revision !== currentRevision
          || payload?.draftVersion !== FULL_DRAFT_VERSION
          || payload?.domainCount !== PERMANENT_DOMAIN_IDS.length
          || JSON.stringify(payload?.domainIds) !== JSON.stringify(PERMANENT_DOMAIN_IDS)) {
        return no("INVALID_CURRENT_SNAPSHOT_METADATA");
      }

      const draft = {
        draft_snapshot_version: payload.draftVersion,
        // Owner is server/auth derived, never copied from client data or snapshot fields.
        owner_uid: authenticatedUid,
        captured_at_unix: payload.untrustedCapturedAtUnix,
        domain_schema_versions: payload.domainSchemaVersions,
        domains: payload.domains,
      };
      const inspection = inspectFullPermanentDraft(draft, authenticatedUid);
      if (!inspection.valid) return no("INVALID_CURRENT_SNAPSHOT_CONTENT");

      const digest = hashFullDraftForQa(draft);
      if (digest !== head.headDigest || digest !== payload.syntheticDigest) {
        return no("CURRENT_SNAPSHOT_DIGEST_MISMATCH");
      }

      return Object.freeze({
        ok: true,
        code: "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY",
        transport_contract_version: ACCOUNT_BOUND_READ_TRANSPORT_VERSION,
        qaOnly: true,
        ownerUid: authenticatedUid,
        revision: currentRevision,
        digest,
        domain_count: PERMANENT_DOMAIN_IDS.length,
        domain_ids: [...PERMANENT_DOMAIN_IDS],
        draft: structuredClone(draft),
        server_revision_verified: true,
        server_freshness_verified: true,
        explicit_restore_decision_required: true,
        restore_allowed: false,
        cloud_mutation_enabled: false,
      });
    });
  } catch {
    return no("EMULATOR_READ_UNAVAILABLE");
  }
}
