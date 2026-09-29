extends Node2D

## Arena configuration lives on the level instance, not in selected UI state.
## This lets Continue load the checkpoint's scene even after browsing another trial.
const ChapterOneCatalog = preload("res://scripts/data/chapter_one_catalog.gd")
const StageHazard = preload("res://scripts/world/stage_hazard.gd")
const ChapterOneBattlefieldGround = preload("res://assets/shaders/chapter_one_battlefield_ground.gdshader")
const ChapterOneBattlefieldVisual = preload("res://scripts/world/chapter_one_battlefield_visual.gd")
const ChapterOnePaintedFloor = preload("res://assets/world/chapter_one/forest_floor_tile.png")

@export_range(1, 6, 1) var stage_id: int = 1

var stage_profile: Dictionary = {}
var hazard_timer: float = 10.0
var hazard_cycle: int = 0
var autosave_left: float = 15.0
var player: Node2D
var wave_manager: Node

func _enter_tree() -> void:
	stage_profile = ChapterOneCatalog.get_stage(stage_id)
	# Children exist after PackedScene instantiation; initialize their exports
	# now, before WaveManager initializes its timer in _ready.
	get_node("EnemySpawner").call("configure_stage", stage_id)
	get_node("WaveManager").set("wave_duration", float(stage_profile["wave_duration"]))
	get_node("DifficultyManager").set("difficulty_interval", float(stage_profile["difficulty_interval"]))
	if stage_id > 1:
		_apply_environment_profile()
	if stage_id <= 5:
		_apply_shared_chapter_ground()

func _ready() -> void:
	player = get_node("player_1") as Node2D
	wave_manager = get_node("WaveManager")
	# Chapter 1 trials 1-1..1-5 share a single authored battlefield.
	# Historical 1-6 is preserved for legacy checkpoint compatibility.
	if stage_id <= 5:
		# Hide older stage-specific procedural art, but keep its node, script and
		# stage identity alive for scene contracts and old QA checks.
		var old_decor: CanvasItem = get_node("VerdantQiValleyDecor") as CanvasItem
		old_decor.visible = false
		var battlefield := ChapterOneBattlefieldVisual.new()
		battlefield.name = "ChapterOneBattlefieldVisual"
		battlefield.z_index = -72
		add_child(battlefield)
	var stage_label: Label = get_node("HUD/ScreenRoot/HUDSafeArea/StageIdentity") as Label
	stage_label.text = "1-%d  /  %s" % [stage_id, str(stage_profile["display_name"]).to_upper()]
	DebugLogger.system("Stage 1-%d | %s" % [stage_id, stage_profile["display_name"]])

func _apply_shared_chapter_ground() -> void:
	# Preserve stage identity and hazard tint, but share the same visible
	# Verdant Qi Valley ground palette and stone-path pattern across 1-1..1-5.
	var ground: Polygon2D = get_node("VerdantQiValleyEnvironment") as Polygon2D
	var material_instance: ShaderMaterial = ground.material.duplicate() as ShaderMaterial
	ground.material = material_instance
	material_instance.shader = ChapterOneBattlefieldGround
	material_instance.set_shader_parameter("forest_floor", ChapterOnePaintedFloor)
	var palette: Dictionary = ChapterOneCatalog.get_stage(1)
	material_instance.set_shader_parameter("deep_earth", palette["ground"])
	material_instance.set_shader_parameter("moss_jade", palette["moss"])
	material_instance.set_shader_parameter("wet_stone", palette["stone"])
	material_instance.set_shader_parameter("qi_jade", palette["accent"])
	material_instance.set_shader_parameter("qi_cyan", palette["accent"])
	# Keep the same atmospheric palette on 1-1 through 1-5 as well. The
	# encounter/hazard/weapon colors remain owned by the individual stage.
	for layer_name: String in ["VerdantQiValleyMistFar", "VerdantQiValleyQiNear"]:
		var layer: Polygon2D = get_node(layer_name) as Polygon2D
		var layer_material: ShaderMaterial = layer.material.duplicate() as ShaderMaterial
		layer.material = layer_material
		layer_material.set_shader_parameter("mist_color", palette["mist"])
		layer_material.set_shader_parameter("qi_color", palette["accent"])
		layer_material.set_shader_parameter("motion_speed", 0.55 if layer_name == "VerdantQiValleyMistFar" else 0.9)
		layer_material.set_shader_parameter("mist_strength", 0.075 if layer_name == "VerdantQiValleyMistFar" else 0.033)

func _apply_environment_profile() -> void:
	var ground: Polygon2D = get_node("VerdantQiValleyEnvironment") as Polygon2D
	var ground_material: ShaderMaterial = ground.material.duplicate() as ShaderMaterial
	ground.material = ground_material
	ground_material.set_shader_parameter("deep_earth", stage_profile["ground"])
	ground_material.set_shader_parameter("moss_jade", stage_profile["moss"])
	ground_material.set_shader_parameter("wet_stone", stage_profile["stone"])
	ground_material.set_shader_parameter("qi_jade", stage_profile["accent"])
	ground_material.set_shader_parameter("qi_cyan", stage_profile["accent"])
	for node_name: String in ["VerdantQiValleyMistFar", "VerdantQiValleyQiNear"]:
		var layer: Polygon2D = get_node(node_name) as Polygon2D
		var mist_material: ShaderMaterial = layer.material.duplicate() as ShaderMaterial
		layer.material = mist_material
		mist_material.set_shader_parameter("mist_color", stage_profile["mist"])
		mist_material.set_shader_parameter("qi_color", stage_profile["accent"])
		mist_material.set_shader_parameter("motion_speed", 1.6 if stage_id == 4 else 0.8)
		if node_name == "VerdantQiValleyMistFar":
			mist_material.set_shader_parameter("mist_strength", 0.13 if stage_id == 2 else 0.075)

func _process(delta: float) -> void:
	autosave_left -= delta
	if autosave_left <= 0.0:
		autosave_left = 20.0
		_save_safe_checkpoint()
	var kind: int = int(stage_profile.get("hazard_kind", 0))
	if kind == 0 or not is_instance_valid(player) or wave_manager == null:
		return
	if wave_manager.current_wave < 3 or wave_manager.current_wave >= wave_manager.final_wave:
		return
	hazard_timer -= delta
	if hazard_timer > 0.0:
		return
	hazard_timer = float(stage_profile["hazard_interval"])
	hazard_cycle += 1
	# Telegraphs use fixed snapshots and stop during the boss encounter.
	# The whole group is bounded; no nodes are allocated every frame.
	if get_tree().get_nodes_in_group("stage_hazard").size() >= 4:
		return
	var target: Vector2 = player.global_position
	if stage_id == 6:
		var secondary_kind: int = int(stage_profile.get("secondary_hazard_kind", 1))
		var active_kind: int = kind if hazard_cycle % 2 == 1 else secondary_kind
		_spawn_hazard(target, active_kind)
		if wave_manager.current_wave >= 6:
			var flank: Vector2 = Vector2.LEFT if hazard_cycle % 2 == 0 else Vector2.RIGHT
			var flank_kind: int = secondary_kind if active_kind == kind else kind
			_spawn_hazard(target + flank * 165.0, flank_kind)
		return
	_spawn_hazard(target, kind)
	if stage_id == 5 and wave_manager.current_wave >= 6:
		var flank: Vector2 = Vector2.LEFT if hazard_cycle % 2 == 0 else Vector2.RIGHT
		_spawn_hazard(target + flank * 150.0, kind)

func _spawn_hazard(target: Vector2, kind: int) -> void:
	var hazard: Node2D = StageHazard.new()
	hazard.set("hazard_kind", kind)
	hazard.set("accent", stage_profile["accent"])
	hazard.position = to_local(target)
	add_child(hazard)

func _save_safe_checkpoint() -> void:
	if not is_node_ready() or not JourneyManager.has_active_run() or SaveManager.is_progress_read_only():
		return
	var hud: Node = get_node("HUD")
	# A level already awarded with its choice still open is not a complete
	# snapshot. Keep the previous snapshot until that choice is resolved.
	if bool(hud.level_up_panel.visible):
		return
	if bool(player.get_node("PlayerHealth").get("is_dead")):
		return
	get_node("CheckPointManager").call("save_checkpoint")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		_save_safe_checkpoint()
		get_node("HUD").call("_on_pause_pressed")
