extends RefCounted

## QA-only decoder/adapter for the account-bound server transport record.
## It consumes JSON bytes produced by the isolated Firestore-emulator transport
## harness, validates the stricter transport envelope, then normalizes it into the
## already-locked controlled-transfer stager input shape. It never performs
## networking, writes player saves, or authorizes restore.

const ContractScript = preload(
	"res://scripts/managers/cloud_full_permanent_snapshot_contract.gd"
)

const TRANSPORT_CONTRACT_VERSION: int = 1
const MAX_TRANSPORT_BYTES: int = 614400
const MAX_SAFE_INTEGER: int = 9007199254740991
const MAX_DEPTH: int = 16
const MAX_CONTAINER_ENTRIES: int = 4096
const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
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


func decode_for_candidate_stager_qa(
	transport_json: String, authenticated_uid: String
) -> Dictionary:
	if not _qa_enabled():
		return _no("ACCOUNT_BOUND_TO_GODOT_QA_DISABLED")
	if not _safe_uid(authenticated_uid):
		return _no("INVALID_AUTHENTICATED_OWNER")
	if transport_json.is_empty() or transport_json.to_utf8_buffer().size() > MAX_TRANSPORT_BYTES:
		return _no("TRANSPORT_RECORD_SIZE_INVALID")

	var parsed: Variant = JSON.parse_string(transport_json)
	if parsed == null:
		return _no("TRANSPORT_JSON_INVALID")
	var normalized_result: Dictionary = _normalize_json_value(parsed, 0)
	if not bool(normalized_result.get("ok", false)):
		return _no(str(normalized_result.get("code", "TRANSPORT_JSON_INVALID")))
	var record: Variant = normalized_result.get("value")
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
	var expected_ids: Array[String] = contract.call("get_domain_ids")
	if not _string_array_exact(transport.get("domain_ids"), expected_ids):
		return _no("TRANSPORT_DOMAIN_SET_INVALID")
	var draft: Dictionary = (transport["draft"] as Dictionary).duplicate(true)
	var inspected: Dictionary = contract.call("inspect_draft", draft, authenticated_uid)
	if not bool(inspected.get("valid", false)):
		return _no("SNAPSHOT_CONTENT_INVALID", {
			"inspection_reason": str(inspected.get("reason", "invalid")),
		})
	var calculated_digest: String = str(contract.call("hash_draft", draft))
	if calculated_digest != digest:
		return _no("SNAPSHOT_DIGEST_MISMATCH")

	# The controlled-transfer stager is already PASS / LOCKED and intentionally
	# accepts this canonical reviewed-record shape. This adapter does not widen
	# authority: it requires stricter transport evidence first, and the stager
	# revalidates the draft and digest again before writing isolated candidates.
	var reviewed_record: Dictionary = {
		"ok": true,
		"code": "QA_LATEST_SNAPSHOT_REVIEWED",
		"qaOnly": true,
		"ownerUid": authenticated_uid,
		"revision": int(transport["revision"]),
		"digest": digest,
		"draft": draft,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
	}
	return _yes("ACCOUNT_BOUND_TRANSPORT_NORMALIZED_FOR_STAGER", {
		"reviewed_record": reviewed_record,
		"remote_revision": int(transport["revision"]),
		"remote_digest": digest,
		"domain_count": expected_ids.size(),
		"explicit_decision_required": true,
	})


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


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_ACCOUNT_BOUND_TO_GODOT_TEST_ONLY") == "1"
		and OS.get_environment("JADE_ACCOUNT_BOUND_TO_GODOT_ACK") == REQUIRED_ACK
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
