package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest
import java.util.Locale

/** Server-only paid summon result, not a local inventory or balance grant. */
internal object PaidSummonCommitContractRC4 {
    private val uuid4 = Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", RegexOption.IGNORE_CASE)
    private val sha = Regex("^spendv1:[a-f0-9]{64}$")
    private val keys = setOf("paid_summon_contract_version", "state", "request_id", "spend_id", "outcome", "wallet")
    private val walletKeys = setOf("wallet_contract_version", "balance", "revision")
    private val outcomes = setOf("outcome_contract_version", "pull_count", "results", "next_pity")
    private val pity = setOf("rare_plus", "epic_plus", "legendary")
    private val fields = setOf("item_id", "rarity", "duplicate", "duplicate_shards", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed")
    private val item = Regex("^[a-z][a-z0-9_]{0,95}$")
    private val rarities = setOf("common", "rare", "epic", "legendary")

    private fun exact(data: Map<String, Any?>, expected: Set<String>) = data.keys == expected
    private fun long(data: Any?, min: Long, max: Long): Long? {
        if (data !is Int && data !is Long) return null
        val n = (data as Number).toLong()
        return if (n in min..max) n else null
    }
    private fun digest(uid: String, id: String): String = "spendv1:" + MessageDigest.getInstance("SHA-256")
        .digest(("summon:v1\u0000" + uid + "\u0000" + id).toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it.toInt() and 255) }

    fun decodeMap(raw: Map<String, Any?>, requestId: String, uid: String, count: Int): String? {
        if (!uuid4.matches(requestId) || count !in setOf(1, 10) ||
            !Regex("^[A-Za-z0-9_-]{1,128}$").matches(uid) || !exact(raw, keys)) return null
        val id = requestId.lowercase(Locale.ROOT)
        val spend = raw["spend_id"] as? String ?: return null
        if (!sha.matches(spend) || spend != digest(uid, id) || raw["request_id"] != id ||
            raw["state"] != "committed" || long(raw["paid_summon_contract_version"], 1, 1) != 1L) return null
        val w = raw["wallet"] as? Map<String, Any?> ?: return null
        if (!exact(w, walletKeys) || long(w["wallet_contract_version"], 1, 1) != 1L) return null
        val balance = long(w["balance"], 0, 9007199254740991L) ?: return null
        val revision = long(w["revision"], 0, 9007199254740990L) ?: return null
        val o = raw["outcome"] as? Map<String, Any?> ?: return null
        if (!exact(o, outcomes) || long(o["outcome_contract_version"], 1, 1) != 1L ||
            long(o["pull_count"], 1, 10) != count.toLong()) return null
        val p = o["next_pity"] as? Map<String, Any?> ?: return null
        if (!exact(p, pity)) return null
        val rare = long(p["rare_plus"], 0, 9) ?: return null
        val epic = long(p["epic_plus"], 0, 29) ?: return null
        val legendary = long(p["legendary"], 0, 49) ?: return null
        val results = o["results"] as? List<*> ?: return null
        if (results.size != count) return null
        val items = JSONArray()
        for (r in results) {
            val m = r as? Map<String, Any?> ?: return null
            if (!exact(m, fields)) return null
            val name = m["item_id"] as? String ?: return null
            val rarity = m["rarity"] as? String ?: return null
            val shards = long(m["duplicate_shards"], 0, 75) ?: return null
            if (!item.matches(name) || rarity !in rarities) return null
            for (flag in listOf("duplicate", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed")) {
                if (m[flag] !is Boolean) return null
            }
            val safe = JSONObject().put("item_id", name).put("rarity", rarity).put("duplicate_shards", shards)
            for (flag in listOf("duplicate", "hard_legendary_pity", "wish_hit", "wish_fate_activated", "wish_fate_consumed")) safe.put(flag, m[flag])
            items.put(safe)
        }
        val safeOutcome = JSONObject().put("outcome_contract_version", 1).put("pull_count", count)
            .put("results", items).put("next_pity", JSONObject().put("rare_plus", rare).put("epic_plus", epic).put("legendary", legendary))
        return JSONObject().put("paid_summon_contract_version", 1).put("state", "committed")
            .put("request_id", id).put("spend_id", spend).put("outcome", safeOutcome)
            .put("wallet", JSONObject().put("wallet_contract_version", 1).put("balance", balance).put("revision", revision))
            .toString()
    }

    fun canonicalOrNull(json: JSONObject, requestId: String, uid: String, count: Int): String? {
      return try {
        fun map(obj: JSONObject): Map<String, Any?> = obj.keys().asSequence().associateWith { obj.get(it) }
        val raw = map(json).toMutableMap()
        val wallet = raw["wallet"] as? JSONObject ?: return null
        val outcome = raw["outcome"] as? JSONObject ?: return null
        val m = map(outcome).toMutableMap()
        val pityJson = m["next_pity"] as? JSONObject ?: return null
        val resultsJson = m["results"] as? JSONArray ?: return null
        val mapped = mutableListOf<Map<String, Any?>>()
        for (i in 0 until resultsJson.length()) mapped.add(map(resultsJson.optJSONObject(i) ?: return null))
        m["next_pity"] = map(pityJson)
        m["results"] = mapped
        raw["outcome"] = m
        raw["wallet"] = map(wallet)
        decodeMap(raw, requestId, uid, count)
      } catch (_: Exception) { null }
    }
}
