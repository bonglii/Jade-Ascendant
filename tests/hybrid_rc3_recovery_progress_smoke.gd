extends SceneTree
const Progress = preload("res://scripts/monetization/hybrid_trusted_progress_rc3.gd")
const Recovery = preload("res://scripts/monetization/hybrid_summon_recovery_index_rc3.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("RC3_GODOT_FAIL=" + label)
func progress_fixture() -> Dictionary:
	return {"trusted_progression_contract_version": 1, "state": "verified",
		"canonical_revision": 2, "cleared_stage_keys": ["1-5", "2-1"],
		"paid_summon_unlocked": true, "authority": "server_verified_only", "display_only": true}
func recovery_fixture() -> Dictionary:
	return {"recovery_index_contract_version": 1, "state": "read_only", "request_ids": ["9cc242ed-56cc-46bc-8f8d-fb2b83388d7a"],
		"next_before": null, "coverage": "indexed_commits_only", "authority": "server_only"}
func parse_progress(d: Dictionary) -> Dictionary:
	return Progress.from_native_result(true,"TRUSTED_PROGRESSION_READ_ONLY",JSON.stringify(d))
func parse_recovery(d: Dictionary) -> Dictionary:
	return Recovery.from_native_result(true,"SUMMON_RECOVERY_INDEX_READ_ONLY",JSON.stringify(d))
func _run() -> void:
	var p: Dictionary = parse_progress(progress_fixture())
	verify(p["status"] == "ready", "progress_valid")
	verify(p["canonical_revision"] == 2, "progress_revision")
	verify(p["server_unlock_preview"] and not p["runtime_cutover"], "progress_display_only")
	verify(not p["can_provision"] and not p["can_spend"], "progress_never_grant")
	var pd: Dictionary = progress_fixture()
	pd["cleared_stage_keys"] = ["1-5", "1-5"]
	verify(parse_progress(pd)["status"] == "invalid_response", "progress_duplicate")
	pd = progress_fixture()
	pd["cleared_stage_keys"] = ["2-1"]
	verify(parse_progress(pd)["status"] == "invalid_response", "progress_missing_unlock")
	pd = progress_fixture()
	pd["can_spend"] = true
	verify(parse_progress(pd)["status"] == "invalid_response", "progress_extra")
	verify(Progress.empty()["status"] == "not_connected", "progress_empty")
	var r: Dictionary = parse_recovery(recovery_fixture())
	verify(r["status"] == "ready", "recovery_valid")
	verify(r["request_ids"].size() == 1, "recovery_ids")
	verify(r["next_before"] == -1, "recovery_no_cursor")
	verify(r["display_only"] and not r["can_grant"] and not r["can_spend"] and not r["runtime_cutover"], "recovery_no_grant")
	var rd: Dictionary = recovery_fixture()
	rd["request_ids"] = ["invalid-id"]
	verify(parse_recovery(rd)["status"] == "invalid_response", "recovery_bad_id")
	rd = recovery_fixture()
	rd["request_ids"] = ["9cc242ed-56cc-46bc-8f8d-fb2b83388d7a", "9cc242ed-56cc-46bc-8f8d-fb2b83388d7a"]
	verify(parse_recovery(rd)["status"] == "invalid_response", "recovery_duplicate")
	rd = recovery_fixture()
	rd["next_before"] = 100
	verify(parse_recovery(rd)["status"] == "invalid_response", "recovery_cursor_short_page")
	rd = recovery_fixture()
	rd["uid"] = "another"
	verify(parse_recovery(rd)["status"] == "invalid_response", "recovery_extra_uid")
	verify(Recovery.empty()["status"] == "not_connected", "recovery_empty")
	verify(Progress.from_native_result(false,"","")["status"] == "unavailable", "progress_network")
	verify(Recovery.from_native_result(false,"","")["status"] == "unavailable", "recovery_network")
	if failures == 0:
		print("RC3_GODOT_SMOKE=PASS_"+str(checks))
		quit(0)
	else:
		printerr("RC3_GODOT_SMOKE=FAIL_"+str(failures))
		quit(1)
