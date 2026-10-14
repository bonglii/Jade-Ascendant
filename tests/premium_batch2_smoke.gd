extends SceneTree
const Catalog = preload("res://scripts/data/boss_premium_catalog.gd")
var checks: int = 0
var failures: int = 0
var settings: Variant
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BATCH2_FAIL " + tag)
func run() -> void:
	if not OS.get_user_data_dir().replace("\\","/").contains("jade_batch2_qa"):
		push_error("Use isolated user:// before startup")
		quit(2)
		return
	await create_timer(0.5).timeout
	settings = root.get_node("SettingsManager")
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK,"load real first trial")
	await create_timer(0.4).timeout
	var scene: Node = current_scene
	var player: CharacterBody2D = scene.get_node("player_1")
	player.set_physics_process(false)
	player.get_node("WeaponManager").process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial: Control = scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
	check(tutorial.tutorial_active and tutorial.prompt_waiting,"first tutorial active")
	check(paused and tutorial.tutorial_owns_pause,"tutorial owns prompt pause")
	for step: int in range(5):
		tutorial._release_tutorial_pause()
		tutorial._set_step(step)
		await process_frame
		await process_frame
		check(tutorial._tutorial_art.texture != null,"illustration ready")
		check(tutorial._step_pips.size() == 5,"five progress steps")
		check(tutorial.tutorial_panel.get_rect().position.y >= 0,"card above bottom within screen")
		check(tutorial.tutorial_panel.get_rect().end.y <= tutorial.size.y+0.1,"card bottom fits")
		check(not tutorial.guidance_root.visible,"prompt copy unobstructed")
	tutorial._release_tutorial_pause()
	tutorial._set_step(0)
	tutorial._on_continue_pressed()
	player.position += Vector2(73,0)
	tutorial._process(1.3)
	check(tutorial.current_step == 1,"move advances from actual distance")
	tutorial._on_continue_pressed()
	tutorial.observed_kills = 1
	tutorial._process(1.3)
	check(tutorial.current_step == 2,"kill objective advances")
	tutorial._on_continue_pressed()
	player.experience = 1
	tutorial._process(1.3)
	check(tutorial.current_step == 3,"experience objective advances")
	tutorial._on_continue_pressed()
	tutorial.level_up_panel.show()
	tutorial._process(0.1)
	tutorial.level_up_panel.hide()
	player.level = 2
	tutorial._process(1.3)
	check(tutorial.current_step == 4,"actual breakthrough closes before final lesson")
	tutorial._on_continue_pressed()
	check(not tutorial.tutorial_active and not paused,"tutorial completes and releases own pause")
	check(tutorial._is_tutorial_completed(),"completion persists")
	check(not tutorial._premium_dim.visible and not tutorial._objective_chip.visible,"completion clears tutorial widgets")
	tutorial.tutorial_active = true
	tutorial.prompt_waiting = true
	tutorial.tutorial_owns_pause = false
	paused = true
	tutorial._on_skip_pressed()
	check(paused,"skip preserves another owner's pause")
	paused = false
	var hud: Node = scene.get_node("HUD")
	hud._on_pause_pressed()
	check(hud._review_guide_button.visible,"completed first trial exposes guide review")
	hud._review_guide_button.pressed.emit()
	check(tutorial._manual_preview and tutorial.prompt_waiting and paused,"review guide owns a safe modal pause")
	var preview_level: int = player.level
	var preview_exp: int = player.experience
	for page: int in range(5): tutorial._on_continue_pressed()
	check(not tutorial.tutorial_active and not paused,"manual review completes")
	check(player.level == preview_level and player.experience == preview_exp and tutorial._is_tutorial_completed(),"review preserves run progress and completed state")

	var body: Node = player.get_node("PremiumBodyPresentation")
	var collider: CollisionShape2D = player.get_node("CollisionShape2D")
	var collider_transform: Transform2D = collider.transform
	var shape_radius: float = collider.shape.radius
	var shape_height: float = collider.shape.height
	for i: int in range(100):
		player.velocity = Vector2(180,0)
		player.position.x += 1
		body._on_cast("Spirit Sword",Vector2.RIGHT)
		body._process(0.02)
	check(body.ghosts.size() == 4 and body.steps.size() == 6,"fixed player effect storage")
	check(collider.transform == collider_transform and collider.shape.radius == shape_radius and collider.shape.height == shape_height,"player collision unchanged by motion/cast")
	settings.reduced_effects = true
	body._process(0.1)
	for ghost: Sprite2D in body.ghosts: check(not ghost.visible,"reduced effects suppress ghost trail")
	check(player.get_node("AnimatedSprite2D").material is ShaderMaterial,"player shader installed")
	settings.reduced_effects = false
	player.get_node("PlayerHealth").take_damage(1.0)
	check(body.hurt_left > 0.0,"actual damage triggers visual hurt feedback")
	var boss_scene: PackedScene = load("res://scenes/enemy/boss_1.tscn")
	var roster: int = 0
	for chapter: int in range(Catalog.Chapters.size()):
		var stages: Dictionary = Catalog.Chapters[chapter].STAGES
		for stage: int in stages:
			var profile: Dictionary = stages[stage]
			var boss: Node2D = boss_scene.instantiate()
			if chapter >= 3:
				boss.set_script(load("res://scripts/enemy/realm_boss.gd"))
			boss.configure_encounter(profile)
			boss.position = player.position+Vector2(400,-200)
			scene.add_child(boss)
			boss.set_physics_process(false)
			var premium: Node = boss.get_node_or_null("PremiumBossPresentation")
			check(premium != null,"boss premium presentation")
			check(premium.profile.chapter == chapter+1 and premium.profile.stage == stage,"unique encounter profile")
			check(boss._get_attack_presentation_theme() == ["jade_valley","crimson_moon","nine_heavens","frostveil","solar_nirvana"][chapter],"chapter attack identity")
			for key: String in profile.get("boss_stats",{}):
				check(boss.get(key) == profile.boss_stats[key],"original boss stat " + key)
			var boss_collider: CollisionShape2D = boss.get_node("CollisionShape2D")
			var transform: Transform2D = boss_collider.transform
			var radius: float = boss_collider.shape.radius
			var height: float = boss_collider.shape.height
			var hp: float = float(boss.current_hp)
			boss.enter_phase_two()
			boss._play_action_animation("lightning",0.5)
			premium._process(0.05)
			settings.reduced_effects = true
			premium._process(0.05)
			settings.reduced_effects = false
			check(boss_collider.transform == transform and boss_collider.shape.radius == radius and boss_collider.shape.height == height,"boss phase/cast collider stable")
			check(boss.current_hp == hp and boss.current_phase == 2,"polish does not change health")
			check(boss.get_node("AnimatedSprite2D").material is ShaderMaterial,"boss shader ready")
			scene.get_node("HUD").setup_boss_health_bar(boss)
			check(scene.get_node("HUD").boss_hp_bar.value == hp,"boss HUD actual HP")
			boss.die()
			check(boss.is_dead and not boss.is_in_group("enemy"),"boss death authority removes target immediately")
			check(scene.get_node_or_null("PremiumBossDefeatRemnant") != null,"boss defeat remnant is visual only")
			boss.free()
			for remnant: Node in scene.find_children("PremiumBossDefeatRemnant*","Node2D",true,false): remnant.free()
			roster += 1
	check(roster == 26,"all26 boss encounters")
	check(Catalog.get_profile("unsupported boss").is_empty(),"unsupported realms untouched")

	var fx_script: Variant = load("res://scripts/enemy/hostile_attack_polish.gd")
	var projectiles: Array[Node2D] = []
	for i: int in range(70):
		var projectile: Node2D = load("res://scenes/enemy/boss_projectile.tscn").instantiate()
		projectile.presentation_theme = "crimson_moon"
		projectile.position = player.position+Vector2(800,800)
		scene.add_child(projectile)
		projectile.set_physics_process(false)
		check(projectile.speed == 250.0 and projectile.damage == 2.0 and projectile.lifetime == 5.0,"projectile balance unchanged")
		projectiles.append(projectile)
	check(fx_script.active_instances <= 64,"hostile fx cap")
	for projectile: Node2D in projectiles: projectile.free()
	check(fx_script.active_instances == 0,"hostile fx cleanup")
	for reduced: bool in [false,true]:
		settings.reduced_effects = reduced
		for kind: String in ["boss_lightning_strike","boss_qi_shockwave"]:
			var attack: Node2D = load("res://scenes/enemy/"+kind+".tscn").instantiate()
			attack.position = player.position+Vector2(800,800)
			attack.presentation_theme = "crimson_moon"
			attack.telegraph_duration = 4.0
			scene.add_child(attack)
			var expected: float = float(attack.strike_radius if kind == "boss_lightning_strike" else attack.shockwave_radius)
			check(is_equal_approx(attack.get_node("CollisionShape2D").shape.radius,expected),"exact telegraph collider radius")
			check(not attack.has_impacted,"polish does not fire early")
			attack.impact()
			check(attack.has_impacted,"original impact occurs")
			attack.free()
	settings.reduced_effects = false
	var unknown: Node2D = load("res://scenes/enemy/boss_projectile.tscn").instantiate()
	unknown.position = player.position+Vector2(800,800)
	scene.add_child(unknown)
	unknown.set_physics_process(false)
	check(fx_script.active_instances == 0,"unthemed attacks outside this batch retain original visuals")
	unknown.free()
	var defeat_script: Variant = load("res://scripts/enemy/boss_defeat_presentation.gd")
	var remnant: Node2D = defeat_script.new()
	scene.add_child(remnant)
	remnant.setup(player.get_node("AnimatedSprite2D"),Color(0.4,0.9,0.8))
	settings.reduced_effects = true
	var pose: Vector2 = remnant.ghost.position
	remnant._process(0.1)
	check(remnant.ghost.position == pose,"reduced defeat suppresses upward motion")
	remnant.free()
	settings.reduced_effects = false
	check(fx_script.active_instances == 0,"all attack effects released")
	await create_timer(4.1).timeout
	current_scene.queue_free()
	current_scene = null
	await process_frame
	await process_frame
	print("PREMIUM_BATCH2_QA checks=",checks," failures=",failures)
	quit(1 if failures else 0)
