extends SceneTree
var checks: int = 0
var failures: int = 0
func check(value: bool, caption: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("RUN_REVIEW_LAYOUT " + caption)
func frames(count: int = 8) -> void:
	for i: int in range(count): await process_frame
func swipe(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT; event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true; event.position = at; root.push_input(event, true)
	await frames(1)
	for i: int in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = at + Vector2(0, -100) * float(i) / 8
		motion.relative = Vector2(0, -12.5); motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true); await frames(1)
	event.pressed = false; event.button_mask = 0; event.position = at + Vector2(0, -100)
	root.push_input(event, true); await frames()
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"): quit(2); return
	create_timer(90).timeout.connect(func(): quit(1))
	await frames()
	root.get_node("GameSession").start_new_game(); root.get_node("JourneyManager").begin_selected_stage()
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "real stage")
	await create_timer(.2).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed(); paused = false
	current_scene.get_node("EnemySpawner").set_process(false)
	current_scene.get_node("EnemySpawner").clear_normal_enemies()
	current_scene.get_node("WaveManager").set_process(false)
	var player: Node = current_scene.get_node("player_1")
	player.set_physics_process(false)
	var weapons: Node = player.get_node("WeaponManager"); weapons.set_process(false)
	weapons.add_fire_orb(); weapons.add_yin_yang_blades(); weapons.add_thunder_talisman()
	var stats: Node = player.get_node("PlayerStats"); stats.power_level = 4; stats.attack_speed_level = 3
	var ledger: Node = weapons.get_node("RunCombatLedger")
	ledger.record("fire_orb", 1.0e12); ledger.record("spirit_sword", 10000); ledger.record("thunder_talisman", 99)
	player.get_node("PlayerHealth").take_damage(10000)
	await frames(15)
	var ui: Node = current_scene.get_node("GameOverUI")
	var ceremony: Node = ui.get_node("ResultCeremony")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for language: String in ["en", "id"]:
		root.get_node("SettingsManager").language = language
		for dimensions: Vector2i in [Vector2i(320,568), Vector2i(390,844), Vector2i(648,1152), Vector2i(896,504)]:
			root.size = dimensions; await frames(15)
			ceremony.capture_defeat_report(); ceremony.fit(); await frames(12)
			var panel: Control = ceremony._panel
			var scroll: ScrollContainer = ceremony._scroll
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).grow(1).encloses(panel.get_global_rect()), "panel inside viewport " + str(dimensions) + language)
			check(scroll.size.y >= 80 and panel.get_global_rect().encloses(scroll.get_global_rect()), "usable scroll reader")
			for action: Button in [ui.retry_button, ui.main_menu_button, ui.revive_button]:
				check(panel.get_global_rect().grow(1).encloses(action.get_global_rect()) and action.size.y >= 44, "fixed action inside panel " + str(action.name))
			ceremony._show_skills = false; ceremony._refresh_report_rows(); scroll.scroll_vertical = 0; await frames()
			for label: Label in ceremony._report_rows.find_children("Report*", "Label", true, false):
				check(label.get_line_count() == 1 and label.get_global_rect().end.x <= scroll.get_global_rect().end.x + 1, "large damage stays within reader")
			var hero: Button = ceremony._body.find_child("ReviewHeroButton", true, false)
			var touch_area: Rect2 = hero.get_global_rect().intersection(scroll.get_global_rect())
			check(touch_area.size.y >= 24, "contextual Hero action initially visible for first button swipe")
			await swipe(touch_area.get_center())
			check(scroll.scroll_vertical > 20 and paused and not current_scene.get_node("GameOverManager").defeat_finalized, "first native swipe scrolls without ending run")
			check(hero.size.y >= 44 and hero.size.x <= scroll.size.x, "Hero action fits reader")
			check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "shared hidden-scrollbar policy")
			var directory: String = OS.get_environment("JADE_COMBAT_RENDER_DIR")
			if not directory.is_empty():
				scroll.scroll_vertical = 0; await frames()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory + "/defeat-" + str(dimensions.x) + "-" + language + ".png")
			ceremony._skills_tab.pressed.emit(); await frames()
			check(ceremony._show_skills and ceremony._report_rows.get_child_count() >= 6, "acquired skills tab usable")
	paused = false
	var world: Node = current_scene; current_scene = null; world.queue_free(); await frames()
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("RUN_REVIEW_LAYOUT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
