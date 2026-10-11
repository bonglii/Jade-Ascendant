/** Source-only candidate. wrangler.toml still points at src/index.mjs. */
import prior from './worker_entry_rc12.mjs';
import {createVerifiedPurchaseRepairHandler} from './verified_purchase_repair.mjs';
const repair=createVerifiedPurchaseRepairHandler();
export default {
  fetch(request,env,ctx) {
    if(new URL(request.url).pathname==='/v1/iap/recover-verified')
      return repair(request,env,ctx);
    return prior.fetch(request,env,ctx);
  },
  scheduled: prior.scheduled,
};
