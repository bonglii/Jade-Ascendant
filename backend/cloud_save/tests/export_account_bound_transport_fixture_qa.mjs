/**
 * Produce one synthetic account-bound transport record for the Godot bridge QA.
 * Firestore access is guarded to the localhost DEMO emulator. The read transport
 * itself performs no writes; Gate 6 QA helpers seed synthetic server state only.
 */
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { createRequire } from "node:module";
import { assertGate5EmulatorOnly } from "../functions/src/economy/firestore_gate5_emulator_model.mjs";
import {
  seedGate6EmulatorAccount,
  mintSyntheticServerReconciledFixture,
  commitGate6SyntheticSnapshot,
} from "../functions/src/snapshot/firestore_gate6_emulator_model.mjs";
import { readCurrentAccountBoundSnapshotForQa } from "../functions/src/transport/account_bound_read_transport_qa.mjs";
import { makeGate7SyntheticDraft } from "./gate7_fixture.mjs";

assertGate5EmulatorOnly();
const require = createRequire(new URL("../functions/index.mjs", import.meta.url));
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const OWNER = "account_bound_transport_to_godot_owner";
const OUTPUT_DIR = resolve(process.cwd(), "qa_artifacts");
const OUTPUT_PATH = resolve(OUTPUT_DIR, "account_bound_transport_record.json");
const app = initializeApp({ projectId: "demo-jade-cloud-save-gate5" }, `transport-to-godot-${process.pid}`);
const db = getFirestore(app);
const account = () => db.collection("gate6_qa_accounts_v1").doc(OWNER);
const request = () => ({
  auth: {
    uid: OWNER,
    token: { firebase: {
      sign_in_provider: "google.com",
      identities: { "google.com": ["synthetic_google_subject"] },
    } },
  },
  data: {},
});

try {
  assert.equal((await seedGate6EmulatorAccount(db, OWNER)).code, "QA_ACCOUNT_SEEDED");
  const first = mintSyntheticServerReconciledFixture(makeGate7SyntheticDraft(OWNER, 72), OWNER);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: OWNER,
    ownerUid: OWNER,
    expectedRevision: 0,
    syntheticProof: first,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");

  const second = mintSyntheticServerReconciledFixture(makeGate7SyntheticDraft(OWNER, 144), OWNER);
  assert.equal((await commitGate6SyntheticSnapshot(db, {
    authenticatedUid: OWNER,
    ownerUid: OWNER,
    expectedRevision: 1,
    syntheticProof: second,
  })).code, "SYNTHETIC_SNAPSHOT_COMMITTED");

  const beforeHead = (await account().get()).data();
  const beforeHistory = (await account().collection("qa_snapshots").get()).docs.map(doc => doc.data());
  const record = await readCurrentAccountBoundSnapshotForQa(db, request());
  assert.equal(record.ok, true);
  assert.equal(record.code, "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY");
  assert.equal(record.revision, 2);
  assert.equal(record.domain_count, 8);
  assert.equal(record.draft.domains.pavilion.celestial_jade, 144);
  assert.equal(record.server_revision_verified, true);
  assert.equal(record.server_freshness_verified, true);
  assert.equal(record.explicit_restore_decision_required, true);
  assert.equal(record.restore_allowed, false);
  assert.equal(record.cloud_mutation_enabled, false);

  // Prove the transport read itself changed neither head nor immutable history.
  assert.deepEqual((await account().get()).data(), beforeHead);
  assert.deepEqual(
    (await account().collection("qa_snapshots").get()).docs.map(doc => doc.data()),
    beforeHistory,
  );

  mkdirSync(OUTPUT_DIR, { recursive: true });
  writeFileSync(OUTPUT_PATH, `${JSON.stringify(record)}\n`, { encoding: "utf8", flag: "w" });
  console.log("JADE_ACCOUNT_BOUND_TRANSPORT_RECORD_EXPORTED | revision=2 | domains=8");
} finally {
  await deleteApp(app);
}
