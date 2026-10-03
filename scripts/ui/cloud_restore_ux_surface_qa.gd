extends Control

## Subphase E3B — QA-only Godot UI surface for the locked E3A presenter.
##
## This node owns presentation and button routing only. It never reads or writes
## saves, never calls E1/E2/registered restore directly, never performs network
## I/O, and never authorizes production execution. Bound commands are emitted to
## an external QA harness and are intentionally never rendered or persisted here.

signal command_requested(command: Dictionary)
signal surface_closed()

const PresenterScript = preload("res://scripts/managers/cloud_restore_ux_presenter_qa.gd")

const REQUIRED_ACK: String = "DISPOSABLE_RUNNER_ONLY"
const STATE_RESTORE_CONFIRMATION_REQUIRED: String = "RESTORE_CONFIRMATION_REQUIRED"
const STATE_EXECUTING: String = "EXECUTING"
const STATE_APPLIED_PENDING_CONFIRMATION: String = "APPLIED_PENDING_CONFIRMATION"

const GOLD: Color = Color(0.99, 0.80, 0.42, 1.0)
const JADE: Color = Color(0.23, 0.89, 0.76, 1.0)
const IVORY: Color = Color(0.95, 0.97, 0.92, 1.0)
const MUTED: Color = Color(0.76, 0.85, 0.81, 1.0)
const DANGER: Color = Color(0.93, 0.46, 0.34, 1.0)
const INK: Color = Color(0.004, 0.029, 0.042, 0.985)

var _presenter: RefCounted = null
var _locale: String = "en"

var _backdrop: ColorRect
var _panel: PanelContainer
var _eyebrow: Label
var _headline: Label
var _message: Label
var _metadata: Label
var _summary: Label
var _timestamp_note: Label
var _domain_box: VBoxContainer
var _keep_local_button: Button
var _restore_cloud_button: Button
var _cancel_confirmation_button: Button
var _confirm_restore_button: Button
var _keep_restored_button: Button
var _rollback_button: Button
var _close_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_surface()
	visible = false
	if _qa_enabled():
		_presenter = PresenterScript.new() as RefCounted
	_render()


func present_review_for_qa(review: Dictionary, locale: String = "en") -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	if locale not in ["en", "id"]:
		return _no("RESTORE_UX_INTEGRATION_LOCALE_INVALID")
	if _presenter == null:
		_presenter = PresenterScript.new() as RefCounted
	_locale = locale
	var result: Dictionary = _presenter.call("present_review_for_qa", review)
	_render()
	if not bool(result.get("ok", false)):
		return result
	return _yes("RESTORE_UX_INTEGRATION_REVIEW_PRESENTED", {
		"state": str(result.get("state", "")),
		"surface_visible": visible,
	})


func show_surface_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	visible = true
	_render()
	return _yes("RESTORE_UX_INTEGRATION_SURFACE_SHOWN", {
		"surface_visible": true,
	})


func hide_surface_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	var state: String = _current_state()
	if state in [
		STATE_RESTORE_CONFIRMATION_REQUIRED,
		STATE_EXECUTING,
		STATE_APPLIED_PENDING_CONFIRMATION,
	]:
		return _no("RESTORE_UX_INTEGRATION_DISMISS_BLOCKED", {
			"state": state,
			"surface_visible": visible,
		})
	visible = false
	surface_closed.emit()
	return _yes("RESTORE_UX_INTEGRATION_SURFACE_HIDDEN", {
		"state": state,
		"surface_visible": false,
	})


func apply_execution_result_for_qa(result: Dictionary) -> Dictionary:
	if not _qa_enabled() or _presenter == null:
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	var applied: Dictionary = _presenter.call("apply_execution_result_for_qa", result)
	_render()
	return applied


func apply_resolution_result_for_qa(result: Dictionary) -> Dictionary:
	if not _qa_enabled() or _presenter == null:
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	var applied: Dictionary = _presenter.call("apply_resolution_result_for_qa", result)
	_render()
	return applied


func get_view_for_qa() -> Dictionary:
	if not _qa_enabled() or _presenter == null:
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	return _presenter.call("get_view_for_qa", _locale)


func get_control_snapshot_for_qa() -> Dictionary:
	if not _qa_enabled():
		return _no("RESTORE_UX_INTEGRATION_QA_DISABLED")
	var domain_texts: Array[String] = []
	if _domain_box != null:
		for child: Node in _domain_box.get_children():
			if child is Label:
				domain_texts.append((child as Label).text)
	return _yes("RESTORE_UX_INTEGRATION_CONTROL_SNAPSHOT", {
		"surface_visible": visible,
		"state": _current_state(),
		"headline": _headline.text if _headline != null else "",
		"message": _message.text if _message != null else "",
		"metadata": _metadata.text if _metadata != null else "",
		"summary": _summary.text if _summary != null else "",
		"timestamp_note": _timestamp_note.text if _timestamp_note != null else "",
		"domain_texts": domain_texts,
		"keep_local_visible": _is_visible(_keep_local_button),
		"restore_cloud_visible": _is_visible(_restore_cloud_button),
		"restore_cloud_disabled": _is_disabled(_restore_cloud_button),
		"cancel_confirmation_visible": _is_visible(_cancel_confirmation_button),
		"confirm_restore_visible": _is_visible(_confirm_restore_button),
		"keep_restored_visible": _is_visible(_keep_restored_button),
		"rollback_visible": _is_visible(_rollback_button),
		"close_visible": _is_visible(_close_button),
		"raw_payload_included": false,
		"production_execution_allowed": false,
	})


func _build_surface() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.001, 0.014, 0.019, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	_backdrop.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.name = "RestoreReviewPanel"
	_panel.custom_minimum_size = Vector2(690.0, 700.0)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	_eyebrow = _make_label("CLOUD SAVE  •  REVIEW", 12, JADE)
	_eyebrow.name = "Eyebrow"
	content.add_child(_eyebrow)

	_headline = _make_label("", 27, GOLD)
	_headline.name = "Headline"
	content.add_child(_headline)

	_message = _make_label("", 15, IVORY)
	_message.name = "Message"
	content.add_child(_message)

	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size.y = 2.0
	rule.color = Color(0.30, 0.79, 0.67, 0.46)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(rule)

	_metadata = _make_label("", 13, MUTED)
	_metadata.name = "Metadata"
	content.add_child(_metadata)

	_summary = _make_label("", 14, IVORY)
	_summary.name = "Summary"
	content.add_child(_summary)

	var scroll := ScrollContainer.new()
	scroll.name = "DomainScroll"
	scroll.custom_minimum_size = Vector2(0.0, 238.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)

	_domain_box = VBoxContainer.new()
	_domain_box.name = "DomainRows"
	_domain_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_domain_box.add_theme_constant_override("separation", 5)
	scroll.add_child(_domain_box)

	_timestamp_note = _make_label("", 12, MUTED)
	_timestamp_note.name = "TimestampNote"
	content.add_child(_timestamp_note)

	var action_grid := GridContainer.new()
	action_grid.name = "Actions"
	action_grid.columns = 2
	action_grid.add_theme_constant_override("h_separation", 10)
	action_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(action_grid)

	_keep_local_button = _make_button("KeepLocalButton", "KEEP LOCAL", false)
	_restore_cloud_button = _make_button("RestoreCloudButton", "RESTORE CLOUD", true)
	_cancel_confirmation_button = _make_button("CancelConfirmationButton", "CANCEL", false)
	_confirm_restore_button = _make_button("ConfirmRestoreButton", "CONFIRM RESTORE", true)
	_keep_restored_button = _make_button("KeepRestoredButton", "KEEP RESTORED", true)
	_rollback_button = _make_button("RollbackButton", "ROLL BACK", false)
	for button: Button in [
		_keep_local_button,
		_restore_cloud_button,
		_cancel_confirmation_button,
		_confirm_restore_button,
		_keep_restored_button,
		_rollback_button,
	]:
		action_grid.add_child(button)

	_close_button = _make_button("CloseButton", "CLOSE", false)
	content.add_child(_close_button)

	_keep_local_button.pressed.connect(_on_keep_local_pressed)
	_restore_cloud_button.pressed.connect(_on_restore_cloud_pressed)
	_cancel_confirmation_button.pressed.connect(_on_cancel_confirmation_pressed)
	_confirm_restore_button.pressed.connect(_on_confirm_restore_pressed)
	_keep_restored_button.pressed.connect(_on_keep_restored_pressed)
	_rollback_button.pressed.connect(_on_rollback_pressed)
	_close_button.pressed.connect(_on_close_pressed)


func _render() -> void:
	if _headline == null:
		return
	if _presenter == null:
		_headline.text = "Restore UX unavailable"
		_message.text = "QA presenter is not armed."
		_metadata.text = ""
		_summary.text = ""
		_timestamp_note.text = ""
		_clear_domain_rows()
		_hide_all_actions()
		_close_button.visible = true
		return

	var view_result: Dictionary = _presenter.call("get_view_for_qa", _locale)
	if not bool(view_result.get("ok", false)):
		_headline.text = "Restore stopped safely"
		_message.text = str(view_result.get("code", "RESTORE_UX_VIEW_UNAVAILABLE"))
		_metadata.text = ""
		_summary.text = ""
		_timestamp_note.text = ""
		_clear_domain_rows()
		_hide_all_actions()
		_close_button.visible = true
		return

	var view: Dictionary = view_result.get("view", {}) as Dictionary
	_headline.text = str(view.get("headline", ""))
	_message.text = str(view.get("message", ""))
	var owner_display: String = str(view.get("owner_display", ""))
	var revision: int = int(view.get("remote_revision", 0))
	var digest_display: String = str(view.get("remote_digest_display", ""))
	_metadata.text = _metadata_copy(owner_display, revision, digest_display)
	_summary.text = _summary_copy(
		int(view.get("same_count", 0)),
		int(view.get("changed_count", 0)),
		int(view.get("local_issue_count", 0))
	)
	_timestamp_note.text = str(view.get("timestamp_note", ""))
	_render_domain_rows(view.get("domain_rows", []) as Array)
	_render_actions(view.get("actions", {}) as Dictionary, bool(view.get("restore_choice_available", false)))


func _render_domain_rows(rows: Array) -> void:
	_clear_domain_rows()
	for index: int in range(rows.size()):
		if not (rows[index] is Dictionary):
			continue
		var row: Dictionary = rows[index] as Dictionary
		var state: String = str(row.get("state", ""))
		var label: Label = _make_label(
			str(row.get("label", "")) + "  •  " + _state_label(state),
			13,
			_state_color(state)
		)
		label.name = "DomainRow%d" % index
		_domain_box.add_child(label)


func _render_actions(actions: Dictionary, restore_choice_available: bool) -> void:
	_keep_local_button.visible = bool(actions.get("keep_local", false))
	_restore_cloud_button.visible = bool(actions.get("choose_restore", false))
	_restore_cloud_button.disabled = not restore_choice_available
	_cancel_confirmation_button.visible = bool(actions.get("cancel_restore_confirmation", false))
	_confirm_restore_button.visible = bool(actions.get("confirm_restore", false))
	_keep_restored_button.visible = bool(actions.get("keep_restored", false))
	_rollback_button.visible = bool(actions.get("rollback", false))
	_close_button.visible = _dismiss_allowed(_current_state())


func _hide_all_actions() -> void:
	for button: Button in [
		_keep_local_button,
		_restore_cloud_button,
		_cancel_confirmation_button,
		_confirm_restore_button,
		_keep_restored_button,
		_rollback_button,
	]:
		if button != null:
			button.visible = false


func _clear_domain_rows() -> void:
	if _domain_box == null:
		return
	for child: Node in _domain_box.get_children():
		_domain_box.remove_child(child)
		child.queue_free()


func _on_keep_local_pressed() -> void:
	if _presenter == null:
		return
	var result: Dictionary = _presenter.call("choose_keep_local_for_qa")
	_render()
	_emit_command_if_ready(result)


func _on_restore_cloud_pressed() -> void:
	if _presenter == null:
		return
	_presenter.call("choose_restore_cloud_for_qa")
	_render()


func _on_cancel_confirmation_pressed() -> void:
	if _presenter == null:
		return
	_presenter.call("cancel_restore_confirmation_for_qa")
	_render()


func _on_confirm_restore_pressed() -> void:
	if _presenter == null:
		return
	var result: Dictionary = _presenter.call("confirm_restore_cloud_for_qa")
	_render()
	_emit_command_if_ready(result)


func _on_keep_restored_pressed() -> void:
	if _presenter == null:
		return
	var result: Dictionary = _presenter.call("choose_keep_restored_for_qa")
	_render()
	_emit_command_if_ready(result)


func _on_rollback_pressed() -> void:
	if _presenter == null:
		return
	var result: Dictionary = _presenter.call("choose_rollback_for_qa")
	_render()
	_emit_command_if_ready(result)


func _on_close_pressed() -> void:
	hide_surface_for_qa()


func _emit_command_if_ready(result: Dictionary) -> void:
	if not bool(result.get("ok", false)) or result.get("command_ready") != true:
		return
	if not (result.get("command") is Dictionary):
		return
	var command: Dictionary = (result["command"] as Dictionary).duplicate(true)
	command_requested.emit(command)
	command.clear()


func _current_state() -> String:
	if _presenter == null:
		return "NO_CANDIDATE"
	var result: Dictionary = _presenter.call("get_view_for_qa", _locale)
	if not bool(result.get("ok", false)):
		return "ERROR_FAIL_CLOSED"
	var view: Dictionary = result.get("view", {}) as Dictionary
	return str(view.get("state", "ERROR_FAIL_CLOSED"))


func _dismiss_allowed(state: String) -> bool:
	return state not in [
		STATE_RESTORE_CONFIRMATION_REQUIRED,
		STATE_EXECUTING,
		STATE_APPLIED_PENDING_CONFIRMATION,
	]


func _metadata_copy(owner_display: String, revision: int, digest_display: String) -> String:
	if owner_display.is_empty():
		return ""
	if _locale == "id":
		return "Akun %s  •  Revisi %d  •  Digest %s" % [owner_display, revision, digest_display]
	return "Account %s  •  Revision %d  •  Digest %s" % [owner_display, revision, digest_display]


func _summary_copy(same_count: int, changed_count: int, issue_count: int) -> String:
	if _locale == "id":
		return "Sama %d  •  Berubah %d  •  Masalah lokal %d" % [same_count, changed_count, issue_count]
	return "Same %d  •  Changed %d  •  Local issues %d" % [same_count, changed_count, issue_count]


func _state_label(state: String) -> String:
	var en: Dictionary = {
		"SAME": "Same",
		"DIFFERENT": "Different",
		"LOCAL_MISSING": "Local missing",
		"LOCAL_INVALID": "Local invalid",
	}
	var id: Dictionary = {
		"SAME": "Sama",
		"DIFFERENT": "Berbeda",
		"LOCAL_MISSING": "Lokal hilang",
		"LOCAL_INVALID": "Lokal tidak valid",
	}
	var labels: Dictionary = id if _locale == "id" else en
	return str(labels.get(state, state))


func _state_color(state: String) -> Color:
	match state:
		"SAME":
			return MUTED
		"DIFFERENT":
			return GOLD
		"LOCAL_MISSING", "LOCAL_INVALID":
			return DANGER
		_:
			return IVORY


func _make_label(message: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(node_name: String, text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _button_style(primary, false))
	button.add_theme_stylebox_override("hover", _button_style(primary, false))
	button.add_theme_stylebox_override("pressed", _button_style(primary, true))
	button.add_theme_stylebox_override("disabled", _button_disabled_style())
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _panel_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = INK
	panel.set_border_width_all(2)
	panel.border_width_bottom = 3
	panel.border_color = Color(0.96, 0.79, 0.44, 0.78)
	panel.set_corner_radius_all(18)
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	panel.shadow_size = 14
	return panel


func _button_style(primary: bool, pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(9)
	style.set_border_width_all(2)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.bg_color = Color(0.012, 0.10, 0.11, 1.0) if primary else Color(0.025, 0.065, 0.073, 1.0)
	style.border_color = JADE if primary else Color(0.55, 0.47, 0.29, 0.92)
	if pressed:
		style.bg_color = style.bg_color.darkened(0.12)
	return style


func _button_disabled_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(9)
	style.set_border_width_all(2)
	style.bg_color = Color(0.08, 0.14, 0.16, 1.0)
	style.border_color = Color(0.38, 0.49, 0.48, 0.50)
	return style


func _is_visible(button: Button) -> bool:
	return button != null and button.visible


func _is_disabled(button: Button) -> bool:
	return button == null or button.disabled


func _qa_enabled() -> bool:
	return (
		OS.has_feature("editor")
		and OS.get_environment("GITHUB_ACTIONS") == "true"
		and OS.get_environment("JADE_RESTORE_UX_INTEGRATION_TEST_ONLY") == "1"
		and OS.get_environment("JADE_RESTORE_UX_INTEGRATION_ACK") == REQUIRED_ACK
	)


func _yes(code: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"code": code,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
	}
	for key in extra:
		result[key] = extra[key]
	return result


func _no(code: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"code": code,
		"upload_allowed": false,
		"restore_allowed": false,
		"cloud_mutation_enabled": false,
		"production_execution_allowed": false,
	}
	for key in extra:
		result[key] = extra[key]
	return result
