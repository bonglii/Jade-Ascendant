extends Node

## Jade Ascendant — clean modal presentation V3.
## Simple, elegant, and more assertive than V2.
## Presentation only: existing buttons keep their original handlers.

const JADE := Color(0.12, 0.76, 0.63, 1.0)
const GOLD := Color(0.93, 0.75, 0.39, 1.0)
const INK := Color(0.025, 0.065, 0.073, 0.99)
const TEXT := Color(0.92, 0.96, 0.94, 1.0)
const MUTED := Color(0.69, 0.78, 0.77, 1.0)
const DANGER := Color(0.89, 0.42, 0.39, 1.0)
const SOFT_GOLD := Color(1.0, 0.91, 0.72, 1.0)


func _ready() -> void:
	var scene_tree: SceneTree = get_tree()
	if not scene_tree.scene_changed.is_connected(_on_scene_changed):
		scene_tree.scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()


func _on_scene_changed() -> void:
	var scene_root: Node = get_tree().current_scene
	if not is_instance_valid(scene_root):
		return
	if scene_root.name == "StageSelect":
		_style_restart(scene_root)
		return
	var victory_ui: Node = scene_root.get_node_or_null("VictoryUI")
	if victory_ui != null:
		_style_victory(victory_ui)
	var defeat_ui: Node = scene_root.get_node_or_null("GameOverUI")
	if defeat_ui != null:
		_style_defeat(defeat_ui)


func _style_victory(scene_ui: Node) -> void:
	if scene_ui.has_meta("ja_clean_popup_v3"):
		return
	var backdrop: ColorRect = scene_ui.get_node_or_null("ColorRect") as ColorRect
	var panel: PanelContainer = scene_ui.get_node_or_null(
		"ColorRect/SafeArea/CenterContainer/Panel"
	) as PanelContainer
	if backdrop == null or panel == null:
		return
	var margin: MarginContainer = panel.get_node_or_null("Margin") as MarginContainer
	var box: VBoxContainer = panel.get_node_or_null("Margin/Content") as VBoxContainer
	if margin == null or box == null:
		return

	_style_backdrop(backdrop, Color(0.002, 0.018, 0.021, 0.975))
	panel.custom_minimum_size = Vector2(534.0, 654.0)
	panel.add_theme_stylebox_override(
		"panel", _frame(INK, GOLD.darkened(0.12), 2, 21, 18)
	)
	_set_margins(margin, 31, 26)
	box.add_theme_constant_override("separation", 12)

	var eyebrow: Label = box.get_node_or_null("Eyebrow") as Label
	_style_label(eyebrow, 12, JADE.lightened(0.14))
	var seal: TextureRect = box.get_node_or_null("VictorySeal") as TextureRect
	if seal != null:
		seal.custom_minimum_size = Vector2(92.0, 92.0)
		seal.pivot_offset = Vector2(46.0, 46.0)
		seal.self_modulate = Color(0.96, 1.0, 0.95, 0.96)
	var title_label: Label = box.get_node_or_null("VictoryLabel") as Label
	_style_label(title_label, 40, GOLD.lightened(0.16))
	var stage: Label = box.get_node_or_null("StageLabel") as Label
	_style_label(stage, 17, TEXT)
	if stage != null:
		stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stage.custom_minimum_size = Vector2(0.0, 42.0)
		stage.add_theme_stylebox_override(
			"normal",
			_chip(Color(0.023, 0.085, 0.091, 0.98), Color(0.19, 0.35, 0.36, 0.95))
		)
	var state_label: Label = box.get_node_or_null("ClearStateLabel") as Label
	_style_label(state_label, 12, JADE.lightened(0.18))
	if state_label != null:
		state_label.custom_minimum_size = Vector2(0.0, 38.0)
		state_label.add_theme_stylebox_override(
			"normal",
			_chip(Color(0.026, 0.126, 0.112, 0.96), Color(0.18, 0.42, 0.36, 0.95))
		)

	var reward_panel: PanelContainer = box.get_node_or_null("RewardPanel") as PanelContainer
	if reward_panel != null:
		reward_panel.custom_minimum_size = Vector2(0.0, 186.0)
		reward_panel.add_theme_stylebox_override(
			"panel",
			_frame(Color(0.029, 0.100, 0.098, 0.99), Color(0.27, 0.47, 0.42, 0.95), 1, 14, 6)
		)
		var reward_title: Label = reward_panel.get_node_or_null(
			"RewardMargin/RewardContent/RewardHeader"
		) as Label
		_style_label(reward_title, 13, SOFT_GOLD)
		var balance: Label = reward_panel.get_node_or_null(
			"RewardMargin/RewardContent/BalanceLabel"
		) as Label
		_style_label(balance, 12, MUTED)
	var home: Button = box.get_node_or_null("MainMenuButton") as Button
	_style_button(home, "gold", 70.0, 18)
	var hint: Label = box.get_node_or_null("Hint") as Label
	_style_label(hint, 12, MUTED)
	if hint != null:
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_ui.set_meta("ja_clean_popup_v3", true)


func _style_defeat(scene_ui: Node) -> void:
	if scene_ui.has_meta("ja_clean_popup_v3"):
		return
	var backdrop: ColorRect = scene_ui.get_node_or_null("ColorRect") as ColorRect
	var panel: PanelContainer = scene_ui.get_node_or_null(
		"ColorRect/SafeArea/CenterContainer/Panel"
	) as PanelContainer
	if backdrop == null or panel == null:
		return
	var margin: MarginContainer = panel.get_node_or_null("Margin") as MarginContainer
	var box: VBoxContainer = panel.get_node_or_null("Margin/Content") as VBoxContainer
	if margin == null or box == null:
		return

	_style_backdrop(backdrop, Color(0.028, 0.014, 0.024, 0.975))
	panel.custom_minimum_size = Vector2(534.0, 772.0)
	panel.add_theme_stylebox_override(
		"panel",
		_frame(Color(0.070, 0.039, 0.046, 0.99), Color(0.67, 0.34, 0.31, 0.95), 2, 21, 18)
	)
	_set_margins(margin, 31, 26)
	box.add_theme_constant_override("separation", 12)

	var eyebrow: Label = box.get_node_or_null("Eyebrow") as Label
	_style_label(eyebrow, 12, DANGER.lightened(0.18))
	var seal: TextureRect = box.get_node_or_null("DefeatSeal") as TextureRect
	if seal != null:
		seal.custom_minimum_size = Vector2(88.0, 88.0)
		seal.pivot_offset = Vector2(44.0, 44.0)
		seal.self_modulate = Color(1.0, 0.86, 0.80, 0.95)
	var title_label: Label = box.get_node_or_null("GameOverLabel") as Label
	_style_label(title_label, 34, SOFT_GOLD)
	var stage: Label = box.get_node_or_null("StageLabel") as Label
	_style_label(stage, 16, TEXT)
	if stage != null:
		stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stage.custom_minimum_size = Vector2(0.0, 40.0)
		stage.add_theme_stylebox_override(
			"normal",
			_chip(Color(0.093, 0.052, 0.054, 0.98), Color(0.31, 0.20, 0.20, 0.95))
		)
	var wave: Label = box.get_node_or_null("WaveLabel") as Label
	_style_label(wave, 18, SOFT_GOLD)
	if wave != null:
		wave.custom_minimum_size = Vector2(0.0, 40.0)
		wave.add_theme_stylebox_override(
			"normal",
			_chip(Color(0.17, 0.083, 0.071, 0.95), Color(0.53, 0.32, 0.25, 0.86))
		)

	var rewards: PanelContainer = box.get_node_or_null("RewardPanel") as PanelContainer
	if rewards != null:
		rewards.custom_minimum_size = Vector2(0.0, 162.0)
		rewards.add_theme_stylebox_override(
			"panel",
			_frame(Color(0.095, 0.049, 0.052, 0.99), Color(0.39, 0.24, 0.24, 0.96), 1, 14, 6)
		)
		var reward_title: Label = rewards.get_node_or_null(
			"RewardMargin/RewardContent/RewardHeader"
		) as Label
		_style_label(reward_title, 13, DANGER.lightened(0.23))
		var balance: Label = rewards.get_node_or_null(
			"RewardMargin/RewardContent/BalanceLabel"
		) as Label
		_style_label(balance, 12, MUTED)
	var revive: Button = scene_ui.get("revive_button") as Button
	_style_button(revive, "primary", 64.0, 17)
	var retry: Button = box.get_node_or_null("RetryButton") as Button
	_style_button(retry, "gold", 62.0, 17)
	var home: Button = box.get_node_or_null("MainMenuButton") as Button
	_style_button(home, "tertiary", 58.0, 16)
	var hint: Label = box.get_node_or_null("Hint") as Label
	_style_label(hint, 12, MUTED)
	if hint != null:
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_ui.set_meta("ja_clean_popup_v3", true)


func _style_restart(scene_ui: Node) -> void:
	if scene_ui.has_meta("ja_clean_popup_v3"):
		return
	var overlay: ColorRect = scene_ui.get("confirm_overlay") as ColorRect
	var stage: Label = scene_ui.get("confirm_stage_label") as Label
	var body: Label = scene_ui.get("confirm_body_label") as Label
	if overlay == null or stage == null or body == null:
		return

	var center: CenterContainer = null
	for child: Node in overlay.get_children():
		if child is CenterContainer:
			center = child as CenterContainer
			break
	if center == null:
		return
	var panel: PanelContainer = null
	for child: Node in center.get_children():
		if child is PanelContainer:
			panel = child as PanelContainer
			break
	if panel == null:
		return
	var margin: MarginContainer = null
	for child: Node in panel.get_children():
		if child is MarginContainer:
			margin = child as MarginContainer
			break
	if margin == null:
		return
	var box: VBoxContainer = null
	for child: Node in margin.get_children():
		if child is VBoxContainer:
			box = child as VBoxContainer
			break
	if box == null:
		return

	var button_row: HBoxContainer = null
	var eyebrow: Label = null
	for child: Node in box.get_children():
		if child is HBoxContainer:
			button_row = child as HBoxContainer
		elif child is Label and child != stage and child != body:
			eyebrow = child as Label
	if button_row == null or button_row.get_child_count() != 2:
		return
	var cancel: Button = button_row.get_child(0) as Button
	var start_new: Button = button_row.get_child(1) as Button
	if cancel == null or start_new == null:
		return

	overlay.color = Color(0.001, 0.014, 0.019, 0.80)
	panel.custom_minimum_size = Vector2(520.0, 420.0)
	panel.add_theme_stylebox_override(
		"panel", _frame(INK, GOLD.darkened(0.14), 2, 20, 18)
	)
	_set_margins(margin, 30, 28)
	box.add_theme_constant_override("separation", 14)

	_style_label(eyebrow, 20, SOFT_GOLD)
	if eyebrow != null:
		eyebrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(stage, 24, TEXT)
	stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.custom_minimum_size = Vector2(0.0, 51.0)
	stage.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage.add_theme_stylebox_override(
		"normal",
		_chip(Color(0.025, 0.12, 0.109, 0.96), Color(0.22, 0.40, 0.35, 0.90))
	)
	_style_label(body, 16, TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var warning := Label.new()
	warning.name = "CheckpointWarning"
	warning.text = tr("CURRENT CHECKPOINT WILL BE REPLACED")
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(warning, 14, DANGER.lightened(0.20))
	warning.add_theme_stylebox_override(
		"normal",
		_chip(Color(0.20, 0.07, 0.06, 0.96), Color(0.55, 0.22, 0.20, 0.95))
	)
	box.add_child(warning)
	box.move_child(warning, button_row.get_index())

	var action_column := VBoxContainer.new()
	action_column.name = "SimplePopupActions"
	action_column.add_theme_constant_override("separation", 11)
	box.add_child(action_column)
	box.move_child(action_column, button_row.get_index())
	button_row.remove_child(cancel)
	button_row.remove_child(start_new)
	action_column.add_child(cancel)
	action_column.add_child(start_new)
	button_row.hide()

	cancel.text = tr("KEEP CURRENT RUN")
	start_new.text = tr("ABANDON & START NEW")
	_style_button(cancel, "tertiary", 63.0, 17)
	_style_button(start_new, "danger", 63.0, 17)
	scene_ui.set_meta("ja_clean_popup_v3", true)


func _style_backdrop(backdrop: ColorRect, tint: Color) -> void:
	backdrop.color = tint
	var art: TextureRect = backdrop.get_node_or_null("ResultBackdropArt") as TextureRect
	if art != null:
		art.modulate.a = 0.46


func _style_label(control_label: Label, size_value: int, tint: Color) -> void:
	if control_label == null:
		return
	control_label.add_theme_font_size_override("font_size", size_value)
	control_label.add_theme_color_override("font_color", tint)


func _set_margins(margin: MarginContainer, sides: int, vertical: int) -> void:
	margin.add_theme_constant_override("margin_left", sides)
	margin.add_theme_constant_override("margin_right", sides)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)


func _frame(
	fill: Color, outline: Color, width_value: int,
	radius_value: int, shadow_value: int = 16
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(width_value)
	style.set_corner_radius_all(radius_value)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.50)
	style.shadow_size = shadow_value
	style.shadow_offset = Vector2(0.0, 6.0)
	return style


func _chip(fill: Color, outline: Color) -> StyleBoxFlat:
	var style := _frame(fill, outline, 1, 11, 0)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _style_button(
	button_control: Button,
	kind: String,
	height_value: float,
	font_size_value: int
) -> void:
	if button_control == null:
		return
	button_control.custom_minimum_size = Vector2(0.0, height_value)
	button_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_control.add_theme_font_size_override("font_size", font_size_value)
	button_control.clip_text = true

	var fill: Color = Color(0.065, 0.13, 0.14, 1.0)
	var outline: Color = Color(0.30, 0.48, 0.47, 1.0)
	var font: Color = TEXT
	if kind == "primary":
		fill = Color(0.045, 0.33, 0.29, 1.0)
		outline = Color(0.30, 0.79, 0.64, 1.0)
		font = Color(0.95, 1.0, 0.97, 1.0)
	elif kind == "gold":
		fill = Color(0.70, 0.52, 0.18, 1.0)
		outline = Color(1.0, 0.84, 0.45, 1.0)
		font = Color(0.13, 0.10, 0.04, 1.0)
	elif kind == "tertiary":
		fill = Color(0.075, 0.099, 0.112, 1.0)
		outline = Color(0.22, 0.34, 0.35, 1.0)
	elif kind == "danger":
		fill = Color(0.46, 0.11, 0.10, 1.0)
		outline = Color(0.90, 0.40, 0.31, 1.0)
		font = Color(1.0, 0.95, 0.90, 1.0)

	button_control.add_theme_color_override("font_color", font)
	button_control.add_theme_color_override("font_hover_color", font if kind == "gold" else Color.WHITE)
	button_control.add_theme_color_override("font_pressed_color", font)
	button_control.add_theme_color_override(
		"font_disabled_color", Color(0.60, 0.64, 0.64, 1.0)
	)
	button_control.add_theme_stylebox_override(
		"normal", _button_style(fill, outline, 1)
	)
	button_control.add_theme_stylebox_override(
		"hover",
		_button_style(fill.lightened(0.14), outline.lightened(0.20), 2)
	)
	button_control.add_theme_stylebox_override(
		"pressed",
		_button_style(fill.darkened(0.18), outline.darkened(0.12), 1)
	)
	button_control.add_theme_stylebox_override(
		"focus", _button_style(fill, GOLD, 2)
	)
	button_control.add_theme_stylebox_override(
		"disabled",
		_button_style(Color(0.09, 0.11, 0.12, 0.91), Color(0.25, 0.30, 0.31, 0.93), 1)
	)


func _button_style(fill: Color, border: Color, width_value: int) -> StyleBoxFlat:
	var style := _frame(fill, border, width_value, 13, 2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_offset = Vector2(0.0, 2.0)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style
