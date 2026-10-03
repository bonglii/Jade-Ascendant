extends RefCounted

## E3C-A production-shaped, side-effect-free account-bound read client contract.
##
## This object performs NO networking, NO disk I/O, NO player-save manager calls, and NO
## restore/upload action. A future native bridge may deliver one fixed account-
## bound transport JSON record here. The contract revalidates the full snapshot
## and exposes only payload-free metadata to UI-facing callers.
##
## Raw transport can leave this object only through the explicit one-shot
## internal handoff API after identity is checked again. That handoff still grants
## zero restore/upload/production-execution authority.

const ContractScript = preload(
	"res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
)

const TRANSPORT_CONTRACT_VERSION: int = 1
const DOMAIN_COUNT: int = 8
const MAX_TRANSPORT_BYTES: int = 614400
const MAX_SAFE_INTEGER: int = 9007199254740991
const MAX_DEPTH: int = 16
const MAX_CONTAINER_ENTRIES: int = 4096

const STATE_IDLE: String = "IDLE"
const STATE_REQUESTING: String = "REQUESTING"
const STATE_READY_FOR_REVIEW: String = "READY_FOR_REVIEW"
const STATE_ENDPOINT_NOT_ENABLED: String = "ENDPOINT_NOT_ENABLED"
const STATE_NO_SNAPSHOT: String = "NO_SNAPSHOT"
const STATE_UNAVAILABLE: String = "UNAVAILABLE"
const STATE_HANDED_OFF: String = "HANDED_OFF"
const STATE_ERROR_FAIL_CLOSED: String = "ERROR_FAIL_CLOSED"

const ACTION_REQUEST_CURRENT_SNAPSHOT: String = "REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT"
const SUCCESS_NATIVE_CODE: String = "ACCOUNT_BOUND_SNAPSHOT_READY"
const SUCCESS_TRANSPORT_CODE: String = "ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY"

const TRANSPORT_KEYS = [
	"ok",
	"code",
	"transport_contract_version",
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

const ENDPOINT_DISABLED_CODES = [
	"CALLABLE_NOT_FOUND",
	"READ_ENDPOINT_NOT_ENABLED",
]
const NO_SNAPSHOT_CODES = [
	"NO_CURRENT_SNAPSHOT",
	"ACCOUNT_NOT_FOUND",
]
const TRANSIENT_UNAVAILABLE_CODES = [
	"CALLABLE_UNAVAILABLE",
	"CALLABLE_DEADLINE_EXCEEDED",
	"CALLABLE_UNAUTHENTICATED",
	"CALLABLE_PERMISSION_DENIED",
	"APP_CHECK_NOT_READY",
	"GOOGLE_SIGN_IN_REQUIRED",
	"NATIVE_UNAVAILABLE",
	"BUSY",
]

var _state: String = STATE_IDLE
var _request_owner_uid: String = ""
var _validated_transport: Dictionary = {}
var _safe_summary: Dictionary = {}
var _last_code: String = ""


func begin_manual_request(authenticated_uid: String) -> Dictionary:
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if _state == STATE_REQUESTING:
		return _no("ACCOUNT_BOUND_READ_ALREADY_REQUESTING")
	_clear_sensitive()
	_request_owner_uid = authenticated_uid
	_state = STATE_REQUESTING
	_last_code = "ACCOUNT_BOUND_READ_REQUEST_READY"
	return _yes(_last_code, {
		"state": _state,
		"action": ACTION_REQUEST_CURRENT_SNAPSHOT,
		# Future native callable MUST receive exactly this empty payload. UID,
		# revision, digest, economy values and operation claims never cross as
		# caller-controlled request data.
		"client_payload": {},
		"owner_argument_included": false,
		"automatic_request": false,
		"explicit_user_action_required": true,
	})


func apply_native_result(
	success: bool,
	native_code: String,
	transport_json: String,
	current_authenticated_uid: String
) -> Dictionary:
	if _state != STATE_REQUESTING or _request_owner_uid.is_empty():
		return _no("ACCOUNT_BOUND_READ_RESULT_UNEXPECTED")
	if (
		not _safe_uid(current_authenticated_uid)
		or current_authenticated_uid != _request_owner_uid
	):
		return _fail_closed("ACCOUNT_CHANGED")

	if not success:
		_clear_validated_transport()
		_last_code = native_code
		if native_code in ENDPOINT_DISABLED_CODES:
			_request_owner_uid = ""
			_state = STATE_ENDPOINT_NOT_ENABLED
			return _no("ACCOUNT_BOUND_READ_ENDPOINT_NOT_ENABLED", {"state": _state})
		if native_code in NO_SNAPSHOT_CODES:
			_request_owner_uid = ""
			_state = STATE_NO_SNAPSHOT
			return _no("ACCOUNT_BOUND_READ_NO_SNAPSHOT", {"state": _state})
		if native_code in TRANSIENT_UNAVAILABLE_CODES:
			_request_owner_uid = ""
			_state = STATE_UNAVAILABLE
			return _no("ACCOUNT_BOUND_READ_UNAVAILABLE", {"state": _state})
		return _fail_closed("ACCOUNT_BOUND_READ_NATIVE_STATUS_UNSUPPORTED")

	if native_code != SUCCESS_NATIVE_CODE:
		return _fail_closed("ACCOUNT_BOUND_READ_NATIVE_SUCCESS_CODE_INVALID")
	var decoded: Dictionary = _decode_transport_json(transport_json, current_authenticated_uid)
	if not bool(decoded.get("ok", false)):
		return _fail_closed(str(decoded.get("code", "ACCOUNT_BOUND_READ_TRANSPORT_INVALID")))

	_validated_transport = (decoded["transport"] as Dictionary).duplicate(true)
	_safe_summary = _build_safe_summary(_validated_transport)
	_state = STATE_READY_FOR_REVIEW
	_last_code = "ACCOUNT_BOUND_READ_VALIDATED"
	return _yes(_last_code, {
		"state": _state,
		"safe_summary": _safe_summary.duplicate(true),
		"internal_handoff_available": true,
	})


func get_safe_status() -> Dictionary:
	return _yes("ACCOUNT_BOUND_READ_SAFE_STATUS", {
		"state": _state,
		"last_code": _safe_status_code(),
		"safe_summary": _safe_summary.duplicate(true),
		"internal_handoff_available": (
			_state == STATE_READY_FOR_REVIEW and not _validated_transport.is_empty()
		),
		"raw_payload_included": false,
	})


func take_validated_transport_for_internal_handoff(
	current_authenticated_uid: String
) -> Dictionary:
	if _state != STATE_READY_FOR_REVIEW or _validated_transport.is_empty():
		return _no("ACCOUNT_BOUND_READ_HANDOFF_NOT_AVAILABLE")
	if (
		not _safe_uid(current_authenticated_uid)
		or current_authenticated_uid != _request_owner_uid
	):
		return _fail_closed("ACCOUNT_CHANGED_BEFORE_HANDOFF")

	var transport: Dictionary = _validated_transport.duplicate(true)
	_clear_validated_transport()
	_request_owner_uid = ""
	_state = STATE_HANDED_OFF
	_last_code = "ACCOUNT_BOUND_READ_INTERNAL_HANDOFF_READY"
	return _yes(_last_code, {
		"state": _state,
		"internal_only": true,
		"ui_safe": false,
		"raw_payload_included": true,
		"one_shot": true,
		"transport": transport,
	})


func discard() -> Dictionary:
	_clear_sensitive()
	_state = STATE_IDLE
	_last_code = "ACCOUNT_BOUND_READ_DISCARDED"
	return _yes(_last_code, {"state": _state})


func _decode_transport_json(transport_json: String, authenticated_uid: String) -> Dictionary:
	if transport_json.is_empty() or transport_json.to_utf8_buffer().size() > MAX_TRANSPORT_BYTES:
		return _no("TRANSPORT_RECORD_SIZE_INVALID")
	var parsed: Variant = JSON.parse_string(transport_json)
	if parsed == null:
		return _no("TRANSPORT_JSON_INVALID")
	var normalized: Dictionary = _normalize_json_value(parsed, 0)
	if not bool(normalized.get("ok", false)):
		return _no(str(normalized.get("code", "TRANSPORT_JSON_INVALID")))
	var record_variant: Variant = normalized.get("value")
	if not (record_variant is Dictionary):
		return _no("TRANSPORT_RECORD_SHAPE_INVALID")
	var transport: Dictionary = record_variant
	if not _has_exact_keys(transport, TRANSPORT_KEYS):
		return _no("TRANSPORT_RECORD_SHAPE_INVALID")
	if transport.get("ok") != true or str(transport.get("code", "")) != SUCCESS_TRANSPORT_CODE:
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
	if typeof(transport.get("domain_count")) != TYPE_INT \
		or int(transport["domain_count"]) != DOMAIN_COUNT:
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
	var expected_ids: Array[String] = contract.call("get_domain_ids")
	if expected_ids.size() != DOMAIN_COUNT:
		return _no("PERMANENT_DOMAIN_CONTRACT_CHANGED")
	if not _string_array_exact(transport.get("domain_ids"), expected_ids):
		return _no("TRANSPORT_DOMAIN_SET_INVALID")
	var draft: Dictionary = (transport["draft"] as Dictionary).duplicate(true)
	var inspected: Dictionary = contract.call("inspect_draft", draft, authenticated_uid)
	if not bool(inspected.get("valid", false)):
		return _no("SNAPSHOT_CONTENT_INVALID")
	if str(contract.call("hash_draft", draft)) != digest:
		return _no("SNAPSHOT_DIGEST_MISMATCH")
	if typeof(draft.get("captured_at_unix")) != TYPE_INT or int(draft["captured_at_unix"]) < 0:
		return _no("REMOTE_CAPTURE_TIME_INVALID")

	return _yes("ACCOUNT_BOUND_READ_TRANSPORT_VALID", {
		"transport": transport.duplicate(true),
	})


func _build_safe_summary(transport: Dictionary) -> Dictionary:
	var draft: Dictionary = transport["draft"] as Dictionary
	return {
		"owner_display": _masked_uid(str(transport["ownerUid"])),
		"remote_revision": int(transport["revision"]),
		"remote_digest_display": _short_digest(str(transport["digest"])),
		"captured_at_unix": int(draft["captured_at_unix"]),
		"domain_count": int(transport["domain_count"]),
		"server_revision_verified": true,
		"server_freshness_verified": true,
		"explicit_restore_decision_required": true,
		"raw_payload_included": false,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
	}


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


func _clear_sensitive() -> void:
	_request_owner_uid = ""
	_clear_validated_transport()
	_safe_summary.clear()


func _clear_validated_transport() -> void:
	_validated_transport.clear()


func _fail_closed(code: String) -> Dictionary:
	_clear_sensitive()
	_state = STATE_ERROR_FAIL_CLOSED
	_last_code = code
	return _no(code, {"state": _state})


func _safe_status_code() -> String:
	match _state:
		STATE_IDLE:
			return "IDLE"
		STATE_REQUESTING:
			return "REQUESTING"
		STATE_READY_FOR_REVIEW:
			return "READY_FOR_REVIEW"
		STATE_ENDPOINT_NOT_ENABLED:
			return "ENDPOINT_NOT_ENABLED"
		STATE_NO_SNAPSHOT:
			return "NO_SNAPSHOT"
		STATE_UNAVAILABLE:
			return "UNAVAILABLE"
		STATE_HANDED_OFF:
			return "HANDED_OFF"
		STATE_ERROR_FAIL_CLOSED:
			return "ERROR_FAIL_CLOSED"
	return "UNKNOWN"


func _masked_uid(uid: String) -> String:
	if uid.length() <= 8:
		return "••••"
	return uid.left(4) + "…" + uid.right(4)


func _short_digest(digest: String) -> String:
	if digest.length() != 64:
		return ""
	return digest.left(8) + "…" + digest.right(8)


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


func _string_array_exact(value: Variant, expected: Array[String]) -> bool:
	if not (value is Array) or value.size() != expected.size():
		return false
	for index in range(expected.size()):
		if not (value[index] is String) or str(value[index]) != expected[index]:
			return false
	return true


func _has_exact_keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for raw_key in data:
		if not (raw_key is String) or raw_key not in expected:
			return false
	return true


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
