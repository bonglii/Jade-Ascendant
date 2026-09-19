extends Node

## Applies the commercial icon family and mobile readability polish to stable
## existing screens without changing gameplay, save, reward, equipment, or
## navigation authority.

const EQUIPMENT_SCREEN_SCENE: String = (
	"res://scenes/ui/equipment_screen.tscn"
)

const ICON_DAILY: Texture2D = preload(
	"res://assets/ui/icons/actions/daily.png"
)
const ICON_ACHIEVEMENT: Texture2D = preload(
	"res://assets/ui/icons/actions/achievement.png"
)
const ICON_REWARD: Texture2D = preload(
	"res://assets/ui/pavilion/icons/reward_chest.png"
)

const HERO_REFRESH_INTERVAL: float = 0.30

var _scene_instance_id: int = 0
var _hero_refresh_elapsed: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	call_deferred("_refresh_current_scene")


func _process(delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var current_scene: Node = tree.current_scene
	var current_id: int = int(current_scene.get_instance_id())
	if current_id != _scene_instance_id:
		_scene_instance_id = current_id
		_hero_refresh_elapsed = 0.0
		call_deferred("_refresh_current_scene")
		return

	if current_scene.scene_file_path != EQUIPMENT_SCREEN_SCENE:
		return

	_hero_refresh_elapsed += delta
	if _hero_refresh_elapsed < HERO_REFRESH_INTERVAL:
		return
	_hero_refresh_elapsed = 0.0
	_polish_hero_screen(current_scene)


func _refresh_current_scene() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene: Node = tree.current_scene
	_scene_instance_id = int(scene.get_instance_id())

	_decorate_named_button(
		scene,
		"DailyQuickButton",
		ICON_DAILY,
		42
	)
	_decorate_named_button(
		scene,
		"AchievementQuickButton",
		ICON_ACHIEVEMENT,
		42
	)
	_decorate_named_button(
		scene,
		"DailyTab",
		ICON_DAILY,
		28
	)
	_decorate_named_button(
		scene,
		"AchievementTab",
		ICON_ACHIEVEMENT,
		28
	)
	_decorate_named_button(
		scene,
		"ClaimAllButton",
		ICON_REWARD,
		26
	)

	if scene.scene_file_path == EQUIPMENT_SCREEN_SCENE:
		_polish_hero_screen(scene)
		call_deferred("_polish_hero_screen", scene)


func _decorate_named_button(
	scene: Node,
	node_name: String,
	texture: Texture2D,
	max_width: int
) -> void:
	var node: Node = scene.find_child(node_name, true, false)
	if node == null or not node is Button:
		return
	var button := node as Button
	button.icon = texture
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", max_width)
	button.add_theme_constant_override("h_separation", 7)
	button.add_theme_color_override(
		"icon_normal_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"icon_hover_color",
		Color(1.0, 1.0, 1.0, 1.0)
	)
	button.add_theme_color_override(
		"icon_pressed_color",
		Color(0.86, 1.0, 0.94, 1.0)
	)
	button.add_theme_color_override(
		"icon_disabled_color",
		Color(0.56, 0.62, 0.60, 0.58)
	)


func _polish_hero_screen(scene: Node) -> void:
	if not is_instance_valid(scene):
		return

	# Give long Indonesian slot names enough width without shrinking Lin Yue.
	for node_name: String in ["RobeButton", "PendantButton"]:
		_configure_left_slot(
			scene.find_child(node_name, true, false) as Button
		)
	for node_name: String in [
		"ArmamentButton",
		"BracerButton",
		"BootsButton",
	]:
		_configure_right_slot(
			scene.find_child(node_name, true, false) as Button
		)

	_raise_label_readability(scene, "StatusLabel", 13)
	_raise_label_readability(scene, "StageTitle", 13)
	_raise_label_readability(scene, "BonusSummaryLabel", 12)
	_raise_label_readability(scene, "EquippedCountLabel", 14)

	var candidate_scroll := scene.find_child(
		"CandidateScroll",
		true,
		false
	) as ScrollContainer
	if candidate_scroll != null:
		var collection_vbox := candidate_scroll.get_parent() as VBoxContainer
		if collection_vbox != null:
			collection_vbox.add_theme_constant_override(
				"separation",
				10
			)

	var showcase := scene.find_child(
		"CollectionShowcase",
		true,
		false
	) as PanelContainer
	if showcase != null:
		showcase.custom_minimum_size.y = 98.0
		_polish_collection_showcase(showcase)

	var filter_bar := scene.find_child(
		"CollectionFilterBar",
		true,
		false
	) as HBoxContainer
	if filter_bar != null:
		filter_bar.custom_minimum_size.y = 42.0
		filter_bar.add_theme_constant_override("separation", 8)
		for child: Node in filter_bar.get_children():
			if child is Button:
				var filter_button := child as Button
				filter_button.custom_minimum_size.y = 38.0
				filter_button.add_theme_font_size_override(
					"font_size",
					11
				)
			elif child is Label:
				(child as Label).add_theme_font_size_override(
					"font_size",
					11
				)


func _configure_left_slot(button: Button) -> void:
	if button == null:
		return
	button.anchor_left = 0.015
	button.anchor_right = 0.225
	button.offset_left = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 90.0
	button.add_theme_font_size_override("font_size", 13)
	_polish_slot_caption(button)


func _configure_right_slot(button: Button) -> void:
	if button == null:
		return
	button.anchor_left = 0.775
	button.anchor_right = 0.985
	button.offset_left = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 90.0
	button.add_theme_font_size_override("font_size", 13)
	_polish_slot_caption(button)


func _polish_slot_caption(button: Button) -> void:
	var caption := button.get_node_or_null("SlotCaption") as Label
	if caption == null:
		return
	caption.offset_left = 5.0
	caption.offset_top = -38.0
	caption.offset_right = -5.0
	caption.offset_bottom = -3.0
	caption.add_theme_font_size_override("font_size", 10)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.max_lines_visible = 2
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.clip_text = false


func _raise_label_readability(
	scene: Node,
	node_name: String,
	font_size: int
) -> void:
	var label := scene.find_child(
		node_name,
		true,
		false
	) as Label
	if label == null:
		return
	label.add_theme_font_size_override("font_size", font_size)
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _polish_collection_showcase(root: Node) -> void:
	var labels: Array[Label] = []
	_collect_labels(root, labels)

	for label: Label in labels:
		label.clip_text = false
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2

		var upper_text: String = label.text.to_upper()
		if (
			"OWNED EQUIPMENT" in upper_text
			or "PERLENGKAPAN DIMILIKI" in upper_text
		):
			label.add_theme_font_size_override("font_size", 11)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
		elif (
			"LOADOUT RESONANCE" in upper_text
			or "RESONANSI LOADOUT" in upper_text
		):
			label.add_theme_font_size_override("font_size", 12)
		elif "/" in label.text and "%" in label.text:
			label.add_theme_font_size_override("font_size", 15)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
		else:
			var current_size: int = label.get_theme_font_size(
				"font_size"
			)
			if current_size < 10:
				label.add_theme_font_size_override(
					"font_size",
					10
				)


func _collect_labels(
	root: Node,
	target: Array[Label]
) -> void:
	for child: Node in root.get_children():
		if child is Label:
			target.append(child as Label)
		_collect_labels(child, target)
