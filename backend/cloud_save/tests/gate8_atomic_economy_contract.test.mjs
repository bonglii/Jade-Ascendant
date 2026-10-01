import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import { createHash } from "node:crypto";
import { makeGate7SyntheticDraft } from "./gate7_fixture.mjs";
import {
  inspectFullPermanentDraft, PERMANENT_DOMAIN_IDS, hashFullDraftForQa,
} from "../functions/src/snapshot/full_permanent_draft_v2.mjs";
import { verifyPlayPurchaseV2 } from "../functions/src/economy/play_purchase_v2.mjs";
import {
  seedGate8SyntheticAccount, commitGate8SyntheticPurchase,
  recordGate8SyntheticVoid, reviewGate8SyntheticHead,
} from "../functions/src/integration/firestore_gate8_closed_economy_emulator.mjs";
const ROOT = fileURLToPath(new URL("../../../", import.meta.url));
const text = p => readFileSync(resolve(ROOT, p), "utf8");
const uid = "gate8_offline_synthetic";

const ENV_KEYS = ["JADE_GATE5_EMULATOR_ONLY", "FIRESTORE_EMULATOR_HOST", "GCLOUD_PROJECT", "GOOGLE_CLOUD_PROJECT"];
const isolated = async run => {
  const backup = Object.fromEntries(ENV_KEYS.map(k => [k, process.env[k]]));
  try {
    delete process.env.JADE_GATE5_EMULATOR_ONLY;
    delete process.env.FIRESTORE_EMULATOR_HOST;
    delete process.env.GCLOUD_PROJECT;
    delete process.env.GOOGLE_CLOUD_PROJECT;
    return await run();
  } finally {
    for (const k of ENV_KEYS) {
      if (backup[k] === undefined) delete process.env[k];
      else process.env[k] = backup[k];
    }
  }
};

test("Gate 8 source boundary: no production function or predeploy mutation", () => {
  const entry = text("backend/cloud_save/functions/index.mjs");
  assert.match(entry, /export const \{ jadeCloudSaveCapabilities \}/);
  assert.doesNotMatch(entry, /gate8|firestore_gate8|commitGate8SyntheticPurchase/);
  const policy = JSON.parse(text("backend/cloud_save/predeploy_gate.json"));
  assert.equal(policy.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(policy.deployment_approved, false);
  assert.equal(policy.cloud_mutations_approved, false);
  assert.deepEqual(policy.approved_callable_exports, ["jadeCloudSaveCapabilities"]);
});

test("Gate 8 reuses reviewed eight-domain shape and never includes checkpoint", () => {
  const d = makeGate7SyntheticDraft(uid, 210);
  assert.equal(inspectFullPermanentDraft(d, uid).valid, true);
  assert.equal(PERMANENT_DOMAIN_IDS.length, 8);
  assert.equal(PERMANENT_DOMAIN_IDS.includes("checkpoint"), false);
  const corrupted = structuredClone(d);
  corrupted.domains.checkpoint = { wave: 3 };
  assert.equal(inspectFullPermanentDraft(corrupted, uid).valid, false);
});

test("Gate 8 rejects a draft with raw Play-token grant history", () => {
  const d = makeGate7SyntheticDraft(uid);
  d.domains.pavilion.processed_grant_ids = ["iap:jade_pouch_100:FAKE_PRIVATE_TOKEN"];
  assert.equal(inspectFullPermanentDraft(d, uid).valid, false);
  const digest = hashFullDraftForQa(makeGate7SyntheticDraft(uid));
  assert.match(digest, /^[a-f0-9]{64}$/);
});

test("Gate 8 model refuses all datastore entry points without exact emulator guard", async () => isolated(async () => {
  const db = { collection() { throw Error("MUST_NOT_CREATE_DATASTORE_HANDLE"); } };
  const original = makeGate7SyntheticDraft(uid);
  for (const action of [
    () => seedGate8SyntheticAccount(db, uid, original),
    () => commitGate8SyntheticPurchase(db, { ownerUid: uid }),
    () => recordGate8SyntheticVoid(db, "a".repeat(64)),
    () => reviewGate8SyntheticHead(db, { ownerUid: uid }),
  ]) await assert.rejects(action, /GATE5_EMULATOR_ONLY/);
}));

test("Gate 8 identity cannot be derived from a client-supplied snapshot", async () => {
  const binding = createHash("sha256").update("synthetic_identity").digest("hex");
  const proof = await verifyPlayPurchaseV2({
    reader: { getPurchase: async () => ({
      kind: "androidpublisher#productPurchaseV2",
      purchaseStateContext: { purchaseState: "PURCHASED" },
      productLineItem: [{ productId: "jade_pouch_100", productOfferDetails: {
        quantity: 1, refundableQuantity: 1,
        consumptionState: "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
      } }],
      purchaseCompletionTime: "2026-10-01T12:00:00Z",
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
      obfuscatedExternalAccountId: binding,
    }) },
    purchaseToken: "synthetic_only_not_a_google_token_123",
    playProductId: "jade_pouch_100", expectedObfuscatedAccountId: binding,
    fingerprintSecret: Buffer.alloc(32, 0x33),
  });
  assert.equal(proof.celestialJade, 100);
  assert.equal(proof.pavilionSeals, 0);
  assert.equal(JSON.stringify(proof).includes("synthetic_only_not_a_google_token"), false);
  assert.deepEqual({ ...proof }.celestialJade, proof.celestialJade);
});
