/** Gate 5 Spark-only synthetic QA. NO money, Google OAuth, Firestore or player saves. */
import test from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { resolve } from "node:path";
import {
  ANDROID_PACKAGE, ACTIVE_PLAY_PRODUCTS, getActivePlayProduct,
} from "../functions/src/economy/product_catalog.mjs";
import {
  PurchasePolicyError, createPlayProductsV2Reader,
  verifyPlayPurchaseV2, isVerifiedGate5Proof,
} from "../functions/src/economy/play_purchase_v2.mjs";
import { SimulatedPurchaseLedger } from "../functions/src/economy/ledger_reference.mjs";
import { assertGate5EmulatorOnly } from "../functions/src/economy/firestore_gate5_emulator_model.mjs";

const ROOT = fileURLToPath(new URL("../../../", import.meta.url));
const read = rel => readFileSync(resolve(ROOT, rel), "utf8");
const ACCOUNT_HASH = createHash("sha256").update("synthetic_uid_a").digest("hex");
const FOREIGN_ACCOUNT_HASH = createHash("sha256").update("synthetic_uid_b").digest("hex");
const KEY = Buffer.alloc(32, 0x42); // TEST ONLY: never copy into production.
const TOKEN = "synthetic_qa_play_token_A__non_real";
const SKU = "jade_pouch_550";
const verified = response => ({ getPurchase: async () => structuredClone(response) });

function purchase({
  sku = SKU, state = "PURCHASED", quantity = 1, refundableQuantity = 1,
  consumption = "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
  account = ACCOUNT_HASH,
  ack = "ACKNOWLEDGEMENT_STATE_PENDING",
} = {}) {
  return {
    kind: "androidpublisher#productPurchaseV2",
    purchaseStateContext: { purchaseState: state },
    productLineItem: [{ productId: sku, productOfferDetails: {
      quantity, refundableQuantity, consumptionState: consumption,
    } }],
    purchaseCompletionTime: "2026-10-01T12:00:00Z",
    acknowledgementState: ack,
    obfuscatedExternalAccountId: account,
    orderId: "fake-GPA-order-never-used-as-key",
  };
}

async function proof({ response = purchase(), token = TOKEN, sku = SKU, overrides = {} } = {}) {
  return verifyPlayPurchaseV2({
    reader: verified(response), purchaseToken: token, playProductId: sku,
    expectedObfuscatedAccountId: ACCOUNT_HASH, fingerprintSecret: KEY, ...overrides,
  });
}

async function rejects(response, code, opts = {}) {
  await assert.rejects(() => proof({ response, ...opts }), error =>
    error instanceof PurchasePolicyError && error.code === code
      && !error.message.includes(TOKEN) && !error.message.includes(ACCOUNT_HASH));
}

test("Gate 5 catalog matches 6 active game/Play products; no client price or disabled products", () => {
  assert.equal(ANDROID_PACKAGE, "com.yungdevstudio.jadeascendant");
  const expected = [
    ["jade_pouch_100", "jade_pouch_100", 100],
    ["jade_satchel_550", "jade_pouch_550", 550],
    ["jade_casket_1200", "jade_pouch_1200", 1200],
    ["jade_vault_2500", "jade_pouch_2500", 2500],
    ["jade_treasury_6500", "jade_pouch_6500", 6500],
    ["jade_ascendant_14000", "jade_pouch_14000", 14000],
  ];
  assert.deepEqual(Object.keys(ACTIVE_PLAY_PRODUCTS).sort(), expected.map(x => x[1]).sort());
  const gameCatalog = read("scripts/data/economy_catalog.gd");
  const billing = read("scripts/monetization/google_play_billing_provider.gd");
  const release = read("release/GOOGLE_PLAY_IAP_SETUP.md");
  for (const [internalId, playId, amount] of expected) {
    assert.deepEqual(getActivePlayProduct(playId), {
      internalId, playProductId: playId, celestialJade: amount,
      pavilionSeals: 0, kind: "consumable",
    });
    assert.match(gameCatalog, new RegExp(`"${internalId}":[\\s\\S]*?"celestial_jade": ${amount}\\b`));
    assert.ok(billing.includes(`"${internalId}": "${playId}"`));
    assert.ok(release.includes(`${internalId} -> ${playId}`));
    assert.equal(Object.hasOwn(getActivePlayProduct(playId), "price"), false);
  }
  for (const p of ["starter_support_pack", "monthly_jade_blessing", "__proto__", "toString", "jade_pouch_999"]) {
    assert.equal(getActivePlayProduct(p), null);
  }
  assert.equal(getActivePlayProduct(null), null);
  assert.equal(Object.isFrozen(ACTIVE_PLAY_PRODUCTS), true);
});

test("Google API reader cannot be instantiated with implicit fetch or credentials", () => {
  assert.throws(() => createPlayProductsV2Reader(), { code: "SERVER_READER_NOT_CONFIGURED" });
  assert.throws(() => createPlayProductsV2Reader({ fetchImpl() {} }), { code: "SERVER_READER_NOT_CONFIGURED" });
});

test("Google API reader performs GET only against fixed package and token URL, no token logs", async () => {
  const captured = [];
  const api = createPlayProductsV2Reader({
    getAccessToken: async () => "synthetic_bearer_token",
    fetchImpl: async (url, opts) => {
      captured.push({ url, opts });
      return { ok: true, status: 200, json: async () => purchase() };
    },
  });
  assert.deepEqual(await api.getPurchase("fake_play_token/with?reserved=chars"), purchase());
  assert.equal(captured.length, 1);
  const { url, opts } = captured[0];
  assert.equal(new URL(url).origin, "https://androidpublisher.googleapis.com");
  assert.ok(url.includes(`/applications/${ANDROID_PACKAGE}/purchases/productsv2/tokens/`));
  assert.ok(url.includes("fake_play_token%2Fwith%3Freserved%3Dchars"));
  assert.equal(opts.method, "GET");
  assert.equal(opts.redirect, "error");
  assert.equal(opts.headers.Authorization, "Bearer synthetic_bearer_token");
  assert.ok(opts.signal instanceof AbortSignal);
});

test("Google API reader maps network errors/404/bad JSON to sanitized codes", async () => {
  const reader = response => createPlayProductsV2Reader({
    getAccessToken: async () => "synthetic_bearer_token",
    fetchImpl: async () => response,
  });
  await assert.rejects(reader({ status: 404, ok: false }).getPurchase(TOKEN), { code: "PLAY_PURCHASE_NOT_FOUND" });
  await assert.rejects(reader({ status: 403, ok: false }).getPurchase(TOKEN), { code: "PLAY_API_UNAVAILABLE" });
  await assert.rejects(reader({ status: 200, ok: true, json: async () => "forged" }).getPurchase(TOKEN), { code: "PLAY_RESPONSE_INVALID" });
  await assert.rejects(reader({ status: 200, ok: true, json: async () => { throw Error(TOKEN); } }).getPurchase(TOKEN), { code: "PLAY_RESPONSE_INVALID" });
  const network = createPlayProductsV2Reader({ getAccessToken: async () => "valid_bearer", fetchImpl: async () => { throw Error(TOKEN); } });
  await assert.rejects(network.getPurchase(TOKEN), e => e.code === "PLAY_API_UNAVAILABLE" && !e.message.includes(TOKEN));
  const auth = createPlayProductsV2Reader({ getAccessToken: async () => { throw Error(TOKEN); }, fetchImpl: async () => {} });
  await assert.rejects(auth.getPurchase(TOKEN), e => e.code === "PLAY_AUTH_UNAVAILABLE" && !e.message.includes(TOKEN));
});

test("Play V2 purchased + exact account/SKU yields brand-only frozen proof, not token", async () => {
  const result = await proof();
  assert.equal(isVerifiedGate5Proof(result), true);
  assert.equal(result.productId, "jade_satchel_550");
  assert.equal(result.playProductId, SKU);
  assert.equal(result.celestialJade, 550);
  assert.equal(result.pavilionSeals, 0);
  assert.equal(result.kind, "consumable");
  assert.equal(result.fingerprint.length, 64);
  assert.equal(Object.isFrozen(result), true);
  assert.ok(!JSON.stringify(result).includes(TOKEN));
  assert.ok(!JSON.stringify(result).includes(ACCOUNT_HASH));
  assert.ok(!JSON.stringify(result).includes("GPA"));
});

test("Reject missing, malformed and untrusted purchase inputs", async () => {
  for (const value of [null, "", "tiny", ` ${TOKEN}`, `${TOKEN}\n`, "a".repeat(4097)]) {
    await assert.rejects(() => proof({ token: value }), { code: "INVALID_TOKEN" });
  }
  for (const p of ["starter_support_pack", "monthly_jade_blessing", "__proto__", "jade_pouch_999"]) {
    await assert.rejects(() => proof({ sku: p }), { code: "UNSUPPORTED_PRODUCT" });
  }
  await assert.rejects(() => proof({ overrides: { expectedObfuscatedAccountId: "uid_from_client" } }), { code: "ACCOUNT_BINDING_REQUIRED" });
  await assert.rejects(() => proof({ overrides: { fingerprintSecret: Buffer.alloc(12) } }), { code: "LEDGER_KEY_UNAVAILABLE" });
  await assert.rejects(() => proof({ overrides: { fingerprintSecret: "client_supplied_key" } }), { code: "LEDGER_KEY_UNAVAILABLE" });
  await assert.rejects(() => proof({ overrides: { reader: null } }), { code: "SERVER_READER_NOT_CONFIGURED" });
  await assert.rejects(() => proof({ overrides: { reader: { getPurchase: async () => { throw Error(TOKEN); } } } }), e => e.code === "PLAY_API_UNAVAILABLE" && !e.message.includes(TOKEN));
});

test("Reject pending/cancelled/unknown state and invalid completion time", async () => {
  for (const state of ["PENDING", "CANCELLED", "PURCHASE_STATE_UNSPECIFIED", null]) {
    await rejects(purchase({ state }), "PURCHASE_NOT_COMPLETED");
  }
  const noTime = purchase(); delete noTime.purchaseCompletionTime;
  await rejects(noTime, "PURCHASE_TIME_MISSING");
  await rejects({ ...purchase(), purchaseCompletionTime: "fake" }, "PURCHASE_TIME_MISSING");
  await rejects({ ...purchase(), purchaseCompletionTime: "2026-10-01" }, "PURCHASE_TIME_MISSING");
  await rejects({ ...purchase(), purchaseStateContext: "PURCHASED" }, "PLAY_RESPONSE_INVALID");
  await rejects({ ...purchase(), kind: "androidpublisher#productPurchase" }, "PLAY_RESPONSE_INVALID");
});

test("Reject price/product substitution, fake package, extra line items", async () => {
  await rejects(purchase({ sku: "jade_pouch_100" }), "PLAY_PRODUCT_MISMATCH");
  await rejects({ ...purchase(), packageName: "com.attacker.game" }, "PACKAGE_MISMATCH");
  await rejects({ ...purchase(), productLineItem: [] }, "MULTI_LINE_PURCHASE_UNSUPPORTED");
  await rejects({ ...purchase(), productLineItem: [purchase().productLineItem[0], purchase().productLineItem[0]] }, "MULTI_LINE_PURCHASE_UNSUPPORTED");
  await rejects({ ...purchase(), productLineItem: [{ productId: SKU }] }, "PLAY_RESPONSE_INVALID");
  const extra = purchase(); extra.productLineItem[0].productOfferDetails.preorderOfferDetails = {};
  await rejects(extra, "UNSUPPORTED_OFFER");
  const rental = purchase(); rental.productLineItem[0].productOfferDetails.rentOfferDetails = {};
  await rejects(rental, "UNSUPPORTED_OFFER");
});

test("Reject multi-quantity, refunds, already-consumed and unsupported acknowledgements", async () => {
  for (const quantity of [0, 2, "1", null, 1.2, Number.MAX_SAFE_INTEGER]) {
    await rejects(purchase({ quantity }), "UNSUPPORTED_QUANTITY");
  }
  for (const refundableQuantity of [0, 2, "1", null]) {
    await rejects(purchase({ refundableQuantity }), "REFUND_RECONCILIATION_REQUIRED");
  }
  await rejects(purchase({ consumption: "CONSUMPTION_STATE_CONSUMED" }), "PURCHASE_ALREADY_CONSUMED");
  await rejects(purchase({ consumption: "CONSUMPTION_STATE_UNSPECIFIED" }), "PURCHASE_ALREADY_CONSUMED");
  await rejects(purchase({ ack: "ACKNOWLEDGEMENT_STATE_UNSPECIFIED" }), "ACKNOWLEDGEMENT_UNKNOWN");
  assert.equal(isVerifiedGate5Proof(await proof({ response: purchase({ ack: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" }) })), true);
});

test("Reject wrong/missing account binding and test card unless explicit QA opt-in", async () => {
  await rejects(purchase({ account: FOREIGN_ACCOUNT_HASH }), "ACCOUNT_BINDING_MISMATCH");
  const absent = purchase(); delete absent.obfuscatedExternalAccountId;
  await rejects(absent, "ACCOUNT_BINDING_MISMATCH");
  const tester = purchase(); tester.testPurchaseContext = { fopType: "TEST" };
  await rejects(tester, "TEST_PURCHASE_NOT_ALLOWED");
  assert.equal(isVerifiedGate5Proof(await proof({ response: tester, overrides: { allowLicenseTester: true } })), true);
  const badTester = purchase(); badTester.testPurchaseContext = { fopType: "FOP_TYPE_UNSPECIFIED" };
  await rejects(badTester, "TEST_PURCHASE_NOT_ALLOWED", { overrides: { allowLicenseTester: true } });
});

test("HMAC fingerprint is stable across same token and key but never embeds token", async () => {
  const first = await proof(); const again = await proof();
  const anotherKey = await proof({ overrides: { fingerprintSecret: Buffer.alloc(32, 0x41) } });
  assert.equal(first.fingerprint, again.fingerprint);
  assert.notEqual(first.fingerprint, anotherKey.fingerprint);
  assert.notEqual(first.fingerprint, TOKEN);
  assert.equal(isVerifiedGate5Proof({ ...first }), false);
  assert.equal(isVerifiedGate5Proof({ fingerprint: first.fingerprint, productId: first.productId }), false);
});

test("Synthetic ledger cannot accept a forged client proof or missing account", async () => {
  const model = new SimulatedPurchaseLedger();
  assert.equal(model.seedAccount("synthetic_uid_a").ok, true);
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: { ...await proof() } }).code, "UNVERIFIED_PURCHASE");
  assert.equal(model.applyVerifiedFixture({ ownerUid: "missing", expectedRevision: 0, proof: await proof() }).code, "ACCOUNT_NOT_FOUND");
  assert.equal(model.applyVerifiedFixture({ ownerUid: "illegal/uid", expectedRevision: 0, proof: await proof() }).code, "INVALID_OWNER");
  assert.equal(model.ledgerSize, 0);
});

test("Synthetic ledger grants once and repeats same-owner retries idempotently", async () => {
  const model = new SimulatedPurchaseLedger();model.seedAccount("synthetic_uid_a");
  const v = await proof();
  assert.deepEqual(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: v }), { ok: true, code: "APPLIED", revision: 1, grant: 550 });
  assert.deepEqual(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: v }), { ok: true, code: "ALREADY_APPLIED", revision: 1, grant: 0 });
  assert.equal(model.readAccount("synthetic_uid_a").celestialJade, 550);
  assert.equal(model.ledgerSize, 1);
  assert.equal(model.eventCount, 1);
});

test("Synthetic ledger enforces GLOBAL replay protection between two users", async () => {
  const model = new SimulatedPurchaseLedger();model.seedAccount("synthetic_uid_a");model.seedAccount("synthetic_uid_b");
  const v = await proof();
  model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: v });
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_b", expectedRevision: 0, proof: v }).code, "TOKEN_BOUND_TO_OTHER_ACCOUNT");
  assert.equal(model.readAccount("synthetic_uid_b").celestialJade, 0);
});

test("Synthetic ledger rejects forged product switch with reused Play token", async () => {
  const model = new SimulatedPurchaseLedger();model.seedAccount("synthetic_uid_a");
  const v = await proof();
  model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: v });
  // Same purchase token, different server-verified product: fingerprint must be global.
  const product100 = await proof({ response: purchase({ sku: "jade_pouch_100" }), sku: "jade_pouch_100" });
  assert.equal(v.fingerprint, product100.fingerprint);
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 1, proof: product100 }).code, "TOKEN_PRODUCT_MISMATCH");
  assert.equal(model.readAccount("synthetic_uid_a").celestialJade, 550);
});

test("Synthetic ledger prevents two-device stale CAS and overflow", async () => {
  const model = new SimulatedPurchaseLedger();model.seedAccount("synthetic_uid_a", 10);
  const a = await proof();
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: a }).code, "APPLIED");
  const b = await proof({ token: `${TOKEN}_SECOND` });
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: b }).code, "REVISION_CONFLICT");
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 1, proof: b }).code, "APPLIED");
  assert.equal(model.readAccount("synthetic_uid_a").revision, 2);
  const full = new SimulatedPurchaseLedger();full.seedAccount("synthetic_uid_a", Number.MAX_SAFE_INTEGER - 1);
  assert.equal(full.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: a }).code, "BALANCE_OVERFLOW");
  assert.equal(full.ledgerSize, 0);
});

test("Synthetic ledger still blocks earliest replay after 1200 unrelated grants", async () => {
  const model = new SimulatedPurchaseLedger();model.seedAccount("synthetic_uid_a");
  const first = await proof();
  let revision = 0;
  for (let i = 0; i < 1200; i++) {
    const v = i === 0 ? first : await proof({ token: `synthetic_qa_batch_${i}________________` });
    const result = model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: revision, proof: v });
    assert.equal(result.code, "APPLIED");
    revision += 1;
  }
  assert.equal(model.ledgerSize, 1200);
  assert.equal(model.eventCount, 1200);
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: first }).code, "ALREADY_APPLIED");
  assert.equal(model.readAccount("synthetic_uid_a").celestialJade, 1200 * 550);
});

test("Verified void fixtures are permanent tombstones, hold accounts, and never blindly debit", async () => {
  const model = new SimulatedPurchaseLedger();model.seedAccount("synthetic_uid_a");
  const first = await proof();
  assert.equal(model.recordSyntheticVerifiedVoid("not_a_fingerprint").code, "INVALID_VOID_FINGERPRINT");
  assert.equal(model.recordSyntheticVerifiedVoid(first.fingerprint).code, "VOID_RECONCILIATION_HOLD");
  assert.equal(model.recordSyntheticVerifiedVoid(first.fingerprint).code, "VOID_ALREADY_RECORDED");
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: first }).code, "ECONOMY_RECONCILIATION_HOLD");
  const other = await proof({ token: `${TOKEN}_OTHER` });
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 0, proof: other }).code, "APPLIED");
  assert.equal(model.recordSyntheticVerifiedVoid(other.fingerprint).code, "VOID_RECONCILIATION_HOLD");
  assert.equal(model.readAccount("synthetic_uid_a").hold, true);
  assert.equal(model.readAccount("synthetic_uid_a").celestialJade, 550);
  assert.equal(model.applyVerifiedFixture({ ownerUid: "synthetic_uid_a", expectedRevision: 1, proof: await proof({ token: `${TOKEN}_THIRD` }) }).code, "ECONOMY_RECONCILIATION_HOLD");
});

test("No new cloud purchase/grant callable or Firebase deploy; Spark and writes remain locked", () => {
  const entry = read("backend/cloud_save/functions/index.mjs");
  const gate = JSON.parse(read("backend/cloud_save/predeploy_gate.json"));
  assert.deepEqual(gate.approved_callable_exports, ["jadeCloudSaveCapabilities"]);
  assert.equal(gate.state, "PRE_DEPLOYMENT_ONLY");
  assert.equal(gate.deployment_approved, false);
  assert.equal(gate.cloud_mutations_approved, false);
  assert.equal(gate.firebase_project_id, null);
  assert.match(entry, /export const \{ jadeCloudSaveCapabilities \}/);
  assert.equal((entry.match(/\bexport\s+const\s*\{/g) ?? []).length, 1);
  assert.doesNotMatch(entry, /economy|purchase|ledger|refund|void/i);
  const newSources = [
    "backend/cloud_save/functions/src/economy/product_catalog.mjs",
    "backend/cloud_save/functions/src/economy/play_purchase_v2.mjs",
    "backend/cloud_save/functions/src/economy/ledger_reference.mjs",
  ].map(read).join("\n");
  assert.doesNotMatch(newSources, /\b(?:initializeApp|admin\.firestore|setDoc|writeBatch|runTransaction|firebase\s+deploy)\b/);
  const firestoreHarness = read("backend/cloud_save/functions/src/economy/firestore_gate5_emulator_model.mjs");
  assert.match(firestoreHarness, /assertGate5EmulatorOnly\(\)/);
  assert.match(firestoreHarness, /db\.runTransaction/);
  const cfg = JSON.parse(read("backend/cloud_save/firebase-gate5-emulator.json"));
  assert.deepEqual(cfg.emulators.firestore, { host: "127.0.0.1", port: 8080 });
  assert.deepEqual(cfg.firestore, { rules: "tests/gate5_emulator_deny.rules" });
  assert.match(read("backend/cloud_save/tests/gate5_emulator_deny.rules"), /allow read, write: if false;/);
  const workflow = read(".github/workflows/cloud-economy-gate5-qa.yml");
  assert.match(workflow, /--project demo-jade-cloud-save-gate5/);
  assert.match(workflow, /--only firestore/);
  assert.doesNotMatch(workflow, /\b(?:firebase|gcloud)\s+deploy\b/);
  assert.throws(() => assertGate5EmulatorOnly(), /GATE5_EMULATOR_ONLY/);
});
