extends SceneTree

## Gate 9B runtime-only write barrier and process-restart QA.
## Runs only on an ephemeral CI runner. It never authorizes restore or cloud I/O.
const QA_ROOT: String = "user://jade_gate9b_qa"
const MARKER_PATH: String = QA_ROOT + "/armed.marker"
const OWNER: String = "gate9b_ci_owner"
const SECOND_OWNER: String = "gate9b_other_owner"
var checks: int = 0
var failures: int = 0
var saver: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("JADE_GATE9_TEST_ONLY") != "1":
		push_error("Gate 9B QA requires isolated CI environment.")
		quit(2)
		return
	saver = root.get_node_or_null("SaveManager")
	if saver == null:
		push_error("Gate 9B QA requires SaveManager autoload.")
		quit(2)
		return
	var stage: String = OS.get_environment("JADE_GATE9B_STAGE")
	if stage == "arm":
		_run_arm_stage()
	elif stage == "verify":
		_run_verify_stage()
	else:
		push_error("Unknown Gate 9B stage: " + stage)
		quit(2)


func _run_arm_stage() -> void:
	_expect(not bool(saver.call("is_save_write_barrier_active")),
		"Barrier starts inactive")
	var acquired: Dictionary = saver.call(
		"begin_save_write_barrier", OWNER, "gate9b_crash_probe"
	)
	_expect(acquired.get("success") == true, "Owner acquires global barrier")
	_expect(acquired.get("code") == "WRITE_BARRIER_ACQUIRED", "Acquire code is explicit")
	_expect(bool(saver.call("is_save_write_barrier_active")), "Barrier reports active")
	_expect(str(saver.call("get_save_write_barrier_owner")) == OWNER, "Barrier owner is exact")
	_expect(bool(saver.call("is_progress_read_only")), "Progress becomes read-only while barrier active")

	var competing: Dictionary = saver.call(
		"begin_save_write_barrier", SECOND_OWNER, "should_not_enter"
	)
	_expect(competing.get("success") == false, "Second owner cannot acquire barrier")
	_expect(competing.get("code") == "WRITE_BARRIER_ALREADY_ACTIVE", "Concurrent barrier fails closed")

	var progression_path: String = str(saver.call("get_save_path", "progression"))
	var checkpoint_path: String = str(saver.call("get_save_path", "checkpoint"))
	var journal_path: String = "user://transaction.journal"
	var before_progression := _fingerprint(progression_path)
	var before_checkpoint := _fingerprint(checkpoint_path)
	var before_journal := _fingerprint(journal_path)
	var write_result: Dictionary = saver.call("write_save_data", "progression", {})
	_expect(write_result.get("success") == false, "Single-domain write blocked")
	_expect(write_result.get("code") == "SAVE_WRITE_BARRIER_ACTIVE", "Single write exposes barrier code")
	_expect(not bool(saver.call("write_save_batch", {"progression": {}})), "Batch journal creation blocked")
	var recovery_result: Dictionary = saver.call("recover_save_from_backup", "progression")
	_expect(recovery_result.get("success") == false, "Backup recovery write blocked")
	_expect(recovery_result.get("code") == "SAVE_WRITE_BARRIER_ACTIVE", "Recovery exposes barrier code")
	var delete_result: Dictionary = saver.call("delete_active_run_save", "checkpoint")
	_expect(delete_result.get("success") == false, "Checkpoint deletion blocked")
	_expect(delete_result.get("code") == "SAVE_WRITE_BARRIER_ACTIVE", "Delete exposes barrier code")
	var reset_result: Dictionary = saver.call("reset_active_run_saves")
	_expect(reset_result.get("success") == false, "Active-run reset blocked")
	_expect(reset_result.get("code") == "SAVE_WRITE_BARRIER_ACTIVE", "Reset exposes barrier code")
	_expect(_fingerprint(progression_path) == before_progression, "Blocked write leaves progression bytes untouched")
	_expect(_fingerprint(checkpoint_path) == before_checkpoint, "Blocked delete leaves checkpoint bytes untouched")
	_expect(_fingerprint(journal_path) == before_journal, "Blocked batch leaves transaction journal untouched")

	var wrong_release: Dictionary = saver.call("end_save_write_barrier", SECOND_OWNER)
	_expect(wrong_release.get("success") == false, "Wrong owner cannot release barrier")
	_expect(wrong_release.get("code") == "WRITE_BARRIER_OWNER_MISMATCH", "Release mismatch is explicit")
	_expect(bool(saver.call("is_save_write_barrier_active")), "Wrong release keeps barrier active")

	if DirAccess.make_dir_recursive_absolute(QA_ROOT) != OK:
		_expect(false, "Create Gate 9B QA marker directory")
		_finish("JADE_GATE9_WRITE_BARRIER_ARM_PASS")
		return
	var marker: FileAccess = FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	_expect(marker != null, "Create process-restart marker")
	if marker != null:
		marker.store_string("armed")
		marker.flush()
		marker.close()
	_expect(FileAccess.file_exists(MARKER_PATH), "Restart marker persisted")
	# Intentionally DO NOT release OWNER. Process exit simulates a crash while
	# the in-memory maintenance barrier is held. The next process must recover
	# simply by starting with a fresh runtime barrier state.
	_finish("JADE_GATE9_WRITE_BARRIER_ARM_PASS")


func _run_verify_stage() -> void:
	_expect(FileAccess.file_exists(MARKER_PATH), "Prior process reached armed state")
	_expect(not bool(saver.call("is_save_write_barrier_active")),
		"Fresh process does not inherit stale runtime barrier")
	_expect(str(saver.call("get_save_write_barrier_owner")).is_empty(),
		"Fresh process barrier owner is empty")
	var reacquired: Dictionary = saver.call(
		"begin_save_write_barrier", OWNER, "gate9b_restart_verify"
	)
	_expect(reacquired.get("success") == true, "Fresh process can reacquire barrier")
	var released: Dictionary = saver.call("end_save_write_barrier", OWNER)
	_expect(released.get("success") == true, "Correct owner releases barrier")
	_expect(released.get("code") == "WRITE_BARRIER_RELEASED", "Release code is explicit")
	_expect(not bool(saver.call("is_save_write_barrier_active")), "Barrier inactive after release")
	if FileAccess.file_exists(MARKER_PATH):
		_expect(DirAccess.remove_absolute(MARKER_PATH) == OK, "Remove own QA restart marker")
	_finish("JADE_GATE9_WRITE_BARRIER_RESTART_PASS")


func _fingerprint(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return "missing"
	return "%d:%s" % [FileAccess.get_size(path), FileAccess.get_sha256(path)]


func _expect(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("GATE9B_QA_FAIL | " + note)


func _finish(marker: String) -> void:
	print("JADE_GATE9B_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print(marker)
	quit(0 if failures == 0 else 1)
