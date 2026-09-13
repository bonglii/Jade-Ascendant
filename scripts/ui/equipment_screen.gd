extends Control

## Hero / Equipment Hub
## Presentation layer only. EquipmentManager owns equipment state/save and
## InventoryManager owns item ownership/counts.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const BACKPACK_SCENE: String = "res://scenes/ui/backpack_screen.tscn"
const EquipmentVisualCatalog = preload("res://scripts/ui/equipment_visual_catalog.gd")

const SLOT_ORDER: Array[String] = [
	"armament",
	"robe",
	"bracer",
	"pendant",
	"boots"
]

const COMPARISON_KEYS: Array[String] = [
	"max_health_flat",
	"damage_bonus",
	"movement_speed_bonus",
	"experience_bonus",
	"critical_chance_bonus",
	"critical_damage_bonus",
	"pickup_radius_bonus",
	"starting_shield_charges",
	"blood_qi_heal_bonus"
]

@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var equipped_count_label: Label = %EquippedCountLabel
@onready var status_label: Label = %StatusLabel
@onready var bonus_summary_label: Label = %BonusSummaryLabel
@onready var hero_preview_sprite: AnimatedSprite2D = %HeroPreviewSprite
@onready var armament_button: Button = %ArmamentButton
@onready var robe_button: Button = %RobeButton
@onready var bracer_button: Button = %BracerButton
@onready var pendant_button: Button = %PendantButton
@onready var boots_button: Button = %BootsButton
@onready var selected_slot_label: Label = %SelectedSlotLabel
@onready var equipped_item_label: Label = %EquippedItemLabel
@onready var selected_item_icon: TextureRect = %SelectedItemIcon
@onready var item_role_label: Label = %ItemRoleLabel
@onready var selected_stat_label: Label = %SelectedStatLabel
@onready var signature_effect_label: Label = %SignatureEffectLabel
@onready var ascension_status_label: Label = %AscensionStatusLabel
@onready var ascension_preview_label: Label = %AscensionPreviewLabel
@onready var ascend_button: Button = %AscendButton
@onready var ascend_hint_label: Label = %AscendHintLabel
@onready var compare_label: Label = %CompareLabel
@onready var candidate_grid: GridContainer = %CandidateGrid
@onready var action_button: Button = %ActionButton
@onready var action_hint_label: Label = %ActionHintLabel
@onready var backpack_tab_button: Button = %BackpackTabButton
@onready var detail_panel: PanelContainer = %DetailPanel
@onready var detail_close_button: Button = %DetailCloseButton

var selected_slot_id: String = "robe"
var selected_item_id: String = ""
var detail_open: bool = false

func _ready() -> void:
	SceneTransitionManager.set_back_handler(handle_system_back)
	armament_button.pressed.connect(_on_slot_pressed.bind("armament"))
	robe_button.pressed.connect(_on_slot_pressed.bind("robe"))
	bracer_button.pressed.connect(_on_slot_pressed.bind("bracer"))
	pendant_button.pressed.connect(_on_slot_pressed.bind("pendant"))
	boots_button.pressed.connect(_on_slot_pressed.bind("boots"))
	action_button.pressed.connect(_on_action_pressed)
	ascend_button.pressed.connect(_on_ascend_pressed)
	detail_close_button.pressed.connect(_close_detail)
	backpack_tab_button.pressed.connect(_open_backpack)
	if not EquipmentManager.equipment_changed.is_connected(_on_equipment_changed):
		EquipmentManager.equipment_changed.connect(_on_equipment_changed)
	if not InventoryManager.inventory_changed.is_connected(_on_inventory_changed):
		InventoryManager.inventory_changed.connect(_on_inventory_changed)
	if not EquipmentManager.equipment_ascended.is_connected(_on_equipment_ascended):
		EquipmentManager.equipment_ascended.connect(_on_equipment_ascended)
	if hero_preview_sprite.sprite_frames != null and hero_preview_sprite.sprite_frames.has_animation(&"idle_down"):
		hero_preview_sprite.play(&"idle_down")
	_refresh_screen()
	detail_panel.visible = detail_open
	DebugLogger.system(str("Hero Equipment Hub aktif!"))

func _refresh_screen() -> void:
	spirit_stone_label.text = "%d" % ProgressionManager.spirit_stone
	var can_modify: bool = EquipmentManager.can_modify_equipment()
	var equipped_count: int = _get_equipped_count()
	equipped_count_label.text = tr("EQUIPPED %d / %d") % [equipped_count, SLOT_ORDER.size()]
	if can_modify:
		status_label.text = tr("LOADOUT READY  •  SELECT A SLOT TO ATTUNE")
		hero_preview_sprite.modulate = Color.WHITE
	else:
		status_label.text = tr("LOADOUT SEALED  •  ACTIVE RUN CHECKPOINT")
		hero_preview_sprite.modulate = Color(0.78, 0.86, 0.90, 0.92)
	bonus_summary_label.text = _build_bonus_summary()
	_refresh_slot_button(armament_button, "armament")
	_refresh_slot_button(robe_button, "robe")
	_refresh_slot_button(bracer_button, "bracer")
	_refresh_slot_button(pendant_button, "pendant")
	_refresh_slot_button(boots_button, "boots")
	_validate_selected_item()
	_rebuild_candidate_grid()
	_refresh_detail_panel(can_modify)
	detail_panel.visible = detail_open

func _refresh_slot_button(button: Button, slot_id: String) -> void:
	var equipped_item_id: String = EquipmentManager.get_equipped_item_id(slot_id)
	var item_name: String = "EMPTY"
	var icon_texture: Texture2D = null
	if not equipped_item_id.is_empty():
		var item_data: Dictionary = EquipmentManager.get_item_data(equipped_item_id)
		item_name = str(item_data.get("display_name", equipped_item_id))
		icon_texture = _load_item_icon(equipped_item_id)
	button.text = "" if icon_texture != null else EquipmentVisualCatalog.get_slot_title(slot_id)
	button.icon = icon_texture
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 46)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 9)
	var selected: bool = detail_open and slot_id == selected_slot_id
	button.add_theme_stylebox_override("normal", _make_slot_style(selected, false))
	button.add_theme_stylebox_override("hover", _make_slot_style(selected, true))
	button.add_theme_stylebox_override("pressed", _make_slot_style(true, true))
	button.add_theme_stylebox_override("focus", _make_slot_style(true, true))
	button.tooltip_text = (
		"%s — %s" % [item_name, EquipmentVisualCatalog.get_slot_role(slot_id)]
		if not equipped_item_id.is_empty()
		else "Empty %s slot" % EquipmentVisualCatalog.get_slot_title(slot_id).to_lower()
	)

func _validate_selected_item() -> void:
	if selected_item_id.is_empty():
		return
	if EquipmentManager.has_item_definition(selected_item_id):
		return
	selected_item_id = ""
	detail_open = false

func _get_all_equipment_item_ids() -> Array[String]:
	var result: Array[String] = []
	for slot_id: String in SLOT_ORDER:
		for item_id: String in EquipmentManager.get_item_ids_for_slot(slot_id):
			if not result.has(item_id):
				result.append(item_id)
	return result

func _rebuild_candidate_grid() -> void:
	for child: Node in candidate_grid.get_children():
		child.queue_free()
	for item_id: String in _get_all_equipment_item_ids():
		candidate_grid.add_child(_create_candidate_button(item_id))

func _create_candidate_button(item_id: String) -> Button:
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var slot_id: String = str(item_data.get("slot", ""))
	var owned_count: int = InventoryManager.get_item_count(item_id)
	var equipped: bool = EquipmentManager.get_equipped_item_id(slot_id) == item_id
	var selected: bool = detail_open and item_id == selected_item_id
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(112.0, 88.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 8)
	button.icon = _load_item_icon(item_id)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 48)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = ""
	var rarity_color: Color = EquipmentVisualCatalog.get_rarity_color(str(item_data.get("rarity", "common")))
	button.add_theme_stylebox_override("normal", _make_candidate_style(rarity_color, equipped, selected, owned_count > 0, false))
	button.add_theme_stylebox_override("hover", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	button.add_theme_stylebox_override("pressed", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	button.add_theme_stylebox_override("focus", _make_candidate_style(rarity_color, equipped, true, owned_count > 0, true))
	if selected:
		button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.54, 1.0))
	elif owned_count <= 0:
		button.add_theme_color_override("font_color", Color(0.46, 0.52, 0.54, 0.82))
	else:
		button.add_theme_color_override("font_color", Color(0.74, 0.90, 0.86, 1.0))
	_add_star_badge(button, EquipmentManager.get_item_star(item_id), owned_count > 0)
	button.pressed.connect(_on_candidate_pressed.bind(item_id))
	var effective_data: Dictionary = EquipmentManager.get_effective_item_data(item_id)
	button.tooltip_text = "%s\n%s  •  %s\n%s" % [
		str(item_data.get("display_name", item_id)),
		_format_stars(EquipmentManager.get_item_star(item_id)),
		EquipmentVisualCatalog.get_stat_summary(effective_data),
		EquipmentVisualCatalog.get_signature_effect_description(item_data)
	]
	return button

func _make_slot_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.062, 0.069, 0.91) if selected else Color(0.001, 0.021, 0.032, 0.82)
	if hovered:
		style.bg_color = Color(0.010, 0.092, 0.088, 0.96)
	var border_color: Color = Color(0.96, 0.78, 0.36, 0.88) if selected else Color(0.28, 0.82, 0.72, 0.42)
	if hovered and not selected:
		border_color = Color(0.36, 0.90, 0.78, 0.70)
	var border_width: int = 2 if selected else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 4.0
	style.content_margin_top = 3.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 3.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 1
	return style

func _make_candidate_style(rarity_color: Color, equipped: bool, selected: bool, owned: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.002, 0.026, 0.038, 0.88)
	if selected or hovered:
		style.bg_color = Color(0.008, 0.069, 0.071, 0.95)
	var border_color: Color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.58)
	if not owned:
		border_color = Color(0.26, 0.34, 0.36, 0.52)
	if equipped:
		border_color = Color(0.34, 0.90, 0.75, 0.86)
	if selected:
		border_color = Color(0.98, 0.80, 0.38, 0.96)
	var border_width: int = 2 if selected else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	return style

func _refresh_detail_panel(can_modify: bool) -> void:
	selected_slot_label.text = "%s  •  %s" % [
		tr(EquipmentVisualCatalog.get_slot_title(selected_slot_id)),
		tr(EquipmentVisualCatalog.get_slot_focus(selected_slot_id))
	]
	var equipped_item_id: String = EquipmentManager.get_equipped_item_id(selected_slot_id)
	if equipped_item_id.is_empty():
		equipped_item_label.text = tr("EQUIPPED  •  NONE")
	else:
		var equipped_data: Dictionary = EquipmentManager.get_effective_item_data(equipped_item_id)
		equipped_item_label.text = tr("EQUIPPED  •  %s  •  %s") % [
			str(equipped_data.get("display_name", equipped_item_id)),
			tr(str(equipped_data.get("rarity", "common")).to_upper())
		]

	if selected_item_id.is_empty():
		selected_item_icon.texture = null
		item_role_label.text = tr("NO EQUIPMENT")
		selected_stat_label.text = tr("No equipment definition is available for this slot.")
		signature_effect_label.text = tr("SIGNATURE EFFECT  •  NONE")
		compare_label.text = tr("LOADOUT IMPACT  •  NONE")
		ascension_status_label.text = tr("ASCENSION  •  NO ITEM")
		ascension_preview_label.text = ""
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = ""
		action_button.text = tr("NO ITEM AVAILABLE")
		action_button.disabled = true
		action_hint_label.text = ""
		return

	var selected_base_data: Dictionary = EquipmentManager.get_item_data(selected_item_id)
	var selected_data: Dictionary = EquipmentManager.get_effective_item_data(selected_item_id)
	var selected_star: int = EquipmentManager.get_item_star(selected_item_id)
	selected_item_icon.texture = _load_item_icon(selected_item_id)
	item_role_label.text = "%s  •  %s  •  %s  •  %s" % [
		str(selected_data.get("display_name", selected_item_id)),
		tr(str(selected_data.get("rarity", "common")).to_upper()),
		_format_stars(selected_star),
		tr(EquipmentVisualCatalog.get_slot_role(selected_slot_id))
	]
	item_role_label.add_theme_color_override(
		"font_color",
		EquipmentVisualCatalog.get_rarity_color(str(selected_data.get("rarity", "common")))
	)
	selected_stat_label.text = tr("CORE PASSIVE  •  %s  •  Owned x%d") % [
		_get_item_stat_text(selected_data),
		InventoryManager.get_item_count(selected_item_id)
	]
	signature_effect_label.text = "%s  •  %s" % [
		tr(EquipmentVisualCatalog.get_signature_effect_name(selected_base_data)),
		tr(EquipmentVisualCatalog.get_signature_effect_description(selected_base_data))
	]
	compare_label.text = _build_loadout_impact(equipped_item_id, selected_item_id)
	_refresh_ascension_controls(can_modify)

	var is_equipped: bool = equipped_item_id == selected_item_id
	if not can_modify:
		action_button.text = tr("LOADOUT SEALED")
		action_button.disabled = true
		action_hint_label.text = tr("Finish or clear the active run before changing equipment.")
	elif is_equipped:
		action_button.text = tr("UNEQUIP")
		action_button.disabled = false
		action_hint_label.text = tr("Remove this item from the permanent loadout.")
	elif not InventoryManager.owns_item(selected_item_id):
		action_button.text = tr("ITEM NOT OWNED")
		action_button.disabled = true
		action_hint_label.text = tr("Inspect it here; forge or acquire it before equipping.")
	else:
		action_button.text = tr("EQUIP ITEM")
		action_button.disabled = false
		action_hint_label.text = tr("Applies immediately and saves outside active runs.")

func _build_loadout_impact(equipped_item_id: String, inspected_item_id: String) -> String:
	if inspected_item_id.is_empty():
		return tr("LOADOUT IMPACT  •  NONE")
	if equipped_item_id == inspected_item_id:
		return tr("LOADOUT IMPACT  •  NO CHANGE — CURRENTLY EQUIPPED")
	var inspected_data: Dictionary = EquipmentManager.get_effective_item_data(inspected_item_id)
	if equipped_item_id.is_empty():
		return tr("LOADOUT IMPACT  •  EQUIP TO APPLY %s") % _get_item_stat_text(inspected_data).to_upper()
	var equipped_data: Dictionary = EquipmentManager.get_effective_item_data(equipped_item_id)
	var deltas: Array[String] = []
	for stat_key: String in COMPARISON_KEYS:
		var old_value: float = float(equipped_data.get(stat_key, 0.0))
		var new_value: float = float(inspected_data.get(stat_key, 0.0))
		var delta: float = new_value - old_value
		if is_zero_approx(delta):
			continue
		deltas.append(_format_stat_delta(stat_key, delta))
	if deltas.is_empty():
		return tr("LOADOUT IMPACT  •  NO STAT CHANGE")
	return tr("LOADOUT IMPACT  •  %s") % "  •  ".join(deltas)

func _format_stat_delta(stat_key: String, delta: float) -> String:
	var prefix: String = "+" if delta > 0.0 else ""
	match stat_key:
		"max_health_flat":
			return "%s%.0f HP" % [prefix, delta]
		"damage_bonus":
			return "%s%.1f%% DMG" % [prefix, delta * 100.0]
		"movement_speed_bonus":
			return "%s%.1f%% MOVE" % [prefix, delta * 100.0]
		"experience_bonus":
			return "%s%.1f%% EXP" % [prefix, delta * 100.0]
		"critical_chance_bonus":
			return "%s%.1f%% CRIT" % [prefix, delta * 100.0]
		"critical_damage_bonus":
			return "%s%.1f%% CRIT DMG" % [prefix, delta * 100.0]
		"pickup_radius_bonus":
			return "%s%.0f PICKUP" % [prefix, delta]
		"starting_shield_charges":
			return "%s%.0f SHIELD" % [prefix, delta]
		"blood_qi_heal_bonus":
			return "%s%.2f BLOOD QI" % [prefix, delta]
		_:
			return "%s%.2f" % [prefix, delta]

func _refresh_ascension_controls(can_modify: bool) -> void:
	if selected_item_id.is_empty() or not EquipmentManager.has_item_definition(selected_item_id):
		ascension_status_label.text = tr("ASCENSION  •  NO ITEM")
		ascension_preview_label.text = ""
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = ""
		return

	var current_star: int = EquipmentManager.get_item_star(selected_item_id)
	var shard_balance: int = InventoryManager.get_item_count(InventoryManager.REFINEMENT_SHARD)
	ascension_status_label.text = tr("ASCENSION  •  %s  •  REFINEMENT SHARDS %d") % [
		_format_stars(current_star),
		shard_balance
	]

	if not InventoryManager.owns_item(selected_item_id):
		ascension_preview_label.text = tr("Acquire this equipment before ascending it.")
		ascend_button.text = tr("ASCENSION LOCKED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Ascension strengthens core passives only; Signature Effects stay fixed.")
		return

	if current_star >= EquipmentManager.MAX_ASCENSION_STAR:
		ascension_preview_label.text = tr("MAX ASCENSION  •  CORE PASSIVE +20% FROM 1★")
		ascend_button.text = tr("MAX ASCENSION")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("This equipment has reached 5★.")
		return

	var target_star: int = current_star + 1
	var cost: int = EquipmentManager.get_ascension_cost(selected_item_id)
	ascension_preview_label.text = tr("NEXT %d★  •  %s") % [
		target_star,
		_build_ascension_stat_preview(selected_item_id, target_star)
	]

	if not can_modify:
		ascend_button.text = tr("ASCENSION SEALED")
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Finish or clear the active run before ascending equipment.")
	elif shard_balance < cost:
		ascend_button.text = tr("ASCEND TO %d★  •  %d SHARDS") % [target_star, cost]
		ascend_button.disabled = true
		ascend_hint_label.text = tr("Need %d more Refinement Shards.") % (cost - shard_balance)
	else:
		ascend_button.text = tr("ASCEND TO %d★  •  %d SHARDS") % [target_star, cost]
		ascend_button.disabled = false
		ascend_hint_label.text = tr("Ascension strengthens core passives only; Signature Effects stay fixed.")

func _build_ascension_stat_preview(item_id: String, target_star: int) -> String:
	var base_data: Dictionary = EquipmentManager.get_item_data(item_id)
	var current_data: Dictionary = EquipmentManager.get_effective_item_data(item_id)
	var target_multiplier: float = float(EquipmentManager.ASCENSION_CORE_MULTIPLIERS.get(target_star, 1.0))
	var transitions: Array[String] = []
	for stat_key: String in EquipmentManager.ASCENSION_SCALABLE_STATS:
		if not base_data.has(stat_key):
			continue
		var current_value: float = float(current_data.get(stat_key, 0.0))
		var target_value: float = float(base_data.get(stat_key, 0.0)) * target_multiplier
		transitions.append(_format_stat_transition(stat_key, current_value, target_value))
	if transitions.is_empty():
		return tr("CORE PASSIVE UNCHANGED")
	return "  •  ".join(transitions)

func _format_stat_transition(stat_key: String, current_value: float, target_value: float) -> String:
	match stat_key:
		"max_health_flat":
			return "%.1f → %.1f HP" % [current_value, target_value]
		"damage_bonus":
			return "%.1f%% → %.1f%% DMG" % [current_value * 100.0, target_value * 100.0]
		"movement_speed_bonus":
			return "%.1f%% → %.1f%% MOVE" % [current_value * 100.0, target_value * 100.0]
		"experience_bonus":
			return "%.1f%% → %.1f%% EXP" % [current_value * 100.0, target_value * 100.0]
		"critical_chance_bonus":
			return "%.1f%% → %.1f%% CRIT" % [current_value * 100.0, target_value * 100.0]
		_:
			return "%.2f → %.2f" % [current_value, target_value]

func _format_stars(star: int) -> String:
	var clamped_star: int = clampi(star, 0, EquipmentManager.MAX_ASCENSION_STAR)
	var result: String = ""
	for index: int in range(EquipmentManager.MAX_ASCENSION_STAR):
		result += "★" if index < clamped_star else "☆"
	return result

func _add_star_badge(parent_button: Button, star: int, owned: bool) -> void:
	var badge: Label = Label.new()
	badge.name = "StarBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.anchor_left = 0.0
	badge.anchor_top = 1.0
	badge.anchor_right = 1.0
	badge.anchor_bottom = 1.0
	badge.offset_left = 4.0
	badge.offset_top = -20.0
	badge.offset_right = -4.0
	badge.offset_bottom = -2.0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 9)
	badge.add_theme_color_override(
		"font_color",
		Color(1.0, 0.84, 0.38, 0.96) if owned else Color(0.46, 0.52, 0.54, 0.72)
	)
	badge.text = _format_stars(star)
	parent_button.add_child(badge)

func _get_compact_stat_text(item_data: Dictionary) -> String:
	var summary: String = EquipmentVisualCatalog.get_stat_summary(item_data)
	var parts: PackedStringArray = summary.split(" • ")
	if parts.is_empty():
		return summary
	return str(parts[0])

func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path: String = EquipmentVisualCatalog.get_icon_path(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	var icon_resource: Resource = ResourceLoader.load(icon_path)
	if icon_resource is Texture2D:
		return icon_resource as Texture2D
	return null

func _build_bonus_summary() -> String:
	var parts: Array[String] = []
	var hp_bonus: float = EquipmentManager.get_total_max_health_bonus()
	var damage_bonus: float = (EquipmentManager.get_damage_multiplier() - 1.0) * 100.0
	var move_bonus: float = (EquipmentManager.get_movement_speed_multiplier() - 1.0) * 100.0
	var exp_bonus: float = (EquipmentManager.get_experience_multiplier() - 1.0) * 100.0
	var crit_bonus: float = EquipmentManager.get_critical_chance_bonus() * 100.0
	if hp_bonus != 0.0:
		parts.append("+%.0f HP" % hp_bonus)
	if damage_bonus != 0.0:
		parts.append("+%.0f%% DMG" % damage_bonus)
	if move_bonus != 0.0:
		parts.append("+%.0f%% MOVE" % move_bonus)
	if exp_bonus != 0.0:
		parts.append("+%.0f%% EXP" % exp_bonus)
	if crit_bonus != 0.0:
		parts.append("+%.0f%% CRIT" % crit_bonus)
	return tr("NO ACTIVE LOADOUT BONUSES") if parts.is_empty() else "  •  ".join(parts)

func _get_equipped_count() -> int:
	var count: int = 0
	for slot_id: String in SLOT_ORDER:
		if not EquipmentManager.get_equipped_item_id(slot_id).is_empty():
			count += 1
	return count

func _get_item_stat_text(item_data: Dictionary) -> String:
	return EquipmentVisualCatalog.get_stat_summary(item_data)

func _on_slot_pressed(slot_id: String) -> void:
	if not SLOT_ORDER.has(slot_id):
		return
	selected_slot_id = slot_id
	selected_item_id = EquipmentManager.get_equipped_item_id(slot_id)
	detail_open = not selected_item_id.is_empty()
	_refresh_screen()

func _on_candidate_pressed(item_id: String) -> void:
	if not EquipmentManager.has_item_definition(item_id):
		return
	var item_data: Dictionary = EquipmentManager.get_item_data(item_id)
	selected_slot_id = str(item_data.get("slot", selected_slot_id))
	selected_item_id = item_id
	detail_open = true
	_refresh_screen()

func _close_detail() -> void:
	detail_open = false
	_refresh_screen()

func _on_action_pressed() -> void:
	if selected_item_id.is_empty():
		return
	if not EquipmentManager.can_modify_equipment():
		_refresh_screen()
		return
	var equipped_item_id: String = EquipmentManager.get_equipped_item_id(selected_slot_id)
	if equipped_item_id == selected_item_id:
		EquipmentManager.unequip_slot(selected_slot_id)
	else:
		EquipmentManager.equip_item(selected_item_id)

func _on_ascend_pressed() -> void:
	if selected_item_id.is_empty():
		return
	if EquipmentManager.ascend_item(selected_item_id):
		_refresh_screen()

func _on_equipment_ascended(item_id: String, _old_star: int, _new_star: int) -> void:
	if item_id == selected_item_id:
		_refresh_screen()

func _on_equipment_changed(_slot_id: String, _item_id: String) -> void:
	_refresh_screen()

func _on_inventory_changed(_item_id: String, _new_count: int) -> void:
	_refresh_screen()

func _open_backpack() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(BACKPACK_SCENE):
		push_error("HeroEquipment: Backpack scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(BACKPACK_SCENE, 1)
	if change_error != OK:
		push_error("HeroEquipment: gagal membuka Backpack. Error code: " + str(change_error))

func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	_return_to_journey()

func _return_to_journey() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error("HeroEquipment: Main Menu scene tidak ditemukan.")
		return
	var change_error: Error = SceneTransitionManager.transition_menu_to(MAIN_MENU_SCENE, -1)
	if change_error != OK:
		push_error("HeroEquipment: gagal kembali ke Journey. Error code: " + str(change_error))
