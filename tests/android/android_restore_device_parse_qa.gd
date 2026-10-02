extends SceneTree

const FILES: Array[String] = [
	"res://tests/android/android_restore_device_qa.gd",
	"res://tests/android/android_restore_device_bootstrap_qa.gd",
	"res://tests/android/android_restore_external_services_stub_qa.gd",
	"res://tests/android/android_restore_device_qa.tscn",
]


func _initialize() -> void:
	for path in FILES:
		var resource: Resource = load(path)
		if resource == null:
			push_error("ANDROID_RESTORE_DEVICE_PARSE_FAIL | " + path)
			quit(1)
			return
	print("JADE_ANDROID_RESTORE_DEVICE_PARSE_PASS")
	quit(0)
