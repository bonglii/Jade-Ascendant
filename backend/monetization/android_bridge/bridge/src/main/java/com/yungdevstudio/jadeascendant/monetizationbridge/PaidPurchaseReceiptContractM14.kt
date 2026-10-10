package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONObject

/** M14: strict receipt of a durable SERVER credit; never spendable locally. */
internal object PaidPurchaseReceiptContractM14 {
    private const val MAX_SAFE = 9_007_199_254_740_991L
    private val outerKeys = setOf("purchase_receipt_version", "state", "wallet")
    private val walletKeys = setOf("wallet_contract_version", "balance", "revision")

    private fun whole(value: Any?, min: Long, max: Long): Long? {
        // JSONObject from the Android runtime parses JSON integers as Int/Long.
        // Floating point, booleans, quoted numbers, and overflow fail closed.
        if (value !is Int && value !is Long) return null
        val n = (value as Number).toLong()
        return n.takeIf { it in min..max }
    }

    fun decodeMap(raw: Map<String, Any?>): String? {
        if (raw.keys != outerKeys || whole(raw["purchase_receipt_version"], 1, 1) != 1L
            || raw["state"] != "server_wallet_credited") return null
        val wallet = raw["wallet"] as? Map<*, *> ?: return null
        if (wallet.keys != walletKeys || whole(wallet["wallet_contract_version"], 1, 1) != 1L) return null
        val balance = whole(wallet["balance"], 0, MAX_SAFE) ?: return null
        val revision = whole(wallet["revision"], 1, MAX_SAFE) ?: return null
        return "{\"purchase_receipt_version\":1,\"state\":\"server_wallet_credited\"," +
            "\"wallet\":{\"wallet_contract_version\":1,\"balance\":$balance,\"revision\":$revision}}"
    }

    fun canonicalOrNull(raw: JSONObject): String? {
        return try {
        val fields = mutableMapOf<String, Any?>()
        val names = raw.keys()
        while (names.hasNext()) { val name = names.next(); fields[name] = raw.get(name) }
        val wallet = raw.optJSONObject("wallet") ?: return null
        val walletFields = mutableMapOf<String, Any?>()
        val walletNames = wallet.keys()
        while (walletNames.hasNext()) { val name = walletNames.next(); walletFields[name] = wallet.get(name) }
        fields["wallet"] = walletFields
        decodeMap(fields)
        } catch (_: Exception) { null }
    }
}
