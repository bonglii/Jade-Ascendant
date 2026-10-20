extends SceneTree
var failures: int = 0
var checks: int = 0
var output: String = "user://premium_render"
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("PREMIUM_RENDER " + message)
func frames(count: int = 4) -> void:
	for index: int in count: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_premium_qa"): quit(2); return
	if OS.get_environment("JADE_RENDER_OUTPUT") != "": output = OS.get_environment("JADE_RENDER_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	await frames(10)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(648,1152)
	var prewarm: Node = root.get_node_or_null("MenuResourcePrewarm")
	if prewarm != null: prewarm.queue_free()
	var guide: Node = root.get_node("RefineOnboarding"); guide.completed = true; guide.set_process(false)
	var journey: Node = root.get_node("JourneyManager")
	journey.select_stage(1,1); root.get_node("GameSession").start_new_game()
	change_scene_to_file(journey.begin_selected_stage())
	await frames(20)
	var scene: Node = current_scene
	var tutorial: Node = scene.find_child("TutorialOverlay",true,false)
	if tutorial != null: tutorial._complete_tutorial(true)
	paused = false
	var hud: Node = scene.get_node("HUD")
	var safe: Control = hud.get_node("ScreenRoot/HUDSafeArea")
	var polish: Node = scene.find_child("HUDCombatPolish",true,false)
	check(polish != null,"actual production combat extension exists")
	scene.get_node("EnemySpawner").set_process(false); scene.get_node("WaveManager").set_process(false)
	for enemy: Node in get_nodes_in_group("enemy"): enemy.process_mode = Node.PROCESS_MODE_DISABLED
	scene.get_node("player_1").process_mode = Node.PROCESS_MODE_DISABLED
	await shot("hud-before")
	root.get_node("SettingsManager").reduced_effects = false
	polish._show_boss_warning()
	for index: int in 16:
		await shot("warning-frame-%02d" % index)
		check(polish._warning_panel.size.y < safe.size.y*0.45,"warning has bounded first-frame height %d" % index)
		check(polish._warning_panel.position.x >= 0,"warning is inside safe area %d" % index)
	polish._warning_tween.kill(); polish._hide_boss_warning()
	scene.get_node("EnemySpawner").spawn_boss()
	for index: int in 16:
		await shot("arrival-frame-%02d" % index)
		check(hud.boss_panel.size.y < 220,"boss bar bounded on first frame %d" % index)
		check(hud.boss_panel.get_rect().end.x <= safe.size.x + 1,"boss bar fits width %d" % index)
	await create_timer(0.4).timeout
	await shot("boss-arrival")
	var geometry: Dictionary = {}
	for node: Control in hud.boss_panel.find_children("*","Control",true,false): geometry[str(hud.boss_panel.get_path_to(node))] = {"rect":str(node.get_rect()),"minimum":str(node.get_combined_minimum_size()),"visible":node.visible}
	geometry["panel"] = {"rect":str(hud.boss_panel.get_rect()),"minimum":str(hud.boss_panel.get_combined_minimum_size())}
	var geometry_file := FileAccess.open(output+"/boss-geometry.json",FileAccess.WRITE)
	geometry_file.store_string(JSON.stringify(geometry,"  ")); geometry_file.close()
	for dimensions: Vector2i in [Vector2i(360,640),Vector2i(390,844),Vector2i(648,1152)]:
		root.size = dimensions
		await frames(5)
		preload("res://scripts/ui/combat_chrome.gd").apply(hud)
		hud._show_encounter_banner("PHASE 2 · GUARDIAN AWAKENS",Color.GOLD)
		await frames(10)
		check(hud._encounter_banner.get_rect().end.x <= safe.size.x+1,"notice fits "+str(dimensions))
		check(hud._encounter_banner.size.y < safe.size.y*0.45,"notice bounded "+str(dimensions))
		await shot("boss-%dx%d" % [dimensions.x,dimensions.y])
		hud._encounter_banner_tween.kill(); hud._hide_encounter_banner()
	root.size = Vector2i(648,1152); await frames(5)
	hud._hide_boss_panel()
	paused = true
	var victory: Node = scene.get_node("VictoryUI")
	victory.victory_reward_entries.assign([{"source_type":"stage_clear","source_id":"1_1_first_clear","reward_data":{"spirit_stone":240,"hero_exp":50,"items":{}}}])
	victory.show_victory(); await create_timer(1.0).timeout
	await shot("victory")
	check(victory.get_node("ColorRect/AscendantResultBackdrop").visible,"victory scenic background is visible")
	victory.hide()
	var defeat: Node = scene.get_node("GameOverUI")
	defeat.show_game_over(); await create_timer(1.0).timeout
	await shot("defeat")
	check(defeat.get_node("ColorRect/AscendantResultBackdrop").visible,"defeat scenic background is visible")
	defeat.hide()
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	paused = false
	current_scene.queue_free(); current_scene = null
	await frames(8)
	print("PREMIUM_COMBAT_RENDER checks=",checks," failures=",failures)
	quit(1 if failures else 0)
