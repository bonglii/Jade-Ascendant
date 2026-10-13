extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("QI_MAGNET_FAIL: " + tag)

func _settle() -> void:
	await process_frame
	await process_frame

func _elite(wave: int) -> Node2D:
	for enemy: Node2D in get_nodes_in_group("enemy"):
		if int(enemy.get_meta("qi_magnet_wave", -1)) == wave:
			return enemy
	return null

func _run() -> void:
	if not OS.get_user_data_dir().contains("jade_magnet_qa"):
		push_error("Use an isolated jade_magnet_qa user directory.")
		quit(2)
		return
	var art: Image = Image.load_from_file("res://assets/pickups/jade_qi_magnet.svg")
	check(art != null and art.get_width() == 128, "native SVG asset loads")
	if OS.has_environment("JADE_MAGNET_ART_OUTPUT"):
		art.resize(384, 384)
		art.save_png(OS.get_environment("JADE_MAGNET_ART_OUTPUT"))
	await create_timer(0.3).timeout
	var gem_scene: PackedScene = load("res://scenes/pickups/xp_gem.tscn")
	root.get_node("GameSession").start_new_game()
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "production scene loads")
	await create_timer(0.3).timeout
	var world: Node = current_scene
	var actor: Node2D = world.get_node("player_1")
	actor.set_physics_process(false)
	actor.global_position = Vector2.ZERO
	actor.get_node("WeaponManager").process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial: Node = world.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	tutorial._on_skip_pressed()
	paused = false
	var spawner: Node = world.get_node("EnemySpawner")
	spawner.process_mode = Node.PROCESS_MODE_DISABLED
	spawner.clear_normal_enemies()
	world.get_node("WaveManager").process_mode = Node.PROCESS_MODE_DISABLED
	await _settle()
	check(spawner.get_qi_magnet_waves() == [4, 8], "default milestones")
	world.get_node("WaveManager").current_wave = 4
	check(spawner.spawn_elite_enemy_1(), "real wave-four elite spawns")
	var elite: Node2D = _elite(4)
	check(elite != null, "elite tagged with original spawn wave")
	elite.global_position = Vector2(1800, 800)
	elite.die()
	await _settle()
	check(get_node_count_in_group("qi_magnet") == 1, "elite combat death drops one magnet")
	var dummy := Node2D.new()
	world.add_child(dummy)
	spawner._on_qi_magnet_elite_defeated(dummy, 4)
	spawner._on_qi_magnet_elite_defeated(dummy, 6)
	await _settle()
	check(get_node_count_in_group("qi_magnet") == 1, "repeat death and nonmilestone cannot award")
	world.get_node("WaveManager").current_wave = 8
	check(spawner.spawn_elite_enemy_2(), "real second elite spawns")
	elite = _elite(8)
	elite.global_position = Vector2(-1600, 500)
	elite.die()
	await _settle()
	check(get_node_count_in_group("qi_magnet") == 2, "two maximum drop milestones")
	var checkpoint: Node = world.get_node("CheckPointManager")
	check(checkpoint.save_checkpoint(), "production checkpoint saves magnet state")
	var saved: Dictionary = spawner.get_qi_magnet_state()
	check(saved.awarded_waves.size() == 2 and saved.pending.size() == 2, "pending drops and ledger captured")
	spawner.restore_qi_magnet_state({})
	await _settle()
	check(get_node_count_in_group("qi_magnet") == 0, "legacy checkpoint has no invented token")
	check(checkpoint.load_checkpoint(), "production checkpoint resumes")
	await _settle()
	check(get_node_count_in_group("qi_magnet") == 2 and spawner.qi_magnet_awarded_waves.size() == 2, "both pending drops restored without reaward")
	spawner._on_qi_magnet_elite_defeated(dummy, 8)
	await _settle()
	check(get_node_count_in_group("qi_magnet") == 2, "continue blocks repeated milestone drop")
	for shard: Node in get_nodes_in_group("qi_pickup"):
		shard.queue_free()
	await _settle()
	var raw_total: int = 0
	for i: int in range(166):
		var shard: Node2D = gem_scene.instantiate()
		shard.experience_value = 1 + i % 7
		raw_total += shard.experience_value
		shard.position = Vector2(2000 + i * 30, -1000)
		world.add_child(shard)
	await _settle()
	var shards: Array[Node] = get_nodes_in_group("qi_pickup")
	check(shards.size() == 160, "existing pickup cap preserved")
	var preserved: int = 0
	for shard: Node in shards:
		preserved += int(shard.experience_value)
	check(preserved == raw_total, "overflow conserves all XP")
	actor.spiritual_insight_level = 3
	actor.experience_to_next_level = 1000000
	var expected: int = 0
	for shard: Node in shards:
		expected += int(round(float(shard.experience_value) * actor.get_experience_multiplier()))
	var before: int = actor.experience
	var token: Node = get_nodes_in_group("qi_magnet")[0]
	token._on_body_entered(actor)
	token._on_body_entered(actor)
	check(token.shard_count == 160 and get_node_count_in_group("qi_magnet") == 1, "vacuum snapshots all shards exactly once")
	check(actor.experience == before, "XP awarded on shard arrival, not activation")
	var location: Vector2 = shards[0].global_position
	paused = true
	await _settle()
	check(shards[0].global_position == location, "vacuum flight respects existing pause")
	paused = false
	for shard: Node in shards:
		shard._physics_process(0.7)
		shard._on_body_entered(actor)
	check(actor.experience - before == expected, "per-shard multiplier and rounding applied exactly once")
	check(get_node_count_in_group("qi_pickup") == 0, "all existing shards collected")
	var fresh: Node2D = gem_scene.instantiate()
	fresh.position = Vector2(4000, 4000)
	world.add_child(fresh)
	check(not fresh.attracted, "later XP is not vacuumed forever")
	fresh.queue_free()
	await _settle()
	var chase: Node2D = gem_scene.instantiate()
	chase.position = Vector2(300, 0)
	world.add_child(chase)
	actor.velocity = Vector2(900, 0)
	check(chase.attract_to_player(actor), "fast player can activate shard attraction")
	chase._physics_process(0.3)
	check(chase.collected, "vacuum shard speed exceeds fast player movement")
	actor.velocity = Vector2.ZERO
	actor.level = 1
	actor.experience = 0
	actor.experience_to_next_level = 10
	var level_shards: Array[Node2D] = []
	for i: int in range(3):
		var shard: Node2D = gem_scene.instantiate()
		shard.position = Vector2(3000 + i * 100, 3000)
		shard.experience_value = 20
		world.add_child(shard)
		level_shards.append(shard)
	get_nodes_in_group("qi_magnet")[0]._on_body_entered(actor)
	for step: int in range(30):
		if not paused:
			for shard: Node2D in level_shards:
				if is_instance_valid(shard) and not shard.is_queued_for_deletion():
					shard._physics_process(0.7)
					if paused:
						break
		var panel: Control = world.get_node("HUD/LevelUpPanel")
		if panel.visible:
			panel._on_upgrade_button_pressed(0)
			await create_timer(0.15).timeout
		await _settle()
		if get_node_count_in_group("qi_pickup") == 0 and not paused:
			break
	check(actor.level >= 4 and not paused, "multiple vacuum level-ups resolve through existing choice panel")
	check(get_node_count_in_group("qi_pickup") == 0, "paused multi-level collection loses no shards")
	for chapter: String in ["one", "two", "three", "four", "five"]:
		var catalog: Script = load("res://scripts/data/chapter_%s_catalog.gd" % chapter)
		for stage: int in range(1, 6):
			var data: Dictionary = catalog.get_stage(stage)
			var packed: PackedScene = load(data.scene_path)
			var instance: Node = packed.instantiate()
			var owner: Node = instance.get_node("EnemySpawner")
			owner.stage_profile = data
			var milestones: Array[int] = owner.get_qi_magnet_waves()
			var schedule: Dictionary = data.get("elite_schedule", {4: 1, 8: 2})
			check(milestones.size() == 2, "two authored milestones per production stage")
			for milestone: int in milestones:
				check(schedule.has(milestone), "magnet wave exists in authored elite schedule")
			instance.free()
	for path: String in ["res://scenes/levels/stage_4_1.tscn", "res://scenes/levels/stage_5_1.tscn"]:
		check(change_scene_to_file(path) == OK, "realm scene loads")
		await create_timer(0.3).timeout
		paused = false
		world = current_scene
		spawner = world.get_node("EnemySpawner")
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
		world.get_node("WaveManager").current_wave = 8
		world.get_node("WaveManager").process_mode = Node.PROCESS_MODE_DISABLED
		world.get_node("player_1/WeaponManager").process_mode = Node.PROCESS_MODE_DISABLED
		check(spawner.spawn_elite_enemy_2(), "realm storm override spawns")
		elite = _elite(8)
		check(elite != null, "realm override retains magnet tag")
		elite.global_position = Vector2(2200, -2000)
		elite.die()
		await _settle()
		check(get_node_count_in_group("qi_magnet") == 1, "realm override death drops magnet")
	print("QI_MAGNET_QA checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
