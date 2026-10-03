extends Node

## Physical Android DEBUG proof for the account-bound transport boundary.
## A debug-only native plugin emits one immutable reviewed QA transport record;
## this runner validates it again and stages eight candidate files under an
## isolated package-specific QA namespace. It NEVER invokes restore.

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
	_stager = StagerScript.new() as RefCounted
	if _stager == null:
		_fail_closed("stager", "candidate stager did not construct")
		return
	_expect(_reset_candidate_namespace(), "candidate namespace starts clean")
	_before_live = _registered_live_fingerprints()
	_expect(_before_live.size() == EXPECTED_DOMAIN_COUNT, "exact eight permanent registered paths fingerprinted")
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

	var staged: Dictionary = _stager.call(
		"stage_transport_json_for_device_qa", transport_json, OWNER
	)
	_expect(
		staged.get("ok") == true
		and staged.get("code") == "ANDROID_ACCOUNT_BOUND_CANDIDATES_READY",
		"reviewed native record becomes isolated durable candidates"
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
			"JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_DEVICE_PASS | head=",
			EXPECTED_HEAD_SHA,
			" | domains=", EXPECTED_DOMAIN_COUNT,
			" | revision=", EXPECTED_REVISION
		)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0 if _failures == 0 else 1)
