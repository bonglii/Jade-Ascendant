extends SceneTree
const Contract = preload("res://scripts/monetization/hybrid_paid_loadout_rc2.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PAID_LOADOUT_RC2_FAILURE=" + tag)
func entitlement() -> Dictionary:
	return {"status":"ready", "revision":4, "item_ids":["mistveil_jian"], "authority":"server_read_only"}
func fixture() -> Dictionary:
	return {"paid_loadout_contract_version":1,"state":"verified","revision":1,
		"entitlement_revision":4,"paid_slots":{"armament":"mistveil_jian","robe":"","bracer":"","boots":"","pendant":""},
		"authority":"server_only"}
func parse_data(data: Dictionary, ent: Dictionary = {}) -> Dictionary:
	return Contract.from_native_result(true,"PAID_LOADOUT_READ_ONLY",JSON.stringify(data),entitlement() if ent.is_empty() else ent)
func _run() -> void:
	var ok: Dictionary = parse_data(fixture())
	check(ok["status"] == "ready", "valid")
	check(ok["revision"] == 1 and ok["entitlement_revision"] == 4, "revision")
	check(ok["paid_slots"]["armament"] == "mistveil_jian", "item")
	check(ok["display_only"] and not ok["can_grant"] and not ok["can_spend"] and not ok["can_equip"] and not ok["runtime_cutover"], "no_runtime")
	var d: Dictionary = fixture()
	d["paid_slots"]["armament"] = "nine_heavens_star_sword"
	check(parse_data(d)["status"] == "invalid_response", "unowned")
	d = fixture()
	d["paid_slots"]["robe"] = "mistveil_jian"
	check(parse_data(d)["status"] == "invalid_response", "wrong_slot")
	d = fixture()
	d["entitlement_revision"] = 3
	check(parse_data(d)["status"] == "stale_entitlements", "stale")
	d = fixture()
	d["local_grant"] = true
	check(parse_data(d)["status"] == "invalid_response", "untrusted_grant")
	d = fixture()
	d["paid_slots"].erase("pendant")
	check(parse_data(d)["status"] == "invalid_response", "missing_slot")
	d = fixture()
	check(parse_data(d,{"status":"not_connected","revision":0})["status"] == "entitlements_unavailable", "auth_missing")
	check(Contract.empty()["status"] == "not_connected", "empty")
	check(not Contract.empty()["can_equip"], "empty_no_equip")
	if failures == 0:
		print("PAID_LOADOUT_RC2_SMOKE=PASS_" + str(checks))
		quit(0)
	else:
		printerr("PAID_LOADOUT_RC2_SMOKE=FAIL_" + str(failures))
		quit(1)
