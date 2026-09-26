extends Control

## Pavilion Ritual Hub LAB V1.
## Presentation-only. No summon, save, currency, inventory, reward, or progression write occurs here.

const SummonStageVisual = preload("res://scripts/ui/pavilion_summon_stage.gd")

const SANCTUARY_BANNER: String = "res://assets/ui/pavilion/polish/pavilion_sanctuary_banner.svg"
const PAVILION_SEAL_ICON: String = "res://assets/ui/pavilion/polish/pavilion_seal.svg"
const CELESTIAL_JADE_ICON: String = "res://assets/ui/pavilion/polish/celestial_jade.svg"
const WISH_RELIC_ICON: String = "res://assets/ui/pavilion/polish/wanderer_jade_jian.svg"
const SPIRIT_STONE_ICON: String = "res://assets/ui/icons/spirit_stone.svg"
const REFINEMENT_SHARD_ICON: String = "res://assets/ui/equipment/refinement_shard.svg"
const MEDITATION_ICON: String = "res://assets/ui/pavilion/icons/meditation.png"
const AURA_ICON: String = "res://assets/ui/pavilion/polish/aura_preview_ascendant.svg"
const FORGE_ICON: String = "res://assets/ui/pavilion/icons/refinement_shard.png"

const OBSIDIAN: Color = Color(0.002, 0.014, 0.024, 0.96)
const OBSIDIAN_SOFT: Color = Color(0.006, 0.030, 0.045, 0.92)
const JADE: Color = Color(0.28, 0.95, 0.78, 1.0)
const JADE_SOFT: Color = Color(0.18, 0.62, 0.54, 1.0)
const GOLD: Color = Color(0.98, 0.78, 0.30, 1.0)
const GOLD_BRIGHT: Color = Color(1.0, 0.89, 0.55, 1.0)
const VIOLET: Color = Color(0.72, 0.48, 0.96, 1.0)
const CYAN: Color = Color(0.30, 0.83, 0.96, 1.0)
const TEXT_MAIN: Color = Color(0.93, 0.97, 0.95, 1.0)
const TEXT_MUTED: Color = Color(0.62, 0.74, 0.71, 1.0)

var content: VBoxContainer
var ritual_stage_visual: Control
var ritual_shell: PanelContainer
var ritual_icon_frame: PanelContainer
var ritual_icon: TextureRect
var ritual_state_label: Label
var ritual_title_label: Label
var ritual_subtitle_label: Label
var wish_chip_label: Label
var summon_one_button: Button
var summon_ten_button: Button
var preview_buttons: Array[Button] = []
var preview_mode: int = 0


func _ready() -> void:
	content = $SafeArea/Scroll/Content
	_configure_backdrop()
	_hide_scrollbar_chrome()
	_build_lab()
	_apply_preview_mode(0)


func _configure_backdrop() -> void:
	var backdrop: Control = $Backdrop
	if backdrop.has_method("apply_profile"):
		backdrop.call("apply_profile", {
			"sky_top": Color(0.001, 0.008, 0.020, 1.0),
			"sky_bottom": Color(0.008, 0.050, 0.064, 1.0),
			"mountain_far": Color(0.026, 0.080, 0.094, 0.74),
			"mountain_near": Color(0.005, 0.028, 0.038, 0.97),
			"mist": Color(0.36, 0.72, 0.82, 0.075),
			"moon": Color(0.82, 0.62, 1.0, 0.10),
			"accent": VIOLET,
			"gold": GOLD,
			"realm_motif": "nine_heavens"
		})


func _hide_scrollbar_chrome() -> void:
	var scroll: ScrollContainer = $SafeArea/Scroll
	var vertical_bar: VScrollBar = scroll.get_v_scroll_bar()
	vertical_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	vertical_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var horizontal_bar: HScrollBar = scroll.get_h_scroll_bar()
	horizontal_bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	horizontal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_lab() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_theme_constant_override("separation", 12)
	_build_preview_switcher()
	_build_wallet_strip()
	_build_identity_masthead()
	_build_ritual_stage()
	_build_pity_constellation()
	_build_summon_actions()
	_build_secondary_modules()
	_build_lab_note()


func _build_preview_switcher() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	for index: int in range(3):
		var label: String = ["OPEN POOL", "WISH FATE", "SEALED"][index]
		var button: Button = _button(row, label, VIOLET, false)
		button.pressed.connect(_on_preview_mode_pressed.bind(index))
		preview_buttons.append(button)


func _build_wallet_strip() -> void:
	var shell: PanelContainer = _panel(content, _panel_style(JADE, 0.38, 10, Color(0.002, 0.021, 0.030, 0.96)))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	shell.add_child(row)
	_wallet_chip(row, SPIRIT_STONE_ICON, "3.7K", GOLD)
	_wallet_chip(row, REFINEMENT_SHARD_ICON, "42", CYAN)
	_wallet_chip(row, CELESTIAL_JADE_ICON, "1,280", VIOLET)
	_wallet_chip(row, PAVILION_SEAL_ICON, "18", JADE)


func _build_identity_masthead() -> void:
	var stage: Control = Control.new()
	stage.custom_minimum_size = Vector2(0.0, 118.0)
	stage.clip_contents = true
	content.add_child(stage)

	var art: TextureRect = TextureRect.new()
	art.texture = load(SANCTUARY_BANNER) as Texture2D
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.0, 0.008, 0.016, 0.48)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var copy: VBoxContainer = VBoxContainer.new()
	copy.anchor_left = 0.04
	copy.anchor_top = 0.10
	copy.anchor_right = 0.96
	copy.anchor_bottom = 0.92
	copy.add_theme_constant_override("separation", 1)
	stage.add_child(copy)
	_label(copy, "CELESTIAL PAVILION", 9, JADE)
	_label(copy, "Sanctum of Invocation", 24, GOLD_BRIGHT)
	_label(copy, "Call relics through a living formation of fate, pity, and celestial seals.", 10, TEXT_MAIN)


func _build_ritual_stage() -> void:
	ritual_shell = _panel(content, _ritual_shell_style(VIOLET, false))
	ritual_shell.custom_minimum_size = Vector2(0.0, 472.0)

	var stage: Control = Control.new()
	stage.custom_minimum_size = Vector2(0.0, 458.0)
	stage.clip_contents = true
	ritual_shell.add_child(stage)

	ritual_stage_visual = SummonStageVisual.new()
	ritual_stage_visual.name = "SummonStageVisual"
	stage.add_child(ritual_stage_visual)
	ritual_stage_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top_copy: VBoxContainer = VBoxContainer.new()
	top_copy.anchor_left = 0.05
	top_copy.anchor_top = 0.035
	top_copy.anchor_right = 0.95
	top_copy.anchor_bottom = 0.22
	top_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	top_copy.add_theme_constant_override("separation", 1)
	stage.add_child(top_copy)
	ritual_state_label = _label(top_copy, "HEAVENLY RELIC INVOCATION", 9, VIOLET)
	ritual_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ritual_title_label = _label(top_copy, "CELESTIAL ARMORY", 22, GOLD_BRIGHT)
	ritual_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var center: CenterContainer = CenterContainer.new()
	center.anchor_left = 0.0
	center.anchor_top = 0.18
	center.anchor_right = 1.0
	center.anchor_bottom = 0.72
	stage.add_child(center)

	ritual_icon_frame = PanelContainer.new()
	ritual_icon_frame.custom_minimum_size = Vector2(206.0, 206.0)
	ritual_icon_frame.add_theme_stylebox_override("panel", _relic_frame_style(VIOLET, false))
	center.add_child(ritual_icon_frame)

	ritual_icon = TextureRect.new()
	ritual_icon.texture = load(PAVILION_SEAL_ICON) as Texture2D
	ritual_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ritual_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ritual_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ritual_icon_frame.add_child(ritual_icon)
	ritual_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ritual_icon.offset_left = 20.0
	ritual_icon.offset_top = 20.0
	ritual_icon.offset_right = -20.0
	ritual_icon.offset_bottom = -20.0

	var bottom_copy: VBoxContainer = VBoxContainer.new()
	bottom_copy.anchor_left = 0.055
	bottom_copy.anchor_top = 0.73
	bottom_copy.anchor_right = 0.945
	bottom_copy.anchor_bottom = 0.97
	bottom_copy.alignment = BoxContainer.ALIGNMENT_END
	bottom_copy.add_theme_constant_override("separation", 5)
	stage.add_child(bottom_copy)

	wish_chip_label = _chip(bottom_copy, "LEGENDARY WISH • NO TARGET", VIOLET)
	wish_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ritual_subtitle_label = _label(bottom_copy, "All unlocked equipment shares the open pool.", 10, TEXT_MUTED)
	ritual_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_pity_constellation() -> void:
	var shell: PanelContainer = _panel(content, _panel_style(VIOLET, 0.38, 11, OBSIDIAN))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	shell.add_child(box)
	var title_row: HBoxContainer = HBoxContainer.new()
	box.add_child(title_row)
	var title: Label = _label(title_row, "FATE CONSTELLATION", 10, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var caption: Label = _label(title_row, "PERSISTENT GUARANTEES", 8, TEXT_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var tracks: HBoxContainer = HBoxContainer.new()
	tracks.add_theme_constant_override("separation", 6)
	box.add_child(tracks)
	_pity_track(tracks, "RARE+", "7 / 10", 0.70, CYAN)
	_pity_track(tracks, "EPIC+", "18 / 30", 0.60, VIOLET)
	_pity_track(tracks, "LEGENDARY", "34 / 50", 0.68, GOLD)


func _build_summon_actions() -> void:
	var shell: PanelContainer = _panel(content, _panel_style(GOLD, 0.42, 12, Color(0.002, 0.019, 0.028, 0.97)))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	shell.add_child(box)

	summon_ten_button = _button(box, "SUMMON ×10   •   10 SEALS / 900 JADE", GOLD, true)
	summon_ten_button.custom_minimum_size.y = 72.0
	summon_ten_button.add_theme_font_size_override("font_size", 15)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	box.add_child(row)
	summon_one_button = _button(row, "SUMMON ×1\n1 SEAL / 100 JADE", VIOLET, false)
	summon_one_button.custom_minimum_size.y = 58.0
	var rates: Button = _button(row, "RATES & RULES\n2% LEGENDARY", CYAN, false)
	rates.custom_minimum_size.y = 58.0

	var note: Label = _label(box, "Preview only • buttons do not call PavilionManager or spend currency.", 8, TEXT_MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_secondary_modules() -> void:
	var title: Label = _label(content, "SANCTUM SERVICES", 10, JADE)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.78))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	content.add_child(row)
	_service_card(row, MEDITATION_ICON, "MEDITATE", "+20 Stones", JADE)
	_service_card(row, AURA_ICON, "AURAS", "Attunement", VIOLET)
	_service_card(row, FORGE_ICON, "FORGE", "Safety Net", GOLD)


func _build_lab_note() -> void:
	var note: Label = _label(
		content,
		"LAB V1 • Ritual hierarchy only. Production economy / save / summon reveal state remains untouched.",
		8,
		Color(0.50, 0.62, 0.60, 1.0)
	)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.y = 36.0


func _on_preview_mode_pressed(mode: int) -> void:
	_apply_preview_mode(mode)


func _apply_preview_mode(mode: int) -> void:
	preview_mode = clampi(mode, 0, 2)
	for index: int in range(preview_buttons.size()):
		var button: Button = preview_buttons[index]
		var selected: bool = index == preview_mode
		button.add_theme_stylebox_override("normal", _button_style(GOLD if selected else VIOLET, selected))
		button.add_theme_color_override("font_color", GOLD_BRIGHT if selected else TEXT_MUTED)

	match preview_mode:
		0:
			_set_ritual_state(
				VIOLET,
				false,
				PAVILION_SEAL_ICON,
				"CELESTIAL ARMORY",
				"HEAVENLY RELIC INVOCATION",
				"LEGENDARY WISH • NO TARGET",
				"All unlocked equipment shares the open pool.",
				true
			)
		1:
			_set_ritual_state(
				GOLD,
				true,
				WISH_RELIC_ICON,
				"WANDERER JADE JIAN",
				"WISH FATE ACTIVE",
				"LEGENDARY WISH • TARGET LOCKED",
				"Next Legendary is guaranteed to match the chosen relic.",
				true
			)
		_:
			_set_ritual_state(
				Color(0.38, 0.44, 0.44, 1.0),
				false,
				PAVILION_SEAL_ICON,
				"CELESTIAL ARMORY SEALED",
				"PAVILION DORMANT",
				"LOCKED • CLEAR 1-5",
				"Complete Verdant Qi Valley to awaken the Pavilion.",
				false
			)


func _set_ritual_state(
	accent: Color,
	fate_active: bool,
	icon_path: String,
	title: String,
	state_text: String,
	wish_text: String,
	subtitle: String,
	active: bool
) -> void:
	ritual_title_label.text = title
	ritual_state_label.text = state_text
	ritual_state_label.add_theme_color_override("font_color", GOLD if fate_active else accent)
	wish_chip_label.text = wish_text
	wish_chip_label.add_theme_color_override("font_color", GOLD_BRIGHT if fate_active else accent)
	ritual_subtitle_label.text = subtitle
	ritual_icon.texture = load(icon_path) as Texture2D
	ritual_icon.modulate = Color.WHITE if active else Color(0.56, 0.61, 0.60, 0.68)
	ritual_shell.add_theme_stylebox_override("panel", _ritual_shell_style(accent, fate_active))
	ritual_icon_frame.add_theme_stylebox_override("panel", _relic_frame_style(accent, fate_active))
	if ritual_stage_visual.has_method("configure"):
		ritual_stage_visual.call("configure", accent, GOLD, active, fate_active)
	summon_one_button.disabled = not active
	summon_ten_button.disabled = not active


func _wallet_chip(parent_node: Node, icon_path: String, value_text: String, accent: Color) -> void:
	var panel: PanelContainer = _panel(parent_node, _panel_style(accent, 0.28, 9, Color(0.004, 0.028, 0.038, 0.96)))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0.0, 42.0)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load(icon_path) as Texture2D
	icon.custom_minimum_size = Vector2(18.0, 18.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	_label(row, value_text, 11, GOLD_BRIGHT if accent == GOLD else TEXT_MAIN)


func _pity_track(parent_node: Node, title_text: String, value_text: String, ratio: float, accent: Color) -> void:
	var card: PanelContainer = _panel(parent_node, _panel_style(accent, 0.30, 9, Color(0.004, 0.026, 0.035, 0.96)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 70.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var title: Label = _label(box, title_text, 8, accent)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value: Label = _label(box, value_text, 12, TEXT_MAIN)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var track: ProgressBar = ProgressBar.new()
	track.min_value = 0.0
	track.max_value = 1.0
	track.value = clampf(ratio, 0.0, 1.0)
	track.show_percentage = false
	track.custom_minimum_size = Vector2(0.0, 7.0)
	track.add_theme_stylebox_override("background", _bar_style(Color(0.03, 0.06, 0.07, 0.96), 3))
	track.add_theme_stylebox_override("fill", _bar_style(Color(accent.r, accent.g, accent.b, 0.82), 3))
	box.add_child(track)


func _service_card(parent_node: Node, icon_path: String, title_text: String, subtitle_text: String, accent: Color) -> void:
	var card: PanelContainer = _panel(parent_node, _panel_style(accent, 0.32, 10, Color(0.003, 0.026, 0.036, 0.96)))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 112.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	var icon: TextureRect = TextureRect.new()
	icon.texture = load(icon_path) as Texture2D
	icon.custom_minimum_size = Vector2(44.0, 44.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var title: Label = _label(box, title_text, 10, GOLD_BRIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label = _label(box, subtitle_text, 8, TEXT_MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _panel(parent_node: Node, style: StyleBox) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	parent_node.add_child(panel)
	return panel


func _label(parent_node: Node, text_value: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent_node.add_child(label)
	return label


func _chip(parent_node: Node, text_value: String, accent: Color) -> Label:
	var panel: PanelContainer = _panel(parent_node, _panel_style(accent, 0.44, 12, Color(0.005, 0.024, 0.034, 0.94)))
	panel.custom_minimum_size = Vector2(0.0, 30.0)
	var label: Label = _label(panel, text_value, 9, accent)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _button(parent_node: Node, text_value: String, accent: Color, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text_value
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", GOLD_BRIGHT if primary else TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.43, 0.49, 0.48, 0.80))
	button.add_theme_stylebox_override("normal", _button_style(accent, primary))
	button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.08), true))
	button.add_theme_stylebox_override("pressed", _button_style(accent.darkened(0.12), true))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.28, 0.33, 0.33, 1.0), false))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent_node.add_child(button)
	return button


func _panel_style(accent: Color, alpha: float, radius: int, background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, alpha)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10.0
	style.content_margin_top = 9.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 5
	return style


func _ritual_shell_style(accent: Color, fate_active: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = _panel_style(GOLD if fate_active else accent, 0.78, 14, Color(0.001, 0.009, 0.020, 0.985))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.13 if not fate_active else 0.18)
	style.shadow_size = 10
	return style


func _relic_frame_style(accent: Color, fate_active: bool) -> StyleBoxFlat:
	var border: Color = GOLD if fate_active else accent
	var style: StyleBoxFlat = _panel_style(border, 0.90, 103, Color(0.001, 0.010, 0.018, 0.88))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(border.r, border.g, border.b, 0.20)
	style.shadow_size = 12
	return style


func _button_style(accent: Color, primary: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		accent.r * (0.16 if primary else 0.08),
		accent.g * (0.16 if primary else 0.08),
		accent.b * (0.16 if primary else 0.08),
		0.98
	)
	style.border_width_left = 1 if not primary else 2
	style.border_width_top = 1 if not primary else 2
	style.border_width_right = 1 if not primary else 2
	style.border_width_bottom = 1 if not primary else 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.82 if primary else 0.54)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.10 if primary else 0.03)
	style.shadow_size = 6 if primary else 2
	return style


func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
