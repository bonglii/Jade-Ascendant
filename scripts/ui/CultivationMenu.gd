extends Control

## Cultivation Hub
## Presentation layer for permanent cultivation progression.
## ProgressionManager remains the authority for state, cost, purchase and save.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const HEALTH_PER_VITALITY_LEVEL: int = 5
const SWORD_POWER_PERCENT_PER_LEVEL: int = 10
const SWIFT_QI_COOLDOWN_MULTIPLIER: float = 0.95

const PATH_DATA: Dictionary = {
	"vitality": {
		"name": "Vitality",
		"subtitle": "BODY MERIDIAN",
		"description": "Strengthen the body and expand the vessel of qi.",
		"accent": Color(0.34, 0.96, 0.66, 1.0)
	},
	"sword_power": {
		"name": "Sword Power",
		"subtitle": "SWORD DAO MERIDIAN",
		"description": "Refine sword intent into permanent spiritual power.",
		"accent": Color(1.0, 0.76, 0.26, 1.0)
	},
	"swift_qi": {
		"name": "Swift Qi",
		"subtitle": "FLOWING QI MERIDIAN",
		"description": "Circulate qi faster to shorten the interval between attacks.",
		"accent": Color(0.30, 0.87, 1.0, 1.0)
	}
}

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var mastery_label: Label = %MasteryLabel
@onready var formation: Control = %Formation
@onready var selected_path_subtitle: Label = %SelectedPathSubtitle
@onready var selected_path_name: Label = %SelectedPathName
@onready var level_label: Label = %LevelLabel
@onready var description_label: Label = %DescriptionLabel
@onready var current_effect_label: Label = %CurrentEffectLabel
@onready var next_effect_label: Label = %NextEffectLabel
@onready var cost_label: Label = %CostLabel
@onready var refine_button: Button = %RefineButton
@onready var insufficient_label: Label = %InsufficientLabel

@onready var top_bar: PanelContainer = $Content/TopBar
@onready var top_title: Label = $Content/TopBar/TopRow/TitleBox/TopTitle
@onready var top_subtitle: Label = $Content/TopBar/TopRow/TitleBox/TopSubtitle
@onready var stone_icon: TextureRect = $Content/TopBar/TopRow/StoneBox/StoneIcon
@onready var header_panel: PanelContainer = $Content/HeaderPanel
@onready var header_vbox: VBoxContainer = $Content/HeaderPanel/HeaderVBox
@onready var header_title: Label = $Content/HeaderPanel/HeaderVBox/HeaderTitle
@onready var eyebrow: Label = $Content/HeaderPanel/HeaderVBox/Eyebrow
@onready var detail_panel: PanelContainer = $Content/DetailPanel
@onready var detail_vbox: VBoxContainer = $Content/DetailPanel/DetailVBox
@onready var current_card: PanelContainer = $Content/DetailPanel/DetailVBox/EffectRow/CurrentCard
@onready var current_caption: Label = $Content/DetailPanel/DetailVBox/EffectRow/CurrentCard/CurrentVBox/CurrentCaption
@onready var next_card: PanelContainer = $Content/DetailPanel/DetailVBox/EffectRow/NextCard
@onready var next_caption: Label = $Content/DetailPanel/DetailVBox/EffectRow/NextCard/NextVBox/NextCaption
@onready var cost_icon: TextureRect = $Content/DetailPanel/DetailVBox/RefineRow/CostBox/CostIcon

var selected_path: String = "vitality"
var mastery_meter: ProgressBar = null
var path_meter: ProgressBar = null

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	_apply_premium_polish()
	if formation.has_signal("path_selected"):
		formation.connect("path_selected", _on_path_selected)
	refine_button.pressed.connect(_on_refine_pressed)
	if not ProgressionManager.cultivation_upgraded.is_connected(_on_cultivation_upgraded):
		ProgressionManager.cultivation_upgraded.connect(_on_cultivation_upgraded)
	update_display()
	DebugLogger.system(str("CultivationMenu aktif!"))

func _apply_premium_polish() -> void:
	# Keep the existing scene contract intact and only upgrade its presentation.
	top_bar.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.002, 0.020, 0.031, 0.96),
			Color(0.31, 0.92, 0.78, 0.42),
			10,
			8
		)
	)
	top_title.add_theme_font_size_override("font_size", 20)
	top_title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.52, 1.0))
	top_subtitle.add_theme_font_size_override("font_size", 10)
	spirit_stone_label.add_theme_font_size_override("font_size", 16)
	stone_icon.custom_minimum_size = Vector2(29.0, 29.0)

	header_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.002, 0.031, 0.043, 0.95),
			Color(0.96, 0.78, 0.33, 0.68),
			14,
			10
		)
	)
	header_vbox.add_theme_constant_override("separation", 2)
	eyebrow.add_theme_font_size_override("font_size", 11)
	eyebrow.add_theme_color_override("font_color", Color(0.39, 0.91, 0.78, 0.96))
	header_title.add_theme_font_size_override("font_size", 27)
	header_title.add_theme_color_override("font_color", Color(1.0, 0.89, 0.61, 1.0))
	mastery_label.add_theme_font_size_override("font_size", 11)

	mastery_meter = ProgressBar.new()
	mastery_meter.name = "MasteryMeter"
	mastery_meter.custom_minimum_size = Vector2(0.0, 10.0)
	mastery_meter.show_percentage = false
	mastery_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mastery_meter.add_theme_stylebox_override(
		"background",
		_make_meter_style(Color(0.006, 0.031, 0.038, 0.96), Color(0.18, 0.47, 0.44, 0.48))
	)
	mastery_meter.add_theme_stylebox_override(
		"fill",
		_make_meter_style(Color(0.20, 0.86, 0.69, 0.98), Color(0.98, 0.80, 0.36, 0.82))
	)
	header_vbox.add_child(mastery_meter)

	detail_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.002, 0.020, 0.032, 0.97),
			Color(0.32, 0.86, 0.74, 0.52),
			14,
			10
		)
	)
	detail_vbox.add_theme_constant_override("separation", 8)
	selected_path_subtitle.add_theme_font_size_override("font_size", 11)
	selected_path_name.add_theme_font_size_override("font_size", 24)
	level_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.82, 0.98))

	path_meter = ProgressBar.new()
	path_meter.name = "SelectedPathMeter"
	path_meter.custom_minimum_size = Vector2(0.0, 9.0)
	path_meter.show_percentage = false
	path_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	path_meter.add_theme_stylebox_override(
		"background",
		_make_meter_style(Color(0.004, 0.026, 0.034, 0.96), Color(0.20, 0.45, 0.43, 0.42))
	)
	path_meter.add_theme_stylebox_override(
		"fill",
		_make_meter_style(Color(0.28, 0.90, 0.73, 0.98), Color(0.98, 0.80, 0.36, 0.76))
	)
	detail_vbox.add_child(path_meter)
	detail_vbox.move_child(path_meter, description_label.get_index() + 1)

	current_caption.add_theme_font_size_override("font_size", 10)
	next_caption.add_theme_font_size_override("font_size", 10)
	current_effect_label.add_theme_font_size_override("font_size", 16)
	next_effect_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_icon.custom_minimum_size = Vector2(27.0, 27.0)
	refine_button.custom_minimum_size.y = 62.0
	refine_button.add_theme_font_size_override("font_size", 19)
	insufficient_label.add_theme_font_size_override("font_size", 11)
	insufficient_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.76, 0.96))

	current_card.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.005, 0.068, 0.066, 0.90),
			Color(0.28, 0.87, 0.73, 0.58),
			10,
			3
		)
	)
	next_card.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.063, 0.044, 0.010, 0.88),
			Color(0.97, 0.79, 0.33, 0.72),
			10,
			3
		)
	)

func _make_panel_style(
	bg_color: Color,
	border_color: Color,
	radius: int,
	shadow_size: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14.0
	style.content_margin_top = 9.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 9.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = shadow_size
	return style

func _make_meter_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func update_display() -> void:
	spirit_stone_label.text = _format_amount(ProgressionManager.spirit_stone)
	var total_level: int = (
		ProgressionManager.vitality_level
		+ ProgressionManager.sword_power_level
		+ ProgressionManager.swift_qi_level
	)
	var total_max: int = (
		ProgressionManager.VITALITY_MAX_LEVEL
		+ ProgressionManager.SWORD_POWER_MAX_LEVEL
		+ ProgressionManager.SWIFT_QI_MAX_LEVEL
	)
	mastery_label.text = tr("MERIDIAN MASTERY %d / %d") % [total_level, total_max]
	if mastery_meter != null:
		mastery_meter.max_value = float(maxi(total_max, 1))
		mastery_meter.value = float(total_level)
	if formation.has_method("set_state"):
		formation.call("set_state", _build_formation_state(), selected_path)
	_update_detail_panel()

func _build_formation_state() -> Dictionary:
	return {
		"vitality": {
			"level": ProgressionManager.vitality_level,
			"max_level": ProgressionManager.VITALITY_MAX_LEVEL,
			"affordable": _can_afford_path("vitality"),
			"maxed": ProgressionManager.is_vitality_maxed()
		},
		"sword_power": {
			"level": ProgressionManager.sword_power_level,
			"max_level": ProgressionManager.SWORD_POWER_MAX_LEVEL,
			"affordable": _can_afford_path("sword_power"),
			"maxed": ProgressionManager.is_sword_power_maxed()
		},
		"swift_qi": {
			"level": ProgressionManager.swift_qi_level,
			"max_level": ProgressionManager.SWIFT_QI_MAX_LEVEL,
			"affordable": _can_afford_path("swift_qi"),
			"maxed": ProgressionManager.is_swift_qi_maxed()
		}
	}

func _update_detail_panel() -> void:
	var data: Dictionary = PATH_DATA.get(selected_path, PATH_DATA["vitality"])
	var level: int = _get_path_level(selected_path)
	var max_level: int = _get_path_max_level(selected_path)
	var maxed: bool = _is_path_maxed(selected_path)
	var cost: int = _get_path_cost(selected_path)
	var accent: Color = data.get("accent", Color(0.32, 0.90, 0.76, 1.0))

	selected_path_subtitle.text = tr(str(data.get("subtitle", "MERIDIAN")))
	selected_path_name.text = tr(str(data.get("name", "Cultivation")))
	selected_path_name.add_theme_color_override("font_color", accent)
	level_label.text = tr("LEVEL %d / %d") % [level, max_level]
	description_label.text = tr(str(data.get("description", "")))
	if path_meter != null:
		path_meter.max_value = float(maxi(max_level, 1))
		path_meter.value = float(level)
	current_effect_label.text = _get_current_effect_text(selected_path, level)
	next_effect_label.text = _get_next_effect_text(selected_path, level, maxed)
	_refresh_detail_accent(accent)

	if maxed:
		cost_label.text = "MAX"
		refine_button.disabled = true
		refine_button.text = tr("MERIDIAN PERFECTED")
		insufficient_label.text = tr("This meridian has reached its current limit.")
		return

	cost_label.text = _format_amount(cost)
	refine_button.disabled = ProgressionManager.spirit_stone < cost
	refine_button.text = tr("REFINE MERIDIAN")

	if refine_button.disabled:
		var missing: int = maxi(cost - ProgressionManager.spirit_stone, 0)
		insufficient_label.text = tr("Need %d more Spirit Stones.") % missing
	else:
		insufficient_label.text = tr("Permanent upgrade • persists between journeys.")

func _refresh_detail_accent(accent: Color) -> void:
	var border: Color = accent
	border.a = 0.60
	detail_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.002, 0.020, 0.032, 0.97), border, 14, 10)
	)
	var current_border: Color = accent
	current_border.a = 0.52
	current_card.add_theme_stylebox_override(
		"panel",
		_make_panel_style(Color(0.005, 0.055, 0.060, 0.90), current_border, 10, 3)
	)
	if path_meter != null:
		var fill_border: Color = accent.lerp(Color(1.0, 0.82, 0.40, 1.0), 0.18)
		fill_border.a = 0.86
		path_meter.add_theme_stylebox_override(
			"fill",
			_make_meter_style(Color(accent.r, accent.g, accent.b, 0.92), fill_border)
		)

func _get_current_effect_text(path_id: String, level: int) -> String:
	match path_id:
		"vitality":
			return tr("+%d MAX HP") % (level * HEALTH_PER_VITALITY_LEVEL)
		"sword_power":
			return tr("+%d%% POWER") % (level * SWORD_POWER_PERCENT_PER_LEVEL)
		"swift_qi":
			var attack_speed: float = _get_swift_qi_attack_speed(level)
			return tr("%.3f ATTACKS/S") % attack_speed
		_:
			return tr("CURRENT EFFECT")

func _get_next_effect_text(path_id: String, level: int, maxed: bool) -> String:
	if maxed:
		return tr("PERFECTED")
	var next_level: int = level + 1
	match path_id:
		"vitality":
			return tr("+%d MAX HP") % (next_level * HEALTH_PER_VITALITY_LEVEL)
		"sword_power":
			return tr("+%d%% POWER") % (next_level * SWORD_POWER_PERCENT_PER_LEVEL)
		"swift_qi":
			var next_speed: float = _get_swift_qi_attack_speed(next_level)
			return tr("%.3f ATTACKS/S") % next_speed
		_:
			return tr("NEXT REFINEMENT")

func _get_swift_qi_attack_speed(level: int) -> float:
	var cooldown: float = pow(SWIFT_QI_COOLDOWN_MULTIPLIER, float(level))
	return 1.0 / maxf(cooldown, 0.2)

func _get_path_level(path_id: String) -> int:
	match path_id:
		"vitality":
			return ProgressionManager.vitality_level
		"sword_power":
			return ProgressionManager.sword_power_level
		"swift_qi":
			return ProgressionManager.swift_qi_level
		_:
			return 0

func _get_path_max_level(path_id: String) -> int:
	match path_id:
		"vitality":
			return ProgressionManager.VITALITY_MAX_LEVEL
		"sword_power":
			return ProgressionManager.SWORD_POWER_MAX_LEVEL
		"swift_qi":
			return ProgressionManager.SWIFT_QI_MAX_LEVEL
		_:
			return 0

func _get_path_cost(path_id: String) -> int:
	match path_id:
		"vitality":
			return ProgressionManager.get_vitality_cost()
		"sword_power":
			return ProgressionManager.get_sword_power_cost()
		"swift_qi":
			return ProgressionManager.get_swift_qi_cost()
		_:
			return 0

func _is_path_maxed(path_id: String) -> bool:
	match path_id:
		"vitality":
			return ProgressionManager.is_vitality_maxed()
		"sword_power":
			return ProgressionManager.is_sword_power_maxed()
		"swift_qi":
			return ProgressionManager.is_swift_qi_maxed()
		_:
			return true

func _can_afford_path(path_id: String) -> bool:
	if _is_path_maxed(path_id):
		return false
	return ProgressionManager.spirit_stone >= _get_path_cost(path_id)

func _buy_selected_path() -> bool:
	match selected_path:
		"vitality":
			return ProgressionManager.buy_vitality()
		"sword_power":
			return ProgressionManager.buy_sword_power()
		"swift_qi":
			return ProgressionManager.buy_swift_qi()
		_:
			return false

func _on_path_selected(path_id: String) -> void:
	if not PATH_DATA.has(path_id):
		return
	selected_path = path_id
	if formation.has_method("set_selected_path"):
		formation.call("set_selected_path", selected_path)
	_update_detail_panel()

func _on_refine_pressed() -> void:
	if _is_path_maxed(selected_path):
		return
	if not _can_afford_path(selected_path):
		_update_detail_panel()
		return
	if _buy_selected_path():
		if formation.has_method("celebrate"):
			formation.call("celebrate", selected_path)

func _on_cultivation_upgraded(_upgrade_id: String, _new_level: int) -> void:
	update_display()

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("CultivationMenu: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error(
			"CultivationMenu: gagal kembali ke Journey Hub. Error code: "
			+ str(change_error)
		)

func _format_amount(value: int) -> String:
	var digits: String = str(maxi(value, 0))
	var formatted: String = ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted
