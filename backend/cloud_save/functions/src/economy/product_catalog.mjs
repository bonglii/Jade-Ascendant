/**
 * Gate 5 — server-owned product allowlist. No price, credential or purchase
 * entitlement can be supplied by a device. NOT wired to a public callable.
 * Audited against economy_catalog.gd, google_play_billing_provider.gd and
 * release/GOOGLE_PLAY_IAP_SETUP.md at a06042f43ce55587d6439db9f3c7de742eb38915.
 */
export const ANDROID_PACKAGE = "com.yungdevstudio.jadeascendant";

const entries = [
  ["jade_pouch_100", "jade_pouch_100", 100],
  ["jade_satchel_550", "jade_pouch_550", 550],
  ["jade_casket_1200", "jade_pouch_1200", 1200],
  ["jade_vault_2500", "jade_pouch_2500", 2500],
  ["jade_treasury_6500", "jade_pouch_6500", 6500],
  ["jade_ascendant_14000", "jade_pouch_14000", 14000],
];

const catalog = Object.create(null);
for (const [internalId, playProductId, celestialJade] of entries) {
  catalog[playProductId] = Object.freeze({
    internalId,
    playProductId,
    celestialJade,
    pavilionSeals: 0,
    kind: "consumable",
  });
}
export const ACTIVE_PLAY_PRODUCTS = Object.freeze(catalog);

/** Unknown, disabled, subscription and unsupported one-time products fail closed. */
export function getActivePlayProduct(playProductId) {
  if (typeof playProductId !== "string"
      || !Object.hasOwn(ACTIVE_PLAY_PRODUCTS, playProductId)) {
    return null;
  }
  return ACTIVE_PLAY_PRODUCTS[playProductId];
}
