/**
 * Gate 5 — SERVER-SIDE purchase verification primitives, NOT an exported route.
 * Production use must inject a Google-authorized Android Publisher reader and
 * a backend-only account binding + HMAC secret. Test readers are NOT proof.
 * There is no Firebase Admin SDK import, save, Firestore or billing mutation.
 */
import { createHmac } from "node:crypto";
import { ACTIVE_PLAY_PRODUCTS, ANDROID_PACKAGE, getActivePlayProduct } from "./product_catalog.mjs";

const PROOF_MARK = Symbol("trusted_play_v2_qa_proof");
const TOKEN_MIN = 8;
const TOKEN_MAX = 4096;
const GOOGLE_API_ORIGIN = "https://androidpublisher.googleapis.com";
const ALLOWED_ACK = new Set([
  "ACKNOWLEDGEMENT_STATE_PENDING",
  "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
]);

/** Safe error codes only. Never echo credentials, purchase tokens or responses. */
export class PurchasePolicyError extends Error {
  constructor(code) {
    super(code);
    this.name = "PurchasePolicyError";
    this.code = code;
  }
}

function deny(code) { throw new PurchasePolicyError(code); }
function plain(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}
function validToken(token) {
  return typeof token === "string"
    && token.length >= TOKEN_MIN && token.length <= TOKEN_MAX
    && token.trim() === token && !/[\x00-\x1f\x7f]/.test(token);
}
function validBinding(binding) {
  return typeof binding === "string" && /^[a-f0-9]{64}$/.test(binding);
}
function validKey(key) {
  return Buffer.isBuffer(key) && key.length >= 32;
}
function singlePositiveInt(value) {
  return Number.isSafeInteger(value) && value === 1;
}

/**
 * An actual GET-only Google Play API V2 reader, configured only by a server.
 * The caller provides an OAuth2 token provider scoped to androidpublisher;
 * no ADC, service-account key, or ambient network access exists by default.
 * `fetchImpl` must be explicitly injected, so test jobs cannot call Google.
 */
export function createPlayProductsV2Reader({ fetchImpl, getAccessToken } = {}) {
  if (typeof fetchImpl !== "function" || typeof getAccessToken !== "function") {
    deny("SERVER_READER_NOT_CONFIGURED");
  }
  return Object.freeze({
    async getPurchase(purchaseToken) {
      if (!validToken(purchaseToken)) deny("INVALID_TOKEN");
      let bearer;
      try {
        bearer = await getAccessToken();
      } catch {
        deny("PLAY_AUTH_UNAVAILABLE");
      }
      if (typeof bearer !== "string" || bearer.length < 8 || /[\x00-\x20\x7f]/.test(bearer)) {
        deny("PLAY_AUTH_UNAVAILABLE");
      }
      const path = `/androidpublisher/v3/applications/${ANDROID_PACKAGE}`
        + `/purchases/productsv2/tokens/${encodeURIComponent(purchaseToken)}`;
      let response;
      try {
        response = await fetchImpl(new URL(path, GOOGLE_API_ORIGIN).toString(), {
          method: "GET",
          headers: { Authorization: `Bearer ${bearer}`, Accept: "application/json" },
          signal: AbortSignal.timeout(8000),
          redirect: "error",
        });
      } catch {
        deny("PLAY_API_UNAVAILABLE");
      }
      if (response?.status === 404) deny("PLAY_PURCHASE_NOT_FOUND");
      if (response?.ok !== true) deny("PLAY_API_UNAVAILABLE");
      try {
        const body = await response.json();
        if (!plain(body)) deny("PLAY_RESPONSE_INVALID");
        return body;
      } catch {
        deny("PLAY_RESPONSE_INVALID");
      }
    },
  });
}

/**
 * Check a Google Play Developer API ProductPurchaseV2 response obtained via
 * a trusted server reader. The response is NOT accepted from the client.
 * Only quantity=1, unconsumed, non-refunded, non-test Jade packs are supported.
 * Multi-quantity and old purchases without account binding remain on HOLD.
 */
export async function verifyPlayPurchaseV2({
  reader,
  purchaseToken,
  playProductId,
  expectedObfuscatedAccountId,
  fingerprintSecret,
  allowLicenseTester = false,
} = {}) {
  const sku = getActivePlayProduct(playProductId);
  if (!sku) deny("UNSUPPORTED_PRODUCT");
  if (!validToken(purchaseToken)) deny("INVALID_TOKEN");
  if (!validBinding(expectedObfuscatedAccountId)) deny("ACCOUNT_BINDING_REQUIRED");
  if (!validKey(fingerprintSecret)) deny("LEDGER_KEY_UNAVAILABLE");
  if (!reader || typeof reader.getPurchase !== "function") deny("SERVER_READER_NOT_CONFIGURED");
  if (typeof allowLicenseTester !== "boolean") deny("TEST_POLICY_INVALID");

  let response;
  try {
    response = await reader.getPurchase(purchaseToken);
  } catch (error) {
    if (error instanceof PurchasePolicyError) throw error;
    deny("PLAY_API_UNAVAILABLE");
  }
  if (!plain(response)) deny("PLAY_RESPONSE_INVALID");
  if (response.kind !== "androidpublisher#productPurchaseV2") deny("PLAY_RESPONSE_INVALID");
  if (response.packageName !== undefined && response.packageName !== ANDROID_PACKAGE) {
    deny("PACKAGE_MISMATCH");
  }
  if (!plain(response.purchaseStateContext)) deny("PLAY_RESPONSE_INVALID");
  if (response.purchaseStateContext.purchaseState !== "PURCHASED") {
    deny("PURCHASE_NOT_COMPLETED");
  }
  if (typeof response.purchaseCompletionTime !== "string"
      || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:\d{2})$/.test(response.purchaseCompletionTime)
      || !Number.isFinite(Date.parse(response.purchaseCompletionTime))) {
    deny("PURCHASE_TIME_MISSING");
  }
  if (response.obfuscatedExternalAccountId !== expectedObfuscatedAccountId) {
    deny("ACCOUNT_BINDING_MISMATCH");
  }
  if (response.testPurchaseContext !== undefined) {
    if (!allowLicenseTester || !plain(response.testPurchaseContext)
        || response.testPurchaseContext.fopType !== "TEST") {
      deny("TEST_PURCHASE_NOT_ALLOWED");
    }
  }
  if (!ALLOWED_ACK.has(response.acknowledgementState)) deny("ACKNOWLEDGEMENT_UNKNOWN");
  if (!Array.isArray(response.productLineItem) || response.productLineItem.length !== 1) {
    deny("MULTI_LINE_PURCHASE_UNSUPPORTED");
  }
  const line = response.productLineItem[0];
  if (!plain(line) || line.productId !== sku.playProductId) {
    deny("PLAY_PRODUCT_MISMATCH");
  }
  if (!plain(line.productOfferDetails)) deny("PLAY_RESPONSE_INVALID");
  const offer = line.productOfferDetails;
  if (Object.hasOwn(offer, "rentOfferDetails")
      || Object.hasOwn(offer, "preorderOfferDetails")) {
    deny("UNSUPPORTED_OFFER");
  }
  if (!singlePositiveInt(offer.quantity)) deny("UNSUPPORTED_QUANTITY");
  if (!singlePositiveInt(offer.refundableQuantity)) deny("REFUND_RECONCILIATION_REQUIRED");
  if (offer.consumptionState !== "CONSUMPTION_STATE_YET_TO_BE_CONSUMED") {
    deny("PURCHASE_ALREADY_CONSUMED");
  }

  // Cross-product token reuse must map to the SAME global deduplication key.
  // Token never enters the proof/ledger; HMAC key is server-only and stable.
  const fingerprint = createHmac("sha256", fingerprintSecret)
    .update(`${ANDROID_PACKAGE}\x00${purchaseToken}`, "utf8")
    .digest("hex");
  return Object.freeze({
    [PROOF_MARK]: true,
    fingerprint,
    productId: sku.internalId,
    playProductId: sku.playProductId,
    celestialJade: sku.celestialJade,
    pavilionSeals: sku.pavilionSeals,
    kind: sku.kind,
  });
}

/** Internal-only provenance check used by the QA ledger model. */
export function isVerifiedGate5Proof(proof) {
  return proof != null && proof[PROOF_MARK] === true
    && Object.isFrozen(proof) && typeof proof.fingerprint === "string"
    && /^[a-f0-9]{64}$/.test(proof.fingerprint)
    && Object.values(ACTIVE_PLAY_PRODUCTS).some(p => p.internalId === proof.productId
      && p.playProductId === proof.playProductId && p.celestialJade === proof.celestialJade);
}
