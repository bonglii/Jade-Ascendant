extends SceneTree

## Subphase E1 disposable-runner integration.
## Reviewed candidate staging -> read-only restore review contract.
## No backup vault, write barrier, registered restore primitive, network, or native transport.

const STAGER_PATH: String = "res://scripts/managers/cloud_transfer_candidate_stager_qa.gd"
const CONTRACT_PATH: String = "res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
const REVIEW_PATH: String = "res://scripts/managers/cloud_restore_review_qa.gd"
const OWNER: String = "controlled_transfer_disposable_owner"
const REMOTE_REVISION: int = 23
const EXPECTED_DOMAIN_COUNT: int = 8
const EXPECTED_DIGEST: String = "9700dd8cc68cc0f02c05f7f365976b8891f3b2c158a37abdff58d542de8c804e"
const SIDECARS = [
	"", ".backup", ".rollback", ".tmp", ".restore.tmp", ".restore.rollback",
	".restore.recovery.tmp", ".restore.recovery.discard",
]

var checks: int = 0
var failures: int = 0
var saver: Node
var stager: RefCounted
var contract: RefCounted
var review: RefCounted
var candidate_draft: Dictionary = {}
var local_payloads: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("Restore review QA requires disposable-runner gates.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		quit(2)
		return
	var stager_script: Script = load(STAGER_PATH) as Script
	var contract_script: Script = load(CONTRACT_PATH) as Script
	var review_script: Script = load(REVIEW_PATH) as Script
	if stager_script == null or contract_script == null or review_script == null:
		quit(2)
		return
	stager = stager_script.new() as RefCounted
	contract = contract_script.new() as RefCounted
	review = review_script.new() as RefCounted

	_expect(_reset_candidate_namespace(), "Start with empty controlled-transfer QA namespace")
	candidate_draft = _candidate_draft()
	local_payloads = _build_local_payloads(candidate_draft)
	_expect(_seed_registered_local_state(), "Seed exact eight valid registered local primaries")
	if failures != 0:
		_finish()
		return

	var inspected: Dictionary = contract.call("inspect_draft", candidate_draft, OWNER)
	_expect(inspected.get("valid") == true, "Candidate draft passes full permanent contract")
	var digest: String = str(contract.call("hash_draft", candidate_draft))
	_expect(digest == EXPECTED_DIGEST, "Candidate digest remains cross-language pinned fixture")
	var staged: Dictionary = stager.call(
		"stage_reviewed_snapshot_for_qa", _reviewed_record(candidate_draft, digest), OWNER
	)
	_expect(staged.get("ok") == true, "Reviewed snapshot stages isolated candidate files")
	if not bool(staged.get("ok", false)):
		_finish()
		return
	var ready: Dictionary = stager.call("inspect_ready_for_qa", str(staged["ready_path"]), OWNER)
	_expect(ready.get("ok") == true, "Independent candidate inspection passes before review")
	_expect(ready.get("remote_revision") == REMOTE_REVISION, "Reviewed candidate retains remote revision")
	_expect(ready.get("remote_digest") == digest, "Reviewed candidate retains remote digest")
	if not bool(ready.get("ok", false)):
		_finish()
		return

	var before_review: Dictionary = _registered_fingerprints()
	var result: Dictionary = review.call("build_restore_review_for_qa", ready, OWNER)
	_expect(result.get("ok") == true and result.get("code") == "RESTORE_REVIEW_READY",
		"Read-only restore review becomes ready")
	_expect(result.get("owner_verified") == true, "Review confirms owner binding without exposing full UID")
	_expect(str(result.get("owner_display", "")) != OWNER, "UI-safe owner display masks full UID")
	_expect(result.get("remote_revision") == REMOTE_REVISION, "Review exposes reviewed remote revision")
	_expect(result.get("remote_digest") == digest, "Review exposes reviewed remote digest")
	_expect(result.get("domain_count") == EXPECTED_DOMAIN_COUNT, "Review contains exact eight domains")
	_expect(result.get("captured_at_unix") == 1700001234, "Review retains snapshot capture timestamp")
	_expect(result.get("same_count") == 2, "Review identifies two byte-identical domains")
	_expect(result.get("changed_count") == 6, "Review identifies six changed domains")
	_expect(result.get("local_issue_count") == 0, "Valid local state has no preimage issue")
	_expect(result.get("preimage_source_files_ready") == true, "Valid eight-domain local state is eligible for future preimage capture")
	_expect(result.get("preimage_backup_required") == true, "Durable preimage remains mandatory before execution")
	_expect(result.get("preimage_runtime_guards_checked") == false, "E1 never claims transient runtime guards were checked")
	_expect(result.get("execution_preconditions_met") == false, "Review alone never satisfies execution preconditions")
	_expect(result.get("decision_required") == true, "Explicit decision remains mandatory")
	_expect(result.get("decision_options") == ["KEEP_LOCAL", "RESTORE_CLOUD"], "Only explicit keep/restore decisions are represented")
	_expect(result.get("restore_allowed") == false, "Review never self-authorizes restore")
	_expect(result.get("execution_allowed") == false, "Review cannot execute restore")
	_expect(result.get("cloud_mutation_enabled") == false, "Review cannot mutate cloud state")
	_expect(result.get("raw_payload_included") == false, "Review output contains no raw save payload")
	_expect(_sha256_shape(str(result.get("local_state_fingerprint", ""))), "Local state gets opaque fingerprint")
	_expect(_sha256_shape(str(result.get("review_id", ""))), "Review gets stable opaque review id")
	_expect(_expected_domain_states(result.get("domain_states", {})), "Per-domain SAME/DIFFERENT summary is exact")
	var serialized: String = JSON.stringify(result)
	_expect("processed_grant_ids" not in serialized, "Review output omits grant identifiers")
	_expect("celestial_jade" not in serialized, "Review output omits economy values")
	_expect("item_counts" not in serialized, "Review output omits inventory contents")
	_expect(_registered_fingerprints() == before_review, "Review mutates zero registered primaries or sidecars")

	var foreign: Dictionary = review.call("build_restore_review_for_qa", ready, "foreign_owner")
	_expect(foreign.get("code") == "ACCOUNT_MISMATCH", "Foreign account cannot review another owner's candidate")
	var unsafe: Dictionary = ready.duplicate(true)
	unsafe["restore_allowed"] = true
	_expect(review.call("build_restore_review_for_qa", unsafe, OWNER).get("code") == "READY_RECORD_UNSAFE_FLAGS",
		"Incoming candidate metadata cannot self-authorize restore")
	var mismatched: Dictionary = ready.duplicate(true)
	mismatched["remote_digest"] = "a".repeat(64) if digest != "a".repeat(64) else "b".repeat(64)
	_expect(review.call("build_restore_review_for_qa", mismatched, OWNER).get("code") == "REMOTE_DIGEST_MISMATCH",
		"Manifest/ready digest mismatch is rejected")
	var escaped: Dictionary = ready.duplicate(true)
	escaped["candidate_paths"] = (ready["candidate_paths"] as Dictionary).duplicate(true)
	escaped["candidate_paths"]["journey"] = saver.call("get_save_path", "journey")
	_expect(review.call("build_restore_review_for_qa", escaped, OWNER).get("code") == "CANDIDATE_PATH_MISMATCH",
		"Candidate path cannot escape immutable ready directory")

	var journey_path: String = str(saver.call("get_save_path", "journey"))
	_expect(_remove_if_present(journey_path), "Fault setup removes one local primary")
	var missing_before: Dictionary = _registered_fingerprints()
	var missing_review: Dictionary = review.call("build_restore_review_for_qa", ready, OWNER)
	_expect(missing_review.get("ok") == true, "Missing local primary remains reviewable")
	_expect(missing_review.get("local_missing_domains") == ["journey"], "Missing domain is surfaced without raw payload")
	_expect(missing_review.get("preimage_source_files_ready") == false, "Missing primary blocks future durable preimage source")
	_expect(missing_review.get("execution_preconditions_met") == false, "Missing primary remains execution-blocked")
	_expect(_registered_fingerprints() == missing_before, "Missing-state review remains read-only")
	_expect(_write_var(journey_path, local_payloads["journey"]), "Restore local journey fixture after missing-state test")

	var equipment_tmp: String = str(saver.call("get_save_path", "equipment")) + ".tmp"
	_expect(_write_var(equipment_tmp, local_payloads["equipment"]), "Fault setup creates unsettled local temp artifact")
	var unsettled_before: Dictionary = _registered_fingerprints()
	var unsettled_review: Dictionary = review.call("build_restore_review_for_qa", ready, OWNER)
	_expect(unsettled_review.get("ok") == true, "Unsettled local artifact remains reviewable")
	_expect(unsettled_review.get("local_unsettled_domains") == ["equipment"], "Unsettled domain is surfaced safely")
	_expect(unsettled_review.get("preimage_source_files_ready") == false, "Unsettled artifact blocks future preimage source")
	_expect(unsettled_review.get("execution_preconditions_met") == false, "Unsettled artifact remains execution-blocked")
	_expect(_registered_fingerprints() == unsettled_before, "Unsettled-state review remains read-only")
	_expect(_remove_if_present(equipment_tmp), "Remove unsettled temp artifact after review test")

	var progression_path: String = str(saver.call("get_save_path", "progression"))
	_expect(_write_var(progression_path, {"version": int(saver.call("get_save_schema_version", "progression"))}),
		"Fault setup writes schema-shaped but incomplete local primary")
	var invalid_before: Dictionary = _registered_fingerprints()
	var invalid_review: Dictionary = review.call("build_restore_review_for_qa", ready, OWNER)
	_expect(invalid_review.get("ok") == true, "Invalid local primary remains reviewable")
	_expect(invalid_review.get("local_invalid_domains") == ["progression"], "Invalid local domain is surfaced safely")
	_expect(invalid_review.get("preimage_source_files_ready") == false, "Invalid primary blocks future durable preimage source")
	_expect(invalid_review.get("execution_preconditions_met") == false, "Invalid primary remains execution-blocked")
	_expect(_registered_fingerprints() == invalid_before, "Invalid-state review remains read-only")
	_expect(_write_var(progression_path, local_payloads["progression"]), "Restore progression fixture after invalid-state test")

	_expect(_reset_candidate_namespace(), "Cleanup candidate namespace")
	_finish()


func _environment_armed() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_TEST_ONLY") == "1"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_RESTORE_REVIEW_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_REVIEW_ACK") == "DISPOSABLE_RUNNER_ONLY"
	)


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
			"achievements": {"version": 1, "progress": {"controlled_transfer": 5}, "unlocked": [], "claimed": []},
			"daily_quests": {"version": 1, "date_key": "2099-03-03", "progress": {}, "completed": [], "claimed": []},
			"equipment": {"version": 1, "equipped_item_ids": {"armament": "", "robe": "", "bracer": "", "boots": "", "pendant": ""}, "ascension_stars": {}},
			"idle_cultivation": {"version": 1, "last_claim_unix": 300, "last_observed_unix": 350, "lifetime_claim_seconds": 50, "shard_progress_units": 9, "processed_rewarded_grant_ids": []},
			"inventory": {"version": 1, "item_counts": {}},
			"journey": {"version": 1, "selected_chapter_id": 1, "selected_stage_id": 1, "active_run_chapter_id": 0, "active_run_stage_id": 0, "unlocked_stage_keys": [], "cleared_stage_keys": []},
			"pavilion": {"version": 1, "meditation_date": "", "cosmetic_id": "plain", "owned_cosmetics": ["plain"], "celestial_jade": 88, "pavilion_seals": 0, "processed_grant_ids": []},
			"progression": {"version": 1, "spirit_stone": 1234, "vitality_level": 2, "sword_power_level": 3, "swift_qi_level": 1},
		},
	}


func _build_local_payloads(draft: Dictionary) -> Dictionary:
	var candidate_domains: Dictionary = draft["domains"]
	return {
		"achievements": (candidate_domains["achievements"] as Dictionary).duplicate(true),
		"daily_quests": {"version": 1, "date_key": "2099-01-01", "progress": {}, "completed": [], "claimed": []},
		"equipment": {"version": 1, "equipped_item_ids": {}, "ascension_stars": {}},
		"idle_cultivation": {"version": 1, "last_claim_unix": 10, "last_observed_unix": 10, "lifetime_claim_seconds": 0, "shard_progress_units": 0, "processed_rewarded_grant_ids": []},
		"inventory": (candidate_domains["inventory"] as Dictionary).duplicate(true),
		"journey": {"version": 1, "selected_chapter_id": 1, "selected_stage_id": 2, "active_run_chapter_id": 0, "active_run_stage_id": 0, "unlocked_stage_keys": [], "cleared_stage_keys": []},
		"pavilion": {"version": 1, "meditation_date": "", "cosmetic_id": "plain", "owned_cosmetics": ["plain"], "celestial_jade": 7, "pavilion_seals": 0, "processed_grant_ids": []},
		"progression": {"version": 1, "spirit_stone": 10, "vitality_level": 0, "sword_power_level": 0, "swift_qi_level": 0},
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


func _seed_registered_local_state() -> bool:
	for id in _ids():
		var base: String = str(saver.call("get_save_path", id))
		for suffix in SIDECARS:
			if not _remove_if_present(base + str(suffix)):
				return false
		if not _write_var(base, local_payloads[id]):
			return false
		# Sidecars are seeded only to prove review does not alter them.
		if id in ["pavilion", "progression"]:
			if not _write_var(base + ".backup", local_payloads[id]):
				return false
	return true


func _expected_domain_states(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var states: Dictionary = value
	return (
		states.get("achievements") == "SAME"
		and states.get("inventory") == "SAME"
		and states.get("daily_quests") == "DIFFERENT"
		and states.get("equipment") == "DIFFERENT"
		and states.get("idle_cultivation") == "DIFFERENT"
		and states.get("journey") == "DIFFERENT"
		and states.get("pavilion") == "DIFFERENT"
		and states.get("progression") == "DIFFERENT"
	)


func _registered_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	for id in _ids():
		var base: String = str(saver.call("get_save_path", id))
		var files: Dictionary = {}
		for suffix in SIDECARS:
			var path: String = base + str(suffix)
			files[str(suffix)] = {
				"exists": FileAccess.file_exists(path),
				"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
			}
		result[id] = files
	return result


func _reset_candidate_namespace() -> bool:
	var path: String = str(stager.call("qa_root")) if stager != null else "user://jade_controlled_transfer_qa/"
	if not DirAccess.dir_exists_absolute(path):
		return true
	return _remove_tree(path)


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
		push_error("CLOUD_RESTORE_REVIEW_QA_FAIL | " + note)


func _finish() -> void:
	print("JADE_CLOUD_RESTORE_REVIEW_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print("JADE_CLOUD_RESTORE_REVIEW_QA_PASS")
	quit(0 if failures == 0 else 1)
