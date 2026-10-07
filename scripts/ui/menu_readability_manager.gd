extends Node

## Production menu readability normalization.
##
## Presentation-only. It never mutates gameplay, rewards, progression, economy,
## save data, navigation state, or input authority.
##
## All production scenes under res://scenes/ui/ share one mobile readability
## floor. LAB scenes are intentionally excluded so visual sandboxes remain
## isolated from production presentation rules.
##
## FIRST-PAINT STABILITY CONTRACT:
## Production UI must resolve its final font size and geometry before it becomes
## visibly interactive. This manager is a fallback, never a delayed animation.
## Selection-only interactions must update existing nodes in place instead of
## rebuilding unaffected sibling cards.

const UI_SCENE_PREFIX: String = "res://scenes/ui/"
const LAB_SEGMENT: String = "/lab/"
const HERO_SCENE: String = "res://scenes/ui/equipment_screen.tscn"
const BACKPACK_SCENE: String = "res://scenes/ui/backpack_screen.tscn"
const READABILITY_META: StringName = &"jade_mobile_readability_v2"

var _last_scene_id: int = 0
var _dirty: bool = true
var _refresh_queued: bool = false


func _ready() -> void:
	set_process(true)
	var tree: SceneTree = get_tree()
	if tree != null and not tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.connect(_on_tree_node_added)
	call_deferred("_refresh_current_scene")


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.disconnect(_on_tree_node_added)


func _process(_delta: float) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var scene_id: int = tree.current_scene.get_instance_id()
	if scene_id == _last_scene_id:
		return

	_dirty = true
	_refresh_current_scene()


func _refresh_current_scene() -> void:
	_refresh_queued = false
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null:
		_last_scene_id = 0
		return

	var scene_id: int = scene.get_instance_id()
	if scene_id != _last_scene_id:
		_last_scene_id = scene_id
		_dirty = true

	if not _dirty:
		return
	_dirty = false

	var scene_path: String = scene.scene_file_path
	if not _is_production_ui_scene(scene_path):
		return

	_apply_readability_tree(scene, scene_path)


func _on_tree_node_added(added_node: Node) -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	var scene: Node = tree.current_scene
	if not _is_production_ui_scene(scene.scene_file_path):
		return
	if added_node == scene or scene.is_ancestor_of(added_node):
		# Dynamic Pavilion / Trials / LiveOps controls are often configured after
		# add_child(). Run one deferred pass after the current build stack finishes,
		# instead of leaving visible text at a smaller size for up to 150 ms.
		_dirty = true
		_queue_refresh()


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_current_scene")


func _is_production_ui_scene(scene_path: String) -> bool:
	return (
		scene_path.begins_with(UI_SCENE_PREFIX)
		and not scene_path.contains(LAB_SEGMENT)
	)


func _apply_readability_tree(root: Node, scene_path: String) -> void:
	_apply_readability_to_node(root, scene_path)
	for child_node: Node in root.get_children():
		_apply_readability_tree(child_node, scene_path)


func _apply_readability_to_node(node: Node, scene_path: String) -> void:
	if not (node is Control):
		return
	if node.has_meta(READABILITY_META):
		return

	var hero_family: bool = scene_path in [HERO_SCENE, BACKPACK_SCENE]

	if node is Label:
		var label := node as Label
		var source_size: int = label.get_theme_font_size("font_size")
		var target_size: int = _target_label_size(source_size, hero_family)
		if target_size > source_size:
			label.add_theme_font_size_override("font_size", target_size)

	elif node is BaseButton:
		var button := node as BaseButton
		var source_size: int = button.get_theme_font_size("font_size")
		var target_size: int = _target_button_size(source_size, hero_family)
		if target_size > source_size:
			button.add_theme_font_size_override("font_size", target_size)

	elif node is LineEdit:
		var line_edit := node as LineEdit
		var source_size: int = line_edit.get_theme_font_size("font_size")
		var target_size: int = _target_body_size(source_size, hero_family)
		if target_size > source_size:
			line_edit.add_theme_font_size_override("font_size", target_size)

	elif node is TextEdit:
		var text_edit := node as TextEdit
		var source_size: int = text_edit.get_theme_font_size("font_size")
		var target_size: int = _target_body_size(source_size, hero_family)
		if target_size > source_size:
			text_edit.add_theme_font_size_override("font_size", target_size)

	node.set_meta(READABILITY_META, true)


func _target_label_size(source_size: int, hero_family: bool) -> int:
	var target: int = source_size
	if source_size <= 7:
		target = 12
	elif source_size <= 9:
		target = 13
	elif source_size <= 11:
		target = 14
	elif source_size <= 13:
		target = 15
	elif source_size <= 15:
		target = 16

	# Hero/Backpack had the densest 7–9 px typography in production. Give this
	# family one additional step instead of leaving it at the generic minimum.
	if hero_family and source_size <= 15:
		target = maxi(target + 1, 14)
	return target


func _target_button_size(source_size: int, hero_family: bool) -> int:
	var target: int = source_size
	if source_size <= 9:
		target = 13
	elif source_size <= 11:
		target = 14
	elif source_size <= 13:
		target = 15
	elif source_size <= 15:
		target = 16

	if hero_family and source_size <= 15:
		target = maxi(target + 1, 14)
	return target


func _target_body_size(source_size: int, hero_family: bool) -> int:
	var target: int = source_size
	if source_size <= 11:
		target = 14
	elif source_size <= 13:
		target = 15
	elif source_size <= 15:
		target = 16
	if hero_family and source_size <= 15:
		target += 1
	return target
