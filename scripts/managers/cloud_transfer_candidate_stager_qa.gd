extends RefCounted

## Controlled-transfer staging QA. It accepts only an already reviewed synthetic
## eight-domain record, validates owner/revision/digest again, then serializes
## candidate save files under its own QA namespace. It never reads/writes live
## SaveManager paths, never performs network I/O and never authorizes restore.

const ContractScript = preload(
	"res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
)

const ROOT: String = "user://jade_controlled_transfer_qa/"
const MANIFEST_VERSION: int = 1
const MAX_DOMAIN_BYTES: int = 1048576
const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
const REVIEW_KEYS = [
	"ok", "code", "qaOnly", "ownerUid", "revision", "digest", "draft",
	"restore_allowed", "cloud_mutation_enabled",
]


func qa_root() -> String:
	return ROOT


func stage_reviewed_snapshot_for_qa(
	reviewed: Dictionary, authenticated_uid: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("CONTROLLED_TRANSFER_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if not _has_exact_keys(reviewed, REVIEW_KEYS):
		return _no("REVIEW_RECORD_SHAPE_INVALID")
	if reviewed.get("ok") != true or reviewed.get("qaOnly") != true:
		return _no("REVIEW_RECORD_NOT_TRUSTED_QA")
	if str(reviewed.get("code", "")) != "QA_LATEST_SNAPSHOT_REVIEWED":
		return _no("REVIEW_RECORD_CODE_INVALID")
	if reviewed.get("restore_allowed") != false or reviewed.get("cloud_mutation_enabled") != false:
		return _no("REVIEW_RECORD_UNSAFE_FLAGS")
	if str(reviewed.get("ownerUid", "")) != authenticated_uid:
		return _no("ACCOUNT_MISMATCH")
	if typeof(reviewed.get("revision")) != TYPE_INT or int(reviewed["revision"]) <= 0:
		return _no("REMOTE_REVISION_INVALID")
	var remote_digest: String = str(reviewed.get("digest", ""))
	if not _sha256_shape(remote_digest):
		return _no("REMOTE_DIGEST_INVALID")
	if not (reviewed.get("draft") is Dictionary):
		return _no("SNAPSHOT_CONTENT_INVALID")

	var draft: Dictionary = (reviewed["draft"] as Dictionary).duplicate(true)
	var contract: RefCounted = ContractScript.new() as RefCounted
	var inspected: Dictionary = contract.call("inspect_draft", draft, authenticated_uid)
	if not bool(inspected.get("valid", false)):
		return _no("SNAPSHOT_CONTENT_INVALID", {
			"inspection_reason": str(inspected.get("reason", "invalid"))
		})
	var calculated_digest: String = str(contract.call("hash_draft", draft))
	if calculated_digest != remote_digest:
		return _no("SNAPSHOT_DIGEST_MISMATCH")

	if DirAccess.make_dir_recursive_absolute(ROOT) != OK:
		return _no("TRANSFER_ROOT_UNAVAILABLE")
	var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var pending: String = ROOT + "pending_" + nonce
	var ready: String = ROOT + "ready_" + nonce
	if DirAccess.make_dir_recursive_absolute(pending + "/domains") != OK:
		return _no("TRANSFER_PENDING_UNAVAILABLE")

	var ids: Array[String] = contract.call("get_domain_ids")
	var domain_files: Dictionary = {}
	for id in ids:
		var payload: Dictionary = (draft["domains"][id] as Dictionary).duplicate(true)
		var file_name: String = id + ".save"
		var path: String = pending + "/domains/" + file_name
		var written: Dictionary = _write_candidate_file(path, payload, id)
		if not bool(written.get("ok", false)):
			_remove_tree(pending)
			return written
		domain_files[id] = {
			"name": file_name,
			"schema": SaveManager.get_save_schema_version(id),
			"bytes": int(written["bytes"]),
			"sha256": str(written["sha256"]),
		}

	var manifest: Dictionary = {
		"version": MANIFEST_VERSION,
		"qa_only": true,
		"owner_uid": authenticated_uid,
		"remote_revision": int(reviewed["revision"]),
		"remote_digest": remote_digest,
		"draft_snapshot_version": int(draft["draft_snapshot_version"]),
		"captured_at_unix": int(draft["captured_at_unix"]),
		"domain_schema_versions": (draft["domain_schema_versions"] as Dictionary).duplicate(true),
		"domain_ids": ids.duplicate(),
		"domain_files": domain_files,
		"restore_allowed": false,
		"explicit_decision_required": true,
		"cloud_mutation_enabled": false,
	}
	if not _write_var_file(pending + "/manifest.bin", manifest):
		_remove_tree(pending)
		return _no("TRANSFER_MANIFEST_WRITE_FAILED")
	var pending_inspection: Dictionary = _inspect_staged_path(pending, authenticated_uid)
	if not bool(pending_inspection.get("ok", false)):
		_remove_tree(pending)
		return _no("TRANSFER_PENDING_VERIFY_FAILED")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(pending), ProjectSettings.globalize_path(ready)
	) != OK:
		_remove_tree(pending)
		return _no("TRANSFER_READY_RENAME_FAILED")
	var ready_inspection: Dictionary = inspect_ready_for_qa(ready, authenticated_uid)
	if not bool(ready_inspection.get("ok", false)):
		return _no("TRANSFER_READY_VERIFY_FAILED")
	return _yes("TRANSFER_CANDIDATES_READY", {
		"ready_path": ready,
		"candidate_paths": ready_inspection.get("candidate_paths", {}).duplicate(true),
		"remote_revision": int(reviewed["revision"]),
		"remote_digest": remote_digest,
		"domain_count": ids.size(),
		"explicit_decision_required": true,
	})


func inspect_ready_for_qa(ready_path: String, authenticated_uid: String) -> Dictionary:
	if not _qa_enabled():
		return _no("CONTROLLED_TRANSFER_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if not ready_path.begins_with(ROOT + "ready_") or ".." in ready_path:
		return _no("TRANSFER_READY_SCOPE_INVALID")
	return _inspect_staged_path(ready_path, authenticated_uid)


func _inspect_staged_path(path: String, authenticated_uid: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(path):
		return _no("TRANSFER_READY_MISSING")
	var manifest: Dictionary = _read_var_dictionary(path + "/manifest.bin")
	if manifest.is_empty():
		return _no("TRANSFER_MANIFEST_INVALID")
	if manifest.get("version") != MANIFEST_VERSION or manifest.get("qa_only") != true:
		return _no("TRANSFER_MANIFEST_INVALID")
	if str(manifest.get("owner_uid", "")) != authenticated_uid:
		return _no("ACCOUNT_MISMATCH")
	if typeof(manifest.get("remote_revision")) != TYPE_INT or int(manifest["remote_revision"]) <= 0:
		return _no("REMOTE_REVISION_INVALID")
	var digest: String = str(manifest.get("remote_digest", ""))
	if not _sha256_shape(digest):
		return _no("REMOTE_DIGEST_INVALID")
	if manifest.get("restore_allowed") != false or manifest.get("cloud_mutation_enabled") != false:
		return _no("TRANSFER_MANIFEST_UNSAFE_FLAGS")
	if manifest.get("explicit_decision_required") != true:
		return _no("TRANSFER_DECISION_FLAG_MISSING")
	if not (manifest.get("domain_schema_versions") is Dictionary):
		return _no("TRANSFER_MANIFEST_INVALID")
	if not (manifest.get("domain_ids") is Array) or not (manifest.get("domain_files") is Dictionary):
		return _no("TRANSFER_MANIFEST_INVALID")

	var contract: RefCounted = ContractScript.new() as RefCounted
	var ids: Array[String] = contract.call("get_domain_ids")
	if manifest["domain_ids"] != ids:
		return _no("TRANSFER_DOMAIN_SET_INVALID")
	var versions: Dictionary = manifest["domain_schema_versions"]
	if not _has_exact_keys(versions, ids):
		return _no("TRANSFER_DOMAIN_SET_INVALID")
	var file_entries: Dictionary = manifest["domain_files"]
	if not _has_exact_keys(file_entries, ids):
		return _no("TRANSFER_DOMAIN_SET_INVALID")

	var domains: Dictionary = {}
	var candidate_paths: Dictionary = {}
	for id in ids:
		var entry: Dictionary = file_entries[id] if file_entries[id] is Dictionary else {}
		var expected_name: String = id + ".save"
		if str(entry.get("name", "")) != expected_name:
			return _no("TRANSFER_FILE_METADATA_INVALID")
		if int(entry.get("schema", -1)) != SaveManager.get_save_schema_version(id):
			return _no("TRANSFER_FILE_METADATA_INVALID")
		if typeof(versions.get(id)) != TYPE_INT or int(versions[id]) != SaveManager.get_save_schema_version(id):
			return _no("TRANSFER_FILE_METADATA_INVALID")
		var file_path: String = path + "/domains/" + expected_name
		if not FileAccess.file_exists(file_path):
			return _no("TRANSFER_CANDIDATE_MISSING")
		var size: int = FileAccess.get_size(file_path)
		if size <= 0 or size > MAX_DOMAIN_BYTES or size != int(entry.get("bytes", -1)):
			return _no("TRANSFER_CANDIDATE_SIZE_INVALID")
		var expected_hash: String = str(entry.get("sha256", ""))
		if not _sha256_shape(expected_hash) or FileAccess.get_sha256(file_path) != expected_hash:
			return _no("TRANSFER_CANDIDATE_HASH_INVALID")
		var payload: Dictionary = _read_var_dictionary(file_path)
		if payload.is_empty() or int(payload.get("version", -1)) != SaveManager.get_save_schema_version(id):
			return _no("TRANSFER_CANDIDATE_CONTENT_INVALID")
		for required_key in SaveManager.get_save_required_keys(id):
			if not payload.has(required_key):
				return _no("TRANSFER_CANDIDATE_CONTENT_INVALID")
		domains[id] = payload
		candidate_paths[id] = file_path

	var draft: Dictionary = {
		"draft_snapshot_version": int(manifest.get("draft_snapshot_version", -1)),
		"owner_uid": authenticated_uid,
		"captured_at_unix": int(manifest.get("captured_at_unix", 0)),
		"domain_schema_versions": versions.duplicate(true),
		"domains": domains,
	}
	var checked: Dictionary = contract.call("inspect_draft", draft, authenticated_uid)
	if not bool(checked.get("valid", false)):
		return _no("TRANSFER_CANDIDATE_CONTENT_INVALID")
	if str(contract.call("hash_draft", draft)) != digest:
		return _no("SNAPSHOT_DIGEST_MISMATCH")
	return _yes("TRANSFER_CANDIDATES_INSPECTED", {
		"ready_path": path,
		"candidate_paths": candidate_paths,
		"remote_revision": int(manifest["remote_revision"]),
		"remote_digest": digest,
		"domain_count": ids.size(),
		"explicit_decision_required": true,
	})


func _write_candidate_file(path: String, payload: Dictionary, domain_id: String) -> Dictionary:
	if not _write_var_file(path, payload):
		return _no("TRANSFER_CANDIDATE_WRITE_FAILED")
	var size: int = FileAccess.get_size(path)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return _no("TRANSFER_CANDIDATE_SIZE_INVALID")
	var reread: Dictionary = _read_var_dictionary(path)
	if reread != payload:
		return _no("TRANSFER_CANDIDATE_VERIFY_FAILED")
	if int(reread.get("version", -1)) != SaveManager.get_save_schema_version(domain_id):
		return _no("TRANSFER_CANDIDATE_SCHEMA_INVALID")
	for required_key in SaveManager.get_save_required_keys(domain_id):
		if not reread.has(required_key):
			return _no("TRANSFER_CANDIDATE_CONTENT_INVALID")
	return _yes("TRANSFER_CANDIDATE_WRITTEN", {
		"bytes": size,
		"sha256": FileAccess.get_sha256(path),
	})


func _write_var_file(path: String, data: Dictionary) -> bool:
	var parent: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data)
	file.flush()
	file.close()
	return _read_var_dictionary(path) == data


func _read_var_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw: Variant = file.get_var(false)
	file.close()
	return raw if raw is Dictionary else {}


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for key in expected:
		if not data.has(key):
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


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_TEST_ONLY") == "1"
		and OS.get_environment("JADE_CONTROLLED_TRANSFER_ACK") == REQUIRED_ACK
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


func _no(code: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"code": code,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
	}
	for key in extra:
		result[key] = extra[key]
	return result
