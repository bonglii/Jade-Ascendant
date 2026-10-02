extends RefCounted

## Disposable-runner-only restore harness that targets the exact permanent paths
## registered by SaveManager. It is intentionally NOT a production restore API.
##
## Safety boundary:
## - requires the Godot editor binary (release/debug exports fail closed),
## - requires three explicit CI environment gates,
## - has no scene/autoload/callsite,
## - has no network/backend code,
## - uses SaveManager's global write barrier for every registered-path mutation,
## - keeps its journal/candidate/vault under a QA-only user:// namespace.

const JOURNAL_VERSION: int = 1
const DOMAIN_COUNT: int = 8
const ROOT: String = "user://jade_registered_restore_qa/"
const CANDIDATE_ROOT: String = ROOT + "candidate/"
const VAULT_ROOT: String = ROOT + "vault"
const TX_ROOT: String = ROOT + "tx/"
const ACTIVE_TX: String = TX_ROOT + "active"
const INTENT_PATH: String = ACTIVE_TX + "/intent.bin"
const COMMIT_MARKER: String = ACTIVE_TX + "/commit_started.marker"
const APPLIED_MARKER: String = ACTIVE_TX + "/applied_pending_confirmation.marker"
const CONFIRMED_MARKER: String = ACTIVE_TX + "/confirmed.marker"
const ROLLED_BACK_MARKER: String = ACTIVE_TX + "/rolled_back.marker"
const MAX_DOMAIN_BYTES: int = 1048576
const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
const BOOT_BARRIER_OWNER: String = "registered_restore_bootstrap_qa"


func qa_root() -> String:
	return ROOT


func registered_source_paths_for_qa() -> Dictionary:
	if not _qa_enabled():
		return {}
	return _registered_paths()


func candidate_paths_for_qa() -> Dictionary:
	if not _qa_enabled():
		return {}
	var paths: Dictionary = {}
	for id in _permanent_ids():
		paths[id] = CANDIDATE_ROOT + id + ".save"
	return paths


func prepare_registered_preimage_for_qa(owner_uid: String) -> Dictionary:
	if not _qa_enabled():
		return _no("REGISTERED_QA_DISABLED")
	if not _safe_uid(owner_uid):
		return _no("INVALID_OWNER")
	if DirAccess.dir_exists_absolute(ACTIVE_TX):
		return _no("RESTORE_TRANSACTION_ALREADY_ACTIVE")
	var paths: Dictionary = _registered_paths()
	var issue: String = _registered_boundary_issue(paths)
	if not issue.is_empty():
		return _no(issue)
	var barrier_owner: String = _barrier_owner("registered_backup")
	var acquired: Dictionary = SaveManager.begin_save_write_barrier(
		barrier_owner, "registered_restore_qa_preimage"
	)
	if not bool(acquired.get("success", false)):
		return _no("SAVE_WRITE_BARRIER_UNAVAILABLE")
	issue = _registered_boundary_issue(paths, barrier_owner)
	var result: Dictionary = _no(issue) if not issue.is_empty() else _copy_preimage_vault(
		paths, owner_uid
	)
	return _finish_barrier(barrier_owner, result)


func begin_registered_restore_for_qa(
	owner_uid: String,
	remote_revision: int,
	remote_digest: String,
	fault_point: String = ""
) -> Dictionary:
	if not _qa_enabled():
		return _no("REGISTERED_QA_DISABLED")
	if not _safe_uid(owner_uid):
		return _no("INVALID_OWNER")
	if remote_revision <= 0:
		return _no("INVALID_REMOTE_REVISION")
	if not _sha256_shape(remote_digest):
		return _no("INVALID_REMOTE_DIGEST")
	if DirAccess.dir_exists_absolute(ACTIVE_TX):
		return _no("RESTORE_TRANSACTION_ALREADY_ACTIVE")
	var paths: Dictionary = _registered_paths()
	var issue: String = _registered_boundary_issue(paths)
	if not issue.is_empty():
		return _no(issue)
	var ready: String = _single_ready_vault()
	if ready.is_empty():
		return _no("PREIMAGE_VAULT_NOT_READY")
	var manifest: Dictionary = _load_valid_vault(ready, owner_uid, paths)
	if manifest.is_empty():
		return _no("PREIMAGE_VAULT_INVALID")
	var candidates: Dictionary = _candidate_paths()
	var source_hashes: Dictionary = {}
	var candidate_hashes: Dictionary = {}
	var candidate_names: Dictionary = {}
	for id in _permanent_ids():
		var source: String = str(paths[id])
		var entry: Dictionary = manifest["domain_files"].get(id, {})
		var primary: Dictionary = entry.get("primary", {})
		var preimage_hash: String = str(primary.get("sha256", ""))
		if not _sha256_shape(preimage_hash):
			return _no("PREIMAGE_MANIFEST_INVALID")
		if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != preimage_hash:
			return _no("LOCAL_STATE_CHANGED_AFTER_BACKUP")
		var candidate: String = str(candidates[id])
		var candidate_check: Dictionary = _validate_dictionary_file(candidate, id, "CANDIDATE")
		if not bool(candidate_check.get("ok", false)):
			return candidate_check
		source_hashes[id] = preimage_hash
		candidate_hashes[id] = FileAccess.get_sha256(candidate)
		candidate_names[id] = id + ".candidate.bin"
	var barrier_owner: String = _barrier_owner("registered_restore")
	var acquired: Dictionary = SaveManager.begin_save_write_barrier(
		barrier_owner, "registered_restore_qa_commit"
	)
	if not bool(acquired.get("success", false)):
		return _no("SAVE_WRITE_BARRIER_UNAVAILABLE")
	issue = _registered_boundary_issue(paths, barrier_owner)
	if not issue.is_empty():
		return _finish_barrier(barrier_owner, _no(issue))
	for id in _permanent_ids():
		if FileAccess.get_sha256(str(paths[id])) != str(source_hashes[id]):
			return _finish_barrier(barrier_owner, _no("LOCAL_STATE_CHANGED_AFTER_BARRIER"))
	var result: Dictionary = _begin_under_barrier(
		paths, candidates, ready, owner_uid, remote_revision, remote_digest,
		source_hashes, candidate_hashes, candidate_names, fault_point
	)
	return _finish_barrier(barrier_owner, result)


func recover_registered_restore_for_qa(owner_uid: String, fault_point: String = "") -> Dictionary:
	if not _qa_enabled():
		return _no("REGISTERED_QA_DISABLED")
	if not DirAccess.dir_exists_absolute(ACTIVE_TX):
		return _no("NO_ACTIVE_RESTORE")
	var intent: Dictionary = _load_and_validate_intent(owner_uid)
	if intent.is_empty():
		if not FileAccess.file_exists(COMMIT_MARKER):
			_remove_tree(ACTIVE_TX)
			return _yes("RESTORE_INCOMPLETE_PREPARE_CLEARED")
		return _no("RESTORE_INTENT_INVALID")
	var barrier: Dictionary = _acquire_registered_barrier(
		"registered_recovery", "registered_restore_qa_recovery"
	)
	if not bool(barrier.get("ok", false)):
		return _no("SAVE_WRITE_BARRIER_UNAVAILABLE")
	var barrier_owner: String = str(barrier["owner_id"])
	var issue: String = _registered_boundary_issue(intent["source_paths"], barrier_owner, true)
	var result: Dictionary = _no(issue) if not issue.is_empty() else _recover_under_barrier(
		intent, fault_point
	)
	return _finish_barrier(barrier_owner, result)


func rollback_registered_restore_for_qa(
	owner_uid: String, fault_point: String = ""
) -> Dictionary:
	if not _qa_enabled():
		return _no("REGISTERED_QA_DISABLED")
	var intent: Dictionary = _load_and_validate_intent(owner_uid)
	if intent.is_empty():
		return _no("RESTORE_INTENT_INVALID")
	if FileAccess.file_exists(CONFIRMED_MARKER):
		return _no("RESTORE_ALREADY_CONFIRMED")
	if not FileAccess.file_exists(APPLIED_MARKER):
		return _no("NO_APPLIED_RESTORE")
	var barrier: Dictionary = _acquire_registered_barrier(
		"registered_rollback", "registered_restore_qa_manual_rollback"
	)
	if not bool(barrier.get("ok", false)):
		return _no("SAVE_WRITE_BARRIER_UNAVAILABLE")
	var barrier_owner: String = str(barrier["owner_id"])
	var issue: String = _registered_boundary_issue(intent["source_paths"], barrier_owner, true)
	if not issue.is_empty():
		return _finish_barrier(barrier_owner, _no(issue))
	var rolled: Dictionary = _rollback_from_vault(intent, fault_point)
	if not bool(rolled.get("ok", false)):
		return _finish_barrier(barrier_owner, rolled)
	if not _all_live_match(intent, "source_hashes"):
		return _finish_barrier(barrier_owner, _no("ROLLBACK_VERIFY_FAILED"))
	if not _write_marker(ROLLED_BACK_MARKER, "manual_rollback"):
		return _finish_barrier(barrier_owner, _no("ROLLBACK_MARKER_FAILED"))
	return _finish_barrier(barrier_owner, _yes("RESTORE_MANUAL_ROLLBACK_COMPLETE", {
		"confirmation_required": false, "vault_retained": true
	}))


func confirm_registered_restore_for_qa(owner_uid: String) -> Dictionary:
	if not _qa_enabled():
		return _no("REGISTERED_QA_DISABLED")
	var intent: Dictionary = _load_and_validate_intent(owner_uid)
	if intent.is_empty():
		return _no("RESTORE_INTENT_INVALID")
	if FileAccess.file_exists(ROLLED_BACK_MARKER):
		return _no("RESTORE_ALREADY_ROLLED_BACK")
	if not FileAccess.file_exists(APPLIED_MARKER):
		return _no("NO_APPLIED_RESTORE")
	var barrier: Dictionary = _acquire_registered_barrier(
		"registered_confirm", "registered_restore_qa_confirm"
	)
	if not bool(barrier.get("ok", false)):
		return _no("SAVE_WRITE_BARRIER_UNAVAILABLE")
	var barrier_owner: String = str(barrier["owner_id"])
	var issue: String = _registered_boundary_issue(intent["source_paths"], barrier_owner, true)
	if not issue.is_empty():
		return _finish_barrier(barrier_owner, _no(issue))
	if not _all_live_match(intent, "candidate_hashes"):
		return _finish_barrier(barrier_owner, _no("APPLIED_STATE_DIVERGED"))
	if not _write_marker(CONFIRMED_MARKER, "confirmed"):
		return _finish_barrier(barrier_owner, _no("RESTORE_CONFIRM_MARKER_FAILED"))
	return _finish_barrier(barrier_owner, _yes("RESTORE_CONFIRMED", {
		"confirmation_required": false,
		"vault_retained": true,
		"vault_cleanup_allowed": true
	}))


func inspect_registered_restore_for_qa(owner_uid: String) -> Dictionary:
	if not _qa_enabled():
		return _no("REGISTERED_QA_DISABLED")
	var intent: Dictionary = _load_and_validate_intent(owner_uid)
	if intent.is_empty():
		return _no("RESTORE_INTENT_INVALID")
	var phase: String = "PREPARED"
	if FileAccess.file_exists(CONFIRMED_MARKER):
		phase = "CONFIRMED"
	elif FileAccess.file_exists(ROLLED_BACK_MARKER):
		phase = "ROLLED_BACK"
	elif FileAccess.file_exists(APPLIED_MARKER):
		phase = "APPLIED_PENDING_CONFIRMATION"
	elif FileAccess.file_exists(COMMIT_MARKER):
		phase = "COMMITTING"
	return _yes("REGISTERED_RESTORE_TX_INSPECTED", {
		"phase": phase,
		"owner_uid": owner_uid,
		"registered_paths": true,
		"restore_allowed": false
	})


func _begin_under_barrier(
	paths: Dictionary,
	candidates: Dictionary,
	ready: String,
	owner_uid: String,
	remote_revision: int,
	remote_digest: String,
	source_hashes: Dictionary,
	candidate_hashes: Dictionary,
	candidate_names: Dictionary,
	fault_point: String
) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(ACTIVE_TX + "/candidate") != OK:
		return _no("RESTORE_TX_DIRECTORY_UNAVAILABLE")
	for id in _permanent_ids():
		var copied: Dictionary = _copy_exact_bytes(
			str(candidates[id]),
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
		"domain_ids": _permanent_ids(),
		"ready_vault_path": ready,
		"source_paths": paths.duplicate(true),
		"source_hashes": source_hashes,
		"candidate_hashes": candidate_hashes,
		"candidate_names": candidate_names,
		"registered_path_qa": true
	}
	if not _write_var_atomic(INTENT_PATH, intent):
		_remove_tree(ACTIVE_TX)
		return _no("RESTORE_INTENT_WRITE_FAILED")
	if fault_point == "after_intent":
		return _fault(fault_point)
	if not _write_marker(COMMIT_MARKER, "commit_started"):
		return _no("RESTORE_COMMIT_MARKER_FAILED")
	if fault_point == "after_commit_marker":
		return _fault(fault_point)
	for id in _permanent_ids():
		var replaced: Dictionary = _replace_live_with_candidate(
			id,
			str(paths[id]),
			ACTIVE_TX + "/candidate/" + str(candidate_names[id]),
			str(candidate_hashes[id]),
			fault_point
		)
		if not bool(replaced.get("ok", false)):
			return replaced
	if fault_point == "after_all_domains":
		return _fault(fault_point)
	if not _all_live_match(intent, "candidate_hashes"):
		return _no("RESTORE_POST_COMMIT_VERIFY_FAILED")
	if not _write_marker(APPLIED_MARKER, "applied_pending_confirmation"):
		return _no("RESTORE_APPLIED_MARKER_FAILED")
	if fault_point == "after_applied_marker":
		return _fault(fault_point)
	return _yes("RESTORE_APPLIED_PENDING_CONFIRMATION", {
		"remote_revision": remote_revision,
		"domain_count": DOMAIN_COUNT,
		"confirmation_required": true,
		"vault_retained": true
	})


func _recover_under_barrier(intent: Dictionary, fault_point: String) -> Dictionary:
	if FileAccess.file_exists(CONFIRMED_MARKER):
		if not _all_live_match(intent, "candidate_hashes"):
			return _no("CONFIRMED_STATE_DIVERGED")
		return _yes("RESTORE_ALREADY_CONFIRMED", {"confirmation_required": false, "vault_retained": true})
	if FileAccess.file_exists(ROLLED_BACK_MARKER):
		if not _all_live_match(intent, "source_hashes"):
			return _no("ROLLED_BACK_STATE_DIVERGED")
		return _yes("RESTORE_ALREADY_ROLLED_BACK", {"confirmation_required": false, "vault_retained": true})
	if FileAccess.file_exists(APPLIED_MARKER):
		if _all_live_match(intent, "candidate_hashes"):
			_cleanup_restore_sidecars(intent)
			return _yes("RESTORE_APPLIED_PENDING_CONFIRMATION", {"confirmation_required": true, "vault_retained": true})
		if _all_live_match(intent, "source_hashes"):
			_cleanup_restore_sidecars(intent)
			if not _write_marker(ROLLED_BACK_MARKER, "recovered_completed_rollback"):
				return _no("ROLLBACK_MARKER_FAILED")
			return _yes("RESTORE_RECOVERED_ROLLED_BACK", {"confirmation_required": false, "vault_retained": true})
		var resumed: Dictionary = _rollback_from_vault(intent, fault_point)
		if not bool(resumed.get("ok", false)):
			return resumed
		if not _all_live_match(intent, "source_hashes"):
			return _no("ROLLBACK_VERIFY_FAILED")
		if not _write_marker(ROLLED_BACK_MARKER, "recovered_interrupted_rollback"):
			return _no("ROLLBACK_MARKER_FAILED")
		return _yes("RESTORE_RECOVERED_ROLLED_BACK", {"confirmation_required": false, "vault_retained": true})
	if not FileAccess.file_exists(COMMIT_MARKER):
		if not _all_live_match(intent, "source_hashes"):
			return _no("PRECOMMIT_LOCAL_STATE_DIVERGED")
		if not _write_marker(ROLLED_BACK_MARKER, "prepare_aborted"):
			return _no("ROLLBACK_MARKER_FAILED")
		return _yes("RESTORE_PREPARE_ABORTED", {"confirmation_required": false, "vault_retained": true})
	if _all_live_match(intent, "candidate_hashes"):
		_cleanup_restore_sidecars(intent)
		if not _write_marker(APPLIED_MARKER, "recovered_applied"):
			return _no("RESTORE_APPLIED_MARKER_FAILED")
		return _yes("RESTORE_RECOVERED_APPLIED", {"confirmation_required": true, "vault_retained": true})
	var rolled: Dictionary = _rollback_from_vault(intent, fault_point)
	if not bool(rolled.get("ok", false)):
		return rolled
	if not _all_live_match(intent, "source_hashes"):
		return _no("ROLLBACK_VERIFY_FAILED")
	if not _write_marker(ROLLED_BACK_MARKER, "rolled_back_after_restart"):
		return _no("ROLLBACK_MARKER_FAILED")
	return _yes("RESTORE_RECOVERED_ROLLED_BACK", {"confirmation_required": false, "vault_retained": true})


func _registered_boundary_issue(
	paths: Dictionary, allowed_barrier_owner: String = "", recovering: bool = false
) -> String:
	if not _exact_registered_paths(paths):
		return "REGISTERED_PATH_MISMATCH"
	if SaveManager.has_pending_transaction():
		return "SAVE_TRANSACTION_UNSAFE"
	if SaveManager.is_save_write_barrier_active():
		if allowed_barrier_owner.is_empty() or SaveManager.get_save_write_barrier_owner() != allowed_barrier_owner:
			return "SAVE_WRITE_BARRIER_BUSY"
	elif SaveManager.is_progress_read_only():
		return "SAVE_TRANSACTION_UNSAFE"
	if SaveManager.has_save_file("checkpoint"):
		return "ACTIVE_CHECKPOINT_UNSAFE"
	for id in _permanent_ids():
		if SaveManager.is_save_write_blocked(id):
			return "SAVE_TRANSACTION_UNSAFE"
		var path: String = str(paths[id])
		for suffix in [".tmp", ".rollback"]:
			if FileAccess.file_exists(path + suffix):
				return "UNSETTLED_DOMAIN_ARTIFACT"
		if not recovering:
			for suffix in [".restore.tmp", ".restore.rollback", ".restore.recovery.tmp", ".restore.recovery.discard"]:
				if FileAccess.file_exists(path + suffix):
					return "UNSETTLED_RESTORE_ARTIFACT"
	return ""


func _copy_preimage_vault(paths: Dictionary, owner_uid: String) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(VAULT_ROOT) != OK:
		return _no("VAULT_DIRECTORY_UNAVAILABLE")
	var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
	var pending: String = VAULT_ROOT + "/pending_" + nonce
	var ready: String = VAULT_ROOT + "/ready_" + nonce
	if DirAccess.make_dir_absolute(pending) != OK:
		return _no("PENDING_DIRECTORY_UNAVAILABLE")
	var files: Dictionary = {}
	var total_bytes: int = 0
	for id in _permanent_ids():
		var source: String = str(paths[id])
		var checked: Dictionary = _validate_dictionary_file(source, id, "PRIMARY")
		if not bool(checked.get("ok", false)):
			return checked
		var entry: Dictionary = {"schema": SaveManager.get_save_schema_version(id)}
		for suffix in ["", ".backup"]:
			var from: String = source + suffix
			if suffix != "" and not FileAccess.file_exists(from):
				continue
			var size: int = FileAccess.get_size(from)
			if size <= 0 or size > MAX_DOMAIN_BYTES:
				return _no("DOMAIN_SIZE_UNSAFE")
			var hash: String = FileAccess.get_sha256(from)
			var name: String = id + (".primary" if suffix.is_empty() else ".backup") + ".bin"
			var copied: Dictionary = _copy_exact_bytes(from, pending + "/" + name, hash)
			if not bool(copied.get("ok", false)):
				return copied
			entry["primary" if suffix.is_empty() else "backup"] = {
				"name": name, "bytes": size, "sha256": hash
			}
			total_bytes += size
		files[id] = entry
	var manifest: Dictionary = {
		"version": 1,
		"owner_uid": owner_uid,
		"domain_ids": _permanent_ids(),
		"domain_files": files,
		"total_bytes": total_bytes,
		"registered_path_qa": true
	}
	if not _write_var_atomic(pending + "/manifest.bin", manifest):
		return _no("MANIFEST_WRITE_FAILED")
	if _load_valid_vault(pending, owner_uid, paths).is_empty():
		return _no("PREIMAGE_VAULT_INVALID")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(pending), ProjectSettings.globalize_path(ready)) != OK:
		return _no("READY_RENAME_FAILED")
	if _load_valid_vault(ready, owner_uid, paths).is_empty():
		return _no("PREIMAGE_VAULT_INVALID")
	return _yes("REGISTERED_PREIMAGE_READY", {
		"ready_path": ready, "domain_count": DOMAIN_COUNT,
		"vault_retained": true, "restore_allowed": false
	})


func _load_valid_vault(ready: String, owner_uid: String, paths: Dictionary) -> Dictionary:
	if not ready.begins_with(VAULT_ROOT + "/") or ".." in ready:
		return {}
	var manifest: Dictionary = _read_var_dictionary(ready + "/manifest.bin")
	if manifest.get("version") != 1 or manifest.get("registered_path_qa") != true:
		return {}
	if str(manifest.get("owner_uid", "")) != owner_uid:
		return {}
	if manifest.get("domain_ids") != _permanent_ids() or not manifest.get("domain_files") is Dictionary:
		return {}
	if not _exact_registered_paths(paths):
		return {}
	for id in _permanent_ids():
		var entry: Dictionary = manifest["domain_files"].get(id, {})
		if int(entry.get("schema", -1)) != SaveManager.get_save_schema_version(id):
			return {}
		var primary: Dictionary = entry.get("primary", {})
		var name: String = str(primary.get("name", ""))
		var hash: String = str(primary.get("sha256", ""))
		if name != id + ".primary.bin" or not _sha256_shape(hash):
			return {}
		var saved: String = ready + "/" + name
		if not FileAccess.file_exists(saved) or FileAccess.get_sha256(saved) != hash:
			return {}
		if entry.has("backup"):
			var backup: Dictionary = entry["backup"]
			var backup_name: String = str(backup.get("name", ""))
			var backup_hash: String = str(backup.get("sha256", ""))
			if backup_name != id + ".backup.bin" or not _sha256_shape(backup_hash):
				return {}
			var backup_saved: String = ready + "/" + backup_name
			if not FileAccess.file_exists(backup_saved) or FileAccess.get_sha256(backup_saved) != backup_hash:
				return {}
	return manifest


func _load_and_validate_intent(owner_uid: String) -> Dictionary:
	var intent: Dictionary = _read_var_dictionary(INTENT_PATH)
	if intent.get("version") != JOURNAL_VERSION or intent.get("registered_path_qa") != true:
		return {}
	if str(intent.get("owner_uid", "")) != owner_uid or not _safe_uid(owner_uid):
		return {}
	if int(intent.get("remote_revision", 0)) <= 0 or not _sha256_shape(str(intent.get("remote_digest", ""))):
		return {}
	if intent.get("domain_ids") != _permanent_ids():
		return {}
	if not intent.get("source_paths") is Dictionary or not _exact_registered_paths(intent["source_paths"]):
		return {}
	if not intent.get("source_hashes") is Dictionary or not intent.get("candidate_hashes") is Dictionary:
		return {}
	if not intent.get("candidate_names") is Dictionary:
		return {}
	var ready: String = str(intent.get("ready_vault_path", ""))
	if _load_valid_vault(ready, owner_uid, intent["source_paths"]).is_empty():
		return {}
	for id in _permanent_ids():
		if not _sha256_shape(str(intent["source_hashes"].get(id, ""))):
			return {}
		if not _sha256_shape(str(intent["candidate_hashes"].get(id, ""))):
			return {}
		var name: String = str(intent["candidate_names"].get(id, ""))
		if name != id + ".candidate.bin":
			return {}
		var candidate: String = ACTIVE_TX + "/candidate/" + name
		if not FileAccess.file_exists(candidate) or FileAccess.get_sha256(candidate) != str(intent["candidate_hashes"][id]):
			return {}
	return intent


func _replace_live_with_candidate(
	domain_id: String, target: String, candidate: String,
	expected_hash: String, fault_point: String
) -> Dictionary:
	var tmp: String = target + ".restore.tmp"
	var rollback: String = target + ".restore.rollback"
	if not _remove_if_present(tmp) or not _remove_if_present(rollback):
		return _no("RESTORE_STALE_ARTIFACT_UNREMOVABLE")
	var copied: Dictionary = _copy_exact_bytes(candidate, tmp, expected_hash)
	if not bool(copied.get("ok", false)):
		return copied
	if fault_point == "after_tmp:" + domain_id:
		return _fault(fault_point)
	if not FileAccess.file_exists(target):
		return _no("RESTORE_PRIMARY_MISSING")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(rollback)) != OK:
		return _no("RESTORE_PRIMARY_STAGE_FAILED")
	if fault_point == "after_primary_to_rollback:" + domain_id:
		return _fault(fault_point)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(target)) != OK:
		return _no("RESTORE_CANDIDATE_PROMOTION_FAILED")
	if fault_point == "after_candidate_to_primary:" + domain_id:
		return _fault(fault_point)
	if FileAccess.get_sha256(target) != expected_hash:
		return _no("RESTORE_CANDIDATE_VERIFY_FAILED")
	if not _remove_if_present(rollback):
		return _no("RESTORE_ROLLBACK_SIDECAR_CLEANUP_FAILED")
	if fault_point == "after_domain:" + domain_id:
		return _fault(fault_point)
	return _yes("DOMAIN_RESTORED")


func _rollback_from_vault(intent: Dictionary, fault_point: String) -> Dictionary:
	var ready: String = str(intent["ready_vault_path"])
	var manifest: Dictionary = _read_var_dictionary(ready + "/manifest.bin")
	if manifest.is_empty():
		return _no("PREIMAGE_MANIFEST_INVALID")
	for id in _permanent_ids():
		var entry: Dictionary = manifest["domain_files"].get(id, {})
		var primary: Dictionary = entry.get("primary", {})
		var expected_hash: String = str(intent["source_hashes"].get(id, ""))
		var name: String = str(primary.get("name", ""))
		if name != id + ".primary.bin" or not _sha256_shape(expected_hash):
			return _no("PREIMAGE_MANIFEST_INVALID")
		var restored: Dictionary = _replace_with_preimage(
			id, str(intent["source_paths"][id]), ready + "/" + name,
			expected_hash, fault_point
		)
		if not bool(restored.get("ok", false)):
			return restored
	_cleanup_restore_sidecars(intent)
	return _yes("ROLLBACK_DISK_COMPLETE")


func _replace_with_preimage(
	domain_id: String, target: String, preimage: String,
	expected_hash: String, fault_point: String
) -> Dictionary:
	var tmp: String = target + ".restore.recovery.tmp"
	var discard: String = target + ".restore.recovery.discard"
	if not _remove_if_present(tmp) or not _remove_if_present(discard):
		return _no("ROLLBACK_STALE_ARTIFACT_UNREMOVABLE")
	var copied: Dictionary = _copy_exact_bytes(preimage, tmp, expected_hash)
	if not bool(copied.get("ok", false)):
		return copied
	if fault_point == "rollback_after_tmp:" + domain_id:
		return _fault(fault_point)
	if FileAccess.file_exists(target):
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(discard)) != OK:
			return _no("ROLLBACK_TARGET_STAGE_FAILED")
	if fault_point == "rollback_after_target_to_discard:" + domain_id:
		return _fault(fault_point)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(target)) != OK:
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


func _all_live_match(intent: Dictionary, hash_key: String) -> bool:
	for id in _permanent_ids():
		var path: String = str(intent["source_paths"].get(id, ""))
		var expected: String = str(intent[hash_key].get(id, ""))
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected:
			return false
	return true


func _cleanup_restore_sidecars(intent: Dictionary) -> void:
	for id in _permanent_ids():
		var path: String = str(intent["source_paths"].get(id, ""))
		for suffix in [".restore.tmp", ".restore.rollback", ".restore.recovery.tmp", ".restore.recovery.discard"]:
			_remove_if_present(path + suffix)


func _candidate_paths() -> Dictionary:
	var paths: Dictionary = {}
	for id in _permanent_ids():
		paths[id] = CANDIDATE_ROOT + id + ".save"
	return paths


func _registered_paths() -> Dictionary:
	var paths: Dictionary = {}
	for id in _permanent_ids():
		paths[id] = SaveManager.get_save_path(id)
	return paths


func _exact_registered_paths(paths: Dictionary) -> bool:
	var ids: Array[String] = _permanent_ids()
	if ids.size() != DOMAIN_COUNT or paths.size() != DOMAIN_COUNT:
		return false
	for id in ids:
		if not paths.has(id) or str(paths[id]) != SaveManager.get_save_path(id):
			return false
	return true


func _permanent_ids() -> Array[String]:
	var ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT)
	ids.sort()
	return ids


func _single_ready_vault() -> String:
	if not DirAccess.dir_exists_absolute(VAULT_ROOT):
		return ""
	var ready_paths: Array[String] = []
	for name in DirAccess.get_directories_at(VAULT_ROOT):
		if name.begins_with("ready_"):
			ready_paths.append(VAULT_ROOT + "/" + name)
	ready_paths.sort()
	return ready_paths[-1] if ready_paths.size() == 1 else ""


func _validate_dictionary_file(path: String, domain_id: String, prefix: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _no(prefix + "_MISSING")
	var size: int = FileAccess.get_size(path)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return _no(prefix + "_SIZE_INVALID")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _no(prefix + "_UNREADABLE")
	var raw: Variant = file.get_var(false)
	file.close()
	if not raw is Dictionary:
		return _no(prefix + "_NOT_DICTIONARY")
	var data: Dictionary = raw
	if not data.get("version") is int or int(data["version"]) != SaveManager.get_save_schema_version(domain_id):
		return _no(prefix + "_SCHEMA_INVALID")
	for key in SaveManager.get_save_required_keys(domain_id):
		if not data.has(key):
			return _no(prefix + "_INCOMPLETE")
	return _yes(prefix + "_VALID")


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
	if not stored or FileAccess.get_size(target) != size or FileAccess.get_sha256(target) != expected_hash:
		return _no("TARGET_WRITE_FAILED")
	return _yes("BYTE_COPY_VERIFIED")


func _write_var_atomic(path: String, data: Dictionary) -> bool:
	var tmp: String = path + ".tmp"
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
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func _write_marker(path: String, value: String) -> bool:
	if FileAccess.file_exists(path):
		return true
	var tmp: String = path + ".tmp"
	if not _remove_if_present(tmp):
		return false
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(value)
	file.flush()
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)) == OK


func _read_var_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value: Variant = file.get_var(false)
	file.close()
	return value if value is Dictionary else {}


func _acquire_registered_barrier(prefix: String, reason: String) -> Dictionary:
	# Restart QA installs a CI-only autoload immediately after SaveManager. It
	# owns this exact barrier before permanent managers can perform startup writes.
	# Reuse that owner until the durable restore journal is resolved.
	if SaveManager.is_save_write_barrier_active():
		if SaveManager.get_save_write_barrier_owner() == BOOT_BARRIER_OWNER:
			return {
				"ok": true,
				"owner_id": BOOT_BARRIER_OWNER,
				"borrowed_boot_barrier": true
			}
		return {"ok": false, "code": "SAVE_WRITE_BARRIER_BUSY"}
	var owner_id: String = _barrier_owner(prefix)
	var acquired: Dictionary = SaveManager.begin_save_write_barrier(owner_id, reason)
	if not bool(acquired.get("success", false)):
		return {
			"ok": false,
			"code": str(acquired.get("code", "SAVE_WRITE_BARRIER_UNAVAILABLE"))
		}
	return {
		"ok": true,
		"owner_id": owner_id,
		"borrowed_boot_barrier": false
	}


func _finish_barrier(barrier_owner: String, result: Dictionary) -> Dictionary:
	var released: Dictionary = SaveManager.end_save_write_barrier(barrier_owner)
	if not bool(released.get("success", false)):
		return _no("SAVE_WRITE_BARRIER_RELEASE_FAILED")
	result["write_barrier_used"] = true
	return result


func _barrier_owner(prefix: String) -> String:
	return prefix + "_" + Crypto.new().generate_random_bytes(12).hex_encode()


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
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/" + file_name)) != OK:
			return false
	for dir_name in DirAccess.get_directories_at(path):
		if not _remove_tree(path + "/" + dir_name):
			return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_ACK") == REQUIRED_ACK
	)


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
