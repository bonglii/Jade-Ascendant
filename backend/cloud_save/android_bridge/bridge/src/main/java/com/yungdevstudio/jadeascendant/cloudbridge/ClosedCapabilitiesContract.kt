package com.yungdevstudio.jadeascendant.cloudbridge

/**
 * Exact, fail-closed decoder of the existing READ-ONLY server contract.
 * No Firebase, Godot, disk, or Android runtime dependency.
 */
internal object ClosedCapabilitiesContract {
    fun accepts(data: Any?): Boolean {
        if (data !is Map<*, *>) return false
        val required = setOf(
            "capabilities_contract_version", "state", "cloud_write_enabled",
            "cloud_restore_enabled", "purchase_verification_enabled", "economy_verified",
            "server_revision_verified", "server_freshness_verified",
        )
        if (data.keys != required || data["state"] != "cloud_save_disabled") return false
        val version = data["capabilities_contract_version"]
        if (version !is Number || version.toDouble() != 1.0) return false
        return required.minus("capabilities_contract_version").minus("state")
            .all { data[it] == false }
    }
}
