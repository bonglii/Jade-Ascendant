/** RC10 candidate entrypoint. NOT active: wrangler.toml still points at index.mjs.
 * Deliberately compose existing Worker instead of patching user-modified index.
 * Requires RC3/5/6/7/8/9 dependencies installed in the same source tree.
 */
import baseWorker from './index.mjs';
import { createWorkerEdgeDispatchRC10 } from './worker_edge_dispatch_rc10.mjs';
import { createGooglePlayVoidedPushHandlerRC9 } from './play_rtdn_signed_push_rc9.mjs';
import { createTrustedProgressionReadHandlerRC3 } from './trusted_progression_read_rc3.mjs';
import { createSummonRecoveryIndexHandlerRC3 } from './summon_recovery_index_rc3.mjs';
import { createPaidLoadoutHandlerRC6 } from './paid_loadout_route_rc6.mjs';
import { createRefundScheduledHandlerRC11 } from './worker_scheduled_refund_rc11.mjs';

const fetch = createWorkerEdgeDispatchRC10({
  baseFetch: (request, env, ctx) => baseWorker.fetch(request, env, ctx),
  rtdnPush: createGooglePlayVoidedPushHandlerRC9(),
  trustedProgressRead: createTrustedProgressionReadHandlerRC3(),
  recoveryIndexRead: createSummonRecoveryIndexHandlerRC3(),
  paidLoadout: createPaidLoadoutHandlerRC6(),
});

export default {fetch,scheduled:createRefundScheduledHandlerRC11()};
