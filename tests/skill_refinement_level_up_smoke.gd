extends SceneTree

const Choices = preload("res://scripts/data/weighted_upgrade_choices.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SKILL_REFINEMENT_FAIL: " + message)

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("jade_onboarding_qa"):
		push_error("Use a private jade_onboarding_qa user directory before startup.")
		quit(2)
		return
	var rng := RandomNumberGenerator.new()
	var uniform_rng := RandomNumberGenerator.new()
	rng.seed = 13102026
	uniform_rng.seed = 13102026
	var candidates: Array[String] = []
	for i: int in range(15):
		candidates.append("art_%d" % i)
	var weighted_hits: int = 0
	var uniform_hits: int = 0
	for i: int in range(20000):
		var draw := Choices.pick(candidates, {"art_0": 2.5}, 3, rng)
		if "art_0" in draw:
			weighted_hits += 1
		if "art_0" in Choices.pick(candidates, {}, 3, uniform_rng):
			uniform_hits += 1
		if i < 50:
			check(draw.size() == 3 and draw[0] != draw[1] and draw[0] != draw[2] and draw[1] != draw[2], "three unique choices")
	var weighted_rate: float = float(weighted_hits) / 20000.0
	check(absf(weighted_rate - 0.411062797) < 0.02, "observed weighted probability matches theory")
	check(absf(float(uniform_hits) / 20000.0 - 0.2) < 0.02, "uniform baseline")
	check(candidates.size() == 15 and candidates[0] == "art_0", "input unchanged")
	var empty: Array[String] = []
	check(Choices.pick(empty, {}, 3, rng).is_empty(), "empty candidates")
	check(Choices.pick(candidates, {}, 0, rng).is_empty(), "zero choices")
	var repeats: Array[String] = ["a", "a", "b", ""]
	check(Choices.pick(repeats, {"a": -1.0, "b": NAN}, 10, rng).size() == 2, "deduplication and invalid weight fallback")
	await create_timer(0.5).timeout
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "load production run")
	await create_timer(0.5).timeout
	var scene: Node = current_scene
	var actor: Node = scene.get_node("player_1")
	actor.set_physics_process(false)
	scene.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
	actor.get_node("WeaponManager").process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial: Node = scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	tutorial._on_skip_pressed()
	paused = false
	var health: Node = actor.get_node("PlayerHealth")
	check(is_equal_approx(health.max_health, 100.0), "production base HP override")
	var panel: Control = scene.get_node("HUD/LevelUpPanel")
	var settings: Node = root.get_node("SettingsManager")
	var previous_language: String = settings.language
	settings.language = "en"
	actor.level = 1
	actor.experience = 0
	actor.experience_to_next_level = 10
	actor.add_experience(10)
	check(actor.level == 2, "actual EXP event increases run level")
	check(panel.visible and paused, "single existing choice panel owns pause")
	check(panel.breakthrough_level_label.text == "LV. 1 → 2", "level transition")
	check(panel.find_child("Eyebrow", true, false).text == "CONGRATULATIONS!", "English congratulation")
	for i: int in range(60):
		panel.generate_upgrades()
		for id: String in panel.current_upgrades:
			check(panel.is_upgrade_available(id), "choice obeys gameplay caps and prerequisites")
	settings.language = "id"
	panel._update_level_up_congratulation()
	check(panel.find_child("Eyebrow", true, false).text == "SELAMAT! LEVEL NAIK", "Indonesian congratulation")
	settings.language = previous_language
	panel.hide()
	paused = false
	for chapter: String in ["one", "two", "three", "four", "five"]:
		var catalog: Script = load("res://scripts/data/chapter_%s_catalog.gd" % chapter)
		for stage: int in range(1, 6):
			var packed: PackedScene = load(catalog.get_stage(stage).scene_path)
			var instance: Node = packed.instantiate()
			check(is_equal_approx(instance.get_node("player_1/PlayerHealth").max_health, 100.0), "authored stage base HP")
			instance.free()
	print("SKILL_REFINEMENT_SMOKE checks=%d failures=%d owned_rate=%.4f uniform_rate=%.4f" % [checks, failures, weighted_rate, float(uniform_hits) / 20000.0])
	quit(0 if failures == 0 else 1)
