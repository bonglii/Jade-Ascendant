extends "res://scripts/ui/pavilion_screen.gd"

## PAVILION LOCKED DESIGN LAB
## Visual translation of the approved Pavilion redesign.
## This scene is presentation-only: no summon, Wish, ad, forge, or save mutation
## is performed. All manager access is read-only.

const EquipmentCatalog = preload("res://scripts/data/equipment_catalog.gd")

const FEATURED_SET_ID: String = "nine_heavens"
const FEATURED_TITLE: String = "CELESTIAL ARMORY"
const FEATURED_OFFSETS: Array[int] = [-2, -1, 0, 1, 2]

var featured_items: Array[String] = []
var selected_item_id: String = ""
var confirmed_preview_target: String = ""

var featured_row: HBoxContainer
var featured_status_label: Label
var wish_target_label: Label
var wish_state_label: Label
var lab_notice_label: Label
var pity_rare_bar: ProgressBar
var pity_epic_bar: ProgressBar
var pity_legendary_bar: ProgressBar
var pity_rare_value: Label
var pity_epic_value: Label
var pity_legendary_value: Label
var lifetime_value: Label

func _ready() -> void:
	content = $SafeArea/Scroll/Content
	SceneTransitionManager.set_back_handler(_back)
	_prepare_pavilion_content()
	_build_wallet_header()
	_sync_wallet_balances()
	_install_pavilion_nav_luxury()
	_load_featured_items()
	_build_locked_pavilion()
	_refresh_read_only_values()

func _load_featured_items() -> void:
	featured_items = EquipmentSetCatalog.get_piece_ids(FEATURED_SET_ID)
	if featured_items.is_empty():
		featured_items = [
			"nine_heavens_star_sword",
			"sovereign_mantle",
			"tribulation_bracer",
			"cloudtreader_boots",
			"ascendant_heart"
		]

	# Keep the LAB fully read-only. The first relic is only a local preview
	# selection and never reads/sanitizes or writes the production Wish target.
	selected_item_id = str(featured_items[0])

func _build_locked_pavilion() -> void:
	content.add_theme_constant_override("separation", 12)
	_build_title_block()
	_build_ritual_stage()
	_build_fate_constellation()
	_build_wish_panel()
	_build_cta_stack()
	_build_lifetime_row()
	_build_rewarded_preview()
	_build_lab_notice()
	_add_bottom_safe_spacer()

func _build_title_block() -> void:
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	content.add_child(title_box)

	_label(title_box, tr("CELESTIAL ARMORY"), 12, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.95))
	var title := _label(title_box, tr("Equipment Summon"), 30, Color(1.0, 0.88, 0.50))
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.58))
	_label(
		title_box,
		tr("Select one of five featured relics as your rate-up target. Pity and Wish Fate persist across sessions."),
		12,
		Color(0.71, 0.82, 0.79, 1.0)
	)

func _build_ritual_stage() -> void:
	var shell := _panel(content, _lab_shell_style())
	shell.custom_minimum_size.y = 360.0

	var stage := Control.new()
	stage.custom_minimum_size.y = 342.0
	stage.clip_contents = true
	shell.add_child(stage)

	var stage_visual: Control = SummonStageVisual.new()
	stage_visual.name = "LockedDesignSummonStage"
	stage.add_child(stage_visual)
	stage_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if stage_visual.has_method("configure"):
		stage_visual.call("configure", VIOLET, GOLD, true, true)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	stage.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var invocation := _state_badge(stack, tr("HEAVENLY RELIC INVOCATION"), VIOLET)
	invocation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	invocation.add_theme_font_size_override("font_size", 11)
	if invocation.get_parent() is PanelContainer:
		(invocation.get_parent() as PanelContainer).custom_minimum_size = Vector2(260.0, 30.0)

	var flexible := Control.new()
	flexible.custom_minimum_size.y = 8.0
	stack.add_child(flexible)

	featured_row = HBoxContainer.new()
	featured_row.alignment = BoxContainer.ALIGNMENT_CENTER
	featured_row.add_theme_constant_override("separation", 7)
	stack.add_child(featured_row)
	_rebuild_featured_row()

	var divider := HSeparator.new()
	divider.modulate = Color(GOLD.r, GOLD.g, GOLD.b, 0.34)
	divider.custom_minimum_size.x = 260.0
	stack.add_child(divider)

	var armory_title := _label(stack, FEATURED_TITLE, 22, Color(1.0, 0.84, 0.42))
	armory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	featured_status_label = _label(stack, "", 10, Color(0.72, 0.82, 0.80, 1.0))
	featured_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	featured_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh_featured_copy()

func _rebuild_featured_row() -> void:
	if featured_row == null:
		return
	for child: Node in featured_row.get_children():
		featured_row.remove_child(child)
		child.queue_free()

	for item_id: String in _ordered_featured_items():
		var is_selected: bool = item_id == selected_item_id
		var button := Button.new()
		button.tooltip_text = _item_display_name(item_id)
		button.custom_minimum_size = Vector2(92.0, 92.0) if is_selected else Vector2(72.0, 72.0)
		button.icon = load(EquipmentVisualCatalog.get_icon_path(item_id)) as Texture2D
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.add_theme_constant_override("icon_max_width", 66 if is_selected else 50)
		button.add_theme_stylebox_override("normal", _relic_circle_style(is_selected, false))
		button.add_theme_stylebox_override("hover", _relic_circle_style(true, true))
		button.add_theme_stylebox_override("pressed", _relic_circle_style(true, false))
		button.add_theme_stylebox_override("focus", _relic_circle_style(is_selected, true))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_select_featured_item.bind(item_id))
		featured_row.add_child(button)

func _ordered_featured_items() -> Array[String]:
	var result: Array[String] = []
	if featured_items.is_empty():
		return result
	var selected_index: int = featured_items.find(selected_item_id)
	if selected_index < 0:
		selected_index = 0
	for offset in FEATURED_OFFSETS:
		var idx: int = posmod(selected_index + offset, featured_items.size())
		result.append(featured_items[idx])
	return result

func _select_featured_item(item_id: String) -> void:
	if item_id not in featured_items:
		return
	selected_item_id = item_id
	_rebuild_featured_row()
	_refresh_featured_copy()
	_refresh_wish_copy()

func _refresh_featured_copy() -> void:
	if featured_status_label == null:
		return
	featured_status_label.text = tr("SELECTED RATE-UP PREVIEW • %s") % _item_display_name(selected_item_id).to_upper()

func _build_fate_constellation() -> void:
	var shell := _panel(content, _lab_section_style(GOLD))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	shell.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var title := _label(header, tr("FATE CONSTELLATION"), 13, Color(1.0, 0.82, 0.38))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tracks := _label(header, tr("GUARANTEE TRACKS"), 11, Color(0.70, 0.78, 0.79, 1.0))
	tracks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	box.add_child(grid)

	var rare := _make_pity_tile(grid, "RARE+", 10, CYAN)
	pity_rare_bar = rare["bar"] as ProgressBar
	pity_rare_value = rare["value"] as Label
	var epic := _make_pity_tile(grid, "EPIC+", 30, VIOLET)
	pity_epic_bar = epic["bar"] as ProgressBar
	pity_epic_value = epic["value"] as Label
	var legendary := _make_pity_tile(grid, "LEGENDARY", 50, GOLD)
	pity_legendary_bar = legendary["bar"] as ProgressBar
	pity_legendary_value = legendary["value"] as Label

func _make_pity_tile(parent_node: Node, caption: String, maximum: int, accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _pity_card_style(accent))
	parent_node.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var cap := _label(box, caption, 11, accent)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value := _label(box, "0 / %d" % maximum, 18, TEXT_MAIN)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = float(maximum)
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size.y = 7.0
	bar.add_theme_stylebox_override("background", _progress_background_style())
	bar.add_theme_stylebox_override("fill", _progress_fill_style(accent))
	box.add_child(bar)
	var guarantee := _label(box, tr("GUARANTEE TRACK"), 9, Color(0.67, 0.74, 0.74, 1.0))
	guarantee.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"bar": bar, "value": value}

func _build_wish_panel() -> void:
	var shell := _panel(content, _wish_panel_style(VIOLET))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	shell.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	_label(copy, tr("LEGENDARY WISH"), 11, Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.96))
	wish_target_label = _label(copy, "", 17, TEXT_MAIN)
	wish_state_label = _label(copy, "", 10, Color(0.69, 0.79, 0.78, 1.0))

	var set_wish := Button.new()
	set_wish.text = tr("SET WISH   ›")
	set_wish.custom_minimum_size = Vector2(240.0, 58.0)
	set_wish.add_theme_font_size_override("font_size", 16)
	set_wish.add_theme_stylebox_override("normal", _wish_button_style(false))
	set_wish.add_theme_stylebox_override("hover", _wish_button_style(true))
	set_wish.add_theme_stylebox_override("pressed", _wish_button_style(true))
	set_wish.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_wish.pressed.connect(_confirm_preview_wish)
	row.add_child(set_wish)
	_refresh_wish_copy()

func _confirm_preview_wish() -> void:
	confirmed_preview_target = selected_item_id
	_refresh_wish_copy()
	_show_lab_notice(tr("Preview target set locally. Production Wish data was not changed."), GOLD)

func _refresh_wish_copy() -> void:
	if wish_target_label == null or wish_state_label == null:
		return
	if confirmed_preview_target.is_empty():
		wish_target_label.text = tr("NO WISH TARGET")
		wish_state_label.text = tr("Selected preview: %s") % _item_display_name(selected_item_id)
	else:
		wish_target_label.text = _item_display_name(confirmed_preview_target).to_upper()
		wish_state_label.text = tr("RATE-UP PREVIEW TARGET • tap another relic to compare")

func _build_cta_stack() -> void:
	var ten := Button.new()
	ten.text = tr("SUMMON ×10\n900 CELESTIAL JADE • SAVE 10%")
	ten.custom_minimum_size.y = 78.0
	ten.add_theme_font_size_override("font_size", 18)
	ten.add_theme_stylebox_override("normal", _gold_cta_style(false))
	ten.add_theme_stylebox_override("hover", _gold_cta_style(true))
	ten.add_theme_stylebox_override("pressed", _gold_cta_style(true))
	ten.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75, 1.0))
	ten.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ten.pressed.connect(_preview_action.bind("Summon ×10"))
	content.add_child(ten)

	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 8)
	content.add_child(secondary)

	var one := Button.new()
	one.text = tr("SUMMON ×1\n100 CELESTIAL JADE")
	one.custom_minimum_size.y = 58.0
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.add_theme_font_size_override("font_size", 14)
	one.add_theme_stylebox_override("normal", _secondary_cta_style(VIOLET, false))
	one.add_theme_stylebox_override("hover", _secondary_cta_style(VIOLET, true))
	one.add_theme_stylebox_override("pressed", _secondary_cta_style(VIOLET, true))
	one.pressed.connect(_preview_action.bind("Summon ×1"))
	secondary.add_child(one)

	var rates := Button.new()
	rates.text = tr("DROP RATES & PITY RULES   ›")
	rates.custom_minimum_size.y = 58.0
	rates.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rates.add_theme_font_size_override("font_size", 13)
	rates.add_theme_stylebox_override("normal", _secondary_cta_style(CYAN, false))
	rates.add_theme_stylebox_override("hover", _secondary_cta_style(CYAN, true))
	rates.add_theme_stylebox_override("pressed", _secondary_cta_style(CYAN, true))
	rates.pressed.connect(_preview_action.bind("Drop Rates & Pity Rules"))
	secondary.add_child(rates)

func _build_lifetime_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var caption := _label(row, tr("LIFETIME SUMMONS"), 11, Color(0.68, 0.78, 0.77, 1.0))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lifetime_value = _label(row, "0", 13, CYAN)
	lifetime_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_rewarded_preview() -> void:
	var panel := _panel(content, _rewarded_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var icon := Label.new()
	icon.text = "▶"
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override("font_color", JADE)
	row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	_label(copy, tr("OPTIONAL REWARDED AD"), 12, JADE)
	_label(copy, tr("Earn one Pavilion Seal without interrupting the summon hierarchy."), 10, Color(0.68, 0.80, 0.77, 1.0))

	var arrow := Button.new()
	arrow.text = "›"
	arrow.custom_minimum_size = Vector2(46.0, 42.0)
	arrow.flat = true
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_color_override("font_color", JADE)
	arrow.pressed.connect(_preview_action.bind("Optional Rewarded Ad"))
	row.add_child(arrow)

func _build_lab_notice() -> void:
	lab_notice_label = _label(content, "", 10, Color(0.68, 0.76, 0.74, 1.0))
	lab_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab_notice_label.visible = false

func _preview_action(action_name: String) -> void:
	_show_lab_notice(tr("LAB preview only • %s does not call production economy logic.") % action_name, CYAN)

func _show_lab_notice(message: String, accent: Color) -> void:
	if lab_notice_label == null:
		return
	lab_notice_label.text = message
	lab_notice_label.add_theme_color_override("font_color", accent)
	lab_notice_label.visible = true

func _refresh_read_only_values() -> void:
	_sync_wallet_balances()
	var pity: Dictionary = PavilionManager.get_summon_pity_status()

	var rare_counter: int = int(pity.get("rare_plus_counter", 0))
	var epic_counter: int = int(pity.get("epic_plus_counter", 0))
	var legendary_counter: int = int(pity.get("legendary_counter", 0))

	pity_rare_bar.value = rare_counter
	pity_epic_bar.value = epic_counter
	pity_legendary_bar.value = legendary_counter
	pity_rare_value.text = "%d / 10" % rare_counter
	pity_epic_value.text = "%d / 30" % epic_counter
	pity_legendary_value.text = "%d / 50" % legendary_counter
	lifetime_value.text = _format_count(PavilionManager.get_lifetime_pulls())

func _item_display_name(item_id: String) -> String:
	var data: Dictionary = EquipmentCatalog.ITEMS.get(item_id, {})
	return str(data.get("display_name", item_id.capitalize()))

func _lab_shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.010, 0.020, 0.86)
	style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.66)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 8
	return style

func _lab_section_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.004, 0.018, 0.030, 0.91)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.32)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _relic_circle_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.020, 0.032, 0.94)
	var alpha := 0.96 if selected else 0.48
	if hovered:
		alpha = 1.0
	style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, alpha)
	var border_width := 2 if selected else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	var radius := 46 if selected else 36
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.18 if selected else 0.05)
	style.shadow_size = 7 if selected else 2
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0
	return style

func _pity_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.003, 0.015, 0.026, 0.92)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.34)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 9.0
	style.content_margin_top = 9.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 9.0
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style

func _progress_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.16, 0.92)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _progress_fill_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _wish_button_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.045, 0.18, 0.98) if not hovered else Color(0.17, 0.065, 0.24, 1.0)
	style.border_color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _gold_cta_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.19, 0.045, 0.98) if not hovered else Color(0.36, 0.24, 0.055, 1.0)
	style.border_color = Color(1.0, 0.79, 0.28, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.20)
	style.shadow_size = 8
	return style

func _secondary_cta_style(accent: Color, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.052, 0.98) if not hovered else Color(0.028, 0.040, 0.075, 1.0)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _rewarded_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.065, 0.070, 0.88)
	style.border_color = Color(JADE.r, JADE.g, JADE.b, 0.65)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
