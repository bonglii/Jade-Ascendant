extends "res://scripts/world/chapter_three_stage.gd"

## Gate A inherited arena adapter. It deliberately leaves existing player,
## HUD, wave, checkpoint, pause, reward signals and save schema untouched.
const ChapterFourCatalog = preload("res://scripts/data/chapter_four_catalog.gd")
const ChapterFiveCatalog = preload("res://scripts/data/chapter_five_catalog.gd")
const FrostFloor = preload("res://assets/shaders/realm_four_frost_floor.gdshader")
const SunforgeFloor = preload("res://assets/shaders/realm_five_sunforge_floor.gdshader")
const FrostFloorTile = preload("res://assets/world/froststone_floor_tile.png")
const SunforgeFloorTile = preload("res://assets/world/sunforge_floor_tile.png")
const RealmBattlefield = preload("res://scripts/world/realm_expansion_battlefield.gd")
const RealmTelegraph = preload("res://scripts/enemy/realm_boss_telegraph.gd")

@export_range(4, 5, 1) var realm_id: int = 4

func _enter_tree() -> void:
	stage_profile = (
		ChapterFourCatalog.get_stage(stage_id)
		if realm_id == 4
		else ChapterFiveCatalog.get_stage(stage_id)
	)
	if stage_profile.is_empty():
		push_error("RealmExpansionStage: unknown trial %d-%d" % [realm_id, stage_id])
		return
	var enemy_spawner: Node = get_node("EnemySpawner")
	if enemy_spawner.has_method("configure_stage_profile"):
		enemy_spawner.call("configure_stage_profile", stage_profile)
	else:
		push_error("RealmExpansionStage: EnemySpawner stage-profile API is missing.")
	get_node("WaveManager").set("wave_duration", float(stage_profile["wave_duration"]))
	get_node("DifficultyManager").set("difficulty_interval", float(stage_profile["difficulty_interval"]))
	hazard_timer = float(stage_profile.get("hazard_initial_delay", 11.0))
	_apply_environment_profile()
	_apply_expansion_ground()

func _ready() -> void:
	player = get_node("player_1") as Node2D
	wave_manager = get_node("WaveManager")
	var legacy_decor: CanvasItem = get_node("VerdantQiValleyDecor") as CanvasItem
	legacy_decor.visible = false
	var battlefield: Node2D = RealmBattlefield.new()
	battlefield.name = "RealmExpansionBattlefield"
	battlefield.set("realm_id", realm_id)
	battlefield.set("stage_id", stage_id)
	add_child(battlefield)
	var stage_label: Label = get_node("HUD/ScreenRoot/HUDSafeArea/StageIdentity") as Label
	stage_label.text = "%d-%d  /  %s" % [
		realm_id, stage_id, str(stage_profile.get("display_name", "Trial")).to_upper()
	]
	DebugLogger.system("Expansion trial %d-%d | %s" % [
		realm_id, stage_id, str(stage_profile.get("display_name", "Trial"))
	])

func _apply_expansion_ground() -> void:
	# One chapter-wide surface language, with stage-specific accent/mist/hazards.
	var ground: Polygon2D = get_node("VerdantQiValleyEnvironment") as Polygon2D
	var material_instance: ShaderMaterial = ground.material.duplicate() as ShaderMaterial
	ground.material = material_instance
	material_instance.shader = FrostFloor if realm_id == 4 else SunforgeFloor
	material_instance.set_shader_parameter(
		"frost_floor" if realm_id == 4 else "sunforge_floor",
		FrostFloorTile if realm_id == 4 else SunforgeFloorTile
	)

func _spawn_hazard(target: Vector2, kind: int) -> void:
	if get_tree().get_nodes_in_group("stage_hazard").size() >= 4:
		return
	var pattern_name: String = str(stage_profile.get("hazard_pattern", "frost_mark" if realm_id == 4 else "ember_mark"))
	var telegraph: Node2D = RealmTelegraph.new()
	telegraph.set("pattern", pattern_name)
	telegraph.set("is_stage_hazard", true)
	telegraph.set("damage", 8.0 + float(stage_id) if realm_id == 4 else 10.0 + float(stage_id))
	telegraph.set("warning_duration", 1.35 if kind % 2 == 1 else 1.46)
	add_child(telegraph)
	telegraph.global_position = target
