extends RefCounted

## Subphase E2 — explicit restore execution coordinator, QA only.
##
## This is NOT a production restore API. It binds an explicit decision to the
## already-reviewed E1 metadata, revalidates the current local fingerprint,
## hands candidate bytes only into the locked registered-path QA namespace,
## captures a durable preimage, revalidates again, then delegates all live-save
## mutation to cloud_registered_path_restore_qa.gd.
##
## No network I/O. No automatic restore. No production UI/autoload/callsite.

const ReviewScript = preload("res://scripts/managers/cloud_restore_review_qa.gd")
const RestoreScript = preload("res://scripts/managers/cloud_registered_path_restore_qa.gd")

const SESSION_VERSION: int = 1
const DOMAIN_COUNT: int = 8
const MAX_DOMAIN_BYTES: int = 1048576
const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"

const ROOT: String = "user://jade_restore_execution_qa/"
const CONTROLLED_TRANSFER_ROOT: String = "user://jade_controlled_transfer_qa/"
const ACTIVE_SESSION: String = ROOT + "active"
const SESSION_INTENT: String = ACTIVE_SESSION + "/intent.bin"
const SESSION_RESOLUTION: String = ACTIVE_SESSION + "/resolution.bin"

const DECISION_KEEP_LOCAL: String = "KEEP_LOCAL"
const DECISION_RESTORE_CLOUD: String = "RESTORE_CLOUD"
const RESOLUTION_CONFIRM: String = "CONFIRM"
const RESOLUTION_ROLLBACK: String = "ROLLBACK"

const SESSION_KEYS = [
	"version", "owner_uid", "review_id", "local_state_fingerprint",
	"ready_path", "remote_revision", "remote_digest", "domain_count",
	"decision",
]


func qa_root() -> String:
	return ROOT


func execute_review_decision_for_qa(
	ready_record: Dictionary,
	presented_review: Dictionary,
	authenticated_uid: String,
	decision: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_EXECUTION_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if decision not in [DECISION_KEEP_LOCAL, DECISION_RESTORE_CLOUD]:
		return _no("INVALID_RESTORE_DECISION")
	if DirAccess.dir_exists_absolute(ACTIVE_SESSION):
		return _no("RESTORE_EXECUTION_SESSION_ALREADY_ACTIVE")

	var review := ReviewScript.new() as RefCounted
	var current: Dictionary = review.call(
		"build_restore_review_for_qa", ready_record, authenticated_uid
	)
	var review_issue: String = _review_binding_issue(presented_review, current)
	if not review_issue.is_empty():
		return _no(review_issue)

	if decision == DECISION_KEEP_LOCAL:
		return _yes("RESTORE_DECISION_KEEP_LOCAL", {
			"decision": DECISION_KEEP_LOCAL,
			"review_id": str(current["review_id"]),
			"remote_revision": int(current["remote_revision"]),
			"remote_digest": str(current["remote_digest"]),
			"mutation_performed": false,
			"confirmation_required": false,
			"qa_execution_performed": false,
		})

	if current.get("preimage_source_files_ready") != true:
		return _no("PREIMAGE_SOURCE_FILES_NOT_READY")
	if int(current.get("local_issue_count", -1)) != 0:
		return _no("LOCAL_STATE_NOT_SAFE_FOR_PREIMAGE")
	if int(current.get("changed_count", 0)) <= 0:
		return _no("NO_CLOUD_DIFFERENCE_TO_RESTORE")

	var restore := RestoreScript.new() as RefCounted
	var handoff: Dictionary = _install_restore_candidates(
		restore, ready_record, authenticated_uid
	)
	if not bool(handoff.get("ok", false)):
		return handoff

	var preimage: Dictionary = restore.call(
		"prepare_registered_preimage_for_qa", authenticated_uid
	)
	if (
		not bool(preimage.get("ok", false))
		or str(preimage.get("code", "")) != "REGISTERED_PREIMAGE_READY"
	):
		return _no("PREIMAGE_BACKUP_FAILED", {
			"restore_code": str(preimage.get("code", "UNKNOWN")),
		})

	# Backup capture must not change the reviewed local state. Rebuild the E1
	# review immediately before durable execution intent + mutation.
	var after_preimage: Dictionary = review.call(
		"build_restore_review_for_qa", ready_record, authenticated_uid
	)
	var post_backup_issue: String = _review_binding_issue(current, after_preimage)
	if not post_backup_issue.is_empty():
		return _no("LOCAL_STATE_CHANGED_AFTER_PREIMAGE", {
			"binding_code": post_backup_issue,
		})
	if not _restore_candidates_match_ready(restore, ready_record):
		return _no("RESTORE_CANDIDATE_HANDOFF_DIVERGED")

	var session: Dictionary = {
		"version": SESSION_VERSION,
		"owner_uid": authenticated_uid,
		"review_id": str(current["review_id"]),
		"local_state_fingerprint": str(current["local_state_fingerprint"]),
		"ready_path": str(ready_record.get("ready_path", "")),
		"remote_revision": int(current["remote_revision"]),
		"remote_digest": str(current["remote_digest"]),
		"domain_count": DOMAIN_COUNT,
		"decision": DECISION_RESTORE_CLOUD,
	}
	if not _write_var_atomic(SESSION_INTENT, session):
		return _no("RESTORE_EXECUTION_INTENT_WRITE_FAILED")

	var applied: Dictionary = restore.call(
		"begin_registered_restore_for_qa",
		authenticated_uid,
		int(current["remote_revision"]),
		str(current["remote_digest"]),
		""
	)
	if (
		not bool(applied.get("ok", false))
		or str(applied.get("code", "")) != "RESTORE_APPLIED_PENDING_CONFIRMATION"
	):
		return _no("RESTORE_APPLY_FAILED", {
			"restore_code": str(applied.get("code", "UNKNOWN")),
			"execution_intent_retained": true,
		})

	var inspected: Dictionary = restore.call(
		"inspect_registered_restore_for_qa", authenticated_uid
	)
	if (
		not bool(inspected.get("ok", false))
		or str(inspected.get("phase", "")) != "APPLIED_PENDING_CONFIRMATION"
	):
		return _no("RESTORE_APPLIED_PHASE_INVALID", {
			"execution_intent_retained": true,
		})

	return _yes("RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION", {
		"decision": DECISION_RESTORE_CLOUD,
		"review_id": str(current["review_id"]),
		"remote_revision": int(current["remote_revision"]),
		"remote_digest": str(current["remote_digest"]),
		"domain_count": DOMAIN_COUNT,
		"phase": "APPLIED_PENDING_CONFIRMATION",
		"mutation_performed": true,
		"qa_execution_performed": true,
		"confirmation_required": true,
		"preimage_backup_ready": true,
		"write_barrier_retained": bool(applied.get("write_barrier_retained", false)),
	})


func inspect_execution_for_qa(
	authenticated_uid: String, expected_review_id: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_EXECUTION_QA_DISABLED")
	var session: Dictionary = _load_session(authenticated_uid, expected_review_id)
	if session.is_empty():
		return _no("RESTORE_EXECUTION_SESSION_INVALID")
	var restore := RestoreScript.new() as RefCounted
	var state: Dictionary = restore.call(
		"inspect_registered_restore_for_qa", authenticated_uid
	)
	if not bool(state.get("ok", false)):
		return _no("RESTORE_ENGINE_STATE_UNAVAILABLE", {
			"restore_code": str(state.get("code", "UNKNOWN")),
		})
	var phase: String = str(state.get("phase", ""))
	if phase not in [
		"PREPARED", "COMMITTING", "APPLIED_PENDING_CONFIRMATION",
		"CONFIRMED", "ROLLED_BACK"
	]:
		return _no("RESTORE_ENGINE_PHASE_INVALID")
	return _yes("RESTORE_EXECUTION_INSPECTED", {
		"review_id": str(session["review_id"]),
		"remote_revision": int(session["remote_revision"]),
		"remote_digest": str(session["remote_digest"]),
		"phase": phase,
		"confirmation_required": phase == "APPLIED_PENDING_CONFIRMATION",
		"resolution_recorded": FileAccess.file_exists(SESSION_RESOLUTION),
	})


func resolve_applied_restore_for_qa(
	authenticated_uid: String,
	expected_review_id: String,
	resolution: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_EXECUTION_QA_DISABLED")
	if resolution not in [RESOLUTION_CONFIRM, RESOLUTION_ROLLBACK]:
		return _no("INVALID_RESTORE_RESOLUTION")
	var session: Dictionary = _load_session(authenticated_uid, expected_review_id)
	if session.is_empty():
		return _no("RESTORE_EXECUTION_SESSION_INVALID")

	var restore := RestoreScript.new() as RefCounted
	var before: Dictionary = restore.call(
		"inspect_registered_restore_for_qa", authenticated_uid
	)
	if not bool(before.get("ok", false)):
		return _no("RESTORE_ENGINE_STATE_UNAVAILABLE")
	var phase_before: String = str(before.get("phase", ""))

	# Idempotent terminal acknowledgement is allowed only for the same terminal
	# choice. Opposite decisions after a terminal state remain rejected.
	if phase_before == "CONFIRMED":
		if resolution != RESOLUTION_CONFIRM:
			return _no("RESTORE_ALREADY_CONFIRMED")
		return _terminal_result(session, RESOLUTION_CONFIRM, "CONFIRMED", true)
	if phase_before == "ROLLED_BACK":
		if resolution != RESOLUTION_ROLLBACK:
			return _no("RESTORE_ALREADY_ROLLED_BACK")
		return _terminal_result(session, RESOLUTION_ROLLBACK, "ROLLED_BACK", true)
	if phase_before != "APPLIED_PENDING_CONFIRMATION":
		return _no("RESTORE_NOT_AWAITING_CONFIRMATION")

	var resolved: Dictionary
	if resolution == RESOLUTION_CONFIRM:
		resolved = restore.call(
			"confirm_registered_restore_for_qa", authenticated_uid
		)
	else:
		resolved = restore.call(
			"rollback_registered_restore_for_qa", authenticated_uid, ""
		)
	if not bool(resolved.get("ok", false)):
		return _no("RESTORE_RESOLUTION_FAILED", {
			"restore_code": str(resolved.get("code", "UNKNOWN")),
		})

	var after: Dictionary = restore.call(
		"inspect_registered_restore_for_qa", authenticated_uid
	)
	if not bool(after.get("ok", false)):
		return _no("RESTORE_RESOLUTION_VERIFY_FAILED")
	var expected_phase: String = (
		"CONFIRMED" if resolution == RESOLUTION_CONFIRM else "ROLLED_BACK"
	)
	if str(after.get("phase", "")) != expected_phase:
		return _no("RESTORE_RESOLUTION_PHASE_INVALID")

	var resolution_record: Dictionary = {
		"version": SESSION_VERSION,
		"owner_uid": authenticated_uid,
		"review_id": expected_review_id,
		"resolution": resolution,
		"phase": expected_phase,
	}
	if not _write_var_atomic(SESSION_RESOLUTION, resolution_record):
		return _no("RESTORE_RESOLUTION_RECORD_WRITE_FAILED")

	return _terminal_result(
		session, resolution, expected_phase, false,
		bool(resolved.get("vault_retained", true))
	)


func _terminal_result(
	session: Dictionary,
	resolution: String,
	phase: String,
	already_terminal: bool,
	vault_retained: bool = true
) -> Dictionary:
	var code: String = "RESTORE_EXECUTION_ROLLED_BACK"
	if phase == "CONFIRMED":
		code = "RESTORE_EXECUTION_CONFIRMED"
	return _yes(code, {
		"review_id": str(session["review_id"]),
		"remote_revision": int(session["remote_revision"]),
		"remote_digest": str(session["remote_digest"]),
		"resolution": resolution,
		"phase": phase,
		"confirmation_required": false,
		"already_terminal": already_terminal,
		"vault_retained": vault_retained,
		"qa_execution_performed": true,
	})


func _review_binding_issue(
	presented: Dictionary, current: Dictionary
) -> String:
	if not bool(current.get("ok", false)) or str(current.get("code", "")) != "RESTORE_REVIEW_READY":
		return "RESTORE_REVIEW_REVALIDATION_FAILED"
	if not bool(presented.get("ok", false)) or str(presented.get("code", "")) != "RESTORE_REVIEW_READY":
		return "PRESENTED_REVIEW_INVALID"
	for key in [
		"review_id", "local_state_fingerprint", "remote_digest",
		"remote_revision", "domain_count"
	]:
		if presented.get(key) != current.get(key):
			if key in ["review_id", "local_state_fingerprint"]:
				return "REVIEW_LOCAL_STATE_CHANGED"
			return "REVIEW_REMOTE_METADATA_CHANGED"
	if (
		presented.get("decision_required") != true
		or presented.get("execution_allowed") != false
		or presented.get("restore_allowed") != false
		or presented.get("upload_allowed") != false
		or presented.get("cloud_mutation_enabled") != false
		or presented.get("raw_payload_included") != false
	):
		return "PRESENTED_REVIEW_UNSAFE_FLAGS"
	return ""


func _install_restore_candidates(
	restore: RefCounted,
	ready_record: Dictionary,
	authenticated_uid: String
) -> Dictionary:
	if not (ready_record.get("candidate_paths") is Dictionary):
		return _no("CANDIDATE_PATHS_INVALID")
	var sources: Dictionary = ready_record["candidate_paths"]
	var targets: Dictionary = restore.call("candidate_paths_for_qa")
	var ids: Array[String] = _permanent_ids()
	if ids.size() != DOMAIN_COUNT:
		return _no("PERMANENT_DOMAIN_REGISTRY_CHANGED")
	if not _has_exact_keys(sources, ids) or not _has_exact_keys(targets, ids):
		return _no("CANDIDATE_DOMAIN_SET_INVALID")

	var ready_path: String = str(ready_record.get("ready_path", ""))
	var restore_root: String = str(restore.call("qa_root"))
	for id in ids:
		var source: String = str(sources[id])
		var target: String = str(targets[id])
		if source != ready_path + "/domains/" + id + ".save":
			return _no("CANDIDATE_SOURCE_PATH_INVALID")
		if (
			not target.begins_with(restore_root + "candidate/")
			or ".." in target
		):
			return _no("RESTORE_CANDIDATE_TARGET_INVALID")
		var copied: Dictionary = _copy_exact_candidate(source, target)
		if not bool(copied.get("ok", false)):
			return copied
	return _yes("RESTORE_CANDIDATE_HANDOFF_READY", {
		"domain_count": DOMAIN_COUNT,
		"owner_bound": not authenticated_uid.is_empty(),
	})


func _restore_candidates_match_ready(
	restore: RefCounted, ready_record: Dictionary
) -> bool:
	if not (ready_record.get("candidate_paths") is Dictionary):
		return false
	var ready_paths: Dictionary = ready_record["candidate_paths"]
	var restore_paths: Dictionary = restore.call("candidate_paths_for_qa")
	var ids: Array[String] = _permanent_ids()
	if not _has_exact_keys(ready_paths, ids) or not _has_exact_keys(restore_paths, ids):
		return false
	for id in ids:
		var reviewed: String = str(ready_paths[id])
		var installed: String = str(restore_paths[id])
		if not FileAccess.file_exists(reviewed) or not FileAccess.file_exists(installed):
			return false
		var reviewed_hash: String = FileAccess.get_sha256(reviewed)
		if not _sha256_shape(reviewed_hash):
			return false
		if FileAccess.get_sha256(installed) != reviewed_hash:
			return false
	return true


func _copy_exact_candidate(source: String, target: String) -> Dictionary:
	if not FileAccess.file_exists(source):
		return _no("CANDIDATE_SOURCE_MISSING")
	var size: int = FileAccess.get_size(source)
	if size <= 0 or size > MAX_DOMAIN_BYTES:
		return _no("CANDIDATE_SOURCE_SIZE_INVALID")
	var digest: String = FileAccess.get_sha256(source)
	if not _sha256_shape(digest):
		return _no("CANDIDATE_SOURCE_HASH_INVALID")
	var reader: FileAccess = FileAccess.open(source, FileAccess.READ)
	if reader == null:
		return _no("CANDIDATE_SOURCE_READ_FAILED")
	var bytes: PackedByteArray = reader.get_buffer(size)
	reader.close()
	if bytes.size() != size:
		return _no("CANDIDATE_SOURCE_READ_FAILED")

	var parent: String = target.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			return _no("RESTORE_CANDIDATE_DIRECTORY_UNAVAILABLE")
	var incoming: String = target + ".incoming"
	if FileAccess.file_exists(incoming):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(incoming)) != OK:
			return _no("RESTORE_CANDIDATE_STALE_INCOMING")
	var writer: FileAccess = FileAccess.open(incoming, FileAccess.WRITE)
	if writer == null:
		return _no("RESTORE_CANDIDATE_WRITE_FAILED")
	var stored: bool = writer.store_buffer(bytes)
	writer.flush()
	writer.close()
	if (
		not stored
		or FileAccess.get_size(incoming) != size
		or FileAccess.get_sha256(incoming) != digest
	):
		return _no("RESTORE_CANDIDATE_WRITE_VERIFY_FAILED")
	if FileAccess.file_exists(target):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) != OK:
			return _no("RESTORE_CANDIDATE_REPLACE_FAILED")
	if DirAccess.rename_absolute(
		ProjectSettings.globalize_path(incoming),
		ProjectSettings.globalize_path(target)
	) != OK:
		return _no("RESTORE_CANDIDATE_PROMOTE_FAILED")
	if FileAccess.get_sha256(target) != digest:
		return _no("RESTORE_CANDIDATE_PROMOTE_VERIFY_FAILED")
	return _yes("RESTORE_CANDIDATE_COPIED", {"sha256": digest, "bytes": size})


func _load_session(authenticated_uid: String, expected_review_id: String) -> Dictionary:
	if not _safe_uid(authenticated_uid) or not _sha256_shape(expected_review_id):
		return {}
	var session: Dictionary = _read_var_dictionary(SESSION_INTENT)
	if not _has_exact_keys(session, SESSION_KEYS):
		return {}
	if session.get("version") != SESSION_VERSION:
		return {}
	if str(session.get("owner_uid", "")) != authenticated_uid:
		return {}
	if str(session.get("review_id", "")) != expected_review_id:
		return {}
	if not _sha256_shape(str(session.get("local_state_fingerprint", ""))):
		return {}
	if not _sha256_shape(str(session.get("remote_digest", ""))):
		return {}
	if typeof(session.get("remote_revision")) != TYPE_INT or int(session["remote_revision"]) <= 0:
		return {}
	if session.get("domain_count") != DOMAIN_COUNT:
		return {}
	if str(session.get("decision", "")) != DECISION_RESTORE_CLOUD:
		return {}
	var ready_path: String = str(session.get("ready_path", ""))
	if (
		not ready_path.begins_with(CONTROLLED_TRANSFER_ROOT + "ready_")
		or ".." in ready_path
	):
		return {}
	return session


func _write_var_atomic(path: String, data: Dictionary) -> bool:
	var parent: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		if DirAccess.make_dir_recursive_absolute(parent) != OK:
			return false
	var tmp: String = path + ".tmp"
	if FileAccess.file_exists(tmp):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp)) != OK:
			return false
	var file: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_var(data)
	file.flush()
	file.close()
	if _read_var_dictionary(tmp) != data:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return false
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
	var raw: Variant = file.get_var(false)
	file.close()
	return raw if raw is Dictionary else {}


func _permanent_ids() -> Array[String]:
	var ids: Array[String] = SaveManager.get_save_domain_ids_for_scope(
		SaveManager.SCOPE_PERMANENT
	)
	ids.sort()
	return ids


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


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_RESTORE_REVIEW_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_REVIEW_ACK") == REQUIRED_ACK
		and OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_ACK") == REQUIRED_ACK
		and OS.get_environment("JADE_RESTORE_EXECUTION_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_EXECUTION_ACK") == REQUIRED_ACK
	)


func _yes(code: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"code": code,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
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
		"production_execution_allowed": false,
	}
	for key in extra:
		result[key] = extra[key]
	return result
