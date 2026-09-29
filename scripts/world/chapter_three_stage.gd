extends Node2D

## Nine Heavens Star Palace production stage controller.
## Reuses the proven Chapter 2 runtime pipeline while owning Chapter 3 catalog,
## celestial presentation, hazard cadence, and checkpoint-safe stage identity.

const CHAPTER_ID: int = 3
const ChapterThreeCatalog = preload("res://scripts/data/chapter_three_catalog.gd")
const StageHazard = preload("res://scripts/world/stage_hazard.gd")
const ChapterThreeBattlefieldGround = preload("res://assets/shaders/chapter_three_battlefield_ground.gdshader")
const ChapterThreeBattlefieldVisual = preload("res://scripts/world/chapter_three_battlefield_visual.gd")
const ChapterThreePaintedFloor = preload("res://assets/world/chapter_three/celestial_floor_tile.png")

@export_range(1, 5, 1) var stage_id: int = 1

var stage_profile: Dictionary = {}
var hazard_timer: float = 8.0
var hazard_cycle: int = 0
var autosave_left: float = 15.0
var player: Node2D
var wave_manager: Node

func _enter_tree() -> void:
	stage_profile = ChapterThreeCatalog.get_stage(stage_id)
	var enemy_spawner: Node = get_node("EnemySpawner")
	if enemy_spawner.has_method("configure_stage_profile"):
		enemy_spawner.call("configure_stage_profile", stage_profile)
	else:
		push_error("ChapterThreeStage: EnemySpawner belum mendukung stage profile generik.")
	get_node("WaveManager").set("wave_duration", float(stage_profile["wave_duration"]))
	get_node("DifficultyManager").set(
		"difficulty_interval",
		float(stage_profile["difficulty_interval"])
	)
	hazard_timer = float(
		stage_profile.get(
			"hazard_initial_delay",
			stage_profile.get("hazard_interval", 8.0)
		)
	)
	_apply_environment_profile()
	_apply_shared_chapter_ground()

func _ready() -> void:
	player = get_node("player_1") as Node2D
	wave_manager = get_node("WaveManager")
	# Preserve the original stage decor node and per-stage visual-signature API
	# for save compatibility / smoke tests. Only hide its legacy drawing.
	var old_decor: CanvasItem = get_node("VerdantQiValleyDecor") as CanvasItem
	old_decor.visible = false
	var battlefield := ChapterThreeBattlefieldVisual.new()
	battlefield.name = "ChapterThreeBattlefieldVisual"
	battlefield.z_index = -72
	add_child(battlefield)
	var stage_label: Label = (
		get_node("HUD/ScreenRoot/HUDSafeArea/StageIdentity") as Label
	)
	stage_label.text = "3-%d  /  %s" % [
		stage_id,
		str(stage_profile["display_name"]).to_upper()
	]
	DebugLogger.system(
		"Stage 3-%d | %s" % [stage_id, stage_profile["display_name"]]
	)

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
		mist_material.set_shader_parameter(
			"motion_speed",
			float(stage_profile.get("motion_speed", 1.0))
		)
		if node_name == "VerdantQiValleyMistFar":
			mist_material.set_shader_parameter(
				"mist_strength",
				float(stage_profile.get("mist_strength", 0.08))
			)

func _apply_shared_chapter_ground() -> void:
	# This visual override replaces only the ground material and ambience.
	# Spawn rates, hazard colors, and stage-profile metadata remain untouched.
	var ground: Polygon2D = get_node("VerdantQiValleyEnvironment") as Polygon2D
	var material_instance: ShaderMaterial = ground.material.duplicate() as ShaderMaterial
	ground.material = material_instance
	material_instance.shader = ChapterThreeBattlefieldGround
	material_instance.set_shader_parameter("celestial_floor", ChapterThreePaintedFloor)
	var palette: Dictionary = ChapterThreeCatalog.get_stage(1)
	material_instance.set_shader_parameter("deep_earth", palette["ground"])
	material_instance.set_shader_parameter("moss_jade", palette["moss"])
	material_instance.set_shader_parameter("wet_stone", palette["stone"])
	material_instance.set_shader_parameter("qi_jade", palette["accent"])
	material_instance.set_shader_parameter("qi_cyan", palette["accent"])
	for layer_name: String in ["VerdantQiValleyMistFar", "VerdantQiValleyQiNear"]:
		var layer: Polygon2D = get_node(layer_name) as Polygon2D
		var layer_material: ShaderMaterial = layer.material.duplicate() as ShaderMaterial
		layer.material = layer_material
		layer_material.set_shader_parameter("mist_color", palette["mist"])
		layer_material.set_shader_parameter("qi_color", palette["accent"])
		layer_material.set_shader_parameter("motion_speed", 0.52 if layer_name == "VerdantQiValleyMistFar" else 0.88)
		layer_material.set_shader_parameter("mist_strength", 0.055 if layer_name == "VerdantQiValleyMistFar" else 0.028)

func _process(delta: float) -> void:
	autosave_left -= delta
	if autosave_left <= 0.0:
		autosave_left = 20.0
		_save_safe_checkpoint()

	var kind: int = int(stage_profile.get("hazard_kind", 0))
	if kind == 0 or not is_instance_valid(player) or wave_manager == null:
		return

	var start_wave: int = int(stage_profile.get("hazard_start_wave", 3))
	if wave_manager.current_wave < start_wave or wave_manager.current_wave >= wave_manager.final_wave:
		return

	hazard_timer -= delta
	if hazard_timer > 0.0:
		return

	hazard_timer = float(stage_profile.get("hazard_interval", 10.0))
	hazard_cycle += 1
	if get_tree().get_nodes_in_group("stage_hazard").size() >= 4:
		return

	var target: Vector2 = player.global_position
	_spawn_hazard(target, kind)

	var flank_wave: int = int(stage_profile.get("hazard_flank_wave", 999))
	if wave_manager.current_wave >= flank_wave:
		var flank_offset: float = float(stage_profile.get("hazard_flank_offset", 150.0))
		var flank_direction: Vector2 = Vector2.LEFT if hazard_cycle % 2 == 0 else Vector2.RIGHT
		_spawn_hazard(target + flank_direction * flank_offset, kind)

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
	if bool(hud.level_up_panel.visible):
		return
	if bool(player.get_node("PlayerHealth").get("is_dead")):
		return
	get_node("CheckPointManager").call("save_checkpoint")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		_save_safe_checkpoint()
		get_node("HUD").call("_on_pause_pressed")
