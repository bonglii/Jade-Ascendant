extends RefCounted

## Synthetic-only transactional restore disk model.
##
## This file deliberately cannot touch production save paths. It exists to prove
## the durable restore protocol against disposable user://jade_gate9_qa/ files
## before any separately reviewed SaveManager restore primitive is considered.
## No production scene/autoload/callsite may reference this script.

const BackupVaultScript = preload("res://scripts/managers/cloud_local_backup_vault.gd")

const JOURNAL_VERSION: int = 1
const DOMAIN_COUNT: int = 8
const QA_ROOT: String = "user://jade_gate9_qa/"
const QA_SOURCE_ROOT: String = QA_ROOT + "source/"
const QA_CANDIDATE_ROOT: String = QA_ROOT + "candidate/"
const QA_TX_ROOT: String = QA_ROOT + "restore_tx/"
const ACTIVE_TX: String = QA_TX_ROOT + "active"
const INTENT_PATH: String = ACTIVE_TX + "/intent.bin"
const COMMIT_MARKER: String = ACTIVE_TX + "/commit_started.marker"
const APPLIED_MARKER: String = ACTIVE_TX + "/applied_pending_confirmation.marker"
const CONFIRMED_MARKER: String = ACTIVE_TX + "/confirmed.marker"
const ROLLED_BACK_MARKER: String = ACTIVE_TX + "/rolled_back.marker"
const MAX_DOMAIN_BYTES: int = 1048576


func begin_sandbox_restore_for_qa(
	source_paths: Dictionary,
	candidate_paths: Dictionary,
	ready_vault_path: String,
	owner_uid: String,
	remote_revision: int,
	remote_digest: String,
	fault_point: String = ""
) -> Dictionary:
	if not _qa_enabled():
		return _no("QA_DISABLED")
	if DirAccess.dir_exists_absolute(ACTIVE_TX):
		return _no("RESTORE_TRANSACTION_ALREADY_ACTIVE")
	var ids: Array[String] = _permanent_ids()
	if ids.size() != DOMAIN_COUNT:
		return _no("PERMANENT_DOMAIN_COUNT_CHANGED")
	if not _exact_path_set(source_paths, ids, QA_SOURCE_ROOT):
		return _no("QA_SOURCE_SCOPE")
	if not _exact_path_set(candidate_paths, ids, QA_CANDIDATE_ROOT):
		return _no("QA_CANDIDATE_SCOPE")
	if (
		not ready_vault_path.begins_with(QA_ROOT + "vault/ready_")
		or ".." in ready_vault_path
	):
		return _no("QA_VAULT_SCOPE")
	if not _safe_uid(owner_uid):
		return _no("INVALID_OWNER")
	if remote_revision <= 0:
		return _no("INVALID_REMOTE_REVISION")
	if not _sha256_shape(remote_digest):
		return _no("INVALID_REMOTE_DIGEST")

	var vault := BackupVaultScript.new() as RefCounted
	var inspected: Dictionary = vault.call("inspect_sandbox_backup_for_qa", ready_vault_path)
	if not bool(inspected.get("ok", false)):
		return _no("PREIMAGE_VAULT_INVALID")
	var manifest: Dictionary = _read_var_dictionary(ready_vault_path + "/manifest.bin")
	if manifest.is_empty() or str(manifest.get("owner_uid", "")) != owner_uid:
		return _no("PREIMAGE_OWNER_MISMATCH")
	if manifest.get("domain_ids") != ids or not manifest.get("domain_files") is Dictionary:
		return _no("PREIMAGE_MANIFEST_INVALID")

	var source_hashes: Dictionary = {}
	var candidate_hashes: Dictionary = {}
	var candidate_names: Dictionary = {}
	for id in ids:
		var source: String = str(source_paths[id])
		var candidate: String = str(candidate_paths[id])
		var entry: Dictionary = manifest["domain_files"].get(id, {})
		var primary: Dictionary = entry.get("primary", {})
		var preimage_hash: String = str(primary.get("sha256", ""))
		if not _sha256_shape(preimage_hash):
			return _no("PREIMAGE_MANIFEST_INVALID")
		if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != preimage_hash:
			return _no("LOCAL_STATE_CHANGED_AFTER_BACKUP")
		var candidate_check: Dictionary = _validate_candidate(candidate, id)
		if not bool(candidate_check.get("ok", false)):
			return candidate_check
		source_hashes[id] = preimage_hash
		candidate_hashes[id] = FileAccess.get_sha256(candidate)
		candidate_names[id] = id + ".candidate.bin"

	if DirAccess.make_dir_recursive_absolute(ACTIVE_TX + "/candidate") != OK:
		return _no("RESTORE_TX_DIRECTORY_UNAVAILABLE")
	for id in ids:
		var copied: Dictionary = _copy_exact_bytes(
			str(candidate_paths[id]),
			ACTIVE_TX + "/candidate/" + str(candidate_names[id]),
			str(candidate_hashes[id])
		)
		if not bool(copied.get("ok", false)):
			_remove_tree(ACTIVE_TX)
			return copied

	var intent: Dictionary = {
		"version": JOURNAL_VERSION,
		"owner_uid": owner_uid,
		"remote_revision": remote_revision,
		"remote_digest": remote_digest,
		"domain_ids": ids,
		"ready_vault_path": ready_vault_path,
		"source_paths": source_paths.duplicate(true),
		"source_hashes": source_hashes,
		"candidate_hashes": candidate_hashes,
		"candidate_names": candidate_names
	}
	if not _write_var_atomic(INTENT_PATH, intent):
		_remove_tree(ACTIVE_TX)
		return _no("RESTORE_INTENT_WRITE_FAILED")
	if fault_point == "after_intent":
		return _fault("after_intent")
	if not _write_marker(COMMIT_MARKER, "commit_started"):
		return _no("RESTORE_COMMIT_MARKER_FAILED")
	if fault_point == "after_commit_marker":
		return _fault("after_commit_marker")

	for id in ids:
		var replace: Dictionary = _replace_live_with_candidate(
			id,
			str(source_paths[id]),
			ACTIVE_TX + "/candidate/" + str(candidate_names[id]),
			str(candidate_hashes[id]),
			fault_point
		)
		if not bool(replace.get("ok", false)):
			return replace
	if fault_point == "after_all_domains":
		return _fault("after_all_domains")
	if not _all_live_match(intent, "candidate_hashes"):
		return _no("RESTORE_POST_COMMIT_VERIFY_FAILED")
	if not _write_marker(APPLIED_MARKER, "applied_pending_confirmation"):
		return _no("RESTORE_APPLIED_MARKER_FAILED")
	if fault_point == "after_applied_marker":
		return _fault("after_applied_marker")
	return _yes("RESTORE_APPLIED_PENDING_CONFIRMATION", {
		"remote_revision": remote_revision,
		"domain_count": DOMAIN_COUNT,
		"confirmation_required": true,
		"vault_retained": true
	})


func recover_sandbox_restore_for_qa(fault_point: String = "") -> Dictionary:
	if not _qa_enabled():
		return _no("QA_DISABLED")
	if not DirAccess.dir_exists_absolute(ACTIVE_TX):
		return _no("NO_ACTIVE_RESTORE")
	var intent: Dictionary = _load_and_validate_intent()
	if intent.is_empty():
		# No committed marker means no primary was authorized to change. A partial
		# prepare directory can therefore be discarded safely. Once commit starts,
		# invalid durable intent is a hard fail-closed condition.
		if not FileAccess.file_exists(COMMIT_MARKER):
			_remove_tree(ACTIVE_TX)
			return _yes("RESTORE_INCOMPLETE_PREPARE_CLEARED")
		return _no("RESTORE_INTENT_INVALID")
	if FileAccess.file_exists(CONFIRMED_MARKER):
		if not _all_live_match(intent, "candidate_hashes"):
			return _no("CONFIRMED_STATE_DIVERGED")
		return _yes("RESTORE_ALREADY_CONFIRMED", {
			"confirmation_required": false, "vault_retained": true
		})
	if FileAccess.file_exists(ROLLED_BACK_MARKER):
		if not _all_live_match(intent, "source_hashes"):
			return _no("ROLLED_BACK_STATE_DIVERGED")
		return _yes("RESTORE_ALREADY_ROLLED_BACK", {
			"confirmation_required": false, "vault_retained": true
		})
	if FileAccess.file_exists(APPLIED_MARKER):
		if _all_live_match(intent, "candidate_hashes"):
			_cleanup_restore_sidecars(intent)
			return _yes("RESTORE_APPLIED_PENDING_CONFIRMATION", {
				"confirmation_required": true, "vault_retained": true
			})
		# A manual rollback may have finished all eight preimage writes but died
		# before its terminal marker. Exact preimage state is self-authenticating
		# against the immutable intent/vault and can be finalized safely.
		if _all_live_match(intent, "source_hashes"):
			_cleanup_restore_sidecars(intent)
			if not _write_marker(ROLLED_BACK_MARKER, "recovered_completed_rollback"):
				return _no("ROLLBACK_MARKER_FAILED")
			return _yes("RESTORE_RECOVERED_ROLLED_BACK", {
				"confirmation_required": false, "vault_retained": true
			})
		# Otherwise resume the whole-account rollback from the durable preimage.
		var resumed_rollback: Dictionary = _rollback_from_vault(intent, fault_point)
		if not bool(resumed_rollback.get("ok", false)):
			return resumed_rollback
		if not _all_live_match(intent, "source_hashes"):
			return _no("ROLLBACK_VERIFY_FAILED")
		if not _write_marker(ROLLED_BACK_MARKER, "recovered_interrupted_rollback"):
			return _no("ROLLBACK_MARKER_FAILED")
		return _yes("RESTORE_RECOVERED_ROLLED_BACK", {
			"confirmation_required": false, "vault_retained": true
		})
	if not FileAccess.file_exists(COMMIT_MARKER):
		if not _all_live_match(intent, "source_hashes"):
			return _no("PRECOMMIT_LOCAL_STATE_DIVERGED")
		if not _write_marker(ROLLED_BACK_MARKER, "prepare_aborted"):
			return _no("ROLLBACK_MARKER_FAILED")
		return _yes("RESTORE_PREPARE_ABORTED", {
			"confirmation_required": false, "vault_retained": true
		})

	# A crash can happen after the final primary rename but before the applied
	# marker. Exact all-candidate state is safe to promote. Any partial/missing
	# state rolls back from the durable Gate 9A vault; no progress index is trusted.
	if _all_live_match(intent, "candidate_hashes"):
		_cleanup_restore_sidecars(intent)
		if not _write_marker(APPLIED_MARKER, "recovered_applied"):
			return _no("RESTORE_APPLIED_MARKER_FAILED")
		return _yes("RESTORE_RECOVERED_APPLIED", {
			"confirmation_required": true, "vault_retained": true
		})
	var rolled_back: Dictionary = _rollback_from_vault(intent, fault_point)
	if not bool(rolled_back.get("ok", false)):
		return rolled_back
	if not _all_live_match(intent, "source_hashes"):
		return _no("ROLLBACK_VERIFY_FAILED")
	if not _write_marker(ROLLED_BACK_MARKER, "rolled_back_after_restart"):
		return _no("ROLLBACK_MARKER_FAILED")
	return _yes("RESTORE_RECOVERED_ROLLED_BACK", {
		"confirmation_required": false, "vault_retained": true
	})


func rollback_sandbox_restore_for_qa(owner_uid: String, fault_point: String = "") -> Dictionary:
	if not _qa_enabled():
		return _no("QA_DISABLED")
	var intent: Dictionary = _load_and_validate_intent()
	if intent.is_empty():
		return _no("RESTORE_INTENT_INVALID")
	if owner_uid != str(intent.get("owner_uid", "")):
		return _no("ACCOUNT_CHANGED")
	if FileAccess.file_exists(CONFIRMED_MARKER):
		return _no("RESTORE_ALREADY_CONFIRMED")
	if not FileAccess.file_exists(APPLIED_MARKER):
		return _no("NO_APPLIED_RESTORE")
	var rolled_back: Dictionary = _rollback_from_vault(intent, fault_point)
	if not bool(rolled_back.get("ok", false)):
		return rolled_back
	if not _all_live_match(intent, "source_hashes"):
		return _no("ROLLBACK_VERIFY_FAILED")
	if not _write_marker(ROLLED_BACK_MARKER, "manual_rollback"):
		return _no("ROLLBACK_MARKER_FAILED")
	return _yes("RESTORE_MANUAL_ROLLBACK_COMPLETE", {
		"confirmation_required": false, "vault_retained": true
	})


func confirm_sandbox_restore_for_qa(owner_uid: String) -> Dictionary:
	if not _qa_enabled():
		return _no("QA_DISABLED")
	var intent: Dictionary = _load_and_validate_intent()
	if intent.is_empty():
		return _no("RESTORE_INTENT_INVALID")
	if owner_uid != str(intent.get("owner_uid", "")):
		return _no("ACCOUNT_CHANGED")
	if FileAccess.file_exists(ROLLED_BACK_MARKER):
		return _no("RESTORE_ALREADY_ROLLED_BACK")
	if not FileAccess.file_exists(APPLIED_MARKER):
		return _no("NO_APPLIED_RESTORE")
	if not _all_live_match(intent, "candidate_hashes"):
		return _no("APPLIED_STATE_DIVERGED")
	if not _write_marker(CONFIRMED_MARKER, "confirmed"):
		return _no("RESTORE_CONFIRM_MARKER_FAILED")
	# Deliberately do not delete the Gate 9A vault here. Retention/cleanup needs
	# a separately reviewed policy; this gate only proves when cleanup is safe.
	return _yes("RESTORE_CONFIRMED", {
		"confirmation_required": false,
		"vault_retained": true,
		"vault_cleanup_allowed": true
	})


func inspect_sandbox_restore_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("QA_DISABLED")
	if not DirAccess.dir_exists_absolute(ACTIVE_TX):
		return _no("NO_ACTIVE_RESTORE")
	var intent: Dictionary = _load_and_validate_intent()
	if intent.is_empty():
		return _no("RESTORE_INTENT_INVALID")
	var phase := "PREPARED"
	if FileAccess.file_exists(CONFIRMED_MARKER):
		phase = "CONFIRMED"
	elif FileAccess.file_exists(ROLLED_BACK_MARKER):
		phase = "ROLLED_BACK"
	elif FileAccess.file_exists(APPLIED_MARKER):
		phase = "APPLIED_PENDING_CONFIRMATION"
	elif FileAccess.file_exists(COMMIT_MARKER):
		phase = "COMMITTING"
	return _yes("RESTORE_TX_INSPECTED", {
		"phase": phase,
		"owner_uid": str(intent.get("owner_uid", "")),
		"remote_revision": int(intent.get("remote_revision", 0)),
		"vault_retained": true,
		"restore_allowed": false
	})


func _replace_live_with_candidate(
	domain_id: String,
	target: String,
	candidate: String,
	expected_hash: String,
	fault_point: String
) -> Dictionary:
	var tmp := target + ".restore.tmp"
	var rollback := target + ".restore.rollback"
	if not _remove_if_present(tmp) or not _remove_if_present(rollback):
		return _no("RESTORE_STALE_ARTIFACT_UNREMOVABLE")
	var copied: Dictionary = _copy_exact_bytes(candidate, tmp, expected_hash)
	if not bool(copied.get("ok", false)):
		return copied
	if fault_point == "after_tmp:" + domain_id:
		return _fault(fault_point)
	if not FileAccess.file_exists(target):
		return _no("RESTORE_PRIMARY_MISSING")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(target),
		ProjectSettings.globalize_path(rollback)
	) != OK:
		return _no("RESTORE_PRIMARY_STAGE_FAILED")
	if fault_point == "after_primary_to_rollback:" + domain_id:
		return _fault(fault_point)
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(target)
	) != OK:
		return _no("RESTORE_CANDIDATE_PROMOTION_FAILED")
	if fault_point == "after_candidate_to_primary:" + domain_id:
		return _fault(fault_point)
	if not FileAccess.file_exists(target) or FileAccess.get_sha256(target) != expected_hash:
		return _no("RESTORE_CANDIDATE_VERIFY_FAILED")
	if not _remove_if_present(rollback):
		return _no("RESTORE_ROLLBACK_SIDECAR_CLEANUP_FAILED")
	if fault_point == "after_domain:" + domain_id:
		return _fault(fault_point)
	return _yes("DOMAIN_RESTORED")


func _rollback_from_vault(intent: Dictionary, fault_point: String) -> Dictionary:
	var ready_path: String = str(intent["ready_vault_path"])
	var manifest: Dictionary = _read_var_dictionary(ready_path + "/manifest.bin")
	if manifest.is_empty() or not manifest.get("domain_files") is Dictionary:
		return _no("PREIMAGE_MANIFEST_INVALID")
	for id in intent["domain_ids"]:
		var domain_id: String = str(id)
		var entry: Dictionary = manifest["domain_files"].get(domain_id, {})
		var primary: Dictionary = entry.get("primary", {})
		var name: String = str(primary.get("name", ""))
		var expected_hash: String = str(intent["source_hashes"].get(domain_id, ""))
		if name != domain_id + ".primary.bin" or not _sha256_shape(expected_hash):
			return _no("PREIMAGE_MANIFEST_INVALID")
		var restore: Dictionary = _replace_with_preimage(
			domain_id,
			str(intent["source_paths"][domain_id]),
			ready_path + "/" + name,
			expected_hash,
			fault_point
		)
		if not bool(restore.get("ok", false)):
			return restore
	_cleanup_restore_sidecars(intent)
	return _yes("ROLLBACK_DISK_COMPLETE")


func _replace_with_preimage(
	domain_id: String,
	target: String,
	preimage: String,
	expected_hash: String,
	fault_point: String
) -> Dictionary:
	var tmp := target + ".restore.recovery.tmp"
	var discard := target + ".restore.recovery.discard"
	if not _remove_if_present(tmp) or not _remove_if_present(discard):
		return _no("ROLLBACK_STALE_ARTIFACT_UNREMOVABLE")
	var copied: Dictionary = _copy_exact_bytes(preimage, tmp, expected_hash)
	if not bool(copied.get("ok", false)):
		return copied
	if fault_point == "rollback_after_tmp:" + domain_id:
		return _fault(fault_point)
	if FileAccess.file_exists(target):
		if DirAccess.rename_absolute(
			ProjectSettings.globalize_path(target),
			ProjectSettings.globalize_path(discard)
		) != OK:
			return _no("ROLLBACK_TARGET_STAGE_FAILED")
	if fault_point == "rollback_after_target_to_discard:" + domain_id:
		return _fault(fault_point)
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(target)
	) != OK:
		return _no("ROLLBACK_PREIMAGE_PROMOTION_FAILED")
	if fault_point == "rollback_after_preimage_to_primary:" + domain_id:
		return _fault(fault_point)
	if FileAccess.get_sha256(target) != expected_hash:
		return _no("ROLLBACK_PREIMAGE_VERIFY_FAILED")
	if not _remove_if_present(discard):
		return _no("ROLLBACK_DISCARD_CLEANUP_FAILED")
	_remove_if_present(target + ".restore.tmp")
	_remove_if_present(target + ".restore.rollback")
	if fault_point == "rollback_after_cleanup:" + domain_id:
		return _fault(fault_point)
	return _yes("DOMAIN_ROLLED_BACK")


func _load_and_validate_intent() -> Dictionary:
	var intent: Dictionary = _read_var_dictionary(INTENT_PATH)
	if intent.is_empty() or intent.get("version") != JOURNAL_VERSION:
		return {}
	if not _safe_uid(str(intent.get("owner_uid", ""))):
		return {}
	if int(intent.get("remote_revision", 0)) <= 0:
		return {}
	if not _sha256_shape(str(intent.get("remote_digest", ""))):
		return {}
	var ids: Array[String] = _permanent_ids()
	if intent.get("domain_ids") != ids:
		return {}
	if not intent.get("source_paths") is Dictionary:
		return {}
	if not intent.get("source_hashes") is Dictionary:
		return {}
	if not intent.get("candidate_hashes") is Dictionary:
		return {}
	if not intent.get("candidate_names") is Dictionary:
		return {}
	if not _exact_path_set(intent["source_paths"], ids, QA_SOURCE_ROOT):
		return {}
	var ready_path: String = str(intent.get("ready_vault_path", ""))
	if not ready_path.begins_with(QA_ROOT + "vault/ready_") or ".." in ready_path:
		return {}
	var vault := BackupVaultScript.new() as RefCounted
	if not bool(vault.call("inspect_sandbox_backup_for_qa", ready_path).get("ok", false)):
		return {}
	for id in ids:
		if not _sha256_shape(str(intent["source_hashes"].get(id, ""))):
			return {}
		if not _sha256_shape(str(intent["candidate_hashes"].get(id, ""))):
			return {}
		var name: String = str(intent["candidate_names"].get(id, ""))
		if name != id + ".candidate.bin":
			return {}
		var candidate: String = ACTIVE_TX + "/candidate/" + name
		if not FileAccess.file_exists(candidate):
			return {}
		if FileAccess.get_sha256(candidate) != str(intent["candidate_hashes"][id]):
			return {}
	return intent


func _all_live_match(intent: Dictionary, hash_key: String) -> bool:
	if not intent.get(hash_key) is Dictionary:
		return false
	for id in intent["domain_ids"]:
		var domain_id: String = str(id)
		var path: String = str(intent["source_paths"].get(domain_id, ""))
		var expected: String = str(intent[hash_key].get(domain_id, ""))
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected:
			return false
	return true


func _cleanup_restore_sidecars(intent: Dictionary) -> void:
	for id in intent["domain_ids"]:
		var path: String = str(intent["source_paths"].get(str(id), ""))
		for suffix in [
			".restore.tmp", ".restore.rollback",
			".restore.recovery.tmp", ".restore.recovery.discard"
		]:
			_remove_if_present(path + suffix)


func _validate_candidate(path: String, domain_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _no("CANDIDATE_MISSING")
	var size: int = FileAccess.get_size(path)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return _no("CANDIDATE_SIZE_INVALID")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _no("CANDIDATE_UNREADABLE")
	var value: Variant = file.get_var(false)
	file.close()
	if not value is Dictionary:
		return _no("CANDIDATE_NOT_DICTIONARY")
	var data: Dictionary = value
	if not data.get("version") is int:
		return _no("CANDIDATE_SCHEMA_INVALID")
	if int(data["version"]) != SaveManager.get_save_schema_version(domain_id):
		return _no("CANDIDATE_SCHEMA_INVALID")
	for key in SaveManager.get_save_required_keys(domain_id):
		if not data.has(key):
			return _no("CANDIDATE_INCOMPLETE")
	return _yes("CANDIDATE_VALIDATED")


func _copy_exact_bytes(source: String, target: String, expected_hash: String) -> Dictionary:
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != expected_hash:
		return _no("SOURCE_HASH_MISMATCH")
	var size: int = FileAccess.get_size(source)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return _no("SOURCE_SIZE_INVALID")
	var reader: FileAccess = FileAccess.open(source, FileAccess.READ)
	if reader == null:
		return _no("SOURCE_READ_FAILED")
	var bytes: PackedByteArray = reader.get_buffer(size)
	reader.close()
	if bytes.size() != size:
		return _no("SOURCE_READ_FAILED")
	var writer: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if writer == null:
		return _no("TARGET_WRITE_FAILED")
	var stored: bool = writer.store_buffer(bytes)
	writer.flush()
	writer.close()
	if not stored or FileAccess.get_size(target) != size:
		return _no("TARGET_WRITE_FAILED")
	if FileAccess.get_sha256(target) != expected_hash:
		return _no("TARGET_HASH_MISMATCH")
	return _yes("BYTE_COPY_VERIFIED")


func _write_var_atomic(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	if not _remove_if_present(tmp):
		return false
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data)
	file.flush()
	file.close()
	var verify: Dictionary = _read_var_dictionary(tmp)
	if verify != data:
		_remove_if_present(tmp)
		return false
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(path)
	) == OK


func _write_marker(path: String, value: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	var tmp := path + ".tmp"
	if not _remove_if_present(tmp):
		return false
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp),
		ProjectSettings.globalize_path(path)
	) == OK


func _read_var_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = file.get_var(false)
	file.close()
	return value if value is Dictionary else {}


func _exact_path_set(paths: Dictionary, ids: Array[String], root_path: String) -> bool:
	if paths.size() != ids.size():
		return false
	for id in ids:
		if not paths.has(id) or not paths[id] is String:
			return false
		var path: String = str(paths[id])
		if not path.begins_with(root_path) or ".." in path:
			return false
	return true


func _permanent_ids() -> Array[String]:
	var ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT)
	ids.sort()
	return ids


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


func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _remove_tree(path: String) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return true
	for file_name in DirAccess.get_files_at(path):
		if DirAccess.remove_absolute(
			ProjectSettings.globalize_path(path + "/" + file_name)
		) != OK:
			return false
	for dir_name in DirAccess.get_directories_at(path):
		if not _remove_tree(path + "/" + dir_name):
			return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _qa_enabled() -> bool:
	return OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"


func _fault(point: String) -> Dictionary:
	return {"ok": false, "code": "QA_FAULT_INJECTED", "fault_point": point,
		"upload_allowed": false, "restore_allowed": false}


func _yes(code: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": true, "code": code,
		"upload_allowed": false, "restore_allowed": false}
	for key in extra:
		result[key] = extra[key]
	return result


func _no(code: String) -> Dictionary:
	return {"ok": false, "code": code,
		"upload_allowed": false, "restore_allowed": false}
