extends RefCounted

## Android DEBUG device QA only.
## Consumes one account-bound reviewed transport JSON record delivered by the
## debug-only native bridge, validates the full eight-domain contract again, and
## writes durable candidate files only under its isolated QA namespace.
## It never invokes the restore engine and never writes registered save paths.

const ContractScript = preload(
	"res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
)

const ROOT: String = "user://jade_account_bound_android_transport_qa/"
const MANIFEST_VERSION: int = 1
const TRANSPORT_CONTRACT_VERSION: int = 1
const MAX_TRANSPORT_BYTES: int = 614400
const MAX_DOMAIN_BYTES: int = 1048576
const MAX_SAFE_INTEGER: int = 9007199254740991
const MAX_DEPTH: int = 16
const MAX_CONTAINER_ENTRIES: int = 4096
const QA_FEATURE: String = "jade_android_account_bound_transport_qa"
const QA_MAIN_SCENE: String = "res://tests/android/android_account_bound_transport_device_qa.tscn"
const TRANSPORT_KEYS = [
	"ok",
	"code",
	"transport_contract_version",
	"qaOnly",
	"ownerUid",
	"revision",
	"digest",
	"domain_count",
	"domain_ids",
	"draft",
	"server_revision_verified",
	"server_freshness_verified",
	"explicit_restore_decision_required",
	"restore_allowed",
	"cloud_mutation_enabled",
]


func qa_root() -> String:
	return ROOT


func stage_transport_json_for_device_qa(
	transport_json: String, authenticated_uid: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("ANDROID_TRANSPORT_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if transport_json.is_empty() or transport_json.to_utf8_buffer().size() > MAX_TRANSPORT_BYTES:
		return _no("TRANSPORT_RECORD_SIZE_INVALID")

	var parsed: Variant = JSON.parse_string(transport_json)
	if parsed == null:
		return _no("TRANSPORT_JSON_INVALID")
	var normalized: Dictionary = _normalize_json_value(parsed, 0)
	if not bool(normalized.get("ok", false)):
		return _no(str(normalized.get("code", "TRANSPORT_JSON_INVALID")))
	var record: Variant = normalized.get("value")
	if not (record is Dictionary):
		return _no("TRANSPORT_RECORD_SHAPE_INVALID")
	var transport: Dictionary = record
	if not _has_exact_keys(transport, TRANSPORT_KEYS):
		return _no("TRANSPORT_RECORD_SHAPE_INVALID")
	if transport.get("ok") != true or transport.get("qaOnly") != true:
		return _no("TRANSPORT_RECORD_NOT_TRUSTED_QA")
	if str(transport.get("code", "")) != "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY":
		return _no("TRANSPORT_RECORD_CODE_INVALID")
	if typeof(transport.get("transport_contract_version")) != TYPE_INT \
		or int(transport["transport_contract_version"]) != TRANSPORT_CONTRACT_VERSION:
		return _no("TRANSPORT_CONTRACT_VERSION_INVALID")
	if str(transport.get("ownerUid", "")) != authenticated_uid:
		return _no("ACCOUNT_MISMATCH")
	if not _positive_int(transport.get("revision")):
		return _no("REMOTE_REVISION_INVALID")
	var digest: String = str(transport.get("digest", ""))
	if not _sha256_shape(digest):
		return _no("REMOTE_DIGEST_INVALID")
	if typeof(transport.get("domain_count")) != TYPE_INT or int(transport["domain_count"]) != 8:
		return _no("TRANSPORT_DOMAIN_COUNT_INVALID")
	if transport.get("server_revision_verified") != true \
		or transport.get("server_freshness_verified") != true:
		return _no("TRANSPORT_SERVER_VERIFICATION_MISSING")
	if transport.get("explicit_restore_decision_required") != true:
		return _no("TRANSPORT_DECISION_FLAG_MISSING")
	if transport.get("restore_allowed") != false \
		or transport.get("cloud_mutation_enabled") != false:
		return _no("TRANSPORT_RECORD_UNSAFE_FLAGS")
	if not (transport.get("draft") is Dictionary):
		return _no("SNAPSHOT_CONTENT_INVALID")

	var contract: RefCounted = ContractScript.new() as RefCounted
	var ids: Array[String] = contract.call("get_domain_ids")
	if not _string_array_exact(transport.get("domain_ids"), ids):
		return _no("TRANSPORT_DOMAIN_SET_INVALID")
	var draft: Dictionary = (transport["draft"] as Dictionary).duplicate(true)
	var inspected: Dictionary = contract.call("inspect_draft", draft, authenticated_uid)
	if not bool(inspected.get("valid", false)):
		return _no("SNAPSHOT_CONTENT_INVALID", {
			"inspection_reason": str(inspected.get("reason", "invalid")),
		})
	if str(contract.call("hash_draft", draft)) != digest:
		return _no("SNAPSHOT_DIGEST_MISMATCH")

	if DirAccess.make_dir_recursive_absolute(ROOT) != OK:
		return _no("DEVICE_TRANSFER_ROOT_UNAVAILABLE")
	var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var pending: String = ROOT + "pending_" + nonce
	var ready: String = ROOT + "ready_" + nonce
	if DirAccess.make_dir_recursive_absolute(pending + "/domains") != OK:
		return _no("DEVICE_TRANSFER_PENDING_UNAVAILABLE")

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
		"remote_revision": int(transport["revision"]),
		"remote_digest": digest,
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
		return _no("DEVICE_TRANSFER_MANIFEST_WRITE_FAILED")
	var pending_check: Dictionary = _inspect_staged_path(pending, authenticated_uid)
	if not bool(pending_check.get("ok", false)):
		_remove_tree(pending)
		return _no("DEVICE_TRANSFER_PENDING_VERIFY_FAILED")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(pending), ProjectSettings.globalize_path(ready)
	) != OK:
		_remove_tree(pending)
		return _no("DEVICE_TRANSFER_READY_RENAME_FAILED")
	var ready_check: Dictionary = _inspect_staged_path(ready, authenticated_uid)
	if not bool(ready_check.get("ok", false)):
		return _no("DEVICE_TRANSFER_READY_VERIFY_FAILED")
	return _yes("ANDROID_ACCOUNT_BOUND_CANDIDATES_READY", {
		"ready_path": ready,
		"candidate_paths": ready_check.get("candidate_paths", {}).duplicate(true),
		"remote_revision": int(transport["revision"]),
		"remote_digest": digest,
		"domain_count": ids.size(),
		"explicit_decision_required": true,
	})


func inspect_ready_for_device_qa(ready_path: String, authenticated_uid: String) -> Dictionary:
	if not _qa_enabled():
		return _no("ANDROID_TRANSPORT_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if not ready_path.begins_with(ROOT + "ready_") or ".." in ready_path:
		return _no("DEVICE_TRANSFER_READY_SCOPE_INVALID")
	return _inspect_staged_path(ready_path, authenticated_uid)


func _inspect_staged_path(path: String, authenticated_uid: String) -> Dictionary:
	if not DirAccess.dir_exists_absolute(path):
		return _no("DEVICE_TRANSFER_READY_MISSING")
	var manifest: Dictionary = _read_var_dictionary(path + "/manifest.bin")
	if manifest.is_empty() or manifest.get("version") != MANIFEST_VERSION \
		or manifest.get("qa_only") != true:
		return _no("DEVICE_TRANSFER_MANIFEST_INVALID")
	if str(manifest.get("owner_uid", "")) != authenticated_uid:
		return _no("ACCOUNT_MISMATCH")
	if not _positive_int(manifest.get("remote_revision")):
		return _no("REMOTE_REVISION_INVALID")
	var digest: String = str(manifest.get("remote_digest", ""))
	if not _sha256_shape(digest):
		return _no("REMOTE_DIGEST_INVALID")
	if manifest.get("restore_allowed") != false \
		or manifest.get("cloud_mutation_enabled") != false \
		or manifest.get("explicit_decision_required") != true:
		return _no("DEVICE_TRANSFER_MANIFEST_UNSAFE")
	if not (manifest.get("domain_schema_versions") is Dictionary) \
		or not (manifest.get("domain_ids") is Array) \
		or not (manifest.get("domain_files") is Dictionary):
		return _no("DEVICE_TRANSFER_MANIFEST_INVALID")

	var contract: RefCounted = ContractScript.new() as RefCounted
	var ids: Array[String] = contract.call("get_domain_ids")
	if not _string_array_exact(manifest["domain_ids"], ids):
		return _no("DEVICE_TRANSFER_DOMAIN_SET_INVALID")
	var versions: Dictionary = manifest["domain_schema_versions"]
	var entries: Dictionary = manifest["domain_files"]
	if not _has_exact_keys(versions, ids) or not _has_exact_keys(entries, ids):
		return _no("DEVICE_TRANSFER_DOMAIN_SET_INVALID")

	var domains: Dictionary = {}
	var candidate_paths: Dictionary = {}
	for id in ids:
		var entry: Dictionary = entries[id] if entries[id] is Dictionary else {}
		var expected_name: String = id + ".save"
		if str(entry.get("name", "")) != expected_name:
			return _no("DEVICE_TRANSFER_FILE_METADATA_INVALID")
		var schema: int = SaveManager.get_save_schema_version(id)
		if typeof(versions.get(id)) != TYPE_INT or int(versions[id]) != schema \
			or int(entry.get("schema", -1)) != schema:
			return _no("DEVICE_TRANSFER_FILE_METADATA_INVALID")
		var file_path: String = path + "/domains/" + expected_name
		if not FileAccess.file_exists(file_path):
			return _no("DEVICE_TRANSFER_CANDIDATE_MISSING")
		var size: int = FileAccess.get_size(file_path)
		if size <= 0 or size > MAX_DOMAIN_BYTES or size != int(entry.get("bytes", -1)):
			return _no("DEVICE_TRANSFER_CANDIDATE_SIZE_INVALID")
		var expected_hash: String = str(entry.get("sha256", ""))
		if not _sha256_shape(expected_hash) or FileAccess.get_sha256(file_path) != expected_hash:
			return _no("DEVICE_TRANSFER_CANDIDATE_HASH_INVALID")
		var payload: Dictionary = _read_var_dictionary(file_path)
		if payload.is_empty() or int(payload.get("version", -1)) != schema:
			return _no("DEVICE_TRANSFER_CANDIDATE_CONTENT_INVALID")
		for required_key in SaveManager.get_save_required_keys(id):
			if not payload.has(required_key):
				return _no("DEVICE_TRANSFER_CANDIDATE_CONTENT_INVALID")
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
		return _no("DEVICE_TRANSFER_CANDIDATE_CONTENT_INVALID")
	if str(contract.call("hash_draft", draft)) != digest:
		return _no("SNAPSHOT_DIGEST_MISMATCH")
	return _yes("ANDROID_ACCOUNT_BOUND_CANDIDATES_INSPECTED", {
		"ready_path": path,
		"candidate_paths": candidate_paths,
		"remote_revision": int(manifest["remote_revision"]),
		"remote_digest": digest,
		"domain_count": ids.size(),
		"explicit_decision_required": true,
	})


func _write_candidate_file(path: String, payload: Dictionary, domain_id: String) -> Dictionary:
	if not _write_var_file(path, payload):
		return _no("DEVICE_TRANSFER_CANDIDATE_WRITE_FAILED")
	var size: int = FileAccess.get_size(path)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return _no("DEVICE_TRANSFER_CANDIDATE_SIZE_INVALID")
	var reread: Dictionary = _read_var_dictionary(path)
	if reread != payload:
		return _no("DEVICE_TRANSFER_CANDIDATE_VERIFY_FAILED")
	if int(reread.get("version", -1)) != SaveManager.get_save_schema_version(domain_id):
		return _no("DEVICE_TRANSFER_CANDIDATE_SCHEMA_INVALID")
	for required_key in SaveManager.get_save_required_keys(domain_id):
		if not reread.has(required_key):
			return _no("DEVICE_TRANSFER_CANDIDATE_CONTENT_INVALID")
	return _yes("DEVICE_TRANSFER_CANDIDATE_WRITTEN", {
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


func _normalize_json_value(value: Variant, depth: int) -> Dictionary:
	if depth > MAX_DEPTH:
		return _no("TRANSPORT_JSON_DEPTH_INVALID")
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			if typeof(value) == TYPE_STRING and str(value).length() > 4096:
				return _no("TRANSPORT_JSON_VALUE_INVALID")
			return {"ok": true, "value": value}
		TYPE_INT:
			if int(value) < -MAX_SAFE_INTEGER or int(value) > MAX_SAFE_INTEGER:
				return _no("TRANSPORT_JSON_NUMBER_INVALID")
			return {"ok": true, "value": int(value)}
		TYPE_FLOAT:
			var number: float = float(value)
			if number != number or absf(number) > float(MAX_SAFE_INTEGER) or floor(number) != number:
				return _no("TRANSPORT_JSON_NUMBER_INVALID")
			return {"ok": true, "value": int(number)}
		TYPE_ARRAY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return _no("TRANSPORT_JSON_CONTAINER_INVALID")
			var output_array: Array = []
			for entry in value:
				var normalized_entry: Dictionary = _normalize_json_value(entry, depth + 1)
				if not bool(normalized_entry.get("ok", false)):
					return normalized_entry
				output_array.append(normalized_entry.get("value"))
			return {"ok": true, "value": output_array}
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER_ENTRIES:
				return _no("TRANSPORT_JSON_CONTAINER_INVALID")
			var output_dictionary: Dictionary = {}
			for raw_key in value:
				if not (raw_key is String):
					return _no("TRANSPORT_JSON_KEY_INVALID")
				var key: String = str(raw_key)
				if key.is_empty() or key.length() > 256 \
					or key in ["__proto__", "prototype", "constructor"]:
					return _no("TRANSPORT_JSON_KEY_INVALID")
				var normalized_value: Dictionary = _normalize_json_value(value[raw_key], depth + 1)
				if not bool(normalized_value.get("ok", false)):
					return normalized_value
				output_dictionary[key] = normalized_value.get("value")
			return {"ok": true, "value": output_dictionary}
	return _no("TRANSPORT_JSON_VALUE_INVALID")


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for raw_key in data:
		if not (raw_key is String) or raw_key not in expected:
			return false
	return true


func _string_array_exact(value: Variant, expected: Array[String]) -> bool:
	if not (value is Array) or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not (value[index] is String) or str(value[index]) != expected[index]:
			return false
	return true


func _safe_uid(uid: String) -> bool:
	if uid.is_empty() or uid.length() > 128:
		return false
	for character in uid:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-".contains(character):
			return false
	return true


func _positive_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and int(value) > 0 and int(value) <= MAX_SAFE_INTEGER


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
		OS.get_name() == "Android"
		and OS.is_debug_build()
		and OS.has_feature(QA_FEATURE)
		and str(ProjectSettings.get_setting("application/run/main_scene", "")) == QA_MAIN_SCENE
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
