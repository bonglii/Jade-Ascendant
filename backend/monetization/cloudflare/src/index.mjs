/** Jade Ascendant IAP — Cloudflare Workers predeploy candidate.
 * NOT enabled, NOT deployed, NOT wired to Android. All paid grants fail closed by default.
 */
import { verifyFirebaseHeaders } from "./jwt_verify.mjs";
import { createPaidWalletReadHandlerM8 } from "./paid_wallet_read_route_m8.mjs";
import { createSummonRecoveryHandlerM11 } from "./summon_recovery_route_m11.mjs";
import { createPaidPurchaseCreditHandlerM13 } from "./paid_purchase_credit_route_m13.mjs";
import { createPaidSummonWriteHandlerRC } from "./paid_summon_write_route_rc.mjs";
import { createPaidEntitlementsReadHandlerRC } from "./paid_entitlements_read_route_rc.mjs";

const noStore = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff" };
function json(body, status) { return new Response(JSON.stringify(body), { status, headers: noStore }); }
export function createWorkerHandler({ verifyIdentity = verifyFirebaseHeaders, makePaidWalletRead = createPaidWalletReadHandlerM8, makeSummonRecovery = createSummonRecoveryHandlerM11, makePaidPurchaseCredit = createPaidPurchaseCreditHandlerM13, makePaidSummon = createPaidSummonWriteHandlerRC, makePaidEntitlements = createPaidEntitlementsReadHandlerRC } = {}) {
  const paidWalletRead = makePaidWalletRead({ verifyIdentity });
  const summonRecovery = makeSummonRecovery({ verifyIdentity });
  const paidPurchaseCredit = makePaidPurchaseCredit({ verifyIdentity });
  const paidSummon = makePaidSummon({ verifyIdentity });
  const paidEntitlements = makePaidEntitlements({ verifyIdentity });
  return async function handler(request, env) {
    const path = new URL(request.url).pathname;
    // Read-only, independently gated by JADE_PAID_WALLET_READ_ENABLED.
    // Not a purchase, credit, debit or refund endpoint.
    if (path === "/v1/wallet/paid") return paidWalletRead(request, env);
    if (path.startsWith("/v1/wallet/summon-recovery/")) return summonRecovery(request, env);
    if (path === "/v1/iap/authorize-v2") return paidPurchaseCredit(request, env);
    if (path === "/v1/wallet/summon") return paidSummon(request, env);
    if (path === "/v1/wallet/entitlements") return paidEntitlements(request, env);
    if (path === "/health" && request.method === "GET") return json({ service: "jade-iap", activation: "locked" }, 200);
    if (path !== "/v1/iap/authorize") return json({ error: "not_found" }, 404);
    if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    // M13: NEVER return legacy locally-creditable grants again. The M13 route
    // emits ONLY a server wallet receipt and has an independent default-off gate.
    if (env.JADE_IAP_BACKEND_ENABLED !== "true") return json({ error: "purchase_backend_disabled" }, 503);
    return json({ error: "legacy_purchase_route_retired" }, 410);
  };
}
export default { fetch: createWorkerHandler() };
