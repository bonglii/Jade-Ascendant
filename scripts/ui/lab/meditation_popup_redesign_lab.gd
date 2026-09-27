extends Control

## MEDITATION TOTAL REDESIGN LAB V1
## Approved portrait popup direction translated into Godot.
## Presentation-only: no claim, reward, ad, save, or economy writes.

const HubNavScript = preload("res://scripts/ui/wuxia_hub_nav.gd")

const HOME_ART: Texture2D = preload(
	"res://assets/ui/main_menu/main_menu_key_art_lin_yue.png"
)
const SANCTUM_ART: Texture2D = preload(
	"res://assets/ui/cultivation/cultivation_inner_sea_sanctum_v6.png"
)
const MEDITATION_EMBLEM: Texture2D = preload(
	"res://assets/ui/home/liveops_premium/meditation_premium.png"
)
const DAO_CORE_ICON: Texture2D = preload(
	"res://assets/ui/cultivation/meridian_dao_core.png"
)
const RESOURCE_FRAME: Texture2D = preload(
	"res://assets/ui/shared/hub_resource_bar_frame.svg"
)
const SPIRIT_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const JADE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/celestial_jade_premium.png"
)
const SEAL_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/pavilion_seal_premium.png"
)
const HERO_EXP_ICON: Texture2D = preload(
	"res://assets/ui/equipment/polish/ascension_emblem.svg"
)
const CLAIM_BLUE_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_blue.png"
)
const CLAIM_GOLD_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/claim_gold.png"
)
const TIER_RIBBON_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/tier_ribbon.png"
)
const REWARD_SPIRIT_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_spirit.png"
)
const REWARD_HERO_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_hero_exp.png"
)
const REWARD_SHARD_FRAME: Texture2D = preload(
	"res://assets/ui/meditation/premium_popup/reward_shard.png"
)

const GOLD := Color(0.96, 0.76, 0.32, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.54, 1.0)
const JADE := Color(0.29, 0.91, 0.76, 1.0)
const JADE_SOFT := Color(0.47, 0.98, 0.87, 1.0)
const TEXT := Color(0.95, 0.99, 0.97, 1.0)
const MUTED := Color(0.71, 0.82, 0.79, 1.0)
const MOBILE_SCROLL_DEADZONE: int = 6

var popup_panel: PanelContainer = null
var popup_scroll: ScrollContainer = null
var popup_body: VBoxContainer = null


func _ready() -> void:
	_build_home_backdrop()
	_build_resource_bar()
	_build_hub_nav()
	_build_scrim()
	_build_popup()
	call_deferred("_fit_popup_to_content")
	call_deferred("_disable_lab_navigation")


func _build_home_backdrop() -> void:
	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.texture = HOME_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	var dark := ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.color = Color(0.0, 0.010, 0.018, 0.34)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dark)


func _build_resource_bar() -> void:
	var bar := TextureRect.new()
	bar.name = "SharedHubResourceBar"
	bar.anchor_left = 0.03
	bar.anchor_right = 0.97
	bar.offset_top = 5.0
	bar.offset_bottom = 70.0
	bar.texture = RESOURCE_FRAME
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_SCALE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_right = -10.0
	row.add_theme_constant_override("separation", 2)
	bar.add_child(row)

	for data in [
		{"icon": SPIRIT_ICON, "value": "3.570"},
		{"icon": SHARD_ICON, "value": "18"},
		{"icon": JADE_ICON, "value": "90"},
		{"icon": SEAL_ICON, "value": "4"},
	]:
		row.add_child(_resource_cell(
			data["icon"] as Texture2D,
			str(data["value"])
		))


func _resource_cell(icon_texture: Texture2D, value_text: String) -> Control:
	var cell := HBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 4)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(27.0, 27.0)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", TEXT)
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(value)
	return cell


func _build_hub_nav() -> void:
	var nav := Control.new()
	nav.name = "HubNav"
	nav.anchor_left = 0.03
	nav.anchor_top = 1.0
	nav.anchor_right = 0.97
	nav.anchor_bottom = 1.0
	nav.offset_top = -84.0
	nav.offset_bottom = -4.0
	nav.set_script(HubNavScript)
	nav.set("active_tab", 0)
	add_child(nav)


func _build_scrim() -> void:
	var scrim := ColorRect.new()
	scrim.anchor_left = 0.0
	scrim.anchor_top = 0.0
	scrim.anchor_right = 1.0
	scrim.anchor_bottom = 1.0
	scrim.offset_top = 70.0
	scrim.offset_bottom = -84.0
	scrim.color = Color(0.0, 0.006, 0.012, 0.64)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)


func _build_popup() -> void:
	popup_panel = PanelContainer.new()
	popup_panel.name = "MeditationPopupPreview"
	popup_panel.anchor_left = 0.045
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_right = 0.955
	popup_panel.anchor_bottom = 0.5
	popup_panel.offset_top = 0.0
	popup_panel.offset_bottom = 0.0
	popup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.002, 0.020, 0.028, 0.992),
			Color(0.98, 0.78, 0.32, 0.94),
			20,
			18
		)
	)
	add_child(popup_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	popup_panel.add_child(margin)

	popup_scroll = ScrollContainer.new()
	popup_scroll.name = "MeditationPopupScroll"
	popup_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup_scroll.scroll_deadzone = MOBILE_SCROLL_DEADZONE
	popup_scroll.follow_focus = false
	popup_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_child(popup_scroll)

	popup_body = VBoxContainer.new()
	popup_body.name = "MeditationPopupBody"
	popup_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_body.add_theme_constant_override("separation", 8)
	popup_scroll.add_child(popup_body)

	popup_body.add_child(_build_header())
	popup_body.add_child(_build_sanctum_hero())
	popup_body.add_child(_build_status_row())
	popup_body.add_child(_build_rewards())
	popup_body.add_child(_build_claim_row())


func _fit_popup_to_content() -> void:
	if (
		popup_panel == null
		or popup_scroll == null
		or popup_body == null
		or not is_instance_valid(popup_panel)
	):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var desired_height: float = ceilf(
		popup_body.get_combined_minimum_size().y + 22.0
	)
	var available_height: float = maxf(
		size.y - 178.0,
		420.0
	)
	var final_height: float = minf(
		desired_height,
		available_height
	)
	var half_height: float = final_height * 0.5

	popup_panel.offset_top = -half_height
	popup_panel.offset_bottom = half_height

	var needs_scroll: bool = (
		desired_height > available_height + 1.0
	)
	if needs_scroll:
		popup_scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_SHOW_NEVER
			if OS.has_feature("android") or OS.has_feature("ios")
			else ScrollContainer.SCROLL_MODE_AUTO
		)
		_make_scroll_tree_touch_safe(popup_body)
	else:
		popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _make_scroll_tree_touch_safe(root: Node) -> void:
	for child: Node in root.get_children():
		if child is Button:
			var button := child as Button
			button.mouse_filter = Control.MOUSE_FILTER_PASS
			button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			button.keep_pressed_outside = false
		elif child is Label or child is TextureRect:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif child is Control:
			var control := child as Control
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				control.mouse_filter = Control.MOUSE_FILTER_PASS

		_make_scroll_tree_touch_safe(child)


func _build_header() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -1)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)

	var spacer := Control.new()
	spacer.custom_minimum_size.x = 42.0
	top.add_child(spacer)

	var title := _label("SPIRIT MEDITATION", 30, GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title)

	var close := Button.new()
	close.custom_minimum_size = Vector2(42.0, 42.0)
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_color_override("font_color", GOLD_BRIGHT)
	close.add_theme_stylebox_override(
		"normal",
		_round_style(
			Color(0.002, 0.035, 0.045, 0.96),
			Color(0.96, 0.77, 0.32, 0.82),
			21
		)
	)
	top.add_child(close)

	var subtitle := _label(
		"Refine Qi  •  Accumulate Resources  •  Even While Away",
		14,
		Color(0.83, 0.91, 0.88, 1.0)
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	return box


func _build_sanctum_hero() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0.0, 334.0)
	frame.clip_contents = true
	frame.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.0, 0.018, 0.026, 0.96),
			Color(0.31, 0.89, 0.77, 0.54),
			18,
			8
		)
	)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 0.0
	art.offset_top = 0.0
	art.offset_right = 0.0
	art.offset_bottom = 0.0
	art.texture = _load_meditation_hero_texture()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.012, 0.018, 0.05)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(shade)

	var inner_glow := PanelContainer.new()
	inner_glow.anchor_left = 0.5
	inner_glow.anchor_top = 0.5
	inner_glow.anchor_right = 0.5
	inner_glow.anchor_bottom = 0.5
	inner_glow.offset_left = -126.0
	inner_glow.offset_top = -110.0
	inner_glow.offset_right = 126.0
	inner_glow.offset_bottom = 110.0
	inner_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_glow.add_theme_stylebox_override(
		"panel",
		_round_style(
			Color(0.05, 0.78, 0.80, 0.10),
			Color(0.98, 0.80, 0.34, 0.34),
			26
		)
	)
	frame.add_child(inner_glow)


	var hero_title := _label("INNER SEA SANCTUM", 15, Color(1.0, 0.88, 0.55, 0.96))
	hero_title.anchor_left = 0.0
	hero_title.anchor_top = 1.0
	hero_title.anchor_right = 1.0
	hero_title.anchor_bottom = 1.0
	hero_title.offset_top = -34.0
	hero_title.offset_bottom = -9.0
	hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(hero_title)
	return frame


func _build_tier_ribbon() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0.0, 82.0)
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", transparent)

	var frame := TextureRect.new()
	frame.anchor_left = 0.0
	frame.anchor_top = 0.0
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = -48.0
	frame.offset_top = -2.0
	frame.offset_right = 48.0
	frame.offset_bottom = 2.0
	frame.texture = TIER_RIBBON_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(50.0, 50.0)
	icon.texture = MEDITATION_EMBLEM
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", -1)
	row.add_child(copy)

	copy.add_child(_label("CULTIVATION TIER", 12, JADE_SOFT))
	copy.add_child(_label("JADE MERIDIAN FLOW", 21, TEXT))
	copy.add_child(_label("QI RESONANCE 03", 12, GOLD_BRIGHT))

	var details := Button.new()
	details.custom_minimum_size = Vector2(108.0, 40.0)
	details.text = "VIEW DETAILS"
	details.focus_mode = Control.FOCUS_NONE
	details.mouse_filter = Control.MOUSE_FILTER_PASS
	details.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	details.keep_pressed_outside = false
	details.add_theme_font_size_override("font_size", 13)
	details.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0, 1.0))
	details.add_theme_stylebox_override(
		"normal",
		_panel_style(
			Color(0.006, 0.070, 0.092, 0.90),
			Color(0.34, 0.76, 0.96, 0.68),
			11,
			3
		)
	)
	row.add_child(details)
	return panel


func _build_status_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	row.add_child(_status_card(
		"ACCUMULATED TIME",
		"08:20:00",
		"12H OFFLINE CAP",
		GOLD_BRIGHT
	))
	row.add_child(_status_card(
		"CURRENT SPIRITUAL YIELD",
		"60 STONE / H",
		"12 HERO EXP / H",
		JADE_SOFT
	))
	return row


func _status_card(
	heading: String,
	value_text: String,
	footnote: String,
	accent: Color
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 92.0)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.002, 0.032, 0.043, 0.97),
			Color(accent.r, accent.g, accent.b, 0.48),
			13,
			4
		)
	)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)

	var heading_label := _label(heading, 12, accent)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading_label)

	var value := _label(value_text, 20, TEXT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)

	var note := _label(footnote, 11, MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	return panel


func _build_rewards() -> Control:
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.005, 0.027, 0.034, 0.94),
			Color(0.95, 0.73, 0.27, 0.54),
			15,
			5
		)
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	shell.add_child(box)

	var heading := _label("ESTIMATED REWARDS", 15, GOLD_BRIGHT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	box.add_child(row)

	row.add_child(_premium_reward_card(
		REWARD_SPIRIT_FRAME,
		SPIRIT_ICON,
		"SPIRIT STONE",
		"480"
	))
	row.add_child(_premium_reward_card(
		REWARD_HERO_FRAME,
		HERO_EXP_ICON,
		"HERO EXP",
		"96"
	))
	row.add_child(_premium_reward_card(
		REWARD_SHARD_FRAME,
		SHARD_ICON,
		"REFINEMENT",
		"2"
	))
	return shell


func _premium_reward_card(
	frame_texture: Texture2D,
	icon_texture: Texture2D,
	name_text: String,
	amount_text: String
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 116.0)
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", transparent)

	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = frame_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -1)
	panel.add_child(box)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var amount := _label(amount_text, 19, GOLD_BRIGHT)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(amount)

	var name_label := _label(name_text, 12, Color(0.83, 0.91, 0.88, 1.0))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return panel


func _build_claim_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	row.add_child(_premium_cta(
		CLAIM_BLUE_FRAME,
		"CLAIM 1×",
		Color(0.94, 0.99, 1.0, 1.0)
	))
	row.add_child(_premium_cta(
		CLAIM_GOLD_FRAME,
		"WATCH AD  •  CLAIM 2×",
		Color(0.19, 0.10, 0.015, 1.0)
	))
	return row


func _premium_cta(
	frame_texture: Texture2D,
	text_value: String,
	font_color: Color
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 66.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.keep_pressed_outside = false
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)

	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var transparent := StyleBoxFlat.new()
		transparent.bg_color = Color.TRANSPARENT
		button.add_theme_stylebox_override(state_name, transparent)

	var frame := TextureRect.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.texture = frame_texture
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.show_behind_parent = true
	button.add_child(frame)

	return button


func _disable_lab_navigation() -> void:
	var nav := get_node_or_null("HubNav")
	if nav == null:
		return
	for child in nav.get_children():
		if child is Button:
			(child as Button).disabled = true



func _load_meditation_hero_texture() -> Texture2D:
	var path := "res://assets/ui/meditation/premium_popup/meditation_hero_sanctum.png"
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return SANCTUM_ART
	var texture := ImageTexture.create_from_image(image)
	if texture == null:
		return SANCTUM_ART
	return texture



func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _panel_style(
	background: Color,
	border: Color,
	radius: int,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = shadow_size
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


func _round_style(
	background: Color,
	border: Color,
	radius: int
) -> StyleBoxFlat:
	return _panel_style(background, border, radius, 6)
