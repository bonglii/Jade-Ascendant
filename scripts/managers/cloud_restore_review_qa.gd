extends RefCounted

const ContractScript = preload("res://scripts/managers/cloud_full_permanent_snapshot_contract.gd")

## Subphase E1 — restore review contract, QA only.
##
## Consumes an already-inspected controlled-transfer candidate set and compares
## its eight immutable candidate files against the eight registered local
## permanent primaries using read-only file access. It returns safe metadata and
## per-domain status only. It never writes a save, never captures a backup,
## never invokes restore, and never performs network I/O.

const DOMAIN_COUNT: int = 8
const MANIFEST_VERSION: int = 1
const MAX_DOMAIN_BYTES: int = 1048576
const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
const CONTROLLED_TRANSFER_ROOT: String = "user://jade_controlled_transfer_qa/"
const READY_KEYS = [
	"ok", "code", "upload_allowed", "restore_allowed", "cloud_mutation_enabled",
	"ready_path", "candidate_paths", "remote_revision", "remote_digest",
	"domain_count", "explicit_decision_required",
]
const MANIFEST_KEYS = [
	"version", "qa_only", "owner_uid", "remote_revision", "remote_digest",
	"draft_snapshot_version", "captured_at_unix", "domain_schema_versions",
	"domain_ids", "domain_files", "restore_allowed", "explicit_decision_required",
	"cloud_mutation_enabled",
]
const DOMAIN_ENTRY_KEYS = ["name", "schema", "bytes", "sha256"]
const DECISION_OPTIONS = ["KEEP_LOCAL", "RESTORE_CLOUD"]
const SAFE_STATES = ["SAME", "DIFFERENT", "LOCAL_MISSING", "LOCAL_INVALID"]
const UNSETTLED_SUFFIXES = [".tmp", ".rollback"]


func build_restore_review_for_qa(
	ready_record: Dictionary, authenticated_uid: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_REVIEW_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if not _has_exact_keys(ready_record, READY_KEYS):
		return _no("READY_RECORD_SHAPE_INVALID")
	if ready_record.get("ok") != true or str(ready_record.get("code", "")) != "TRANSFER_CANDIDATES_INSPECTED":
		return _no("READY_RECORD_NOT_INSPECTED")
	if (
		ready_record.get("upload_allowed") != false
		or ready_record.get("restore_allowed") != false
		or ready_record.get("cloud_mutation_enabled") != false
	):
		return _no("READY_RECORD_UNSAFE_FLAGS")
	if ready_record.get("explicit_decision_required") != true:
		return _no("READY_RECORD_DECISION_FLAG_MISSING")
	if typeof(ready_record.get("remote_revision")) != TYPE_INT or int(ready_record["remote_revision"]) <= 0:
		return _no("REMOTE_REVISION_INVALID")
	var remote_digest: String = str(ready_record.get("remote_digest", ""))
	if not _sha256_shape(remote_digest):
		return _no("REMOTE_DIGEST_INVALID")
	if typeof(ready_record.get("domain_count")) != TYPE_INT or int(ready_record["domain_count"]) != DOMAIN_COUNT:
		return _no("REMOTE_DOMAIN_COUNT_INVALID")
	if not (ready_record.get("candidate_paths") is Dictionary):
		return _no("CANDIDATE_PATHS_INVALID")

	var ids: Array[String] = _permanent_ids()
	if ids.size() != DOMAIN_COUNT:
		return _no("PERMANENT_DOMAIN_REGISTRY_CHANGED")
	var candidate_paths: Dictionary = ready_record["candidate_paths"]
	if not _has_exact_keys(candidate_paths, ids):
		return _no("CANDIDATE_DOMAIN_SET_INVALID")

	var ready_path: String = str(ready_record.get("ready_path", ""))
	if (
		not ready_path.begins_with(CONTROLLED_TRANSFER_ROOT + "ready_")
		or ".." in ready_path
		or not DirAccess.dir_exists_absolute(ready_path)
	):
		return _no("READY_PATH_SCOPE_INVALID")

	var manifest: Dictionary = _read_var_dictionary(ready_path + "/manifest.bin")
	if not _has_exact_keys(manifest, MANIFEST_KEYS):
		return _no("RESTORE_REVIEW_MANIFEST_INVALID")
	if manifest.get("version") != MANIFEST_VERSION or manifest.get("qa_only") != true:
		return _no("RESTORE_REVIEW_MANIFEST_INVALID")
	if str(manifest.get("owner_uid", "")) != authenticated_uid:
		return _no("ACCOUNT_MISMATCH")
	if (
		typeof(manifest.get("remote_revision")) != TYPE_INT
		or int(manifest["remote_revision"]) != int(ready_record["remote_revision"])
	):
		return _no("REMOTE_REVISION_MISMATCH")
	if str(manifest.get("remote_digest", "")) != remote_digest:
		return _no("REMOTE_DIGEST_MISMATCH")
	if manifest.get("draft_snapshot_version") != 2:
		return _no("RESTORE_REVIEW_MANIFEST_INVALID")
	if manifest.get("domain_ids") != ids:
		return _no("RESTORE_REVIEW_DOMAIN_SET_INVALID")
	if (
		manifest.get("restore_allowed") != false
		or manifest.get("cloud_mutation_enabled") != false
		or manifest.get("explicit_decision_required") != true
	):
		return _no("RESTORE_REVIEW_MANIFEST_UNSAFE_FLAGS")
	if typeof(manifest.get("captured_at_unix")) != TYPE_INT or int(manifest["captured_at_unix"]) < 0:
		return _no("REMOTE_CAPTURE_TIME_INVALID")
	if not (manifest.get("domain_schema_versions") is Dictionary) or not (manifest.get("domain_files") is Dictionary):
		return _no("RESTORE_REVIEW_MANIFEST_INVALID")
	var versions: Dictionary = manifest["domain_schema_versions"]
	var domain_files: Dictionary = manifest["domain_files"]
	if not _has_exact_keys(versions, ids) or not _has_exact_keys(domain_files, ids):
		return _no("RESTORE_REVIEW_DOMAIN_SET_INVALID")

	var domain_states: Dictionary = {}
	var same_domains: Array[String] = []
	var changed_domains: Array[String] = []
	var missing_domains: Array[String] = []
	var invalid_domains: Array[String] = []
	var unsettled_domains: Array[String] = []
	var backup_issue_domains: Array[String] = []
	var state_material: Array[String] = []
	var preimage_source_files_ready: bool = true
	var candidate_domains: Dictionary = {}

	for id in ids:
		var candidate_path: String = str(candidate_paths[id])
		var expected_candidate: String = ready_path + "/domains/" + id + ".save"
		if candidate_path != expected_candidate:
			return _no("CANDIDATE_PATH_MISMATCH")
		if not (domain_files.get(id) is Dictionary):
			return _no("CANDIDATE_METADATA_INVALID")
		var metadata: Dictionary = domain_files[id]
		if not _has_exact_keys(metadata, DOMAIN_ENTRY_KEYS):
			return _no("CANDIDATE_METADATA_INVALID")
		if str(metadata.get("name", "")) != id + ".save":
			return _no("CANDIDATE_METADATA_INVALID")
		if typeof(metadata.get("schema")) != TYPE_INT or int(metadata["schema"]) != SaveManager.get_save_schema_version(id):
			return _no("CANDIDATE_SCHEMA_INVALID")
		if typeof(metadata.get("bytes")) != TYPE_INT or int(metadata["bytes"]) <= 0 or int(metadata["bytes"]) > MAX_DOMAIN_BYTES:
			return _no("CANDIDATE_METADATA_INVALID")
		if not _sha256_shape(str(metadata.get("sha256", ""))):
			return _no("CANDIDATE_METADATA_INVALID")
		if typeof(versions.get(id)) != TYPE_INT or int(versions[id]) != SaveManager.get_save_schema_version(id):
			return _no("CANDIDATE_SCHEMA_INVALID")
		var candidate_check: Dictionary = _inspect_save_file(candidate_path, id)
		if not bool(candidate_check.get("ok", false)):
			return _no("CANDIDATE_CONTENT_INVALID")
		candidate_domains[id] = (candidate_check["data"] as Dictionary).duplicate(true)
		if int(candidate_check.get("bytes", -1)) != int(metadata.get("bytes", -2)):
			return _no("CANDIDATE_METADATA_INVALID")
		if str(candidate_check.get("sha256", "")) != str(metadata.get("sha256", "")):
			return _no("CANDIDATE_METADATA_INVALID")

		var live_path: String = SaveManager.get_save_path(id)
		var state: String
		var local_hash: String = ""
		if not FileAccess.file_exists(live_path):
			state = "LOCAL_MISSING"
			missing_domains.append(id)
			preimage_source_files_ready = false
		else:
			local_hash = FileAccess.get_sha256(live_path)
			var local_check: Dictionary = _inspect_save_file(live_path, id)
			if not bool(local_check.get("ok", false)):
				state = "LOCAL_INVALID"
				invalid_domains.append(id)
				preimage_source_files_ready = false
			elif local_hash == str(candidate_check["sha256"]):
				state = "SAME"
				same_domains.append(id)
			else:
				state = "DIFFERENT"
				changed_domains.append(id)
		if state not in SAFE_STATES:
			return _no("RESTORE_REVIEW_STATE_INVALID")
		domain_states[id] = state

		var unsettled: bool = false
		for suffix in UNSETTLED_SUFFIXES:
			if FileAccess.file_exists(live_path + str(suffix)):
				unsettled = true
		if unsettled:
			unsettled_domains.append(id)
			preimage_source_files_ready = false

		var backup_marker: String = "none"
		var backup_path: String = live_path + ".backup"
		if FileAccess.file_exists(backup_path):
			var backup_size: int = FileAccess.get_size(backup_path)
			if backup_size <= 0 or backup_size > MAX_DOMAIN_BYTES:
				backup_marker = "invalid_size"
				backup_issue_domains.append(id)
				preimage_source_files_ready = false
			else:
				var backup_hash: String = FileAccess.get_sha256(backup_path)
				if not _sha256_shape(backup_hash):
					backup_marker = "invalid_hash"
					backup_issue_domains.append(id)
					preimage_source_files_ready = false
				else:
					backup_marker = backup_hash
		state_material.append(
			id + ":" + state + ":" + local_hash + ":backup=" + backup_marker
			+ ":unsettled=" + str(unsettled)
		)


	var draft: Dictionary = {
		"draft_snapshot_version": int(manifest["draft_snapshot_version"]),
		"owner_uid": authenticated_uid,
		"captured_at_unix": int(manifest["captured_at_unix"]),
		"domain_schema_versions": versions.duplicate(true),
		"domains": candidate_domains,
	}
	var contract: RefCounted = ContractScript.new() as RefCounted
	var draft_check: Dictionary = contract.call("inspect_draft", draft, authenticated_uid)
	if not bool(draft_check.get("valid", false)):
		return _no("CANDIDATE_FULL_CONTRACT_INVALID")
	if str(contract.call("hash_draft", draft)) != remote_digest:
		return _no("CANDIDATE_CANONICAL_DIGEST_MISMATCH")

	var local_state_fingerprint: String = _sha256_text("\n".join(state_material))
	if not _sha256_shape(local_state_fingerprint):
		return _no("LOCAL_STATE_FINGERPRINT_FAILED")
	var review_id: String = _sha256_text(
		authenticated_uid + "|" + str(ready_record["remote_revision"]) + "|"
		+ remote_digest + "|" + local_state_fingerprint
	)
	if not _sha256_shape(review_id):
		return _no("RESTORE_REVIEW_ID_FAILED")

	return _yes("RESTORE_REVIEW_READY", {
		"owner_verified": true,
		"owner_display": _masked_uid(authenticated_uid),
		"remote_revision": int(ready_record["remote_revision"]),
		"remote_digest": remote_digest,
		"captured_at_unix": int(manifest["captured_at_unix"]),
		"domain_count": DOMAIN_COUNT,
		"domain_states": domain_states,
		"same_domains": same_domains,
		"changed_domains": changed_domains,
		"local_missing_domains": missing_domains,
		"local_invalid_domains": invalid_domains,
		"local_unsettled_domains": unsettled_domains,
		"local_backup_issue_domains": backup_issue_domains,
		"same_count": same_domains.size(),
		"changed_count": changed_domains.size(),
		"local_issue_count": (
			missing_domains.size() + invalid_domains.size()
			+ unsettled_domains.size() + backup_issue_domains.size()
		),
		"local_state_fingerprint": local_state_fingerprint,
		"review_id": review_id,
		"decision_required": true,
		"decision_options": DECISION_OPTIONS.duplicate(),
		"preimage_backup_required": true,
		"preimage_source_files_ready": preimage_source_files_ready,
		"preimage_runtime_guards_checked": false,
		"execution_preconditions_met": false,
		"execution_allowed": false,
		"raw_payload_included": false,
	})


func _inspect_save_file(path: String, domain_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var size: int = FileAccess.get_size(path)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return {"ok": false}
	var digest: String = FileAccess.get_sha256(path)
	if not _sha256_shape(digest):
		return {"ok": false}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var raw: Variant = file.get_var(false)
	file.close()
	if not (raw is Dictionary):
		return {"ok": false}
	var data: Dictionary = raw
	var schema: int = SaveManager.get_save_schema_version(domain_id)
	if typeof(data.get("version")) != TYPE_INT or int(data["version"]) != schema:
		return {"ok": false}
	for key in SaveManager.get_save_required_keys(domain_id):
		if not data.has(key):
			return {"ok": false}
	return {"ok": true, "bytes": size, "sha256": digest, "data": data}


func _read_var_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw: Variant = file.get_var(false)
	file.close()
	return raw if raw is Dictionary else {}


func _permanent_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT):
		ids.append(str(raw_id))
	ids.sort()
	return ids


func _masked_uid(uid: String) -> String:
	if uid.length() <= 8:
		return "••••"
	return uid.left(4) + "…" + uid.right(4)


func _sha256_text(value: String) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for raw_key in data:
		if not (raw_key is String) or raw_key not in expected:
			return false
	return true


func _safe_uid(uid: String) -> bool:
	if uid.is_empty() or uid.length() > 128:
		return false
	for character in uid:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			return false
	return true


func _sha256_shape(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_RESTORE_REVIEW_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_REVIEW_ACK") == REQUIRED_ACK
	)


func _yes(code: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"code": code,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
	}
	for key in extra:
		result[key] = extra[key]
	return result


func _no(code: String) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"execution_allowed": false,
	}
