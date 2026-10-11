package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONObject

/** Server-ledger repair receipt: no purchase token, amount, UID or grant authority. */
internal object VerifiedPurchaseRepairContract {
    private val rootFields = setOf(
        "repair_contract_version", "state", "verified_purchases", "new_wallet_credits"
    )
    private fun whole(v: Any?, min: Int, max: Int): Int? {
        if (v !is Int && v !is Long) return null
        val n = (v as Number).toLong()
        return if (n in min.toLong()..max.toLong()) n.toInt() else null
    }
    fun decodeMap(raw: Map<String, Any?>): String? {
        if (raw.keys != rootFields ||
            whole(raw["repair_contract_version"], 1, 1) != 1 ||
            raw["state"] != "server_reconciled") return null
        val verified = whole(raw["verified_purchases"], 0, 32) ?: return null
        val added = whole(raw["new_wallet_credits"], 0, verified) ?: return null
        return JSONObject().put("repair_contract_version", 1)
            .put("state", "server_reconciled")
            .put("verified_purchases", verified)
            .put("new_wallet_credits", added).toString()
    }
    fun canonicalOrNull(raw: JSONObject): String? = try {
        val keys = raw.keys().asSequence().associateWith { raw.get(it) }
        decodeMap(keys)
    } catch (_: Exception) { null }
}
