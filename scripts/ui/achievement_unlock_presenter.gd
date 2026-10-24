extends Node

## Non-blocking in-run presentation for newly unlocked achievements.
## AchievementManager remains the sole owner of unlock, reward, and save state.

const TrialsRecordSealScript = preload(
	"res://scripts/ui/trials_record_seal.gd"
)

const TOAST_TOP: float = 168.0
const TOAST_HEIGHT: float = 142.0
const ENTER_OFFSET: float = -26.0
const ENTER_DURATION: float = 0.22
const HOLD_DURATION: float = 5.0
const EXIT_DURATION: float = 0.24
const REDUCED_HOLD_DURATION: float = 5.0

var _pending_ids: Array[String] = []
var _current_id: String = ""
var _active: bool = false
var _scene_instance_id: int = 0
var _host: Control = null
var _panel: PanelContainer = null
var _active_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var manager: Node = get_parent()
	var unlocked_callable := Callable(self, "_on_achievement_unlocked")
	if (
		manager != null
		and manager.has_signal("achievement_unlocked")
		and not manager.is_connected("achievement_unlocked", unlocked_callable)
	):
		manager.connect("achievement_unlocked", unlocked_callable)


func _process(_delta: float) -> void:
	if not _active:
		if not _pending_ids.is_empty(): _present_next()
		return
	if _host == null or not is_instance_valid(_host):
		_abort_sequence()
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.get_instance_id() != _scene_instance_id:
		_abort_sequence()
		return
	var safe: Control = _host.get_parent()
	var boss_notice: bool = false
	for node_name: String in ["BossPreWarning", "EncounterBanner"]:
		var notice: Control = safe.get_node_or_null(node_name)
		boss_notice = boss_notice or (notice != null and notice.visible)
	if boss_notice:
		_panel.visible = false
		if _active_tween != null and _active_tween.is_valid(): _active_tween.pause()
	elif not _panel.visible:
		_panel.visible = true
		_layout_toast()
		if _active_tween != null and _active_tween.is_valid(): _active_tween.play()


func _on_achievement_unlocked(achievement_id: String) -> void:
	if achievement_id.is_empty():
		return
	if not _is_gameplay_scene_active():
		return
	if achievement_id == _current_id or achievement_id in _pending_ids:
		return
	_pending_ids.append(achievement_id)
	if not _active:
		call_deferred("_present_next")


func _is_gameplay_scene_active() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	if get_tree().get_first_node_in_group("player") == null:
		return false
	return scene.get_node_or_null("HUD/ScreenRoot/HUDSafeArea") != null


func _present_next() -> void:
	if _active or _pending_ids.is_empty():
		return
	var safe_area: Control = _get_current_safe_area()
	if safe_area == null:
		_pending_ids.clear()
		return

	for notice_name: String in ["BossPreWarning", "EncounterBanner"]:
		var notice: Control = safe_area.get_node_or_null(notice_name)
		if notice != null and notice.visible: return

	_current_id = _pending_ids.pop_front()
	var manager: Node = get_parent()
	if manager == null or not manager.has_method("get_achievement_data"):
		_current_id = ""
		return

	var data: Dictionary = manager.call("get_achievement_data", _current_id)
	if data.is_empty():
		_current_id = ""
		call_deferred("_present_next")
		return

	_active = true
	_scene_instance_id = get_tree().current_scene.get_instance_id()
	_build_toast(safe_area, data)
	AudioManager.play_sfx("ui_confirm")
	_play_toast_animation()


func _get_current_safe_area() -> Control:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("HUD/ScreenRoot/HUDSafeArea") as Control


func _build_toast(safe_area: Control, data: Dictionary) -> void:
	_host = Control.new()
	_host.name = "AchievementUnlockToast"
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.z_index = 90
	safe_area.add_child(_host)
	safe_area.resized.connect(_layout_toast)
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var category: String = str(data.get("category", "achievement")).to_lower()
	var accent: Color = _get_category_color(category)
	var reward: int = 0
	var manager: Node = get_parent()
	if manager != null and manager.has_method("get_reward"):
		reward = int(manager.call("get_reward", _current_id))

	_panel = PanelContainer.new()
	_panel.name = "RecordToastPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.055
	_panel.anchor_right = 0.945
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_top = TOAST_TOP
	_panel.offset_bottom = TOAST_TOP + TOAST_HEIGHT
	_panel.add_theme_stylebox_override("panel", _make_panel_style(accent))
	_host.add_child(_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var compact: bool = safe_area.size.x < 380.0
	var seal: Control = TrialsRecordSealScript.new()
	seal.custom_minimum_size = Vector2(48.0, 48.0) if compact else Vector2(72.0, 72.0)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seal.call("configure", category, "reward_ready", false)
	row.add_child(seal)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 3)
	row.add_child(body)

	var eyebrow := Label.new()
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eyebrow.max_lines_visible = 1 if compact else 2
	eyebrow.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	eyebrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eyebrow.add_theme_font_size_override("font_size", 11 if compact else 13)
	eyebrow.add_theme_color_override("font_color", accent)
	eyebrow.text = "ETERNAL RECORD DISCOVERED  •  %s" % category.to_upper()
	body.add_child(eyebrow)

	var title := Label.new()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18 if compact else 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.60, 1.0))
	title.text = str(data.get("title", _current_id))
	body.add_child(title)

	var description := Label.new()
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.custom_minimum_size = Vector2(0.0, 34.0)
	description.add_theme_font_size_override("font_size", 12 if compact else 14)
	description.add_theme_color_override("font_color", Color(0.78, 0.86, 0.84, 1.0))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2 if compact else 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.text = str(data.get("description", ""))
	body.add_child(description)

	var footer := VBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_theme_constant_override("separation", 4 if compact else 8)
	body.add_child(footer)

	var reward_label := Label.new()
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_label.max_lines_visible = 1 if compact else 2
	reward_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_label.add_theme_font_size_override("font_size", 11 if compact else 13)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
	reward_label.text = "REWARD READY  •  +%d SPIRIT STONES" % reward
	footer.add_child(reward_label)

	var claim_label := Label.new()
	claim_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	claim_label.max_lines_visible = 1
	claim_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	claim_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	claim_label.add_theme_font_size_override("font_size", 12)
	claim_label.add_theme_color_override("font_color", Color(0.54, 0.72, 0.69, 1.0))
	claim_label.text = "CLAIM IN TRIALS"
	footer.add_child(claim_label)
	_layout_toast()
	call_deferred("_layout_toast")


func _layout_toast() -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_host): return
	var safe: Control = _host.get_parent()
	var width: float = minf(560.0, safe.size.x * 0.9)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.size.x = width
	var top: float = 12.0
	for node_name: String in ["TopHUD", "BossPanel", "BossPreWarning", "EncounterBanner"]:
		var strip: Control = safe.get_node_or_null(node_name)
		if strip != null and strip.visible: top = maxf(top, strip.get_rect().end.y + 16.0)
	_panel.size.y = maxf(TOAST_HEIGHT, _panel.get_combined_minimum_size().y)
	_panel.position = Vector2((safe.size.x-_panel.size.x)*0.5, minf(top,maxf(12.0,safe.size.y-_panel.size.y-12.0)))

func _make_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.003, 0.024, 0.031, 0.965)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	style.shadow_size = 10
	return style


func _get_category_color(category: String) -> Color:
	match category:
		"combat":
			return Color(0.94, 0.34, 0.28, 1.0)
		"progression":
			return Color(0.30, 0.80, 0.98, 1.0)
		"journey":
			return Color(0.25, 0.90, 0.66, 1.0)
		"boss":
			return Color(1.0, 0.70, 0.20, 1.0)
		"cultivation":
			return Color(0.70, 0.50, 1.0, 1.0)
		_:
			return Color(0.32, 0.86, 0.76, 1.0)


func _play_toast_animation() -> void:
	if _panel == null or not is_instance_valid(_panel):
		_finish_current()
		return
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_panel.modulate = Color.WHITE
	_panel.scale = Vector2.ONE
	_panel.pivot_offset = Vector2(_panel.size.x * 0.5, 0.0)

	if bool(SettingsManager.reduced_effects):
		_active_tween = create_tween()
		_active_tween.tween_interval(REDUCED_HOLD_DURATION)
		_active_tween.tween_property(_panel, "modulate:a", 0.0, 0.12)
		_active_tween.tween_callback(_finish_current)
		return

	_panel.modulate = Color(1.0, 0.90, 0.62, 0.0)
	_panel.scale = Vector2(0.985, 0.985)

	_active_tween = create_tween()
	_active_tween.tween_property(
		_panel,
		"modulate",
		Color.WHITE,
		ENTER_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(
		_panel,
		"scale",
		Vector2.ONE,
		ENTER_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_interval(HOLD_DURATION)
	_active_tween.tween_property(
		_panel,
		"modulate:a",
		0.0,
		EXIT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.tween_callback(_finish_current)


func _finish_current() -> void:
	if _host != null and is_instance_valid(_host):
		var safe: Node = _host.get_parent()
		if safe.resized.is_connected(_layout_toast): safe.resized.disconnect(_layout_toast)
		_host.queue_free()
	_host = null
	_panel = null
	_active_tween = null
	_current_id = ""
	_active = false
	_scene_instance_id = 0
	if not _pending_ids.is_empty():
		call_deferred("_present_next")


func _abort_sequence() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _host != null and is_instance_valid(_host):
		var safe: Node = _host.get_parent()
		if safe.resized.is_connected(_layout_toast): safe.resized.disconnect(_layout_toast)
		_host.queue_free()
	_pending_ids.clear()
	_current_id = ""
	_active = false
	_scene_instance_id = 0
	_host = null
	_panel = null
	_active_tween = null
