extends RefCounted

## Subphase E3A — QA-only restore UX presenter/state model.
##
## This object accepts only the safe E1 review dictionary shape, formats a
## payload-free view model, and enforces explicit user decision sequencing.
## It never reads/writes save files, never performs network I/O, and never
## calls restore authority directly. E3B may consume its bound command output
## and route that command to the already-locked execution authority.

const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
const DOMAIN_COUNT: int = 8
const DOMAIN_IDS = [
	"achievements",
	"daily_quests",
	"equipment",
	"idle_cultivation",
	"inventory",
	"journey",
	"pavilion",
	"progression",
]
const SAFE_DOMAIN_STATES = ["SAME", "DIFFERENT", "LOCAL_MISSING", "LOCAL_INVALID"]

const STATE_NO_CANDIDATE: String = "NO_CANDIDATE"
const STATE_REVIEW_READY: String = "REVIEW_READY"
const STATE_RESTORE_CONFIRMATION_REQUIRED: String = "RESTORE_CONFIRMATION_REQUIRED"
const STATE_EXECUTING: String = "EXECUTING"
const STATE_APPLIED_PENDING_CONFIRMATION: String = "APPLIED_PENDING_CONFIRMATION"
const STATE_USER_CHOSE_KEEP_LOCAL: String = "USER_CHOSE_KEEP_LOCAL"
const STATE_USER_CONFIRMED_RESTORED: String = "USER_CONFIRMED_RESTORED"
const STATE_USER_ROLLED_BACK: String = "USER_ROLLED_BACK"
const STATE_ERROR_FAIL_CLOSED: String = "ERROR_FAIL_CLOSED"

const DECISION_KEEP_LOCAL: String = "KEEP_LOCAL"
const DECISION_RESTORE_CLOUD: String = "RESTORE_CLOUD"
const RESOLUTION_CONFIRM: String = "CONFIRM"
const RESOLUTION_ROLLBACK: String = "ROLLBACK"

const ACTION_SUBMIT_REVIEW_DECISION: String = "SUBMIT_REVIEW_DECISION"
const ACTION_RESOLVE_APPLIED_RESTORE: String = "RESOLVE_APPLIED_RESTORE"

var _state: String = STATE_NO_CANDIDATE
var _review: Dictionary = {}
var _pending_action: String = ""
var _last_error_code: String = ""


func present_review_for_qa(review: Dictionary) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state in [
		STATE_RESTORE_CONFIRMATION_REQUIRED,
		STATE_EXECUTING,
		STATE_APPLIED_PENDING_CONFIRMATION,
		STATE_ERROR_FAIL_CLOSED,
	]:
		return _no("RESTORE_UX_REVIEW_REPLACEMENT_BLOCKED")
	var issue: String = _review_issue(review)
	if not issue.is_empty():
		_review = {}
		return _fail_closed(issue)
	_review = _copy_safe_review_binding(review)
	_pending_action = ""
	_last_error_code = ""
	_state = STATE_REVIEW_READY
	return _yes("RESTORE_UX_REVIEW_PRESENTED", {
		"state": _state,
		"restore_choice_available": _restore_choice_available(),
	})


func get_view_for_qa(locale: String = "en") -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if locale not in ["en", "id"]:
		return _no("RESTORE_UX_LOCALE_INVALID")
	var view: Dictionary = {
		"state": _state,
		"headline": _headline(locale),
		"message": _message(locale),
		"timestamp_note": _timestamp_note(locale),
		"owner_display": "",
		"remote_revision": 0,
		"remote_digest_display": "",
		"captured_at_unix": 0,
		"domain_count": 0,
		"same_count": 0,
		"changed_count": 0,
		"local_issue_count": 0,
		"domain_rows": [],
		"restore_choice_available": false,
		"actions": _available_actions(),
		"raw_payload_included": false,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
	}
	if not _review.is_empty():
		view["owner_display"] = str(_review["owner_display"])
		view["remote_revision"] = int(_review["remote_revision"])
		view["remote_digest_display"] = _short_digest(str(_review["remote_digest"]))
		view["captured_at_unix"] = int(_review["captured_at_unix"])
		view["domain_count"] = DOMAIN_COUNT
		view["same_count"] = int(_review["same_count"])
		view["changed_count"] = int(_review["changed_count"])
		view["local_issue_count"] = int(_review["local_issue_count"])
		view["domain_rows"] = _domain_rows(locale)
		view["restore_choice_available"] = _restore_choice_available()
	return _yes("RESTORE_UX_VIEW_READY", {"view": view})


func choose_keep_local_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_REVIEW_READY:
		return _no("RESTORE_UX_KEEP_LOCAL_NOT_AVAILABLE")
	_state = STATE_EXECUTING
	_pending_action = DECISION_KEEP_LOCAL
	return _decision_command(DECISION_KEEP_LOCAL)


func choose_restore_cloud_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_REVIEW_READY:
		return _no("RESTORE_UX_RESTORE_CHOICE_NOT_AVAILABLE")
	if not _restore_choice_available():
		return _no("RESTORE_UX_RESTORE_CHOICE_BLOCKED")
	_state = STATE_RESTORE_CONFIRMATION_REQUIRED
	_pending_action = ""
	return _yes("RESTORE_UX_CONFIRMATION_REQUIRED", {
		"state": _state,
		"command_ready": false,
		"mutation_requested": false,
	})


func cancel_restore_confirmation_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_RESTORE_CONFIRMATION_REQUIRED:
		return _no("RESTORE_UX_CONFIRMATION_NOT_ACTIVE")
	_state = STATE_REVIEW_READY
	_pending_action = ""
	return _yes("RESTORE_UX_CONFIRMATION_CANCELLED", {
		"state": _state,
		"mutation_requested": false,
	})


func confirm_restore_cloud_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_RESTORE_CONFIRMATION_REQUIRED:
		return _no("RESTORE_UX_SECOND_CONFIRMATION_REQUIRED")
	_state = STATE_EXECUTING
	_pending_action = DECISION_RESTORE_CLOUD
	return _decision_command(DECISION_RESTORE_CLOUD)


func apply_execution_result_for_qa(result: Dictionary) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_EXECUTING or _pending_action not in [DECISION_KEEP_LOCAL, DECISION_RESTORE_CLOUD]:
		return _no("RESTORE_UX_EXECUTION_RESULT_UNEXPECTED")
	var binding_issue: String = _bound_result_issue(result)
	if not binding_issue.is_empty():
		return _fail_closed(binding_issue)
	if result.get("ok") != true:
		return _fail_closed("RESTORE_UX_EXECUTION_REJECTED")

	if _pending_action == DECISION_KEEP_LOCAL:
		if (
			str(result.get("code", "")) != "RESTORE_DECISION_KEEP_LOCAL"
			or str(result.get("decision", "")) != DECISION_KEEP_LOCAL
			or result.get("mutation_performed") != false
			or result.get("confirmation_required") != false
		):
			return _fail_closed("RESTORE_UX_KEEP_LOCAL_RESULT_INVALID")
		_pending_action = ""
		_state = STATE_USER_CHOSE_KEEP_LOCAL
		return _yes("RESTORE_UX_KEEP_LOCAL_COMPLETE", {
			"state": _state,
			"mutation_performed": false,
		})

	if (
		str(result.get("code", "")) != "RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION"
		or str(result.get("decision", "")) != DECISION_RESTORE_CLOUD
		or str(result.get("phase", "")) != STATE_APPLIED_PENDING_CONFIRMATION
		or result.get("mutation_performed") != true
		or result.get("confirmation_required") != true
		or result.get("preimage_backup_ready") != true
	):
		return _fail_closed("RESTORE_UX_APPLIED_RESULT_INVALID")
	_pending_action = ""
	_state = STATE_APPLIED_PENDING_CONFIRMATION
	return _yes("RESTORE_UX_APPLIED_PENDING_CONFIRMATION", {
		"state": _state,
		"confirmation_required": true,
	})


func choose_keep_restored_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_APPLIED_PENDING_CONFIRMATION:
		return _no("RESTORE_UX_RESOLUTION_NOT_AVAILABLE")
	_state = STATE_EXECUTING
	_pending_action = RESOLUTION_CONFIRM
	return _resolution_command(RESOLUTION_CONFIRM)


func choose_rollback_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_APPLIED_PENDING_CONFIRMATION:
		return _no("RESTORE_UX_RESOLUTION_NOT_AVAILABLE")
	_state = STATE_EXECUTING
	_pending_action = RESOLUTION_ROLLBACK
	return _resolution_command(RESOLUTION_ROLLBACK)


func apply_resolution_result_for_qa(result: Dictionary) -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_QA_DISABLED")
	if _state != STATE_EXECUTING or _pending_action not in [RESOLUTION_CONFIRM, RESOLUTION_ROLLBACK]:
		return _no("RESTORE_UX_RESOLUTION_RESULT_UNEXPECTED")
	var binding_issue: String = _bound_result_issue(result)
	if not binding_issue.is_empty():
		return _fail_closed(binding_issue)
	if result.get("ok") != true:
		return _fail_closed("RESTORE_UX_RESOLUTION_REJECTED")

	var expected_phase: String = "CONFIRMED" if _pending_action == RESOLUTION_CONFIRM else "ROLLED_BACK"
	var expected_code: String = (
		"RESTORE_EXECUTION_CONFIRMED"
		if _pending_action == RESOLUTION_CONFIRM
		else "RESTORE_EXECUTION_ROLLED_BACK"
	)
	if (
		str(result.get("code", "")) != expected_code
		or str(result.get("resolution", "")) != _pending_action
		or str(result.get("phase", "")) != expected_phase
		or result.get("confirmation_required") != false
	):
		return _fail_closed("RESTORE_UX_RESOLUTION_RESULT_INVALID")

	var terminal_action: String = _pending_action
	_pending_action = ""
	_state = (
		STATE_USER_CONFIRMED_RESTORED
		if terminal_action == RESOLUTION_CONFIRM
		else STATE_USER_ROLLED_BACK
	)
	return _yes("RESTORE_UX_RESOLUTION_COMPLETE", {
		"state": _state,
		"resolution": terminal_action,
	})


func _decision_command(decision: String) -> Dictionary:
	return _command(ACTION_SUBMIT_REVIEW_DECISION, {
		"decision": decision,
		"mutation_requested": decision == DECISION_RESTORE_CLOUD,
	})


func _resolution_command(resolution: String) -> Dictionary:
	return _command(ACTION_RESOLVE_APPLIED_RESTORE, {
		"resolution": resolution,
		"mutation_requested": true,
	})


func _command(action: String, extra: Dictionary) -> Dictionary:
	if _review.is_empty():
		return _fail_closed("RESTORE_UX_REVIEW_BINDING_MISSING")
	var command: Dictionary = {
		"action": action,
		"review_id": str(_review["review_id"]),
		"remote_revision": int(_review["remote_revision"]),
		"remote_digest": str(_review["remote_digest"]),
		"upload_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
	}
	for key in extra:
		command[key] = extra[key]
	return _yes("RESTORE_UX_COMMAND_READY", {
		"state": _state,
		"command_ready": true,
		"command": command,
	})


func _review_issue(review: Dictionary) -> String:
	if review.get("ok") != true or str(review.get("code", "")) != "RESTORE_REVIEW_READY":
		return "RESTORE_UX_REVIEW_INVALID"
	for forbidden_key in ["owner_uid", "candidate_paths", "domains", "draft"]:
		if review.has(forbidden_key):
			return "RESTORE_UX_RAW_REVIEW_FIELD_REJECTED"
	if (
		review.get("upload_allowed") != false
		or review.get("restore_allowed") != false
		or review.get("cloud_mutation_enabled") != false
		or review.get("execution_allowed") != false
		or review.get("raw_payload_included") != false
	):
		return "RESTORE_UX_REVIEW_UNSAFE_FLAGS"
	if review.get("owner_verified") != true or not _masked_owner_shape(str(review.get("owner_display", ""))):
		return "RESTORE_UX_OWNER_DISPLAY_INVALID"
	if typeof(review.get("remote_revision")) != TYPE_INT or int(review["remote_revision"]) <= 0:
		return "RESTORE_UX_REMOTE_REVISION_INVALID"
	if not _sha256_shape(str(review.get("remote_digest", ""))):
		return "RESTORE_UX_REMOTE_DIGEST_INVALID"
	if typeof(review.get("captured_at_unix")) != TYPE_INT or int(review["captured_at_unix"]) < 0:
		return "RESTORE_UX_CAPTURE_TIME_INVALID"
	if review.get("domain_count") != DOMAIN_COUNT:
		return "RESTORE_UX_DOMAIN_COUNT_INVALID"
	if not _sha256_shape(str(review.get("review_id", ""))):
		return "RESTORE_UX_REVIEW_ID_INVALID"
	if not _sha256_shape(str(review.get("local_state_fingerprint", ""))):
		return "RESTORE_UX_LOCAL_FINGERPRINT_INVALID"
	if (
		review.get("decision_required") != true
		or review.get("decision_options") != [DECISION_KEEP_LOCAL, DECISION_RESTORE_CLOUD]
		or review.get("preimage_backup_required") != true
		or review.get("preimage_runtime_guards_checked") != false
		or review.get("execution_preconditions_met") != false
	):
		return "RESTORE_UX_REVIEW_DECISION_CONTRACT_INVALID"
	if not (review.get("domain_states") is Dictionary):
		return "RESTORE_UX_DOMAIN_STATES_INVALID"
	var states: Dictionary = review["domain_states"]
	if not _has_exact_keys(states, DOMAIN_IDS):
		return "RESTORE_UX_DOMAIN_STATES_INVALID"
	var counted_same: int = 0
	var counted_different: int = 0
	var counted_local_state_issues: int = 0
	for domain_id in DOMAIN_IDS:
		var state: String = str(states[domain_id])
		if state not in SAFE_DOMAIN_STATES:
			return "RESTORE_UX_DOMAIN_STATE_INVALID"
		if state == "SAME":
			counted_same += 1
		elif state == "DIFFERENT":
			counted_different += 1
		else:
			counted_local_state_issues += 1
	for key in ["same_count", "changed_count", "local_issue_count"]:
		if typeof(review.get(key)) != TYPE_INT or int(review[key]) < 0:
			return "RESTORE_UX_REVIEW_COUNTS_INVALID"
	if int(review["same_count"]) != counted_same or int(review["changed_count"]) != counted_different:
		return "RESTORE_UX_REVIEW_COUNTS_INVALID"
	if typeof(review.get("preimage_source_files_ready")) != TYPE_BOOL:
		return "RESTORE_UX_PREIMAGE_READINESS_INVALID"
	var issue_count: int = int(review["local_issue_count"])
	var source_ready: bool = bool(review["preimage_source_files_ready"])
	if issue_count < counted_local_state_issues:
		return "RESTORE_UX_REVIEW_COUNTS_INVALID"
	if source_ready != (issue_count == 0):
		return "RESTORE_UX_PREIMAGE_READINESS_INVALID"
	return ""


func _bound_result_issue(result: Dictionary) -> String:
	if _review.is_empty():
		return "RESTORE_UX_REVIEW_BINDING_MISSING"
	if (
		str(result.get("review_id", "")) != str(_review["review_id"])
		or result.get("remote_revision") != _review["remote_revision"]
		or str(result.get("remote_digest", "")) != str(_review["remote_digest"])
	):
		return "RESTORE_UX_RESULT_BINDING_MISMATCH"
	if (
		result.get("upload_allowed") != false
		or result.get("restore_allowed") != false
		or result.get("cloud_mutation_enabled") != false
		or result.get("production_execution_allowed") != false
	):
		return "RESTORE_UX_RESULT_UNSAFE_FLAGS"
	return ""


func _copy_safe_review_binding(review: Dictionary) -> Dictionary:
	return {
		"owner_display": str(review["owner_display"]),
		"remote_revision": int(review["remote_revision"]),
		"remote_digest": str(review["remote_digest"]),
		"captured_at_unix": int(review["captured_at_unix"]),
		"domain_states": (review["domain_states"] as Dictionary).duplicate(true),
		"same_count": int(review["same_count"]),
		"changed_count": int(review["changed_count"]),
		"local_issue_count": int(review["local_issue_count"]),
		"preimage_source_files_ready": bool(review["preimage_source_files_ready"]),
		"review_id": str(review["review_id"]),
		"local_state_fingerprint": str(review["local_state_fingerprint"]),
	}


func _restore_choice_available() -> bool:
	return (
		not _review.is_empty()
		and int(_review.get("changed_count", 0)) > 0
		and int(_review.get("local_issue_count", 1)) == 0
		and bool(_review.get("preimage_source_files_ready", false))
	)


func _available_actions() -> Dictionary:
	return {
		"keep_local": _state == STATE_REVIEW_READY,
		"choose_restore": _state == STATE_REVIEW_READY and _restore_choice_available(),
		"cancel_restore_confirmation": _state == STATE_RESTORE_CONFIRMATION_REQUIRED,
		"confirm_restore": _state == STATE_RESTORE_CONFIRMATION_REQUIRED,
		"keep_restored": _state == STATE_APPLIED_PENDING_CONFIRMATION,
		"rollback": _state == STATE_APPLIED_PENDING_CONFIRMATION,
	}


func _domain_rows(locale: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var states: Dictionary = _review["domain_states"]
	for domain_id in DOMAIN_IDS:
		rows.append({
			"id": domain_id,
			"label": _domain_label(domain_id, locale),
			"state": str(states[domain_id]),
		})
	return rows


func _domain_label(domain_id: String, locale: String) -> String:
	var labels_en: Dictionary = {
		"achievements": "Achievements",
		"daily_quests": "Daily Quests",
		"equipment": "Equipment",
		"idle_cultivation": "Idle Cultivation",
		"inventory": "Inventory",
		"journey": "Journey",
		"pavilion": "Pavilion",
		"progression": "Progression",
	}
	var labels_id: Dictionary = {
		"achievements": "Pencapaian",
		"daily_quests": "Misi Harian",
		"equipment": "Perlengkapan",
		"idle_cultivation": "Kultivasi Idle",
		"inventory": "Inventaris",
		"journey": "Perjalanan",
		"pavilion": "Paviliun",
		"progression": "Progresi",
	}
	var labels: Dictionary = labels_id if locale == "id" else labels_en
	return str(labels.get(domain_id, domain_id))


func _headline(locale: String) -> String:
	match _state:
		STATE_NO_CANDIDATE:
			return "Belum ada snapshot cloud untuk ditinjau" if locale == "id" else "No cloud snapshot is ready for review"
		STATE_REVIEW_READY:
			return "Tinjau pilihan save" if locale == "id" else "Review save choice"
		STATE_RESTORE_CONFIRMATION_REQUIRED:
			return "Konfirmasi pemulihan" if locale == "id" else "Confirm restore"
		STATE_EXECUTING:
			return "Memproses pilihan" if locale == "id" else "Processing decision"
		STATE_APPLIED_PENDING_CONFIRMATION:
			return "Pemulihan belum final" if locale == "id" else "Restore is not final yet"
		STATE_USER_CHOSE_KEEP_LOCAL:
			return "Save lokal dipertahankan" if locale == "id" else "Local save kept"
		STATE_USER_CONFIRMED_RESTORED:
			return "Save hasil pemulihan dipertahankan" if locale == "id" else "Restored save kept"
		STATE_USER_ROLLED_BACK:
			return "Save lokal dipulihkan kembali" if locale == "id" else "Local save rolled back"
		_:
			return "Pemulihan dihentikan dengan aman" if locale == "id" else "Restore stopped safely"


func _message(locale: String) -> String:
	match _state:
		STATE_REVIEW_READY:
			return (
				"Pilih apakah save lokal tetap dipakai atau lanjut ke konfirmasi pemulihan. Belum ada save yang diubah."
				if locale == "id"
				else "Choose whether to keep the local save or continue to restore confirmation. No save has changed yet."
			)
		STATE_RESTORE_CONFIRMATION_REQUIRED:
			return (
				"Lanjutkan hanya jika lu memang ingin memakai snapshot yang sudah ditinjau. Backup lokal wajib dibuat sebelum perubahan dan hasil pemulihan tetap harus dikonfirmasi atau dibatalkan."
				if locale == "id"
				else "Continue only if you intend to use the reviewed snapshot. A local backup is required before mutation, and the applied result must still be kept or rolled back explicitly."
			)
		STATE_EXECUTING:
			return (
				"Pilihan sedang diperiksa oleh lapisan keamanan restore. Jangan anggap perubahan sudah final."
				if locale == "id"
				else "The decision is being checked by the restore safety layer. Do not treat the change as final."
			)
		STATE_APPLIED_PENDING_CONFIRMATION:
			return (
				"Data hasil pemulihan sudah diterapkan tetapi belum final. Pilih PERTAHANKAN HASIL atau ROLLBACK."
				if locale == "id"
				else "Restored data is applied but not final. Choose KEEP RESTORED or ROLLBACK."
			)
		STATE_USER_CHOSE_KEEP_LOCAL:
			return "Tidak ada pemulihan yang diterapkan." if locale == "id" else "No restore was applied."
		STATE_USER_CONFIRMED_RESTORED:
			return "Hasil pemulihan sudah dikonfirmasi secara eksplisit." if locale == "id" else "The restored result was explicitly confirmed."
		STATE_USER_ROLLED_BACK:
			return "Pemulihan dibatalkan dan preimage lokal dipilih kembali." if locale == "id" else "The restore was rolled back to the local preimage."
		STATE_ERROR_FAIL_CLOSED:
			return "Alur restore dihentikan karena validasi tidak cocok. Tidak ada keputusan otomatis." if locale == "id" else "The restore flow stopped because validation did not match. No automatic decision was made."
		_:
			return "Belum ada keputusan restore." if locale == "id" else "No restore decision is active."


func _timestamp_note(locale: String) -> String:
	return (
		"Waktu snapshot hanya informasi. Bandingkan status domain sebelum memilih."
		if locale == "id"
		else "Snapshot time is informational only. Compare domain status before choosing."
	)


func _short_digest(value: String) -> String:
	if not _sha256_shape(value):
		return ""
	return value.left(10) + "…" + value.right(8)


func _masked_owner_shape(value: String) -> bool:
	if value == "••••":
		return true
	if value.length() != 9:
		return false
	return value.substr(4, 1) == "…"


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for key in expected:
		if not data.has(key):
			return false
	return true


func _sha256_shape(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _fail_closed(code: String) -> Dictionary:
	_state = STATE_ERROR_FAIL_CLOSED
	_pending_action = ""
	_last_error_code = code
	return _no(code, {"state": _state})


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_RESTORE_UX_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_UX_ACK") == REQUIRED_ACK
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
