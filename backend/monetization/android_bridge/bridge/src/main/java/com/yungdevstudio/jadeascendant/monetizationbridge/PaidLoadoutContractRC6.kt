package com.yungdevstudio.jadeascendant.monetizationbridge

import org.json.JSONObject
import java.util.Locale

/** Strict, server-only loadout read/write envelope. Never imports equipment into local saves. */
internal object PaidLoadoutContractRC6 {
    private const val LIMIT = 9007199254740990L
    private val keys = setOf("paid_loadout_contract_version", "state", "revision", "entitlement_revision", "paid_slots", "authority")
    private val slots = listOf("armament", "robe", "bracer", "boots", "pendant")
    private val idsBySlot = mapOf(
        "armament" to setOf("wanderer_jade_jian", "mistveil_jian", "spirit_seal_fan", "cinnabar_moon_saber", "nine_heavens_star_sword", "mountain_ward_jian", "stillwater_mirror_blade", "sunfire_dragon_jian"),
        "robe" to setOf("verdant_qi_robe", "bamboo_weave_robe", "moonthread_robe", "ward_keeper_robe", "sovereign_mantle", "stone_meridian_robe", "glassmoon_robe", "dawn_meridian_robe"),
        "bracer" to setOf("jade_guard_bracer", "jade_edge_bracer", "mirror_edge_bracer", "stormcall_bracer", "tribulation_bracer", "earthseal_bracer", "reflection_bracer", "solar_edict_bracer"),
        "boots" to setOf("cloudstep_boots", "miststride_boots", "shadowstep_boots", "starstep_boots", "cloudtreader_boots", "rootstep_boots", "silent_ripple_boots", "sunstride_boots"),
        "pendant" to setOf("spirit_jade_pendant", "qi_reservoir_pendant", "shrine_seal_pendant", "sword_heart_pendant", "ascendant_heart", "guardian_jade_pendant", "mirror_heart_pendant", "golden_core_pendant")
    )
    private val uuid = Regex("^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$", RegexOption.IGNORE_CASE)
    private fun validNumber(value: Any?, min: Long = 0, max: Long = LIMIT): Long? {
        if (value !is Int && value !is Long) return null
        val n = (value as Number).toLong()
        return if (n in min..max) n else null
    }
    private fun validSlots(raw: Map<String, Any?>): Map<String, String>? {
        if (raw.keys != slots.toSet()) return null
        val out = linkedMapOf<String, String>()
        for (slot in slots) {
            val item = raw[slot] as? String ?: return null
            if (item.isNotEmpty() && !idsBySlot.getValue(slot).contains(item)) return null
            out[slot] = item
        }
        if (out.values.filter { it.isNotEmpty() }.distinct().size != out.values.count { it.isNotEmpty() }) return null
        return out
    }
    private fun readObject(value: JSONObject): Map<String, Any?> = value.keys().asSequence().associateWith { value.get(it) }
    fun decodeMap(raw: Map<String, Any?>): String? {
        if (raw.keys != keys || validNumber(raw["paid_loadout_contract_version"], 1, 1) != 1L ||
            raw["state"] != "verified" || raw["authority"] != "server_only") return null
        val revision = validNumber(raw["revision"]) ?: return null
        val entitlementRevision = validNumber(raw["entitlement_revision"]) ?: return null
        val itemMap = raw["paid_slots"] as? Map<*, *> ?: return null
        if (itemMap.keys.any { it !is String }) return null
        @Suppress("UNCHECKED_CAST")
        val equipped = validSlots(itemMap as Map<String, Any?>) ?: return null
        val jsonSlots = JSONObject()
        slots.forEach { jsonSlots.put(it, equipped.getValue(it)) }
        return JSONObject().put("paid_loadout_contract_version", 1).put("state", "verified")
            .put("revision", revision).put("entitlement_revision", entitlementRevision)
            .put("paid_slots", jsonSlots).put("authority", "server_only").toString()
    }
    fun canonicalOrNull(raw: JSONObject): String? { return try {
        val flat = readObject(raw).toMutableMap()
        flat["paid_slots"] = readObject(flat["paid_slots"] as? JSONObject ?: return null)
        decodeMap(flat)
    } catch (_: Exception) { null }
    }

    /** Client command is a proposal only. Server does current entitlement checks + atomic CAS. */
    fun commandOrNull(requestId: String, loadoutRevision: Long, entitlementRevision: Long, rawSlots: String): String? {
        if (!uuid.matches(requestId) || loadoutRevision !in 0..LIMIT || entitlementRevision !in 0..LIMIT || rawSlots.length > 1024) return null
        val slotObject = try { JSONObject(rawSlots) } catch (_: Exception) { return null }
        val value = try { validSlots(readObject(slotObject)) } catch (_: Exception) { null } ?: return null
        val slotJson = JSONObject()
        slots.forEach { slotJson.put(it, value.getValue(it)) }
        return JSONObject().put("request_id", requestId.lowercase(Locale.ROOT))
            .put("expected_loadout_revision", loadoutRevision)
            .put("expected_entitlement_revision", entitlementRevision)
            .put("paid_slots", slotJson).toString()
    }
}
