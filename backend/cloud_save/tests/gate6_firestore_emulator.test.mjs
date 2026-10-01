/** Gate 6 Firestore Emulator ONLY; synthetic accounts and untrusted drafts. */
import test, { after } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { assertGate5EmulatorOnly } from "../functions/src/economy/firestore_gate5_emulator_model.mjs";
import {
  mintSyntheticServerReconciledFixture,
  seedGate6EmulatorAccount,
  setGate6SyntheticReconciliationHold,
  commitGate6SyntheticSnapshot,
} from "../functions/src/snapshot/firestore_gate6_emulator_model.mjs";
import { PERMANENT_DOMAIN_IDS } from "../functions/src/snapshot/full_permanent_draft_v2.mjs";

// Exact localhost/demo project guard precedes loading any Firebase Admin SDK.
assertGate5EmulatorOnly();
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const app = initializeApp({ projectId: "demo-jade-cloud-save-gate5" }, `gate6-ci-${process.pid}`);
const db = getFirestore(app);
after(() => deleteApp(app));

function draft(uid, jade = 0) {
  return {
    draft_snapshot_version: 2, owner_uid: uid, captured_at_unix: 1700000000,
    domain_schema_versions: Object.fromEntries(PERMANENT_DOMAIN_IDS.map(id => [id, 1])),
    domains: {
      achievements: { version: 1, progress: {}, unlocked: [], claimed: [] },
      daily_quests: { version: 1, date_key: "", progress: {}, completed: [], claimed: [] },
      equipment: { version: 1, equipped_item_ids: {
        armament: "", robe: "", bracer: "", boots: "", pendant: "",
      } },
      inventory: { version: 1, item_counts: {} },
      journey: { version: 1, selected_chapter_id: 1, selected_stage_id: 1,
        active_run_chapter_id: 0, active_run_stage_id: 0,
        unlocked_stage_keys: [], cleared_stage_keys: [] },
      progression: { version: 1, spirit_stone: 0, vitality_level: 0, sword_power_level: 0, swift_qi_level: 0 },
      pavilion: { version: 1, meditation_date: "", cosmetic_id: "plain", owned_cosmetics: ["plain"],
        celestial_jade: jade, pavilion_seals: 0, processed_grant_ids: [] },
      idle_cultivation: { version: 1, last_claim_unix: 1000, last_observed_unix: 1000,
        lifetime_claim_seconds: 0, shard_progress_units: 0 },
    },
  };
}
const account = uid => db.collection("gate6_qa_accounts_v1").doc(uid);
const snap = (uid, revision) => account(uid).collection("qa_snapshots")
  .doc(`rev_${String(revision).padStart(14, "0")}`);
const commit = (uid, rev, proof, auth = uid) => commitGate6SyntheticSnapshot(db, {
  authenticatedUid: auth, ownerUid: uid, expectedRevision: rev, syntheticProof: proof,
});

test("Gate 6 synthetic full-eight snapshot advances server CAS and writes immutable revision 1", async () => {
  const uid = "gate6_first";
  assert.equal((await seedGate6EmulatorAccount(db, uid)).ok, true);
  const proof = mintSyntheticServerReconciledFixture(draft(uid, 100), uid);
  assert.deepEqual(await commit(uid, 0, proof), {
    ok: true, code: "SYNTHETIC_SNAPSHOT_COMMITTED", revision: 1, domain_count: 8,
  });
  const [a, s] = await Promise.all([account(uid).get(), snap(uid, 1).get()]);
  assert.equal(a.data().revision, 1);
  assert.equal(s.exists, true);
  assert.deepEqual(s.data().domainIds, PERMANENT_DOMAIN_IDS);
  assert.equal(s.data().domains.pavilion.celestial_jade, 100);
  assert.equal(s.data().domains.idle_cultivation.last_observed_unix, 1000);
  assert.equal(s.data().qaOnly, true);
  assert.equal(s.data().syntheticDigest, a.data().headDigest);
});

test("Gate 6 cross-account proof and unauthenticated owner claims never write", async () => {
  const uid = "gate6_owner", other = "gate6_foreign";
  await seedGate6EmulatorAccount(db, uid);
  const proof = mintSyntheticServerReconciledFixture(draft(uid), uid);
  assert.equal((await commit(uid, 0, proof, other)).code, "FOREIGN_ACCOUNT");
  assert.equal((await commit(uid, 0, proof, "")).code, "UNAUTHENTICATED");
  assert.equal((await commit(other, 0, proof, other)).code, "PROOF_ACCOUNT_MISMATCH");
  assert.equal((await account(uid).get()).data().revision, 0);
});

test("Gate 6 cannot commit copied proof, forged client reconcile flag or incomplete draft", async () => {
  const uid = "gate6_forged";
  await seedGate6EmulatorAccount(db, uid);
  assert.equal((await commit(uid, 0, { test_fixture_only: true })).code, "NO_SERVER_RECONCILIATION");
  const full = draft(uid); delete full.domains.pavilion;
  const invalid = mintSyntheticServerReconciledFixture(full, uid);
  assert.equal(invalid.code, "INCOMPLETE_PERMANENT_DOMAINS");
  assert.equal((await commit(uid, 0, invalid)).code, "NO_SERVER_RECONCILIATION");
  assert.equal((await account(uid).get()).data().revision, 0);
});

test("Gate 6 stale two-device writes fail CAS without creating a second snapshot", async () => {
  const uid = "gate6_stale";
  await seedGate6EmulatorAccount(db, uid);
  const a = mintSyntheticServerReconciledFixture(draft(uid, 10), uid);
  const b = mintSyntheticServerReconciledFixture(draft(uid, 90), uid);
  assert.equal((await commit(uid, 0, a)).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
  assert.equal((await commit(uid, 0, b)).code, "REVISION_CONFLICT");
  assert.equal((await snap(uid, 2).get()).exists, false);
  assert.equal((await account(uid).get()).data().revision, 1);
});

test("Gate 6 concurrent CAS creates at most one revision and one immutable document", async () => {
  const uid = "gate6_concurrent";
  await seedGate6EmulatorAccount(db, uid);
  const proofs = Array.from({ length: 5 }, (_, i) =>
    mintSyntheticServerReconciledFixture(draft(uid, i + 1), uid));
  const results = await Promise.all(proofs.map(p => commit(uid, 0, p)));
  assert.equal(results.filter(r => r.code === "SYNTHETIC_SNAPSHOT_COMMITTED").length, 1);
  assert.ok(results.every(r => ["SYNTHETIC_SNAPSHOT_COMMITTED", "REVISION_CONFLICT",
    "EMULATOR_TRANSACTION_UNAVAILABLE"].includes(r.code)));
  const [a, docs] = await Promise.all([account(uid).get(), account(uid).collection("qa_snapshots").get()]);
  assert.equal(a.data().revision, 1);
  assert.equal(docs.size, 1);
});

test("Gate 6 reconciliation hold blocks revision and refuses overflows", async () => {
  const uid = "gate6_hold";
  await seedGate6EmulatorAccount(db, uid);
  await setGate6SyntheticReconciliationHold(db, uid);
  const proof = mintSyntheticServerReconciledFixture(draft(uid), uid);
  assert.equal((await commit(uid, 0, proof)).code, "ECONOMY_RECONCILIATION_HOLD");
  assert.equal((await account(uid).get()).data().revision, 0);
  assert.equal((await commit(uid, -1, proof)).code, "INVALID_EXPECTED_REVISION");
});

test("Gate 6 next revision preserves old snapshot and rejects same-content duplicate", async () => {
  const uid = "gate6_history";
  await seedGate6EmulatorAccount(db, uid);
  const first = mintSyntheticServerReconciledFixture(draft(uid, 10), uid);
  const next = mintSyntheticServerReconciledFixture(draft(uid, 11), uid);
  assert.equal((await commit(uid, 0, first)).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
  assert.equal((await commit(uid, 1, next)).code, "SYNTHETIC_SNAPSHOT_COMMITTED");
  assert.equal((await snap(uid, 1).get()).data().domains.pavilion.celestial_jade, 10);
  assert.equal((await snap(uid, 2).get()).data().domains.pavilion.celestial_jade, 11);
  assert.equal((await account(uid).get()).data().revision, 2);
  assert.equal((await commit(uid, 2, next)).code, "NO_STATE_CHANGE");
  assert.equal((await snap(uid, 3).get()).exists, false);
});
