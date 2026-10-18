extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("TRIALS_ASCENDANT " + message)
func frames(count: int = 8) -> void:
	for index: int in range(count):
		await process_frame
func capture(file: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var folder: String = OS.get_environment("JADE_TRIALS_RENDER_DIR")
	if folder.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder + "/" + file)
func _run() -> void:
	if not OS.get_user_data_dir().contains("jade_warning_cleanup_qa"):
		quit(2)
		return
	create_timer(85).timeout.connect(func(): push_error("TRIALS_WATCHDOG"); quit(3))
	await frames(3)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(648, 1152)
	var prewarm: Node = root.get_node_or_null("MenuResourcePrewarm")
	if prewarm != null:
		prewarm.queue_free()
	var guide: Node = root.get_node("RefineOnboarding")
	guide.completed = true
	guide.set_process(false)
	var daily: Node = root.get_node("DailyQuestManager")
	var achievements: Node = root.get_node("AchievementManager")
	var progression: Node = root.get_node("ProgressionManager")
	daily.claimed_quest_ids.clear()
	daily.completed_quest_ids.clear()
	for record_id: String in daily.get_daily_quest_ids():
		daily.quest_progress[record_id] = 0
	var first_id: String = daily.get_daily_quest_ids()[0]
	daily.set_progress_at_least(first_id, daily.get_target(first_id))
	var mobile: Node = load("res://tests/fixtures/trials_touch_presenter.gd").new()
	root.add_child(mobile)
	mobile.set_process(false)
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = Vector2(30, 30)
	mobile._on_trials_scroll_gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(30, 70)
	mobile._on_trials_scroll_gui_input(drag)
	down.pressed = false
	mobile._on_trials_scroll_gui_input(down)
	var blocked_balance: int = progression.spirit_stone
	mobile._on_single_claim(first_id)
	check(not daily.is_claimed(first_id) and progression.spirit_stone == blocked_balance, "swipe release cannot claim")
	mobile.queue_free()
	change_scene_to_file("res://scenes/ui/daily_quest_screen.tscn")
	await frames(30)
	var presenter: Node = current_scene.get_node("TrialsProductionPresenter")
	check(presenter.get_script().resource_path.ends_with("trials_ascendant_presenter.gd"), "approved presenter installed")
	check(presenter.daily_card_nodes.size() == daily.get_daily_quest_ids().size(), "all actual daily records")
	check(presenter.claim_all_button.visible and not presenter.claim_all_button.disabled, "claim all available")
	var initial_card: PanelContainer = presenter.daily_card_nodes[first_id]
	for viewport: Vector2i in [Vector2i(648, 1152), Vector2i(390, 844), Vector2i(320, 568), Vector2i(896, 504)]:
		root.size = viewport
		await frames(10)
		var actions: Node = presenter.daily_card_nodes[first_id].find_child("RecordActions", true, false)
		var action_button: Button = actions.get_child(1) as Button
		var guard: Node = root.get_node("MobileTouchPresentationGuard")
		var connections: int = 0
		for connection: Dictionary in action_button.get_signal_connection_list("button_down"):
			if connection.callable.get_object() == guard:
				connections += 1
		check(connections == 1, "responsive reparent keeps a single touch callback")
		check(presenter.daily_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "hidden scrollbar")
		check(presenter.claim_all_button.get_global_rect().end.y <= viewport.y - 90, "fixed footer clears navigation " + str(viewport))
		check(presenter.daily_scroll.size.y >= 40, "usable scrolling region " + str(viewport))
		check(presenter.daily_tab.get_global_rect().position.x >= 0 and presenter.achievement_tab.get_global_rect().end.x <= viewport.x, "tabs contained " + str(viewport))
		await capture("daily-%dx%d.png" % [viewport.x, viewport.y])
	root.size = Vector2i(648, 1152)
	var before: int = progression.spirit_stone
	var reward: int = daily.get_reward(first_id)
	presenter._on_single_claim(first_id)
	presenter._on_single_claim(first_id)
	await frames(12)
	check(progression.spirit_stone == before + reward, "duplicate claim grants once through manager")
	check(daily.is_claimed(first_id), "manager retains claim")
	check(not is_instance_valid(initial_card), "claimed state replaces only changed card")
	await create_timer(1.1).timeout
	root.get_node("RewardClaimResultPresenter")._close_popup()
	await frames(8)
	presenter._switch_section("achievement")
	await frames(70)
	check(not presenter.footer.visible and presenter.filters.visible, "achievement footer and filters")
	check(presenter.achievement_card_nodes.size() == achievements.get_achievement_ids().size(), "all actual achievements retained")
	var cached: Dictionary = presenter.achievement_card_nodes.duplicate()
	for category: String in ["combat", "cultivation", "journey", "all"]:
		presenter._select_filter(category)
		await frames(3)
		for record_id: String in cached:
			var data: Dictionary = achievements.get_achievement_data(record_id)
			var actual: String = str(data.get("category", "journey"))
			var group: String = "combat" if actual in ["combat", "boss"] else "cultivation" if actual in ["cultivation", "progression"] else "journey"
			check(cached[record_id].visible == (category == "all" or category == group), "filter matches actual category")
			check(cached[record_id] == presenter.achievement_card_nodes[record_id], "filter retains cached card")
	var achievement_before: int = progression.spirit_stone
	presenter._on_claim_all_pressed()
	check(progression.spirit_stone == achievement_before, "daily bulk claim cannot execute on achievement tab")
	for viewport: Vector2i in [Vector2i(648, 1152), Vector2i(390, 844), Vector2i(320, 568), Vector2i(896, 504)]:
		root.size = viewport
		await frames(10)
		print("TRIALS_GEOMETRY ", viewport, " root=", presenter.presentation_root.size, " filters=", presenter.filters.size, " columns=", presenter.filters.columns, " list=", presenter.achievement_scroll.size)
		check(presenter.filters.get_global_rect().end.x <= viewport.x, "filters contained " + str(viewport))
		check(presenter.achievement_scroll.size.y >= 40, "achievement list usable " + str(viewport))
		await capture("records-%dx%d.png" % [viewport.x, viewport.y])
	presenter._switch_section("daily")
	await frames(10)
	check(presenter.daily_card_nodes.size() == daily.get_daily_quest_ids().size(), "tab return retains daily cards")
	check(presenter.reset_label.text.begins_with("Resets in"), "local daily reset clock")
	var due: int = 0
	for record_id: String in daily.get_daily_quest_ids():
		daily.set_progress_at_least(record_id, daily.get_target(record_id))
		if daily.is_claimable(record_id):
			due += daily.get_reward(record_id)
	before = progression.spirit_stone
	presenter._on_claim_all_pressed()
	presenter._on_claim_all_pressed()
	check(progression.spirit_stone == before + due and daily.get_claimable_count() == 0, "bulk claim grants exact remaining rewards once")
	presenter._switch_section("achievement")
	await frames(35)
	var achievement_id: String = achievements.get_achievement_ids()[0]
	achievements.claimed_achievement_ids.erase(achievement_id)
	achievements.unlocked_achievement_ids.erase(achievement_id)
	achievements.achievement_progress[achievement_id] = 0
	achievements.set_progress_at_least(achievement_id, achievements.get_target(achievement_id))
	before = progression.spirit_stone
	presenter._on_single_claim(achievement_id)
	presenter._on_single_claim(achievement_id)
	check(achievements.is_claimed(achievement_id) and progression.spirit_stone == before + achievements.get_reward(achievement_id), "individual achievement claim remains exact and idempotent")
	change_scene_to_file("res://scenes/ui/achievement_screen.tscn")
	await frames(45)
	presenter = current_scene.get_node("TrialsProductionPresenter")
	check(presenter.active_section == "achievement", "direct achievement entry selects archive")
	check(presenter.daily_card_nodes.is_empty(), "inactive daily tab stays lazy")
	presenter._switch_section("daily")
	presenter._switch_section("achievement")
	presenter._switch_section("daily")
	await frames(12)
	check(presenter.daily_card_nodes.size() == daily.get_daily_quest_ids().size(), "rapid switching cancels stale construction safely")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	current_scene.queue_free()
	await frames(10)
	print("TRIALS_ASCENDANT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
