extends SceneTree
var checks: int = 0
var failures: int = 0

func check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("COMBAT_STATS_LAYOUT " + caption)

func frames(count: int = 8) -> void:
	for i: int in range(count):
		await process_frame

func swipe(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	event.position = at
	root.push_input(event, true)
	await frames(1)
	for i: int in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = at + Vector2(0, -110) * float(i) / 8
		motion.relative = Vector2(0, -110.0 / 8)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion, true)
		await frames(1)
	event.pressed = false
	event.button_mask = 0
	event.position = at + Vector2(0, -110)
	root.push_input(event, true)
	await frames()

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):
		quit(2)
		return
	create_timer(70).timeout.connect(func(): quit(1))
	await frames()
	root.get_node("GameSession").start_new_game()
	root.get_node("JourneyManager").begin_selected_stage()
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "real stage loaded")
	await create_timer(0.2).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
	paused = false
	var player: Node = current_scene.get_node("player_1")
	player.set_physics_process(false)
	var manager: Node = player.get_node("WeaponManager")
	manager.set_process(false)
	manager.add_fire_orb()
	manager.add_yin_yang_blades()
	var stats: Node = player.get_node("PlayerStats")
	var mastery: Node = root.get_node("CultivationMasteryManager")
	var journey: Node = root.get_node("JourneyManager")
	mastery.state.run = {"id": journey.m7d_run_id, "choices": {"vitality": "", "sword_power": "focus", "swift_qi": ""}}
	var prior_mastery: Dictionary = mastery.state.duplicate(true)
	var health: Node = player.get_node("PlayerHealth")
	health.current_health = health.max_health
	var overlay: Control = current_scene.get_node("HUD/ScreenRoot/InRunStatsOverlay")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for language: String in ["en", "id"]:
		root.get_node("SettingsManager").language = language
		for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(648, 1152)]:
			root.size = dimensions
			await frames(15)
			overlay.open_snapshot()
			await frames(15)
			var panel: Control = overlay.get_node("SafeMargin/Center/Panel")
			var scroll: ScrollContainer = overlay.find_child("CombatStatsScroll", true, false)
			scroll.scroll_vertical = 0
			await frames(3)
			check(Rect2(Vector2.ZERO, Vector2(dimensions)).grow(1).encloses(panel.get_global_rect()), "panel fits phone " + str(dimensions) + language)
			check(panel.get_global_rect().grow(1).encloses(scroll.get_global_rect()) and scroll.size.y >= 80, "body has usable scroll bounds")
			var close: Button = overlay.find_child("CloseCombatStats", true, false)
			check(panel.get_global_rect().encloses(close.get_global_rect()) and close.size.y >= 44, "close action stays visible and touchable")
			check(overlay._rows.conditional.text == "+5.0%", "high-health mastery appears in snapshot")
			check(overlay._rows.weapon_spirit_sword.text.contains("CAST"), "actual cast interval displayed")
			check(mastery.state == prior_mastery, "opening readout never commits or changes mastery")
			var note: Control = overlay.find_child("CombatStatsFootnote", true, false)
			check(panel.get_global_rect().grow(1).encloses(note.get_global_rect()), "legend stays inside frame")
			var old_scroll: int = scroll.scroll_vertical
			await swipe(scroll.get_global_rect().get_center() + Vector2(0, 40))
			check(scroll.scroll_vertical > old_scroll + 20 and overlay.visible and paused, "first native swipe scrolls without closing/unpausing")
			check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "scroll axis works without chrome")
			var render_path: String = OS.get_environment("JADE_COMBAT_RENDER_DIR")
			if not render_path.is_empty():
				scroll.scroll_vertical = 0
				await frames()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(render_path + "/combat-stats-" + str(dimensions.x) + "-" + language + ".png")
			var transition: Node = root.get_node("SceneTransitionManager")
			check(transition.back_handler == Callable(overlay, "close_snapshot"), "system back points to open stats")
			transition.back_handler.call()
			check(not paused and not overlay.visible, "system back closes and resumes combat")
	# A preview before first hit must not create frozen mastery data.
	mastery.state.run = {}
	var before: Dictionary = mastery.state.duplicate(true)
	var unused: float = stats.get_conditional_damage_bonus(true)
	check(mastery.state == before, "read-only preview does not freeze choices before first hit")
	check(is_finite(unused), "read-only preview returns a finite multiplier")
	paused = false
	var world: Node = current_scene
	current_scene = null
	world.queue_free()
	await frames(8)
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("COMBAT_STATS_LAYOUT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
