extends SceneTree

## Multi-process real disk QA for the disconnected synthetic restore transaction.
## Every mutable path is under user://jade_gate9_qa/. No real player save path is used.
const VAULT_SCRIPT: String = "res://scripts/managers/cloud_local_backup_vault.gd"
const RESTORE_SCRIPT: String = "res://scripts/managers/cloud_local_restore_transaction.gd"
const QA_ROOT: String = "user://jade_gate9_qa/"
const SOURCE_ROOT: String = QA_ROOT + "source/"
const CANDIDATE_ROOT: String = QA_ROOT + "candidate/"
const OWNER: String = "restore_tx_qa"
const REMOTE_DIGEST: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

var checks: int = 0
var failures: int = 0
var saver: Node
var vault: RefCounted
var restore: RefCounted
var sources: Dictionary = {}
var candidates: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("JADE_GATE9_TEST_ONLY") != "1":
		push_error("Transactional restore QA requires isolated test mode.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		push_error("SaveManager autoload is required.")
		quit(2)
		return
	var vault_script: Script = load(VAULT_SCRIPT) as Script
	var restore_script: Script = load(RESTORE_SCRIPT) as Script
	if vault_script == null or restore_script == null:
		push_error("Restore QA scripts failed to load.")
		quit(2)
		return
	vault = vault_script.new() as RefCounted
	restore = restore_script.new() as RefCounted
	var stage: String = OS.get_environment("JADE_RESTORE_TX_STAGE")
	match stage:
		"apply_for_rollback":
			_stage_apply_for_rollback()
		"rollback_after_restart":
			_stage_rollback_after_restart()
		"apply_for_confirm":
			_stage_apply_for_confirm()
		"confirm_after_restart":
			_stage_confirm_after_restart()
		"fault":
			_stage_fault()
		"recover":
			_stage_recover()
		"recover_fault":
			_stage_recover_fault()
		"manual_rollback_fault":
			_stage_manual_rollback_fault()
		_:
			push_error("Unknown restore transaction QA stage: " + stage)
			quit(2)


func _stage_apply_for_rollback() -> void:
	if not _seed_clean_case():
		_finish("JADE_RESTORE_TX_APPLY_PASS")
		return
	var result: Dictionary = _begin("")
	_expect(result.get("ok") == true, "Successful synthetic restore applies")
	_expect(result.get("code") == "RESTORE_APPLIED_PENDING_CONFIRMATION",
		"Successful restore requires explicit confirmation")
	_expect(_live_state() == "candidate", "All eight primaries are candidate state")
	_expect(_valid_vault_count() == 1, "Preimage vault remains intact after apply")
	_finish("JADE_RESTORE_TX_APPLY_PASS")


func _stage_rollback_after_restart() -> void:
	_load_case_paths()
	var recovered: Dictionary = restore.call("recover_sandbox_restore_for_qa")
	_expect(recovered.get("ok") == true, "Restart reopens applied restore")
	_expect(str(recovered.get("code", "")) in [
		"RESTORE_APPLIED_PENDING_CONFIRMATION", "RESTORE_RECOVERED_APPLIED"
	], "Restart recognizes complete candidate state")
	var wrong: Dictionary = restore.call("rollback_sandbox_restore_for_qa", "foreign_owner")
	_expect(wrong.get("code") == "ACCOUNT_CHANGED", "Foreign account cannot rollback")
	var rolled: Dictionary = restore.call("rollback_sandbox_restore_for_qa", OWNER)
	_expect(rolled.get("ok") == true, "Same-account manual rollback succeeds")
	_expect(rolled.get("code") == "RESTORE_MANUAL_ROLLBACK_COMPLETE",
		"Manual rollback result is explicit")
	_expect(_live_state() == "preimage", "Manual rollback restores all eight preimages")
	_expect(_valid_vault_count() == 1, "Rollback retains durable preimage vault")
	_finish("JADE_RESTORE_TX_ROLLBACK_PASS")


func _stage_apply_for_confirm() -> void:
	if not _seed_clean_case():
		_finish("JADE_RESTORE_TX_CONFIRM_ARM_PASS")
		return
	var result: Dictionary = _begin("")
	_expect(result.get("ok") == true, "Confirmation scenario applies candidate")
	_expect(_live_state() == "candidate", "Confirmation scenario has complete candidate")
	_finish("JADE_RESTORE_TX_CONFIRM_ARM_PASS")


func _stage_confirm_after_restart() -> void:
	_load_case_paths()
	var recovered: Dictionary = restore.call("recover_sandbox_restore_for_qa")
	_expect(recovered.get("ok") == true, "Restart reopens candidate before confirmation")
	var wrong: Dictionary = restore.call("confirm_sandbox_restore_for_qa", "foreign_owner")
	_expect(wrong.get("code") == "ACCOUNT_CHANGED", "Foreign account cannot confirm")
	var confirmed: Dictionary = restore.call("confirm_sandbox_restore_for_qa", OWNER)
	_expect(confirmed.get("ok") == true, "Same-account confirmation succeeds")
	_expect(confirmed.get("code") == "RESTORE_CONFIRMED", "Confirmation code is explicit")
	_expect(confirmed.get("vault_cleanup_allowed") == true,
		"Confirmation only marks vault cleanup as eligible")
	_expect(_live_state() == "candidate", "Confirmation never mutates candidate primaries")
	_expect(_valid_vault_count() == 1, "Confirmation still retains vault in this gate")
	var inspected: Dictionary = restore.call("inspect_sandbox_restore_for_qa")
	_expect(inspected.get("phase") == "CONFIRMED", "Confirmed phase survives in durable markers")
	_finish("JADE_RESTORE_TX_CONFIRM_PASS")


func _stage_fault() -> void:
	if not _seed_clean_case():
		_finish("JADE_RESTORE_TX_FAULT_ARM_PASS")
		return
	var point: String = OS.get_environment("JADE_RESTORE_TX_FAULT")
	var result: Dictionary = _begin(point)
	_expect(result.get("code") == "QA_FAULT_INJECTED", "Requested fault is injected: " + point)
	_expect(str(result.get("fault_point", "")) == point, "Fault marker identifies exact boundary")
	_expect(_valid_vault_count() == 1, "Fault never deletes preimage vault")
	_finish("JADE_RESTORE_TX_FAULT_ARM_PASS")


func _stage_recover() -> void:
	_load_case_paths()
	var result: Dictionary = restore.call("recover_sandbox_restore_for_qa")
	_expect(result.get("ok") == true, "Restart recovery completes")
	var state: String = _live_state()
	_expect(state in ["preimage", "candidate"], "Recovery leaves no mixed eight-domain state")
	_expect(_valid_vault_count() == 1, "Restart recovery retains preimage vault")
	if state == "candidate":
		_expect(str(result.get("code", "")) in [
			"RESTORE_RECOVERED_APPLIED", "RESTORE_APPLIED_PENDING_CONFIRMATION"
		], "Complete candidate state is promoted, not partially rewritten")
	else:
		_expect(str(result.get("code", "")) in [
			"RESTORE_RECOVERED_ROLLED_BACK", "RESTORE_PREPARE_ABORTED",
			"RESTORE_ALREADY_ROLLED_BACK"
		], "Partial/precommit state deterministically resolves to preimage")
	_finish("JADE_RESTORE_TX_RESTART_RECOVERY_PASS")


func _stage_recover_fault() -> void:
	_load_case_paths()
	var point: String = OS.get_environment("JADE_RESTORE_TX_RECOVERY_FAULT")
	var result: Dictionary = restore.call("recover_sandbox_restore_for_qa", point)
	_expect(result.get("code") == "QA_FAULT_INJECTED", "Rollback recovery fault is injected")
	_expect(str(result.get("fault_point", "")) == point, "Rollback fault boundary is exact")
	_expect(_valid_vault_count() == 1, "Interrupted rollback retains preimage vault")
	_finish("JADE_RESTORE_TX_RECOVERY_FAULT_PASS")


func _stage_manual_rollback_fault() -> void:
	if not _seed_clean_case():
		_finish("JADE_RESTORE_TX_MANUAL_ROLLBACK_FAULT_PASS")
		return
	var applied: Dictionary = _begin("")
	_expect(applied.get("ok") == true, "Manual rollback fault scenario first applies candidate")
	var point: String = OS.get_environment("JADE_RESTORE_TX_RECOVERY_FAULT")
	var result: Dictionary = restore.call("rollback_sandbox_restore_for_qa", OWNER, point)
	_expect(result.get("code") == "QA_FAULT_INJECTED", "Manual rollback fault is injected")
	_expect(str(result.get("fault_point", "")) == point, "Manual rollback fault boundary is exact")
	_expect(_valid_vault_count() == 1, "Interrupted manual rollback retains preimage vault")
	_finish("JADE_RESTORE_TX_MANUAL_ROLLBACK_FAULT_PASS")


func _begin(fault_point: String) -> Dictionary:
	var ready: String = _single_valid_vault()
	return restore.call(
		"begin_sandbox_restore_for_qa",
		sources, candidates, ready, OWNER, 7, REMOTE_DIGEST, fault_point
	)


func _seed_clean_case() -> bool:
	if DirAccess.dir_exists_absolute(QA_ROOT):
		if not _remove_tree(QA_ROOT):
			_expect(false, "Remove prior disposable QA tree")
			return false
	if DirAccess.make_dir_recursive_absolute(SOURCE_ROOT) != OK:
		_expect(false, "Create synthetic source directory")
		return false
	if DirAccess.make_dir_recursive_absolute(CANDIDATE_ROOT) != OK:
		_expect(false, "Create synthetic candidate directory")
		return false
	_load_case_paths()
	for id in _ids():
		_expect(_write_var(str(sources[id]), _fixture(id, false)), "Write preimage " + id)
		_expect(_write_var(str(candidates[id]), _fixture(id, true)), "Write candidate " + id)
	var backup: Dictionary = vault.call("prepare_sandbox_backup_for_qa", sources, OWNER)
	_expect(backup.get("ok") == true, "Create durable Gate 9A preimage vault")
	_expect(backup.get("code") == "LOCAL_BACKUP_READY", "Preimage vault has ready commit marker")
	return failures == 0


func _load_case_paths() -> void:
	sources.clear()
	candidates.clear()
	for id in _ids():
		sources[id] = SOURCE_ROOT + id + ".save"
		candidates[id] = CANDIDATE_ROOT + id + ".save"


func _ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in saver.call("get_save_domain_ids_for_scope", "permanent"):
		ids.append(str(raw_id))
	ids.sort()
	return ids


func _fixture(id: String, candidate: bool) -> Dictionary:
	var data: Dictionary = {"version": int(saver.call("get_save_schema_version", id))}
	for key in saver.call("get_save_required_keys", id):
		if key in ["unlocked", "claimed", "completed", "unlocked_stage_keys", "cleared_stage_keys", "owned_cosmetics"]:
			data[key] = ["plain"] if key == "owned_cosmetics" else []
		elif key in ["progress", "item_counts", "equipped_item_ids"]:
			data[key] = {}
		elif key in ["date_key", "meditation_date", "cosmetic_id"]:
			data[key] = "plain" if key == "cosmetic_id" else ""
		elif key in ["selected_chapter_id", "selected_stage_id"]:
			data[key] = 1
		else:
			data[key] = 0
	if not candidate:
		if id == "pavilion":
			data["processed_grant_ids"] = ["iap:qa_local_only_token"]
		return data
	match id:
		"achievements":
			data["progress"] = {"qa_restore": 3}
		"daily_quests":
			data["date_key"] = "2099-01-01"
		"equipment":
			data["ascension_stars"] = {}
		"idle_cultivation":
			data["last_claim_unix"] = 100
			data["last_observed_unix"] = 120
			data["shard_progress_units"] = 7
		"inventory":
			data["item_counts"] = {"qa_restore_item": 1}
		"journey":
			data["selected_stage_id"] = 2
		"pavilion":
			data["celestial_jade"] = 77
		"progression":
			data["spirit_stone"] = 999
	return data


func _live_state() -> String:
	var ready: String = _single_valid_vault()
	if ready.is_empty():
		return "invalid"
	var mf: FileAccess = FileAccess.open(ready + "/manifest.bin", FileAccess.READ)
	if mf == null:
		return "invalid"
	var manifest: Variant = mf.get_var(false)
	mf.close()
	if not manifest is Dictionary:
		return "invalid"
	var all_preimage := true
	var all_candidate := true
	for id in _ids():
		var source: String = str(sources[id])
		if not FileAccess.file_exists(source):
			all_preimage = false
			all_candidate = false
			continue
		var live_hash: String = FileAccess.get_sha256(source)
		var preimage_hash: String = str(manifest["domain_files"][id]["primary"]["sha256"])
		var candidate_hash: String = FileAccess.get_sha256(str(candidates[id]))
		all_preimage = all_preimage and live_hash == preimage_hash
		all_candidate = all_candidate and live_hash == candidate_hash
	if all_preimage:
		return "preimage"
	if all_candidate:
		return "candidate"
	return "mixed"


func _single_valid_vault() -> String:
	var root_path := QA_ROOT + "vault"
	if not DirAccess.dir_exists_absolute(root_path):
		return ""
	for name in DirAccess.get_directories_at(root_path):
		if not name.begins_with("ready_"):
			continue
		var path := root_path + "/" + name
		if bool(vault.call("inspect_sandbox_backup_for_qa", path).get("ok", false)):
			return path
	return ""


func _valid_vault_count() -> int:
	var root_path := QA_ROOT + "vault"
	if not DirAccess.dir_exists_absolute(root_path):
		return 0
	var count := 0
	for name in DirAccess.get_directories_at(root_path):
		if name.begins_with("ready_"):
			var path := root_path + "/" + name
			if bool(vault.call("inspect_sandbox_backup_for_qa", path).get("ok", false)):
				count += 1
	return count


func _write_var(path: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(value)
	file.flush()
	file.close()
	return FileAccess.file_exists(path)


func _remove_tree(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
	for file_name in DirAccess.get_files_at(path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/" + file_name)) != OK:
			return false
	for dir_name in DirAccess.get_directories_at(path):
		if not _remove_tree(path + "/" + dir_name):
			return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _expect(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("RESTORE_TX_QA_FAIL | " + note)


func _finish(marker: String) -> void:
	print("JADE_RESTORE_TX_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print(marker)
	quit(0 if failures == 0 else 1)
