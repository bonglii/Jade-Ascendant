package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONArray
import org.json.JSONObject

/** Strict immutable index, used only to locate committed recovery receipts on a new device. */
internal object SummonRecoveryIndexContractRC6 {
    private val keys = setOf("recovery_index_contract_version", "state", "request_ids", "next_before", "coverage", "authority")
    private val uuid = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
    private const val CURSOR_MAX = 999999999999999L
    fun decodeMap(raw: Map<String, Any?>): String? {
        if (raw.keys != keys || raw["recovery_index_contract_version"] != 1 ||
            raw["state"] != "read_only" || raw["coverage"] != "indexed_commits_only" ||
            raw["authority"] != "server_only") return null
        val requests = raw["request_ids"] as? List<*> ?: return null
        if (requests.size > 20 || requests.any { it !is String || !uuid.matches(it) } || requests.distinct().size != requests.size) return null
        val cursor = raw["next_before"]
        if (cursor != null && (cursor !is Int && cursor !is Long || (cursor as Number).toLong() !in 1..CURSOR_MAX || requests.size != 20)) return null
        val ids = JSONArray()
        requests.forEach { ids.put(it) }
        return JSONObject().put("recovery_index_contract_version", 1).put("state", "read_only")
            .put("request_ids", ids).put("next_before", cursor ?: JSONObject.NULL)
            .put("coverage", "indexed_commits_only").put("authority", "server_only").toString()
    }
    fun canonicalOrNull(raw: JSONObject): String? { return try {
        val fields = raw.keys().asSequence().associateWith { raw.get(it) }.toMutableMap()
        val ids = fields["request_ids"] as? JSONArray ?: return null
        fields["request_ids"] = (0 until ids.length()).map { ids.get(it) }
        if (fields["next_before"] == JSONObject.NULL) fields["next_before"] = null
        decodeMap(fields)
    } catch (_: Exception) { null }
    }
}
