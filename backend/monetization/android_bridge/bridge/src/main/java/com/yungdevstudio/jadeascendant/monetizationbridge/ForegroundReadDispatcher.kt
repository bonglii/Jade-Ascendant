package com.yungdevstudio.jadeascendant.monetizationbridge

import java.util.concurrent.Executor

/** Three independently single-flight GETs must not queue behind purchase/recovery IO.
 * This selects a scheduling lane only. Auth, App Check, HTTPS, contracts and UID
 * checks remain in requestSignedRC6; every mutation keeps the ordered executor.
 */
internal class ForegroundReadDispatcher(private val ordered: Executor, private val reads: Executor) {
    fun execute(endpoint: String, method: String, body: String?, base: String, job: Runnable) {
        (if (isForegroundRead(endpoint, method, body, base)) reads else ordered).execute(job)
    }

    companion object {
        fun isForegroundRead(endpoint: String, method: String, body: String?, base: String): Boolean =
            base in setOf(IapTransportPolicy.PRODUCTION_URL, IapTransportPolicy.STAGING_URL) &&
                method == "GET" && body == null && endpoint in setOf(
                    "$base/v1/wallet/gameplay-v2", "$base/v4/odyssey", "$base/v1/heavenly-trials"
                )
    }
}
