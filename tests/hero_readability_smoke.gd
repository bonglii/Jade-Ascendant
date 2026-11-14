extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("HERO_READABILITY_FAIL " + label)

func frames(count: int = 5) -> void:
	for index: int in range(count):
		await process_frame

func swipe(at: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = at
	Input.parse_input_event(down)
	await frames(1)
	for index: int in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = at + Vector2(0, -8 * index)
		drag.relative = Vector2(0, -8)
		Input.parse_input_event(drag)
		await frames(1)
	down.position = at + Vector2(0, -64)
	down.pressed = false
	Input.parse_input_event(down)
	await frames(8)

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_polish_nov14"):
		quit(2)
		return
	await frames()
	Input.set_emulate_touch_from_mouse(true)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(405, 860)
	var settings: Node = root.get_node("SettingsManager")
	settings.set_presentation("language", "en")
	var equipment: Node = root.get_node("EquipmentManager")
	var inventory: Node = root.get_node("InventoryManager")
	var pavilion: Node = root.get_node("PavilionManager")
	var old_paid: Node = pavilion.paid_gameplay
	var paid: Node = load("res://tests/fixtures/paid_gameplay_manager_v2.gd").new()
	root.add_child(paid)
	paid.set("_binding", "a".repeat(64))
	paid.set("_expires", Time.get_ticks_msec() + 120000)
	paid.snapshot = {"paid_gameplay_version":2, "account_binding":"a".repeat(64), "catalog_hash":paid.HASH,
		"state":"ready", "revision":0, "wallet":{"balance":1500,"revision":1},
		"inventory":{"mistveil_jian":1}, "stars":{"mistveil_jian":5},
		"slots":{"armament":"", "robe":"", "bracer":"", "pendant":"", "boots":""},
		"pity":{"rare_plus":0,"epic_plus":0,"legendary":0}, "wish":"", "wish_guaranteed":false,
		"lifetime_pulls":1, "rates":{"common":6000,"rare":2900,"epic":900,"legendary":200}, "lease_seconds":120}
	check(paid.valid_snapshot(paid.snapshot, "a".repeat(64)), "fixture follows the real paid snapshot contract")
	pavilion.paid_gameplay = paid
	equipment.active_run_loadout_snapshot = {}
	for id: String in equipment.get_item_ids():
		inventory.item_counts[id] = 2
	equipment.ascension_stars = {"wanderer_jade_jian":4}
	equipment.equipped_item_ids = {"armament":"wanderer_jade_jian", "robe":"frost_lotus_robe",
		"bracer":"frost_lotus_bracer", "boots":"", "pendant":"frost_lotus_pendant"}
	var config := ConfigFile.new()
	config.set_value("meta", "version", 2)
	config.set_value("tutorials", "equipment", true)
	config.save("user://jade_onboarding.cfg")
	check(change_scene_to_file("res://scenes/ui/equipment_screen.tscn") == OK, "production Hero scene")
	await scene_changed
	await frames(12)
	var hero: Control = current_scene
	hero.sort_id = 2
	hero.filter_id = "armament"
	hero._rebuild_grid()
	await frames()
	var ids: Array[String] = hero._visible_item_ids()
	check(ids[0] == "mistveil_jian", "verified five-star equipment sorts before local four-star equipment")
	check(ids[1] == "wanderer_jade_jian", "local star order follows the displayed backpack source")
	check(hero.card_buttons["mistveil_jian"].get_node("ItemRank").text == "★ 5/5", "explicit paid star fraction")
	check(hero.card_buttons["wanderer_jade_jian"].get_node("ItemRank").text == "★ 4/5", "explicit local star fraction")
	hero.query = "   Mistveil   "
	check(hero._visible_item_ids() == ["mistveil_jian"], "search ignores accidental surrounding spaces")
	hero.search_box.text = hero.query
	hero.search_box.show()
	hero._slot_pressed("boots")
	await frames()
	check(hero.query.is_empty() and hero.search_box.text.is_empty() and not hero.search_box.visible,
		"empty-slot shortcut clears the unrelated search")
	check(hero.filter_id == "boots" and hero._visible_item_ids().size() > 0,
		"empty-slot shortcut exposes the owned candidates")
	var counts: Dictionary = inventory.item_counts.duplicate(true)
	var stars: Dictionary = equipment.ascension_stars.duplicate(true)
	var paid_snapshot: Dictionary = paid.snapshot.duplicate(true)
	for language: String in ["en", "id"]:
		settings.set_presentation("language", language)
		for viewport: Vector2i in [Vector2i(320,568), Vector2i(405,860), Vector2i(648,1152), Vector2i(860,405)]:
			root.size = viewport
			await frames()
			hero.filter_id = "armament"
			hero._refresh_all()
			await frames()
			var card: Button = hero.card_buttons["wanderer_jade_jian"]
			var caption: Label = card.get_node("EquippedMark/EquippedBadge/EquippedCaption")
			check(caption.text in (["✓ AKTIF", "TERPAKAI"] if language == "id" else ["✓ ON", "EQUIPPED"]),
				"equipped badge language " + language + str(viewport))
			var font: Font = caption.get_theme_font("font")
			check(font.get_string_size(caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				caption.get_theme_font_size("font_size")).x <= caption.size.x + 1,
				"native badge text fits " + language + str(viewport))
			var rank: Label = card.get_node("ItemRank")
			check(rank.get_theme_font("font").get_string_size(rank.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				rank.get_theme_font_size("font_size")).x <= rank.size.x + 1,
				"rank fraction fits " + language + str(viewport))
			if viewport.y < 620:
				hero.scroll.scroll_vertical = 0
				await frames()
				var first_card: Button = hero.card_buttons["mistveil_jian"]
				if viewport.x > viewport.y:
					check(hero.fixed_deck.get_parent() == hero.scroll_stack and hero.scroll.size.y > 160,
						"landscape loadout and backpack share a usable native scroller " + language)
				else:
					check(hero.scroll.get_global_rect().grow(1).encloses(first_card.get_global_rect()),
						"short phone shows a complete first card " + language)
				var practice: Button = hero.content.find_child("HeroTraining", true, false)
				check(practice != null and practice.get_global_rect().end.x <= hero.content.get_global_rect().end.x,
					"compact training action fits " + language + str(viewport))
			var same_order: Array[String] = hero._visible_item_ids()
			check(same_order[0] == "mistveil_jian" and same_order[1] == "wanderer_jade_jian",
				"sort stable across layout and language " + language + str(viewport))
	root.size = Vector2i(405, 860)
	await frames()
	hero.filter_id = "all"
	hero._refresh_all()
	await frames()
	hero.scroll.scroll_vertical = 0
	await frames()
	var visible_card := Rect2()
	for card: Button in hero.card_buttons.values():
		var visible: Rect2 = card.get_global_rect().intersection(hero.scroll.get_global_rect())
		if visible.size.x > 20 and visible.size.y > 35:
			visible_card = visible
			break
	check(visible_card.has_area(), "first swipe starts on a real visible equipment card")
	print("HERO_SWIPE before=", hero.scroll.scroll_vertical, " rect=", hero.scroll.get_global_rect(), " max=", hero.scroll.get_v_scroll_bar().max_value, " card=", visible_card)
	if visible_card.has_area():
		await swipe(visible_card.get_center())
	print("HERO_SWIPE after=", hero.scroll.scroll_vertical, " detail=", hero.detail_open, " busy=", paid.busy)
	check(hero.scroll.scroll_vertical > 20 and not hero.detail_open and not paid.busy,
		"first native drag scrolls without inspecting, equipping, or spending")
	check(inventory.item_counts == counts and equipment.ascension_stars == stars and paid.snapshot == paid_snapshot,
		"browsing and sorting preserve local and verified ownership")
	print("HERO_READABILITY_CHECKS=", checks, ";FAILURES=", failures, ";DISPLAY=", DisplayServer.get_name())
	if "--review" in OS.get_cmdline_user_args():
		root.size = Vector2i(320, 568) if "--compact" in OS.get_cmdline_user_args() else Vector2i(405, 860)
		root.title = "Jade Ascendant · Hero review fixture"
		settings.set_presentation("language", "id" if "--review-id" in OS.get_cmdline_user_args() else "en")
		hero._refresh_all()
		return
	current_scene.queue_free()
	await frames()
	pavilion.paid_gameplay = old_paid
	paid.queue_free()
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
