extends SceneTree
const Snapshot = preload("res://scripts/monetization/hybrid_paid_wallet_snapshot_m9.gd")
var assertions: int = 0

func check(ok: bool, name: String) -> bool:
	if not ok:
		push_error("GODOT_M9_FAIL=" + name)
		quit(1)
		return false
	assertions += 1
	return true


func _initialize() -> void:
	var base: Dictionary = {
		"hybrid_policy_version": 1,
		"paid_wallet": {
			"currency": "celestial_jade", "authority": "server",
			"balance": 1234, "revision": 7,
		},
		"local_wallet_authority": "device_only_untrusted",
		"legacy_wallet_migration": "requires_explicit_reconciliation",
	}
	var canonical: String = JSON.stringify(base)
	var before: String = JSON.stringify(base)
	var ok: Dictionary = Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", canonical)
	if not check(ok["status"] == "ready", "accept_ready"): return
	if not check(ok["balance"] == 1234, "balance"): return
	if not check(ok["revision"] == 7, "revision"): return
	if not check(ok["authority"] == "server_only", "authority"): return
	if not check(ok["is_fresh"] == true, "fresh"): return
	if not check(ok["display_only"] == true, "display_only"): return
	if not check(ok["can_grant"] == false, "cannot_grant"): return
	if not check(ok["can_spend"] == false, "cannot_spend"): return
	if not check(ok["runtime_cutover"] == false, "cutover_blocked"): return
	if not check(JSON.stringify(base) == before, "source_immutable"): return
	var blank: Dictionary = Snapshot.empty()
	if not check(blank["balance"] == -1, "blank_not_fake_zero"): return
	if not check(blank["revision"] == -1, "blank_revision_unknown"): return
	if not check(blank["is_fresh"] == false, "blank_not_fresh"): return
	if not check(blank["can_spend"] == false, "blank_cannot_spend"): return
	if not check(blank["runtime_cutover"] == false, "blank_no_cutover"): return
	if not check(Snapshot.from_native_result(false, "NETWORK", canonical)["status"] == "unavailable", "network_fail_closed"): return
	if not check(Snapshot.from_native_result(true, "WRONG", canonical)["status"] == "invalid_response", "wrong_status"): return
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", "")["status"] == "invalid_response", "empty_payload"): return
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", "hello")["status"] == "invalid_response", "invalid_json"): return
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", "[]")["status"] == "invalid_response", "reject_array"): return
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", " ".repeat(2049))["status"] == "invalid_response", "oversized_payload"): return
	var clone: Dictionary = base.duplicate(true)
	clone["bonus"] = 1
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_extra_root"): return
	clone = base.duplicate(true)
	clone.erase("local_wallet_authority")
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_missing_root"): return
	clone = base.duplicate(true)
	clone["hybrid_policy_version"] = 2
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_wrong_version"): return
	clone = base.duplicate(true)
	clone["local_wallet_authority"] = "device_and_server"
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_fake_local_authority"): return
	clone = base.duplicate(true)
	clone["legacy_wallet_migration"] = "automatic"
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_automatic_migration"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["authority"] = "client"
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_client_authority"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["currency"] = "gold"
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_wrong_currency"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["bonus"] = 500
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_extra_wallet_field"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["balance"] = -1
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_negative_balance"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["balance"] = 3.5
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_float_balance"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["revision"] = -1
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_negative_revision"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["revision"] = 1.5
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_float_revision"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["balance"] = 9007199254740992
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_unsafe_balance"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["revision"] = 9007199254740992
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_unsafe_revision"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["balance"] = true
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "invalid_response", "reject_boolean"): return
	clone = base.duplicate(true)
	clone["paid_wallet"]["balance"] = 0
	clone["paid_wallet"]["revision"] = 0
	if not check(Snapshot.from_native_result(true, "WALLET_SNAPSHOT_READ_ONLY", JSON.stringify(clone))["status"] == "ready", "accept_zero_wallet"): return
	if not check(assertions == 37, "expected_test_count"): return
	print("GODOT_M9_SMOKE=PASS_" + str(assertions))
	quit(0)
