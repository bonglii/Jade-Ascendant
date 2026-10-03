extends SceneTree

## E2 QA integration:
## E1 reviewed candidate -> explicit KEEP_LOCAL / RESTORE_CLOUD decision ->
## durable preimage -> locked registered restore -> explicit rollback / confirm.
## Disposable CI only. No backend network, production UI, or automatic restore.

const STAGER_PATH: String = "res://scripts/managers/cloud_transfer_candidate_stager_qa.gd"
const CONTRACT_PATH: String = "res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
const REVIEW_PATH: String = "res://scripts/managers/cloud_restore_review_qa.gd"
const EXECUTION_PATH: String = "res://scripts/managers/cloud_restore_execution_qa.gd"
const RESTORE_PATH: String = "res://scripts/managers/cloud_registered_path_restore_qa.gd"

const OWNER: String = "restore_execution_disposable_owner"
const REMOTE_REVISION: int = 29

var checks: int = 0
var failures: int = 0
var saver: Node
var stager: RefCounted
var contract: RefCounted
var reviewer: RefCounted
var execution: RefCounted
var restore: RefCounted

var sources: Dictionary = {}
var preimage_hashes: Dictionary = {}
var backup_hashes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("Restore execution QA requires disposable GitHub Actions gates.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		quit(2)
		return

	var stager_script: Script = load(STAGER_PATH) as Script
	var contract_script: Script = load(CONTRACT_PATH) as Script
	var review_script: Script = load(REVIEW_PATH) as Script
	var execution_script: Script = load(EXECUTION_PATH) as Script
	var restore_script: Script = load(RESTORE_PATH) as Script
	if (
		stager_script == null or contract_script == null or review_script == null
		or execution_script == null or restore_script == null
	):
		quit(2)
		return

	stager = stager_script.new() as RefCounted
	contract = contract_script.new() as RefCounted
	reviewer = review_script.new() as RefCounted
	execution = execution_script.new() as RefCounted
	restore = restore_script.new() as RefCounted

	_expect(_reset_test_namespaces(), "Start from clean disposable E2 namespaces")
	sources = restore.call("registered_source_paths_for_qa")
	_expect(sources.size() == 8, "Exact eight registered permanent paths available")
	_expect(_seed_registered_preimage(), "Seed valid local preimage and backup sidecars")
	if failures != 0:
		_finish()
		return

	var ready: Dictionary = _stage_remote_candidate()
	_expect(ready.get("ok") == true, "Reviewed cloud candidate stages under isolated transfer namespace")
	if not bool(ready.get("ok", false)):
		_finish()
		return

	var review: Dictionary = reviewer.call(
		"build_restore_review_for_qa", ready, OWNER
	)
	_expect(review.get("ok") == true and review.get("code") == "RESTORE_REVIEW_READY",
		"E1 review is ready before any E2 decision")
	_expect(review.get("preimage_source_files_ready") == true,
		"E1 says source files are ready for durable preimage")
	_expect(int(review.get("local_issue_count", -1)) == 0,
		"E1 reports zero local file issues")
	_expect(int(review.get("changed_count", 0)) > 0,
		"Remote candidate differs from local state")
	_expect(review.get("execution_allowed") == false,
		"E1 review still cannot self-authorize execution")

	var baseline: Dictionary = _live_fingerprints()

	var kept: Dictionary = execution.call(
		"execute_review_decision_for_qa", ready, review, OWNER, "KEEP_LOCAL"
	)
	_expect(
		kept.get("ok") == true and kept.get("code") == "RESTORE_DECISION_KEEP_LOCAL",
		"Explicit KEEP_LOCAL is accepted"
	)
	_expect(kept.get("mutation_performed") == false,
		"KEEP_LOCAL performs no save mutation")
	_expect(_live_fingerprints() == baseline,
		"KEEP_LOCAL leaves every primary and sidecar byte-identical")
	_expect(not DirAccess.dir_exists_absolute(str(execution.call("qa_root")) + "active"),
		"KEEP_LOCAL creates no execution session")

	var tampered_review: Dictionary = review.duplicate(true)
	tampered_review["review_id"] = _other_hash(str(review["review_id"]))
	var tampered: Dictionary = execution.call(
		"execute_review_decision_for_qa", ready, tampered_review, OWNER, "RESTORE_CLOUD"
	)
	_expect(
		tampered.get("ok") == false
		and tampered.get("code") == "REVIEW_LOCAL_STATE_CHANGED",
		"Tampered review id is rejected before backup or mutation"
	)
	_expect(_live_fingerprints() == baseline,
		"Tampered review rejection changes zero live bytes")

	_expect(_mutate_progression_after_review(), "Inject one valid local change after user review")
	var stale: Dictionary = execution.call(
		"execute_review_decision_for_qa", ready, review, OWNER, "RESTORE_CLOUD"
	)
	_expect(
		stale.get("ok") == false
		and stale.get("code") == "REVIEW_LOCAL_STATE_CHANGED",
		"Stale review is rejected when local state changed after review")
	_expect(not DirAccess.dir_exists_absolute(str(execution.call("qa_root")) + "active"),
		"Stale review rejection creates no execution session")

	_expect(_seed_registered_preimage(), "Restore original local preimage after stale-review test")
	baseline = _live_fingerprints()
	review = reviewer.call("build_restore_review_for_qa", ready, OWNER)
	_expect(review.get("ok") == true, "Fresh review rebuild succeeds after local reset")

	var applied: Dictionary = execution.call(
		"execute_review_decision_for_qa", ready, review, OWNER, "RESTORE_CLOUD"
	)
	_expect(
		applied.get("ok") == true
		and applied.get("code") == "RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION",
		"Explicit RESTORE_CLOUD reaches applied-pending-confirmation"
	)
	_expect(applied.get("confirmation_required") == true,
		"Applied restore requires explicit terminal decision")
	_expect(applied.get("preimage_backup_ready") == true,
		"Durable preimage exists before applied state")
	_expect(applied.get("write_barrier_retained") == true,
		"Applied restore retains SaveManager write fence")
	_expect(applied.get("production_execution_allowed") == false,
		"QA execution never grants production restore authority")
	_expect(_live_matches_candidates(ready),
		"All eight live primaries exactly match reviewed candidate bytes")
	_expect(_backup_sidecars_intact(),
		"Apply preserves pre-existing .backup sidecars")

	var pending: Dictionary = execution.call(
		"inspect_execution_for_qa", OWNER, str(review["review_id"])
	)
	_expect(
		pending.get("ok") == true
		and pending.get("phase") == "APPLIED_PENDING_CONFIRMATION",
		"Execution session durably reports applied-pending-confirmation"
	)

	var wrong_resolution: Dictionary = execution.call(
		"resolve_applied_restore_for_qa",
		OWNER,
		_other_hash(str(review["review_id"])),
		"ROLLBACK"
	)
	_expect(
		wrong_resolution.get("ok") == false
		and wrong_resolution.get("code") == "RESTORE_EXECUTION_SESSION_INVALID",
		"Wrong review id cannot resolve an applied restore"
	)

	var rolled: Dictionary = execution.call(
		"resolve_applied_restore_for_qa",
		OWNER,
		str(review["review_id"]),
		"ROLLBACK"
	)
	_expect(
		rolled.get("ok") == true
		and rolled.get("code") == "RESTORE_EXECUTION_ROLLED_BACK",
		"Explicit rollback resolves applied restore"
	)
	_expect(rolled.get("confirmation_required") == false,
		"Rollback is terminal")
	_expect(_live_hashes() == preimage_hashes,
		"Rollback restores exact eight-domain preimage")
	_expect(_backup_sidecars_intact(),
		"Rollback preserves pre-existing .backup sidecars")
	_expect(not bool(saver.call("is_save_write_barrier_active")),
		"Terminal rollback releases SaveManager write fence")

	var rolled_state: Dictionary = execution.call(
		"inspect_execution_for_qa", OWNER, str(review["review_id"])
	)
	_expect(rolled_state.get("phase") == "ROLLED_BACK",
		"Execution inspection reports terminal rolled-back phase")

	# New disposable session for the confirm branch. The locked restore engine
	# retains terminal evidence by design, so the test explicitly cleans only
	# QA namespaces between independent scenarios.
	_expect(_reset_execution_and_restore_namespaces(),
		"Reset only disposable execution/restore namespaces between terminal scenarios")
	_expect(_live_hashes() == preimage_hashes,
		"Local preimage remains exact before confirm scenario")
	review = reviewer.call("build_restore_review_for_qa", ready, OWNER)
	_expect(review.get("ok") == true, "Fresh review rebuild succeeds for confirm scenario")

	var applied_for_confirm: Dictionary = execution.call(
		"execute_review_decision_for_qa", ready, review, OWNER, "RESTORE_CLOUD"
	)
	_expect(
		applied_for_confirm.get("ok") == true
		and applied_for_confirm.get("code") == "RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION",
		"Second explicit restore reaches pending-confirmation"
	)
	_expect(_live_matches_candidates(ready),
		"Confirm scenario applies exact reviewed candidate bytes")

	var confirmed: Dictionary = execution.call(
		"resolve_applied_restore_for_qa",
		OWNER,
		str(review["review_id"]),
		"CONFIRM"
	)
	_expect(
		confirmed.get("ok") == true
		and confirmed.get("code") == "RESTORE_EXECUTION_CONFIRMED",
		"Explicit confirm resolves applied restore"
	)
	_expect(confirmed.get("phase") == "CONFIRMED",
		"Confirm reports durable terminal phase")
	_expect(_live_matches_candidates(ready),
		"Confirmed state remains exact candidate bytes")
	_expect(_backup_sidecars_intact(),
		"Confirm preserves pre-existing .backup sidecars")
	_expect(not bool(saver.call("is_save_write_barrier_active")),
		"Terminal confirm releases SaveManager write fence")

	var idempotent_confirm: Dictionary = execution.call(
		"resolve_applied_restore_for_qa",
		OWNER,
		str(review["review_id"]),
		"CONFIRM"
	)
	_expect(
		idempotent_confirm.get("ok") == true
		and idempotent_confirm.get("already_terminal") == true,
		"Repeated same terminal confirmation is idempotent"
	)

	var opposite_after_confirm: Dictionary = execution.call(
		"resolve_applied_restore_for_qa",
		OWNER,
		str(review["review_id"]),
		"ROLLBACK"
	)
	_expect(
		opposite_after_confirm.get("ok") == false
		and opposite_after_confirm.get("code") == "RESTORE_ALREADY_CONFIRMED",
		"Opposite decision after confirmation is rejected")

	_finish()


func _stage_remote_candidate() -> Dictionary:
	var draft: Dictionary = _candidate_draft()
	var inspected: Dictionary = contract.call("inspect_draft", draft, OWNER)
	_expect(inspected.get("valid") == true, "Remote draft passes full eight-domain contract")
	var digest: String = str(contract.call("hash_draft", draft))
	_expect(_sha256_shape(digest), "Remote draft has canonical SHA-256 digest")
	var reviewed: Dictionary = {
		"ok": true,
		"code": "QA_LATEST_SNAPSHOT_REVIEWED",
		"qaOnly": true,
		"ownerUid": OWNER,
		"revision": REMOTE_REVISION,
		"digest": digest,
		"draft": draft.duplicate(true),
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
	}
	var staged: Dictionary = stager.call(
		"stage_reviewed_snapshot_for_qa", reviewed, OWNER
	)
	if not bool(staged.get("ok", false)):
		return staged
	return stager.call("inspect_ready_for_qa", str(staged["ready_path"]), OWNER)


func _environment_armed() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_TEST_ONLY") == "1"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_RESTORE_REVIEW_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_REVIEW_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_RESTORE_EXECUTION_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_EXECUTION_ACK") == "DISPOSABLE_RUNNER_ONLY"
	)


func _reset_test_namespaces() -> bool:
	var okay: bool = true
	for path in [
		str(stager.call("qa_root")),
		str(restore.call("qa_root")),
		str(execution.call("qa_root")),
	]:
		if DirAccess.dir_exists_absolute(path):
			okay = _remove_tree(path) and okay
	if saver.call("has_save_file", "checkpoint"):
		var checkpoint: String = str(saver.call("get_save_path", "checkpoint"))
		okay = _remove_if_present(checkpoint) and okay
		okay = _remove_if_present(checkpoint + ".backup") and okay
	return okay


func _reset_execution_and_restore_namespaces() -> bool:
	var okay: bool = true
	for path in [str(restore.call("qa_root")), str(execution.call("qa_root"))]:
		if DirAccess.dir_exists_absolute(path):
			okay = _remove_tree(path) and okay
	return okay


func _seed_registered_preimage() -> bool:
	preimage_hashes.clear()
	backup_hashes.clear()
	for id in _ids():
		var path: String = str(sources[id])
		for suffix in [
			"", ".backup", ".tmp", ".rollback", ".restore.tmp", ".restore.rollback",
			".restore.recovery.tmp", ".restore.recovery.discard",
		]:
			if not _remove_if_present(path + suffix):
				return false
		if not _write_var(path, _preimage_fixture(id)):
			return false
		preimage_hashes[id] = FileAccess.get_sha256(path)
	if not _write_var(str(sources["pavilion"]) + ".backup", _preimage_fixture("pavilion")):
		return false
	if not _write_var(str(sources["progression"]) + ".backup", _preimage_fixture("progression")):
		return false
	backup_hashes["pavilion"] = FileAccess.get_sha256(str(sources["pavilion"]) + ".backup")
	backup_hashes["progression"] = FileAccess.get_sha256(str(sources["progression"]) + ".backup")
	return true


func _mutate_progression_after_review() -> bool:
	var path: String = str(sources["progression"])
	var data: Dictionary = _preimage_fixture("progression")
	data["spirit_stone"] = 777
	return _write_var(path, data)


func _candidate_draft() -> Dictionary:
	var versions: Dictionary = {}
	for id in _ids():
		versions[id] = int(saver.call("get_save_schema_version", id))
	return {
		"draft_snapshot_version": 2,
		"owner_uid": OWNER,
		"captured_at_unix": 1700004321,
		"domain_schema_versions": versions,
		"domains": {
			"achievements": {
				"version": 1, "progress": {"restore_execution": 7},
				"unlocked": [], "claimed": [],
			},
			"daily_quests": {
				"version": 1, "date_key": "2099-04-04", "progress": {},
				"completed": [], "claimed": [],
			},
			"equipment": {
				"version": 1,
				"equipped_item_ids": {
					"armament": "", "robe": "", "bracer": "", "boots": "", "pendant": "",
				},
				"ascension_stars": {},
			},
			"idle_cultivation": {
				"version": 1, "last_claim_unix": 400, "last_observed_unix": 460,
				"lifetime_claim_seconds": 60, "shard_progress_units": 12,
				"processed_rewarded_grant_ids": [],
			},
			"inventory": {"version": 1, "item_counts": {}},
			"journey": {
				"version": 1, "selected_chapter_id": 1, "selected_stage_id": 1,
				"active_run_chapter_id": 0, "active_run_stage_id": 0,
				"unlocked_stage_keys": [], "cleared_stage_keys": [],
			},
			"pavilion": {
				"version": 1, "meditation_date": "", "cosmetic_id": "plain",
				"owned_cosmetics": ["plain"], "celestial_jade": 166,
				"pavilion_seals": 0, "processed_grant_ids": [],
			},
			"progression": {
				"version": 1, "spirit_stone": 2468, "vitality_level": 3,
				"sword_power_level": 4, "swift_qi_level": 2,
			},
		},
	}


func _preimage_fixture(id: String) -> Dictionary:
	var data: Dictionary = {"version": int(saver.call("get_save_schema_version", id))}
	for key in saver.call("get_save_required_keys", id):
		if key in [
			"unlocked", "claimed", "completed",
			"unlocked_stage_keys", "cleared_stage_keys", "owned_cosmetics"
		]:
			data[key] = ["plain"] if key == "owned_cosmetics" else []
		elif key in ["progress", "item_counts", "equipped_item_ids"]:
			data[key] = {}
		elif key in ["date_key", "meditation_date", "cosmetic_id"]:
			data[key] = "plain" if key == "cosmetic_id" else ""
		elif key in ["selected_chapter_id", "selected_stage_id"]:
			data[key] = 1
		else:
			data[key] = 0
	return data


func _live_matches_candidates(ready: Dictionary) -> bool:
	var candidates: Dictionary = ready.get("candidate_paths", {})
	for id in _ids():
		var live: String = str(sources[id])
		var candidate: String = str(candidates.get(id, ""))
		if not FileAccess.file_exists(live) or not FileAccess.file_exists(candidate):
			return false
		if FileAccess.get_sha256(live) != FileAccess.get_sha256(candidate):
			return false
	return true


func _live_hashes() -> Dictionary:
	var result: Dictionary = {}
	for id in _ids():
		var path: String = str(sources[id])
		result[id] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	return result


func _live_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for id in _ids():
		var base: String = str(sources[id])
		var files: Dictionary = {}
		for suffix in [
			"", ".backup", ".tmp", ".rollback",
			".restore.tmp", ".restore.rollback",
			".restore.recovery.tmp", ".restore.recovery.discard",
		]:
			var path: String = base + suffix
			files[suffix] = {
				"exists": FileAccess.file_exists(path),
				"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
			}
		result[id] = files
	return result


func _backup_sidecars_intact() -> bool:
	for id in backup_hashes:
		var path: String = str(sources[id]) + ".backup"
		if not FileAccess.file_exists(path):
			return false
		if FileAccess.get_sha256(path) != str(backup_hashes[id]):
			return false
	return true


func _ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in saver.call("get_save_domain_ids_for_scope", "permanent"):
		ids.append(str(raw_id))
	ids.sort()
	return ids


func _other_hash(value: String) -> String:
	var alternate: String = "a".repeat(64)
	if value == alternate:
		alternate = "b".repeat(64)
	return alternate


func _sha256_shape(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


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


func _expect(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CLOUD_RESTORE_EXECUTION_QA_FAIL | " + note)


func _finish() -> void:
	print("JADE_CLOUD_RESTORE_EXECUTION_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print("JADE_CLOUD_RESTORE_EXECUTION_QA_PASS")
	quit(0 if failures == 0 else 1)
