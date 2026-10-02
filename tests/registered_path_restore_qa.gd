extends SceneTree

## Destructive only to the disposable runner's user:// registered permanent files.
## Release/debug exports cannot enter the harness because the implementation also
## requires OS.has_feature("editor") plus explicit CI environment acknowledgements.

const SCRIPT_PATH: String = "res://scripts/managers/cloud_registered_path_restore_qa.gd"
const OWNER: String = "registered_restore_disposable_owner"
const REMOTE_DIGEST: String = "b".repeat(64)
var checks: int = 0
var failures: int = 0
var saver: Node
var restore: RefCounted
var sources: Dictionary = {}
var candidates: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if (
		OS.get_environment("JADE_GATE9_TEST_ONLY") != "1"
		or OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") != "1"
		or OS.get_environment("JADE_REGISTERED_RESTORE_ACK") != "DISPOSABLE_RUNNER_ONLY"
	):
		push_error("Registered-path restore QA requires explicit disposable-runner gates.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		quit(2)
		return
	var script: Script = load(SCRIPT_PATH) as Script
	if script == null:
		quit(2)
		return
	restore = script.new() as RefCounted
	_load_paths()
	var stage: String = OS.get_environment("JADE_REGISTERED_RESTORE_STAGE")
	match stage:
		"apply_for_rollback": _stage_apply_for_rollback()
		"rollback_after_restart": _stage_rollback_after_restart()
		"apply_for_confirm": _stage_apply_for_confirm()
		"confirm_after_restart": _stage_confirm_after_restart()
		"fault": _stage_fault()
		"recover": _stage_recover()
		"recover_fault": _stage_recover_fault()
		"manual_rollback_fault": _stage_manual_rollback_fault()
		_:
			push_error("Unknown registered restore QA stage: " + stage)
			quit(2)


func _stage_apply_for_rollback() -> void:
	if not _seed_clean_case():
		_finish("JADE_REGISTERED_RESTORE_ROLLBACK_ARM_PASS")
		return
	var result: Dictionary = _begin("")
	_expect(result.get("ok") == true, "Apply candidate to exact registered paths")
	_expect(result.get("write_barrier_used") == true, "Registered apply owns SaveManager barrier")
	_expect(_live_state() == "candidate", "All eight registered paths become candidate")
	_expect(_sidecars_intact(), "Existing .backup sidecars remain byte-identical")
	_finish("JADE_REGISTERED_RESTORE_ROLLBACK_ARM_PASS")


func _stage_rollback_after_restart() -> void:
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	_expect(recovered.get("ok") == true, "Restart reopens registered-path candidate state")
	var wrong: Dictionary = restore.call("rollback_registered_restore_for_qa", "foreign_owner")
	_expect(wrong.get("code") == "RESTORE_INTENT_INVALID", "Foreign owner cannot open durable intent")
	var rolled: Dictionary = restore.call("rollback_registered_restore_for_qa", OWNER)
	_expect(rolled.get("ok") == true, "Same owner rolls back exact registered paths")
	_expect(_live_state() == "preimage", "Rollback restores all eight registered preimages")
	_expect(_sidecars_intact(), "Rollback never rotates existing SaveManager .backup sidecars")
	_finish("JADE_REGISTERED_RESTORE_ROLLBACK_PASS")


func _stage_apply_for_confirm() -> void:
	if not _seed_clean_case():
		_finish("JADE_REGISTERED_RESTORE_CONFIRM_ARM_PASS")
		return
	var result: Dictionary = _begin("")
	_expect(result.get("ok") == true, "Confirmation scenario applies candidate")
	_expect(_live_state() == "candidate", "Confirmation scenario has exact candidate state")
	_finish("JADE_REGISTERED_RESTORE_CONFIRM_ARM_PASS")


func _stage_confirm_after_restart() -> void:
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	_expect(recovered.get("ok") == true, "Restart reopens pending confirmation")
	var confirmed: Dictionary = restore.call("confirm_registered_restore_for_qa", OWNER)
	_expect(confirmed.get("ok") == true, "Same owner confirms registered restore")
	_expect(confirmed.get("vault_cleanup_allowed") == true, "Confirmation only marks cleanup eligible")
	_expect(_live_state() == "candidate", "Confirmation does not rewrite primaries")
	_expect(_sidecars_intact(), "Confirmation preserves prior .backup sidecars")
	var inspected: Dictionary = restore.call("inspect_registered_restore_for_qa", OWNER)
	_expect(inspected.get("phase") == "CONFIRMED", "Confirmed marker survives restart")
	_finish("JADE_REGISTERED_RESTORE_CONFIRM_PASS")


func _stage_fault() -> void:
	if not _seed_clean_case():
		_finish("JADE_REGISTERED_RESTORE_FAULT_ARM_PASS")
		return
	var point: String = OS.get_environment("JADE_REGISTERED_RESTORE_FAULT")
	var result: Dictionary = _begin(point)
	_expect(result.get("code") == "QA_FAULT_INJECTED", "Inject exact registered-path fault: " + point)
	_expect(str(result.get("fault_point", "")) == point, "Fault result identifies boundary")
	_expect(not bool(saver.call("is_save_write_barrier_active")), "Returned fault releases runtime barrier before process exit")
	_expect(_sidecars_intact(), "Injected commit fault does not touch .backup sidecars")
	_finish("JADE_REGISTERED_RESTORE_FAULT_ARM_PASS")


func _stage_recover() -> void:
	var result: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	_expect(result.get("ok") == true, "Registered-path restart recovery completes")
	var state: String = _live_state()
	_expect(state in ["preimage", "candidate"], "Recovery never leaves mixed registered save")
	_expect(_sidecars_intact(), "Recovery preserves .backup sidecars")
	_expect(not bool(saver.call("is_save_write_barrier_active")), "Recovery releases barrier")
	_finish("JADE_REGISTERED_RESTORE_RESTART_RECOVERY_PASS")


func _stage_recover_fault() -> void:
	var point: String = OS.get_environment("JADE_REGISTERED_RESTORE_RECOVERY_FAULT")
	var result: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER, point)
	_expect(result.get("code") == "QA_FAULT_INJECTED", "Inject rollback recovery fault")
	_expect(str(result.get("fault_point", "")) == point, "Recovery fault boundary is exact")
	_expect(_sidecars_intact(), "Interrupted rollback preserves .backup sidecars")
	_finish("JADE_REGISTERED_RESTORE_RECOVERY_FAULT_PASS")


func _stage_manual_rollback_fault() -> void:
	if not _seed_clean_case():
		_finish("JADE_REGISTERED_RESTORE_MANUAL_ROLLBACK_FAULT_PASS")
		return
	var applied: Dictionary = _begin("")
	_expect(applied.get("ok") == true, "Manual rollback fault case first applies candidate")
	var point: String = OS.get_environment("JADE_REGISTERED_RESTORE_RECOVERY_FAULT")
	var result: Dictionary = restore.call("rollback_registered_restore_for_qa", OWNER, point)
	_expect(result.get("code") == "QA_FAULT_INJECTED", "Inject manual rollback fault")
	_expect(str(result.get("fault_point", "")) == point, "Manual rollback boundary is exact")
	_expect(_sidecars_intact(), "Interrupted manual rollback preserves .backup sidecars")
	_finish("JADE_REGISTERED_RESTORE_MANUAL_ROLLBACK_FAULT_PASS")


func _begin(point: String) -> Dictionary:
	return restore.call("begin_registered_restore_for_qa", OWNER, 11, REMOTE_DIGEST, point)


func _seed_clean_case() -> bool:
	var qa_root: String = str(restore.call("qa_root"))
	if DirAccess.dir_exists_absolute(qa_root) and not _remove_tree(qa_root):
		_expect(false, "Remove prior registered-path QA tree")
		return false
	_load_paths()
	if bool(saver.call("has_save_file", "checkpoint")):
		var checkpoint_path: String = str(saver.call("get_save_path", "checkpoint"))
		_remove_if_present(checkpoint_path)
		_remove_if_present(checkpoint_path + ".backup")
	for id in _ids():
		var path: String = str(sources[id])
		for suffix in ["", ".backup", ".tmp", ".rollback", ".restore.tmp", ".restore.rollback", ".restore.recovery.tmp", ".restore.recovery.discard"]:
			_remove_if_present(path + suffix)
		_expect(_write_var(path, _fixture(id, false)), "Write registered preimage " + id)
		_expect(_write_var(str(candidates[id]), _fixture(id, true)), "Write registered candidate " + id)
	if not _write_var(str(sources["pavilion"]) + ".backup", _fixture("pavilion", false)):
		_expect(false, "Write Pavilion prior sidecar")
	if not _write_var(str(sources["progression"]) + ".backup", _fixture("progression", false)):
		_expect(false, "Write progression prior sidecar")
	var sidecars: Dictionary = {
		"pavilion": FileAccess.get_sha256(str(sources["pavilion"]) + ".backup"),
		"progression": FileAccess.get_sha256(str(sources["progression"]) + ".backup")
	}
	_expect(_write_var(qa_root + "expected_sidecars.bin", sidecars), "Persist expected sidecar hashes")
	var backup: Dictionary = restore.call("prepare_registered_preimage_for_qa", OWNER)
	_expect(backup.get("ok") == true, "Create registered-path durable preimage")
	_expect(backup.get("write_barrier_used") == true, "Preimage capture owns SaveManager barrier")
	_expect(not bool(backup.get("restore_allowed", true)), "Preimage capture never authorizes production restore")
	return failures == 0


func _load_paths() -> void:
	sources = restore.call("registered_source_paths_for_qa")
	candidates = restore.call("candidate_paths_for_qa")
	if not candidates.is_empty():
		DirAccess.make_dir_recursive_absolute(str(restore.call("qa_root")) + "candidate")


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
			data["processed_grant_ids"] = ["iap:registered_qa_local_only_token"]
		return data
	match id:
		"achievements": data["progress"] = {"registered_restore": 5}
		"daily_quests": data["date_key"] = "2099-02-02"
		"equipment": data["ascension_stars"] = {}
		"idle_cultivation":
			data["last_claim_unix"] = 300
			data["last_observed_unix"] = 350
			data["shard_progress_units"] = 9
		"inventory": data["item_counts"] = {"registered_restore_item": 2}
		"journey": data["selected_stage_id"] = 3
		"pavilion": data["celestial_jade"] = 88
		"progression": data["spirit_stone"] = 1234
	return data


func _live_state() -> String:
	var manifest: Dictionary = _single_manifest()
	if manifest.is_empty():
		return "invalid"
	var all_preimage: bool = true
	var all_candidate: bool = true
	for id in _ids():
		var live: String = str(sources[id])
		if not FileAccess.file_exists(live):
			return "mixed"
		var live_hash: String = FileAccess.get_sha256(live)
		var preimage_hash: String = str(manifest["domain_files"][id]["primary"]["sha256"])
		var candidate_hash: String = FileAccess.get_sha256(str(candidates[id]))
		all_preimage = all_preimage and live_hash == preimage_hash
		all_candidate = all_candidate and live_hash == candidate_hash
	if all_preimage:
		return "preimage"
	if all_candidate:
		return "candidate"
	return "mixed"


func _single_manifest() -> Dictionary:
	var vault_root: String = str(restore.call("qa_root")) + "vault"
	if not DirAccess.dir_exists_absolute(vault_root):
		return {}
	var ready: Array[String] = []
	for name in DirAccess.get_directories_at(vault_root):
		if name.begins_with("ready_"):
			ready.append(vault_root + "/" + name)
	if ready.size() != 1:
		return {}
	var file: FileAccess = FileAccess.open(ready[0] + "/manifest.bin", FileAccess.READ)
	if file == null:
		return {}
	var raw: Variant = file.get_var(false)
	file.close()
	return raw if raw is Dictionary else {}


func _sidecars_intact() -> bool:
	var file: FileAccess = FileAccess.open(str(restore.call("qa_root")) + "expected_sidecars.bin", FileAccess.READ)
	if file == null:
		return false
	var raw: Variant = file.get_var(false)
	file.close()
	if not raw is Dictionary:
		return false
	for id in ["pavilion", "progression"]:
		var path: String = str(sources[id]) + ".backup"
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(raw[id]):
			return false
	return true


func _write_var(path: String, value: Dictionary) -> bool:
	var parent: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		DirAccess.make_dir_recursive_absolute(parent)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(value)
	file.flush()
	file.close()
	return FileAccess.file_exists(path)


func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


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
		push_error("REGISTERED_RESTORE_QA_FAIL | " + note)


func _finish(marker: String) -> void:
	print("JADE_REGISTERED_RESTORE_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print(marker)
	quit(0 if failures == 0 else 1)
