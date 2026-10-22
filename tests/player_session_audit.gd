extends SceneTree
## Runs production scenes with input actions and real skill buttons. No health,
## enemy, damage, clock, reward or weapon override after initial fixture setup.
var actor: Node2D
var health: Node
var manager: Node
var world: Node
var choices: Node
var tutorial: Node
var case_id: String
var decisions: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var outcome: String = ""
var reaction: float = 0.0
var sample_clock: float = 0.0
var wall_started: int = 0
var last_direction: Vector2 = Vector2.RIGHT
var tutorial_prompts: int = 0
var pilot_node: Node
var initial: Dictionary

class Pilot extends Node:
	var audit: SceneTree
	func _physics_process(delta: float) -> void:
		audit.tick(delta)

func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):
		quit(2)
		return
	await process_frame
	case_id = OS.get_environment("JADE_PLAY_CASE")
	if case_id.is_empty(): case_id = "fresh_sword"
	var cases: Dictionary = {
		"fresh_sword": {"chapter": 1, "stage": 1, "cultivation": 0, "armament": "", "set": "", "stars": 1, "level": 1},
		"fresh_defense": {"chapter": 1, "stage": 1, "cultivation": 0, "armament": "", "set": "", "stars": 1, "level": 1},
		"mid_chain": {"chapter": 2, "stage": 1, "cultivation": 5, "armament": "jade_binding_chain", "set": "moon_seal", "stars": 1, "level": 10},
		"late_glaive": {"chapter": 5, "stage": 5, "cultivation": 10, "armament": "celestial_returning_glaive", "set": "nine_heavens", "stars": 3, "level": 30}
	}
	if not cases.has(case_id): quit(2); return
	initial = cases[case_id]
	seed(22102026)
	root.get_node("SettingsManager").reduced_effects = true
	var progress: Node = root.get_node("ProgressionManager")
	for path: String in ["vitality", "sword_power", "swift_qi"]:
		progress.set(path + "_level", int(initial.cultivation))
	var equipment: Node = root.get_node("EquipmentManager")
	var inventory: Node = root.get_node("InventoryManager")
	for slot: String in equipment.get_slot_ids(): equipment.equipped_item_ids[slot] = ""
	var ids: Array[String] = []
	if not str(initial.set).is_empty(): ids = load("res://scripts/data/equipment_set_catalog.gd").get_piece_ids(str(initial.set))
	if not str(initial.armament).is_empty(): ids.append(str(initial.armament))
	for id: String in ids:
		inventory.item_counts[id] = 1
		equipment.ascension_stars[id] = int(initial.stars)
		equipment.equipped_item_ids[str(equipment.get_item_data(id).slot)] = id
		if id == initial.armament: equipment.weapon_levels[id] = int(initial.level)
	root.get_node("GameSession").start_new_game()
	var journey: Node = root.get_node("JourneyManager")
	journey.restore_active_run(int(initial.chapter), int(initial.stage))
	var data: Dictionary = journey.get_stage_data(int(initial.chapter), int(initial.stage))
	if change_scene_to_file(str(data.scene_path)) != OK: quit(1); return
	await process_frame
	await process_frame
	world = current_scene
	actor = world.get_node("player_1")
	health = actor.get_node("PlayerHealth")
	manager = actor.get_node("WeaponManager")
	choices = world.get_node("HUD").level_up_panel
	choices._choice_rng.seed = 22102026
	tutorial = world.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	var pilot := Pilot.new()
	pilot_node = pilot
	pilot.audit = self
	pilot.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(pilot)
	wall_started = Time.get_ticks_msec()
	print("PLAYER_SESSION_STARTED case=", case_id, " fixture=", JSON.stringify(initial))

func tick(delta: float) -> void:
	if not outcome.is_empty() or world == null: return
	if bool(world.get_node("VictoryManager").victory_processed):
		outcome = "victory"; finish.call_deferred(); return
	if bool(world.get_node("GameOverManager").game_over_triggered):
		outcome = "defeat"; finish.call_deferred(); return
	var clock: float = float(world.get_node("SurvivalManager").survival_time)
	if clock > 540.0 or Time.get_ticks_msec() - wall_started > 180000:
		outcome = "timeout"; finish.call_deferred(); return
	reaction -= delta
	if reaction > 0.0: return
	reaction = 0.18
	if bool(tutorial.tutorial_active) and bool(tutorial.prompt_waiting):
		tutorial.continue_button.pressed.emit()
		tutorial_prompts += 1
		return
	if choices.visible:
		if choices.selection_locked: return
		var priority: Array[String] = ["spirit_sword", "fire_orb", "attack_speed", "power", "heavenly_sword_rain", "thunder_talisman", "sword_intent", "iron_body", "body_refinement", "qi_shield", "yin_yang_blades", "blood_qi", "spiritual_insight", "movement_speed"]
		if case_id == "fresh_defense": priority = ["qi_shield", "body_refinement", "iron_body", "blood_qi", "spirit_sword", "fire_orb", "attack_speed", "power", "thunder_talisman", "yin_yang_blades", "spiritual_insight", "movement_speed"]
		var index: int = 0
		var best: int = 1000
		for i: int in range(choices.current_upgrades.size()):
			var score: int = priority.find(str(choices.current_upgrades[i]))
			if score < 0: score = 500
			if score < best: best = score; index = i
		decisions.append({"time": clock, "level": actor.level, "offered": choices.current_upgrades.duplicate(), "chosen": choices.current_upgrades[index]})
		choices.upgrade_buttons[index].pressed.emit()
		return
	if paused: return
	sample_clock += 0.18
	if sample_clock >= 5:
		sample_clock = 0
		samples.append({"seconds": clock, "wave": world.get_node("WaveManager").current_wave, "hp": health.current_health, "max_hp": health.max_health, "level": actor.level, "alive": get_nodes_in_group("enemy").size(), "position": [actor.position.x, actor.position.y], "velocity": [actor.velocity.x, actor.velocity.y], "input": [Input.get_action_strength("ui_left"), Input.get_action_strength("ui_right"), Input.get_action_strength("ui_up"), Input.get_action_strength("ui_down")], "damage": manager.get_node("RunCombatLedger").totals.duplicate()})
	steer()

func steer() -> void:
	var enemies: Array[Node] = get_nodes_in_group("enemy")
	var desired: Vector2 = Vector2.from_angle(float(actor.level) * 0.4)
	var boss: Node2D = get_first_node_in_group("boss") as Node2D
	if is_instance_valid(boss):
		var offset: Vector2 = boss.global_position - actor.global_position
		desired = offset.normalized() * clampf((offset.length() - 170) / 100.0, -1, 1) + offset.orthogonal().normalized() * 0.7
	else:
		var target: Node2D
		var nearest: float = 600.0
		for pickup: Node2D in get_nodes_in_group("qi_pickup"):
			if pickup.is_queued_for_deletion(): continue
			var distance: float = pickup.global_position.distance_to(actor.global_position)
			if distance < nearest: nearest = distance; target = pickup
		if is_instance_valid(target): desired = actor.global_position.direction_to(target.global_position)
		elif not enemies.is_empty():
			var approach: Vector2 = (enemies[0] as Node2D).global_position - actor.global_position
			desired = approach.normalized() if approach.length() > 220 else approach.orthogonal().normalized()
	var best: Vector2 = Vector2.ZERO
	var best_score: float = -INF
	for i: int in range(16):
		var direction: Vector2 = Vector2.from_angle(TAU * i / 16)
		var future: Vector2 = actor.global_position + direction * actor.get_effective_movement_speed() * 0.30
		var score: float = direction.dot(desired) * 5.0 + direction.dot(last_direction) * 0.4
		for enemy: Node2D in enemies:
			if enemy.is_queued_for_deletion() or bool(enemy.get("is_dead")): continue
			var distance: float = future.distance_to(enemy.global_position)
			if distance < 110: score -= pow((110 - distance) / 13.0, 2)
		var arena: Node2D = world.get_node_or_null("BossCombatArena") as Node2D
		if arena != null and future.distance_to(arena.global_position) > 365: score -= 15
		if score > best_score: best_score = score; best = direction
	last_direction = best
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]: Input.action_release(action)
	if best.x < -0.05: Input.action_press("ui_left", -best.x)
	if best.x > 0.05: Input.action_press("ui_right", best.x)
	if best.y < -0.05: Input.action_press("ui_up", -best.y)
	if best.y > 0.05: Input.action_press("ui_down", best.y)

func finish() -> void:
	for action: String in ["ui_left", "ui_right", "ui_up", "ui_down"]: Input.action_release(action)
	# Final attack/death signal must finish before reading its real ledger.
	await process_frame
	var ledger: Node = manager.get_node("RunCombatLedger")
	var boss: Node = get_first_node_in_group("boss")
	var result: Dictionary = {"case": case_id, "initial_fixture": initial, "outcome": outcome, "game_seconds": world.get_node("SurvivalManager").survival_time, "wall_seconds": float(Time.get_ticks_msec() - wall_started) / 1000, "wave": world.get_node("WaveManager").current_wave, "level": actor.level, "hp": health.current_health, "max_hp": health.max_health, "hits": ledger.hp_hits, "deaths": ledger.deaths, "damage": ledger.damage_rows(), "skills": ledger.skills(), "choices": decisions, "samples": samples, "tutorial_prompts": tutorial_prompts, "boss_remaining_hp": boss.get("current_hp") if is_instance_valid(boss) else 0, "scope": "Input pilot, actual production combat; fixed-fps acceleration if supplied by launcher, not human or phone performance evidence. No revive/purchase/reward cheat."}
	var directory: String = OS.get_environment("JADE_PLAY_OUTPUT")
	if not directory.is_empty():
		var file: FileAccess = FileAccess.open(directory + "/" + case_id + ".json", FileAccess.WRITE)
		if file != null: file.store_string(JSON.stringify(result, "\t")); file.close()
	print("PLAYER_SESSION_COMPLETE ", case_id, " outcome=", outcome, " seconds=", result.game_seconds, " level=", actor.level, " hits=", ledger.hp_hits)
	paused = false
	current_scene = null
	world.queue_free()
	world = null
	actor = null
	health = null
	manager = null
	choices = null
	tutorial = null
	pilot_node.audit = null
	pilot_node.queue_free()
	for i: int in range(8): await process_frame
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	OS.delay_msec(150) # Let the Dummy audio thread drain at accelerated fixed FPS.
	for i: int in range(4): await process_frame
	quit.call_deferred(0 if outcome != "timeout" else 1)
