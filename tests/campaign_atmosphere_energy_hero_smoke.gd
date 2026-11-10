extends SceneTree

const Energy = preload("res://scripts/data/campaign_energy.gd")
const Sets = preload("res://scripts/data/equipment_set_catalog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CAMPAIGN_BATCH_FAIL " + label)

func frames(count: int = 8) -> void:
	for index: int in count:
		await process_frame

func show_scene(path: String) -> Node:
	check(change_scene_to_file(path) == OK, "scene load " + path)
	await frames(16)
	return current_scene

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_campaign_batch_qa"):
		quit(2)
		return
	create_timer(110.0, true).timeout.connect(func(): quit(3))
	await frames()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	test_energy()
	await test_campaign_maps()
	await test_stage_picker()
	await test_hero()
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("CAMPAIGN_BATCH checks=%d failures=%d display=%s" % [checks, failures, DisplayServer.get_name()])
	quit(1 if failures > 0 else 0)

func test_energy() -> void:
	const NOW: int = 1000000
	var empty: Dictionary = Energy.debit({"units":2,"anchor":NOW}, 2, NOW)
	check(Energy.view({}, NOW).units == 12, "old saves receive a full meter")
	check(Energy.view({"units": [], "anchor": {}}, NOW).units == 12, "malformed optional energy stays readable")
	check(Energy.seconds_until(empty, 2, NOW) == 1800, "two units recover in 30 minutes")
	check(Energy.view(empty, NOW + 899).units == 0 and Energy.view(empty, NOW + 900).units == 1, "refill boundary")
	check(Energy.view(empty, NOW - 10).units == 0, "clock rollback does not grant units")
	check(Energy.debit(empty, 2, NOW + 15000).units == 10, "refill capped before a debit")
	var journey: Node = root.get_node("JourneyManager")
	var saved: Dictionary = journey.build_save_data()
	journey.unlocked_stage_keys.assign(["1-1","1-5","2-1"])
	journey.cleared_stage_keys.clear()
	journey.campaign_energy = {"units":0,"anchor":int(Time.get_unix_time_from_system())}
	journey.select_stage(2,1)
	check(journey.begin_selected_stage().is_empty(), "campaign entry guards a depleted balance")
	check(journey.get_stage_energy_cost(1,5) == 0, "Pavilion path remains free")
	journey.campaign_energy = {"units":2,"anchor":int(Time.get_unix_time_from_system())}
	check(not journey.begin_selected_stage().is_empty() and journey.active_run_energy_cost == 2, "new stage records one first-clear cost")
	check(journey.get_energy_status(2,1).units == 2, "entry does not debit")
	var pending: Dictionary = journey.build_save_data()
	check(journey.restore_active_run(2,1,2) and journey.active_run_energy_cost == 2, "checkpoint keeps one original charge")
	check(journey.complete_active_stage(false), "first clear")
	check(journey.get_energy_status(2,1).units == 0 and journey.is_stage_cleared(2,1), "first clear debits two with completion")
	journey.restore_uncommitted_clear(pending)
	check(journey.get_energy_status(2,1).units == 2 and not journey.is_stage_cleared(2,1), "rollback restores energy and unlocks")
	journey.clear_active_run(false)
	check(journey.get_energy_status(2,1).units == 2, "defeat or abandon leaves balance")
	journey.restore_active_run(2,1)
	check(journey.active_run_energy_cost == 0, "legacy checkpoint restored without retroactive charge")
	check(journey.complete_active_stage(true), "legacy first clear still saves")
	check(not journey.begin_selected_stage().is_empty() and journey.active_run_energy_cost == 0, "repeat can enter without charge")
	check(not journey.complete_active_stage(true) and journey.get_energy_status(2,1).units == 2, "repeat rewards do not debit energy")
	journey.restore_uncommitted_clear(saved)

func test_campaign_maps() -> void:
	var journey: Node = root.get_node("JourneyManager")
	var profiles: Dictionary = {}
	var pacing = load("res://scripts/data/campaign_pacing.gd")
	for realm: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(realm):
			var data: Dictionary = journey.get_stage_data(realm, stage)
			if not bool(data.get("implemented", false)):
				continue
			root.get_node("GameSession").start_new_game()
			var world: Node = await show_scene(str(data.scene_path))
			paused = false
			var waves: Node = world.get_node("WaveManager")
			var atmosphere: Node = world.get_node_or_null("StageAtmosphere")
			var opening: float = waves.duration_for_wave(1)
			check(waves.campaign_durations.size() == 9 and absf(float(waves.wave_timer) - opening) < 0.5, "opening wave uses stage schedule %d-%d" % [realm, stage])
			check(is_equal_approx(pacing.total(waves.campaign_durations), pacing.BOSS_ENTRY[realm][stage-1]), "boss entry target %d-%d" % [realm, stage])
			check(waves.campaign_opening_qi_bonus() == 2, "opening Qi policy %d-%d" % [realm, stage])
			check(atmosphere != null and atmosphere._patches.size() == 6 and atmosphere._bed != null and atmosphere._near != null, "bounded ambient visuals and two audio layers %d-%d" % [realm, stage])
			if atmosphere != null:
				check(not profiles.has(atmosphere.profile), "distinct map motif %d-%d" % [realm, stage])
				profiles[atmosphere.profile] = true
				if realm == 1 and stage == 2:
					test_crowd_budget(atmosphere, world)
			if realm == 1 and stage == 2:
				var opening_gem: Node2D = load("res://scenes/pickups/xp_gem.tscn").instantiate()
				opening_gem.position = Vector2(900,900)
				world.add_child(opening_gem)
				check(opening_gem.experience_value == 7, "real opening pickup uses the early Qi bonus")
				opening_gem.free()
			waves.current_wave = waves.final_wave - 1
			waves.wave_timer = 3.0
			check(waves.campaign_opening_qi_bonus() == 0, "opening Qi ends before boss")
			if realm == 1 and stage == 2:
				var final_gem: Node2D = load("res://scenes/pickups/xp_gem.tscn").instantiate()
				final_gem.position = Vector2(900,900)
				world.add_child(final_gem)
				world.get_node("EnemySpawner")._process(0.0)
				check(final_gem.collected and not final_gem.is_in_group("qi_pickup"), "pre-boss interval delivers already earned Qi before spawn")
			if atmosphere != null:
				atmosphere._refresh_patches()
				check(atmosphere._boss_near and atmosphere._voice_target <= -39, "boss cue has audio priority")
	check(profiles.size() == 26, "every authored campaign map has a distinct motif pairing")

func test_crowd_budget(atmosphere: Node, world: Node) -> void:
	var mob_markers: Array[Node2D] = []
	for index: int in 64:
		var marker := Node2D.new()
		marker.add_to_group("enemy")
		world.add_child(marker)
		mob_markers.append(marker)
	atmosphere._refresh_patches()
	var visible: int = 0
	for patch: CanvasItem in atmosphere._patches:
		if patch.visible:
			visible += 1
	check(visible == 2 and not atmosphere._far_mist.visible, "crowd keeps two local accents and suppresses broad fog")
	for marker: Node2D in mob_markers:
		marker.free()
	atmosphere._refresh_patches()

func test_stage_picker() -> void:
	var journey: Node = root.get_node("JourneyManager")
	journey.unlocked_stage_keys.append("2-1")
	journey.cleared_stage_keys.erase("2-1")
	journey.campaign_energy = {"units":1,"anchor":int(Time.get_unix_time_from_system())}
	journey.select_stage(2,1)
	var menu: Node = await show_scene("res://scenes/ui/stage_select.tscn")
	for language: String in ["en","id"]:
		root.get_node("SettingsManager").language = language
		root.size = Vector2i(320,568)
		await frames()
		menu._refresh_stage_energy()
		var label: Label = menu.find_child("StageEnergy", true, false)
		check(label.text.contains("1/12") and menu.start_button.disabled, "compact depleted " + language)
		check(menu.start_button.get_global_rect().end.y <= root.get_visible_rect().end.y + 1, "entry action remains in view " + language)
	journey.campaign_energy.anchor -= 900
	menu._refresh_stage_energy()
	check(not menu.start_button.disabled and menu._energy_label.text.contains("2/12"), "refill unlocks CTA without reopening stage")
	journey.select_stage(1,1)

func test_hero() -> void:
	var equipment: Node = root.get_node("EquipmentManager")
	var inventory: Node = root.get_node("InventoryManager")
	var current: Array[String] = Sets.get_piece_ids("frost_lotus")
	var candidate: Array[String] = Sets.get_piece_ids("crimson_shadow")
	current.append("nine_heavens_star_sword")
	candidate.append("jade_binding_chain")
	for id: String in current + candidate:
		inventory.item_counts[id] = 2
	for id: String in current:
		equipment.equipped_item_ids[str(equipment.get_item_data(id).slot)] = id
	var hero: Node = await show_scene("res://scenes/ui/equipment_screen.tscn")
	for language: String in ["en", "id"]:
		root.get_node("SettingsManager").language = language
		for dims: Vector2i in [Vector2i(320,568), Vector2i(648,1152)]:
			root.size = dims
			await frames()
			for id: String in candidate:
				hero._show_detail(id)
				await frames()
				var slot: String = str(equipment.get_item_data(id).slot)
				var is_weapon: bool = slot == "armament"
				var left: Control = hero.detail.find_child("EquippedWeapon" if is_weapon else "EquippedGear", true, false)
				var right: Control = hero.detail.find_child("CandidateWeapon" if is_weapon else "CandidateGear", true, false)
				check(left != null and right != null and left.global_position.x < right.global_position.x, "comparison cards " + slot + " " + language)
				check(hero.sheet_panel.get_global_rect().end.x <= root.get_visible_rect().end.x + 1, "no horizontal clipping " + slot)
				check(hero.sheet_actions.find_child("EquipAction", true, false).is_visible_in_tree(), "fixed equip action " + slot)
				var detail: Control = hero.detail.find_child("EquipmentDetails", true, false)
				check(not detail.visible, "long detail folded " + slot)
				if not is_weapon:
					check(hero.set_impact.visible and not hero.set_impact.text.is_empty(), "actual four-piece impact " + slot)
				hero._close_detail()
	var gear: String = candidate[0]
	equipment.equipped_item_ids[str(equipment.get_item_data(gear).slot)] = ""
	hero._show_detail(gear)
	await frames()
	var shown: Control = hero.detail.find_child("EquippedGear", true, false)
	check(shown != null and shown.get_child(0).get_child(1).text.contains("kosong"), "empty slot message")
