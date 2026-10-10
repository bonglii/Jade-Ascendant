package com.yungdevstudio.jadeascendant.monetizationbridge

import org.junit.Assert.*
import org.junit.Test

class PaidPurchaseReceiptContractM14Test {
    private fun good(balance: Any = 550, revision: Any = 2): MutableMap<String, Any?> = mutableMapOf(
        "purchase_receipt_version" to 1, "state" to "server_wallet_credited",
        "wallet" to mutableMapOf<String, Any?>(
            "wallet_contract_version" to 1, "balance" to balance, "revision" to revision,
        ),
    )
    private fun decode(raw: Map<String, Any?> = good()) = PaidPurchaseReceiptContractM14.decodeMap(raw)
    @Test fun goodReceiptCanonicalAndNoGrant() {
        assertEquals("{\"purchase_receipt_version\":1,\"state\":\"server_wallet_credited\",\"wallet\":{\"wallet_contract_version\":1,\"balance\":550,\"revision\":2}}", decode())
    }
    @Test fun zeroBalanceAccepted() = assertNotNull(decode(good(0)))
    @Test fun maxSafeBalanceAccepted() = assertNotNull(decode(good(9007199254740991L)))
    @Test fun maxSafeRevisionAccepted() = assertNotNull(decode(good(revision=9007199254740991L)))
    @Test fun negativeBalanceRejected() = assertNull(decode(good(-1)))
    @Test fun zeroRevisionRejected() = assertNull(decode(good(revision=0)))
    @Test fun negativeRevisionRejected() = assertNull(decode(good(revision=-1)))
    @Test fun fractionalBalanceRejected() = assertNull(decode(good(1.5)))
    @Test fun floatWholeRejected() = assertNull(decode(good(550.0)))
    @Test fun quotedBalanceRejected() = assertNull(decode(good("550")))
    @Test fun overflowBalanceRejected() = assertNull(decode(good(9007199254740992L)))
    @Test fun overflowRevisionRejected() = assertNull(decode(good(revision=9007199254740992L)))
    @Test fun extraRootGrantRejected() = assertNull(decode(good().also { it["grant_id"] = "injected" }))
    @Test fun wrongStateRejected() = assertNull(decode(good().also { it["state"] = "grant_ready" }))
    @Test fun missingWalletRejected() = assertNull(decode(good().also { it.remove("wallet") }))
    @Test fun missingVersionRejected() = assertNull(decode(good().also { it.remove("purchase_receipt_version") }))
    @Test fun invalidVersionRejected() = assertNull(decode(good().also { it["purchase_receipt_version"] = 2 }))
    @Test fun extraWalletValueRejected() {
        val x = good(); (x["wallet"] as MutableMap<String, Any?>)["celestial_jade"] = 550
        assertNull(decode(x))
    }
    @Test fun nestedWalletVersionRejected() {
        val x = good(); (x["wallet"] as MutableMap<String, Any?>)["wallet_contract_version"] = "1"
        assertNull(decode(x))
    }
}
