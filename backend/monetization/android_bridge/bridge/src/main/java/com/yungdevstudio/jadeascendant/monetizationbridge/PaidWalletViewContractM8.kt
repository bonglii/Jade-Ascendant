package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONObject

/** M8 strictly read-only DISPLAY projection: never a grant or debit permission. */
internal object PaidWalletViewContractM8 {
    private val outerFields = setOf(
        "hybrid_policy_version", "paid_wallet", "local_wallet_authority", "legacy_wallet_migration",
    )
    private val walletFields = setOf("currency", "authority", "balance", "revision")
    private const val MAX_SAFE_INTEGER = 9007199254740991L

    private fun strictSafeInt(value: Any?, min: Long): Long? {
        if (value !is Int && value !is Long) return null
        val n = (value as Number).toLong()
        return if (n in min..MAX_SAFE_INTEGER) n else null
    }

    private fun objectMap(json: JSONObject): Map<String, Any?> {
        val entries = mutableMapOf<String, Any?>()
        val names = json.keys()
        while (names.hasNext()) {
            val key = names.next()
            entries[key] = json.get(key)
        }
        return entries
    }

    /** Parses only an exact server view, rejecting extra/unknown fields and coercions. */
    fun decodeMap(view: Map<String, Any?>): String? {
        if (view.keys != outerFields) return null
        if (strictSafeInt(view["hybrid_policy_version"], 1) != 1L) return null
        if (view["local_wallet_authority"] != "device_only_untrusted") return null
        if (view["legacy_wallet_migration"] != "requires_explicit_reconciliation") return null
        val wallet = view["paid_wallet"] as? Map<*, *> ?: return null
        if (wallet.keys != walletFields) return null
        if (wallet["currency"] != "celestial_jade" || wallet["authority"] != "server") return null
        val balance = strictSafeInt(wallet["balance"], 0) ?: return null
        val revision = strictSafeInt(wallet["revision"], 0) ?: return null
        // Strict canonical JSON; only trusted result may be displayed as a hint.
        return "{\"hybrid_policy_version\":1,\"paid_wallet\":" +
            "{\"currency\":\"celestial_jade\",\"authority\":\"server\"," +
            "\"balance\":$balance,\"revision\":$revision}," +
            "\"local_wallet_authority\":\"device_only_untrusted\"," +
            "\"legacy_wallet_migration\":\"requires_explicit_reconciliation\"}"
    }

    fun canonicalOrNull(json: JSONObject): String? {
        val outer = objectMap(json)
        val nested = outer["paid_wallet"] as? JSONObject ?: return null
        return decodeMap(outer + ("paid_wallet" to objectMap(nested)))
    }
}
