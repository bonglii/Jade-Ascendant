extends SceneTree

## CI-only integration: reviewed eight-domain record -> isolated candidate files ->
## explicit handoff into the already locked registered-path restore harness ->
## manual rollback. No Firebase/network path exists in this runner.

const STAGER_PATH: String = "res://scripts/managers/cloud_transfer_candidate_stager_qa.gd"
const CONTRACT_PATH: String = "res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
const RESTORE_PATH: String = "res://scripts/managers/cloud_registered_path_restore_qa.gd"
const OWNER: String = "controlled_transfer_disposable_owner"
const REMOTE_REVISION: int = 17
const EXPECTED_JS_DIGEST: String = "9700dd8cc68cc0f02c05f7f365976b8891f3b2c158a37abdff58d542de8c804e"

var checks: int = 0
var failures: int = 0
var saver: Node
var stager: RefCounted
var contract: RefCounted
var restore: RefCounted
var sources: Dictionary = {}
var restore_candidates: Dictionary = {}
var preimage_hashes: Dictionary = {}
var backup_hashes: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("Controlled transfer QA requires GitHub Actions disposable-runner gates.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		quit(2)
		return
	var stager_script: Script = load(STAGER_PATH) as Script
	var contract_script: Script = load(CONTRACT_PATH) as Script
	var restore_script: Script = load(RESTORE_PATH) as Script
	if stager_script == null or contract_script == null or restore_script == null:
		quit(2)
		return
	stager = stager_script.new() as RefCounted
	contract = contract_script.new() as RefCounted
	restore = restore_script.new() as RefCounted

	_expect(_reset_test_namespaces(), "Start from disposable QA namespaces")
	_load_registered_paths()
	_expect(sources.size() == 8 and restore_candidates.size() == 8,
		"Exact eight registered permanent paths available")
	_expect(_seed_registered_preimage(), "Seed disposable registered preimage")
	if failures != 0:
		_finish()
		return

	var draft: Dictionary = _candidate_draft()
	var inspected: Dictionary = contract.call("inspect_draft", draft, OWNER)
	_expect(
		inspected.get("valid") == true,
		"Eight-domain candidate passes local full contract | reason="
		+ str(inspected.get("reason", "missing"))
	)
	var digest: String = str(contract.call("hash_draft", draft))
	_expect(_sha256_shape(digest), "Canonical full-draft digest produced")
	_expect(digest == EXPECTED_JS_DIGEST, "Godot canonical digest matches reviewed backend JavaScript fixture")
	var reviewed: Dictionary = _reviewed_record(draft, digest)

	var foreign: Dictionary = reviewed.duplicate(true)
	foreign["ownerUid"] = "foreign_owner"
	_expect(
		stager.call("stage_reviewed_snapshot_for_qa", foreign, OWNER).get("code") == "ACCOUNT_MISMATCH",
		"Foreign reviewed owner rejected before staging"
	)
	var bad_digest: Dictionary = reviewed.duplicate(true)
	bad_digest["digest"] = "a".repeat(64) if digest != "a".repeat(64) else "b".repeat(64)
	_expect(
		stager.call("stage_reviewed_snapshot_for_qa", bad_digest, OWNER).get("code") == "SNAPSHOT_DIGEST_MISMATCH",
		"Digest mismatch rejected before staging"
	)
	var unsafe_flags: Dictionary = reviewed.duplicate(true)
	unsafe_flags["restore_allowed"] = true
	_expect(
		stager.call("stage_reviewed_snapshot_for_qa", unsafe_flags, OWNER).get("code") == "REVIEW_RECORD_UNSAFE_FLAGS",
		"Incoming record cannot self-authorize restore"
	)
	var incomplete: Dictionary = reviewed.duplicate(true)
	incomplete["draft"] = draft.duplicate(true)
	incomplete["draft"]["domains"] = (draft["domains"] as Dictionary).duplicate(true)
	incomplete["draft"]["domains"].erase("idle_cultivation")
	_expect(
		stager.call("stage_reviewed_snapshot_for_qa", incomplete, OWNER).get("code") == "SNAPSHOT_CONTENT_INVALID",
		"Incomplete eight-domain snapshot rejected"
	)
	var raw_token: Dictionary = reviewed.duplicate(true)
	raw_token["draft"] = draft.duplicate(true)
	raw_token["draft"]["domains"] = (draft["domains"] as Dictionary).duplicate(true)
	raw_token["draft"]["domains"]["pavilion"] = (
		(draft["domains"]["pavilion"] as Dictionary).duplicate(true)
	)
	raw_token["draft"]["domains"]["pavilion"]["processed_grant_ids"] = [
		"iap:jade_pouch_100:SYNTHETIC_PRIVATE_TOKEN_NEVER_TRANSFER"
	]
	_expect(
		stager.call("stage_reviewed_snapshot_for_qa", raw_token, OWNER).get("code") == "SNAPSHOT_CONTENT_INVALID",
		"Raw Play token is rejected before candidate serialization"
	)

	var before_stage: Dictionary = _live_hashes()
	var staged: Dictionary = stager.call("stage_reviewed_snapshot_for_qa", reviewed, OWNER)
	_expect(staged.get("ok") == true and staged.get("code") == "TRANSFER_CANDIDATES_READY",
		"Reviewed snapshot becomes durable isolated candidate set")
	_expect(staged.get("domain_count") == 8, "Ready candidate set contains exactly eight domains")
	_expect(staged.get("restore_allowed") == false, "Candidate staging never authorizes restore")
	_expect(staged.get("explicit_decision_required") == true, "Candidate staging requires explicit restore decision")
	_expect(_live_hashes() == before_stage, "Candidate staging mutates zero registered primary files")
	if not bool(staged.get("ok", false)):
		_finish()
		return

	var reopened: RefCounted = (load(STAGER_PATH) as Script).new() as RefCounted
	var ready: Dictionary = reopened.call(
		"inspect_ready_for_qa", str(staged["ready_path"]), OWNER
	)
	_expect(ready.get("ok") == true, "Independent stager instance reopens durable candidate set")
	_expect(ready.get("remote_revision") == REMOTE_REVISION, "Remote revision survives staging")
	_expect(ready.get("remote_digest") == digest, "Remote digest survives staging")

	var staged_paths: Dictionary = ready.get("candidate_paths", {})
	_expect(_copy_staged_candidates(staged_paths), "Copy staged bytes into locked restore harness candidate namespace")
	_expect(_restore_candidates_match(staged_paths), "Restore harness candidates are byte-identical to staged transfer files")
	_expect(_live_hashes() == before_stage, "Handoff into restore candidate namespace still mutates zero primaries")

	var backup: Dictionary = restore.call("prepare_registered_preimage_for_qa", OWNER)
	_expect(backup.get("ok") == true, "Create durable preimage before any restore mutation")
	_expect(backup.get("restore_allowed") == false, "Preimage capture does not self-authorize restore")
	var applied: Dictionary = restore.call(
		"begin_registered_restore_for_qa", OWNER, REMOTE_REVISION, digest, ""
	)
	_expect(applied.get("ok") == true, "Explicit decision applies staged transfer through locked restore engine")
	_expect(applied.get("confirmation_required") == true, "Applied transfer remains pending explicit confirmation")
	_expect(applied.get("write_barrier_retained") == true, "Applied transfer keeps SaveManager write fence")
	_expect(_live_matches(staged_paths), "All eight registered primaries become staged candidate bytes")
	_expect(_backups_intact(), "Existing .backup sidecars remain byte-identical after apply")

	var rolled: Dictionary = restore.call("rollback_registered_restore_for_qa", OWNER)
	_expect(rolled.get("ok") == true, "Explicit rollback resolves staged transfer")
	_expect(_live_hashes() == preimage_hashes, "Rollback restores all eight registered preimages")
	_expect(_backups_intact(), "Rollback preserves existing .backup sidecars")
	_expect(not bool(saver.call("is_save_write_barrier_active")), "Terminal rollback releases SaveManager write fence")
	_finish()


func _environment_armed() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_TEST_ONLY") == "1"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_ACK") == "DISPOSABLE_RUNNER_ONLY"
	)


func _reset_test_namespaces() -> bool:
	var okay: bool = true
	var transfer_root: String = str(stager.call("qa_root"))
	if DirAccess.dir_exists_absolute(transfer_root):
		okay = _remove_tree(transfer_root) and okay
	var restore_root: String = str(restore.call("qa_root"))
	if DirAccess.dir_exists_absolute(restore_root):
		okay = _remove_tree(restore_root) and okay
	if saver.call("has_save_file", "checkpoint"):
		var checkpoint: String = str(saver.call("get_save_path", "checkpoint"))
		okay = _remove_if_present(checkpoint) and okay
		okay = _remove_if_present(checkpoint + ".backup") and okay
	return okay


func _load_registered_paths() -> void:
	sources = restore.call("registered_source_paths_for_qa")
	restore_candidates = restore.call("candidate_paths_for_qa")
	if not restore_candidates.is_empty():
		DirAccess.make_dir_recursive_absolute(str(restore.call("qa_root")) + "candidate")


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


func _candidate_draft() -> Dictionary:
	var versions: Dictionary = {}
	for id in _ids():
		versions[id] = int(saver.call("get_save_schema_version", id))
	return {
		"draft_snapshot_version": 2,
		"owner_uid": OWNER,
		"captured_at_unix": 1700001234,
		"domain_schema_versions": versions,
		"domains": {
			"achievements": {
				"version": 1, "progress": {"controlled_transfer": 5},
				"unlocked": [], "claimed": [],
			},
			"daily_quests": {
				"version": 1, "date_key": "2099-03-03", "progress": {},
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
				"version": 1, "last_claim_unix": 300, "last_observed_unix": 350,
				"lifetime_claim_seconds": 50, "shard_progress_units": 9,
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
				"owned_cosmetics": ["plain"], "celestial_jade": 88,
				"pavilion_seals": 0, "processed_grant_ids": [],
			},
			"progression": {
				"version": 1, "spirit_stone": 1234, "vitality_level": 2,
				"sword_power_level": 3, "swift_qi_level": 1,
			},
		},
	}


func _reviewed_record(draft: Dictionary, digest: String) -> Dictionary:
	return {
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


func _preimage_fixture(id: String) -> Dictionary:
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
	if id == "pavilion":
		data["processed_grant_ids"] = ["iap:local_preimage_private_token_not_transferred"]
	return data


func _copy_staged_candidates(staged_paths: Dictionary) -> bool:
	if staged_paths.size() != restore_candidates.size():
		return false
	for id in _ids():
		if not staged_paths.has(id) or not restore_candidates.has(id):
			return false
		var source: String = str(staged_paths[id])
		var target: String = str(restore_candidates[id])
		if not _copy_exact(source, target):
			return false
	return true


func _copy_exact(source: String, target: String) -> bool:
	if not FileAccess.file_exists(source):
		return false
	var size: int = FileAccess.get_size(source)
	if size <= 0 or size > 1048576:
		return false
	var reader: FileAccess = FileAccess.open(source, FileAccess.READ)
	if reader == null:
		return false
	var bytes: PackedByteArray = reader.get_buffer(size)
	reader.close()
	if bytes.size() != size:
		return false
	var parent: String = target.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			return false
	var writer: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if writer == null:
		return false
	var stored: bool = writer.store_buffer(bytes)
	writer.flush()
	writer.close()
	return (
		stored
		and FileAccess.get_size(target) == size
		and FileAccess.get_sha256(target) == FileAccess.get_sha256(source)
	)


func _restore_candidates_match(staged_paths: Dictionary) -> bool:
	for id in _ids():
		var staged: String = str(staged_paths.get(id, ""))
		var restored: String = str(restore_candidates.get(id, ""))
		if not FileAccess.file_exists(staged) or not FileAccess.file_exists(restored):
			return false
		if FileAccess.get_sha256(staged) != FileAccess.get_sha256(restored):
			return false
	return true


func _live_matches(staged_paths: Dictionary) -> bool:
	for id in _ids():
		var live: String = str(sources[id])
		var staged: String = str(staged_paths[id])
		if not FileAccess.file_exists(live) or not FileAccess.file_exists(staged):
			return false
		if FileAccess.get_sha256(live) != FileAccess.get_sha256(staged):
			return false
	return true


func _live_hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for id in _ids():
		var path: String = str(sources.get(id, ""))
		hashes[id] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	return hashes


func _backups_intact() -> bool:
	for id in backup_hashes:
		var path: String = str(sources[id]) + ".backup"
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(backup_hashes[id]):
			return false
	return true


func _ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in saver.call("get_save_domain_ids_for_scope", "permanent"):
		ids.append(str(raw_id))
	ids.sort()
	return ids


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


func _sha256_shape(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _expect(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CONTROLLED_TRANSFER_QA_FAIL | " + note)


func _finish() -> void:
	print("JADE_CONTROLLED_TRANSFER_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print("JADE_CONTROLLED_TRANSFER_CANDIDATE_QA_PASS")
	quit(0 if failures == 0 else 1)
