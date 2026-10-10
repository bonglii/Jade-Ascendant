package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.*
import org.junit.Test
import java.security.MessageDigest

class PaidSummonRecoveryContractM12Test {
    private val uid = "alice1"
    private val id = "9cc242ed-56cc-46bc-8f8d-fb2b83388d7a"
    private fun spend(user: String = uid): String = "spendv1:" + MessageDigest.getInstance("SHA-256")
        .digest(("summon:v1\u0000" + user + "\u0000" + id).toByteArray()).joinToString("") { "%02x".format(it.toInt() and 255) }
    private fun good() = mutableMapOf<String, Any?>(
        "recovery_contract_version" to 1, "request_id" to id, "state" to "committed", "spend_id" to spend(),
        "outcome" to mutableMapOf<String, Any?>(
            "outcome_contract_version" to 1, "pull_count" to 1,
            "results" to mutableListOf<MutableMap<String, Any?>>(mutableMapOf(
                "item_id" to "mistveil_jian", "rarity" to "rare", "duplicate" to false, "duplicate_shards" to 0,
                "hard_legendary_pity" to false, "wish_hit" to false, "wish_fate_activated" to false, "wish_fate_consumed" to false,
            )), "next_pity" to mutableMapOf<String, Any?>("rare_plus" to 0, "epic_plus" to 1, "legendary" to 1),
        ),
    )
    private fun decode(data: Map<String, Any?> = good(), account: String = uid, request: String = id) =
        PaidSummonRecoveryContractM12.decodeMap(data,request,account)
    @Test fun valid() { val result=decode();assertNotNull(result);assertTrue(result!!.contains("\"state\":\"committed\"")) }
    @Test fun upperCaseRequestValid() { assertNotNull(decode(request=id.uppercase())) }
    @Test fun wrongAccountRejected() { assertNull(decode(account="bob2")) }
    @Test fun wrongRequestRejected() { assertNull(decode(request="362ef4da-bc86-43e6-86dc-dad77241cbde")) }
    @Test fun malformedRequestRejected() { assertNull(decode(request="../bad")) }
    @Test fun spendMismatchRejected() { assertNull(decode(good().also{it["spend_id"]="spendv1:fake"})) }
    @Test fun extraRootRejected() { assertNull(decode(good().also{it["uid"]=uid})) }
    @Test fun otherStateRejected() { assertNull(decode(good().also{it["state"]="pending"})) }
    @Test fun versionStringRejected() { assertNull(decode(good().also{it["recovery_contract_version"]="1"})) }
    @Test fun versionChangedRejected() { assertNull(decode(good().also{it["recovery_contract_version"]=2})) }
    @Test fun pityInvalidRejected() { val v=good();((v["outcome"] as MutableMap<String,Any?>)["next_pity"] as MutableMap<String,Any?>)["legendary"]=99;assertNull(decode(v)) }
    @Test fun itemTraversalRejected() { val v=good();(((v["outcome"] as MutableMap<String,Any?>)["results"] as MutableList<MutableMap<String,Any?>>)[0])["item_id"]="../bad";assertNull(decode(v)) }
    @Test fun countMismatchRejected() { val v=good();(v["outcome"] as MutableMap<String,Any?>)["pull_count"]=10;assertNull(decode(v)) }
    @Test fun booleanCoercionRejected() { val v=good();(((v["outcome"] as MutableMap<String,Any?>)["results"] as MutableList<MutableMap<String,Any?>>)[0])["duplicate"]="false";assertNull(decode(v)) }
    @Test fun unexpectedOutcomeFieldRejected() { val v=good();(v["outcome"] as MutableMap<String,Any?>)["extra"]="hack";assertNull(decode(v)) }
    @Test fun fractionalCountRejected() { val v=good();(v["outcome"] as MutableMap<String,Any?>)["pull_count"]=1.5;assertNull(decode(v)) }
}
