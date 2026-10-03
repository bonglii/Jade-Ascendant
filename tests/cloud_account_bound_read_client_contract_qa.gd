extends SceneTree

## E3C-A CI proof for the production-shaped account-bound read client contract.
## Uses an existing synthetic eight-domain QA transport fixture, transforms only
## its outer QA envelope into the future production transport envelope, and proves
## that the new client contract remains side-effect-free and fail-closed.

const CONTRACT_PATH: String = "res://scripts/managers/cloud_account_bound_read_client_contract.gd"
const FIXTURE_PATH: String = "res://backend/cloud_save/android_bridge/bridge/src/debug/assets/jade_account_bound_transport_device_record.json"
const OWNER: String = "account_bound_android_debug_owner"
const REMOTE_DIGEST: String = "f599e332a532f86844ececafc005bb21880e14a1a899745c5b7dfe44ddcf22a7"
const REMOTE_REVISION: int = 2

var checks: int = 0
var failures: int = 0
var contract: RefCounted


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("E3C-A account-bound read client contract QA requires disposable-runner gates.")
		quit(2)
		return
	var script: Script = load(CONTRACT_PATH) as Script
	_expect(script != null, "E3C-A client contract script loads")
	if script == null:
		_finish()
		return
	contract = script.new() as RefCounted
	_expect(contract != null, "E3C-A client contract constructs")
	if contract == null:
		_finish()
		return

	_test_manual_request_is_empty_and_explicit()
	_test_valid_transport_becomes_safe_summary()
	_test_one_shot_internal_handoff()
	_test_account_change_fails_closed()
	_test_unsafe_server_flags_fail_closed()
	_test_server_verification_required()
	_test_digest_binding_required()
	_test_endpoint_not_enabled_is_non_destructive()
	_test_unknown_native_status_fails_closed()
	_finish()


func _test_manual_request_is_empty_and_explicit() -> void:
	var request: Dictionary = contract.call("begin_manual_request", OWNER)
	_expect(request.get("ok") == true, "Manual account-bound read request can be armed")
	_expect(request.get("action") == "REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT",
		"Request action is fixed and non-generic")
	_expect((request.get("client_payload", {}) as Dictionary).is_empty(),
		"Future native request carries an empty client payload")
	_expect(request.get("owner_argument_included") == false,
		"Authenticated owner is never a caller-controlled argument")
	_expect(request.get("automatic_request") == false,
		"Account-bound read cannot auto-run at boot/sign-in")
	_expect(request.get("explicit_user_action_required") == true,
		"Account-bound read requires explicit user action")
	_expect(request.get("restore_allowed") == false and request.get("cloud_mutation_enabled") == false,
		"Request grants zero restore/cloud mutation authority")
	var duplicate: Dictionary = contract.call("begin_manual_request", OWNER)
	_expect(duplicate.get("ok") == false and duplicate.get("code") == "ACCOUNT_BOUND_READ_ALREADY_REQUESTING",
		"Concurrent/duplicate request is rejected")
	contract.call("discard")


func _test_valid_transport_becomes_safe_summary() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var transport_json: String = _production_transport_json()
	_expect(not transport_json.is_empty(), "Synthetic production transport fixture is available")
	var accepted: Dictionary = contract.call(
		"apply_native_result", true, "ACCOUNT_BOUND_SNAPSHOT_READY", transport_json, OWNER
	)
	_expect(accepted.get("ok") == true and accepted.get("state") == "READY_FOR_REVIEW",
		"Validated production envelope becomes READY_FOR_REVIEW")
	var safe: Dictionary = contract.call("get_safe_status")
	var summary: Dictionary = safe.get("safe_summary", {}) as Dictionary
	_expect(summary.get("owner_display") == "acco…wner", "Safe summary masks owner identity")
	_expect(summary.get("remote_revision") == REMOTE_REVISION, "Safe summary exposes reviewed revision")
	_expect(str(summary.get("remote_digest_display", "")).length() < 64,
		"Safe summary abbreviates digest")
	_expect(summary.get("captured_at_unix") == 1700000000,
		"Capture time remains informational metadata")
	_expect(summary.get("domain_count") == 8, "Exactly eight permanent domains survive validation")
	_expect(summary.get("server_revision_verified") == true and summary.get("server_freshness_verified") == true,
		"Server revision/freshness evidence survives as metadata")
	_expect(summary.get("explicit_restore_decision_required") == true,
		"Explicit restore decision remains mandatory")
	_expect(summary.get("raw_payload_included") == false,
		"Safe summary declares no raw payload")
	_expect(summary.get("restore_allowed") == false and summary.get("production_execution_allowed") == false,
		"Safe summary cannot authorize restore/production execution")
	var serialized: String = JSON.stringify(safe)
	_expect(OWNER not in serialized, "Full authenticated UID never appears in safe status")
	_expect(REMOTE_DIGEST not in serialized, "Full remote digest never appears in safe status")
	_expect("domains" not in serialized and "draft" not in serialized and "ownerUid" not in serialized,
		"Raw transport fields never appear in safe status")


func _test_one_shot_internal_handoff() -> void:
	var handoff: Dictionary = contract.call("take_validated_transport_for_internal_handoff", OWNER)
	_expect(handoff.get("ok") == true and handoff.get("state") == "HANDED_OFF",
		"Validated transport can move through one explicit internal handoff")
	_expect(handoff.get("internal_only") == true and handoff.get("ui_safe") == false,
		"Raw handoff is explicitly marked internal-only and not UI-safe")
	_expect(handoff.get("raw_payload_included") == true and handoff.get("one_shot") == true,
		"Raw handoff is explicit and one-shot")
	_expect(handoff.get("restore_allowed") == false and handoff.get("cloud_mutation_enabled") == false,
		"Internal handoff still grants zero restore/cloud mutation authority")
	var transport: Dictionary = handoff.get("transport", {}) as Dictionary
	_expect(transport.get("ownerUid") == OWNER and transport.get("digest") == REMOTE_DIGEST,
		"Internal handoff retains exact validated account binding")
	var second: Dictionary = contract.call("take_validated_transport_for_internal_handoff", OWNER)
	_expect(second.get("ok") == false and second.get("code") == "ACCOUNT_BOUND_READ_HANDOFF_NOT_AVAILABLE",
		"Raw transport cannot be consumed twice")
	var safe_after: Dictionary = contract.call("get_safe_status")
	_expect(safe_after.get("internal_handoff_available") == false,
		"Safe status reports no residual raw handoff after consumption")


func _test_account_change_fails_closed() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var changed: Dictionary = contract.call(
		"apply_native_result", true, "ACCOUNT_BOUND_SNAPSHOT_READY", _production_transport_json(), "different_owner"
	)
	_expect(changed.get("ok") == false and changed.get("state") == "ERROR_FAIL_CLOSED",
		"Account change during async read fails closed")
	_expect(contract.call("get_safe_status").get("internal_handoff_available") == false,
		"Account-change failure retains no raw handoff")


func _test_unsafe_server_flags_fail_closed() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var record: Dictionary = _production_transport_record()
	record["restore_allowed"] = true
	var rejected: Dictionary = contract.call(
		"apply_native_result", true, "ACCOUNT_BOUND_SNAPSHOT_READY", JSON.stringify(record), OWNER
	)
	_expect(rejected.get("ok") == false and rejected.get("state") == "ERROR_FAIL_CLOSED",
		"Transport attempting to authorize restore is rejected")
	_expect(rejected.get("code") == "TRANSPORT_RECORD_UNSAFE_FLAGS",
		"Unsafe server flags have a stable fail-closed code")


func _test_server_verification_required() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var record: Dictionary = _production_transport_record()
	record["server_freshness_verified"] = false
	var rejected: Dictionary = contract.call(
		"apply_native_result", true, "ACCOUNT_BOUND_SNAPSHOT_READY", JSON.stringify(record), OWNER
	)
	_expect(rejected.get("ok") == false and rejected.get("code") == "TRANSPORT_SERVER_VERIFICATION_MISSING",
		"Missing server revision/freshness evidence fails closed")


func _test_digest_binding_required() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var record: Dictionary = _production_transport_record()
	record["digest"] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var rejected: Dictionary = contract.call(
		"apply_native_result", true, "ACCOUNT_BOUND_SNAPSHOT_READY", JSON.stringify(record), OWNER
	)
	_expect(rejected.get("ok") == false and rejected.get("code") == "SNAPSHOT_DIGEST_MISMATCH",
		"Full eight-domain draft remains bound to canonical digest")


func _test_endpoint_not_enabled_is_non_destructive() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var unavailable: Dictionary = contract.call(
		"apply_native_result", false, "CALLABLE_NOT_FOUND", "", OWNER
	)
	_expect(unavailable.get("ok") == false and unavailable.get("state") == "ENDPOINT_NOT_ENABLED",
		"Undeployed endpoint is represented explicitly, not as restore success")
	var safe: Dictionary = contract.call("get_safe_status")
	_expect(safe.get("internal_handoff_available") == false,
		"Undeployed endpoint produces no raw handoff")
	_expect(safe.get("restore_allowed") == false and safe.get("cloud_mutation_enabled") == false,
		"Undeployed endpoint never widens authority")


func _test_unknown_native_status_fails_closed() -> void:
	contract.call("discard")
	contract.call("begin_manual_request", OWNER)
	var rejected: Dictionary = contract.call(
		"apply_native_result", false, "SOMETHING_NEW_FROM_SERVER", "", OWNER
	)
	_expect(rejected.get("ok") == false and rejected.get("state") == "ERROR_FAIL_CLOSED",
		"Unknown native/server status fails closed")
	_expect(contract.call("get_safe_status").get("internal_handoff_available") == false,
		"Unknown status retains no sensitive transport")


func _production_transport_json() -> String:
	var record: Dictionary = _production_transport_record()
	return JSON.stringify(record) if not record.is_empty() else ""


func _production_transport_record() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {}
	var record: Dictionary = (parsed as Dictionary).duplicate(true)
	record.erase("qaOnly")
	record["code"] = "ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY"
	return record


func _environment_armed() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_ACCOUNT_BOUND_READ_CLIENT_CONTRACT_TEST_ONLY") == "1"
		and OS.get_environment("JADE_ACCOUNT_BOUND_READ_CLIENT_CONTRACT_ACK") == "DISPOSABLE_RUNNER_ONLY"
	)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
		return
	failures += 1
	push_error("FAIL: " + label)


func _finish() -> void:
	print("JADE_ACCOUNT_BOUND_READ_CLIENT_CONTRACT_QA_TOTAL: %d checks; %d failures" % [checks, failures])
	if failures == 0:
		print("JADE_ACCOUNT_BOUND_READ_CLIENT_CONTRACT_QA_PASS")
		quit(0)
		return
	quit(1)
