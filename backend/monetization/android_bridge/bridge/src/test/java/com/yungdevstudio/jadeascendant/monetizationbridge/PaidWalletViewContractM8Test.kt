package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.*
import org.junit.Test

class PaidWalletViewContractM8Test {
    private fun good(balance: Any = 1200, revision: Any = 1): Map<String, Any?> = mapOf(
        "hybrid_policy_version" to 1,
        "paid_wallet" to mapOf("currency" to "celestial_jade", "authority" to "server", "balance" to balance, "revision" to revision),
        "local_wallet_authority" to "device_only_untrusted",
        "legacy_wallet_migration" to "requires_explicit_reconciliation",
    )
    private fun replace(field: String, value: Any?) = good().toMutableMap().also { it[field] = value }

    @Test fun acceptsValid() {
        val json = PaidWalletViewContractM8.decodeMap(good())
        assertNotNull(json)
        assertTrue(json!!.contains("\"balance\":1200"))
    }
    @Test fun zeroBalanceIsValid() = assertNotNull(PaidWalletViewContractM8.decodeMap(good(0)))
    @Test fun negativeBalanceRejected() = assertNull(PaidWalletViewContractM8.decodeMap(good(-1)))
    @Test fun fractionRejected() = assertNull(PaidWalletViewContractM8.decodeMap(good(1.5)))
    @Test fun stringRejected() = assertNull(PaidWalletViewContractM8.decodeMap(good("1200")))
    @Test fun maxSafeIntegerBounded() = assertNull(PaidWalletViewContractM8.decodeMap(good(9007199254740992L)))
    @Test fun revisionMustBeNonnegative() = assertNull(PaidWalletViewContractM8.decodeMap(good(revision=-1)))
    @Test fun unexpectedOwnerUidRejected() = assertNull(PaidWalletViewContractM8.decodeMap(replace("uid", "someone")))
    @Test fun mismatchedAuthorityRejected() = assertNull(PaidWalletViewContractM8.decodeMap(replace("local_wallet_authority", "server")))
    @Test fun wrongProtocolVersionRejected() = assertNull(PaidWalletViewContractM8.decodeMap(replace("hybrid_policy_version", 2)))
    @Test fun wrongMigrationStatusRejected() = assertNull(PaidWalletViewContractM8.decodeMap(replace("legacy_wallet_migration", "done")))
    @Test fun extraNestedFieldRejected() {
        val wallet = (good()["paid_wallet"] as Map<String, Any?>).toMutableMap()
        wallet["free_jade"] = 999
        assertNull(PaidWalletViewContractM8.decodeMap(replace("paid_wallet", wallet)))
    }
}
