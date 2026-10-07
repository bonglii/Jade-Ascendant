extends Node

## Applies the commercial icon family to stable screens without changing
## gameplay, save, reward, equipment, or navigation authority.
##
## Hero owns its final geometry and readability inside equipment_screen.gd.
## This global manager must never mutate Hero layout after scene construction.

const ICON_DAILY: Texture2D = preload(
	"res://assets/ui/icons/actions/daily.png"
)
const ICON_ACHIEVEMENT: Texture2D = preload(
	"res://assets/ui/icons/actions/achievement.png"
)
const ICON_REWARD: Texture2D = preload(
	"res://assets/ui/pavilion/icons/reward_chest.png"
)

var _scene_instance_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	call_deferred("_refresh_current_scene")


func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var current_scene: Node = tree.current_scene
	var current_id: int = int(current_scene.get_instance_id())
	if current_id == _scene_instance_id:
		return

	_scene_instance_id = current_id
	# FIRST-PAINT STABILITY: apply scene-entry decoration once. Never keep
	# resizing/re-anchoring Hero after the player can already see the screen.
	_refresh_current_scene()


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
