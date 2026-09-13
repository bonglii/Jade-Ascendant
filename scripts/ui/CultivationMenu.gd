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
		"description": "Strengthen the body and expand the vessel of qi."
	},
	"sword_power": {
		"name": "Sword Power",
		"subtitle": "SWORD DAO MERIDIAN",
		"description": "Refine sword intent into permanent spiritual power."
	},
	"swift_qi": {
		"name": "Swift Qi",
		"subtitle": "FLOWING QI MERIDIAN",
		"description": "Circulate qi faster to shorten the interval between attacks."
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

var selected_path: String = "vitality"

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	if formation.has_signal("path_selected"):
		formation.connect("path_selected", _on_path_selected)
	refine_button.pressed.connect(_on_refine_pressed)
	if not ProgressionManager.cultivation_upgraded.is_connected(_on_cultivation_upgraded):
		ProgressionManager.cultivation_upgraded.connect(_on_cultivation_upgraded)
	update_display()
	DebugLogger.system(str("CultivationMenu aktif!"))

func update_display() -> void:
	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone
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

	selected_path_subtitle.text = str(data.get("subtitle", "MERIDIAN"))
	selected_path_name.text = str(data.get("name", "Cultivation"))
	level_label.text = tr("LEVEL %d / %d") % [level, max_level]
	description_label.text = str(data.get("description", ""))
	current_effect_label.text = _get_current_effect_text(selected_path, level)
	next_effect_label.text = _get_next_effect_text(selected_path, level, maxed)

	if maxed:
		cost_label.text = "MAX"
		refine_button.disabled = true
		refine_button.text = "MERIDIAN PERFECTED"
		insufficient_label.text = "This meridian has reached its current limit."
		return

	cost_label.text = "%d" % cost
	refine_button.disabled = ProgressionManager.spirit_stone < cost
	refine_button.text = "REFINE MERIDIAN"

	if refine_button.disabled:
		var missing: int = maxi(cost - ProgressionManager.spirit_stone, 0)
		insufficient_label.text = tr("Need %d more Spirit Stones.") % missing
	else:
		insufficient_label.text = "Permanent upgrade • persists between journeys."

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
			return "CURRENT EFFECT"

func _get_next_effect_text(path_id: String, level: int, maxed: bool) -> String:
	if maxed:
		return "PERFECTED"
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
			return "NEXT REFINEMENT"

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
