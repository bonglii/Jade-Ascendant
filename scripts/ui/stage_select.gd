extends Control

## Production Stage Select — ascension journey map.
## Progression, selection, rewards, checkpoints and run identity remain manager-owned.

const CHAPTER_SELECT_SCENE := "res://scenes/ui/chapter_select.tscn"
const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")

const JourneyArtCatalog = preload("res://scripts/ui/journey_art_catalog.gd")
const MobileSafeAreaScript = preload("res://scripts/ui/mobile_safe_area.gd")

const GOLD := Color(0.957, 0.78, 0.357, 1.0)
const TEXT_MAIN := Color(0.95, 0.96, 0.93, 1.0)

var chapter_id: int = 1
var preview_stage_id: int = 1
var realm_profile: Dictionary = {}
var realm_texture: Texture2D
var stage_textures: Dictionary = {}
var seal_textures: Dictionary = {}
var background_texture: TextureRect
var view_host: Control
var map_scroll: ScrollContainer
var start_button: Button
var confirm_overlay: Control
var start_confirm_dialog: Control
var confirm_stage_label: Label
var confirm_body_label: Label


func _ready() -> void:
	chapter_id = JourneyManager.selected_chapter_id
	preview_stage_id = JourneyManager.selected_stage_id
	if not JourneyManager.has_stage(chapter_id, preview_stage_id):
		var ids := JourneyManager.get_stage_ids(chapter_id)
		if not ids.is_empty():
			preview_stage_id = int(ids[0])
	realm_profile = JourneyVisualCatalog.get_chapter_profile(chapter_id)
	_load_textures()
	_build_shell()
	_refresh_screen()
	SceneTransitionManager.set_back_handler(handle_system_back)


func _load_textures() -> void:
	var realm_path: String = JourneyArtCatalog.get_realm_vista_path(chapter_id)
	realm_texture = ResourceLoader.load(realm_path, "Texture2D") as Texture2D
	if realm_texture == null:
		push_error("StageSelect: failed to load realm artwork: " + realm_path)
	stage_textures.clear()
	for raw_stage_id: Variant in JourneyManager.get_stage_ids(chapter_id):
		var stage_id: int = int(raw_stage_id)
		var path: String = JourneyArtCatalog.get_stage_art_path(chapter_id, stage_id)
		if path.is_empty():
			continue
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		if texture != null:
			stage_textures[stage_id] = texture
	seal_textures.clear()
	for state: String in ["CLEARED", "CURRENT", "LOCKED", "BOSS"]:
		var path: String = JourneyArtCatalog.get_node_seal_path(chapter_id, state)
		var texture: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		if texture != null:
			seal_textures[state] = texture


func _build_shell() -> void:
	background_texture = TextureRect.new()
	background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background_texture.texture = realm_texture
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_texture)

	var veil_gradient := Gradient.new()
	veil_gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.38, 0.62, 0.82, 1.0])
	veil_gradient.colors = PackedColorArray([
		Color(0.0, 0.008, 0.014, 0.64), Color(0.0, 0.008, 0.014, 0.30),
		Color(0.0, 0.008, 0.014, 0.04), Color(0.0, 0.008, 0.014, 0.12),
		Color(0.0, 0.008, 0.014, 0.48), Color(0.0, 0.008, 0.014, 0.82),
	])
	var veil_texture := GradientTexture2D.new()
	veil_texture.gradient = veil_gradient
	veil_texture.width = 8
	veil_texture.height = 512
	veil_texture.fill_from = Vector2(0.5, 0.0)
	veil_texture.fill_to = Vector2(0.5, 1.0)
	var veil := TextureRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.texture = veil_texture
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var top_accent := ColorRect.new()
	top_accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_accent.custom_minimum_size = Vector2(0.0, 3.0)
	var accent: Color = realm_profile.get("accent", Color(0.30, 0.82, 0.65, 1.0))
	top_accent.color = Color(accent.r, accent.g, accent.b, 0.82)
	top_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_accent)

	var safe_host := Control.new()
	safe_host.name = "SafeArea"
	safe_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_host.set_script(MobileSafeAreaScript)
	add_child(safe_host)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 12)
	safe.add_theme_constant_override("margin_top", 16)
	safe.add_theme_constant_override("margin_right", 12)
	safe.add_theme_constant_override("margin_bottom", 12)
	safe_host.add_child(safe)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 7)
	safe.add_child(main)

	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0.0, 48.0)
	main.add_child(top_bar)
	var back := Button.new()
	back.custom_minimum_size = Vector2(112.0, 46.0)
	back.text = "‹   REALM"
	back.theme_type_variation = &"JadeBackButton"
	back.add_theme_font_size_override("font_size", 15)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_on_back_pressed)
	top_bar.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)
	var context := Label.new()
	context.theme_type_variation = &"JadeNavLabel"
	context.add_theme_font_size_override("font_size", 12)
	context.text = "%s • JOURNEY MAP" % str(JourneyManager.get_chapter_data(chapter_id).get("display_name", "REALM")).to_upper()
	context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(context)

	view_host = Control.new()
	view_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(view_host)

	_build_confirm_overlay()


func _refresh_screen() -> void:
	for child: Node in view_host.get_children():
		view_host.remove_child(child)
		child.queue_free()
	_build_journey_view()


func _build_journey_view() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 7)
	view_host.add_child(layout)
	var accent: Color = realm_profile.get("accent", Color(0.30, 0.82, 0.65, 1.0))
	var chapter_data := JourneyManager.get_chapter_data(chapter_id)
	var stage_ids: Array = JourneyArtCatalog.get_presentation_stage_ids(
		chapter_id,
		JourneyManager.get_stage_ids(chapter_id)
	)

	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0.0, 104.0)
	header.add_theme_stylebox_override("panel", _make_panel_style(Color(0.003, 0.018, 0.027, 0.84), Color(accent.r, accent.g, accent.b, 0.30), 14, 1))
	layout.add_child(header)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 15)
	hm.add_theme_constant_override("margin_top", 9)
	hm.add_theme_constant_override("margin_right", 15)
	hm.add_theme_constant_override("margin_bottom", 9)
	header.add_child(hm)
	var hb := VBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hm.add_child(hb)
	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.text = "REALM %d   •   %d-TRIAL ASCENSION PATH" % [chapter_id, stage_ids.size()]
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(eyebrow)
	var title := Label.new()
	title.theme_type_variation = &"JadeTitle"
	title.add_theme_font_size_override("font_size", 26)
	title.text = str(chapter_data.get("display_name", "Unknown Realm")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(title)
	var subtitle := Label.new()
	subtitle.theme_type_variation = &"JadeMutedLabel"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.79, 0.84, 0.84, 1.0))
	subtitle.text = "Follow the awakened route toward the realm boss. Locked paths fade into mist."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(subtitle)

	map_scroll = ScrollContainer.new()
	map_scroll.name = "JourneyMapScroll"
	map_scroll.custom_minimum_size = Vector2(0.0, 300.0)
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hide_scrollbar_chrome(map_scroll)
	layout.add_child(map_scroll)

	var metrics := _get_stage_map_metrics(stage_ids.size())
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(0.0, float(metrics.get("height", 900.0)))
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.add_child(canvas)
	_build_stage_map(canvas, accent, metrics, stage_ids)

	layout.add_child(_build_selected_stage_panel(accent))
	call_deferred("_scroll_stage_map_to_selected", metrics, stage_ids)


func _get_stage_map_metrics(stage_count: int) -> Dictionary:
	var count := maxi(stage_count, 1)
	var top_y := 122.0
	var boss_gap := 238.0
	var normal_gap := 176.0
	var bottom_padding := 112.0
	var last_y := top_y
	if count > 1:
		last_y += boss_gap + float(count - 2) * normal_gap
	return {"height": maxf(900.0, last_y + bottom_padding), "top_y": top_y, "boss_gap": boss_gap, "normal_gap": normal_gap}


func _build_stage_map(canvas: Control, accent: Color, metrics: Dictionary, stage_ids: Array) -> void:
	if stage_ids.is_empty():
		return
	var map_height := float(metrics.get("height", 900.0))
	var top_y := float(metrics.get("top_y", 122.0))
	var boss_gap := float(metrics.get("boss_gap", 238.0))
	var normal_gap := float(metrics.get("normal_gap", 176.0))
	var points := PackedVector2Array()
	for index in range(stage_ids.size()):
		var x := 176.0 if index % 2 == 0 else 436.0
		if index == stage_ids.size() - 1:
			x = 306.0
		var distance := stage_ids.size() - 1 - index
		var y := top_y
		if distance > 0:
			y += boss_gap + float(distance - 1) * normal_gap
		points.append(Vector2(x, y))

	var base := Line2D.new()
	base.width = 9.0
	base.default_color = Color(0.18, 0.23, 0.23, 0.24)
	base.points = points
	base.antialiased = true
	canvas.add_child(base)
	for i in range(points.size() - 1):
		_add_route_segment(canvas, points[i], points[i + 1], accent, _segment_status(int(stage_ids[i]), int(stage_ids[i + 1])))

	var occupied: Array[Rect2] = []
	for index in range(stage_ids.size()):
		var stage_id := int(stage_ids[index])
		var data: Dictionary = JourneyArtCatalog.apply_stage_presentation(
			chapter_id,
			stage_id,
			JourneyManager.get_stage_data(chapter_id, stage_id)
		)
		var is_boss := bool(data.get("is_chapter_boss", false)) or index == stage_ids.size() - 1
		var raw_status := _get_stage_status(stage_id)
		var visual_status := _get_visual_status(stage_id, raw_status)
		var selected := stage_id == preview_stage_id
		var node_size := 104.0 if is_boss else 78.0
		var point := points[index]
		_add_stage_seal_asset(canvas, point, visual_status, is_boss, selected)
		var button := Button.new()
		button.position = point - Vector2(node_size, node_size) * 0.5
		button.size = Vector2(node_size, node_size)
		button.text = "%d-%d" % [chapter_id, stage_id]
		button.add_theme_font_size_override("font_size", 19 if is_boss else 16)
		button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.76, 1.0))
		button.focus_mode = Control.FOCUS_NONE
		_apply_stage_node_style(button, visual_status, is_boss, selected)
		button.pressed.connect(_on_stage_node_pressed.bind(stage_id))
		canvas.add_child(button)
		var rect := _add_stage_label_plate(canvas, point, data, raw_status, accent, is_boss, selected, occupied, map_height)
		occupied.append(rect)


func _segment_status(from_stage: int, to_stage: int) -> String:
	if JourneyManager.is_stage_cleared(chapter_id, from_stage) and JourneyManager.is_stage_cleared(chapter_id, to_stage):
		return "CLEARED"
	if JourneyManager.is_stage_cleared(chapter_id, from_stage) and JourneyManager.is_stage_unlocked(chapter_id, to_stage):
		return "CURRENT"
	return "LOCKED"


func _get_stage_status(stage_id: int) -> String:
	if not JourneyManager.is_stage_unlocked(chapter_id, stage_id):
		return "LOCKED"
	if not JourneyManager.is_stage_implemented(chapter_id, stage_id):
		return "COMING SOON"
	if JourneyManager.is_stage_cleared(chapter_id, stage_id):
		return "CLEARED"
	return "AVAILABLE"


func _get_visual_status(stage_id: int, raw_status: String) -> String:
	if raw_status == "LOCKED" or raw_status == "COMING SOON":
		return "LOCKED"
	if stage_id == preview_stage_id:
		return "CURRENT"
	if raw_status == "CLEARED":
		return "CLEARED"
	return "CURRENT"


func _build_selected_stage_panel(accent: Color) -> PanelContainer:
	var data: Dictionary = JourneyArtCatalog.apply_stage_presentation(
		chapter_id,
		preview_stage_id,
		JourneyManager.get_stage_data(chapter_id, preview_stage_id)
	)
	var status := _get_stage_status(preview_stage_id)
	var can_start := (
		JourneyManager.selected_chapter_id == chapter_id
		and JourneyManager.selected_stage_id == preview_stage_id
		and JourneyManager.is_stage_unlocked(chapter_id, preview_stage_id)
		and JourneyManager.is_stage_implemented(chapter_id, preview_stage_id)
	)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 232.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.003, 0.018, 0.027, 0.95), Color(accent.r, accent.g, accent.b, 0.38), 14, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	margin.add_child(row)
	var image_panel := PanelContainer.new()
	image_panel.custom_minimum_size = Vector2(112.0, 172.0)
	image_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.01, 0.03, 0.04, 0.96), Color(GOLD.r, GOLD.g, GOLD.b, 0.42), 10, 1))
	row.add_child(image_panel)
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	image.texture = stage_textures.get(preview_stage_id, realm_texture) as Texture2D
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_panel.add_child(image)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 5)
	row.add_child(text_box)
	var status_row := HBoxContainer.new()
	text_box.add_child(status_row)
	var code := Label.new()
	code.theme_type_variation = &"JadeSubtitle"
	code.add_theme_font_size_override("font_size", 13)
	code.text = "TRIAL %d-%d" % [chapter_id, preview_stage_id]
	status_row.add_child(code)
	var status_fill := Control.new()
	status_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_fill)
	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", _stage_status_color(status, accent))
	status_label.text = status
	status_row.add_child(status_label)
	var title := Label.new()
	title.theme_type_variation = &"JadeHeroName"
	title.add_theme_font_size_override("font_size", 21)
	title.text = str(data.get("display_name", "Unknown Trial"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(title)
	var hint := Label.new()
	hint.theme_type_variation = &"JadeMutedLabel"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.80, 0.85, 0.84, 1.0))
	hint.text = str(data.get("description", ""))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.max_lines_visible = 2
	text_box.add_child(hint)
	var reward := Label.new()
	reward.theme_type_variation = &"JadeSubtitle"
	reward.add_theme_font_size_override("font_size", 12)
	reward.add_theme_color_override("font_color", Color(1.0, 0.84, 0.50, 1.0))
	var first_clear: bool = not JourneyManager.is_stage_cleared(
		chapter_id,
		preview_stage_id
	)
	var reward_data: Dictionary = RewardManager.get_stage_clear_reward(
		chapter_id,
		preview_stage_id,
		first_clear
	)
	var summary: String = RewardManager.get_reward_summary(
		RewardManager.preview_received_reward(reward_data)
	)
	reward.text = (
		("FIRST CLEAR" if first_clear else "REPLAY REWARD")
		+ " • "
		+ summary
	)
	text_box.add_child(reward)
	start_button = Button.new()
	start_button.custom_minimum_size = Vector2(0.0, 50.0)
	start_button.theme_type_variation = &"JadePrimaryButton"
	start_button.add_theme_font_size_override("font_size", 16)
	start_button.text = "BEGIN TRIAL" if can_start else ("TRIAL LOCKED" if status == "LOCKED" else "SELECT TRIAL")
	start_button.disabled = not can_start
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(_on_start_pressed)
	text_box.add_child(start_button)
	return panel


func _on_stage_node_pressed(stage_id: int) -> void:
	preview_stage_id = stage_id
	if JourneyManager.is_stage_unlocked(chapter_id, stage_id) and JourneyManager.is_stage_implemented(chapter_id, stage_id):
		JourneyManager.select_stage(chapter_id, stage_id)
	_refresh_screen()


func _on_start_pressed() -> void:
	if start_button == null or start_button.disabled:
		return
	if SaveManager.has_save_file("checkpoint"):
		_show_start_confirm_dialog()
		return
	_start_selected_stage()


func _build_confirm_overlay() -> void:
	confirm_overlay = ColorRect.new()
	start_confirm_dialog = confirm_overlay
	confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_overlay.hide()
	add_child(confirm_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520.0, 300.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.004, 0.018, 0.025, 0.99), Color(GOLD.r, GOLD.g, GOLD.b, 0.84), 16, 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.text = "ABANDON CURRENT TRIAL?"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(eyebrow)
	confirm_stage_label = Label.new()
	confirm_stage_label.theme_type_variation = &"JadeTitle"
	confirm_stage_label.add_theme_font_size_override("font_size", 25)
	confirm_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(confirm_stage_label)
	confirm_body_label = Label.new()
	confirm_body_label.theme_type_variation = &"JadeMutedLabel"
	confirm_body_label.add_theme_font_size_override("font_size", 14)
	confirm_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(confirm_body_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var cancel := Button.new()
	cancel.custom_minimum_size = Vector2(0.0, 52.0)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.text = "CANCEL"
	cancel.pressed.connect(_hide_start_confirm_dialog)
	buttons.add_child(cancel)
	var start_new := Button.new()
	start_new.custom_minimum_size = Vector2(0.0, 52.0)
	start_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_new.theme_type_variation = &"JadePrimaryButton"
	start_new.text = "START NEW"
	start_new.pressed.connect(_confirm_start_new_stage)
	buttons.add_child(start_new)


func _show_start_confirm_dialog() -> void:
	var data := JourneyManager.get_selected_stage_data()
	confirm_stage_label.text = str(data.get("display_name", "Selected Trial"))
	confirm_body_label.text = "A saved run already exists. Starting this trial will replace that checkpoint."
	confirm_overlay.show()


func _hide_start_confirm_dialog() -> void:
	confirm_overlay.hide()


func _confirm_start_new_stage() -> void:
	_hide_start_confirm_dialog()
	_start_selected_stage()


func _start_selected_stage() -> void:
	if SaveManager.is_progress_read_only():
		return
	var data := JourneyManager.get_selected_stage_data()
	if data.is_empty():
		push_error("StageSelect: selected stage data is unavailable.")
		return
	var expected_scene_path := str(data.get("scene_path", ""))
	if expected_scene_path.is_empty() or not ResourceLoader.exists(expected_scene_path):
		push_error("StageSelect: stage scene is unavailable: " + expected_scene_path)
		return
	if not _delete_checkpoint_if_present():
		return
	GameSession.start_new_game()
	var stage_scene_path := JourneyManager.begin_selected_stage()
	if stage_scene_path.is_empty():
		push_error("StageSelect: JourneyManager failed to begin selected stage.")
		return
	var change_error := SceneTransitionManager.transition_to(stage_scene_path, {
		"title": str(data.get("display_name", "Entering the trial")),
		"subtitle": "Stage %d-%d" % [JourneyManager.active_run_chapter_id, JourneyManager.active_run_stage_id],
		"minimum_display_time": 0.65,
	})
	if change_error != OK:
		JourneyManager.clear_active_run()
		push_error("StageSelect: failed to open stage. Error code: " + str(change_error))


func _delete_checkpoint_if_present() -> bool:
	var result := SaveManager.reset_active_run_saves()
	if bool(result.get("success", false)):
		return true
	push_error("StageSelect: failed to clear active-run save: " + str(result.get("failed_domain_ids", [])))
	return false


func _add_route_segment(canvas: Control, start: Vector2, finish: Vector2, accent: Color, status: String) -> void:
	var glow_color := Color(0.24, 0.30, 0.30, 0.08)
	var core_color := Color(0.36, 0.42, 0.42, 0.34)
	if status == "CLEARED":
		glow_color = Color(accent.r, accent.g, accent.b, 0.22)
		core_color = Color(accent.r, accent.g, accent.b, 0.90)
	elif status == "CURRENT":
		glow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.22)
		core_color = accent.lerp(GOLD, 0.42)
	var glow := Line2D.new()
	glow.width = 11.0
	glow.default_color = glow_color
	glow.points = PackedVector2Array([start, finish])
	glow.antialiased = true
	canvas.add_child(glow)
	var core := Line2D.new()
	core.width = 3.0 if status != "LOCKED" else 2.0
	core.default_color = core_color
	core.points = PackedVector2Array([start, finish])
	core.antialiased = true
	canvas.add_child(core)


func _add_stage_seal_asset(canvas: Control, point: Vector2, status: String, is_boss: bool, selected: bool) -> void:
	var frame_size := 172.0 if is_boss else 124.0
	var texture_key := "BOSS" if is_boss else status
	var frame := TextureRect.new()
	frame.position = point - Vector2(frame_size, frame_size) * 0.5
	frame.size = Vector2(frame_size, frame_size)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.texture = seal_textures.get(texture_key, seal_textures.get("LOCKED")) as Texture2D
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status == "LOCKED":
		frame.modulate = Color(0.82, 0.84, 0.84, 0.92)
	if selected and status != "LOCKED":
		var halo_size := frame_size + 22.0
		var halo := Panel.new()
		halo.position = point - Vector2(halo_size, halo_size) * 0.5
		halo.size = Vector2(halo_size, halo_size)
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		halo.add_theme_stylebox_override("panel", _make_panel_style(Color(GOLD.r, GOLD.g, GOLD.b, 0.02), Color(GOLD.r, GOLD.g, GOLD.b, 0.22), int(halo_size * 0.5), 1))
		canvas.add_child(halo)
	canvas.add_child(frame)


func _apply_stage_node_style(button: Button, status: String, is_boss: bool, selected: bool) -> void:
	var fill := Color(0.0, 0.012, 0.018, 0.10)
	if status == "LOCKED":
		fill = Color(0.0, 0.008, 0.012, 0.18)
	var border := Color(GOLD.r, GOLD.g, GOLD.b, 0.34) if selected else Color.TRANSPARENT
	var width := 1 if selected else 0
	var radius := 52 if is_boss else 39
	button.add_theme_stylebox_override("normal", _make_panel_style(fill, border, radius, width))
	button.add_theme_stylebox_override("hover", _make_panel_style(fill.lightened(0.08), border, radius, width))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.0, 0.008, 0.012, 0.28), border, radius, width))


func _add_stage_label_plate(canvas: Control, point: Vector2, data: Dictionary, status: String, accent: Color, is_boss: bool, selected: bool, occupied: Array[Rect2], map_height: float) -> Rect2:
	var border_color := _stage_status_color(status, accent)
	var desired: Rect2
	if is_boss:
		desired = Rect2(Vector2(104.0, point.y + 94.0), Vector2(404.0, 64.0))
	elif point.x < 300.0:
		desired = Rect2(Vector2(point.x + 68.0, point.y - 32.0), Vector2(304.0, 64.0))
	else:
		desired = Rect2(Vector2(18.0, point.y - 32.0), Vector2(350.0, 64.0))
	var safe_rect := _resolve_stage_label_rect(desired, occupied, map_height)
	var plate := PanelContainer.new()
	plate.position = safe_rect.position
	plate.size = safe_rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _make_panel_style(Color(0.002, 0.014, 0.020, 0.84 if selected else 0.74), Color(border_color.r, border_color.g, border_color.b, 0.24), 9, 1))
	canvas.add_child(plate)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	plate.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	margin.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18 if is_boss else 16)
	title.add_theme_color_override("font_color", TEXT_MAIN)
	title.text = str(data.get("display_name", "Trial"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible = 2
	if is_boss:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif point.x >= 300.0:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(title)
	var state := Label.new()
	state.add_theme_font_size_override("font_size", 12)
	state.add_theme_color_override("font_color", border_color)
	state.text = ("REALM BOSS • " if is_boss else "") + status
	if is_boss:
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif point.x >= 300.0:
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(state)
	return safe_rect


func _resolve_stage_label_rect(desired: Rect2, occupied: Array[Rect2], map_height: float) -> Rect2:
	var resolved := desired
	var maximum_y := maxf(8.0, map_height - resolved.size.y - 8.0)
	resolved.position.y = clampf(resolved.position.y, 8.0, maximum_y)
	for _pass_index in range(8):
		var moved := false
		for other: Rect2 in occupied:
			if not resolved.grow(8.0).intersects(other):
				continue
			if resolved.get_center().y <= other.get_center().y:
				resolved.position.y = other.position.y - resolved.size.y - 12.0
			else:
				resolved.position.y = other.position.y + other.size.y + 12.0
			resolved.position.y = clampf(resolved.position.y, 8.0, maximum_y)
			moved = true
			break
		if not moved:
			break
	return resolved


func _stage_status_color(status: String, accent: Color) -> Color:
	if status == "CLEARED":
		return accent
	if status == "AVAILABLE" or status == "CURRENT":
		return GOLD
	return Color(0.62, 0.66, 0.66, 1.0)


func _scroll_stage_map_to_selected(metrics: Dictionary, stage_ids: Array) -> void:
	if map_scroll == null or stage_ids.is_empty():
		return
	var index := stage_ids.find(preview_stage_id)
	if index < 0:
		return
	var top_y := float(metrics.get("top_y", 122.0))
	var boss_gap := float(metrics.get("boss_gap", 238.0))
	var normal_gap := float(metrics.get("normal_gap", 176.0))
	var distance := stage_ids.size() - 1 - index
	var y := top_y
	if distance > 0:
		y += boss_gap + float(distance - 1) * normal_gap
	map_scroll.scroll_vertical = maxi(int(y - maxf(map_scroll.size.y, 300.0) * 0.42), 0)


func _hide_scrollbar_chrome(scroll: ScrollContainer) -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	for bar: ScrollBar in [scroll.get_v_scroll_bar(), scroll.get_h_scroll_bar()]:
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.focus_mode = Control.FOCUS_NONE
		bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
		bar.add_theme_stylebox_override("scroll", transparent)
		bar.add_theme_stylebox_override("grabber", transparent)
		bar.add_theme_stylebox_override("grabber_highlight", transparent)
		bar.add_theme_stylebox_override("grabber_pressed", transparent)


func _make_panel_style(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style


func handle_system_back() -> void:
	if confirm_overlay != null and confirm_overlay.visible:
		_hide_start_confirm_dialog()
		return
	_on_back_pressed()


func _on_back_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var error := SceneTransitionManager.transition_menu_to(CHAPTER_SELECT_SCENE, -1)
	if error != OK:
		push_error("StageSelect: failed to return to Realm Select. Error code: " + str(error))
