extends Node2D

## Enemy Spawner
## Mengelola normal enemy, Elite Enemy, dan Boss berdasarkan
## progression wave serta difficulty selama run.
## Meneruskan event kematian Enemy untuk sistem berbasis kill.

signal boss_spawned_signal(boss: Node)
signal enemy_killed

const ELITE_SPAWN_WAVES: Array[int] = [4, 8]
const ChapterOneCatalog = preload("res://scripts/data/chapter_one_catalog.gd")
const ChapterTwoEnemyVisualCatalog = preload(
	"res://scripts/data/chapter_two_enemy_visual_catalog.gd"
)
const ChapterThreeEnemyVisualCatalog = preload(
	"res://scripts/data/chapter_three_enemy_visual_catalog.gd"
)

@export var enemy_scene: PackedScene
@export var enemy_2_scene: PackedScene
@export var enemy_3_scene: PackedScene
@export var enemy_4_scene: PackedScene
@export var enemy_5_scene: PackedScene
@export var enemy_6_scene: PackedScene
@export var elite_enemy_1_scene: PackedScene
@export var elite_enemy_2_scene: PackedScene
@export var boss_scene: PackedScene

@export var spawn_distance: float = 300.0
@export var spawn_interval: float = 2.0

var boss_spawned: bool = false
var spawn_timer: float = 0.0
var elite_spawned_waves: Dictionary = {}
var run_kill_count: int = 0
var stage_profile: Dictionary = {}

var player: Node2D = null
var difficulty_manager: Node = null
var wave_manager: Node = null

func configure_stage(stage_id: int) -> void:
	configure_stage_profile(
		ChapterOneCatalog.get_stage(stage_id)
	)

func configure_stage_profile(profile: Dictionary) -> void:
	stage_profile = profile.duplicate(true)
	spawn_interval = float(
		stage_profile.get(
			"spawn_interval",
			spawn_interval
		)
	)

## Mengembalikan stable archetype id untuk enam scene normal existing.
## Scene gameplay tetap sama lintas chapter; presentation dapat berbeda.
func get_enemy_archetype_id(selected_scene: PackedScene) -> int:
	var choices: Array[PackedScene] = [
		enemy_scene, enemy_2_scene, enemy_3_scene,
		enemy_4_scene, enemy_5_scene, enemy_6_scene
	]
	for index: int in range(choices.size()):
		if choices[index] == selected_scene:
			return index + 1
	return 1

## Mengambil presentation entry berdasarkan visual set stage.
## Chapter 1 tetap memakai presentation dari scene asli.
func get_stage_enemy_visual_entry(
	archetype_id: int,
	is_elite: bool = false
) -> Dictionary:
	var visual_set: String = str(
		stage_profile.get("enemy_visual_set", "")
	)

	if visual_set == str(ChapterTwoEnemyVisualCatalog.VISUAL_SET_ID):
		return (
			ChapterTwoEnemyVisualCatalog.get_elite(archetype_id)
			if is_elite
			else ChapterTwoEnemyVisualCatalog.get_enemy(archetype_id)
		)

	if visual_set == str(ChapterThreeEnemyVisualCatalog.VISUAL_SET_ID):
		return (
			ChapterThreeEnemyVisualCatalog.get_elite(archetype_id)
			if is_elite
			else ChapterThreeEnemyVisualCatalog.get_enemy(archetype_id)
		)

	return {}

## Mengaplikasikan identity visual chapter tanpa mengubah combat behavior.
func apply_stage_enemy_identity(
	entity: Node,
	archetype_id: int,
	is_elite: bool = false
) -> void:
	if entity == null:
		return

	var entry: Dictionary = get_stage_enemy_visual_entry(
		archetype_id,
		is_elite
	)
	if entry.is_empty():
		return

	var sprite := entity.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var frames := entry.get("sprite_frames") as SpriteFrames
	if sprite != null and frames != null:
		sprite.sprite_frames = frames

	var display_name: String = str(entry.get("display_name", ""))
	if not display_name.is_empty():
		entity.set_meta("encounter_display_name", display_name)

	if entity.has_method("configure_encounter_presentation"):
		entity.call("configure_encounter_presentation", entry)

func get_enemy_display_name(entity: Node) -> String:
	if entity == null:
		return "Unknown Enemy"
	if entity.has_meta("encounter_display_name"):
		return str(entity.get_meta("encounter_display_name"))
	return str(entity.name)

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_error(str("ERROR: Player tidak ditemukan!"))
		return

	difficulty_manager = get_parent().get_node_or_null("DifficultyManager")

	if difficulty_manager == null:
		push_error(str("ERROR: DifficultyManager tidak ditemukan!"))
		return

	wave_manager = get_parent().get_node_or_null("WaveManager")

	if wave_manager == null:
		push_error(str("ERROR: WaveManager tidak ditemukan!"))
		return

	DebugLogger.system(str("EnemySpawner aktif!"))
	DebugLogger.system(str("Player ditemukan: ", player.name))
	DebugLogger.system(str("DifficultyManager terhubung!"))
	DebugLogger.system(str("WaveManager terhubung!"))

	spawn_timer = spawn_interval

func _process(delta: float) -> void:
	if player == null:
		return

	if difficulty_manager == null:
		return

	if wave_manager == null:
		return

	if wave_manager.current_wave >= wave_manager.final_wave:
		if not boss_spawned:
			spawn_boss()

		return

	try_spawn_elite_for_current_wave()

	spawn_timer -= delta

	if spawn_timer <= 0.0:
		var difficulty_spawn_count: int = (
			difficulty_manager.get_spawn_count()
		)

		var wave_spawn_bonus: int = (
			wave_manager.get_spawn_bonus()
		)

		var spawn_count: int = (
			difficulty_spawn_count
			+ wave_spawn_bonus
		)

		DebugLogger.spawn(
			"Difficulty: %d | Wave Bonus: %d | Total: %d"
			% [
				difficulty_spawn_count,
				wave_spawn_bonus,
				spawn_count
			]
		)

		# Every production stage has an explicit population ceiling. Count once
		# per spawn batch so a weak build cannot create an unbounded mobile load.
		var enemy_cap: int = int(stage_profile.get("enemy_cap", 0))
		if enemy_cap > 0:
			var alive_count: int = get_tree().get_nodes_in_group("enemy").size()
			spawn_count = mini(spawn_count, maxi(enemy_cap - alive_count, 0))

		for i in range(spawn_count):
			spawn_enemy()

		spawn_timer = get_current_spawn_interval()

## Memilih tipe normal Enemy berdasarkan progression wave.
func get_enemy_scene_for_current_wave() -> PackedScene:
	if wave_manager == null:
		return enemy_scene

	var current_wave: int = wave_manager.current_wave
	var bands: Array = stage_profile.get("enemy_bands", [])
	if not bands.is_empty():
		return get_profile_enemy_scene(current_wave, bands)
	var roll: float = randf()

	if current_wave <= 2:
		return enemy_scene

	if current_wave <= 4:
		if enemy_2_scene != null and roll < 0.25:
			return enemy_2_scene

		return enemy_scene

	if current_wave == 5:
		if enemy_3_scene != null and roll < 0.20:
			return enemy_3_scene

		if enemy_2_scene != null and roll < 0.45:
			return enemy_2_scene

		return enemy_scene

	if current_wave == 6:
		if enemy_4_scene != null and roll < 0.15:
			return enemy_4_scene

		if enemy_3_scene != null and roll < 0.35:
			return enemy_3_scene

		if enemy_2_scene != null and roll < 0.60:
			return enemy_2_scene

		return enemy_scene

	if current_wave == 7:
		if enemy_5_scene != null and roll < 0.12:
			return enemy_5_scene

		if enemy_4_scene != null and roll < 0.27:
			return enemy_4_scene

		if enemy_3_scene != null and roll < 0.47:
			return enemy_3_scene

		if enemy_2_scene != null and roll < 0.72:
			return enemy_2_scene

		return enemy_scene

	if current_wave == 8:
		if enemy_6_scene != null and roll < 0.10:
			return enemy_6_scene

		if enemy_5_scene != null and roll < 0.22:
			return enemy_5_scene

		if enemy_4_scene != null and roll < 0.37:
			return enemy_4_scene

		if enemy_3_scene != null and roll < 0.52:
			return enemy_3_scene

		if enemy_2_scene != null and roll < 0.72:
			return enemy_2_scene

		return enemy_scene

	if current_wave == 9:
		if enemy_6_scene != null and roll < 0.12:
			return enemy_6_scene

		if enemy_5_scene != null and roll < 0.27:
			return enemy_5_scene

		if enemy_4_scene != null and roll < 0.42:
			return enemy_4_scene

		if enemy_3_scene != null and roll < 0.57:
			return enemy_3_scene

		if enemy_2_scene != null and roll < 0.77:
			return enemy_2_scene

		return enemy_scene

	return enemy_scene

## Weights reference the six existing archetypes, in their stable order.
func get_profile_enemy_scene(current_wave: int, bands: Array) -> PackedScene:
	var weights: Array = []
	for band: Dictionary in bands:
		if current_wave >= int(band.get("from_wave", 1)):
			weights = band.get("weights", [])
	var choices: Array[PackedScene] = [
		enemy_scene, enemy_2_scene, enemy_3_scene,
		enemy_4_scene, enemy_5_scene, enemy_6_scene
	]
	var total: float = 0.0
	for index: int in range(mini(weights.size(), choices.size())):
		if choices[index] != null:
			total += maxf(float(weights[index]), 0.0)
	if total <= 0.0:
		return enemy_scene
	var roll: float = randf() * total
	for index: int in range(mini(weights.size(), choices.size())):
		if choices[index] == null:
			continue
		roll -= maxf(float(weights[index]), 0.0)
		if roll < 0.0:
			return choices[index]
	return enemy_scene

## Spawn satu normal Enemy menggunakan tipe yang dipilih berdasarkan wave.
func spawn_enemy() -> void:
	var selected_scene: PackedScene = (
		get_enemy_scene_for_current_wave()
	)

	if selected_scene == null:
		push_error(str("ERROR: Enemy Scene belum diisi!"))
		return

	var enemy = selected_scene.instantiate()
	var archetype_id: int = get_enemy_archetype_id(selected_scene)

	configure_top_down_character_body(enemy)
	apply_stage_enemy_identity(enemy, archetype_id)

	enemy.max_hp = (
		difficulty_manager.get_enemy_hp(enemy.max_hp)
		* float(
			stage_profile.get(
				"enemy_hp_multiplier",
				1.0
			)
		)
	)
	enemy.speed = (
		difficulty_manager.get_enemy_speed(enemy.speed)
		* float(
			stage_profile.get(
				"enemy_speed_multiplier",
				1.0
			)
		)
	)

	get_parent().add_child(enemy)

	enemy.global_position = get_random_spawn_position()

	connect_enemy_defeated_signal(enemy)

	DebugLogger.spawn(
		"Enemy: %s | HP: %.1f | Speed: %.1f"
		% [
			get_enemy_display_name(enemy),
			enemy.max_hp,
			enemy.speed
		]
	)

func apply_profile_elite_scaling(entity: Node) -> void:
	if entity == null:
		return
	entity.set(
		"max_hp",
		float(entity.get("max_hp"))
		* float(
			stage_profile.get(
				"elite_hp_multiplier",
				1.0
			)
		)
	)
	entity.set(
		"speed",
		float(entity.get("speed"))
		* float(
			stage_profile.get(
				"elite_speed_multiplier",
				1.0
			)
		)
	)

## Menetapkan physics semantics top-down pada actor CharacterBody2D.
## Tidak mengubah speed, HP, collision layer/mask, atau attack behavior.
func configure_top_down_character_body(entity: Node) -> void:
	if entity == null:
		return

	if entity is CharacterBody2D:
		var body := entity as CharacterBody2D
		body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

## Menghubungkan event kematian Enemy ke kill tracking selama run.
func connect_enemy_defeated_signal(enemy: Node) -> void:
	if enemy == null:
		return

	if not enemy.has_signal("enemy_defeated"):
		DebugLogger.system(str(
			"WARNING: ",
			enemy.name,
			" tidak memiliki signal enemy_defeated."
		))
		return

	enemy.enemy_defeated.connect(_on_enemy_defeated)

## Mencatat satu kill ketika Enemy dikalahkan melalui combat.
func _on_enemy_defeated() -> void:
	run_kill_count += 1

	DebugLogger.progression(
		"Run Kill Count: %d"
		% run_kill_count
	)

	enemy_killed.emit()

## Memeriksa apakah wave saat ini memiliki jadwal spawn Elite Enemy.
func try_spawn_elite_for_current_wave() -> void:
	var current_wave: int = wave_manager.current_wave
	var schedule: Dictionary = stage_profile.get("elite_schedule", {4: 1, 8: 2})
	if not schedule.has(current_wave):
		return

	if elite_spawned_waves.has(current_wave):
		return

	var elite_spawned: bool = false

	match int(schedule[current_wave]):
		1:
			elite_spawned = spawn_elite_enemy_1()
		2:
			elite_spawned = spawn_elite_enemy_2()

	if elite_spawned:
		elite_spawned_waves[current_wave] = true

## Spawn Elite Enemy 1 pada Wave 4.
func spawn_elite_enemy_1() -> bool:
	if elite_enemy_1_scene == null:
		push_error(str("ERROR: Elite Enemy 1 Scene belum diisi!"))
		return false

	var elite_enemy = elite_enemy_1_scene.instantiate()

	configure_top_down_character_body(elite_enemy)
	apply_profile_elite_scaling(elite_enemy)
	apply_stage_enemy_identity(elite_enemy, 1, true)

	get_parent().add_child(elite_enemy)

	elite_enemy.global_position = get_random_spawn_position()

	connect_enemy_defeated_signal(elite_enemy)

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("ELITE ENEMY 1 MUNCUL!"))
	DebugLogger.system(str("Wave: ", wave_manager.current_wave))
	DebugLogger.system(str("Identity: ", get_enemy_display_name(elite_enemy)))
	DebugLogger.system(str("Elite HP: ", elite_enemy.max_hp))
	DebugLogger.system(str("Elite Speed: ", elite_enemy.speed))
	DebugLogger.system(str("=========================================="))

	return true

## Spawn Elite Enemy 2 — Storm Cultivator pada Wave 8.
func spawn_elite_enemy_2() -> bool:
	if elite_enemy_2_scene == null:
		push_error(str("ERROR: Elite Enemy 2 Scene belum diisi!"))
		return false

	var elite_enemy = elite_enemy_2_scene.instantiate()

	configure_top_down_character_body(elite_enemy)
	apply_profile_elite_scaling(elite_enemy)
	apply_stage_enemy_identity(elite_enemy, 2, true)

	get_parent().add_child(elite_enemy)

	elite_enemy.global_position = get_random_spawn_position()

	connect_enemy_defeated_signal(elite_enemy)

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("ELITE ENEMY 2 MUNCUL!"))
	DebugLogger.system(str("Wave: ", wave_manager.current_wave))
	DebugLogger.system(str("Identity: ", get_enemy_display_name(elite_enemy)))
	DebugLogger.system(str("Elite HP: ", elite_enemy.max_hp))
	DebugLogger.system(str("Elite Speed: ", elite_enemy.speed))
	DebugLogger.system(str("=========================================="))

	return true

## Menghapus seluruh Enemy non-Boss sebelum Boss Wave dimulai.
func clear_normal_enemies() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		if enemy == null:
			continue

		if enemy.is_in_group("boss"):
			continue

		enemy.queue_free()

	DebugLogger.system(str(
		"Enemy normal dan Elite dibersihkan untuk Boss Wave!"
	))

## Menghapus seluruh serangan Enemy yang masih aktif
## sebelum transisi ke Boss Wave.
func clear_enemy_attacks() -> void:
	var enemy_attacks := (
		get_tree().get_nodes_in_group("enemy_attack")
	)

	for enemy_attack in enemy_attacks:
		if enemy_attack == null:
			continue

		enemy_attack.queue_free()

	DebugLogger.spawn(
		"Enemy attacks dibersihkan untuk Boss Wave."
	)

## Spawn Boss dan menghentikan normal enemy spawning pada Wave 10.
func spawn_boss() -> void:
	if boss_spawned:
		return
	if boss_scene == null:
		push_error(str("ERROR: Boss Scene belum diisi!"))
		return

	clear_normal_enemies()
	clear_enemy_attacks()

	var boss = boss_scene.instantiate()
	configure_top_down_character_body(boss)
	if boss.has_method("configure_encounter"):
		boss.configure_encounter(stage_profile)
	boss.position = (get_parent() as Node2D).to_local(get_random_spawn_position())

	get_parent().add_child(boss)
	boss_spawned = true

	boss_spawned_signal.emit(boss)

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("BOSS WAVE DIMULAI!"))
	DebugLogger.system(str("Boss: ", boss.name))
	DebugLogger.system(str("Wave: ", wave_manager.current_wave))
	DebugLogger.system(str("=========================================="))

## Menghasilkan posisi spawn acak di sekitar Player.
func get_random_spawn_position() -> Vector2:
	var angle: float = randf() * TAU

	var spawn_offset := Vector2(
		cos(angle),
		sin(angle)
	) * spawn_distance

	return player.global_position + spawn_offset

## Menghitung spawn interval berdasarkan Difficulty Level.
func get_current_spawn_interval() -> float:
	if difficulty_manager == null:
		return spawn_interval

	var difficulty_level: int = (
		difficulty_manager.difficulty_level
	)

	var new_interval: float = spawn_interval - (
		(difficulty_level - 1) * 0.2
	)

	return max(new_interval, 0.5)

func debug_spawn_elite_near_player() -> void:
	var elite_scene = preload(
		"res://scenes/enemy/elite_enemy_1.tscn"
	)

	var elite = elite_scene.instantiate()

	configure_top_down_character_body(elite)
	apply_stage_enemy_identity(elite, 1, true)

	elite.global_position = (
		player.global_position
		+ Vector2(120.0, 0.0)
	)

	get_parent().add_child(elite)
