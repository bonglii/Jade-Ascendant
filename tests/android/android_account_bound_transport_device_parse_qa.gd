extends SceneTree

const STAGER: String = "res://scripts/managers/cloud_account_bound_android_candidate_stager_qa.gd"
const RUNNER: String = "res://tests/android/android_account_bound_transport_device_qa.gd"
const SCENE: String = "res://tests/android/android_account_bound_transport_device_qa.tscn"
const STUB: String = "res://tests/android/android_account_bound_transport_external_services_stub_qa.gd"


func _initialize() -> void:
	var failures: int = 0
	for path in [STAGER, RUNNER, SCENE, STUB]:
		var resource: Resource = load(path)
		if resource == null:
			failures += 1
			push_error("ANDROID_ACCOUNT_BOUND_PARSE_FAIL | " + path)
	if failures == 0:
		print("JADE_ANDROID_ACCOUNT_BOUND_TRANSPORT_PARSE_PASS")
	quit(0 if failures == 0 else 1)
