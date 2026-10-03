extends Node

## Physical Android DEBUG proof for the account-bound transport boundary.
## A debug-only native plugin emits one immutable reviewed QA transport record.
## E3C-B requires those native bytes to pass the locked E3C-A production-shaped
## client contract before a one-shot internal handoff may reach the existing
## isolated candidate stager. This runner NEVER invokes restore.

const ClientContractScript = preload(
	"res://scripts/managers/cloud_account_bound_read_client_contract.gd"
)
const StagerScript = preload(
	"res://scripts/managers/cloud_account_bound_android_candidate_stager_qa.gd"
)

const EXPECTED_HEAD_SHA: String = "QA_HEAD_SHA_PLACEHOLDER"
const OWNER: String = "account_bound_android_debug_owner"
const EXPECTED_REVISION: int = 2
const EXPECTED_JADE: int = 144
const EXPECTED_DOMAIN_COUNT: int = 8
const NATIVE_SINGLETON: String = "JadeAccountBoundTransportDebugBridge"
const NATIVE_METHOD: String = "requestQaAccountBoundTransport"
const NATIVE_SIGNAL: StringName = &"accountBoundTransportQaResult"
const QA_FEATURE: String = "jade_android_account_bound_transport_qa"
const QA_MAIN_SCENE: String = "res://tests/android/android_account_bound_transport_device_qa.tscn"
const TIMEOUT_SECONDS: float = 20.0
const SIDECARS = [
	"", ".backup", ".rollback", ".tmp", ".restore.tmp", ".restore.rollback",
	".restore.recovery.tmp", ".restore.recovery.discard",
]

var _checks: int = 0
var _failures: int = 0
var _client_contract: RefCounted
var _stager: RefCounted
var _before_live: Dictionary = {}
var _completed: bool = false


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		_fail_closed("environment", "QA Android/debug/export feature/main scene gate missing")
		return
	if EXPECTED_HEAD_SHA == "QA_HEAD_SHA_PLACEHOLDER" or EXPECTED_HEAD_SHA.length() != 40:
		_fail_closed("head", "HEAD_SHA_UNBOUND")
		return
	_client_contract = ClientContractScript.new() as RefCounted
	_stager = StagerScript.new() as RefCounted
	if _client_contract == null:
		_fail_closed("client_contract", "E3C-A client contract did not construct")
		return
	if _stager == null:
		_fail_closed("stager", "candidate stager did not construct")
		return
	_expect(_reset_candidate_namespace(), "candidate namespace starts clean")
	_before_live = _registered_live_fingerprints()
	_expect(_before_live.size() == EXPECTED_DOMAIN_COUNT, "exact eight permanent registered paths fingerprinted")

	var request: Dictionary = _client_contract.call("begin_manual_request", OWNER)
	_expect(request.get("ok") == true, "E3C-A manual account-bound request arms on device")
	_expect(
		request.get("action") == "REQUEST_ACCOUNT_BOUND_CURRENT_SNAPSHOT",
		"E3C-A emits fixed account-bound read action"
	)
	var client_payload: Variant = request.get("client_payload", null)
	_expect(
		client_payload is Dictionary and (client_payload as Dictionary).is_empty(),
		"E3C-A device request carries exactly empty caller payload"
	)
	_expect(request.get("owner_argument_included") == false, "owner UID is not a caller-controlled native argument")
	_expect(request.get("automatic_request") == false, "account-bound read is never automatic")
	_expect(request.get("explicit_user_action_required") == true, "account-bound read remains explicit-user-action only")
	_expect(request.get("restore_allowed") == false, "request contract never authorizes restore")
	_expect(request.get("cloud_mutation_enabled") == false, "request contract never enables cloud mutation")
	if _failures != 0:
		_finish()
		return

	if not Engine.has_singleton(NATIVE_SINGLETON):
		_fail_closed("native", "DEBUG_NATIVE_SINGLETON_MISSING")
		return
	var native: Object = Engine.get_singleton(NATIVE_SINGLETON)
	if native == null or not native.has_method("has_java_method"):
		_fail_closed("native", "NATIVE_INTROSPECTION_UNAVAILABLE")
		return
	if not bool(native.call("has_java_method", NATIVE_METHOD)):
		_fail_closed("native", "NATIVE_TRANSPORT_METHOD_MISSING")
		return
	if not native.has_signal(NATIVE_SIGNAL):
		_fail_closed("native", "NATIVE_TRANSPORT_SIGNAL_MISSING")
		return
	var callback: Callable = Callable(self, "_on_native_result")
	if not native.is_connected(NATIVE_SIGNAL, callback):
		native.connect(NATIVE_SIGNAL, callback)
	print("JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_ARMED | head=", EXPECTED_HEAD_SHA)
	get_tree().create_timer(TIMEOUT_SECONDS).timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
	native.call(NATIVE_METHOD)


func _on_native_result(success: bool, status: String, transport_json: String) -> void:
	if _completed:
		return
	_expect(success, "native debug bridge returned success")
	_expect(status == "QA_TRANSPORT_FIXTURE_READY", "native status is exact reviewed-fixture marker")
	_expect(not transport_json.is_empty(), "native bridge delivered transport bytes")
	if _failures != 0:
		_finish()
		return

	# The immutable native fixture predates E3C-A and carries a QA-only envelope.
	# Normalize ONLY its envelope in this disposable runner. Snapshot bytes, owner,
	# revision, digest and domains are unchanged before E3C-A validates them.
	var production_contract_json: String = _normalize_debug_fixture_for_e3ca(transport_json)
	_expect(not production_contract_json.is_empty(), "debug fixture normalizes to exact E3C-A production-shaped envelope")
	if production_contract_json.is_empty():
		_finish()
		return

	var accepted: Dictionary = _client_contract.call(
		"apply_native_result",
		true,
		"ACCOUNT_BOUND_SNAPSHOT_READY",
		production_contract_json,
		OWNER
	)
	_expect(
		accepted.get("ok") == true and accepted.get("state") == "READY_FOR_REVIEW",
		"native bytes pass locked E3C-A validation before any candidate staging"
	)
	_expect(accepted.get("restore_allowed") == false, "validated native result still cannot authorize restore")
	_expect(accepted.get("cloud_mutation_enabled") == false, "validated native result still cannot mutate cloud")
	if not bool(accepted.get("ok", false)):
		_finish()
		return

	var safe_status: Dictionary = _client_contract.call("get_safe_status")
	var safe_summary: Dictionary = safe_status.get("safe_summary", {})
	var safe_serialized: String = JSON.stringify(safe_status)
	_expect(safe_status.get("state") == "READY_FOR_REVIEW", "E3C-A safe status reaches READY_FOR_REVIEW on device")
	_expect(safe_status.get("raw_payload_included") == false, "safe status exposes no raw transport payload")
	_expect(int(safe_summary.get("remote_revision", 0)) == EXPECTED_REVISION, "safe summary exposes reviewed revision only")
	_expect(int(safe_summary.get("domain_count", 0)) == EXPECTED_DOMAIN_COUNT, "safe summary exposes exact eight-domain count")
	_expect(str(safe_summary.get("owner_display", "")) != OWNER, "safe summary masks authenticated owner")
	_expect(OWNER not in safe_serialized, "raw owner never appears in safe status")
	_expect("celestial_jade" not in safe_serialized, "gameplay payload never appears in safe status")
	_expect("domains" not in safe_serialized, "domain payload map never appears in safe status")
	_expect(safe_summary.get("restore_allowed") == false, "safe summary remains restore-disabled")
	_expect(safe_summary.get("cloud_mutation_enabled") == false, "safe summary remains cloud-mutation-disabled")
	_expect(safe_summary.get("production_execution_allowed") == false, "safe summary grants no production execution authority")

	var handoff: Dictionary = _client_contract.call(
		"take_validated_transport_for_internal_handoff", OWNER
	)
	_expect(handoff.get("ok") == true, "validated transport is available through explicit internal handoff")
	_expect(handoff.get("one_shot") == true, "raw transport handoff is explicitly one-shot")
	_expect(handoff.get("internal_only") == true and handoff.get("ui_safe") == false, "raw handoff is internal-only and never UI-safe")
	_expect(handoff.get("restore_allowed") == false, "one-shot handoff still cannot authorize restore")
	_expect(handoff.get("cloud_mutation_enabled") == false, "one-shot handoff still cannot mutate cloud")
	var second_handoff: Dictionary = _client_contract.call(
		"take_validated_transport_for_internal_handoff", OWNER
	)
	_expect(
		second_handoff.get("ok") == false
		and second_handoff.get("code") == "ACCOUNT_BOUND_READ_HANDOFF_NOT_AVAILABLE",
		"second raw handoff is rejected on device"
	)
	if not bool(handoff.get("ok", false)):
		_finish()
		return

	# Existing Android candidate stager is PASS / LOCKED and consumes the older QA
	# envelope. Adapt ONLY after E3C-A has already validated + one-shot handed off
	# the production-shaped record. The original native JSON is never staged.
	var handoff_transport_json: String = _handoff_to_locked_stager_json(handoff)
	_expect(not handoff_transport_json.is_empty(), "E3C-A handoff converts to locked stager QA envelope")
	if handoff_transport_json.is_empty():
		_finish()
		return

	var staged: Dictionary = _stager.call(
		"stage_transport_json_for_device_qa", handoff_transport_json, OWNER
	)
	_expect(
		staged.get("ok") == true
		and staged.get("code") == "ANDROID_ACCOUNT_BOUND_CANDIDATES_READY",
		"E3C-A one-shot handoff becomes isolated durable candidates"
	)
	_expect(staged.get("domain_count") == EXPECTED_DOMAIN_COUNT, "candidate set contains exact eight domains")
	_expect(staged.get("remote_revision") == EXPECTED_REVISION, "candidate manifest retains exact remote revision")
	_expect(staged.get("restore_allowed") == false, "candidate staging never authorizes restore")
	_expect(staged.get("cloud_mutation_enabled") == false, "candidate staging never enables cloud mutation")
	_expect(staged.get("explicit_decision_required") == true, "explicit restore decision remains required")
	_expect(_registered_live_fingerprints() == _before_live, "candidate staging mutates zero registered primaries or sidecars")
	if not bool(staged.get("ok", false)):
		_finish()
		return

	var ready: Dictionary = _stager.call(
		"inspect_ready_for_device_qa", str(staged.get("ready_path", "")), OWNER
	)
	_expect(ready.get("ok") == true, "ready candidate set reopens and validates")
	_expect(ready.get("domain_count") == EXPECTED_DOMAIN_COUNT, "reopened ready set keeps exact domain count")
	_expect(ready.get("remote_revision") == EXPECTED_REVISION, "reopened ready set keeps exact revision")
	_expect(ready.get("remote_digest") == staged.get("remote_digest"), "reopened ready set keeps exact digest")
	_expect(_pavilion_candidate_has_expected_jade(ready), "Pavilion candidate payload matches reviewed fixture")
	_expect(_registered_live_fingerprints() == _before_live, "ready-set inspection still mutates zero registered save state")
	_expect(_reset_candidate_namespace(), "disposable candidate namespace cleans up")
	_expect(_registered_live_fingerprints() == _before_live, "cleanup leaves registered save state byte-identical")
	_finish()


func _normalize_debug_fixture_for_e3ca(transport_json: String) -> String:
	var parsed: Variant = JSON.parse_string(transport_json)
	if not (parsed is Dictionary):
		return ""
	var record: Dictionary = (parsed as Dictionary).duplicate(true)
	if record.get("qaOnly") != true:
		return ""
	if str(record.get("code", "")) != "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY":
		return ""
	record.erase("qaOnly")
	record["code"] = "ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY"
	return JSON.stringify(record)


func _handoff_to_locked_stager_json(handoff: Dictionary) -> String:
	var raw_transport: Variant = handoff.get("transport", null)
	if not (raw_transport is Dictionary):
		return ""
	var transport: Dictionary = (raw_transport as Dictionary).duplicate(true)
	if str(transport.get("code", "")) != "ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY":
		return ""
	if transport.get("restore_allowed") != false or transport.get("cloud_mutation_enabled") != false:
		return ""
	transport["code"] = "QA_ACCOUNT_BOUND_CURRENT_SNAPSHOT_READY"
	transport["qaOnly"] = true
	return JSON.stringify(transport)


func _on_timeout() -> void:
	if _completed:
		return
	_fail_closed("timeout", "native transport callback timeout")


func _pavilion_candidate_has_expected_jade(ready: Dictionary) -> bool:
	var paths: Dictionary = ready.get("candidate_paths", {})
	var path: String = str(paths.get("pavilion", ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var raw: Variant = file.get_var(false)
	file.close()
	return raw is Dictionary and raw.get("celestial_jade") == EXPECTED_JADE


func _registered_live_fingerprints() -> Dictionary:
	var result: Dictionary = {}
	var ids: Array[String] = []
	for raw_id in SaveManager.get_save_domain_ids_for_scope(SaveManager.SCOPE_PERMANENT):
		ids.append(str(raw_id))
	ids.sort()
	for id in ids:
		var base: String = SaveManager.get_save_path(id)
		var files: Dictionary = {}
		for suffix in SIDECARS:
			var path: String = base + str(suffix)
			files[str(suffix)] = {
				"exists": FileAccess.file_exists(path),
				"sha256": FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "",
			}
		result[id] = files
	return result


func _reset_candidate_namespace() -> bool:
	var path: String = str(_stager.call("qa_root"))
	if not DirAccess.dir_exists_absolute(path):
		return true
	return _remove_tree(path)


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


func _environment_armed() -> bool:
	return (
		OS.get_name() == "Android"
		and OS.is_debug_build()
		and OS.has_feature(QA_FEATURE)
		and str(ProjectSettings.get_setting("application/run/main_scene", "")) == QA_MAIN_SCENE
	)


func _expect(value: bool, note: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_CHECK_FAIL | " + note)


func _fail_closed(stage: String, message: String) -> void:
	if _completed:
		return
	_failures += 1
	push_error(
		"JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_FAIL | stage="
		+ stage + " | " + message
	)
	_finish()


func _finish() -> void:
	if _completed:
		return
	_completed = true
	print(
		"JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_QA_TOTAL: ",
		_checks, " checks; ", _failures, " failures"
	)
	if _failures == 0:
		print(
			"JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_E3CB_CONTRACT_PASS | head=",
			EXPECTED_HEAD_SHA,
			" | client_contract=E3C-A | one_shot=true"
		)
		print(
			"JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS | head=",
			EXPECTED_HEAD_SHA,
			" | domains=", EXPECTED_DOMAIN_COUNT,
			" | revision=", EXPECTED_REVISION
		)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0 if _failures == 0 else 1)
