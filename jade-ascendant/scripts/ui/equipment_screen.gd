extends Control

## Jade Ascendant production Hero / Equipment / Inventory hub.
## Visual structure is the approved Unified Hero + Tas design.
## EquipmentManager remains authoritative for loadout/save/ascension.
## InventoryManager remains authoritative for ownership/counts.

const EquipmentVisualCatalog = preload(
	"res://scripts/ui/equipment_visual_catalog.gd"
)
const EquipmentSetCatalog = preload(
	"res://scripts/data/equipment_set_catalog.gd"
)

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

const SLOT_BUTTON_NODE_NAMES: Dictionary = {
	"armament": "ArmamentButton",
	"robe": "RobeButton",
	"bracer": "BracerButton",
	"pendant": "PendantButton",
	"boots": "BootsButton"
}

const SLOT_FRAME_DEFAULT: Texture2D = preload(
	"res://assets/ui/system_v2/custom/slots/relic_slot_default.svg"
)
const SLOT_FRAME_SELECTED: Texture2D = preload(
	"res://assets/ui/system_v2/custom/slots/relic_slot_selected.svg"
)
const CARD_COMMON: Texture2D = preload(
	"res://assets/ui/system_v2/custom/cards/relic_card_common.svg"
)
const CARD_RARE: Texture2D = preload(
	"res://assets/ui/system_v2/custom/cards/relic_card_rare.svg"
)
const CARD_EPIC: Texture2D = preload(
	"res://assets/ui/system_v2/custom/cards/relic_card_epic.svg"
)
const CARD_LEGENDARY: Texture2D = preload(
	"res://assets/ui/system_v2/custom/cards/relic_card_legendary.svg"
)
const CARD_SELECTED: Texture2D = preload(
	"res://assets/ui/system_v2/custom/cards/relic_card_selected.svg"
)
const CARD_SELECTION_OVERLAY: Texture2D = preload(
	"res://assets/ui/system_v2/custom/effects/relic_card_selection_overlay_v2.svg"
)
const TAB_NORMAL: Texture2D = preload(
	"res://assets/ui/system_v2/custom/tabs/tab_normal.svg"
)
const TAB_SELECTED: Texture2D = preload(
	"res://assets/ui/system_v2/custom/tabs/tab_selected.svg"
)
const PRIMARY_NORMAL: Texture2D = preload(
	"res://assets/ui/system_v2/custom/buttons/primary_normal.svg"
)
const PRIMARY_SELECTED: Texture2D = preload(
	"res://assets/ui/system_v2/custom/buttons/primary_selected.svg"
)
const SECONDARY_NORMAL: Texture2D = preload(
	"res://assets/ui/system_v2/custom/buttons/secondary_normal.svg"
)

const SLOT_ORDER: Array[String] = [
	"armament",
	"robe",
	"bracer",
	"pendant",
	"boots"
]

const SLOT_LABELS: Dictionary = {
	"armament": "SENJATA",
	"robe": "JUBAH",
	"bracer": "LENGAN",
	"pendant": "LIONTIN",
	"boots": "SEPATU"
}

const FILTER_ALL: String = "all"
const FILTER_ARMAMENT: String = "armament"
const FILTER_ROBE: String = "robe"
const FILTER_BRACER: String = "bracer"
const FILTER_PENDANT: String = "pendant"
const FILTER_BOOTS: String = "boots"

const SORT_RARITY: String = "rarity"
const SORT_SLOT: String = "slot"
const SORT_NAME: String = "name"

const MODE_EQUIPMENT: String = "equipment"
const MODE_BAG: String = "bag"

@onready var content: Control = %Content
@onready var top_header: Control = %TopHeader
@onready var spirit_stone_label: Label = %SpiritStoneLabel
@onready var main_scroll: ScrollContainer = %CandidateScroll
@onready var fixed_vbox: VBoxContainer = %FixedVBox

@onready var hero_stage: Control = %HeroStage
@onready var hero_art: TextureRect = %HeroArt
@onready var hero_halo: TextureRect = %HeroHalo
@onready var hero_seal: TextureRect = %HeroSeal
@onready var hero_pedestal: TextureRect = %HeroPedestal
@onready var hero_name: Label = %HeroName
@onready var hero_subtitle: Label = %HeroSubtitle
@onready var status_label: Label = %StatusLabel

@onready var armament_slot: Control = %ArmamentSlot
@onready var robe_slot: Control = %RobeSlot
@onready var bracer_slot: Control = %BracerSlot
@onready var pendant_slot: Control = %PendantSlot
@onready var boots_slot: Control = %BootsSlot

@onready var weapon_line: Line2D = %WeaponLine
@onready var robe_line: Line2D = %RobeLine
@onready var bracer_line: Line2D = %BracerLine
@onready var pendant_line: Line2D = %PendantLine
@onready var boots_line: Line2D = %BootsLine

@onready var resonance_panel: Control = %ResonancePanel
@onready var selected_detail_panel: Control = %SelectedDetail

@onready var hp_value: Label = %HpValue
@onready var dmg_value: Label = %DmgValue
@onready var move_value: Label = %MoveValue
@onready var crit_value: Label = %CritValue
@onready var set_name_label: Label = %SetNameLabel
@onready var set_tier_label: Label = %SetTierLabel
@onready var resonance_path_root: Control = %ResonancePathRoot
@onready var resonance_path_background: Line2D = %ResonancePathBackground
@onready var resonance_path_active: Line2D = %ResonancePathActive
@onready var resonance_node_1: PanelContainer = %ResonanceNode1
@onready var resonance_node_2: PanelContainer = %ResonanceNode2
@onready var resonance_node_3: PanelContainer = %ResonanceNode3
@onready var resonance_node_4: PanelContainer = %ResonanceNode4
@onready var resonance_node_5: PanelContainer = %ResonanceNode5
@onready var next_resonance_label: Label = %NextResonanceLabel

@onready var selected_item_icon: TextureRect = %SelectedItemIcon
@onready var selected_item_name: Label = %SelectedItemName
@onready var selected_meta: Label = %SelectedMeta
@onready var selected_stats: Label = %SelectedStats
@onready var selected_set: Label = %SelectedSet
@onready var selected_effect_scroll: ScrollContainer = %SelectedEffectScroll
@onready var selected_effect: Label = %SignatureEffectLabel
@onready var action_primary: Button = %ActionPrimary
@onready var action_forge: Button = %AscendButton

@onready var equipment_mode_button: Button = %EquipmentModeButton
@onready var bag_mode_button: Button = %BagModeButton
@onready var all_filter_button: Button = %AllFilterButton
@onready var armament_filter_button: Button = %ArmamentFilterButton
@onready var robe_filter_button: Button = %RobeFilterButton
@onready var bracer_filter_button: Button = %BracerFilterButton
@onready var pendant_filter_button: Button = %PendantFilterButton
@onready var boots_filter_button: Button = %BootsFilterButton
@onready var sort_button: Button = %SortButton

@onready var owned_summary: Label = %OwnedSummary
@onready var codex_summary: Label = %CodexSummary
@onready var collection_progress_track: Control = %CollectionProgressTrack
@onready var collection_progress_fill: TextureRect = %CollectionProgressFill
@onready var item_grid: GridContainer = %CandidateGrid
@onready var empty_label: Label = %EmptyLabel

@onready var nav_bar: Control = %NavBar

var slot_nodes: Dictionary = {}
var formation_lines: Dictionary = {}
var resonance_nodes: Array[PanelContainer] = []
var card_buttons: Dictionary = {}

var selected_slot_id: String = "armament"
var selected_item_id: String = ""
var active_filter: String = FILTER_ALL
var active_mode: String = MODE_EQUIPMENT
var sort_mode: String = SORT_RARITY
var current_resonance_piece_count: int = 0
var motion_time: float = 0.0

var ui_font: SystemFont
var display_font: SystemFont


func _ready() -> void:
	_build_screen_fonts()

	slot_nodes = {
		"armament": armament_slot,
		"robe": robe_slot,
		"bracer": bracer_slot,
		"pendant": pendant_slot,
		"boots": boots_slot
	}
	formation_lines = {
		"armament": weapon_line,
		"robe": robe_line,
		"bracer": bracer_line,
		"pendant": pendant_line,
		"boots": boots_line
	}
	resonance_nodes = [
		resonance_node_1,
		resonance_node_2,
		resonance_node_3,
		resonance_node_4,
		resonance_node_5
	]

	SceneTransitionManager.set_back_handler(handle_system_back)
	resized.connect(_queue_layout)

	for slot_id: String in SLOT_ORDER:
		var slot_node: Control = slot_nodes[slot_id] as Control
		var button_name: String = str(
			SLOT_BUTTON_NODE_NAMES.get(slot_id, "")
		)
		var button: Button = slot_node.get_node(button_name) as Button
		button.pressed.connect(_on_slot_pressed.bind(slot_id))

	if not EquipmentManager.equipment_changed.is_connected(
		_on_equipment_changed
	):
		EquipmentManager.equipment_changed.connect(
			_on_equipment_changed
		)
	if not EquipmentManager.equipment_ascended.is_connected(
		_on_equipment_ascended
	):
		EquipmentManager.equipment_ascended.connect(
			_on_equipment_ascended
		)
	if not InventoryManager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		InventoryManager.inventory_changed.connect(
			_on_inventory_changed
		)

	equipment_mode_button.pressed.connect(
		_set_mode.bind(MODE_EQUIPMENT)
	)
	bag_mode_button.pressed.connect(
		_set_mode.bind(MODE_BAG)
	)

	all_filter_button.pressed.connect(
		_set_filter.bind(FILTER_ALL)
	)
	armament_filter_button.pressed.connect(
		_set_filter.bind(FILTER_ARMAMENT)
	)
	robe_filter_button.pressed.connect(
		_set_filter.bind(FILTER_ROBE)
	)
	bracer_filter_button.pressed.connect(
		_set_filter.bind(FILTER_BRACER)
	)
	pendant_filter_button.pressed.connect(
		_set_filter.bind(FILTER_PENDANT)
	)
	boots_filter_button.pressed.connect(
		_set_filter.bind(FILTER_BOOTS)
	)
	sort_button.pressed.connect(_cycle_sort)

	action_primary.pressed.connect(
		_on_primary_action_pressed
	)
	action_forge.pressed.connect(
		_on_forge_pressed
	)
	_apply_action_button_styles()
	_configure_inventory_scroll_zone()
	_configure_selected_effect_scroll_zone()

	_choose_initial_selection()
	_refresh_all()
	_apply_screen_typography()
	_layout_screen()
	set_process(true)


func _build_screen_fonts() -> void:
	# Cross-platform system stacks: Android usually resolves Roboto / generic
	# families, while Windows falls back to Segoe UI / Georgia cleanly.
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray([
		"Roboto Condensed",
		"sans-serif-condensed",
		"Roboto",
		"Noto Sans",
		"Segoe UI",
		"Arial"
	])

	display_font = SystemFont.new()
	display_font.font_names = PackedStringArray([
		"Noto Serif",
		"serif",
		"Georgia",
		"Times New Roman",
		"Roboto"
	])


func _apply_screen_typography() -> void:
	_apply_typography_recursive(self)

	var header_title: Label = top_header.get_node("Title") as Label
	if header_title != null:
		header_title.add_theme_font_override(
			"font",
			display_font
		)

	hero_name.add_theme_font_override(
		"font",
		display_font
	)
	selected_item_name.add_theme_font_override(
		"font",
		display_font
	)
	set_name_label.add_theme_font_override(
		"font",
		display_font
	)


func _apply_typography_recursive(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		label.add_theme_font_override(
			"font",
			ui_font
		)
	elif node is Button:
		var button: Button = node as Button
		button.add_theme_font_override(
			"font",
			ui_font
		)

	for child: Node in node.get_children():
		_apply_typography_recursive(child)


func _process(delta: float) -> void:
	if not is_inside_tree():
		return

	if (
		is_instance_valid(SettingsManager)
		and SettingsManager.reduced_effects
	):
		hero_halo.modulate.a = 0.15
		hero_seal.modulate.a = 0.07
		selected_item_icon.modulate.a = 1.0
		for resonance_node: PanelContainer in resonance_nodes:
			resonance_node.modulate.a = 1.0
		return

	motion_time = fmod(motion_time + delta, 1000.0)
	var pulse: float = (sin(motion_time * 1.55) + 1.0) * 0.5

	hero_halo.modulate.a = 0.12 + pulse * 0.06
	hero_seal.modulate.a = 0.05 + pulse * 0.025
	selected_item_icon.modulate.a = 0.94 + pulse * 0.06

	var selected_slot: Control = slot_nodes.get(
		selected_slot_id
	) as Control
	if selected_slot != null:
		var selected_frame: TextureRect = selected_slot.get_node(
			"Frame"
		) as TextureRect
		selected_frame.modulate.a = 0.90 + pulse * 0.10

	_refresh_resonance_motion(pulse)


func _queue_layout() -> void:
	_layout_screen.call_deferred()


func _layout_screen() -> void:
	if not is_inside_tree():
		return

	var width: float = content.size.x
	var height: float = content.size.y
	if width <= 0.0 or height <= 0.0:
		return

	var margin: float = 8.0
	var gap: float = 8.0
	var top_y: float = 12.0
	var top_h: float = 68.0
	# NavBar geometry is owned by its production anchors/offsets in the scene:
	# left/right = 0.03/0.97, top/bottom = 1.0, offsets = -98/-10.
	# Do not set position/size here; Godot will override anchored Control sizing
	# and emit a warning after _ready().
	var nav_top: float = height - 98.0

	top_header.position = Vector2(margin, top_y)
	top_header.size = Vector2(width - margin * 2.0, top_h)

	var content_y: float = top_y + top_h + gap
	var fixed_h: float = (
		hero_stage.custom_minimum_size.y
		+ resonance_panel.custom_minimum_size.y
		+ selected_detail_panel.custom_minimum_size.y
		+ gap * 2.0
	)

	fixed_vbox.position = Vector2(margin, content_y)
	fixed_vbox.size = Vector2(width - margin * 2.0, fixed_h)

	var scroll_y: float = content_y + fixed_h + gap
	var scroll_bottom: float = nav_top - gap
	main_scroll.position = Vector2(margin, scroll_y)
	main_scroll.size = Vector2(
		width - margin * 2.0,
		maxf(scroll_bottom - scroll_y, 220.0)
	)

	item_grid.columns = 3
	item_grid.add_theme_constant_override("h_separation", 8)
	item_grid.add_theme_constant_override("v_separation", 8)

	_layout_hero_stage.call_deferred()
	_layout_resonance_path.call_deferred()
	_refresh_collection_progress.call_deferred()


func _layout_hero_stage() -> void:
	var stage_w: float = hero_stage.size.x
	var stage_h: float = hero_stage.size.y
	if stage_w <= 0.0 or stage_h <= 0.0:
		return

	# V1.5 chamber redistribution:
	# - entire hero/orbit block sits slightly lower so the top weapon has
	#   breathing room from the showcase frame;
	# - four side equipment slots become slim vertical relic cards;
	# - chamber height is increased so the initial inventory viewport lands on
	#   exactly two clean rows instead of showing a clipped third row.
	var hero_w: float = stage_w * 0.47
	var hero_left: float = (stage_w - hero_w) * 0.5

	hero_art.position = Vector2(hero_left, 100.0)
	hero_art.size = Vector2(hero_w, stage_h - 136.0)

	hero_halo.position = Vector2(
		stage_w * 0.23,
		stage_h * 0.25
	)
	hero_halo.size = Vector2(
		stage_w * 0.54,
		stage_h * 0.60
	)

	hero_seal.position = Vector2(
		stage_w * 0.30,
		stage_h * 0.22
	)
	hero_seal.size = Vector2(
		stage_w * 0.40,
		stage_h * 0.48
	)

	hero_pedestal.position = Vector2(
		stage_w * 0.34,
		stage_h - 70.0
	)
	hero_pedestal.size = Vector2(
		stage_w * 0.32,
		56.0
	)

	hero_name.position = Vector2(
		stage_w * 0.35,
		stage_h - 42.0
	)
	hero_name.size = Vector2(stage_w * 0.30, 22.0)

	hero_subtitle.position = Vector2(
		stage_w * 0.26,
		stage_h - 22.0
	)
	hero_subtitle.size = Vector2(stage_w * 0.48, 16.0)

	var side_size: Vector2 = Vector2(76.0, 98.0)
	var weapon_size: Vector2 = Vector2(110.0, 78.0)

	var side_inset: float = 54.0
	var left_x: float = side_inset
	var right_x: float = stage_w - side_size.x - side_inset
	var upper_y: float = 100.0
	var lower_y: float = stage_h - side_size.y - 50.0

	armament_slot.position = Vector2(
		(stage_w - weapon_size.x) * 0.5,
		10.0
	)
	armament_slot.size = weapon_size

	robe_slot.position = Vector2(left_x, upper_y)
	robe_slot.size = side_size

	bracer_slot.position = Vector2(right_x, upper_y)
	bracer_slot.size = side_size

	pendant_slot.position = Vector2(left_x, lower_y)
	pendant_slot.size = side_size

	boots_slot.position = Vector2(right_x, lower_y)
	boots_slot.size = side_size

	_layout_formation_lines()


func _layout_formation_lines() -> void:
	var stage_w: float = hero_stage.size.x
	var stage_h: float = hero_stage.size.y
	var core: Vector2 = Vector2(
		stage_w * 0.5,
		stage_h * 0.53
	)

	weapon_line.points = PackedVector2Array([
		armament_slot.position
			+ Vector2(
				armament_slot.size.x * 0.5,
				armament_slot.size.y * 0.88
			),
		Vector2(stage_w * 0.5, stage_h * 0.30),
		core
	])

	robe_line.points = PackedVector2Array([
		robe_slot.position
			+ Vector2(
				robe_slot.size.x * 0.92,
				robe_slot.size.y * 0.48
			),
		Vector2(stage_w * 0.40, stage_h * 0.43),
		core
	])

	bracer_line.points = PackedVector2Array([
		bracer_slot.position
			+ Vector2(
				bracer_slot.size.x * 0.08,
				bracer_slot.size.y * 0.48
			),
		Vector2(stage_w * 0.60, stage_h * 0.43),
		core
	])

	pendant_line.points = PackedVector2Array([
		pendant_slot.position
			+ Vector2(
				pendant_slot.size.x * 0.92,
				pendant_slot.size.y * 0.52
			),
		Vector2(stage_w * 0.40, stage_h * 0.73),
		core
	])

	boots_line.points = PackedVector2Array([
		boots_slot.position
			+ Vector2(
				boots_slot.size.x * 0.08,
				boots_slot.size.y * 0.52
			),
		Vector2(stage_w * 0.60, stage_h * 0.73),
		core
	])


func _choose_initial_selection() -> void:
	var equipped_weapon: String = (
		EquipmentManager.get_loadout_equipped_item_id("armament")
	)
	if not equipped_weapon.is_empty():
		selected_item_id = equipped_weapon
		selected_slot_id = "armament"
		return

	var owned: Array[String] = InventoryManager.get_owned_item_ids()
	if owned.has("ascendant_heart"):
		selected_item_id = "ascendant_heart"
		selected_slot_id = "pendant"
		return

	if not owned.is_empty():
		selected_item_id = owned[0]
		var data: Dictionary = InventoryManager.get_item_data(
			selected_item_id
		)
		selected_slot_id = str(
			data.get("slot", "armament")
		)


func _refresh_all() -> void:
	if is_instance_valid(ProgressionManager):
		spirit_stone_label.text = str(
			ProgressionManager.spirit_stone
		)
	else:
		spirit_stone_label.text = "—"

	_refresh_status()
	_refresh_hero_slots()
	_refresh_resonance()
	_refresh_selected_item()
	_refresh_mode_buttons()
	_refresh_filter_buttons()
	_refresh_collection_meta()
	_rebuild_collection()
	_apply_slot_selection()


func _refresh_status() -> void:
	if not EquipmentManager.can_modify_equipment():
		status_label.text = "LOADOUT TERKUNCI"
		status_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.60, 0.42, 0.92)
		)
		return

	if EquipmentManager.has_preserved_active_run_loadout():
		status_label.text = "PERUBAHAN UNTUK RUN BERIKUTNYA"
	else:
		status_label.text = "LOADOUT SIAP • PILIH RELIK"

	status_label.add_theme_color_override(
		"font_color",
		Color(0.52, 1.0, 0.86, 0.92)
	)


func _refresh_hero_slots() -> void:
	for slot_id: String in SLOT_ORDER:
		var slot_node: Control = slot_nodes[slot_id] as Control
		var icon: TextureRect = slot_node.get_node(
			"Icon"
		) as TextureRect
		var slot_label: Label = slot_node.get_node(
			"SlotLabel"
		) as Label
		var star_label: Label = slot_node.get_node(
			"StarLabel"
		) as Label

		slot_label.text = str(
			SLOT_LABELS.get(
				slot_id,
				slot_id.to_upper()
			)
		)

		var item_id: String = (
			EquipmentManager.get_loadout_equipped_item_id(
				slot_id
			)
		)
		icon.texture = _load_item_icon(item_id)

		var slot_frame: TextureRect = slot_node.get_node(
			"Frame"
		) as TextureRect
		if item_id.is_empty():
			slot_frame.texture = CARD_COMMON
		else:
			var slot_data: Dictionary = (
				InventoryManager.get_item_data(item_id)
			)
			slot_frame.texture = _get_card_texture_for_rarity(
				str(slot_data.get("rarity", "common"))
			)

		if item_id.is_empty():
			star_label.text = "—"
		else:
			star_label.text = _format_stars(
				EquipmentManager.get_item_star(item_id)
			)


func _refresh_resonance() -> void:
	var equipped_ids: Array[String] = _get_equipped_item_ids()

	hp_value.text = "+%.1f" % (
		EquipmentManager.get_loadout_total_max_health_bonus()
	)
	dmg_value.text = "+%.1f%%" % (
		(
			EquipmentManager.get_loadout_damage_multiplier()
			- 1.0
		) * 100.0
	)
	move_value.text = "+%.1f%%" % (
		(
			EquipmentManager.get_loadout_movement_speed_multiplier()
			- 1.0
		) * 100.0
	)
	crit_value.text = "+%.1f%%" % (
		EquipmentManager.get_loadout_critical_chance_bonus()
		* 100.0
	)

	var state: Dictionary = (
		EquipmentSetCatalog.get_dominant_set_state(
			equipped_ids
		)
	)
	var set_id: String = str(state.get("set_id", ""))
	var piece_count: int = int(
		state.get("piece_count", 0)
	)
	current_resonance_piece_count = piece_count

	if set_id.is_empty():
		set_name_label.text = "NO ACTIVE RESONANCE"
		set_tier_label.text = "0 / 5"
		next_resonance_label.text = (
			"PASANG 2 RELIK SET YANG SAMA UNTUK MEMBANGUNKAN RESONANSI"
		)
	else:
		set_name_label.text = str(
			state.get("display_name", set_id)
		)
		set_tier_label.text = "%d / 5" % piece_count
		next_resonance_label.text = (
			_build_next_resonance_text(
				set_id,
				piece_count
			)
		)

	_refresh_resonance_visuals(piece_count)


func _build_next_resonance_text(
	set_id: String,
	piece_count: int
) -> String:
	if piece_count >= 5:
		return "FULL RESONANCE • SEMUA TIER AKTIF"

	var next_tier: int = maxi(piece_count + 1, 2)
	var next_bonus: String = (
		EquipmentSetCatalog.get_tier_description(
			set_id,
			next_tier
		)
	)
	if next_bonus.is_empty():
		return "NEXT • %d / 5" % next_tier

	return "NEXT • %d / 5  →  %s" % [
		next_tier,
		next_bonus
	]


func _refresh_resonance_visuals(
	piece_count: int
) -> void:
	for index: int in range(resonance_nodes.size()):
		var node_panel: PanelContainer = (
			resonance_nodes[index]
		)
		var tier: int = index + 1
		var state: String = "locked"

		if tier <= piece_count:
			state = "active"
		elif tier == piece_count + 1:
			state = "next"

		node_panel.add_theme_stylebox_override(
			"panel",
			_make_resonance_node_style(state)
		)

		var tier_label: Label = node_panel.get_node(
			"Tier"
		) as Label
		tier_label.text = str(tier)

		if state == "active":
			tier_label.add_theme_color_override(
				"font_color",
				Color(1.0, 0.90, 0.58, 1.0)
			)
		elif state == "next":
			tier_label.add_theme_color_override(
				"font_color",
				Color(0.52, 1.0, 0.86, 1.0)
			)
		else:
			tier_label.add_theme_color_override(
				"font_color",
				Color(0.46, 0.56, 0.56, 0.74)
			)

	var active_ratio: float = clampf(
		float(piece_count - 1) / 4.0,
		0.0,
		1.0
	)
	var width: float = resonance_path_root.size.x
	var y_center: float = (
		resonance_path_root.size.y * 0.5
	)
	var x_start: float = 16.0
	var x_end: float = width - 16.0

	resonance_path_background.points = PackedVector2Array([
		Vector2(x_start, y_center),
		Vector2(x_end, y_center)
	])
	resonance_path_active.points = PackedVector2Array([
		Vector2(x_start, y_center),
		Vector2(
			lerpf(
				x_start,
				x_end,
				active_ratio
			),
			y_center
		)
	])


func _make_resonance_node_style(
	state: String
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	match state:
		"active":
			style.bg_color = Color(
				0.055,
				0.20,
				0.18,
				0.98
			)
			style.border_color = Color(
				0.96,
				0.76,
				0.28,
				0.98
			)
		"next":
			style.bg_color = Color(
				0.025,
				0.18,
				0.17,
				0.96
			)
			style.border_color = Color(
				0.34,
				0.94,
				0.80,
				0.94
			)
			style.shadow_color = Color(
				0.28,
				0.90,
				0.76,
				0.22
			)
			style.shadow_size = 5
		_:
			style.bg_color = Color(
				0.018,
				0.055,
				0.065,
				0.92
			)
			style.border_color = Color(
				0.25,
				0.42,
				0.43,
				0.62
			)
	return style


func _layout_resonance_path() -> void:
	var width: float = resonance_path_root.size.x
	var height: float = resonance_path_root.size.y
	if width <= 0.0 or height <= 0.0:
		return

	var node_size: float = 22.0
	var first_center_x: float = 16.0
	var last_center_x: float = width - 16.0
	var y_center: float = height * 0.5

	for index: int in range(resonance_nodes.size()):
		var progress: float = float(index) / 4.0
		var center_x: float = lerpf(
			first_center_x,
			last_center_x,
			progress
		)
		var node_panel: PanelContainer = (
			resonance_nodes[index]
		)
		node_panel.position = Vector2(
			center_x - node_size * 0.5,
			y_center - node_size * 0.5
		)
		node_panel.size = Vector2(
			node_size,
			node_size
		)

	_refresh_resonance_visuals(
		current_resonance_piece_count
	)


func _refresh_resonance_motion(
	pulse: float
) -> void:
	var next_index: int = (
		current_resonance_piece_count
	)

	for index: int in range(resonance_nodes.size()):
		var node_panel: PanelContainer = (
			resonance_nodes[index]
		)
		if (
			index == next_index
			and current_resonance_piece_count < 5
		):
			node_panel.modulate.a = (
				0.82 + pulse * 0.18
			)
		else:
			node_panel.modulate.a = 1.0


func _refresh_selected_item() -> void:
	if selected_item_id.is_empty():
		selected_item_icon.texture = null
		selected_item_name.text = "PILIH RELIK"
		selected_meta.text = ""
		selected_stats.text = ""
		selected_set.text = ""
		selected_effect.text = ""
		action_primary.text = "PAKAI"
		action_primary.disabled = true
		action_forge.text = "TEMPA"
		action_forge.disabled = true
		action_forge.tooltip_text = ""
		selected_effect_scroll.scroll_vertical = 0
		return

	var item_data: Dictionary = (
		InventoryManager.get_item_data(
			selected_item_id
		)
	)
	var item_type: String = (
		InventoryManager.get_item_type(
			selected_item_id
		)
	)
	var rarity_id: String = str(
		item_data.get("rarity", "common")
	)

	selected_item_icon.texture = _load_item_icon(
		selected_item_id
	)
	selected_item_name.text = str(
		item_data.get(
			"display_name",
			selected_item_id
		)
	)
	selected_item_name.add_theme_color_override(
		"font_color",
		EquipmentVisualCatalog.get_rarity_color(
			rarity_id
		)
	)

	if item_type == InventoryManager.ITEM_TYPE_MATERIAL:
		selected_meta.text = "BAHAN • x%d" % (
			InventoryManager.get_item_count(
				selected_item_id
			)
		)
		selected_stats.text = str(
			item_data.get(
				"description",
				"Material penyempurnaan."
			)
		)
		selected_set.text = "MATERIAL PENYEMPURNAAN"
		selected_effect.text = (
			"Material penyempurnaan tidak dapat dipasang sebagai equipment."
		)
		action_primary.text = "MATERIAL"
		action_primary.disabled = true
		action_forge.text = "TEMPA"
		action_forge.disabled = true
		selected_effect_scroll.scroll_vertical = 0
		return

	var slot_id: String = _get_equipment_slot_id(
		selected_item_id
	)
	var star: int = EquipmentManager.get_item_star(
		selected_item_id
	)
	var effective_data: Dictionary = (
		EquipmentManager.get_effective_item_data(
			selected_item_id
		)
	)

	selected_meta.text = "%s • %s • %s" % [
		rarity_id.to_upper(),
		_get_slot_display_label(slot_id),
		_format_stars(star)
	]
	selected_stats.text = (
		EquipmentVisualCatalog.get_stat_summary(
			effective_data
		)
	)

	var set_id: String = (
		EquipmentSetCatalog.get_set_id_for_item(
			selected_item_id
		)
	)
	if set_id.is_empty():
		selected_set.text = "TANPA SET RESONANSI"
	else:
		var piece_count: int = (
			EquipmentSetCatalog.get_piece_count(
				set_id,
				_get_equipped_item_ids()
			)
		)
		selected_set.text = "%s • %d/5" % [
			EquipmentSetCatalog.get_display_name(
				set_id
			),
			piece_count
		]

	selected_effect.text = "%s • %s" % [
		EquipmentVisualCatalog.get_signature_effect_name(
			item_data
		),
		EquipmentVisualCatalog.get_signature_effect_description(
			item_data
		)
	]

	var equipped_here: bool = (
		EquipmentManager.get_loadout_equipped_item_id(slot_id)
		== selected_item_id
	)
	var can_modify: bool = EquipmentManager.can_modify_equipment()

	action_primary.text = "LEPAS" if equipped_here else "PAKAI"
	action_primary.disabled = (
		not can_modify
		or not InventoryManager.owns_item(selected_item_id)
	)

	action_forge.text = "TEMPA"
	action_forge.disabled = (
		not EquipmentManager.can_ascend_item(selected_item_id)
	)
	action_forge.tooltip_text = _build_forge_tooltip(
		selected_item_id
	)

	selected_effect_scroll.scroll_vertical = 0


func _build_forge_tooltip(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	if not EquipmentManager.has_item_definition(item_id):
		return ""

	var current_star: int = EquipmentManager.get_item_star(item_id)
	if current_star >= EquipmentManager.MAX_ASCENSION_STAR:
		return "Relik sudah mencapai 5★."

	var cost: int = EquipmentManager.get_ascension_cost(item_id)
	var shards: int = InventoryManager.get_item_count(
		InventoryManager.REFINEMENT_SHARD
	)
	return "Tempa ke %d★ • Biaya %d Refinement Shard • Dimiliki %d" % [
		current_star + 1,
		cost,
		shards
	]


func _apply_action_button_styles() -> void:
	_apply_action_button_style(
		action_primary,
		true
	)
	_apply_action_button_style(
		action_forge,
		false
	)

func _configure_inventory_scroll_zone() -> void:
	# The lower collection area is the only scrollable zone.
	# Hide internal scrollbars completely so mobile/touch users do not see
	# the bright bar on the right edge and can drag the panel directly.
	main_scroll.clip_contents = true
	main_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	var v_scroll: VScrollBar = main_scroll.get_v_scroll_bar()
	if v_scroll != null:
		v_scroll.visible = false
		v_scroll.modulate = Color(1.0, 1.0, 1.0, 0.0)
		v_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v_scroll.focus_mode = Control.FOCUS_NONE
		v_scroll.custom_minimum_size = Vector2.ZERO

	var h_scroll: HScrollBar = main_scroll.get_h_scroll_bar()
	if h_scroll != null:
		h_scroll.visible = false
		h_scroll.modulate = Color(1.0, 1.0, 1.0, 0.0)
		h_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h_scroll.focus_mode = Control.FOCUS_NONE
		h_scroll.custom_minimum_size = Vector2.ZERO



func _configure_selected_effect_scroll_zone() -> void:
	selected_effect_scroll.clip_contents = true
	selected_effect_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	var v_scroll: VScrollBar = (
		selected_effect_scroll.get_v_scroll_bar()
	)
	if v_scroll != null:
		v_scroll.visible = false
		v_scroll.modulate = Color(1.0, 1.0, 1.0, 0.0)
		v_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v_scroll.focus_mode = Control.FOCUS_NONE
		v_scroll.custom_minimum_size = Vector2.ZERO

	var h_scroll: HScrollBar = (
		selected_effect_scroll.get_h_scroll_bar()
	)
	if h_scroll != null:
		h_scroll.visible = false
		h_scroll.modulate = Color(1.0, 1.0, 1.0, 0.0)
		h_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h_scroll.focus_mode = Control.FOCUS_NONE
		h_scroll.custom_minimum_size = Vector2.ZERO





func _apply_action_button_style(
	button: Button,
	is_primary: bool
) -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = (
		Color(0.035, 0.18, 0.16, 0.99)
		if is_primary
		else Color(0.025, 0.07, 0.10, 0.99)
	)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(
		0.96,
		0.77,
		0.28,
		1.0
	)
	normal_style.corner_radius_top_left = 7
	normal_style.corner_radius_top_right = 7
	normal_style.corner_radius_bottom_right = 7
	normal_style.corner_radius_bottom_left = 7
	normal_style.content_margin_left = 10.0
	normal_style.content_margin_top = 7.0
	normal_style.content_margin_right = 10.0
	normal_style.content_margin_bottom = 7.0
	normal_style.shadow_color = Color(
		0.95,
		0.72,
		0.20,
		0.14
	)
	normal_style.shadow_size = 2
	normal_style.shadow_offset = Vector2(0.0, 1.0)

	var hover_style: StyleBoxFlat = (
		normal_style.duplicate() as StyleBoxFlat
	)
	hover_style.bg_color = (
		Color(0.055, 0.25, 0.21, 1.0)
		if is_primary
		else Color(0.06, 0.12, 0.14, 1.0)
	)
	hover_style.border_color = Color(
		1.0,
		0.86,
		0.42,
		1.0
	)
	hover_style.shadow_color = Color(
		1.0,
		0.80,
		0.30,
		0.22
	)
	hover_style.shadow_size = 4

	var pressed_style: StyleBoxFlat = (
		normal_style.duplicate() as StyleBoxFlat
	)
	pressed_style.bg_color = (
		Color(0.11, 0.25, 0.17, 1.0)
		if is_primary
		else Color(0.11, 0.12, 0.10, 1.0)
	)
	pressed_style.border_color = Color(
		1.0,
		0.90,
		0.52,
		1.0
	)
	pressed_style.shadow_size = 1

	button.flat = false
	button.custom_minimum_size = Vector2(94.0, 34.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override(
		"font",
		ui_font
	)
	button.add_theme_font_size_override(
		"font_size",
		9
	)
	button.add_theme_color_override(
		"font_color",
		Color(1.0, 0.95, 0.79, 1.0)
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color(1.0, 0.93, 0.66, 1.0)
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color(1.0, 0.98, 0.86, 1.0)
	)

	button.add_theme_stylebox_override(
		"normal",
		normal_style
	)
	button.add_theme_stylebox_override(
		"hover",
		hover_style
	)
	button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)
	button.add_theme_stylebox_override(
		"focus",
		hover_style
	)


func _refresh_mode_buttons() -> void:
	_apply_mode_button_style(
		equipment_mode_button,
		active_mode == MODE_EQUIPMENT
	)
	_apply_mode_button_style(
		bag_mode_button,
		active_mode == MODE_BAG
	)


func _apply_mode_button_style(
	button: Button,
	selected: bool
) -> void:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = (
		PRIMARY_SELECTED
		if selected
		else SECONDARY_NORMAL
	)
	style.texture_margin_left = 22.0
	style.texture_margin_top = 18.0
	style.texture_margin_right = 22.0
	style.texture_margin_bottom = 18.0

	for state: String in [
		"normal",
		"hover",
		"pressed",
		"focus"
	]:
		button.add_theme_stylebox_override(
			state,
			style
		)


func _refresh_filter_buttons() -> void:
	_apply_filter_style(
		all_filter_button,
		active_filter == FILTER_ALL
	)
	_apply_filter_style(
		armament_filter_button,
		active_filter == FILTER_ARMAMENT
	)
	_apply_filter_style(
		robe_filter_button,
		active_filter == FILTER_ROBE
	)
	_apply_filter_style(
		bracer_filter_button,
		active_filter == FILTER_BRACER
	)
	_apply_filter_style(
		pendant_filter_button,
		active_filter == FILTER_PENDANT
	)
	_apply_filter_style(
		boots_filter_button,
		active_filter == FILTER_BOOTS
	)

	match sort_mode:
		SORT_SLOT:
			sort_button.text = "SLOT"
		SORT_NAME:
			sort_button.text = "NAMA"
		_:
			sort_button.text = "RARITAS"


func _apply_filter_style(
	button: Button,
	selected: bool
) -> void:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = (
		TAB_SELECTED
		if selected
		else TAB_NORMAL
	)
	style.texture_margin_left = 14.0
	style.texture_margin_top = 12.0
	style.texture_margin_right = 14.0
	style.texture_margin_bottom = 12.0

	for state: String in [
		"normal",
		"hover",
		"pressed",
		"focus"
	]:
		button.add_theme_stylebox_override(
			state,
			style
		)

	button.add_theme_color_override(
		"font_color",
		Color(1.0, 0.88, 0.52, 1.0)
		if selected
		else Color(0.82, 0.92, 0.91, 1.0)
	)


func _refresh_collection_meta() -> void:
	var unique_count: int = (
		InventoryManager.get_unique_item_count()
	)
	var total_count: int = (
		InventoryManager.get_total_item_count()
	)
	var owned_relics: int = _get_owned_relic_count()
	var catalog_total: int = (
		EquipmentManager.get_item_ids().size()
	)

	owned_summary.text = "%d JENIS • %d TOTAL" % [
		unique_count,
		total_count
	]
	codex_summary.text = "KODEKS %d / %d" % [
		owned_relics,
		catalog_total
	]
	_refresh_collection_progress.call_deferred()


func _refresh_collection_progress() -> void:
	var total: int = maxi(
		EquipmentManager.get_item_ids().size(),
		1
	)
	var ratio: float = clampf(
		float(_get_owned_relic_count())
			/ float(total),
		0.0,
		1.0
	)

	collection_progress_fill.position = Vector2.ZERO
	collection_progress_fill.size = Vector2(
		collection_progress_track.size.x * ratio,
		collection_progress_track.size.y
	)


func _get_collection_source_item_ids() -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}

	for item_id: String in InventoryManager.get_owned_item_ids():
		if not seen.has(item_id):
			seen[item_id] = true
			result.append(item_id)

	for item_id: String in _get_equipped_item_ids():
		if not item_id.is_empty() and not seen.has(item_id):
			seen[item_id] = true
			result.append(item_id)

	return result


func _get_equipment_slot_id(
	item_id: String
) -> String:
	if item_id.is_empty():
		return ""

	var equipment_data: Dictionary = (
		EquipmentManager.get_item_data(item_id)
	)
	var slot_id: String = str(
		equipment_data.get("slot", "")
	)
	if slot_id in SLOT_ORDER:
		return slot_id

	var inventory_data: Dictionary = (
		InventoryManager.get_item_data(item_id)
	)
	slot_id = str(
		inventory_data.get("slot", "")
	)
	if slot_id in SLOT_ORDER:
		return slot_id

	return ""


func _get_slot_display_label(
	slot_id: String
) -> String:
	return str(
		SLOT_LABELS.get(
			slot_id,
			slot_id.to_upper()
		)
	)


func _filtered_item_ids() -> Array[String]:
	var result: Array[String] = []

	for item_id: String in _get_collection_source_item_ids():
		var item_type: String = (
			InventoryManager.get_item_type(item_id)
		)

		if (
			item_type
			!= InventoryManager.ITEM_TYPE_EQUIPMENT
		):
			continue

		var item_slot: String = _get_equipment_slot_id(
			item_id
		)

		if (
			active_filter != FILTER_ALL
			and item_slot != active_filter
		):
			continue

		result.append(item_id)

	result.sort_custom(_sort_item_ids)
	return result


func _sort_item_ids(
	a: String,
	b: String
) -> bool:
	var data_a: Dictionary = (
		InventoryManager.get_item_data(a)
	)
	var data_b: Dictionary = (
		InventoryManager.get_item_data(b)
	)

	match sort_mode:
		SORT_NAME:
			return (
				str(
					data_a.get("display_name", a)
				).nocasecmp_to(
					str(
						data_b.get(
							"display_name",
							b
						)
					)
				)
				< 0
			)

		SORT_SLOT:
			var slot_a: int = (
				EquipmentVisualCatalog.get_slot_sort_order(
					_get_equipment_slot_id(a)
				)
			)
			var slot_b: int = (
				EquipmentVisualCatalog.get_slot_sort_order(
					_get_equipment_slot_id(b)
				)
			)
			if slot_a != slot_b:
				return slot_a < slot_b
			return (
				str(
					data_a.get("display_name", a)
				).nocasecmp_to(
					str(
						data_b.get(
							"display_name",
							b
						)
					)
				)
				< 0
			)

		_:
			var rarity_a: int = (
				EquipmentVisualCatalog.get_rarity_rank(
					str(
						data_a.get(
							"rarity",
							"common"
						)
					)
				)
			)
			var rarity_b: int = (
				EquipmentVisualCatalog.get_rarity_rank(
					str(
						data_b.get(
							"rarity",
							"common"
						)
					)
				)
			)
			if rarity_a != rarity_b:
				return rarity_a > rarity_b
			return (
				str(
					data_a.get("display_name", a)
				).nocasecmp_to(
					str(
						data_b.get(
							"display_name",
							b
						)
					)
				)
				< 0
			)


func _rebuild_collection() -> void:
	for child: Node in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()

	card_buttons.clear()

	var item_ids: Array[String] = _filtered_item_ids()
	empty_label.visible = item_ids.is_empty()

	if (
		not item_ids.is_empty()
		and not item_ids.has(selected_item_id)
	):
		selected_item_id = item_ids[0]
		_sync_selected_slot_from_item(
			selected_item_id
		)

	for item_id: String in item_ids:
		var card: Button = _create_item_card(item_id)
		item_grid.add_child(card)
		card_buttons[item_id] = card

	_refresh_card_selection()
	_apply_screen_typography()


func _create_item_card(
	item_id: String
) -> Button:
	var item_data: Dictionary = (
		InventoryManager.get_item_data(item_id)
	)
	var item_type: String = (
		InventoryManager.get_item_type(item_id)
	)
	var rarity_id: String = str(
		item_data.get("rarity", "common")
	)

	var button: Button = Button.new()
	button.name = "Relic_" + item_id
	button.custom_minimum_size = Vector2(
		0.0,
		166.0
	)
	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	button.pressed.connect(
		_on_item_pressed.bind(item_id)
	)

	_apply_card_style(
		button,
		rarity_id
	)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.anchor_left = 0.18
	icon.anchor_top = 0.09
	icon.anchor_right = 0.82
	icon.anchor_bottom = 0.61
	icon.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	icon.texture = _load_item_icon(item_id)
	button.add_child(icon)

	if _is_equipped(item_id):
		var equipped_label: Label = Label.new()
		equipped_label.name = "Equipped"
		equipped_label.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		equipped_label.anchor_left = 0.06
		equipped_label.anchor_top = 0.04
		equipped_label.anchor_right = 0.62
		equipped_label.anchor_bottom = 0.18
		equipped_label.text = "TERPASANG"
		equipped_label.add_theme_font_size_override(
			"font_size",
			9
		)
		equipped_label.add_theme_color_override(
			"font_color",
			Color(0.52, 1.0, 0.86, 1.0)
		)
		button.add_child(equipped_label)

	var name_label: Label = Label.new()
	name_label.name = "Name"
	name_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	name_label.anchor_left = 0.06
	name_label.anchor_top = 0.63
	name_label.anchor_right = 0.94
	name_label.anchor_bottom = 0.82
	name_label.text = str(
		item_data.get(
			"display_name",
			item_id
		)
	)
	name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	name_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	name_label.clip_text = true
	name_label.add_theme_font_size_override(
		"font_size",
		10
	)
	name_label.add_theme_color_override(
		"font_color",
		EquipmentVisualCatalog.get_rarity_color(
			rarity_id
		)
	)
	button.add_child(name_label)

	var footer: Label = Label.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.anchor_left = 0.05
	footer.anchor_top = 0.82
	footer.anchor_right = 0.95
	footer.anchor_bottom = 0.96
	footer.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	footer.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	footer.add_theme_font_size_override(
		"font_size",
		9
	)

	if item_type == InventoryManager.ITEM_TYPE_EQUIPMENT:
		footer.text = _format_stars(
			EquipmentManager.get_item_star(
				item_id
			)
		)
		footer.add_theme_color_override(
			"font_color",
			Color(1.0, 0.82, 0.25, 1.0)
		)
	else:
		footer.text = "x%d" % (
			InventoryManager.get_item_count(
				item_id
			)
		)
		footer.add_theme_color_override(
			"font_color",
			Color(0.55, 0.88, 1.0, 1.0)
		)

	button.add_child(footer)
	_install_selection_overlay(
		button,
		item_id == selected_item_id
	)

	return button


func _get_card_texture_for_rarity(
	rarity_id: String
) -> Texture2D:
	match rarity_id:
		"rare":
			return CARD_RARE
		"epic":
			return CARD_EPIC
		"legendary":
			return CARD_LEGENDARY
		_:
			return CARD_COMMON


func _apply_card_style(
	button: Button,
	rarity_id: String
) -> void:
	var texture: Texture2D = _get_card_texture_for_rarity(
		rarity_id
	)

	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 18.0
	style.texture_margin_top = 18.0
	style.texture_margin_right = 18.0
	style.texture_margin_bottom = 18.0

	for state: String in [
		"normal",
		"hover",
		"pressed",
		"focus"
	]:
		button.add_theme_stylebox_override(
			state,
			style
		)


func _install_selection_overlay(
	button: Button,
	selected: bool
) -> void:
	var overlay: TextureRect = button.get_node_or_null(
		"SelectionOverlay"
	) as TextureRect

	if overlay == null:
		overlay = TextureRect.new()
		overlay.name = "SelectionOverlay"
		overlay.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		overlay.texture = CARD_SELECTION_OVERLAY
		overlay.expand_mode = (
			TextureRect.EXPAND_IGNORE_SIZE
		)
		overlay.stretch_mode = (
			TextureRect.STRETCH_SCALE
		)
		overlay.z_index = 20
		button.add_child(overlay)
		overlay.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

	overlay.visible = selected


func _refresh_card_selection() -> void:
	for raw_item_id: Variant in card_buttons.keys():
		var item_id: String = str(raw_item_id)
		var button: Button = (
			card_buttons[item_id] as Button
		)
		_install_selection_overlay(
			button,
			item_id == selected_item_id
		)


func _apply_slot_selection() -> void:
	for slot_id: String in SLOT_ORDER:
		var slot_node: Control = (
			slot_nodes[slot_id] as Control
		)
		var frame: TextureRect = slot_node.get_node(
			"Frame"
		) as TextureRect
		var line: Line2D = formation_lines.get(
			slot_id
		) as Line2D
		var item_id: String = (
			EquipmentManager.get_loadout_equipped_item_id(slot_id)
		)

		if slot_id == selected_slot_id:
			frame.texture = CARD_SELECTED
		elif item_id.is_empty():
			frame.texture = CARD_COMMON
		else:
			var item_data: Dictionary = (
				InventoryManager.get_item_data(item_id)
			)
			frame.texture = _get_card_texture_for_rarity(
				str(item_data.get("rarity", "common"))
			)

		frame.modulate = Color.WHITE
		if line != null:
			if slot_id == selected_slot_id:
				line.default_color = Color(
					0.98,
					0.78,
					0.34,
					0.42
				)
			else:
				line.default_color = Color(
					0.27,
					0.85,
					0.78,
					0.16
				)


func _set_mode(
	mode_id: String
) -> void:
	active_mode = mode_id
	active_filter = FILTER_ALL

	_refresh_mode_buttons()
	_refresh_filter_buttons()
	_rebuild_collection()
	_refresh_selected_item()


func _set_filter(
	filter_id: String
) -> void:
	active_filter = filter_id
	active_mode = MODE_EQUIPMENT

	_refresh_mode_buttons()
	_refresh_filter_buttons()
	_rebuild_collection()
	_refresh_selected_item()


func _cycle_sort() -> void:
	match sort_mode:
		SORT_RARITY:
			sort_mode = SORT_SLOT
		SORT_SLOT:
			sort_mode = SORT_NAME
		_:
			sort_mode = SORT_RARITY

	_refresh_filter_buttons()
	_rebuild_collection()


func _on_slot_pressed(
	slot_id: String
) -> void:
	selected_slot_id = slot_id

	var equipped_item_id: String = (
		EquipmentManager.get_loadout_equipped_item_id(
			slot_id
		)
	)
	if not equipped_item_id.is_empty():
		selected_item_id = equipped_item_id

	active_mode = MODE_EQUIPMENT

	# Hero-slot selection must not mutate the player's current inventory filter.
	# It only updates Hero focus + selected-item detail.
	_apply_slot_selection()
	_refresh_mode_buttons()
	_refresh_selected_item()
	_refresh_card_selection()

	status_label.text = "%s DIPILIH" % str(
		SLOT_LABELS.get(
			slot_id,
			slot_id.to_upper()
		)
	)


func _on_item_pressed(
	item_id: String
) -> void:
	selected_item_id = item_id
	_sync_selected_slot_from_item(item_id)
	_refresh_selected_item()
	_apply_slot_selection()
	_refresh_card_selection()

	status_label.text = "RELIK DIPILIH • SIAP DIKELOLA"


func _sync_selected_slot_from_item(
	item_id: String
) -> void:
	if (
		InventoryManager.get_item_type(item_id)
		!= InventoryManager.ITEM_TYPE_EQUIPMENT
	):
		return

	var slot_id: String = _get_equipment_slot_id(
		item_id
	)
	if slot_id in SLOT_ORDER:
		selected_slot_id = slot_id


func _on_primary_action_pressed() -> void:
	if selected_item_id.is_empty():
		return
	if not EquipmentManager.can_modify_equipment():
		_refresh_all()
		return

	var slot_id: String = _get_equipment_slot_id(
		selected_item_id
	)
	if slot_id.is_empty():
		return

	var equipped_item_id: String = (
		EquipmentManager.get_loadout_equipped_item_id(
			slot_id
		)
	)
	if equipped_item_id == selected_item_id:
		EquipmentManager.unequip_slot(slot_id)
	else:
		EquipmentManager.equip_item(selected_item_id)


func _on_forge_pressed() -> void:
	if selected_item_id.is_empty():
		return
	if EquipmentManager.ascend_item(selected_item_id):
		_refresh_all()


func _on_equipment_changed(
	_slot_id: String,
	_item_id: String
) -> void:
	_refresh_all()


func _on_equipment_ascended(
	item_id: String,
	_old_star: int,
	_new_star: int
) -> void:
	if item_id == selected_item_id:
		_refresh_all()


func _on_inventory_changed(
	_item_id: String,
	_new_count: int
) -> void:
	_refresh_all()


func handle_system_back() -> void:
	if SceneTransitionManager.is_transitioning:
		return
	if not ResourceLoader.exists(MAIN_MENU_SCENE):
		push_error(
			"HeroEquipment: Main Menu scene tidak ditemukan."
		)
		return
	var change_error: Error = (
		SceneTransitionManager.transition_menu_to(
			MAIN_MENU_SCENE,
			-1
		)
	)
	if change_error != OK:
		push_error(
			"HeroEquipment: gagal kembali ke Journey. Error code: "
			+ str(change_error)
		)


func _get_equipped_item_ids() -> Array[String]:
	var result: Array[String] = []

	for slot_id: String in EquipmentManager.get_slot_ids():
		var item_id: String = (
			EquipmentManager.get_loadout_equipped_item_id(
				slot_id
			)
		)
		if not item_id.is_empty():
			result.append(item_id)

	return result


func _is_equipped(
	item_id: String
) -> bool:
	for slot_id: String in EquipmentManager.get_slot_ids():
		if (
			EquipmentManager.get_loadout_equipped_item_id(
				slot_id
			)
			== item_id
		):
			return true

	return false


func _get_owned_relic_count() -> int:
	var count: int = 0

	for item_id: String in _get_collection_source_item_ids():
		if (
			InventoryManager.get_item_type(item_id)
			== InventoryManager.ITEM_TYPE_EQUIPMENT
		):
			count += 1

	return count


func _load_item_icon(
	item_id: String
) -> Texture2D:
	if item_id.is_empty():
		return null

	var icon_path: String = (
		EquipmentVisualCatalog.get_icon_path(
			item_id
		)
	)
	if (
		icon_path.is_empty()
		or not ResourceLoader.exists(icon_path)
	):
		return null

	var resource: Resource = ResourceLoader.load(
		icon_path
	)
	if resource is Texture2D:
		return resource as Texture2D

	return null


func _format_stars(
	star: int
) -> String:
	var clamped_star: int = clampi(
		star,
		1,
		EquipmentManager.MAX_ASCENSION_STAR
	)
	var result: String = ""

	for index: int in range(
		EquipmentManager.MAX_ASCENSION_STAR
	):
		result += (
			"★"
			if index < clamped_star
			else "☆"
		)

	return result
