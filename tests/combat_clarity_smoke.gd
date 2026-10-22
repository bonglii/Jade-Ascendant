extends SceneTree
const Cadence = preload("res://scripts/data/encounter_cadence_state.gd")
var checks: int = 0
var failures: int = 0

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("COMBAT_CLARITY " + caption)

func frames(count: int = 4) -> void:
	for i: int in range(count):
		await process_frame

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):
		quit(2)
		return
	create_timer(75).timeout.connect(func(): quit(1))
	await frames()
	root.get_node("SettingsManager").reduced_effects = true
	if "--resume" in OS.get_cmdline_user_args():
		await resume_check()
		return
	var journey: Node = root.get_node("JourneyManager")
	journey.select_stage(1, 1)
	journey.begin_selected_stage()
	root.get_node("GameSession").start_new_game()
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "authored stage loaded")
	await create_timer(0.2).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
	paused = false
	var player: Node2D = current_scene.get_node("player_1")
	var manager: Node = player.get_node("WeaponManager")
	var stats: Node = player.get_node("PlayerStats")
	var health: Node = player.get_node("PlayerHealth")
	var spawner: Node = current_scene.get_node("EnemySpawner")
	var wave: Node = current_scene.get_node("WaveManager")
	var checkpoint: Node = current_scene.get_node("CheckPointManager")
	spawner.set_process(false)
	wave.set_process(false)
	player.set_physics_process(false)
	manager.set_process(false)
	spawner.clear_normal_enemies()
	await frames()
	wave.current_wave = 4
	spawner.try_spawn_elite_for_current_wave()
	var first: Node = get_first_node_in_group("enemy")
	check(first != null, "real elite spawned at authored slot")
	first.set_physics_process(false)
	first.die()
	await frames()
	spawner.spawn_timer = 0.37
	check(checkpoint.save_checkpoint(), "checkpoint commits optional cadence")
	var saved: Dictionary = checkpoint.read_checkpoint_result().data
	check(saved.encounter_cadence.spawned == [4] and saved.encounter_cadence.active.is_empty(), "completed elite slot serialized")
	var kills_before: int = spawner.run_kill_count
	spawner.elite_spawned_waves.clear()
	spawner.spawn_timer = 2.0
	check(checkpoint.load_checkpoint(), "actual checkpoint loader accepts new optional state")
	spawner.try_spawn_elite_for_current_wave()
	check(not spawner.has_active_scheduled_elite(), "Continue does not repeat killed elite at the same wave")
	check(is_equal_approx(spawner.spawn_timer, 0.37) and spawner.run_kill_count == kills_before, "remaining cadence and kills restored without new kill events")
	wave.current_wave = 8
	spawner.try_spawn_elite_for_current_wave()
	var active: Node2D
	for enemy: Node in get_nodes_in_group("enemy"):
		if enemy.has_meta("qi_magnet_wave"):
			active = enemy
	active.set_physics_process(false)
	active.current_hp = active.max_hp * 0.4
	active.global_position = player.global_position + Vector2(140, -90)
	var state: Dictionary = spawner.get_encounter_cadence_state()
	check(is_equal_approx(state.active.health_ratio, 0.4), "living elite health ratio captured")
	wave.current_wave = 9
	spawner.restore_encounter_cadence_state(state)
	await frames()
	var restored: Node2D
	for enemy: Node in get_nodes_in_group("enemy"):
		if enemy.has_meta("qi_magnet_wave"):
			restored = enemy
	check(restored != null and int(restored.get_meta("qi_magnet_wave")) == 8, "prior-wave living elite retains original slot")
	restored.set_physics_process(false)
	check(is_equal_approx(restored.current_hp / restored.max_hp, 0.4), "Continue keeps elite damage progress")
	check(spawner.run_kill_count == kills_before, "restoring elite never emits a kill")
	check(restored.global_position.distance_to(player.global_position + Vector2(140, -90)) < 1, "living elite relative position preserved")
	var valid: Dictionary = state.duplicate(true)
	for patch: Dictionary in [{"spawn_timer": NAN}, {"kills": 0.5}, {"spawned": [4, 4]}, {"spawned": [9]}, {"active": {"wave": 8, "type": 1, "health_ratio": 0.4, "x": 0, "y": 0}}]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed.merge(patch, true)
		check(Cadence.clean(malformed, {4: 1, 8: 2}, 8, 10).is_empty(), "malformed optional state rejected " + str(patch.keys()))
	spawner.restore_encounter_cadence_state({})
	check(spawner.elite_spawned_waves.has(4), "legacy magnet proof preserves completed slot")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("encounter_cadence")
	check(not checkpoint.normalize_checkpoint_save_data(legacy).is_empty(), "old checkpoint format remains valid")
	# Preview must agree with real production cooldowns and never change timers.
	var primary: Weapon = manager.get_weapon_by_name("Spirit Sword")
	var timers: Dictionary = manager.attack_timers.duplicate(true)
	var choices: Node = current_scene.get_node("HUD").level_up_panel
	stats.power_multiplier = 1.4
	check(choices.get_upgrade_effect("power").contains("1.40× → 1.50×"), "Power shows actual additive multiplier")
	for script: String in ["jade_binding_chain", "celestial_returning_glaive", "heavenweaver_compass", "phoenix_war_fan", "void_piercer_spear"]:
		var weapon: Weapon = load("res://scripts/weapon/" + script + "_weapon.gd").new()
		weapon.configure_armament(script)
		player.add_child(weapon)
		for factor: float in [1.0, 0.9, 0.4, 0.2]:
			stats.attack_cooldown = factor
			var readout: Dictionary = manager.get_cadence_snapshot(weapon)
			check(is_equal_approx(readout.seconds, manager.get_weapon_cooldown(weapon)) and is_equal_approx(readout.potency, manager.get_cast_tempo_damage_multiplier(weapon)), "snapshot equals runtime " + script + str(factor))
			var next: Dictionary = manager.get_cadence_snapshot(weapon, maxf(factor * 0.9, 0.2))
			stats.upgrade_attack_speed()
			check(is_equal_approx(next.seconds, manager.get_weapon_cooldown(weapon)) and is_equal_approx(next.potency, manager.get_cast_tempo_damage_multiplier(weapon)), "preview equals real applied upgrade " + script + str(factor))
		weapon.free()
	check(manager.attack_timers == timers, "readouts never modify attack timers")
	stats.attack_cooldown = 1.0
	var preview: String = choices.get_upgrade_effect("attack_speed")
	check(preview.contains("1.00s → 0.90s"), "ordinary sword shows cast timing")
	check(primary != null, "starter remains owned")
	var before_exp: float = player.get_experience_multiplier()
	var exp_text: String = choices.get_upgrade_effect("spiritual_insight")
	player.upgrade_spiritual_insight()
	check(exp_text.contains("%.2f× → %.2f×" % [before_exp, player.get_experience_multiplier()]), "insight preview matches actual next EXP multiplier")
	stats.sword_intent_level = 0
	health.current_health = health.max_health
	player.velocity = Vector2.ZERO
	var conditional: float = stats.get_conditional_damage_bonus()
	var base: float = 10.0 * stats.power_multiplier * (root.get_node("EquipmentManager").get_damage_multiplier() + load("res://scripts/data/equipment_set_runtime.gd").get_bonus("damage_bonus"))
	check(is_equal_approx(stats.calculate_damage_result(10.0).damage, base * (1.0 + conditional)), "shared conditional multiplier equals actual noncritical hit")
	spawner.elite_spawned_waves = {4: true, 8: true}
	spawner.spawn_timer = 0.13
	check(checkpoint.save_checkpoint(), "restart fixture committed using real checkpoint writer")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("COMBAT_CLARITY checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

func resume_check() -> void:
	var before: Dictionary = root.get_node("SaveManager").read_save_data("checkpoint").data
	root.get_node("GameSession").continue_saved_game()
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "restart loads authored scene")
	await create_timer(0.2).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
	paused = true
	var spawner: Node = current_scene.get_node("EnemySpawner")
	check(current_scene.get_node("WaveManager").current_wave == 9, "separate process restores wave")
	check(spawner.elite_spawned_waves.has(4) and spawner.elite_spawned_waves.has(8), "separate process retains completed/active slots")
	check(spawner.run_kill_count == int(before.encounter_cadence.kills), "restart never replays kill events")
	var active: Node2D
	for enemy: Node in get_nodes_in_group("enemy"):
		if enemy.has_meta("qi_magnet_wave"):
			active = enemy
	check(active != null and int(active.get_meta("qi_magnet_wave")) == 8, "separate process restores unfinished elite")
	check(active != null and is_equal_approx(active.current_hp / active.max_hp, float(before.encounter_cadence.active.health_ratio)), "separate process preserves health progress")
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("COMBAT_CLARITY_RESTART checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
