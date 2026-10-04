import test from "node:test";
import assert from "node:assert/strict";
import {
  accountBindingForUid,
  authorizePurchase,
  PurchaseAuthorityError,
  tokenKeyForPurchaseToken,
} from "../src/purchase_authority.mjs";
import {
  listProducts,
  PACKAGE_NAME,
  productByInternalId,
  productByPlayId,
} from "../src/product_catalog.mjs";

const UID = "qa_guest_uid_123";
const OTHER_UID = "qa_guest_uid_other";
const TOKEN = "qa.purchase.token.0123456789abcdef";
const APP_ID = "1:1234567890:android:qa_fixture";

class FakeLedger {
  constructor() {
    this.records = new Map();
  }

  async runTransaction(key, callback) {
    const current = this.records.has(key)
      ? structuredClone(this.records.get(key))
      : null;
    const decision = await callback(current);
    assert.equal(typeof decision, "object");
    if (decision.nextRecord !== undefined) {
      this.records.set(key, structuredClone(decision.nextRecord));
    }
    return structuredClone(decision.result);
  }
}

class FakePlayGateway {
  constructor(purchase) {
    this.purchase = purchase;
    this.getCalls = [];
    this.consumeCalls = [];
    this.consumeError = null;
    this.purchaseAfterConsumeError = null;
  }

  async getProductPurchaseV2(packageName, purchaseToken) {
    this.getCalls.push({ packageName, purchaseToken });
    return structuredClone(this.purchase);
  }

  async consumeProduct(packageName, playProductId, purchaseToken) {
    this.consumeCalls.push({ packageName, playProductId, purchaseToken });
    if (this.consumeError) {
      if (this.purchaseAfterConsumeError) {
        this.purchase = structuredClone(this.purchaseAfterConsumeError);
      }
      throw this.consumeError;
    }
    this.purchase = playPurchase({
      consumptionState: "CONSUMPTION_STATE_CONSUMED",
      refundableQuantity: 0,
    });
  }
}

function request(uid = UID, data = { purchase_token: TOKEN }, provider = "anonymous") {
  return {
    auth: {
      uid,
      token: { firebase: { sign_in_provider: provider } },
    },
    app: { appId: APP_ID },
    data,
  };
}

function playPurchase({
  uid = UID,
  playProductId = "jade_pouch_100",
  state = "PURCHASED",
  consumptionState = "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
  quantity = 1,
  refundableQuantity = 1,
} = {}) {
  return {
    purchaseStateContext: { purchaseState: state },
    acknowledgementState: (
      consumptionState === "CONSUMPTION_STATE_CONSUMED"
        ? "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
        : "ACKNOWLEDGEMENT_STATE_PENDING"
    ),
    obfuscatedExternalAccountId: accountBindingForUid(uid),
    productLineItem: [{
      productId: playProductId,
      productOfferDetails: {
        quantity,
        refundableQuantity,
        consumptionState,
      },
    }],
  };
}

function expectCode(promise, code) {
  return assert.rejects(promise, error =>
    error instanceof PurchaseAuthorityError && error.code === code
  );
}

test("server product allowlist is exactly the six active Celestial Jade packs", () => {
  assert.deepEqual(listProducts(), [
    { internalProductId: "jade_pouch_100", playProductId: "jade_pouch_100", celestialJade: 100 },
    { internalProductId: "jade_satchel_550", playProductId: "jade_pouch_550", celestialJade: 550 },
    { internalProductId: "jade_casket_1200", playProductId: "jade_pouch_1200", celestialJade: 1200 },
    { internalProductId: "jade_vault_2500", playProductId: "jade_pouch_2500", celestialJade: 2500 },
    { internalProductId: "jade_treasury_6500", playProductId: "jade_pouch_6500", celestialJade: 6500 },
    { internalProductId: "jade_ascendant_14000", playProductId: "jade_pouch_14000", celestialJade: 14000 },
  ]);
  assert.equal(productByInternalId("starter_support_pack"), null);
  assert.equal(productByInternalId("monthly_jade_blessing"), null);
  assert.equal(productByPlayId("unknown"), null);
});

test("Firebase anonymous and Google identities are accepted, but App Check/auth are mandatory", async () => {
  for (const provider of ["anonymous", "google.com"]) {
    const result = await authorizePurchase({
      request: request(UID, { purchase_token: TOKEN }, provider),
      playGateway: new FakePlayGateway(playPurchase()),
      ledger: new FakeLedger(),
    });
    assert.equal(result.state, "grant_ready");
  }

  await expectCode(authorizePurchase({
    request: { data: { purchase_token: TOKEN }, app: { appId: APP_ID } },
    playGateway: new FakePlayGateway(playPurchase()),
    ledger: new FakeLedger(),
  }), "unauthenticated");

  await expectCode(authorizePurchase({
    request: request(UID, { purchase_token: TOKEN }, "password"),
    playGateway: new FakePlayGateway(playPurchase()),
    ledger: new FakeLedger(),
  }), "permission-denied");

  const noAppCheck = request();
  delete noAppCheck.app;
  await expectCode(authorizePurchase({
    request: noAppCheck,
    playGateway: new FakePlayGateway(playPurchase()),
    ledger: new FakeLedger(),
  }), "failed-precondition");
});

test("authorize accepts only an opaque purchase token; caller cannot inject product, amount, owner or finalization fields", async () => {
  for (const data of [
    {},
    { purchase_token: TOKEN, product_id: "jade_ascendant_14000" },
    { purchase_token: TOKEN, celestial_jade: 999999 },
    { purchase_token: TOKEN, uid: UID },
    { purchase_token: TOKEN, grant_id: `iapv1:${"a".repeat(64)}` },
    { purchase_token: "short" },
  ]) {
    await expectCode(authorizePurchase({
      request: request(UID, data),
      playGateway: new FakePlayGateway(playPurchase()),
      ledger: new FakeLedger(),
    }), "invalid-argument");
  }
});

test("server consumes before exposing a grant and derives product/amount only from Google Play", async () => {
  const ledger = new FakeLedger();
  const gateway = new FakePlayGateway(
    playPurchase({ playProductId: "jade_pouch_6500" }),
  );

  const result = await authorizePurchase({
    request: request(),
    playGateway: gateway,
    ledger,
  });

  assert.deepEqual(result, {
    purchase_contract_version: 1,
    state: "grant_ready",
    grant_id: result.grant_id,
    internal_product_id: "jade_treasury_6500",
    celestial_jade: 6500,
  });
  assert.match(result.grant_id, /^iapv1:[a-f0-9]{64}$/);
  assert.equal(gateway.consumeCalls.length, 1);
  assert.deepEqual(gateway.consumeCalls[0], {
    packageName: PACKAGE_NAME,
    playProductId: "jade_pouch_6500",
    purchaseToken: TOKEN,
  });
  assert.equal(
    ledger.records.get(tokenKeyForPurchaseToken(TOKEN)).state,
    "grant_ready",
  );
});

test("pending, cancelled, already-consumed, refunded, unknown, multi-line and quantity purchases fail closed on first use", async () => {
  const variants = [
    [playPurchase({ state: "PENDING" }), "failed-precondition"],
    [playPurchase({ state: "CANCELLED" }), "failed-precondition"],
    [playPurchase({
      consumptionState: "CONSUMPTION_STATE_CONSUMED",
      refundableQuantity: 0,
    }), "failed-precondition"],
    [playPurchase({ refundableQuantity: 0 }), "failed-precondition"],
    [playPurchase({ playProductId: "unknown_product" }), "permission-denied"],
    [playPurchase({ quantity: 2, refundableQuantity: 2 }), "failed-precondition"],
  ];

  const multi = playPurchase();
  multi.productLineItem.push(structuredClone(multi.productLineItem[0]));
  variants.push([multi, "failed-precondition"]);

  for (const [purchase, code] of variants) {
    await expectCode(authorizePurchase({
      request: request(),
      playGateway: new FakePlayGateway(purchase),
      ledger: new FakeLedger(),
    }), code);
  }
});

test("purchase must be bound to the authenticated Firebase UID", async () => {
  await expectCode(authorizePurchase({
    request: request(),
    playGateway: new FakePlayGateway(playPurchase({ uid: OTHER_UID })),
    ledger: new FakeLedger(),
  }), "permission-denied");
});

test("consume failure exposes no grant and leaves a recoverable pending server record", async () => {
  const ledger = new FakeLedger();
  const gateway = new FakePlayGateway(playPurchase());
  gateway.consumeError = new Error("synthetic network failure");

  await assert.rejects(authorizePurchase({
    request: request(),
    playGateway: gateway,
    ledger,
  }), /synthetic network failure/);

  const record = ledger.records.get(tokenKeyForPurchaseToken(TOKEN));
  assert.equal(record.state, "verified_pending_consume");
  assert.equal(gateway.consumeCalls.length, 1);
});

test("retry after a consume failure resumes the pending record and returns the same stable grant", async () => {
  const ledger = new FakeLedger();
  const firstGateway = new FakePlayGateway(playPurchase());
  firstGateway.consumeError = new Error("synthetic network failure");

  await assert.rejects(authorizePurchase({
    request: request(),
    playGateway: firstGateway,
    ledger,
  }));

  const pending = structuredClone(
    ledger.records.get(tokenKeyForPurchaseToken(TOKEN)),
  );

  const retryGateway = new FakePlayGateway(playPurchase());
  const result = await authorizePurchase({
    request: request(),
    playGateway: retryGateway,
    ledger,
  });

  assert.equal(result.state, "grant_ready");
  assert.equal(result.grant_id, pending.grantId);
  assert.equal(retryGateway.consumeCalls.length, 1);
});

test("consume-before-ledger crash is repaired without consuming twice", async () => {
  const ledger = new FakeLedger();
  const gateway = new FakePlayGateway(playPurchase());
  gateway.consumeError = new Error("synthetic process loss after Google consume");
  gateway.purchaseAfterConsumeError = playPurchase({
    consumptionState: "CONSUMPTION_STATE_CONSUMED",
    refundableQuantity: 0,
  });

  const result = await authorizePurchase({
    request: request(),
    playGateway: gateway,
    ledger,
  });

  assert.equal(result.state, "grant_ready");
  assert.equal(gateway.consumeCalls.length, 1);
  assert.equal(gateway.getCalls.length, 2);
  assert.equal(
    ledger.records.get(tokenKeyForPurchaseToken(TOKEN)).state,
    "grant_ready",
  );
});

test("grant-ready replay is idempotent and does not call Google Play again", async () => {
  const ledger = new FakeLedger();
  const firstGateway = new FakePlayGateway(playPurchase());
  const first = await authorizePurchase({
    request: request(),
    playGateway: firstGateway,
    ledger,
  });

  const replayGateway = new FakePlayGateway(playPurchase({
    state: "CANCELLED",
  }));
  const replay = await authorizePurchase({
    request: request(),
    playGateway: replayGateway,
    ledger,
  });

  assert.deepEqual(replay, first);
  assert.equal(replayGateway.getCalls.length, 0);
  assert.equal(replayGateway.consumeCalls.length, 0);
});

test("cross-account replay is denied before any Google Play call", async () => {
  const ledger = new FakeLedger();
  await authorizePurchase({
    request: request(),
    playGateway: new FakePlayGateway(playPurchase()),
    ledger,
  });

  const attackerGateway = new FakePlayGateway(
    playPurchase({ uid: OTHER_UID }),
  );
  await expectCode(authorizePurchase({
    request: request(OTHER_UID),
    playGateway: attackerGateway,
    ledger,
  }), "permission-denied");

  assert.equal(attackerGateway.getCalls.length, 0);
  assert.equal(attackerGateway.consumeCalls.length, 0);
});

test("ledger product/token tampering fails closed", async () => {
  const ledger = new FakeLedger();
  await authorizePurchase({
    request: request(),
    playGateway: new FakePlayGateway(playPurchase()),
    ledger,
  });

  const key = tokenKeyForPurchaseToken(TOKEN);
  const corrupt = structuredClone(ledger.records.get(key));
  corrupt.celestialJade = 14000;
  ledger.records.set(key, corrupt);

  await expectCode(authorizePurchase({
    request: request(),
    playGateway: new FakePlayGateway(playPurchase()),
    ledger,
  }), "internal");
});

test("raw purchase token is neither the ledger key nor persisted inside the ledger record", async () => {
  const ledger = new FakeLedger();
  await authorizePurchase({
    request: request(),
    playGateway: new FakePlayGateway(playPurchase()),
    ledger,
  });

  assert.equal(ledger.records.has(TOKEN), false);
  const record = ledger.records.get(tokenKeyForPurchaseToken(TOKEN));
  assert.ok(record);
  assert.equal(JSON.stringify(record).includes(TOKEN), false);
});
