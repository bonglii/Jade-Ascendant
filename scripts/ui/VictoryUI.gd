extends CanvasLayer

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const VICTORY_BACKDROP_ART: String = "res://assets/ui/results/victory_sanctum.svg"
const VICTORY_SEAL_ART: String = "res://assets/ui/results/victory_seal.svg"
const SPIRIT_STONE_ICON: String = "res://assets/ui/icons/spirit_stone.svg"
const REFINEMENT_SHARD_ICON: String = "res://assets/ui/equipment/refinement_shard.svg"
const EndRunAtmosphereScript = preload("res://scripts/ui/end_run_atmosphere.gd")

const INTRO_BACKDROP_FADE_DURATION: float = 0.48
const INTRO_PANEL_DELAY: float = 0.10
const INTRO_PANEL_FADE_DURATION: float = 0.30

@onready var victory_backdrop: ColorRect = $ColorRect
@onready var victory_panel: PanelContainer = (
	$ColorRect/SafeArea/CenterContainer/Panel
)
@onready var content: VBoxContainer = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content
)
@onready var eyebrow_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/Eyebrow
)
@onready var victory_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/VictoryLabel
)
@onready var stage_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/StageLabel
)
@onready var clear_state_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/ClearStateLabel
)
@onready var reward_panel: PanelContainer = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel
)
@onready var reward_header_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/RewardHeader
)
@onready var reward_summary_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/RewardSummaryLabel
)
@onready var balance_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent/BalanceLabel
)
@onready var main_menu_button: Button = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/MainMenuButton
)
@onready var hint_label: Label = (
	$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/Hint
)

var victory_reward_entries: Array[Dictionary] = []
var intro_tween: Tween = null
var victory_seal: TextureRect = null
var reward_chip_row: HBoxContainer = null
var result_atmosphere: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_apply_premium_visuals()
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	if not RewardManager.reward_granted.is_connected(_on_reward_granted):
		RewardManager.reward_granted.connect(_on_reward_granted)
	hide()

func show_victory() -> void:
	_refresh_stage_identity()
	_refresh_reward_summary()
	if SaveManager.is_progress_read_only():
		clear_state_label.text = tr("SAVE PENDING")
		reward_summary_label.text = tr(
			"A save needs recovery. Close and reopen the game before continuing."
		)
	_play_intro()
	DebugLogger.system(str("VictoryUI ditampilkan!"))

func _on_reward_granted(
	source_type: String,
	source_id: String,
	reward_data: Dictionary
) -> void:
	if source_type not in [
		RewardManager.SOURCE_STAGE_CLEAR,
		RewardManager.SOURCE_BOSS_DEFEAT
	]:
		return
	victory_reward_entries.append({
		"source_type": source_type,
		"source_id": source_id,
		"reward_data": RewardManager.get_last_grant_result().get(
			"applied_reward_data",
			reward_data
		).duplicate(true)
	})

func _refresh_stage_identity() -> void:
	var chapter_id: int = JourneyManager.selected_chapter_id
	var stage_id: int = JourneyManager.selected_stage_id
	var chapter_data: Dictionary = JourneyManager.get_chapter_data(chapter_id)
	var stage_data: Dictionary = JourneyManager.get_selected_stage_data()
	var chapter_name: String = str(
		chapter_data.get("display_name", "Chapter %d" % chapter_id)
	)
	var stage_name: String = str(
		stage_data.get("display_name", "Stage %d" % stage_id)
	)
	stage_label.text = "%s  •  %s" % [chapter_name, stage_name]

func _refresh_reward_summary() -> void:
	var presentation_blocks: Array[String] = []
	var clear_state: String = "STAGE CLEAR • REWARD SECURED"
	for raw_reward_entry in victory_reward_entries:
		var reward_entry: Dictionary = raw_reward_entry
		var source_type: String = str(reward_entry.get("source_type", ""))
		var source_id: String = str(reward_entry.get("source_id", ""))
		var reward_data: Dictionary = reward_entry.get("reward_data", {})
		var reward_title: String = _get_reward_title(source_type, source_id)
		presentation_blocks.append(
			tr(reward_title).to_upper()
			+ "\n"
			+ RewardManager.get_reward_summary(reward_data)
		)
		if source_type == RewardManager.SOURCE_STAGE_CLEAR:
			clear_state = _get_clear_state(source_id)
	if presentation_blocks.is_empty():
		presentation_blocks.append(
			tr("Stage Clear Reward").to_upper()
			+ "\n"
			+ tr("No Reward")
		)
	clear_state_label.text = tr(clear_state)
	reward_summary_label.text = "\n\n".join(
		PackedStringArray(presentation_blocks)
	)
	balance_label.text = tr("SPIRIT STONE BALANCE  •  %s") % (
		_format_number(ProgressionManager.spirit_stone)
	)
	_populate_reward_chips()
	DebugLogger.system(str(
		"VictoryUI Reward Presentation: ",
		reward_summary_label.text.replace("\n", " | ")
	))

func _get_reward_title(source_type: String, source_id: String) -> String:
	if source_type == RewardManager.SOURCE_BOSS_DEFEAT:
		return "Boss Reward"
	if source_id.ends_with("_first_clear"):
		return "First Clear Reward"
	if source_id.ends_with("_repeat_clear"):
		return "Repeat Clear Reward"
	return "Stage Clear Reward"

func _get_clear_state(source_id: String) -> String:
	if source_id.ends_with("_first_clear"):
		return "FIRST CLEAR • PROGRESS RECORDED"
	if source_id.ends_with("_repeat_clear"):
		return "REPEAT CLEAR • REWARD SECURED"
	return "STAGE CLEAR • REWARD SECURED"

func _apply_premium_visuals() -> void:
	victory_backdrop.color = Color(0.002, 0.018, 0.025, 0.96)
	_ensure_backdrop_art()
	_ensure_atmosphere()
	_ensure_result_seal()
	_ensure_reward_chip_row()

	victory_panel.custom_minimum_size = Vector2(530.0, 720.0)
	victory_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.055, 0.060, 0.945),
			Color(0.92, 0.72, 0.29, 0.92),
			24,
			3
		)
	)

	var margin: MarginContainer = (
		$ColorRect/SafeArea/CenterContainer/Panel/Margin
	)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	content.add_theme_constant_override("separation", 12)

	eyebrow_label.text = tr("STAGE CLEAR • DAO PATH ADVANCED")
	eyebrow_label.add_theme_color_override(
		"font_color",
		Color(0.50, 0.92, 0.80, 1.0)
	)
	eyebrow_label.add_theme_font_size_override("font_size", 13)

	victory_label.text = tr("VICTORY")
	victory_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.84, 0.40, 1.0)
	)
	victory_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.72)
	)
	victory_label.add_theme_constant_override("shadow_offset_x", 0)
	victory_label.add_theme_constant_override("shadow_offset_y", 3)
	victory_label.add_theme_font_size_override("font_size", 40)

	stage_label.add_theme_color_override(
		"font_color",
		Color(0.91, 0.96, 0.91, 1.0)
	)
	stage_label.add_theme_font_size_override("font_size", 16)

	clear_state_label.add_theme_color_override(
		"font_color",
		Color(0.38, 0.96, 0.76, 1.0)
	)
	clear_state_label.add_theme_font_size_override("font_size", 13)
	clear_state_label.custom_minimum_size = Vector2(0.0, 36.0)
	clear_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_state_label.add_theme_stylebox_override(
		"normal",
		_make_pill_style(
			Color(0.015, 0.105, 0.090, 0.92),
			Color(0.38, 0.96, 0.76, 0.72)
		)
	)

	reward_panel.custom_minimum_size = Vector2(0.0, 184.0)
	reward_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.008, 0.075, 0.073, 0.94),
			Color(0.26, 0.80, 0.67, 0.80),
			16,
			1
		)
	)
	reward_header_label.text = tr("REWARDS SECURED")
	reward_header_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.79, 0.34, 1.0)
	)
	reward_header_label.add_theme_font_size_override("font_size", 12)
	reward_summary_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.94, 0.76, 1.0)
	)
	reward_summary_label.add_theme_font_size_override("font_size", 17)
	balance_label.add_theme_color_override(
		"font_color",
		Color(0.63, 0.82, 0.77, 1.0)
	)
	balance_label.add_theme_font_size_override("font_size", 12)

	main_menu_button.text = tr("RETURN HOME")
	main_menu_button.custom_minimum_size = Vector2(0.0, 68.0)
	main_menu_button.add_theme_font_size_override("font_size", 18)
	main_menu_button.add_theme_color_override(
		"font_color",
		Color(0.025, 0.095, 0.080, 1.0)
	)
	main_menu_button.add_theme_color_override(
		"font_hover_color",
		Color(0.015, 0.070, 0.060, 1.0)
	)
	main_menu_button.add_theme_color_override(
		"font_pressed_color",
		Color(0.015, 0.060, 0.055, 1.0)
	)
	main_menu_button.add_theme_stylebox_override(
		"normal",
		_make_button_style(
			Color(0.92, 0.73, 0.30, 1.0),
			Color(1.0, 0.88, 0.52, 1.0),
			16
		)
	)
	main_menu_button.add_theme_stylebox_override(
		"hover",
		_make_button_style(
			Color(0.98, 0.82, 0.40, 1.0),
			Color(1.0, 0.95, 0.72, 1.0),
			16
		)
	)
	main_menu_button.add_theme_stylebox_override(
		"pressed",
		_make_button_style(
			Color(0.78, 0.59, 0.22, 1.0),
			Color(0.94, 0.78, 0.36, 1.0),
			16
		)
	)
	main_menu_button.add_theme_stylebox_override(
		"focus",
		_make_button_style(
			Color(0.92, 0.73, 0.30, 1.0),
			Color(0.42, 0.95, 0.78, 1.0),
			16,
			2
		)
	)

	hint_label.text = tr(
		"The run is complete. Rewards are already secured before leaving the battlefield."
	)
	hint_label.add_theme_color_override(
		"font_color",
		Color(0.57, 0.73, 0.70, 1.0)
	)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _ensure_backdrop_art() -> void:
	if victory_backdrop.has_node("ResultBackdropArt"):
		return
	var texture: Texture2D = load(VICTORY_BACKDROP_ART) as Texture2D
	if texture == null:
		push_warning("VictoryUI: artwork kemenangan tidak dapat dimuat.")
		return
	var backdrop_art := TextureRect.new()
	backdrop_art.name = "ResultBackdropArt"
	backdrop_art.texture = texture
	backdrop_art.anchor_left = 0.0
	backdrop_art.anchor_top = 0.0
	backdrop_art.anchor_right = 1.0
	backdrop_art.anchor_bottom = 1.0
	backdrop_art.offset_left = 0.0
	backdrop_art.offset_top = 0.0
	backdrop_art.offset_right = 0.0
	backdrop_art.offset_bottom = 0.0
	backdrop_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop_art.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_art.modulate = Color(1.0, 1.0, 1.0, 0.96)
	victory_backdrop.add_child(backdrop_art)
	victory_backdrop.move_child(backdrop_art, 0)


func _ensure_atmosphere() -> void:
	if victory_backdrop.has_node("EndRunAtmosphere"):
		result_atmosphere = (
			victory_backdrop.get_node("EndRunAtmosphere")
			as Control
		)
		return

	result_atmosphere = EndRunAtmosphereScript.new() as Control
	if result_atmosphere == null:
		return

	result_atmosphere.name = "EndRunAtmosphere"
	result_atmosphere.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	result_atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_atmosphere.call("configure", "victory")
	victory_backdrop.add_child(result_atmosphere)
	victory_backdrop.move_child(
		result_atmosphere,
		mini(1, victory_backdrop.get_child_count() - 1)
	)


func _ensure_result_seal() -> void:
	if content.has_node("VictorySeal"):
		victory_seal = content.get_node("VictorySeal") as TextureRect
		return

	var texture: Texture2D = load(VICTORY_SEAL_ART) as Texture2D
	if texture == null:
		push_warning("VictoryUI: segel kemenangan tidak dapat dimuat.")
		return

	victory_seal = TextureRect.new()
	victory_seal.name = "VictorySeal"
	victory_seal.texture = texture
	victory_seal.custom_minimum_size = Vector2(116.0, 116.0)
	victory_seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	victory_seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	victory_seal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	victory_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_seal.pivot_offset = Vector2(58.0, 58.0)
	content.add_child(victory_seal)
	content.move_child(victory_seal, 1)


func _ensure_reward_chip_row() -> void:
	if reward_chip_row != null:
		return

	var reward_content: VBoxContainer = (
		$ColorRect/SafeArea/CenterContainer/Panel/Margin/Content/RewardPanel/RewardMargin/RewardContent
	)

	if reward_content.has_node("RewardChipRow"):
		reward_chip_row = reward_content.get_node("RewardChipRow") as HBoxContainer
		return

	reward_chip_row = HBoxContainer.new()
	reward_chip_row.name = "RewardChipRow"
	reward_chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_chip_row.add_theme_constant_override("separation", 10)
	reward_content.add_child(reward_chip_row)
	reward_content.move_child(reward_chip_row, 1)


func _populate_reward_chips() -> void:
	_ensure_reward_chip_row()
	if reward_chip_row == null:
		return

	for child: Node in reward_chip_row.get_children():
		child.queue_free()

	var stone_total: int = 0
	var item_totals: Dictionary = {}

	for raw_reward_entry: Variant in victory_reward_entries:
		var reward_entry: Dictionary = raw_reward_entry
		var reward_data: Dictionary = reward_entry.get(
			"reward_data",
			{}
		)
		stone_total += int(
			reward_data.get(
				RewardManager.REWARD_KEY_SPIRIT_STONE,
				0
			)
		)

		var item_data: Dictionary = reward_data.get(
			RewardManager.REWARD_KEY_ITEMS,
			{}
		)
		for raw_item_id: Variant in item_data.keys():
			var item_id: String = str(raw_item_id)
			item_totals[item_id] = (
				int(item_totals.get(item_id, 0))
				+ int(item_data.get(raw_item_id, 0))
			)

	if stone_total > 0:
		reward_chip_row.add_child(
			_create_reward_chip(
				"SPIRIT STONE",
				"+%s" % _format_number(stone_total),
				SPIRIT_STONE_ICON,
				Color(0.98, 0.78, 0.31, 1.0)
			)
		)

	for raw_item_id: Variant in item_totals.keys():
		var item_id: String = str(raw_item_id)
		var amount: int = int(item_totals.get(item_id, 0))
		if amount <= 0:
			continue

		var icon_path: String = (
			REFINEMENT_SHARD_ICON
			if item_id == InventoryManager.REFINEMENT_SHARD
			else ""
		)
		var display_name: String = (
			"REFINEMENT SHARD"
			if item_id == InventoryManager.REFINEMENT_SHARD
			else item_id.replace("_", " ").to_upper()
		)
		reward_chip_row.add_child(
			_create_reward_chip(
				display_name,
				"+%s" % _format_number(amount),
				icon_path,
				Color(0.35, 0.91, 0.82, 1.0)
			)
		)

	var has_chips: bool = reward_chip_row.get_child_count() > 0
	reward_chip_row.visible = has_chips
	reward_summary_label.visible = not has_chips


func _create_reward_chip(
	caption: String,
	value_text: String,
	icon_path: String,
	accent: Color
) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(178.0, 72.0)
	panel.add_theme_stylebox_override(
		"panel",
		_make_reward_chip_style(accent)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var texture := load(icon_path) as Texture2D
		if texture != null:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(38.0, 38.0)
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", -1)
	row.add_child(copy)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.theme_type_variation = &"JadeHeroName"
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", accent)
	copy.add_child(value_label)

	var caption_label := Label.new()
	caption_label.text = tr(caption)
	caption_label.theme_type_variation = &"JadeMutedLabel"
	caption_label.add_theme_font_size_override("font_size", 10)
	caption_label.add_theme_color_override(
		"font_color",
		Color(0.75, 0.84, 0.82, 0.98)
	)
	copy.add_child(caption_label)

	return panel


func _make_reward_chip_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		accent.r * 0.055,
		accent.g * 0.055,
		accent.b * 0.055,
		0.95
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.68
	)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 11
	style.corner_radius_top_right = 11
	style.corner_radius_bottom_left = 11
	style.corner_radius_bottom_right = 11
	style.content_margin_left = 12.0
	style.content_margin_top = 9.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 9.0
	return style


func _make_pill_style(
	background: Color,
	border: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 13
	style.corner_radius_bottom_right = 13
	style.content_margin_left = 12.0
	style.content_margin_top = 5.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 5.0
	return style


func _make_panel_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.44)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 8.0)
	return style

func _make_button_style(
	background: Color,
	border: Color,
	radius: int,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.26)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _play_intro() -> void:
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()

	victory_backdrop.modulate.a = 0.0
	victory_panel.modulate.a = 0.0
	clear_state_label.modulate.a = 0.0
	reward_panel.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0

	if victory_seal != null:
		victory_seal.modulate.a = 0.0
		victory_seal.scale = (
			Vector2.ONE
			if SettingsManager.reduced_effects
			else Vector2.ONE * 0.72
		)

	show()

	intro_tween = create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(
		victory_backdrop,
		"modulate:a",
		1.0,
		INTRO_BACKDROP_FADE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	intro_tween.tween_property(
		victory_panel,
		"modulate:a",
		1.0,
		INTRO_PANEL_FADE_DURATION
	).set_delay(INTRO_PANEL_DELAY).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)

	if victory_seal != null:
		intro_tween.tween_property(
			victory_seal,
			"modulate:a",
			1.0,
			0.24
		).set_delay(0.16)
		if not SettingsManager.reduced_effects:
			intro_tween.tween_property(
				victory_seal,
				"scale",
				Vector2.ONE,
				0.34
			).set_delay(0.16).set_trans(
				Tween.TRANS_BACK
			).set_ease(Tween.EASE_OUT)

	intro_tween.tween_property(
		clear_state_label,
		"modulate:a",
		1.0,
		0.22
	).set_delay(0.26)

	intro_tween.tween_property(
		reward_panel,
		"modulate:a",
		1.0,
		0.26
	).set_delay(0.34)

	intro_tween.tween_property(
		main_menu_button,
		"modulate:a",
		1.0,
		0.24
	).set_delay(0.44)


func _reset_intro_visual_state() -> void:
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
	victory_backdrop.modulate.a = 1.0
	victory_panel.modulate.a = 1.0
	clear_state_label.modulate.a = 1.0
	reward_panel.modulate.a = 1.0
	main_menu_button.modulate.a = 1.0
	if victory_seal != null:
		victory_seal.modulate.a = 1.0
		victory_seal.scale = Vector2.ONE

func _format_number(value: int) -> String:
	var magnitude: int = value
	if magnitude < 0:
		magnitude = -magnitude
	var raw_value: String = str(magnitude)
	var formatted: String = ""
	var digit_count: int = 0
	for index in range(raw_value.length() - 1, -1, -1):
		if digit_count > 0 and digit_count % 3 == 0:
			formatted = "," + formatted
		formatted = raw_value.substr(index, 1) + formatted
		digit_count += 1
	if value < 0:
		formatted = "-" + formatted
	return formatted

func _on_main_menu_pressed() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_reset_intro_visual_state()
	var change_error: Error = SceneTransitionManager.transition_to(
		MAIN_MENU_SCENE,
		{
			"title": "Returning in Triumph",
			"subtitle": "The Jade Sanctuary welcomes you",
			"minimum_display_time": 0.45
		}
	)
	if change_error != OK:
		push_error(
			"VictoryUI: gagal kembali ke Main Menu. Error code: "
			+ str(change_error)
		)
