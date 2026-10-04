import { createHash } from "node:crypto";
import {
  PACKAGE_NAME,
  PURCHASE_CONTRACT_VERSION,
  productByInternalId,
  productByPlayId,
} from "./product_catalog.mjs";

export class PurchaseAuthorityError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "PurchaseAuthorityError";
    this.code = code;
  }
}

const SAFE_UID = /^[A-Za-z0-9_-]{1,128}$/;
const SAFE_GRANT_ID = /^iapv1:[a-f0-9]{64}$/;
const PURCHASE_TOKEN = /^[\x21-\x7E]{16,4096}$/;
const ALLOWED_PROVIDERS = new Set(["anonymous", "google.com"]);
const STATE_PENDING_CONSUME = "verified_pending_consume";
const STATE_GRANT_READY = "grant_ready";

function plainRecord(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function requireRuntimeRequest(request) {
  const auth = request?.auth;
  if (!plainRecord(auth) || typeof auth.uid !== "string" || !SAFE_UID.test(auth.uid)) {
    throw new PurchaseAuthorityError("unauthenticated", "Firebase authentication is required.");
  }

  const firebaseClaims = auth.token?.firebase;
  const provider = firebaseClaims?.sign_in_provider;
  if (!plainRecord(firebaseClaims) || !ALLOWED_PROVIDERS.has(provider)) {
    throw new PurchaseAuthorityError("permission-denied", "Unsupported authentication provider.");
  }

  const app = request?.app;
  if (!plainRecord(app) || typeof app.appId !== "string" || app.appId.length < 6) {
    throw new PurchaseAuthorityError("failed-precondition", "App Check is required.");
  }

  return auth.uid;
}

function requirePayload(data) {
  if (!plainRecord(data)) {
    throw new PurchaseAuthorityError("invalid-argument", "Invalid purchase request.");
  }
  const keys = Reflect.ownKeys(data);
  if (keys.length !== 1 || keys[0] !== "purchase_token") {
    throw new PurchaseAuthorityError("invalid-argument", "Unsupported purchase request payload.");
  }
}

function requirePurchaseToken(value) {
  if (typeof value !== "string" || !PURCHASE_TOKEN.test(value)) {
    throw new PurchaseAuthorityError("invalid-argument", "Invalid purchase token.");
  }
  return value;
}

function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function accountBindingForUid(uid) {
  if (typeof uid !== "string" || !SAFE_UID.test(uid)) {
    throw new TypeError("A valid Firebase UID is required.");
  }
  return sha256(uid);
}

export function tokenKeyForPurchaseToken(purchaseToken) {
  return `playtoken:${sha256(requirePurchaseToken(purchaseToken))}`;
}

function grantIdForPurchaseToken(purchaseToken) {
  return `iapv1:${sha256(requirePurchaseToken(purchaseToken))}`;
}

function requireDependency(object, method, label) {
  if (!object || typeof object[method] !== "function") {
    throw new TypeError(`${label}.${method} is required.`);
  }
}

function requirePlayEnvelope(raw) {
  if (!plainRecord(raw)) {
    throw new PurchaseAuthorityError("unavailable", "Google Play verification returned no purchase.");
  }
  if (raw.purchaseStateContext?.purchaseState !== "PURCHASED") {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase is not completed.");
  }
  if (!Array.isArray(raw.productLineItem) || raw.productLineItem.length !== 1) {
    throw new PurchaseAuthorityError("failed-precondition", "Unsupported purchase line items.");
  }
  const line = raw.productLineItem[0];
  if (!plainRecord(line) || typeof line.productId !== "string") {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase product is missing.");
  }
  const offer = line.productOfferDetails;
  if (!plainRecord(offer)) {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase offer details are missing.");
  }
  if (offer.quantity !== 1) {
    throw new PurchaseAuthorityError("failed-precondition", "Unsupported purchase quantity.");
  }
  return { line, offer };
}

function candidateFromFreshPurchase(raw, uid, purchaseToken) {
  const { line, offer } = requirePlayEnvelope(raw);
  const expectedBinding = accountBindingForUid(uid);
  if (raw.obfuscatedExternalAccountId !== expectedBinding) {
    throw new PurchaseAuthorityError("permission-denied", "Purchase account binding does not match.");
  }
  if (offer.refundableQuantity !== 1) {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase is not fully refundable.");
  }
  if (offer.consumptionState !== "CONSUMPTION_STATE_YET_TO_BE_CONSUMED") {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase is already consumed.");
  }

  const product = productByPlayId(line.productId);
  if (!product) {
    throw new PurchaseAuthorityError("permission-denied", "Purchase product is not allowed.");
  }

  return {
    contractVersion: PURCHASE_CONTRACT_VERSION,
    tokenKey: tokenKeyForPurchaseToken(purchaseToken),
    grantId: grantIdForPurchaseToken(purchaseToken),
    ownerUid: uid,
    ownerBinding: expectedBinding,
    internalProductId: product.internalProductId,
    playProductId: product.playProductId,
    celestialJade: product.celestialJade,
    state: STATE_PENDING_CONSUME,
  };
}

function requireLedgerRecord(record, purchaseToken, uid) {
  if (!plainRecord(record)
      || record.contractVersion !== PURCHASE_CONTRACT_VERSION
      || typeof record.tokenKey !== "string"
      || typeof record.grantId !== "string"
      || !SAFE_GRANT_ID.test(record.grantId)
      || typeof record.ownerUid !== "string"
      || typeof record.ownerBinding !== "string"
      || typeof record.internalProductId !== "string"
      || typeof record.playProductId !== "string"
      || !Number.isSafeInteger(record.celestialJade)
      || record.celestialJade <= 0
      || ![STATE_PENDING_CONSUME, STATE_GRANT_READY].includes(record.state)) {
    throw new PurchaseAuthorityError("internal", "Purchase ledger record is invalid.");
  }

  const tokenKey = tokenKeyForPurchaseToken(purchaseToken);
  const grantId = grantIdForPurchaseToken(purchaseToken);
  if (record.tokenKey !== tokenKey || record.grantId !== grantId) {
    throw new PurchaseAuthorityError("internal", "Purchase ledger token binding is invalid.");
  }
  if (record.ownerUid !== uid || record.ownerBinding !== accountBindingForUid(uid)) {
    throw new PurchaseAuthorityError("permission-denied", "Purchase token belongs to another account.");
  }

  const byInternal = productByInternalId(record.internalProductId);
  const byPlay = productByPlayId(record.playProductId);
  if (!byInternal || !byPlay
      || byInternal.internalProductId !== byPlay.internalProductId
      || byInternal.playProductId !== record.playProductId
      || byInternal.celestialJade !== record.celestialJade) {
    throw new PurchaseAuthorityError("internal", "Purchase ledger product binding is invalid.");
  }
  return record;
}

function requireMatchingCandidate(existing, candidate, purchaseToken, uid) {
  requireLedgerRecord(existing, purchaseToken, uid);
  if (
    existing.internalProductId !== candidate.internalProductId
    || existing.playProductId !== candidate.playProductId
    || existing.grantId !== candidate.grantId
    || existing.celestialJade !== candidate.celestialJade
  ) {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase ledger mismatch.");
  }
  return existing;
}

function publicGrant(record) {
  if (record.state !== STATE_GRANT_READY) {
    throw new PurchaseAuthorityError("internal", "Purchase grant is not ready.");
  }
  return {
    purchase_contract_version: record.contractVersion,
    state: STATE_GRANT_READY,
    grant_id: record.grantId,
    internal_product_id: record.internalProductId,
    celestial_jade: record.celestialJade,
  };
}

function verifyPurchaseAgainstLedger(raw, uid, record) {
  const { line, offer } = requirePlayEnvelope(raw);
  if (raw.obfuscatedExternalAccountId !== accountBindingForUid(uid)) {
    throw new PurchaseAuthorityError("permission-denied", "Purchase account binding does not match.");
  }
  if (line.productId !== record.playProductId) {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase product changed.");
  }
  if (![
    "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
    "CONSUMPTION_STATE_CONSUMED",
  ].includes(offer.consumptionState)) {
    throw new PurchaseAuthorityError("failed-precondition", "Unknown purchase consumption state.");
  }
  if (
    offer.consumptionState === "CONSUMPTION_STATE_YET_TO_BE_CONSUMED"
    && offer.refundableQuantity !== 1
  ) {
    throw new PurchaseAuthorityError("failed-precondition", "Purchase is not fully refundable.");
  }
  return offer.consumptionState;
}

async function consumeOrConfirmConsumed({ playGateway, purchaseToken, uid, record, verified }) {
  const initialState = verifyPurchaseAgainstLedger(verified, uid, record);
  if (initialState === "CONSUMPTION_STATE_CONSUMED") {
    return;
  }

  try {
    await playGateway.consumeProduct(
      PACKAGE_NAME,
      record.playProductId,
      purchaseToken,
    );
    return;
  } catch (consumeError) {
    // Concurrent requests or a process crash may mean Google consumed the item
    // even though this specific call failed. Re-read before deciding whether the
    // authorization remains pending.
    const afterFailure = await playGateway.getProductPurchaseV2(
      PACKAGE_NAME,
      purchaseToken,
    );
    const afterState = verifyPurchaseAgainstLedger(
      afterFailure,
      uid,
      record,
    );
    if (afterState === "CONSUMPTION_STATE_CONSUMED") {
      return;
    }
    throw consumeError;
  }
}

/**
 * Returns a grant only after:
 * 1) Firebase Auth + App Check context is present,
 * 2) Google Play verifies the bound purchase,
 * 3) a durable server ledger records the verified entitlement, and
 * 4) Google Play reports the consumable consumed (or the consume call succeeds).
 *
 * The client never has finalization/consume authority. If the local save later
 * fails, replaying the same token returns the same durable grant ID.
 */
export async function authorizePurchase({ request, playGateway, ledger }) {
  requireDependency(playGateway, "getProductPurchaseV2", "playGateway");
  requireDependency(playGateway, "consumeProduct", "playGateway");
  requireDependency(ledger, "runTransaction", "ledger");

  const uid = requireRuntimeRequest(request);
  requirePayload(request.data);
  const purchaseToken = requirePurchaseToken(request.data.purchase_token);
  const tokenKey = tokenKeyForPurchaseToken(purchaseToken);

  const initial = await ledger.runTransaction(tokenKey, async existing => {
    if (existing === null || existing === undefined) {
      return { result: { mode: "new" } };
    }

    const record = requireLedgerRecord(existing, purchaseToken, uid);
    if (record.state === STATE_GRANT_READY) {
      return {
        nextRecord: record,
        result: { mode: "ready", grant: publicGrant(record) },
      };
    }
    return {
      nextRecord: record,
      result: { mode: "resume", record: { ...record } },
    };
  });

  if (initial.mode === "ready") {
    return initial.grant;
  }

  let record;
  let verified;

  if (initial.mode === "new") {
    verified = await playGateway.getProductPurchaseV2(
      PACKAGE_NAME,
      purchaseToken,
    );
    const candidate = candidateFromFreshPurchase(
      verified,
      uid,
      purchaseToken,
    );

    const persisted = await ledger.runTransaction(tokenKey, async existing => {
      if (existing === null || existing === undefined) {
        return {
          nextRecord: candidate,
          result: { ...candidate },
        };
      }

      const record = requireMatchingCandidate(
        existing,
        candidate,
        purchaseToken,
        uid,
      );
      return {
        nextRecord: record,
        result: { ...record },
      };
    });

    record = requireLedgerRecord(
      persisted,
      purchaseToken,
      uid,
    );
    if (record.state === STATE_GRANT_READY) {
      return publicGrant(record);
    }
  } else {
    record = requireLedgerRecord(
      initial.record,
      purchaseToken,
      uid,
    );
  }

  if (verified === undefined) {
    verified = await playGateway.getProductPurchaseV2(
      PACKAGE_NAME,
      purchaseToken,
    );
  }

  await consumeOrConfirmConsumed({
    playGateway,
    purchaseToken,
    uid,
    record,
    verified,
  });

  return ledger.runTransaction(tokenKey, async existing => {
    const latest = requireLedgerRecord(
      existing,
      purchaseToken,
      uid,
    );
    if (latest.state === STATE_GRANT_READY) {
      return {
        nextRecord: latest,
        result: publicGrant(latest),
      };
    }

    const ready = {
      ...latest,
      state: STATE_GRANT_READY,
    };
    return {
      nextRecord: ready,
      result: publicGrant(ready),
    };
  });
}
