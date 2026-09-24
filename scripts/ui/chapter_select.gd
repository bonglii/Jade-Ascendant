extends Control

## Production Realm Select — cinematic, data-driven, scalable.
## Progression/save authority remains JourneyManager. Browsing a locked realm never writes save state.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const STAGE_SELECT_SCENE := "res://scenes/ui/stage_select.tscn"
const JourneyVisualCatalog = preload("res://scripts/ui/journey_visual_catalog.gd")
const JourneyArtCatalog = preload("res://scripts/ui/journey_art_catalog.gd")
const MobileSafeAreaScript = preload("res://scripts/ui/mobile_safe_area.gd")

const ROMAN := {1: "I", 2: "II", 3: "III"}
const GOLD := Color(0.957, 0.78, 0.357, 1.0)
const TEXT_MAIN := Color(0.95, 0.96, 0.93, 1.0)
const TEXT_MUTED := Color(0.74, 0.80, 0.80, 1.0)

var preview_chapter_id: int = 1
var realm_textures: Dictionary = {}
var background_texture: TextureRect
var view_host: Control
var top_context_label: Label


func _ready() -> void:
	preview_chapter_id = JourneyManager.selected_chapter_id
	if not JourneyManager.has_chapter(preview_chapter_id):
		preview_chapter_id = 1
	_load_realm_textures()
	_build_shell()
	_show_realm_view()
	SceneTransitionManager.set_back_handler(handle_system_back)


func _load_realm_textures() -> void:
	realm_textures.clear()
	for raw_id: Variant in JourneyManager.get_chapter_ids():
		var chapter_id: int = int(raw_id)
		var path: String = JourneyArtCatalog.get_realm_vista_path(chapter_id)
		var resource: Resource = ResourceLoader.load(path, "Texture2D")
		var texture := resource as Texture2D
		if texture == null:
			push_error("ChapterSelect: failed to load realm artwork: " + path)
			continue
		realm_textures[chapter_id] = texture


func _build_shell() -> void:
	background_texture = TextureRect.new()
	background_texture.name = "RealmArtwork"
	background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_texture)

	var veil_gradient := Gradient.new()
	veil_gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.36, 0.58, 0.78, 1.0])
	veil_gradient.colors = PackedColorArray([
		Color(0.0, 0.008, 0.014, 0.62),
		Color(0.0, 0.008, 0.014, 0.28),
		Color(0.0, 0.008, 0.014, 0.06),
		Color(0.0, 0.008, 0.014, 0.14),
		Color(0.0, 0.008, 0.014, 0.54),
		Color(0.0, 0.008, 0.014, 0.88),
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

	var accent := ColorRect.new()
	accent.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	accent.custom_minimum_size = Vector2(0.0, 3.0)
	accent.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.78)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var safe_host := Control.new()
	safe_host.name = "SafeArea"
	safe_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe_host.set_script(MobileSafeAreaScript)
	add_child(safe_host)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 18)
	safe.add_theme_constant_override("margin_top", 18)
	safe.add_theme_constant_override("margin_right", 18)
	safe.add_theme_constant_override("margin_bottom", 18)
	safe_host.add_child(safe)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 8)
	safe.add_child(main)

	var top_bar := HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0.0, 50.0)
	top_bar.add_theme_constant_override("separation", 10)
	main.add_child(top_bar)

	var back := Button.new()
	back.custom_minimum_size = Vector2(118.0, 48.0)
	back.text = "‹   REALM"
	back.theme_type_variation = &"JadeBackButton"
	back.add_theme_font_size_override("font_size", 15)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(_on_back_pressed)
	top_bar.add_child(back)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	top_context_label = Label.new()
	top_context_label.theme_type_variation = &"JadeNavLabel"
	top_context_label.add_theme_font_size_override("font_size", 13)
	top_context_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(top_context_label)

	view_host = Control.new()
	view_host.name = "ViewHost"
	view_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(view_host)


func _show_realm_view() -> void:
	_clear_view_host()
	_apply_realm_artwork(preview_chapter_id)
	var chapter_data := JourneyManager.get_chapter_data(preview_chapter_id)
	var profile := JourneyVisualCatalog.get_chapter_profile(preview_chapter_id)
	var accent: Color = profile.get("accent", Color(0.30, 0.82, 0.65, 1.0))
	var chapter_ids: Array = JourneyManager.get_chapter_ids()
	var realm_index: int = chapter_ids.find(preview_chapter_id)
	var is_unlocked: bool = JourneyManager.is_chapter_unlocked(preview_chapter_id)
	var presentation_stage_ids: Array = JourneyArtCatalog.get_presentation_stage_ids(
		preview_chapter_id,
		JourneyManager.get_stage_ids(preview_chapter_id)
	)
	var total_stages: int = presentation_stage_ids.size()
	var cleared_stages: int = 0
	for raw_stage_id: Variant in presentation_stage_ids:
		if JourneyManager.is_stage_cleared(preview_chapter_id, int(raw_stage_id)):
			cleared_stages += 1

	top_context_label.text = "CELESTIAL JOURNEY"

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	view_host.add_child(layout)

	var visual_spacer := Control.new()
	visual_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(visual_spacer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 446.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.003, 0.018, 0.027, 0.88), Color(accent.r, accent.g, accent.b, 0.34), 16, 1))
	layout.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.theme_type_variation = &"JadeSubtitle"
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.text = "REALM %s   •   %s" % [_roman(preview_chapter_id), str(profile.get("realm_mark", "ASCEND"))]
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)

	var title := Label.new()
	title.theme_type_variation = &"JadeTitle"
	title.add_theme_font_size_override("font_size", 34)
	title.text = str(chapter_data.get("display_name", "Unknown Realm")).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)

	var epithet := Label.new()
	epithet.theme_type_variation = &"JadeHeroName"
	epithet.add_theme_font_size_override("font_size", 16)
	epithet.add_theme_color_override("font_color", accent)
	epithet.text = str(profile.get("realm_epithet", "CULTIVATION REALM"))
	epithet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(epithet)

	var hint := Label.new()
	hint.theme_type_variation = &"JadeMutedLabel"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.80, 0.85, 0.84, 1.0))
	hint.text = str(profile.get("realm_hint", ""))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	var progress_row := HBoxContainer.new()
	content.add_child(progress_row)
	var progress_label := Label.new()
	progress_label.theme_type_variation = &"JadeSubtitle"
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.text = "%d / %d TRIALS CLEARED" % [cleared_stages, total_stages]
	progress_row.add_child(progress_label)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(fill)
	var state_label := Label.new()
	state_label.theme_type_variation = &"JadeMutedLabel"
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", accent if is_unlocked else TEXT_MUTED)
	state_label.text = "UNLOCKED" if is_unlocked else "LOCKED"
	progress_row.add_child(state_label)

	var progress_bar := ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(0.0, 14.0)
	progress_bar.min_value = 0.0
	progress_bar.max_value = float(maxi(total_stages, 1))
	progress_bar.value = float(cleared_stages)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.01, 0.04, 0.05, 0.92), Color(accent.r, accent.g, accent.b, 0.26), 7, 1))
	progress_bar.add_theme_stylebox_override("fill", _make_panel_style(Color(accent.r, accent.g, accent.b, 0.90), Color(accent.r, accent.g, accent.b, 0.98), 7, 0))
	content.add_child(progress_bar)

	var rail_header := HBoxContainer.new()
	content.add_child(rail_header)
	var rail_label := Label.new()
	rail_label.theme_type_variation = &"JadeSubtitle"
	rail_label.add_theme_font_size_override("font_size", 13)
	rail_label.text = "ASCENSION REALMS   •   SWIPE TO PREVIEW"
	rail_header.add_child(rail_label)
	var rail_spacer := Control.new()
	rail_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail_header.add_child(rail_spacer)
	var count := Label.new()
	count.theme_type_variation = &"JadeMutedLabel"
	count.add_theme_font_size_override("font_size", 12)
	count.text = "%d / %d" % [realm_index + 1, chapter_ids.size()]
	rail_header.add_child(count)

	var rail_scroll := ScrollContainer.new()
	rail_scroll.custom_minimum_size = Vector2(0.0, 134.0)
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hide_scrollbar_chrome(rail_scroll)
	content.add_child(rail_scroll)
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", 12)
	rail_scroll.add_child(rail)
	_build_realm_rail(rail)

	var enter := Button.new()
	enter.custom_minimum_size = Vector2(0.0, 64.0)
	enter.theme_type_variation = &"JadePrimaryButton"
	enter.add_theme_font_size_override("font_size", 20)
	enter.text = "ENTER REALM" if is_unlocked else "REALM LOCKED"
	enter.disabled = not is_unlocked
	enter.focus_mode = Control.FOCUS_NONE
	enter.pressed.connect(_on_enter_realm_pressed)
	content.add_child(enter)


func _build_realm_rail(rail: HBoxContainer) -> void:
	for raw_id: Variant in JourneyManager.get_chapter_ids():
		var chapter_id := int(raw_id)
		var selected := chapter_id == preview_chapter_id
		var chapter_data := JourneyManager.get_chapter_data(chapter_id)
		var unlocked := JourneyManager.is_chapter_unlocked(chapter_id)
		var card := Control.new()
		card.custom_minimum_size = Vector2(204.0, 126.0)
		rail.add_child(card)
		var image := TextureRect.new()
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		image.texture = realm_textures.get(chapter_id) as Texture2D
		image.modulate = Color.WHITE if unlocked else Color(0.62, 0.62, 0.64, 0.88)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(image)
		var shade := ColorRect.new()
		shade.anchor_top = 0.50
		shade.anchor_right = 1.0
		shade.anchor_bottom = 1.0
		shade.color = Color(0.0, 0.008, 0.014, 0.78)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(shade)
		var label := Label.new()
		label.anchor_left = 0.05
		label.anchor_top = 0.54
		label.anchor_right = 0.95
		label.anchor_bottom = 0.96
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", TEXT_MAIN)
		label.text = "%s   %s" % [_roman(chapter_id), str(chapter_data.get("display_name", "Realm"))]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		if selected:
			var border := Panel.new()
			border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			border.add_theme_stylebox_override("panel", _make_panel_style(Color.TRANSPARENT, GOLD, 3, 2))
			card.add_child(border)
		var click := Button.new()
		click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		click.flat = true
		click.focus_mode = Control.FOCUS_NONE
		click.pressed.connect(_on_realm_card_pressed.bind(chapter_id))
		card.add_child(click)


func _on_realm_card_pressed(chapter_id: int) -> void:
	preview_chapter_id = chapter_id
	_show_realm_view()


func _on_enter_realm_pressed() -> void:
	_on_chapter_pressed(preview_chapter_id)


func _on_chapter_pressed(chapter_id: int) -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not JourneyManager.select_chapter(chapter_id):
		return
	var error := SceneTransitionManager.transition_menu_to(STAGE_SELECT_SCENE, 1)
	if error != OK:
		push_error("ChapterSelect: failed to open Stage Select. Error code: " + str(error))


func _apply_realm_artwork(chapter_id: int) -> void:
	background_texture.texture = realm_textures.get(chapter_id) as Texture2D
	var profile := JourneyVisualCatalog.get_chapter_profile(chapter_id)
	var accent: Color = profile.get("accent", Color(0.30, 0.82, 0.65, 1.0))
	background_texture.modulate = Color(0.90 + accent.r * 0.05, 0.90 + accent.g * 0.05, 0.90 + accent.b * 0.05, 1.0)


func _clear_view_host() -> void:
	for child: Node in view_host.get_children():
		view_host.remove_child(child)
		child.queue_free()


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


func _roman(chapter_id: int) -> String:
	if ROMAN.has(chapter_id):
		return str(ROMAN[chapter_id])
	var value: int = maxi(chapter_id, 1)
	var symbols: Array = [
		[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]
	]
	var result: String = ""
	for raw_symbol: Variant in symbols:
		var symbol: Array = raw_symbol
		var amount: int = int(symbol[0])
		while value >= amount:
			result += str(symbol[1])
			value -= amount
	return result


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
	_on_back_pressed()


func _on_back_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	var error := SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if error != OK:
		push_error("ChapterSelect: failed to return to Main Menu. Error code: " + str(error))
