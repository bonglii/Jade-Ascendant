package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.*
import org.junit.Test

class PaidEntitlementsContractRCTest {
    private fun base() = mapOf<String, Any?>(
        "paid_entitlements_contract_version" to 1,
        "state" to "verified",
        "revision" to 0L,
        "item_ids" to listOf("mistveil_jian"),
        "refinement_shards" to 12L,
        "authority" to "server_read_only",
    )
    @Test fun acceptsValidServerSnapshotOnly() {
        val result=PaidEntitlementsContractRC.decodeMap(base())
        assertNotNull(result);assertTrue(result!!.contains("\"item_ids\":[\"mistveil_jian\"]"))
        assertFalse(result.contains("grant_id"))
    }
    @Test fun rejectsUnverifiedAndForgedAuthority() {
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("state" to "unverified")))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("authority" to "device")))
    }
    @Test fun rejectsClientAmountsAndLocalGrantProperties() {
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("celestial_jade" to 100)))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("grant_id" to "client")))
    }
    @Test fun rejectsUnsafeItemNamesAndUnsortedIds() {
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("item_ids" to listOf("../secret"))))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("item_ids" to listOf("z_item","a_item"))))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("item_ids" to listOf("a_item","a_item"))))
    }
    @Test fun rejectsOverflowNegativeAndCoercedNumbers() {
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("refinement_shards" to -1)))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("revision" to -1)))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("revision" to "5")))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("refinement_shards" to 1.0)))
        assertNull(PaidEntitlementsContractRC.decodeMap(base()+("refinement_shards" to 1_000_000_001L)))
    }
}
