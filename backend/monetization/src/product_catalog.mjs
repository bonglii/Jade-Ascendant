export const PACKAGE_NAME = "com.yungdevstudio.jadeascendant";
export const PURCHASE_CONTRACT_VERSION = 1;

const PRODUCTS = Object.freeze({
  heavenly_trials_support_550: Object.freeze({internalProductId:"heavenly_trials_support_550",playProductId:"heavenly_trials_support_550",celestialJade:550}),
  jade_pouch_100: Object.freeze({
    internalProductId: "jade_pouch_100",
    playProductId: "jade_pouch_100",
    celestialJade: 100,
  }),
  jade_satchel_550: Object.freeze({
    internalProductId: "jade_satchel_550",
    playProductId: "jade_pouch_550",
    celestialJade: 550,
  }),
  jade_casket_1200: Object.freeze({
    internalProductId: "jade_casket_1200",
    playProductId: "jade_pouch_1200",
    celestialJade: 1200,
  }),
  jade_vault_2500: Object.freeze({
    internalProductId: "jade_vault_2500",
    playProductId: "jade_pouch_2500",
    celestialJade: 2500,
  }),
  jade_treasury_6500: Object.freeze({
    internalProductId: "jade_treasury_6500",
    playProductId: "jade_pouch_6500",
    celestialJade: 6500,
  }),
  jade_ascendant_14000: Object.freeze({
    internalProductId: "jade_ascendant_14000",
    playProductId: "jade_pouch_14000",
    celestialJade: 14000,
  }),
});

export const FIRST_TOPUP_PRODUCTS = Object.freeze(Object.values(PRODUCTS)
  .filter(product => product.internalProductId !== "heavenly_trials_support_550")
  .map(product => Object.freeze({internalProductId: product.internalProductId,
    playProductId: `jade_topup_${product.celestialJade / 2}_v2`,
    celestialJade: product.celestialJade / 2, firstTopupBonus: product.celestialJade / 2})));

const BY_PLAY_ID = Object.freeze(Object.fromEntries(
  [...Object.values(PRODUCTS), ...FIRST_TOPUP_PRODUCTS].map(product => [product.playProductId, product]),
));
export function firstTopupProduct(internalId) {
  const product = FIRST_TOPUP_PRODUCTS.find(p => p.internalProductId === internalId);
  return product ? {...product} : null;
}

export function listProducts() {
  return Object.values(PRODUCTS).map(product => ({ ...product }));
}

export function productByPlayId(playProductId) {
  const product = BY_PLAY_ID[playProductId];
  return product ? { ...product } : null;
}

export function productByInternalId(internalProductId) {
  const product = PRODUCTS[internalProductId];
  return product ? { ...product } : null;
}
