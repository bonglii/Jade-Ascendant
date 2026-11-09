extends SceneTree
# Controlled production-scene fixture. Never load player userdata.
func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for index: int in count:
		await process_frame

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_crowd_qa"):
		quit(2)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var chapter: int = int(args[0])
	var count: int = int(args[1])
	await frames(8)
	Engine.max_fps = 0
	var prewarm: Node = root.get_node_or_null("MenuResourcePrewarm")
	if prewarm != null:
		prewarm.free()
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	root.get_node("SettingsManager").reduced_effects = false
	var journey: Node = root.get_node("JourneyManager")
	journey.unlocked_stage_keys.assign(["1-1","1-2","1-3","1-4","1-5","5-5"])
	journey.cleared_stage_keys.assign(["1-1","1-2","1-3","1-4","1-5"])
	journey.select_stage(chapter,5)
	journey.begin_selected_stage()
	root.get_node("GameSession").start_new_game()
	change_scene_to_file("res://scenes/levels/stage_%d_5.tscn" % chapter)
	await frames(16)
	var arena: Node = current_scene
	var player: CharacterBody2D = arena.get_node("player_1")
	var health: Node = player.get_node("PlayerHealth")
	var weapons: Node = player.get_node("WeaponManager")
	weapons.run_paths.boon = "none"
	weapons.get_node("RunPathChoices").set_process(false)
	health.max_health = 10000000.0
	health.current_health = health.max_health
	var waves: Node = arena.get_node("WaveManager")
	waves.set_process(false)
	waves.current_wave = 6
	waves.wave_timer = 24.0
	var spawner: Node = arena.get_node("EnemySpawner")
	spawner.set_process(false)
	for enemy: Node in get_nodes_in_group("enemy"):
		enemy.queue_free()
	await frames(3)
	seed(91106)
	var center: Vector2 = player.global_position
	for index: int in count:
		spawner.spawn_enemy()
		var mob: CharacterBody2D = arena.get_child(-1) as CharacterBody2D
		if mob == null or not mob.is_in_group("enemy"):
			push_error("Production spawner failed")
			quit(1)
			return
		var angle: float = index * 2.399963229728653
		var radius: float = 52.0 + 235.0 * sqrt(float(index) / count)
		mob.global_position = center + Vector2.from_angle(angle) * radius
		mob.max_hp *= 1000.0
		mob.current_hp = mob.max_hp
	var mobs: Array[Node] = get_nodes_in_group("enemy")
	await frames(90)
	var frame_ms := PackedFloat64Array()
	var sampled_poses: int = 0
	var sampled_frames: int = 0
	var peak_hostiles: int = 0
	for index: int in 480:
		var start: int = Time.get_ticks_usec()
		var direction: Vector2 = Vector2.from_angle(index / 73.0)
		player.velocity = direction * 100.0
		player.global_position = center + direction * 78.0
		await process_frame
		frame_ms.append((Time.get_ticks_usec() - start) / 1000.0)
		if index % 4 == 0:
			for mob: Node in mobs:
				if is_instance_valid(mob):
					var pose: Node = mob.get_node_or_null("QiPresentation")
					sampled_poses += int(pose != null and pose.is_processing())
			sampled_frames += 1
			peak_hostiles = maxi(peak_hostiles,get_node_count_in_group("enemy_attack"))
	frame_ms.sort()
	var trace: Dictionary = weapons.get_node("RunCombatLedger").snapshot()
	print("CROWD_PAIRED " + JSON.stringify({
		"chapter":chapter,"enemies":get_node_count_in_group("enemy"),"frames":frame_ms.size(),
		"p50_ms":frame_ms[240],"p95_ms":frame_ms[455],"max_ms":frame_ms[-1],
		"active_poses":float(sampled_poses)/sampled_frames,"peak_hostiles":peak_hostiles,
		"hp_loss":health.max_health-health.current_health,"damage":trace.totals,"incoming":trace.metrics
	}))
	current_scene.free()
	current_scene = null
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit()
