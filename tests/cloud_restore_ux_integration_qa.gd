extends SceneTree

## Subphase E3B disposable-runner UI integration QA.
## Exercises real Godot Control/Button state around the locked E3A presenter.
## No E1/E2 invocation, disk I/O, network, native bridge, or restore engine.

const SURFACE_PATH: String = "res://scripts/ui/cloud_restore_ux_surface_qa.gd"
const REVIEW_ID: String = "1111111111111111111111111111111111111111111111111111111111111111"
const LOCAL_FINGERPRINT: String = "2222222222222222222222222222222222222222222222222222222222222222"
const REMOTE_DIGEST: String = "3333333333333333333333333333333333333333333333333333333333333333"
const REMOTE_REVISION: int = 31

var checks: int = 0
var failures: int = 0
var commands: Array[Dictionary] = []
var surface: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("Restore UX integration QA requires disposable-runner gates.")
		quit(2)
		return
	var surface_script: Script = load(SURFACE_PATH) as Script
	_expect(surface_script != null, "E3B surface script loads")
	if surface_script == null:
		_finish()
		return
	surface = surface_script.new() as Control
	_expect(surface != null, "E3B surface constructs as Control")
	if surface == null:
		_finish()
		return
	root.add_child(surface)
	surface.command_requested.connect(_on_command_requested)

	_test_review_rendering()
	_test_restore_requires_second_confirmation()
	_test_pending_restore_cannot_be_dismissed()
	_test_keep_local_command()
	_test_issue_state_blocks_restore()
	_test_fail_closed_review()
	_finish()


func _test_review_rendering() -> void:
	commands.clear()
	var presented: Dictionary = surface.call("present_review_for_qa", _review_fixture(), "en")
	_expect(presented.get("ok") == true, "Safe E1 review enters E3B surface")
	var shown: Dictionary = surface.call("show_surface_for_qa")
	_expect(shown.get("ok") == true and shown.get("surface_visible") == true,
		"Restore review surface opens explicitly")
	var snap: Dictionary = _snapshot()
	_expect(snap.get("state") == "REVIEW_READY", "Surface renders REVIEW_READY")
	_expect(str(snap.get("headline", "")).contains("Review"), "Headline comes from E3A safe view")
	_expect(str(snap.get("metadata", "")).contains("cont…wner"), "Only masked owner is rendered")
	_expect(str(snap.get("metadata", "")).contains("Revision 31"), "Reviewed revision is rendered")
	_expect(not str(snap.get("metadata", "")).contains(REMOTE_DIGEST), "Full remote digest is never rendered")
	_expect((snap.get("domain_texts", []) as Array).size() == 8, "Exactly eight permanent domain rows render")
	_expect(snap.get("keep_local_visible") == true, "KEEP LOCAL is visible at review")
	_expect(snap.get("restore_cloud_visible") == true, "RESTORE CLOUD is visible for safe changed state")
	_expect(snap.get("restore_cloud_disabled") == false, "Safe changed state enables restore choice")
	_expect(snap.get("raw_payload_included") == false, "Control snapshot declares no raw payload")
	_expect(snap.get("production_execution_allowed") == false, "UI cannot authorize production execution")
	var serialized: String = JSON.stringify(snap)
	_expect(REVIEW_ID not in serialized, "Opaque review id is not rendered")
	_expect(LOCAL_FINGERPRINT not in serialized, "Local fingerprint is not rendered")
	_expect(REMOTE_DIGEST not in serialized, "Full digest is not rendered")
	_expect(str(snap.get("timestamp_note", "")).contains("informational only"),
		"Timestamp is explicitly informational")


func _test_restore_requires_second_confirmation() -> void:
	commands.clear()
	_surface_button("RestoreCloudButton").pressed.emit()
	_expect(commands.is_empty(), "First RESTORE CLOUD tap emits no command")
	var confirmation: Dictionary = _snapshot()
	_expect(confirmation.get("state") == "RESTORE_CONFIRMATION_REQUIRED",
		"First restore tap enters explicit second-stage confirmation")
	_expect(confirmation.get("cancel_confirmation_visible") == true,
		"Confirmation surface exposes CANCEL")
	_expect(confirmation.get("confirm_restore_visible") == true,
		"Confirmation surface exposes CONFIRM RESTORE")
	_expect(confirmation.get("close_visible") == false,
		"Confirmation cannot be dismissed around the decision")

	_surface_button("ConfirmRestoreButton").pressed.emit()
	_expect(commands.size() == 1, "Second explicit confirm emits exactly one command")
	var command: Dictionary = commands[0]
	_expect(command.get("action") == "SUBMIT_REVIEW_DECISION", "Command is a reviewed decision")
	_expect(command.get("decision") == "RESTORE_CLOUD", "Command requests RESTORE_CLOUD")
	_expect(command.get("review_id") == REVIEW_ID, "Command binds exact opaque review id")
	_expect(command.get("remote_revision") == REMOTE_REVISION, "Command binds reviewed revision")
	_expect(command.get("remote_digest") == REMOTE_DIGEST, "Command binds reviewed digest")
	_expect(command.get("mutation_requested") == true, "Only second confirm requests restore mutation")
	_expect(command.get("production_execution_allowed") == false,
		"Emitted command still cannot authorize production execution")
	var executing: Dictionary = _snapshot()
	_expect(executing.get("state") == "EXECUTING", "Surface enters EXECUTING after command emission")
	_expect(executing.get("close_visible") == false, "Executing state cannot be dismissed")


func _test_pending_restore_cannot_be_dismissed() -> void:
	var applied: Dictionary = surface.call("apply_execution_result_for_qa", _applied_result())
	_expect(applied.get("ok") == true and applied.get("state") == "APPLIED_PENDING_CONFIRMATION",
		"Bound E2-style result enters APPLIED_PENDING_CONFIRMATION")
	var pending: Dictionary = _snapshot()
	_expect(pending.get("keep_restored_visible") == true, "Pending state offers KEEP RESTORED")
	_expect(pending.get("rollback_visible") == true, "Pending state offers ROLL BACK")
	_expect(pending.get("close_visible") == false, "Pending restore cannot be silently dismissed")
	var dismiss: Dictionary = surface.call("hide_surface_for_qa")
	_expect(dismiss.get("ok") == false and dismiss.get("code") == "RESTORE_UX_INTEGRATION_DISMISS_BLOCKED",
		"Programmatic dismissal is fail-closed while restore is unresolved")
	_expect(surface.visible == true, "Blocked dismissal leaves the modal visible")

	commands.clear()
	_surface_button("RollbackButton").pressed.emit()
	_expect(commands.size() == 1, "Explicit rollback emits exactly one resolution command")
	var rollback_command: Dictionary = commands[0]
	_expect(rollback_command.get("action") == "RESOLVE_APPLIED_RESTORE",
		"Rollback command uses terminal resolution action")
	_expect(rollback_command.get("resolution") == "ROLLBACK", "Rollback maps to ROLLBACK")
	_expect(rollback_command.get("review_id") == REVIEW_ID, "Rollback remains bound to review")
	var rolled_back: Dictionary = surface.call("apply_resolution_result_for_qa", _resolution_result("ROLLBACK"))
	_expect(rolled_back.get("ok") == true and rolled_back.get("state") == "USER_ROLLED_BACK",
		"Bound rollback result reaches USER_ROLLED_BACK")
	var terminal: Dictionary = _snapshot()
	_expect(terminal.get("close_visible") == true, "Terminal rollback state may be dismissed")
	_expect(surface.call("hide_surface_for_qa").get("ok") == true, "Terminal surface closes explicitly")


func _test_keep_local_command() -> void:
	_reset_surface()
	commands.clear()
	surface.call("present_review_for_qa", _review_fixture(), "id")
	surface.call("show_surface_for_qa")
	var id_snap: Dictionary = _snapshot()
	_expect(str(id_snap.get("timestamp_note", "")).contains("hanya informasi"),
		"Indonesian surface preserves informational timestamp warning")
	_surface_button("KeepLocalButton").pressed.emit()
	_expect(commands.size() == 1, "KEEP LOCAL emits one explicit decision command")
	var command: Dictionary = commands[0]
	_expect(command.get("decision") == "KEEP_LOCAL", "KEEP LOCAL command is explicit")
	_expect(command.get("mutation_requested") == false, "KEEP LOCAL requests no mutation")
	_expect(command.get("production_execution_allowed") == false,
		"KEEP LOCAL command also has no production authority")
	var complete: Dictionary = surface.call("apply_execution_result_for_qa", _keep_local_result())
	_expect(complete.get("ok") == true and complete.get("state") == "USER_CHOSE_KEEP_LOCAL",
		"Keep-local result reaches terminal user choice")
	_expect(_snapshot().get("close_visible") == true, "Keep-local terminal state is dismissible")


func _test_issue_state_blocks_restore() -> void:
	_reset_surface()
	commands.clear()
	var presented: Dictionary = surface.call("present_review_for_qa", _review_fixture(true), "en")
	_expect(presented.get("ok") == true, "Local issue remains reviewable")
	surface.call("show_surface_for_qa")
	var snap: Dictionary = _snapshot()
	_expect(snap.get("state") == "REVIEW_READY", "Issue state still renders review")
	_expect(snap.get("keep_local_visible") == true, "Issue state still permits KEEP LOCAL")
	_expect(snap.get("restore_cloud_visible") == false or snap.get("restore_cloud_disabled") == true,
		"Local issue blocks cloud restore choice")
	_expect(str(snap.get("summary", "")).contains("Local issues 1"),
		"UI surfaces safe local issue count without raw values")


func _test_fail_closed_review() -> void:
	_reset_surface()
	var unsafe: Dictionary = _review_fixture()
	unsafe["owner_uid"] = "raw-owner-must-never-render"
	var rejected: Dictionary = surface.call("present_review_for_qa", unsafe, "en")
	_expect(rejected.get("ok") == false, "Raw identity field is rejected by locked presenter")
	surface.call("show_surface_for_qa")
	var snap: Dictionary = _snapshot()
	_expect(snap.get("state") == "ERROR_FAIL_CLOSED", "Unsafe review renders fail-closed state")
	_expect("raw-owner-must-never-render" not in JSON.stringify(snap), "Rejected raw owner never appears in controls")
	_expect(snap.get("restore_cloud_visible") == false, "Fail-closed surface exposes no restore action")


func _reset_surface() -> void:
	if surface != null and is_instance_valid(surface):
		surface.queue_free()
	var surface_script: Script = load(SURFACE_PATH) as Script
	surface = surface_script.new() as Control
	root.add_child(surface)
	surface.command_requested.connect(_on_command_requested)


func _surface_button(node_name: String) -> Button:
	return surface.find_child(node_name, true, false) as Button


func _snapshot() -> Dictionary:
	var result: Dictionary = surface.call("get_control_snapshot_for_qa")
	_expect(result.get("ok") == true, "Control snapshot remains available")
	return result


func _on_command_requested(command: Dictionary) -> void:
	commands.append(command.duplicate(true))


func _review_fixture(with_issue: bool = false) -> Dictionary:
	var states: Dictionary = {
		"achievements": "SAME",
		"daily_quests": "DIFFERENT",
		"equipment": "SAME",
		"idle_cultivation": "DIFFERENT",
		"inventory": "SAME",
		"journey": "DIFFERENT",
		"pavilion": "SAME",
		"progression": "DIFFERENT",
	}
	var same_count: int = 4
	var changed_count: int = 4
	var local_issue_count: int = 0
	var source_ready: bool = true
	if with_issue:
		states["journey"] = "LOCAL_INVALID"
		changed_count = 3
		local_issue_count = 1
		source_ready = false
	return {
		"ok": true,
		"code": "RESTORE_REVIEW_READY",
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"execution_allowed": false,
		"owner_verified": true,
		"owner_display": "cont…wner",
		"remote_revision": REMOTE_REVISION,
		"remote_digest": REMOTE_DIGEST,
		"captured_at_unix": 1700001234,
		"domain_count": 8,
		"domain_states": states,
		"same_count": same_count,
		"changed_count": changed_count,
		"local_issue_count": local_issue_count,
		"local_state_fingerprint": LOCAL_FINGERPRINT,
		"review_id": REVIEW_ID,
		"decision_required": true,
		"decision_options": ["KEEP_LOCAL", "RESTORE_CLOUD"],
		"preimage_backup_required": true,
		"preimage_source_files_ready": source_ready,
		"preimage_runtime_guards_checked": false,
		"execution_preconditions_met": false,
		"raw_payload_included": false,
	}


func _base_bound_result() -> Dictionary:
	return {
		"ok": true,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
		"review_id": REVIEW_ID,
		"remote_revision": REMOTE_REVISION,
		"remote_digest": REMOTE_DIGEST,
	}


func _keep_local_result() -> Dictionary:
	var result: Dictionary = _base_bound_result()
	result.merge({
		"code": "RESTORE_DECISION_KEEP_LOCAL",
		"decision": "KEEP_LOCAL",
		"mutation_performed": false,
		"confirmation_required": false,
		"qa_execution_performed": false,
	})
	return result


func _applied_result() -> Dictionary:
	var result: Dictionary = _base_bound_result()
	result.merge({
		"code": "RESTORE_EXECUTION_APPLIED_PENDING_CONFIRMATION",
		"decision": "RESTORE_CLOUD",
		"domain_count": 8,
		"phase": "APPLIED_PENDING_CONFIRMATION",
		"mutation_performed": true,
		"qa_execution_performed": true,
		"confirmation_required": true,
		"preimage_backup_ready": true,
		"write_barrier_retained": true,
	})
	return result


func _resolution_result(resolution: String) -> Dictionary:
	var result: Dictionary = _base_bound_result()
	var confirmed: bool = resolution == "CONFIRM"
	result.merge({
		"code": "RESTORE_EXECUTION_CONFIRMED" if confirmed else "RESTORE_EXECUTION_ROLLED_BACK",
		"resolution": resolution,
		"phase": "CONFIRMED" if confirmed else "ROLLED_BACK",
		"confirmation_required": false,
		"already_terminal": false,
		"vault_retained": true,
		"qa_execution_performed": true,
	})
	return result


func _environment_armed() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_RESTORE_UX_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_UX_ACK") == "DISPOSABLE_RUNNER_ONLY"
		and OS.get_environment("JADE_RESTORE_UX_INTEGRATION_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_UX_INTEGRATION_ACK") == "DISPOSABLE_RUNNER_ONLY"
	)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
		return
	failures += 1
	push_error("FAIL: " + label)


func _finish() -> void:
	print("JADE_CLOUD_RESTORE_UX_INTEGRATION_QA_TOTAL: %d checks; %d failures" % [checks, failures])
	if failures == 0:
		print("JADE_CLOUD_RESTORE_UX_INTEGRATION_QA_PASS")
		quit(0)
		return
	quit(1)
