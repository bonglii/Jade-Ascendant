package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONArray
import org.json.JSONObject

/** Server-only paid equipment ownership; display hint, not a local inventory grant. */
internal object PaidEntitlementsContractRC {
    private val fields = setOf(
        "paid_entitlements_contract_version", "state", "revision", "item_ids",
        "refinement_shards", "authority",
    )
    private val item = Regex("^[a-z][a-z0-9_]{0,95}$")
    private const val MAX_SAFE = 9_007_199_254_740_991L
    private const val MAX_SHARDS = 1_000_000_000L

    private fun whole(raw: Any?, min: Long, max: Long): Long? {
        if (raw !is Int && raw !is Long) return null
        val value = (raw as Number).toLong()
        return value.takeIf { it in min..max }
    }

    fun decodeMap(raw: Map<String, Any?>): String? {
        if (raw.keys != fields || whole(raw["paid_entitlements_contract_version"], 1, 1) != 1L
            || raw["state"] != "verified" || raw["authority"] != "server_read_only") return null
        val revision = whole(raw["revision"], 0, MAX_SAFE - 1) ?: return null
        val shards = whole(raw["refinement_shards"], 0, MAX_SHARDS) ?: return null
        val names = raw["item_ids"] as? List<*> ?: return null
        if (names.size > 300) return null
        val ids = mutableListOf<String>()
        for (value in names) {
            val id = value as? String ?: return null
            if (!item.matches(id) || (ids.isNotEmpty() && id <= ids.last())) return null
            ids.add(id)
        }
        // Strict canonical JSON: identifiers are validated and sorted.
        val safeItems = ids.joinToString(",") { "\"$it\"" }
        return "{\"paid_entitlements_contract_version\":1,\"state\":\"verified\"," +
            "\"revision\":$revision,\"item_ids\":[$safeItems]," +
            "\"refinement_shards\":$shards,\"authority\":\"server_read_only\"}"
    }

    fun canonicalOrNull(json: JSONObject): String? {
        return try {
        val root = mutableMapOf<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) { val k = keys.next(); root[k] = json.get(k) }
        val arr = root["item_ids"] as? JSONArray ?: return null
        val values = mutableListOf<String>()
        for (i in 0 until arr.length()) values.add(arr.opt(i) as? String ?: return null)
        root["item_ids"] = values
        decodeMap(root)
        } catch (_: Exception) { null }
    }
}
