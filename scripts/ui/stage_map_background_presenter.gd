extends Control

## Presentation-only chapter-authored map background for Stage Select.
## The map artwork scrolls with the actual stage nodes, but progression,
## interaction, checkpoints, rewards, and scene navigation remain untouched.
##
## This node is intentionally installed from the stage_select.tscn scene root
## after the existing StageSelect._ready() has constructed the map canvas.

const MAP_BACKGROUND_PATHS: Dictionary = {
	1: "res://assets/ui/journey/stage_maps/chapter_1_stage_map.png",
	2: "res://assets/ui/journey/stage_maps/chapter_2_stage_map.png",
	3: "res://assets/ui/journey/stage_maps/chapter_3_stage_map.png",
}

const BACKGROUND_NAME: StringName = &"ChapterStageMapBackground"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_install_into_stage_map")


func _install_into_stage_map() -> void:
	if not is_inside_tree():
		return
	var stage_screen: Control = get_parent() as Control
	if stage_screen == null:
		return
	var map_scroll: ScrollContainer = stage_screen.get("map_scroll") as ScrollContainer
	if not is_instance_valid(map_scroll):
		push_warning("StageMapBackgroundPresenter: Stage Select scroll not ready.")
		return
	var stage_refs_value: Variant = stage_screen.get("_stage_node_refs")
	if not (stage_refs_value is Dictionary):
		push_warning("StageMapBackgroundPresenter: stage references unavailable.")
		return
	var stage_refs: Dictionary = stage_refs_value
	var canvas: Control = null
	for candidate_value: Variant in stage_refs.values():
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		var stage_button: Button = candidate.get("button") as Button
		if is_instance_valid(stage_button):
			canvas = stage_button.get_parent() as Control
			break
	if canvas == null or canvas.get_parent() != map_scroll:
		push_warning("StageMapBackgroundPresenter: journey canvas not found.")
		return
	if canvas.has_node(NodePath(String(BACKGROUND_NAME))):
		return

	var chapter_id: int = int(stage_screen.get("chapter_id"))
	var art_path: String = str(MAP_BACKGROUND_PATHS.get(chapter_id, ""))
	if art_path.is_empty():
		push_warning("StageMapBackgroundPresenter: no map artwork for chapter %d." % chapter_id)
		return
	var background_art: Texture2D = ResourceLoader.load(art_path, "Texture2D") as Texture2D
	if background_art == null:
		push_error("StageMapBackgroundPresenter: missing map image: " + art_path)
		return

	# Important: parent is the SCROLL CONTENT canvas, not the viewport.
	# Keep the whole authored picture mapped to the same coordinate space as
	# the existing node positions; this is a deliberate STRETCH_SCALE fit.
	var backdrop := TextureRect.new()
	backdrop.name = String(BACKGROUND_NAME)
	backdrop.texture = background_art
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.move_child(backdrop, 0)

	# This staging helper never owns progression or input and does not need
	# to stay alive after installing the background in the canvas.
	queue_free()
