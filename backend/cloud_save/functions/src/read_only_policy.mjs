/**
 * Jade Ascendant — Gate 4 server-boundary policy.
 * Runs ONLY behind a Firebase Functions v2 onCall request whose `auth` field
 * is supplied by the Firebase callable runtime, NOT a field from `data`.
 * This module has no Firebase imports, network calls, or persistence.
 */

export const CAPABILITIES_CONTRACT_VERSION = 1;

export class CloudBoundaryError extends Error {
  constructor(code, message) {
    super(message);
    this.name = "CloudBoundaryError";
    this.code = code;
  }
}

const SAFE_UID = /^[A-Za-z0-9_-]{1,128}$/;
const PRIVATE_RESPONSE = Object.freeze({
  capabilities_contract_version: CAPABILITIES_CONTRACT_VERSION,
  state: "cloud_save_disabled",
  cloud_write_enabled: false,
  cloud_restore_enabled: false,
  purchase_verification_enabled: false,
  economy_verified: false,
  server_revision_verified: false,
  server_freshness_verified: false,
});

function plainRecord(value) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

/**
 * Never accept owner_uid, currencies, tokens, revisions or other data from
 * the calling device. This intentionally accepts an empty object ONLY.
 */
function requireEmptyData(data) {
  if (!plainRecord(data) || Reflect.ownKeys(data).length !== 0) {
    throw new CloudBoundaryError("invalid-argument", "Unsupported cloud request payload.");
  }
}

/**
 * Firebase onCall must verify Firebase Auth before populating request.auth.
 * Require a Google identity as well as a non-anonymous provider claim.
 * This is ONLY an identity check, never a purchase or save verification.
 */
function requireGoogleIdentity(request) {
  const auth = request?.auth;
  if (!auth || typeof auth !== "object" || typeof auth.uid !== "string"
      || !SAFE_UID.test(auth.uid)) {
    throw new CloudBoundaryError("unauthenticated", "Google sign-in is required.");
  }
  const firebaseClaims = auth.token?.firebase;
  if (!plainRecord(firebaseClaims)
      || firebaseClaims.sign_in_provider !== "google.com") {
    throw new CloudBoundaryError("permission-denied", "A Google-linked account is required.");
  }
  const googleIdentities = firebaseClaims.identities?.["google.com"];
  if (!Array.isArray(googleIdentities)
      || googleIdentities.length === 0
      || !googleIdentities.every(value => typeof value === "string" && value.length > 0)) {
    throw new CloudBoundaryError("permission-denied", "A Google-linked account is required.");
  }
  return auth.uid;
}

/** This is the ONLY callable operation registered in Gate 4. */
export function readCloudSaveCapabilities(request) {
  requireGoogleIdentity(request);
  requireEmptyData(request?.data);
  // Never echo UID, email, tokens or client fields. No game/save file access.
  return { ...PRIVATE_RESPONSE };
}

/**
 * An explicit fail-closed guard for future integration code. It does not
 * register a callable route, and must not be wired as a mutation endpoint.
 */
export function rejectCloudMutation() {
  throw new CloudBoundaryError(
    "failed-precondition",
    "Cloud Save mutations require a deployed trusted economy backend."
  );
}
