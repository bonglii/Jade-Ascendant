extends SceneTree
const Snapshot = preload("res://scripts/managers/progress_backup_snapshot.gd")
const Build = preload("res://scripts/debug/build_metadata.gd")
const ErrorLogger = preload("res://scripts/debug/release_error_logger.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("PUBLIC_READINESS_QA " + label)
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_paid_v2_qa"): quit(2); return
	create_timer(30.0).timeout.connect(func(): push_error("PUBLIC_READINESS_QA_TIMEOUT"); quit(1))
	for i: int in range(8): await process_frame
	var snapshot: Dictionary = Snapshot.capture()
	check(not snapshot.is_empty(), "capture all nine permanent domains")
	if snapshot.is_empty(): print("PUBLIC_READINESS_QA_CAPTURE=EMPTY"); quit(1); return
	check(snapshot.domains.size() == 9 and snapshot.domains.has("cultivation_mastery"), "mastery retained")
	check(snapshot.domains.equipment.has("weapon_levels"), "weapon levels retained")
	check(Snapshot.valid(Snapshot.integer_tree(JSON.parse_string(JSON.stringify(snapshot)))) , "JSON round trip canonical integers")
	var invalid: Dictionary = snapshot.duplicate(true); invalid.domains.erase("cultivation_mastery")
	check(not Snapshot.valid(invalid), "incomplete historical eight-domain draft rejected")
	invalid = snapshot.duplicate(true); invalid.domains.journey.active_run_stage_id = 1
	check(not Snapshot.valid(invalid), "active runs excluded")
	invalid = snapshot.duplicate(true); invalid.domains.pavilion.paid_wallet = {"balance": 999}
	check(not Snapshot.valid(invalid), "paid wallet excluded")
	invalid = snapshot.duplicate(true); invalid.domains.equipment.weapon_levels["missing_weapon"] = 50
	check(not Snapshot.valid(invalid), "unknown weapon rejected")
	check(not Snapshot.safe_tree({"email": "private", "value": 0}), "credentials and private fields excluded")
	check(not Snapshot.safe_tree({"count": -1}), "negative/corrupt counters rejected")
	check(not str(Build.read().version_name).is_empty(), "version never blank")
	var logger: Logger = ErrorLogger.new()
	var backtraces: Array[ScriptBacktrace] = []
	logger.call("_log_error", "private uid", "res://scripts/test.gd", 12, "secret purchase token", "private Firebase token", false, 0, backtraces)
	var events: Array = logger.call("drain")
	check(events.size() == 1 and JSON.stringify(events).find("secret") < 0 and JSON.stringify(events).find("private") < 0, "diagnostics keep locations only")
	check(events[0].source == "test.gd" and events[0].line == 12, "useful error location retained")
	var saver: Node = root.get_node("SaveManager")
	var before: Dictionary = snapshot.domains.duplicate(true)
	check(saver.write_save_batch(before), "atomic restore target batch accepts current permanent registry")
	for id: String in Snapshot.DOMAINS:
		var read: Dictionary = saver.read_save_data(id)
		check(bool(read.success) and read.data == before[id], "restore exact values: " + id)
	check(not saver.has_pending_transaction(), "restore leaves no unsettled journal")
	var after_crash: Dictionary = before.duplicate(true)
	after_crash.progression.spirit_stone += 123
	var staged: Dictionary = saver.call("_write_dictionary_to_path_atomic", "user://transaction.journal", {"version": 1, "targets": after_crash}, false)
	check(bool(staged.success), "simulate interrupted restore with committed nine-domain intent")
	saver.call("_recover_pending_transaction")
	check(not saver.has_pending_transaction() and saver.read_save_data("progression").data.spirit_stone == after_crash.progression.spirit_stone, "restart replays exact restore targets")
	saver.call("_recover_pending_transaction")
	check(saver.read_save_data("progression").data.spirit_stone == after_crash.progression.spirit_stone, "repeat recovery never adds currency twice")
	var manager: Node = root.get_node("ProgressBackupManager")
	check(not manager.can_restore() and not manager.can_backup(), "signed-out backup/restore refused")
	var client: Node = load("res://tests/fixtures/progress_backup_manager_fixture.gd").new()
	root.add_child(client)
	var owner: String = "a".repeat(64)
	client.set("_owner", owner); client.set("_nonce", 42); client.set("busy", true); client.set("_pending", {"kind": "read", "owner": owner})
	client.call("_response", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify({"version": 1, "owner_binding": owner, "backup": {"revision": 1, "updated_at": 1, "snapshot": snapshot}}).to_utf8_buffer(), 42, owner)
	check(int(client.get("revision")) == 1 and client.call("can_restore"), "account-owned remote snapshot accepted")
	check(not bool((client.call("get_status") as Dictionary).auto_enabled), "fresh install does not overwrite remote backup automatically")
	client.set("_local", {"owner": "b".repeat(64), "approved": true, "revision": 1})
	check(not client.call("can_backup") and client.call("can_restore"), "local progress from another owner cannot be uploaded into new account")
	client.set("test_owner", "b".repeat(64))
	check(not client.call("can_restore") and not client.call("can_backup"), "account switch immediately fences old backup actions")
	client.set("busy", true); client.set("_pending", {"kind": "read", "owner": owner})
	client.call("_response", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), "{}".to_utf8_buffer(), 42, owner)
	check((client.get("remote") as Dictionary).is_empty(), "late old-account callback clears old snapshot")
	client.queue_free()
	print("PUBLIC_READINESS_QA checks=%d failures=%d" % [checks, failures])
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
