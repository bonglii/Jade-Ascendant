extends Node

## CI-only early write fence for registered-path restore restart QA.
## This script is never tracked as an autoload in project.godot. The dedicated
## workflow injects it after SaveManager and before permanent managers only on
## a disposable editor runner. Release/debug exports cannot arm it.

const OWNER_ID: String = "registered_restore_bootstrap_qa"
const ACTIVE_TX: String = "user://jade_registered_restore_qa/tx/active"
const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
const RESTART_STAGES: Array[String] = [
	"rollback_after_restart",
	"confirm_after_restart",
	"recover",
	"recover_fault"
]


func _ready() -> void:
	if not _qa_enabled():
		return
	var stage: String = OS.get_environment("JADE_REGISTERED_RESTORE_STAGE")
	if stage not in RESTART_STAGES:
		return
	if not DirAccess.dir_exists_absolute(ACTIVE_TX):
		return
	if SaveManager.is_save_write_barrier_active():
		if SaveManager.get_save_write_barrier_owner() == OWNER_ID:
			return
		_fail_closed("another write barrier is already active")
		return
	var acquired: Dictionary = SaveManager.begin_save_write_barrier(
		OWNER_ID, "registered_restore_qa_boot_recovery"
	)
	if not bool(acquired.get("success", false)):
		_fail_closed(
			"could not acquire startup write barrier: "
			+ str(acquired.get("code", "UNKNOWN"))
		)
		return
	print("JADE_REGISTERED_BOOT_BARRIER_ARMED | ", stage)


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("JADE_GATE9_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_TEST_ONLY") == "1"
		and OS.get_environment("JADE_REGISTERED_RESTORE_ACK") == REQUIRED_ACK
	)


func _fail_closed(message: String) -> void:
	push_error("REGISTERED_RESTORE_BOOTSTRAP_FAIL | " + message)
	get_tree().quit(97)
