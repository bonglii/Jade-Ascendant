extends SceneTree

## Subphase E3A disposable-runner QA.
## Pure presentation/state sequencing only: no save I/O, restore engine, network,
## native bridge, or production UI wiring.

const PRESENTER_PATH: String = "res://scripts/managers/cloud_restore_ux_presenter_qa.gd"
const REVIEW_ID: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const LOCAL_FINGERPRINT: String = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
const REMOTE_DIGEST: String = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
const REMOTE_REVISION: int = 41

var checks: int = 0
var failures: int = 0
var presenter_script: Script


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _environment_armed():
		push_error("Restore UX presenter QA requires disposable-runner gates.")
		quit(2)
		return
	presenter_script = load(PRESENTER_PATH) as Script
	if presenter_script == null:
		push_error("Restore UX presenter script failed to load.")
		quit(2)
		return

	_test_safe_review_view()
	_test_restore_second_confirmation_and_confirm()
	_test_restore_rollback()
	_test_keep_local()
	_test_restore_choice_guards()
	_test_fail_closed_binding()
	_finish()


func _test_safe_review_view() -> void:
	var presenter: RefCounted = presenter_script.new() as RefCounted
	var initial: Dictionary = presenter.call("get_view_for_qa", "en")
	_expect(initial.get("ok") == true, "Initial presenter view is available")
	_expect((initial.get("view", {}) as Dictionary).get("state") == "NO_CANDIDATE",
		"Initial state is NO_CANDIDATE")

	var review: Dictionary = _review_fixture()
	var presented: Dictionary = presenter.call("present_review_for_qa", review)
	_expect(presented.get("ok") == true, "Safe E1 review is accepted")
	_expect(presented.get("state") == "REVIEW_READY", "Accepted review enters REVIEW_READY")
	_expect(presented.get("restore_choice_available") == true,
		"Clean changed review offers restore choice")

	var en_result: Dictionary = presenter.call("get_view_for_qa", "en")
	var view: Dictionary = en_result.get("view", {}) as Dictionary
	_expect(en_result.get("ok") == true, "English view builds")
	_expect(view.get("owner_display") == "cont…wner", "Only masked owner is shown")
	_expect(view.get("remote_revision") == REMOTE_REVISION, "Remote revision is shown")
	_expect(str(view.get("remote_digest_display", "")).length() < 64,
		"Digest display is abbreviated")
	_expect(view.get("captured_at_unix") == 1700001234,
		"Capture timestamp is informational metadata")
	_expect(view.get("domain_count") == 8, "Exactly eight permanent domains are shown")
	_expect((view.get("domain_rows", []) as Array).size() == 8,
		"View contains eight safe domain rows")
	_expect(view.get("same_count") == 4 and view.get("changed_count") == 4,
		"Safe summary counts are preserved")
	_expect(view.get("local_issue_count") == 0, "Clean review shows no local issue")
	_expect(view.get("restore_choice_available") == true,
		"Restore action is available only on safe changed state")
	_expect(str(view.get("timestamp_note", "")).contains("informational only"),
		"Timestamp copy explicitly stays informational")
	_expect(view.get("raw_payload_included") == false, "View declares no raw payload")
	_expect(view.get("upload_allowed") == false, "View cannot authorize upload")
	_expect(view.get("restore_allowed") == false, "View cannot authorize restore")
	_expect(view.get("cloud_mutation_enabled") == false, "View cannot mutate cloud")
	_expect(view.get("production_execution_allowed") == false,
		"View cannot authorize production execution")
	var serialized: String = JSON.stringify(view)
	_expect(REVIEW_ID not in serialized, "View hides opaque review binding id")
	_expect(LOCAL_FINGERPRINT not in serialized, "View hides local fingerprint")
	_expect(REMOTE_DIGEST not in serialized, "View hides full remote digest")
	_expect("owner_uid" not in serialized and "candidate_paths" not in serialized,
		"View omits raw identity and candidate paths")

	var id_result: Dictionary = presenter.call("get_view_for_qa", "id")
	var id_view: Dictionary = id_result.get("view", {}) as Dictionary
	_expect(str(id_view.get("timestamp_note", "")).contains("hanya informasi"),
		"Indonesian timestamp copy stays informational")
	_expect(presenter.call("get_view_for_qa", "xx").get("code") == "RESTORE_UX_LOCALE_INVALID",
		"Unknown locale is rejected")

	var unsafe: Dictionary = review.duplicate(true)
	unsafe["raw_payload_included"] = true
	var unsafe_presenter: RefCounted = presenter_script.new() as RefCounted
	var unsafe_result: Dictionary = unsafe_presenter.call("present_review_for_qa", unsafe)
	_expect(unsafe_result.get("ok") == false and unsafe_result.get("code") == "RESTORE_UX_REVIEW_UNSAFE_FLAGS",
		"Unsafe review flags fail closed")
	_expect((unsafe_presenter.call("get_view_for_qa", "en").get("view", {}) as Dictionary).get("state") == "ERROR_FAIL_CLOSED",
		"Unsafe review enters ERROR_FAIL_CLOSED")


func _test_restore_second_confirmation_and_confirm() -> void:
	var presenter: RefCounted = _ready_presenter()
	var premature: Dictionary = presenter.call("confirm_restore_cloud_for_qa")
	_expect(premature.get("code") == "RESTORE_UX_SECOND_CONFIRMATION_REQUIRED",
		"Restore cannot execute before first explicit restore choice")

	var first_choice: Dictionary = presenter.call("choose_restore_cloud_for_qa")
	_expect(first_choice.get("ok") == true and first_choice.get("code") == "RESTORE_UX_CONFIRMATION_REQUIRED",
		"First restore choice only opens second-stage confirmation")
	_expect(first_choice.get("command_ready") == false,
		"First restore choice emits no execution command")
	_expect(first_choice.get("mutation_requested") == false,
		"First restore choice requests no mutation")
	var confirm_view: Dictionary = (presenter.call("get_view_for_qa", "en").get("view", {}) as Dictionary)
	_expect(confirm_view.get("state") == "RESTORE_CONFIRMATION_REQUIRED",
		"Presenter stays at explicit restore confirmation state")
	_expect((confirm_view.get("actions", {}) as Dictionary).get("confirm_restore") == true,
		"Confirmation state exposes explicit confirm action")
	_expect((confirm_view.get("actions", {}) as Dictionary).get("cancel_restore_confirmation") == true,
		"Confirmation state exposes explicit cancel action")

	var cancel: Dictionary = presenter.call("cancel_restore_confirmation_for_qa")
	_expect(cancel.get("ok") == true and cancel.get("state") == "REVIEW_READY",
		"User can cancel second-stage confirmation without mutation")
	_expect(cancel.get("mutation_requested") == false, "Cancel requests no mutation")

	_expect(presenter.call("choose_restore_cloud_for_qa").get("ok") == true,
		"Restore choice can be selected again after cancel")
	var command_result: Dictionary = presenter.call("confirm_restore_cloud_for_qa")
	_expect(command_result.get("ok") == true and command_result.get("command_ready") == true,
		"Second explicit confirm emits bound execution command")
	var command: Dictionary = command_result.get("command", {}) as Dictionary
	_expect(command.get("action") == "SUBMIT_REVIEW_DECISION",
		"Execution command routes a reviewed decision")
	_expect(command.get("decision") == "RESTORE_CLOUD", "Execution command selects RESTORE_CLOUD")
	_expect(command.get("review_id") == REVIEW_ID, "Execution command binds exact review id")
	_expect(command.get("remote_revision") == REMOTE_REVISION, "Execution command binds revision")
	_expect(command.get("remote_digest") == REMOTE_DIGEST, "Execution command binds digest")
	_expect(command.get("mutation_requested") == true, "Only second confirm requests restore mutation")
	_expect(command.get("production_execution_allowed") == false,
		"Command still cannot authorize production execution")

	var applied: Dictionary = presenter.call("apply_execution_result_for_qa", _applied_result())
	_expect(applied.get("ok") == true and applied.get("state") == "APPLIED_PENDING_CONFIRMATION",
		"Valid execution result enters APPLIED_PENDING_CONFIRMATION")
	_expect(applied.get("confirmation_required") == true,
		"Applied restore still requires explicit terminal choice")
	var pending_view: Dictionary = (presenter.call("get_view_for_qa", "en").get("view", {}) as Dictionary)
	_expect((pending_view.get("actions", {}) as Dictionary).get("keep_restored") == true,
		"Pending state offers KEEP RESTORED")
	_expect((pending_view.get("actions", {}) as Dictionary).get("rollback") == true,
		"Pending state offers ROLLBACK")

	var resolve_command_result: Dictionary = presenter.call("choose_keep_restored_for_qa")
	var resolve_command: Dictionary = resolve_command_result.get("command", {}) as Dictionary
	_expect(resolve_command.get("action") == "RESOLVE_APPLIED_RESTORE",
		"Keep-restored action emits resolution command")
	_expect(resolve_command.get("resolution") == "CONFIRM",
		"Keep-restored action maps to explicit CONFIRM")
	_expect(resolve_command.get("review_id") == REVIEW_ID,
		"Resolution command remains bound to same review")

	var confirmed: Dictionary = presenter.call("apply_resolution_result_for_qa", _resolution_result("CONFIRM"))
	_expect(confirmed.get("ok") == true and confirmed.get("state") == "USER_CONFIRMED_RESTORED",
		"Explicit confirm reaches USER_CONFIRMED_RESTORED")
	_expect(presenter.call("choose_rollback_for_qa").get("code") == "RESTORE_UX_RESOLUTION_NOT_AVAILABLE",
		"Opposite terminal action is unavailable after confirm")


func _test_restore_rollback() -> void:
	var presenter: RefCounted = _ready_presenter()
	presenter.call("choose_restore_cloud_for_qa")
	presenter.call("confirm_restore_cloud_for_qa")
	presenter.call("apply_execution_result_for_qa", _applied_result())
	var rollback_command_result: Dictionary = presenter.call("choose_rollback_for_qa")
	var rollback_command: Dictionary = rollback_command_result.get("command", {}) as Dictionary
	_expect(rollback_command.get("resolution") == "ROLLBACK",
		"Pending restore can emit explicit ROLLBACK")
	_expect(rollback_command.get("review_id") == REVIEW_ID,
		"Rollback remains bound to same review")
	var rolled_back: Dictionary = presenter.call("apply_resolution_result_for_qa", _resolution_result("ROLLBACK"))
	_expect(rolled_back.get("ok") == true and rolled_back.get("state") == "USER_ROLLED_BACK",
		"Explicit rollback reaches USER_ROLLED_BACK")
	_expect(rolled_back.get("resolution") == "ROLLBACK", "Terminal result reports rollback choice")


func _test_keep_local() -> void:
	var presenter: RefCounted = _ready_presenter()
	var command_result: Dictionary = presenter.call("choose_keep_local_for_qa")
	var command: Dictionary = command_result.get("command", {}) as Dictionary
	_expect(command_result.get("ok") == true and command_result.get("command_ready") == true,
		"KEEP LOCAL emits a bound no-restore decision command")
	_expect(command.get("decision") == "KEEP_LOCAL", "Keep-local command is explicit")
	_expect(command.get("mutation_requested") == false, "KEEP LOCAL requests no mutation")
	var complete: Dictionary = presenter.call("apply_execution_result_for_qa", _keep_local_result())
	_expect(complete.get("ok") == true and complete.get("state") == "USER_CHOSE_KEEP_LOCAL",
		"Validated keep-local result reaches terminal local state")
	_expect(complete.get("mutation_performed") == false, "Keep-local terminal state reports no mutation")


func _test_restore_choice_guards() -> void:
	var no_difference: Dictionary = _review_fixture()
	no_difference["domain_states"] = _all_same_states()
	no_difference["same_count"] = 8
	no_difference["changed_count"] = 0
	var same_presenter: RefCounted = presenter_script.new() as RefCounted
	_expect(same_presenter.call("present_review_for_qa", no_difference).get("restore_choice_available") == false,
		"Byte-identical review does not offer restore")
	_expect(same_presenter.call("choose_restore_cloud_for_qa").get("code") == "RESTORE_UX_RESTORE_CHOICE_BLOCKED",
		"No-difference restore choice is blocked")
	_expect(same_presenter.call("choose_keep_local_for_qa").get("ok") == true,
		"No-difference review can still explicitly keep local")

	var issue_review: Dictionary = _review_fixture(true)
	var issue_presenter: RefCounted = presenter_script.new() as RefCounted
	_expect(issue_presenter.call("present_review_for_qa", issue_review).get("restore_choice_available") == false,
		"Local preimage issue disables restore choice")
	_expect(issue_presenter.call("choose_restore_cloud_for_qa").get("code") == "RESTORE_UX_RESTORE_CHOICE_BLOCKED",
		"Unsafe preimage source cannot reach confirmation")


func _test_fail_closed_binding() -> void:
	var presenter: RefCounted = _ready_presenter()
	presenter.call("choose_restore_cloud_for_qa")
	presenter.call("confirm_restore_cloud_for_qa")
	var mismatched: Dictionary = _applied_result()
	mismatched["review_id"] = "e".repeat(64)
	var rejected: Dictionary = presenter.call("apply_execution_result_for_qa", mismatched)
	_expect(rejected.get("ok") == false and rejected.get("code") == "RESTORE_UX_RESULT_BINDING_MISMATCH",
		"Mismatched execution result fails closed")
	_expect(rejected.get("state") == "ERROR_FAIL_CLOSED",
		"Binding mismatch enters ERROR_FAIL_CLOSED")
	var error_view: Dictionary = (presenter.call("get_view_for_qa", "en").get("view", {}) as Dictionary)
	_expect(error_view.get("state") == "ERROR_FAIL_CLOSED", "Error view preserves fail-closed state")
	_expect((error_view.get("actions", {}) as Dictionary).values().count(true) == 0,
		"Fail-closed view exposes no automatic action")


func _ready_presenter() -> RefCounted:
	var presenter: RefCounted = presenter_script.new() as RefCounted
	var presented: Dictionary = presenter.call("present_review_for_qa", _review_fixture())
	_expect(presented.get("ok") == true, "Scenario review is presented")
	return presenter


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


func _all_same_states() -> Dictionary:
	return {
		"achievements": "SAME",
		"daily_quests": "SAME",
		"equipment": "SAME",
		"idle_cultivation": "SAME",
		"inventory": "SAME",
		"journey": "SAME",
		"pavilion": "SAME",
		"progression": "SAME",
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
	)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS | ", label)
		return
	failures += 1
	push_error("FAIL | " + label)


func _finish() -> void:
	print("JADE_CLOUD_RESTORE_UX_PRESENTER_QA_TOTAL: ", checks, " checks; ", failures, " failures")
	if failures == 0:
		print("JADE_CLOUD_RESTORE_UX_PRESENTER_QA_PASS")
		quit(0)
	else:
		quit(1)
