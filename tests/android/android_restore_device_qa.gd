extends Control

## Android destructive restore QA runner.
##
## This scene is never referenced by the tracked production project. The
## dedicated PowerShell launcher exports it from `git archive HEAD` into an
## isolated `.restoreqa` Android package, then watches logcat and force-stops
## the app only when this runner emits an exact force-stop marker.
##
## The runner uses the SAME registered-path transactional restore implementation
## proven in CI. The build tool changes only that implementation's QA activation
## predicate inside the disposable archive so Android debug can enter it.

const RESTORE_SCRIPT_PATH: String = "res://scripts/managers/cloud_registered_path_restore_qa.gd"
const OWNER: String = "android_restore_device_qa_owner"
const FOREIGN_OWNER: String = "android_restore_device_foreign_owner"
const REMOTE_DIGEST: String = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
const REQUIRED_TOKEN: String = "ANDROID_DESTRUCTIVE_QA_ONLY"
const STATE_PATH: String = "user://jade_android_restore_device_state.json"
const STATE_TMP_PATH: String = STATE_PATH + ".tmp"
const STATE_VERSION: int = 1

const CASES: Array[String] = [
	"apply_rollback_restart",
	"apply_confirm_restart",
	"commit_fault_primary_to_rollback",
	"commit_fault_candidate_to_primary",
	"commit_fault_after_all_domains",
	"interrupted_recovery_rollback",
	"interrupted_manual_rollback",
	"owner_mismatch_after_restart",
	"corrupt_candidate_rejected",
	"checkpoint_guard",
]

@onready var status_label: Label = %StatusLabel

var saver: Node
var restore: RefCounted
var sources: Dictionary = {}
var candidates: Dictionary = {}
var state: Dictionary = {}
var stopped: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _qa_enabled():
		_fail("QA package is not correctly armed")
		return
	saver = get_node_or_null("/root/SaveManager")
	if saver == null:
		_fail("SaveManager autoload missing")
		return
	var script: Script = load(RESTORE_SCRIPT_PATH) as Script
	if script == null:
		_fail("registered restore implementation did not load")
		return
	restore = script.new() as RefCounted
	_load_paths()
	if sources.size() != 8 or candidates.size() != 8:
		_fail("expected exactly eight registered permanent paths")
		return
	state = _load_state()
	if state.is_empty():
		state = {
			"version": STATE_VERSION,
			"case_index": 0,
			"step": "start",
			"nonce": 0,
			"checks": 0,
			"failures": 0,
		}
		if not _save_state():
			_fail("could not create persistent QA state")
			return
	if int(state.get("version", -1)) != STATE_VERSION:
		_fail("unsupported persistent QA state version")
		return
	_run_current_case()


func _run_current_case() -> void:
	if stopped:
		return
	var case_index: int = int(state.get("case_index", 0))
	if case_index >= CASES.size():
		_pass_suite()
		return
	var case_name: String = CASES[case_index]
	var step: String = str(state.get("step", "start"))
	_set_status("Case %d/%d\n%s\n%s" % [case_index + 1, CASES.size(), case_name, step])
	print("JADE_ANDROID_RESTORE_CASE | case=", case_name, " | step=", step)
	match case_name:
		"apply_rollback_restart": _case_apply_rollback(step)
		"apply_confirm_restart": _case_apply_confirm(step)
		"commit_fault_primary_to_rollback": _case_commit_fault(step, "after_primary_to_rollback:inventory")
		"commit_fault_candidate_to_primary": _case_commit_fault(step, "after_candidate_to_primary:inventory")
		"commit_fault_after_all_domains": _case_commit_fault(step, "after_all_domains")
		"interrupted_recovery_rollback": _case_interrupted_recovery(step)
		"interrupted_manual_rollback": _case_interrupted_manual_rollback(step)
		"owner_mismatch_after_restart": _case_owner_mismatch(step)
		"corrupt_candidate_rejected": _case_corrupt_candidate(step)
		"checkpoint_guard": _case_checkpoint_guard(step)
		_: _fail("unknown case " + case_name)


func _case_apply_rollback(step: String) -> void:
	if step == "start":
		if not _seed_clean_case(true):
			return
		var applied: Dictionary = _begin("")
		if not _expect(bool(applied.get("ok", false)), "apply candidate before rollback restart"):
			return
		if not _expect(bool(applied.get("write_barrier_retained", false)), "apply retains write barrier"):
			return
		if not _expect(_live_state() == "candidate", "all eight domains are candidate before restart"):
			return
		if not _expect(_sidecars_intact(), "sidecars intact before rollback restart"):
			return
		_request_force_stop("resume")
		return
	if step != "resume":
		_fail("invalid apply_rollback_restart step")
		return
	if not _expect(_boot_barrier_active(), "boot barrier armed before rollback recovery"):
		return
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	if not _expect(bool(recovered.get("ok", false)), "restart recovery reopens candidate"):
		return
	if not _expect(_live_state() == "candidate", "restart recovery keeps complete candidate"):
		return
	var rolled: Dictionary = restore.call("rollback_registered_restore_for_qa", OWNER)
	if not _expect(bool(rolled.get("ok", false)), "explicit rollback completes after restart"):
		return
	if not _expect(_live_state() == "preimage", "rollback restores all eight preimages"):
		return
	if not _expect(_sidecars_intact(), "rollback preserves existing backups"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "terminal rollback releases barrier"):
		return
	_complete_case()


func _case_apply_confirm(step: String) -> void:
	if step == "start":
		if not _seed_clean_case(true):
			return
		var applied: Dictionary = _begin("")
		if not _expect(bool(applied.get("ok", false)), "apply candidate before confirmation restart"):
			return
		if not _expect(_live_state() == "candidate", "candidate complete before confirmation restart"):
			return
		_request_force_stop("resume")
		return
	if step != "resume":
		_fail("invalid apply_confirm_restart step")
		return
	if not _expect(_boot_barrier_active(), "boot barrier armed before confirmation recovery"):
		return
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	if not _expect(bool(recovered.get("ok", false)), "restart reopens pending confirmation"):
		return
	var confirmed: Dictionary = restore.call("confirm_registered_restore_for_qa", OWNER)
	if not _expect(bool(confirmed.get("ok", false)), "confirmation completes after restart"):
		return
	if not _expect(bool(confirmed.get("vault_cleanup_allowed", false)), "confirmed state only marks vault cleanup eligible"):
		return
	if not _expect(_live_state() == "candidate", "confirmation keeps all eight candidate primaries"):
		return
	if not _expect(_sidecars_intact(), "confirmation preserves prior backups"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "terminal confirmation releases barrier"):
		return
	_complete_case()


func _case_commit_fault(step: String, fault_point: String) -> void:
	if step == "start":
		if not _seed_clean_case(true):
			return
		var faulted: Dictionary = _begin(fault_point)
		if not _expect(str(faulted.get("code", "")) == "QA_FAULT_INJECTED", "commit fault injected at " + fault_point):
			return
		if not _expect(bool(saver.call("is_save_write_barrier_active")), "fault keeps runtime write fence"):
			return
		if not _expect(_sidecars_intact(), "commit fault preserves prior backups"):
			return
		_request_force_stop("resume")
		return
	if step != "resume":
		_fail("invalid commit fault step")
		return
	if not _expect(_boot_barrier_active(), "boot barrier armed after commit fault"):
		return
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	if not _expect(bool(recovered.get("ok", false)), "commit fault recovers after Android restart"):
		return
	var live: String = _live_state()
	if not _expect(live in ["preimage", "candidate"], "commit recovery never leaves mixed state"):
		return
	if live == "candidate":
		var rolled: Dictionary = restore.call("rollback_registered_restore_for_qa", OWNER)
		if not _expect(bool(rolled.get("ok", false)), "recovered candidate is explicitly rolled back"):
			return
	if not _expect(_live_state() == "preimage", "commit fault case ends at whole preimage"):
		return
	if not _expect(_sidecars_intact(), "commit fault recovery preserves backups"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "commit fault case ends with barrier clear"):
		return
	_complete_case()


func _case_interrupted_recovery(step: String) -> void:
	if step == "start":
		if not _seed_clean_case(true):
			return
		var faulted: Dictionary = _begin("after_primary_to_rollback:achievements")
		if not _expect(str(faulted.get("code", "")) == "QA_FAULT_INJECTED", "setup mixed commit for rollback interruption"):
			return
		_request_force_stop("recover_fault")
		return
	if step == "recover_fault":
		if not _expect(_boot_barrier_active(), "boot barrier armed before interrupted rollback"):
			return
		var faulted_recovery: Dictionary = restore.call(
			"recover_registered_restore_for_qa",
			OWNER,
			"rollback_after_preimage_to_primary:inventory"
		)
		if not _expect(str(faulted_recovery.get("code", "")) == "QA_FAULT_INJECTED", "rollback itself is interrupted on device"):
			return
		if not _expect(bool(saver.call("is_save_write_barrier_active")), "interrupted rollback keeps startup fence"):
			return
		if not _expect(_sidecars_intact(), "interrupted rollback preserves backups"):
			return
		_request_force_stop("final_recover")
		return
	if step != "final_recover":
		_fail("invalid interrupted recovery step")
		return
	if not _expect(_boot_barrier_active(), "second restart re-arms barrier"):
		return
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	if not _expect(bool(recovered.get("ok", false)), "second restart finishes whole-account rollback"):
		return
	if not _expect(_live_state() == "preimage", "interrupted rollback converges to all preimages"):
		return
	if not _expect(_sidecars_intact(), "completed interrupted rollback preserves backups"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "completed rollback releases barrier"):
		return
	_complete_case()


func _case_interrupted_manual_rollback(step: String) -> void:
	if step == "start":
		if not _seed_clean_case(true):
			return
		var applied: Dictionary = _begin("")
		if not _expect(bool(applied.get("ok", false)), "manual rollback interruption starts from applied candidate"):
			return
		var faulted: Dictionary = restore.call(
			"rollback_registered_restore_for_qa",
			OWNER,
			"rollback_after_target_to_discard:inventory"
		)
		if not _expect(str(faulted.get("code", "")) == "QA_FAULT_INJECTED", "manual rollback interrupted at inventory"):
			return
		if not _expect(bool(saver.call("is_save_write_barrier_active")), "manual rollback fault retains barrier"):
			return
		_request_force_stop("resume")
		return
	if step != "resume":
		_fail("invalid interrupted manual rollback step")
		return
	if not _expect(_boot_barrier_active(), "restart re-arms barrier after manual rollback interruption"):
		return
	var recovered: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	if not _expect(bool(recovered.get("ok", false)), "restart recovers interrupted manual rollback"):
		return
	if not _expect(_live_state() == "preimage", "manual rollback interruption converges to preimage"):
		return
	if not _expect(_sidecars_intact(), "manual rollback recovery preserves backups"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "manual rollback recovery releases barrier"):
		return
	_complete_case()


func _case_owner_mismatch(step: String) -> void:
	if step == "start":
		if not _seed_clean_case(true):
			return
		var applied: Dictionary = _begin("")
		if not _expect(bool(applied.get("ok", false)), "owner mismatch case applies candidate"):
			return
		_request_force_stop("resume")
		return
	if step != "resume":
		_fail("invalid owner mismatch step")
		return
	if not _expect(_boot_barrier_active(), "owner mismatch restart begins fenced"):
		return
	var foreign: Dictionary = restore.call("recover_registered_restore_for_qa", FOREIGN_OWNER)
	if not _expect(str(foreign.get("code", "")) == "RESTORE_INTENT_INVALID", "foreign owner cannot reopen restore intent"):
		return
	if not _expect(bool(saver.call("is_save_write_barrier_active")), "foreign owner rejection remains fail-closed"):
		return
	if not _expect(_live_state() == "candidate", "foreign owner cannot mutate candidate state"):
		return
	var correct: Dictionary = restore.call("recover_registered_restore_for_qa", OWNER)
	if not _expect(bool(correct.get("ok", false)), "correct owner can reopen after mismatch"):
		return
	var rolled: Dictionary = restore.call("rollback_registered_restore_for_qa", OWNER)
	if not _expect(bool(rolled.get("ok", false)), "correct owner resolves mismatch case by rollback"):
		return
	if not _expect(_live_state() == "preimage", "owner mismatch case restores preimage"):
		return
	if not _expect(_sidecars_intact(), "owner mismatch case preserves backups"):
		return
	_complete_case()


func _case_corrupt_candidate(step: String) -> void:
	if step != "start":
		_fail("invalid corrupt candidate step")
		return
	if not _seed_clean_case(true):
		return
	var inventory_candidate: String = str(candidates.get("inventory", ""))
	var file: FileAccess = FileAccess.open(inventory_candidate, FileAccess.WRITE)
	if file == null:
		_fail("could not corrupt isolated inventory candidate")
		return
	file.store_string("not-a-dictionary")
	file.flush()
	file.close()
	var result: Dictionary = _begin("")
	if not _expect(not bool(result.get("ok", true)), "corrupt candidate is rejected"):
		return
	if not _expect(str(result.get("code", "")).begins_with("CANDIDATE_"), "corrupt candidate failure is candidate-scoped"):
		return
	if not _expect(_live_state() == "preimage", "corrupt candidate never mutates registered primaries"):
		return
	if not _expect(_sidecars_intact(), "corrupt candidate rejection preserves backups"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "candidate validation failure leaves no barrier"):
		return
	_complete_case()


func _case_checkpoint_guard(step: String) -> void:
	if step != "start":
		_fail("invalid checkpoint guard step")
		return
	if not _seed_clean_case(false):
		return
	var checkpoint_path: String = str(saver.call("get_save_path", "checkpoint"))
	if not _write_var(checkpoint_path, {"version": int(saver.call("get_save_schema_version", "checkpoint"))}):
		_fail("could not create isolated checkpoint guard fixture")
		return
	var result: Dictionary = restore.call("prepare_registered_preimage_for_qa", OWNER)
	if not _expect(str(result.get("code", "")) == "ACTIVE_CHECKPOINT_UNSAFE", "active checkpoint blocks preimage capture"):
		return
	if not _expect(not bool(saver.call("is_save_write_barrier_active")), "checkpoint rejection leaves no barrier"):
		return
	if not _expect(_sidecars_intact(), "checkpoint rejection preserves backups"):
		return
	_remove_if_present(checkpoint_path)
	_remove_if_present(checkpoint_path + ".backup")
	_complete_case()


func _begin(point: String) -> Dictionary:
	return restore.call("begin_registered_restore_for_qa", OWNER, 21, REMOTE_DIGEST, point)


func _seed_clean_case(create_vault: bool) -> bool:
	if bool(saver.call("is_save_write_barrier_active")):
		_fail("cannot seed while SaveManager barrier is active")
		return false
	var qa_root: String = str(restore.call("qa_root"))
	if DirAccess.dir_exists_absolute(qa_root) and not _remove_tree(qa_root):
		_fail("could not clear previous isolated restore QA tree")
		return false
	_load_paths()
	var checkpoint_path: String = str(saver.call("get_save_path", "checkpoint"))
	_remove_if_present(checkpoint_path)
	_remove_if_present(checkpoint_path + ".backup")
	for id in _ids():
		var path: String = str(sources[id])
		for suffix in ["", ".backup", ".tmp", ".rollback", ".restore.tmp", ".restore.rollback", ".restore.recovery.tmp", ".restore.recovery.discard"]:
			_remove_if_present(path + suffix)
		if not _write_var(path, _fixture(id, false)):
			_fail("could not seed preimage " + id)
			return false
		if not _write_var(str(candidates[id]), _fixture(id, true)):
			_fail("could not seed candidate " + id)
			return false
	for id in ["pavilion", "progression"]:
		if not _write_var(str(sources[id]) + ".backup", _fixture(id, false)):
			_fail("could not seed existing backup " + id)
			return false
	var sidecars: Dictionary = {
		"pavilion": FileAccess.get_sha256(str(sources["pavilion"]) + ".backup"),
		"progression": FileAccess.get_sha256(str(sources["progression"]) + ".backup"),
	}
	if not _write_json(qa_root + "device_expected_sidecars.json", sidecars):
		_fail("could not persist expected backup hashes")
		return false
	if not create_vault:
		return true
	var backup: Dictionary = restore.call("prepare_registered_preimage_for_qa", OWNER)
	if not _expect(bool(backup.get("ok", false)), "create durable preimage vault"):
		return false
	if not _expect(bool(backup.get("write_barrier_used", false)), "preimage capture uses SaveManager barrier"):
		return false
	if not _expect(not bool(backup.get("restore_allowed", true)), "device QA never authorizes production restore"):
		return false
	return true


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
			data["processed_grant_ids"] = ["iap:android_restore_device_qa_local_token"]
		return data
	match id:
		"achievements": data["progress"] = {"android_restore_device": 9}
		"daily_quests": data["date_key"] = "2099-03-03"
		"equipment": data["ascension_stars"] = {}
		"idle_cultivation":
			data["last_claim_unix"] = 400
			data["last_observed_unix"] = 450
			data["shard_progress_units"] = 11
		"inventory": data["item_counts"] = {"android_restore_device_item": 3}
		"journey": data["selected_stage_id"] = 4
		"pavilion": data["celestial_jade"] = 99
		"progression": data["spirit_stone"] = 4321
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
		var candidate_path: String = str(candidates[id])
		if not FileAccess.file_exists(candidate_path):
			return "mixed"
		var candidate_hash: String = FileAccess.get_sha256(candidate_path)
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
	var raw: Variant = _read_json(str(restore.call("qa_root")) + "device_expected_sidecars.json")
	if not raw is Dictionary:
		return false
	var hashes: Dictionary = raw as Dictionary
	for id in ["pavilion", "progression"]:
		var path: String = str(sources[id]) + ".backup"
		if not FileAccess.file_exists(path):
			return false
		if FileAccess.get_sha256(path) != str(hashes.get(id, "")):
			return false
	return true


func _boot_barrier_active() -> bool:
	return (
		bool(saver.call("is_save_write_barrier_active"))
		and str(saver.call("get_save_write_barrier_owner")) == "registered_restore_bootstrap_qa"
	)


func _complete_case() -> void:
	if stopped:
		return
	state["case_index"] = int(state.get("case_index", 0)) + 1
	state["step"] = "start"
	if not _save_state():
		_fail("could not persist completed case")
		return
	call_deferred("_run_current_case")


func _request_force_stop(next_step: String) -> void:
	state["step"] = next_step
	state["nonce"] = int(state.get("nonce", 0)) + 1
	if not _save_state():
		_fail("could not persist pre-force-stop state")
		return
	stopped = true
	var case_name: String = CASES[int(state.get("case_index", 0))]
	var marker: String = (
		"JADE_ANDROID_RESTORE_FORCE_STOP | case=" + case_name
		+ " | next=" + next_step
		+ " | nonce=" + str(state["nonce"])
	)
	_set_status("FORCE-STOP REQUIRED\n" + case_name + "\nThe ADB controller will relaunch automatically.")
	print(marker)


func _expect(condition: bool, note: String) -> bool:
	state["checks"] = int(state.get("checks", 0)) + 1
	if condition:
		return true
	state["failures"] = int(state.get("failures", 0)) + 1
	_fail(note)
	return false


func _fail(note: String) -> void:
	if stopped:
		return
	stopped = true
	if not state.is_empty():
		_save_state()
	var case_name: String = "bootstrap"
	if not state.is_empty():
		var index: int = int(state.get("case_index", 0))
		if index >= 0 and index < CASES.size():
			case_name = CASES[index]
	var step: String = str(state.get("step", "unknown")) if not state.is_empty() else "unknown"
	var marker: String = "JADE_ANDROID_RESTORE_DEVICE_FAIL | case=" + case_name + " | step=" + step + " | note=" + note
	_set_status("FAIL\n" + note)
	push_error(marker)
	print(marker)


func _pass_suite() -> void:
	stopped = true
	var head_sha: String = str(ProjectSettings.get_setting("jade_android_restore_qa/head_sha", "unknown"))
	var marker: String = (
		"JADE_ANDROID_RESTORE_DEVICE_PASS | checks=" + str(state.get("checks", 0))
		+ " | cases=" + str(CASES.size())
		+ " | head=" + head_sha
	)
	_set_status("PASS\nAll Android destructive restore cases completed.\n" + head_sha)
	print(marker)


func _qa_enabled() -> bool:
	return (
		OS.has_feature("android")
		and OS.is_debug_build()
		and bool(ProjectSettings.get_setting("jade_android_restore_qa/enabled", false))
		and str(ProjectSettings.get_setting("jade_android_restore_qa/token", "")) == REQUIRED_TOKEN
	)


func _load_state() -> Dictionary:
	var raw: Variant = _read_json(STATE_PATH)
	return raw as Dictionary if raw is Dictionary else {}


func _save_state() -> bool:
	return _write_json(STATE_PATH, state)


func _write_json(path: String, value: Dictionary) -> bool:
	var parent: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			return false
	var tmp: String = path + ".tmp"
	_remove_if_present(tmp)
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	var verify: Variant = _read_json(tmp)
	if not verify is Dictionary:
		_remove_if_present(tmp)
		return false
	if FileAccess.file_exists(path) and not _remove_if_present(path):
		_remove_if_present(tmp)
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text: String = file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _write_var(path: String, value: Dictionary) -> bool:
	var parent: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			return false
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


func _set_status(message: String) -> void:
	if status_label != null:
		status_label.text = message
