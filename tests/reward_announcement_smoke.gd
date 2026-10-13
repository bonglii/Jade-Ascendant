extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("REWARD_ANNOUNCEMENT_FAIL: " + tag)
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
func _run() -> void:
	if not OS.get_user_data_dir().contains("jade_rewards_qa"): quit(2); return
	root.content_scale_size = Vector2i.ZERO
	await create_timer(0.4).timeout
	root.get_node("SettingsManager").reduced_effects = OS.get_environment("JADE_QA_REDUCED") == "1"
	var progression: Node = root.get_node("ProgressionManager")
	var inventory: Node = root.get_node("InventoryManager")
	var balance_before: Dictionary = progression.build_progression_save_data().duplicate(true)
	var inventory_before: Dictionary = inventory.item_counts.duplicate(true)
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "actual scene loads")
	await create_timer(0.4).timeout
	current_scene.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
	current_scene.get_node("player_1/WeaponManager").process_mode = Node.PROCESS_MODE_DISABLED
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
	var victory: Node = current_scene.get_node("VictoryUI")
	var defeat: Node = current_scene.get_node("GameOverUI")
	victory.victory_reward_entries.append({"source_type":"stage_clear", "source_id":"chapter_1_stage_1_first_clear", "reward_data":{"spirit_stone":200,"hero_exp":55,"items":{"refinement_shard":2}}})
	paused = true
	for viewport_size: Vector2i in [Vector2i(320,568), Vector2i(390,844), Vector2i(648,1152), Vector2i(720,1600)]:
		root.size = viewport_size
		await settle()
		for ui: Node in [victory, defeat]:
			if ui == victory: ui.show_victory()
			else: ui.show_game_over()
			await create_timer(0.7).timeout
			var panel: Control = ui.get_node("ColorRect/SafeArea/CenterContainer/Panel")
			var rect: Rect2 = panel.get_global_rect()
			check(rect.position.x >= -0.5 and rect.end.x <= viewport_size.x + 0.5, "result panel fits width %s" % viewport_size)
			check(rect.position.y >= -0.5 and rect.end.y <= viewport_size.y + 0.5, "result panel fits height %s" % viewport_size)
			var button: Button = ui.get("main_menu_button")
			check(button.get_global_rect().end.y <= viewport_size.y and button.size.y >= 44, "fixed result action visible")
			var scroll: ScrollContainer = ui.get_node("ResultCeremony")._scroll
			check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "result text scrolls vertically")
			check((ui.get("victory_seal" if ui == victory else "defeat_seal") as TextureRect).size.x > 0, "hero artwork has real width")
			ui.hide()
	check(victory.reward_chip_row.get_child_count() == 3, "HERO EXP joins stone and shard cards")
	victory._refresh_reward_summary()
	victory._refresh_reward_summary()
	check(victory.reward_chip_row.get_child_count() == 3, "repeat refresh cannot duplicate reward cards")
	var mail: Node = root.get_node("ServerMailManager")
	var center: Node = root.get_node("AnnouncementCenter")
	center.set_process(false)
	var account: String = "f".repeat(64)
	mail._owner = account
	var now: int = int(Time.get_unix_time_from_system())
	var entry: Dictionary = {"id":"a".repeat(32),"title":"Welcome to Jade Sanctuary","body":"A new journey awaits.\n".repeat(160),"kind":"event","starts_at":now-1,"expires_at":now+3600,"cancelled":false}
	check(center.accept_snapshot(account, [entry], now), "signed-owner feed accepted")
	center._check_left = 0
	center._process(0.3)
	check(not center.visible and center._queue.size() == 1, "notice waits for result and level-up pause")
	paused = false
	center._check_left = 0
	center._process(0.3)
	check(not center.visible and center._queue.size() == 1, "notice never interrupts live combat")
	check(change_scene_to_file("res://scenes/ui/main_menu.tscn") == OK, "return HOME")
	await create_timer(0.7).timeout
	mail._owner = account
	var onboarding: Control = current_scene.find_child("JadeOnboardingOverlay", true, false) as Control
	if onboarding != null and onboarding.visible:
		check(center._blocked(), "HOME onboarding has priority over broadcast")
		for node: Node in current_scene.find_children("*", "Control", true, false):
			if node.has_method("_finish_onboarding") and node.get("_tutorial_overlay") == onboarding:
				node._finish_onboarding()
				break
		await settle()
	check(not center._blocked(), "HOME safe for queued message")
	var blocker := PanelContainer.new()
	blocker.name = "OtherModal"
	blocker.size = Vector2(100,100)
	current_scene.add_child(blocker)
	check(center._blocked(), "another modal blocks announcement")
	blocker.hide()
	center._check_left = 0
	center._process(0.3)
	check(center.visible and not center._current.is_empty(), "queued announcement appears at safe HOME")
	if center._panel == null: quit(1); return
	for viewport_size: Vector2i in [Vector2i(320,568), Vector2i(390,844), Vector2i(648,1152)]:
		root.size = viewport_size
		await settle()
		center._fit()
		await settle()
		var rect: Rect2 = center._panel.get_global_rect()
		check(rect.position.x >= 0 and rect.end.x <= viewport_size.x + 0.5, "announcement fits width")
		check(rect.position.y >= 0 and rect.end.y <= viewport_size.y + 0.5, "announcement fits height")
		check(center._button.get_global_rect().end.y <= viewport_size.y and center._button.size.y >= 44, "notice close stays visible")
		check(center._scroll.get_v_scroll_bar().max_value > center._scroll.size.y, "long message can scroll")
	check(not center.accept_snapshot("e".repeat(64), [], now), "stale account response rejected")
	check(not center.accept_snapshot(account, [entry,entry], now), "duplicate feed rejected atomically")
	var broken: Dictionary = entry.duplicate(true)
	broken.id = "invalid"
	check(not center.accept_snapshot(account, [broken], now), "invalid notification rejected")
	center._dismiss()
	center._dismiss()
	check(not center.visible and mail.is_announcement_seen(str(entry.id)), "dismiss persisted once for account")
	check(center.accept_snapshot(account, [entry], now) and center._queue.is_empty(), "refresh does not replay dismissed message")
	var cached: Dictionary = root.get_node("SaveManager").read_save_data("server_mail").get("data", {})
	check(str(entry.id) in cached.get("announcement_seen",{}).get(account,[]), "seen marker survives restart storage")
	var fresh: Dictionary = entry.duplicate(true)
	fresh.id = "b".repeat(32)
	check(center.accept_snapshot(account, [fresh], now), "new broadcast accepted")
	center._next_at = 0
	center._check_left = 0
	center._process(0.3)
	check(center.visible, "new message can appear")
	check(center.accept_snapshot(account, [], now) and not center.visible, "cancelled server snapshot closes message")
	center.set_account_owner("e".repeat(64))
	check(center._queue.is_empty() and center._current.is_empty() and not center.visible, "account switch clears presentation")
	check(progression.build_progression_save_data() == balance_before and inventory.item_counts == inventory_before, "presentation grants no fake rewards")
	# Native renders run the real menu prewarm; let its resource jobs finish
	# before teardown so QA does not quit while scripts are still loading.
	var prewarm: Node = root.get_node_or_null("MenuResourcePrewarm")
	if DisplayServer.get_name() != "headless" and prewarm != null:
		var deadline: int = Time.get_ticks_msec() + 15000
		while bool(prewarm.get("_prewarm_started")) and Time.get_ticks_msec() < deadline:
			await create_timer(0.1, true).timeout
	print("REWARD_ANNOUNCEMENT_QA checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
