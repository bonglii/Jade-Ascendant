extends SceneTree
const Overlay = preload("res://scripts/monetization/paid_equipment_runtime_rc6.gd")
var checks: int = 0
var failed: int = 0
const BINDING: String = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
func test(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		printerr("RC6_RUNTIME_FAILED=" + why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var ent: Dictionary = {"status": "ready", "revision": 4, "authority": "server_read_only", "item_ids": ["mistveil_jian", "bamboo_weave_robe"]}
	var slots: Dictionary = {"armament": "mistveil_jian", "robe": "bamboo_weave_robe", "bracer": "", "boots": "", "pendant": ""}
	var load: Dictionary = {"status": "ready", "entitlement_revision": 4, "authority": "server_only", "paid_slots": slots}
	var s: Dictionary = Overlay.verified_session(BINDING, ent, load, 1000)
	test(s["status"] == "ready", "valid_server_pair")
	test(Overlay.slot_if_fresh(s, BINDING, "armament", 1001) == "mistveil_jian", "runtime_resolves_owned")
	test(Overlay.slot_if_fresh(s, BINDING, "armament", 121001) == "", "expiry_fails_closed")
	test(Overlay.slot_if_fresh(s, "f".repeat(64), "armament", 1001) == "", "account_switch")
	test(Overlay.slot_if_fresh(s, BINDING, "no_slot", 1001) == "", "invalid_slot")
	test(not s["can_grant"] and not s["can_save"], "never_grants_or_saves")
	var bad_ent: Dictionary = ent.duplicate(true)
	bad_ent["revision"] = 3
	test(Overlay.verified_session(BINDING, bad_ent, load, 1000)["status"] != "ready", "revision_mismatch")
	bad_ent = ent.duplicate(true)
	bad_ent["item_ids"] = []
	test(Overlay.verified_session(BINDING, bad_ent, load, 1000)["status"] != "ready", "no_unowned_items")
	var bad_load: Dictionary = load.duplicate(true)
	bad_load["paid_slots"]["armament"] = "bamboo_weave_robe"
	test(Overlay.verified_session(BINDING, ent, bad_load, 1000)["status"] != "ready", "slot_mismatch")
	bad_load = load.duplicate(true)
	bad_load["status"] = "loading"
	test(Overlay.verified_session(BINDING, ent, bad_load, 1000)["status"] != "ready", "loading_not_authorized")
	test(Overlay.verified_session("not_hash", ent, load, 1000)["status"] != "ready", "invalid_identity_binding")
	test(Overlay.empty()["status"] == "not_connected", "empty_default")
	if failed == 0:
		print("RC6_GODOT_RUNTIME_SMOKE=PASS_%d" % checks)
		quit(0)
	else:
		printerr("RC6_GODOT_RUNTIME_SMOKE=FAIL_%d" % failed)
		quit(1)
