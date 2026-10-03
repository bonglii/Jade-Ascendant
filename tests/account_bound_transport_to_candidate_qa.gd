extends SceneTree

## CI-only bridge proof: exact account-bound emulator transport JSON -> strict
## Godot adapter -> already-locked controlled-transfer candidate stager.
## This runner never invokes the transactional restore engine and never mutates
## registered permanent save primaries.

const ADAPTER_PATH: String = "res://scripts/managers/cloud_account_bound_transport_adapter_qa.gd"
const STAGER_PATH: String = "res://scripts/managers/cloud_transfer_candidate_stager_qa.gd"
const RECORD_PATH: String = "res://qa_artifacts/account_bound_transport_record.json"
const OWNER: String = "account_bound_transport_to_godot_owner"
const EXPECTED_REVISION: int = 2
const EXPECTED_JADE: int = 144

var checks: int = 0
var failures: int = 0
var saver: Node
var adapter: RefCounted
var stager: RefCounted


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("Account-bound transport-to-Godot QA requires disposable GitHub Actions gates.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		quit(2)
		return
	var adapter_script: Script = load(ADAPTER_PATH) as Script
	var stager_script: Script = load(STAGER_PATH) as Script
	if adapter_script == null or stager_script == null:
		quit(2)
		return
	adapter = adapter_script.new() as RefCounted
	stager = stager_script.new() as RefCounted

	_expect(_reset_transfer_namespace(), "Start from empty controlled-transfer QA namespace")
	_expect(FileAccess.file_exists(RECORD_PATH), "Emulator-produced transport JSON artifact is present")
	var transport_json: String = _read_text(RECORD_PATH)
	_expect(not transport_json.is_empty(), "Transport JSON artifact is readable")
	if failures != 0:
		_finish()
		return

	var before_live: Dictionary = _registered_primary_fingerprints()
	var decoded: Dictionary = adapter.call(
		"decode_for_candidate_stager_qa", transport_json, OWNER
	)
	_expect(
		decoded.get("ok") == true
		and decoded.get("code") == "ACCOUNT_BOUND_TRANSPORT_NORMALIZED_FOR_STAGER",
		"Account-bound server record validates and normalizes for locked stager"
	)
	_expect(decoded.get("restore_allowed") == false, "Adapter never authorizes restore")
	_expect(decoded.get("cloud_mutation_enabled") == false, "Adapter never enables cloud mutation")
	_expect(decoded.get("explicit_decision_required") == true, "Explicit restore decision remains required")
	_expect(decoded.get("remote_revision") == EXPECTED_REVISION, "Exact server current revision survives JSON bridge")
	_expect(_sha256_shape(str(decoded.get("remote_digest", ""))), "Server digest survives JSON bridge")
	_expect(decoded.get("domain_count") == 8, "Transport-to-Godot bridge keeps exact eight-domain set")
	if not bool(decoded.get("ok", false)):
		_finish()
		return

	var reviewed: Dictionary = decoded.get("reviewed_record", {})
	_expect(reviewed.get("code") == "QA_LATEST_SNAPSHOT_REVIEWED", "Adapter emits locked stager review shape only after strict transport validation")
	_expect(reviewed.get("ownerUid") == OWNER, "Authenticated owner remains account-bound")
	_expect(reviewed.get("revision") == EXPECTED_REVISION, "Normalized stager record retains exact revision")
	_expect(reviewed.get("restore_allowed") == false, "Normalized stager record remains restore-disabled")

	var draft: Dictionary = reviewed.get("draft", {})
	var domains: Dictionary = draft.get("domains", {}) if draft is Dictionary else {}
	var pavilion: Dictionary = domains.get("pavilion", {}) if domains is Dictionary else {}
	_expect(pavilion.get("celestial_jade") == EXPECTED_JADE, "Expected current snapshot payload reached Godot unchanged")

	var staged: Dictionary = stager.call(
		"stage_reviewed_snapshot_for_qa", reviewed, OWNER
	)
	_expect(
		staged.get("ok") == true and staged.get("code") == "TRANSFER_CANDIDATES_READY",
		"Account-bound transport record becomes durable isolated candidate set"
	)
	_expect(staged.get("domain_count") == 8, "Candidate set contains exactly eight domains")
	_expect(staged.get("restore_allowed") == false, "Candidate staging remains restore-disabled")
	_expect(staged.get("explicit_decision_required") == true, "Candidate staging still requires explicit decision")
	_expect(_registered_primary_fingerprints() == before_live, "Candidate staging mutates zero registered permanent primaries")
	if not bool(staged.get("ok", false)):
		_finish()
		return

	var ready: Dictionary = stager.call(
		"inspect_ready_for_qa", str(staged.get("ready_path", "")), OWNER
	)
	_expect(ready.get("ok") == true, "Independent ready-set validation succeeds")
	_expect(ready.get("remote_revision") == EXPECTED_REVISION, "Ready candidate manifest retains exact remote revision")
	_expect(ready.get("remote_digest") == decoded.get("remote_digest"), "Ready candidate manifest retains exact remote digest")
	_expect(_candidate_payload_matches(ready), "Staged Pavilion candidate bytes decode to expected current payload")
	_expect(_registered_primary_fingerprints() == before_live, "Ready-set reopen still mutates zero registered primaries")
	_expect(_reset_transfer_namespace(), "Disposable candidate namespace cleans up after proof")
	_expect(_registered_primary_fingerprints() == before_live, "Cleanup leaves registered primaries byte-identical")
	_finish()


func _environment_armed() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_ACCOUNT_BOUND_TO_GODOT_TEST_ONLY") == "1"
		and OS.get_environment("JADE_ACCOUNT_BOUND_TO_GODOT_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_TEST_ONLY") == "1"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_ACK") == "DISPOSABLE_RUNNER_ONLY"
	)


func _candidate_payload_matches(ready: Dictionary) -> bool:
	var paths: Dictionary = ready.get("candidate_paths", {})
	var pavilion_path: String = str(paths.get("pavilion", ""))
	if pavilion_path.is_empty() or not FileAccess.file_exists(pavilion_path):
		return false
	var file: FileAccess = FileAccess.open(pavilion_path, FileAccess.READ)
	if file == null:
		return false
	var raw: Variant = file.get_var(false)
	file.close()
	return raw is Dictionary and raw.get("celestial_jade") == EXPECTED_JADE


func _registered_primary_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	var ids: Array[String] = []
	for raw_id in saver.call("get_save_domain_ids_for_scope", "permanent"):
		ids.append(str(raw_id))
	ids.sort()
	for id in ids:
		var path: String = str(saver.call("get_save_path", id))
		result[id] = {
			"exists": FileAccess.file_exists(path),
			"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
		}
	return result


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _reset_transfer_namespace() -> bool:
	var root_path: String = str(stager.call("qa_root"))
	if not DirAccess.dir_exists_absolute(root_path):
		return true
	return _remove_tree(root_path)


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
		push_error("ACCOUNT_BOUND_TO_GODOT_QA_FAIL | " + note)


func _finish() -> void:
	print("JADE_ACCOUNT_BOUND_TO_GODOT_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print("JADE_ACCOUNT_BOUND_TRANSPORT_TO_CANDIDATE_QA_PASS")
	quit(0 if failures == 0 else 1)
