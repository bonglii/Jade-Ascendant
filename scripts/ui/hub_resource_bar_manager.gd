extends Node

## Shared top resource bar for the five primary hub screens.
## Presentation-only: reads existing manager state and never mutates economy data.
## The frame sits at the top edge of each screen's safe UI host so every hub
## presents the same wallet order, proportions, typography, and spacing.

const BAR_NODE_NAME: String = "SharedHubResourceBar"
const BAR_HEIGHT: float = 70.0
const BAR_SIDE_ANCHOR: float = 0.03
const REFRESH_INTERVAL: float = 0.20

const HOME_SCENE: String = "res://scenes/ui/main_menu.tscn"
const CULTIVATION_SCENE: String = "res://scenes/ui/cultivation_menu.tscn"
const HERO_SCENE: String = "res://scenes/ui/equipment_screen.tscn"
const TRIALS_SCENE: String = "res://scenes/ui/daily_quest_screen.tscn"
const PAVILION_SCENE: String = "res://scenes/ui/pavilion_screen.tscn"

const HUB_SCENES: Array[String] = [
	HOME_SCENE,
	CULTIVATION_SCENE,
	HERO_SCENE,
	TRIALS_SCENE,
	PAVILION_SCENE,
]

const FRAME_TEXTURE: Texture2D = preload(
	"res://assets/ui/shared/hub_resource_bar_frame.svg"
)
const SPIRIT_STONE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/spirit_stone_premium.png"
)
const REFINEMENT_SHARD_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/refinement_shard_premium.png"
)
const CELESTIAL_JADE_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/celestial_jade_premium.png"
)
const PAVILION_SEAL_ICON: Texture2D = preload(
	"res://assets/ui/shared/resources/pavilion_seal_premium.png"
)

var _bound_scene_id: int = 0
var _bound_scene_path: String = ""
var _resource_bar: Control = null
var _stone_value: Label = null
var _shard_value: Label = null
var _jade_value: Label = null
var _seal_value: Label = null
var _refresh_elapsed: float = 0.0


func _ready() -> void:
	set_process(true)
	call_deferred("_refresh_scene_binding")


func _process(delta: float) -> void:
	_refresh_elapsed += delta
	if _refresh_elapsed < REFRESH_INTERVAL:
		return
	_refresh_elapsed = 0.0
	_refresh_scene_binding()
	_sync_values()
	_enforce_bound_scene_layout()


func _refresh_scene_binding() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		_clear_binding()
		return

	var scene_path: String = scene_root.scene_file_path
	if scene_path not in HUB_SCENES:
		_clear_binding()
		return

	var scene_id: int = scene_root.get_instance_id()
	if (
		scene_id == _bound_scene_id
		and is_instance_valid(_resource_bar)
	):
		return

	_clear_binding()
	_bound_scene_id = scene_id
	_bound_scene_path = scene_path
	_install_resource_bar(scene_root, scene_path)
	_enforce_bound_scene_layout()
	_sync_values()


func _clear_binding() -> void:
	_bound_scene_id = 0
	_bound_scene_path = ""
	_resource_bar = null
	_stone_value = null
	_shard_value = null
	_jade_value = null
	_seal_value = null


func _install_resource_bar(scene_root: Node, scene_path: String) -> void:
	var host: Control = _resource_host(scene_root, scene_path)
	if host == null:
		return

	var existing: Node = host.get_node_or_null(BAR_NODE_NAME)
	if existing is Control:
		_resource_bar = existing as Control
		_cache_value_labels()
		return

	var bar := Control.new()
	bar.name = BAR_NODE_NAME
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = 80
	host.add_child(bar)
	bar.anchor_left = BAR_SIDE_ANCHOR
	bar.anchor_top = 0.0
	bar.anchor_right = 1.0 - BAR_SIDE_ANCHOR
	bar.anchor_bottom = 0.0
	bar.offset_left = 0.0
	bar.offset_top = 0.0
	bar.offset_right = 0.0
	bar.offset_bottom = BAR_HEIGHT
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.texture = FRAME_TEXTURE
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	bar.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.name = "ResourceRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	bar.add_child(row)
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 9.0
	row.offset_top = 8.0
	row.offset_right = -9.0
	row.offset_bottom = -8.0

	_stone_value = _add_resource_cell(
		row,
		SPIRIT_STONE_ICON,
		tr("Spirit Stone")
	)
	_shard_value = _add_resource_cell(
		row,
		REFINEMENT_SHARD_ICON,
		tr("Refinement Shard")
	)
	_jade_value = _add_resource_cell(
		row,
		CELESTIAL_JADE_ICON,
		tr("Celestial Jade")
	)
	_seal_value = _add_resource_cell(
		row,
		PAVILION_SEAL_ICON,
		tr("Pavilion Seal")
	)

	_resource_bar = bar


func _resource_host(scene_root: Node, _scene_path: String) -> Control:
	# Intentionally mount outside MobileSafeArea. The screen already reserves its
	# device-safe content inset; this uses that previously empty top band so the
	# shared wallet visually touches the very top edge without pushing content
	# farther down. Existing menu content remains inside its safe host.
	return scene_root as Control


func _add_resource_cell(
	parent_row: HBoxContainer,
	icon_texture: Texture2D,
	tooltip_value: String
) -> Label:
	var cell := HBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 4)
	cell.tooltip_text = tooltip_value
	parent_row.add_child(cell)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(27.0, 27.0)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell.add_child(icon)

	var value := Label.new()
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.text = "0"
	value.custom_minimum_size = Vector2(38.0, 0.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override(
		"font_color",
		Color(0.97, 0.92, 0.76, 1.0)
	)
	value.add_theme_constant_override("outline_size", 1)
	value.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.72)
	)
	cell.add_child(value)
	return value


func _cache_value_labels() -> void:
	if not is_instance_valid(_resource_bar):
		return
	var row := _resource_bar.get_node_or_null("ResourceRow") as HBoxContainer
	if row == null or row.get_child_count() < 4:
		return
	_stone_value = _cell_value_label(row.get_child(0))
	_shard_value = _cell_value_label(row.get_child(1))
	_jade_value = _cell_value_label(row.get_child(2))
	_seal_value = _cell_value_label(row.get_child(3))


func _cell_value_label(cell_node: Node) -> Label:
	if cell_node == null:
		return null
	for child_node: Node in cell_node.get_children():
		if child_node is Label:
			return child_node as Label
	return null


func _sync_values() -> void:
	if not is_instance_valid(_resource_bar):
		return
	if _stone_value != null:
		_stone_value.text = _format_count(ProgressionManager.spirit_stone)
	if _shard_value != null:
		_shard_value.text = _format_count(
			InventoryManager.get_item_count(
				InventoryManager.REFINEMENT_SHARD
			)
		)
	if _jade_value != null:
		_jade_value.text = _format_count(PavilionManager.get_celestial_jade())
	if _seal_value != null:
		_seal_value.text = _format_count(PavilionManager.get_pavilion_seals())


func _enforce_bound_scene_layout() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or scene_root.get_instance_id() != _bound_scene_id:
		return
	match _bound_scene_path:
		HOME_SCENE:
			_enforce_home_layout(scene_root)
		CULTIVATION_SCENE:
			_enforce_cultivation_layout(scene_root)
		HERO_SCENE:
			_enforce_hero_layout(scene_root)
		TRIALS_SCENE:
			_enforce_trials_layout(scene_root)
		PAVILION_SCENE:
			_enforce_pavilion_layout(scene_root)


func _enforce_home_layout(scene_root: Node) -> void:
	var legacy_currency := scene_root.get_node_or_null(
		"HomeUI/TopBar/Row/Currency"
	) as Control
	if legacy_currency != null:
		legacy_currency.visible = false

	# Home keeps its profile/settings strip, but it must sit below the one
	# shared wallet instead of being covered by it.
	var home_top_bar := scene_root.get_node_or_null(
		"HomeUI/TopBar"
	) as Control
	if home_top_bar != null:
		home_top_bar.offset_top = BAR_HEIGHT + 6.0
		home_top_bar.offset_bottom = BAR_HEIGHT + 80.0


func _enforce_cultivation_layout(scene_root: Node) -> void:
	# The old top strip duplicated both the screen label and Spirit Stone.
	# The main cultivation header already carries the screen identity below it.
	var legacy_top_bar := scene_root.get_node_or_null(
		"Content/TopBar"
	) as Control
	if legacy_top_bar != null:
		legacy_top_bar.visible = false


func _enforce_hero_layout(scene_root: Node) -> void:
	# The shared wallet replaces Hero's legacy top header. EquipmentScreen's
	# existing layout already begins the actual Hero stage at y ~= 88, leaving a
	# clean gap under the 70 px wallet without changing gameplay/UI structure.
	var old_top_header := scene_root.get_node_or_null(
		"Content/TopHeader"
	) as Control
	if old_top_header != null:
		old_top_header.visible = false

	var hero_content := scene_root.get_node_or_null("Content")
	if hero_content != null:
		_enforce_hero_readability(hero_content)


func _enforce_hero_readability(root_node: Node) -> void:
	for child_node: Node in root_node.get_children():
		# Navbar already has its own production typography contract.
		if str(child_node.name) == "HubNav":
			continue

		if child_node is Label:
			_boost_hero_label(child_node as Label)
		elif child_node is Button:
			_boost_hero_button(child_node as Button)

		_enforce_hero_readability(child_node)


func _boost_hero_label(label: Label) -> void:
	if label.has_meta("hero_mobile_font_polished"):
		return

	var source_size: int = label.get_theme_font_size("font_size")
	var target_size: int = source_size
	if source_size <= 7:
		target_size = 10
	elif source_size <= 9:
		target_size = 11
	elif source_size <= 11:
		target_size = 12
	elif source_size <= 15:
		target_size = source_size + 2

	if target_size > source_size:
		label.add_theme_font_size_override("font_size", target_size)
	label.set_meta("hero_mobile_font_polished", true)


func _boost_hero_button(button: Button) -> void:
	if button.has_meta("hero_mobile_font_polished"):
		return

	var source_size: int = button.get_theme_font_size("font_size")
	var target_size: int = source_size
	if source_size <= 7:
		target_size = 10
	elif source_size <= 9:
		target_size = 11
	elif source_size <= 11:
		target_size = 12
	elif source_size <= 13:
		target_size = 14

	if target_size > source_size:
		button.add_theme_font_size_override("font_size", target_size)
	button.set_meta("hero_mobile_font_polished", true)


func _enforce_trials_layout(scene_root: Node) -> void:
	# Trial Hall's main hero/header panel remains below this strip and already
	# identifies the screen, so remove the duplicate top resource/title strip.
	var legacy_top_bar := scene_root.get_node_or_null(
		"Content/TopBar"
	) as Control
	if legacy_top_bar != null:
		legacy_top_bar.visible = false


func _enforce_pavilion_layout(scene_root: Node) -> void:
	var legacy_wallet := scene_root.get_node_or_null(
		"SafeArea/WalletHeader"
	) as Control
	if legacy_wallet != null:
		legacy_wallet.visible = false
	var pavilion_scroll := scene_root.get_node_or_null(
		"SafeArea/Scroll"
	) as ScrollContainer
	if pavilion_scroll != null:
		pavilion_scroll.offset_top = BAR_HEIGHT + 8.0


func _format_count(value: int) -> String:
	var remaining: String = str(maxi(value, 0))
	var groups: Array[String] = []
	while remaining.length() > 3:
		groups.push_front(remaining.right(3))
		remaining = remaining.left(remaining.length() - 3)
	groups.push_front(remaining)
	return ".".join(groups)
