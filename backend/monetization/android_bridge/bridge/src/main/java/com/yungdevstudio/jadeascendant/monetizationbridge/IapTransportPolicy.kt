package com.yungdevstudio.jadeascendant.monetizationbridge

/** Build facts are passed explicitly so all variants can test the full policy matrix. */
internal data class IapTransportPolicy(
    val debug: Boolean, val target: String, val url: String,
    val sandboxCredit: Boolean, val gameplay: Boolean, val candidate: Boolean,
) {
    val staging: Boolean get() = debug && target == "staging" && sandboxCredit && !candidate && url == STAGING_URL
    val production: Boolean get() = !debug && target == "production-candidate" && candidate && !sandboxCredit && gameplay && url == PRODUCTION_URL
    val wallet: Boolean get() = staging || production
    fun allowsUser(anonymous: Boolean, google: Boolean): Boolean = if (anonymous) staging else google
    fun allowsHost(host: String): Boolean = (staging && host == STAGING_HOST) || (production && host == PRODUCTION_HOST)
    companion object {
        const val STAGING_HOST = "jade-ascendant-iap-staging.jade-ascendant-studio.workers.dev"
        const val PRODUCTION_HOST = "jade-ascendant-iap.jade-ascendant-studio.workers.dev"
        const val STAGING_URL = "https://" + STAGING_HOST
        const val PRODUCTION_URL = "https://" + PRODUCTION_HOST
        fun compiled() = IapTransportPolicy(BuildConfig.DEBUG, BuildConfig.JADE_IAP_TARGET,
            BuildConfig.JADE_IAP_WORKER_BASE_URL, BuildConfig.JADE_IAP_STAGING_CREDIT_ENABLED,
            BuildConfig.JADE_IAP_GAMEPLAY_V2_ENABLED, BuildConfig.JADE_IAP_PRODUCTION_CANDIDATE_ENABLED)
    }
}
