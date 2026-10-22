extends SceneTree
var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("CADENCE_REALMS " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):
		quit(2)
		return
	await process_frame
	for chapter: int in [1, 4, 5]:
		paused = false
		root.get_node("GameSession").start_new_game()
		var data: Dictionary = root.get_node("JourneyManager").get_stage_data(chapter, 1)
		check(change_scene_to_file(str(data.scene_path)) == OK, "authored realm scene " + str(chapter))
		await create_timer(0.15).timeout
		current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
		paused = false
		var owner: Node = current_scene.get_node("EnemySpawner")
		var wave: Node = current_scene.get_node("WaveManager")
		owner.set_process(false)
		wave.set_process(false)
		current_scene.get_node("player_1").set_physics_process(false)
		current_scene.get_node("player_1/WeaponManager").set_process(false)
		owner.clear_normal_enemies()
		await process_frame
		var slot: int = 0
		for at: int in data.elite_schedule:
			if int(data.elite_schedule[at]) == 2:
				slot = at
		check(slot > 0, "stage has authored lightning elite")
		wave.current_wave = slot
		owner.try_spawn_elite_for_current_wave()
		var original: Node = get_first_node_in_group("enemy")
		original.set_physics_process(false)
		original.current_hp = original.max_hp * 0.35
		var script_path: String = original.get_script().resource_path
		var damage: float = original.lightning_damage
		var max_hp: float = original.max_hp
		var state: Dictionary = owner.get_encounter_cadence_state()
		owner.restore_encounter_cadence_state(state)
		await process_frame
		var living: Array[Node] = get_nodes_in_group("enemy")
		check(living.size() == 1, "one unfinished elite after restore " + str(chapter))
		var restored: Node = living[0]
		restored.set_physics_process(false)
		check(restored.get_script().resource_path == script_path, "realm-specific lightning script preserved")
		check(is_equal_approx(restored.max_hp, max_hp) and is_equal_approx(restored.lightning_damage, damage), "authored pressure/scaling preserved")
		check(is_equal_approx(restored.current_hp / restored.max_hp, 0.35), "damaged health preserved")
		owner.restore_encounter_cadence_state(state)
		await process_frame
		check(get_nodes_in_group("enemy").size() == 1, "restore is repeatable without stacking elites")
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("CADENCE_REALMS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
