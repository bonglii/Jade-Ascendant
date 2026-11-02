extends SceneTree
## Isolated, actual manager/UI regression. Native GUI status is reported honestly.
var checks: int = 0
var failures: int = 0
var native: bool = false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("PAVILION_FOCUS " + label)
func frames(count: int = 8) -> void:
	for index: int in count: await process_frame
func state() -> Dictionary:
	return {"pavilion":root.get_node("PavilionManager").state.duplicate(true), "inventory":root.get_node("InventoryManager").item_counts.duplicate(true), "stones":root.get_node("ProgressionManager").spirit_stone}
func swipe(at: Vector2, motion: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.button_mask = MOUSE_BUTTON_MASK_LEFT; down.position = at
	root.push_input(down, true); await frames(1)
	for index: int in range(1, 9):
		var drag := InputEventMouseMotion.new()
		drag.position = at + motion * float(index) / 8.0; drag.relative = motion / 8.0; drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(drag, true); await frames(1)
	down.position = at + motion; down.pressed = false; down.button_mask = 0
	root.push_input(down, true); await frames(10)
func capture(label: String) -> void:
	if not native: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.local/pavilion_focus_qa/images")
	root.get_texture().get_image().save_png("res://.local/pavilion_focus_qa/images/" + label + ".png")

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_pavilion_focus_qa"): quit(2); return
	create_timer(90).timeout.connect(func(): push_error("Pavilion fixture watchdog"); quit(3))
	native = DisplayServer.get_name() != "headless"
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	await frames(10)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(390,844)
	var conf := ConfigFile.new()
	for id: String in ["pavilion", "equipment"]: conf.set_value("tutorials", id, true)
	conf.save("user://jade_onboarding.cfg")
	var journey: Node = root.get_node("JourneyManager")
	for chapter: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(chapter): journey.cleared_stage_keys.append(journey.get_stage_key(chapter, stage))
	var pavilion: Node = root.get_node("PavilionManager")
	var progression: Node = root.get_node("ProgressionManager")
	var inventory: Node = root.get_node("InventoryManager")
	pavilion.state.pavilion_seals = 3; pavilion.state.celestial_jade = 1200; pavilion.state.starter_seals_claimed = true
	pavilion.state.pity_legendary = 12
	progression.spirit_stone = 50000
	change_scene_to_file("res://scenes/ui/pavilion_screen.tscn"); await frames(15)
	var screen: Control = current_scene
	check(screen.has_method("_select_focus_tab"), "production scene loads approved redesign")
	if not screen.has_method("_select_focus_tab"): quit(1); return
	if screen.has_node("JadeOnboardingOverlay"): screen.get_node("JadeOnboardingOverlay").hide()
	var before: Dictionary = state()
	check(screen.focus_tab == "summon" and not screen.paid_mode, "earned summon opens first")
	check(screen.focus_pages.summon.visible and not screen.focus_pages.has("forge") and (not screen.focus_pages.has("aura") or not screen.focus_pages.aura.visible), "one focused page at a time")
	check(not is_instance_valid(screen._focus_aura_preview), "offscreen catalogs are lazy")
	check(screen.summon_ten_button.text.contains("3 SEALS + 630 JADE"), "mixed ten-pull cost matches current manager")
	await capture("summon-390")
	screen._select_summon_mode(true); await frames()
	check(screen._paid_buttons[0].get_parent().visible and not screen._focus_normal_row.visible, "paid mode presents exactly its own actions")
	check(screen._paid_buttons[0].disabled and screen._focus_use_seals.visible, "owned-Seal-first restriction is explicit")
	check(screen.focal_name.text.contains("Legendary") and screen.legendary_value.text != "12 / 50", "paid mode never borrows local target or pity")
	screen._summon_paid(1)
	check(state() == before, "explicit paid tap cannot silently spend regular Seals")
	await capture("paid-390")
	screen._select_summon_mode(false)
	check(screen.legendary_value.text == "12 / 50", "return restores earned pity")
	check(state() == before, "browsing modes never spends or changes guarantees")
	# Target selection must not consume Fate until the confirmation action.
	pavilion.state.wish_item_id = "nine_heavens_star_sword"; pavilion.state.wish_fate_guaranteed = true
	screen._open_target_picker("weapon"); await frames()
	screen._target_button_down(); screen._choose_browser_target("jade_binding_chain", screen._target_epoch); await frames()
	check(pavilion.state.wish_item_id == "nine_heavens_star_sword" and pavilion.state.wish_fate_guaranteed, "opening confirmation preserves target and Fate")
	screen._back()
	check(pavilion.state.wish_fate_guaranteed, "cancel preserves Fate")
	screen._open_target_picker("weapon"); await create_timer(0.2).timeout
	screen._target_button_down(); screen._choose_browser_target("jade_binding_chain", screen._target_epoch); await frames()
	screen._confirm_focus_target("jade_binding_chain", "nine_heavens_star_sword"); await frames()
	check(pavilion.state.wish_item_id == "jade_binding_chain" and not pavilion.state.wish_fate_guaranteed and pavilion.state.pity_legendary == 12, "confirmed target resets Fate only")
	# Daily claims remain the original exactly-once save transaction.
	var stones: int = progression.spirit_stone
	screen._open_daily(); await frames()
	screen._claim_focus_daily(); screen._claim_focus_daily(); await frames()
	check(progression.spirit_stone == stones + 20, "daily double tap cannot grant twice")
	# The removed forge cannot grant or debit through its legacy entry point.
	stones = progression.spirit_stone
	check(not pavilion.acquire_equipment("nine_heavens_star_sword", true) and progression.spirit_stone == stones, "retired forge cannot spend")
	# A player dismisses the real reward receipt before using the next page.
	await create_timer(1.2).timeout
	var receipt: Node = root.get_node_or_null("RewardClaimResultPresenter")
	if receipt != null: receipt._close_popup()
	await frames()
	if pavilion.is_aura_feature_enabled():
		# Preview stays read-only; only an explicit Equip applies the aura.
		screen._select_focus_tab("aura"); await frames()
		before = state()
		screen._preview_focus_aura("astral_aura"); await frames()
		check(state() == before and screen._focus_aura_preview.aura_id == "astral_aura", "locked/unowned aura preview never grants, equips or debits")
		var stone_balance: int = progression.spirit_stone
		progression.spirit_stone = 0
		screen._preview_focus_aura("ascendant_aura")
		before = state()
		screen._apply_focus_aura()
		check(screen._focus_aura_action.disabled and state() == before, "missing prerequisite and funds cannot acquire an aura")
		progression.spirit_stone = stone_balance
		screen._preview_focus_aura("jade_aura"); screen._apply_focus_aura(); await frames()
		check(pavilion.get_cosmetic_id() == "jade_aura" and pavilion.is_cosmetic_owned("jade_aura"), "explicit equip uses existing cosmetic manager")
		var live: Node2D = load("res://scripts/player/lin_yue_pavilion_aura_presentation.gd").new()
		root.add_child(live)
		check(live.visible and not live.is_physics_processing(), "selected aura draws in gameplay without physics")
		live.queue_free()
		await capture("aura-390")
	else:
		before = state()
		screen._select_focus_tab("aura"); screen._preview_focus_aura("jade_aura"); screen._apply_focus_aura()
		check(screen.focus_tab == "summon" and not screen.focus_pages.has("aura") and not is_instance_valid(screen._focus_aura_preview), "held aura has no tab, preview or direct action")
		check(not pavilion.acquire_cosmetic("jade_aura") and not pavilion.select_cosmetic("jade_aura") and state() == before, "held aura preserves balances and ownership")
	# Fit all pages and sheets at real narrow and production logical widths.
	for dims: Vector2i in [Vector2i(320,568), Vector2i(390,844), Vector2i(648,1152), Vector2i(896,504)]:
		root.size = dims; await frames()
		for key: String in screen.focus_pages:
			screen._select_focus_tab(key); await frames()
			check(screen.content.get_global_rect().end.x <= dims.x + 1, "no horizontal overflow " + key + str(dims))
			check(screen.focus_tabs[key].get_global_rect().end.x <= dims.x + 1, "tab fits " + key + str(dims))
			screen._open_daily(); await frames()
			var panel: PanelContainer = screen._focus_sheet.get_meta("panel")
			check(panel.get_global_rect().end.y <= screen._focus_sheet.get_global_rect().end.y + 1 and panel.size.x <= dims.x, "daily sheet fits " + str(dims))
			screen._back()
		await capture("aura-" + str(dims.x))
	# System Back remains owned after a universal receipt has closed.
	if pavilion.is_aura_feature_enabled():
		screen._select_focus_tab("aura"); screen.handle_system_back()
		check(screen.focus_tab == "summon", "system Back returns from secondary Pavilion page")
	else:
		screen._open_daily(); await frames(); screen.handle_system_back(); await frames()
		check(current_scene == screen and not is_instance_valid(screen._focus_sheet), "system Back closes the utility sheet without leaving Pavilion")
	# Drag a genuine catalog card; browsing must never confirm a wish or spend.
	root.size = Vector2i(390,844); await frames()
	screen._select_focus_tab("summon"); screen._open_target_picker("weapon"); await frames(12)
	var scroll: ScrollContainer = screen._target_overlay.get_meta("scroll")
	var initial: int = scroll.scroll_vertical
	var card: Control = screen._target_overlay.find_child("TargetChoices",true,false).get_child(0)
	before = state()
	var visible: Rect2 = card.get_global_rect().intersection(scroll.get_global_rect())
	check(visible.size.y > 20, "swipe starts on visible catalog card")
	await swipe(visible.get_center(), Vector2(0,-130))
	check(scroll.scroll_vertical > initial + 20, "first catalog drag scrolls immediately")
	check(not is_instance_valid(screen._focus_sheet) and state() == before, "swipe cannot select, claim or spend")
	check(scroll.has_meta("jade_shared_scroll"), "shared touch policy remains active")
	screen._close_target_picker()
	# New benefits/action must obey the existing sealed-reveal boundary.
	screen._select_focus_tab("summon"); await frames()
	before = state()
	screen._start_summon_reveal({"results":[{"item_id":"nine_heavens_star_sword", "rarity":"legendary", "duplicate":true}]})
	check(not screen._focus_result_stats.visible and not screen._focus_result_hero.visible, "benefits and Hero action stay sealed during charge")
	screen._skip_ritual(); await frames()
	check(screen._focus_result_stats.visible and screen._focus_result_stats.text.contains("10%") and screen._focus_result_hero.visible, "landed item reveals actual benefits and Hero action")
	await capture("result-390")
	screen._finish_summon_reveal()
	check(state() == before, "result presentation cannot regrant or debit")
	print("PAVILION_FOCUS checks=%d failures=%d; NATIVE_GUI=%s; PHONE=NOT_TESTED" % [checks, failures, str(native)])
	current_scene.queue_free(); current_scene = null; await frames()
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
