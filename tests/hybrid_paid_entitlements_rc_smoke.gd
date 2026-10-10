extends SceneTree
const Contract = preload("res://scripts/monetization/hybrid_paid_entitlements_rc.gd")
var checks: int = 0
var fails: int = 0
func _initialize() -> void:
	call_deferred("_run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		printerr("FASTTRACK_RC_GODOT_FAILED=" + label)
func fixture() -> Dictionary:
	return {
		"paid_entitlements_contract_version": 1,
		"state": "verified", "revision": 2, "item_ids": ["mistveil_jian", "river_sabre"],
		"refinement_shards": 12, "authority": "server_read_only"
	}
func parsed(data: Dictionary, ok: bool = true, status: String = "PAID_ENTITLEMENTS_READ_ONLY") -> Dictionary:
	return Contract.from_native_result(ok, status, JSON.stringify(data))
func _run() -> void:
	var safe: Dictionary = parsed(fixture())
	verify(safe["status"] == "ready", "valid")
	verify(safe["revision"] == 2, "revision")
	verify(safe["item_ids"].size() == 2, "items")
	verify(safe["refinement_shards"] == 12, "shards")
	verify(safe["display_only"] and not safe["can_grant"] and not safe["can_spend"] and not safe["runtime_cutover"], "never_local_grant")
	var d: Dictionary = fixture()
	d["grant_id"] = "attack"
	verify(parsed(d)["status"] == "invalid_response", "extra_grant")
	d = fixture()
	d["item_ids"] = ["../bad"]
	verify(parsed(d)["status"] == "invalid_response", "bad_item")
	d = fixture()
	d["item_ids"] = ["z_id", "a_id"]
	verify(parsed(d)["status"] == "invalid_response", "sorted")
	d = fixture()
	d["refinement_shards"] = -1
	verify(parsed(d)["status"] == "invalid_response", "shards_negative")
	d = fixture()
	d["authority"] = "device"
	verify(parsed(d)["status"] == "invalid_response", "untrusted")
	d = fixture()
	d["state"] = "unprovisioned"
	verify(parsed(d)["status"] == "invalid_response", "unprovisioned")
	verify(parsed(fixture(), false)["status"] == "unavailable", "native_error")
	verify(parsed(fixture(), true, "OTHER")["status"] == "invalid_response", "status_mismatch")
	verify(Contract.empty()["status"] == "not_connected", "empty")
	verify(not Contract.empty()["can_grant"], "empty_no_grant")
	if fails == 0:
		print("FASTTRACK_RC_GODOT_SMOKE=PASS_" + str(checks))
		quit(0)
	else:
		printerr("FASTTRACK_RC_GODOT_SMOKE=FAIL_" + str(fails))
		quit(1)
