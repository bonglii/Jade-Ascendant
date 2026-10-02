extends Node

## Disposable Android-debug startup fence for destructive restore QA.
## This file lives under tests/ (excluded by the production export preset) and
## is injected as an autoload only inside the temporary QA workspace.

const OWNER_ID: String = "registered_restore_bootstrap_qa"
const ACTIVE_TX: String = "user://jade_registered_restore_qa/tx/active"
const CONFIRMED_MARKER: String = ACTIVE_TX + "/confirmed.marker"
const ROLLED_BACK_MARKER: String = ACTIVE_TX + "/rolled_back.marker"
const QA_EXPORT_FEATURE: String = "jade_android_restore_qa"
const QA_MAIN_SCENE: String = "res://tests/android/android_restore_device_qa.tscn"


func _ready() -> void:
	if not _qa_enabled():
		return
	if not DirAccess.dir_exists_absolute(ACTIVE_TX):
		return
	if FileAccess.file_exists(CONFIRMED_MARKER) or FileAccess.file_exists(ROLLED_BACK_MARKER):
		return
	if SaveManager.is_save_write_barrier_active():
		if SaveManager.get_save_write_barrier_owner() == OWNER_ID:
			return
		_fail_closed("another write barrier is already active")
		return
	var acquired: Dictionary = SaveManager.begin_save_write_barrier(
		OWNER_ID, "android_restore_device_qa_boot_recovery"
	)
	if not bool(acquired.get("success", false)):
		_fail_closed(
			"could not acquire startup barrier: "
			+ str(acquired.get("code", "UNKNOWN"))
		)
		return
	print("JADE_ANDROID_RESTORE_BOOT_BARRIER_ARMED")


func _qa_enabled() -> bool:
	return (
		OS.has_feature("android")
		and OS.is_debug_build()
		and OS.has_feature(QA_EXPORT_FEATURE)
		and str(ProjectSettings.get_setting("application/run/main_scene", "")) == QA_MAIN_SCENE
	)


func _fail_closed(message: String) -> void:
	push_error("JADE_ANDROID_RESTORE_DEVICE_FAIL | bootstrap | " + message)
	get_tree().quit(97)
