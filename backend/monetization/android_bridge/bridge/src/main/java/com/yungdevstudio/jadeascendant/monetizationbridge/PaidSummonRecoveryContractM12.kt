package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Locale

/** Strict, display-only M11 recovery envelope; never a grant or spend authority. */
internal object PaidSummonRecoveryContractM12 {
    private val uuid4 = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", RegexOption.IGNORE_CASE)
    private val itemId = Regex("^[a-z][a-z0-9_]{0,95}$")
    private val uidPattern = Regex("^[A-Za-z0-9_-]{1,128}$")
    private val rarities = setOf("common", "rare", "epic", "legendary")
    private val rootFields = setOf("recovery_contract_version", "request_id", "state", "spend_id", "outcome")
    private val outcomeFields = setOf("outcome_contract_version", "pull_count", "results", "next_pity")
    private val resultFields = setOf("item_id", "rarity", "duplicate", "duplicate_shards", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed")
    private val pityFields = setOf("rare_plus", "epic_plus", "legendary")

    fun validRequestId(value: String): Boolean = uuid4.matches(value)
    private fun exact(value: Any?, fields: Set<String>): Boolean = value is Map<*, *> && value.keys == fields
    private fun whole(value: Any?, min: Int, max: Int): Int? {
        if (value !is Int && value !is Long) return null
        val n = (value as Number).toLong()
        return if (n in min.toLong()..max.toLong()) n.toInt() else null
    }
    private fun expectedSpendId(uid: String, requestId: String): String {
        val bytes = ("summon:v1\u0000" + uid + "\u0000" + requestId).toByteArray(Charsets.UTF_8)
        val hash = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }
        return "spendv1:$hash"
    }

    /** Testable without Android JSONObject mocks. Copies ONLY known safe fields. */
    fun decodeMap(raw: Map<String, Any?>, requestId: String, verifiedUid: String): String? {
        if (!validRequestId(requestId) || !uidPattern.matches(verifiedUid) || !exact(raw, rootFields)) return null
        val id = requestId.lowercase(Locale.ROOT)
        if (whole(raw["recovery_contract_version"], 1, 1) != 1 || raw["request_id"] != id
            || raw["state"] != "committed" || raw["spend_id"] != expectedSpendId(verifiedUid, id)) return null
        val outcome = raw["outcome"] as? Map<*, *> ?: return null
        if (!exact(outcome, outcomeFields) || whole(outcome["outcome_contract_version"], 1, 1) != 1) return null
        val count = whole(outcome["pull_count"], 1, 10) ?: return null
        if (count !in setOf(1, 10)) return null
        val results = outcome["results"] as? List<*> ?: return null
        if (results.size != count) return null
        val pity = outcome["next_pity"] as? Map<*, *> ?: return null
        if (!exact(pity, pityFields)) return null
        val rare = whole(pity["rare_plus"], 0, 9) ?: return null
        val epic = whole(pity["epic_plus"], 0, 29) ?: return null
        val legendary = whole(pity["legendary"], 0, 49) ?: return null
        val encoded = mutableListOf<String>()
        for (x in results) {
            val result = x as? Map<*, *> ?: return null
            if (!exact(result, resultFields)) return null
            val name = result["item_id"] as? String ?: return null
            val rarity = result["rarity"] as? String ?: return null
            if (!itemId.matches(name) || rarity !in rarities) return null
            val shards = whole(result["duplicate_shards"], 0, 75) ?: return null
            val flags = listOf("duplicate", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed")
            if (flags.any { result[it] !is Boolean }) return null
            encoded.add("{\"item_id\":\"$name\",\"rarity\":\"$rarity\"," +
                "\"duplicate\":${result["duplicate"]},\"duplicate_shards\":$shards," +
                "\"hard_legendary_pity\":${result["hard_legendary_pity"]}," +
                "\"wish_hit\":${result["wish_hit"]}," +
                "\"wish_fate_activated\":${result["wish_fate_activated"]}," +
                "\"wish_fate_consumed\":${result["wish_fate_consumed"]}}")
        }
        // Identifiers, item names and rarity are regex constrained, so manual JSON has no escaping ambiguity.
        return "{\"recovery_contract_version\":1,\"request_id\":\"$id\"," +
            "\"state\":\"committed\",\"spend_id\":\"${expectedSpendId(verifiedUid, id)}\"," +
            "\"outcome\":{\"outcome_contract_version\":1,\"pull_count\":$count," +
            "\"results\":[${encoded.joinToString(",")}]," +
            "\"next_pity\":{\"rare_plus\":$rare,\"epic_plus\":$epic,\"legendary\":$legendary}}}"
    }

    private fun keys(json: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val it = json.keys()
        while (it.hasNext()) { val key = it.next(); map[key] = json.get(key) }
        return map
    }

    fun canonicalOrNull(raw: JSONObject, requestId: String, verifiedUid: String): String? {
        return try {
            val outer = keys(raw).toMutableMap()
            val outcome = outer["outcome"] as? JSONObject ?: return null
            val o = keys(outcome).toMutableMap()
            val pity = o["next_pity"] as? JSONObject ?: return null
            val items = o["results"] as? JSONArray ?: return null
            val mapped = mutableListOf<Map<String, Any?>>()
            for (i in 0 until items.length()) mapped.add(keys(items.optJSONObject(i) ?: return null))
            o["next_pity"] = keys(pity)
            o["results"] = mapped
            outer["outcome"] = o
            decodeMap(outer, requestId, verifiedUid)
        } catch (_: Exception) { null }
    }
}
