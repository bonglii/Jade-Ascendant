package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.security.MessageDigest

class PaidSummonCommitContractRC4Test {
    private val uid = "firebaseuidrc4"
    private val requestId = "9cc242ed-56cc-46bc-8f8d-fb2b83388d7a"
    private fun spendId(): String = "spendv1:" + MessageDigest.getInstance("SHA-256")
        .digest(("summon:v1\u0000"+uid+"\u0000"+requestId).toByteArray())
        .joinToString("") { "%02x".format(it.toInt() and 255) }
    private fun outcome() = mapOf<String, Any?>(
        "outcome_contract_version" to 1, "pull_count" to 1,
        "results" to listOf(mapOf<String, Any?>(
            "item_id" to "mistveil_jian", "rarity" to "rare", "duplicate" to false,
            "duplicate_shards" to 0, "hard_legendary_pity" to false, "wish_hit" to false,
            "wish_fate_activated" to false, "wish_fate_consumed" to false
        )),
        "next_pity" to mapOf("rare_plus" to 0, "epic_plus" to 1, "legendary" to 1)
    )
    private fun valid() = mapOf<String, Any?>(
        "paid_summon_contract_version" to 1, "state" to "committed",
        "request_id" to requestId, "spend_id" to spendId(),
        "outcome" to outcome(),
        "wallet" to mapOf("wallet_contract_version" to 1, "balance" to 1100L, "revision" to 2L)
    )
    private fun parse(data: Map<String, Any?>, id: String = requestId, user: String = uid, count: Int = 1) =
        PaidSummonCommitContractRC4.decodeMap(data, id, user, count)

    @Test fun validCommittedServerReceipt() { assertNotNull(parse(valid())) }
    @Test fun wrongUidRejected() { assertNull(parse(valid(), user = "otheruid")) }
    @Test fun wrongRequestIdRejected() { assertNull(parse(valid(), id = "0cc242ed-56cc-46bc-8f8d-fb2b83388d7a")) }
    @Test fun mismatchPullCountRejected() { assertNull(parse(valid(), count = 10)) }
    @Test fun wrongSpendHashRejected() { assertNull(parse(valid() + ("spend_id" to ("spendv1:" + "a".repeat(64))))) }
    @Test fun localGrantFieldRejected() { assertNull(parse(valid() + ("grant_id" to "attack"))) }
    @Test fun negativeBalanceRejected() {
        assertNull(parse(valid() + ("wallet" to mapOf("wallet_contract_version" to 1, "balance" to -1, "revision" to 2))))
    }
    @Test fun fractionalBalanceRejected() {
        assertNull(parse(valid() + ("wallet" to mapOf("wallet_contract_version" to 1, "balance" to 1.5, "revision" to 2))))
    }
    @Test fun mismatchedOutcomeCountRejected() { assertNull(parse(valid() + ("outcome" to (outcome() + ("pull_count" to 10))))) }
    @Test fun untrustedItemIdRejected() {
        val o = outcome().toMutableMap()
        val entry = (o["results"] as List<*>)[0] as Map<String, Any?>
        o["results"] = listOf(entry + ("item_id" to "../attack"))
        assertNull(parse(valid() + ("outcome" to o)))
    }
    @Test fun extraResultFieldRejected() {
        val o = outcome().toMutableMap()
        val entry = (o["results"] as List<*>)[0] as Map<String, Any?>
        o["results"] = listOf(entry + ("local_grant" to true))
        assertNull(parse(valid() + ("outcome" to o)))
    }
}
