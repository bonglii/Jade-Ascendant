import test from "node:test";
import assert from "node:assert/strict";
import { createFirestoreLedger, PURCHASE_LEDGER_COLLECTION } from "../src/firestore_ledger.mjs";
import { createGooglePlayGateway } from "../src/google_play_gateway.mjs";
import { PurchaseAuthorityError } from "../src/purchase_authority.mjs";

const TOKEN = "qa.purchase.token.0123456789abcdef";
const KEY = `playtoken:${"a".repeat(64)}`;

test("Firestore ledger persists only hashed key and preserves existing data", async () => {
  const rows = new Map();
  let name;
  const db = {
    collection(collectionName) {
      name = collectionName;
      return { doc: key => ({ key }) };
    },
    runTransaction(callback) {
      return callback({
        get: async ref => ({ exists: rows.has(ref.key), data: () => rows.get(ref.key) }),
        set: (ref, value) => rows.set(ref.key, structuredClone(value)),
      });
    },
  };
  const ledger = createFirestoreLedger(db);
  const first = await ledger.runTransaction(KEY, old => ({
    nextRecord: { count: (old?.count ?? 0) + 1 }, result: "created",
  }));
  const second = await ledger.runTransaction(KEY, old => ({ result: old.count }));
  assert.equal(first, "created");
  assert.equal(second, 1);
  assert.equal(name, PURCHASE_LEDGER_COLLECTION);
  assert.deepEqual(rows.get(KEY), { count: 1 });
  assert.equal(JSON.stringify([...rows]).includes(TOKEN), false);
  await assert.rejects(ledger.runTransaction(TOKEN, () => ({})), /Invalid purchase ledger key/);
});

test("Google Play gateway calls official V2 verify and consumption endpoints", async () => {
  const calls = [];
  const client = {
    async request(args) {
      calls.push(args);
      return { data: { purchaseStateContext: { purchaseState: "PURCHASED" } } };
    },
  };
  const gateway = createGooglePlayGateway(client);
  const result = await gateway.getProductPurchaseV2("com.yungdevstudio.jadeascendant", TOKEN);
  await gateway.consumeProduct("com.yungdevstudio.jadeascendant", "jade_pouch_100", TOKEN);
  assert.equal(result.purchaseStateContext.purchaseState, "PURCHASED");
  assert.equal(calls.length, 2);
  assert.equal(calls[0].method, "GET");
  assert.match(calls[0].url, /purchases\/productsv2\/tokens\//);
  assert.equal(calls[1].method, "POST");
  assert.match(calls[1].url, /purchases\/products\/jade_pouch_100\/tokens\/.+:consume$/);
});

test("Google Play failures never leak raw tokens in error messages", async () => {
  const client = { request: async () => {
    const e = new Error(`Secret leaked: ${TOKEN}`);
    e.response = { status: 403 };
    throw e;
  } };
  const gateway = createGooglePlayGateway(client);
  await assert.rejects(
    gateway.getProductPurchaseV2("com.yungdevstudio.jadeascendant", TOKEN),
    error => error instanceof PurchaseAuthorityError && error.code === "unavailable"
      && !error.message.includes(TOKEN),
  );
});
