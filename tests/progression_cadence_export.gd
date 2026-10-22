extends SceneTree
## Authored data/model, never measured player income, TTK or phone performance.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"):
		quit(2)
		return
	await process_frame
	var journey: Node = root.get_node("JourneyManager")
	var rewards: Node = root.get_node("RewardManager")
	var daily: Node = root.get_node("DailyQuestManager")
	var before: Dictionary = {"journey": journey.build_save_data(), "inventory": root.get_node("InventoryManager").item_counts.duplicate(true), "equipment": root.get_node("EquipmentManager").build_equipment_save_data(), "daily": daily.build_save_data()}
	var report: Dictionary = {"scope": "Authored pre-boss survival time; boss duration and actual player income are unmeasured. No balances changed.", "stages": [], "daily_rotation_samples": [], "seven_active_day_baseline": {}, "permanent_weapon_costs": []}
	for chapter: int in journey.get_chapter_ids():
		for stage: int in journey.get_stage_ids(chapter):
			var data: Dictionary = journey.get_stage_data(chapter, stage)
			var authored: Node = load(str(data.scene_path)).instantiate()
			var wave: Node = authored.get_node("WaveManager")
			var seconds: float = float(data.get("wave_duration", wave.wave_duration)) * (int(wave.final_wave) - 1)
			var first: Dictionary = rewards.get_stage_clear_reward(chapter, stage, true)
			var repeat: Dictionary = rewards.get_stage_clear_reward(chapter, stage, false)
			report.stages.append({"id": "%d-%d" % [chapter, stage], "name": data.display_name, "preboss_seconds": seconds, "final_wave": wave.final_wave, "elite_schedule": data.get("elite_schedule", {}), "enemy_cap": data.get("enemy_cap", 0), "first_clear": first, "repeat_clear": repeat, "repeat_stones_per_preboss_minute_upper_bound": float(repeat.get("spirit_stone", 0)) * 60.0 / seconds})
			authored.free()
	for day: int in range(1, 29):
		var date: String = "2026-11-%02d" % day
		var ids: Array[String] = daily._pick_quests_for_date(date)
		var stones: int = 0
		var runs: int = 0
		var level: int = 0
		var kills: int = 0
		for id: String in ids:
			var quest: Dictionary = daily.DAILY_QUESTS[id]
			stones += int(quest.reward)
			match str(quest.category):
				"journey": runs = maxi(runs, int(quest.target))
				"progression": level = maxi(level, int(quest.target))
				"combat": kills = maxi(kills, int(quest.target))
		report.daily_rotation_samples.append({"date": date, "quest_ids": ids, "quest_stones": stones, "required_clears": runs, "required_run_level": level, "required_kills": kills})
	var economy: Script = load("res://scripts/data/economy_catalog.gd")
	var login_jade: int = 0
	var login_seals: int = 0
	for day: int in range(1, 8):
		var reward: Dictionary = root.get_node("LiveOpsManager").get_login_reward(day)
		login_jade += int(reward.get("celestial_jade", 0))
		login_seals += int(reward.get("pavilion_seal", 0))
	report.seven_active_day_baseline = {"daily_completion_jade": 7 * economy.DAILY_COMPLETION_JADE, "cycle_jade": economy.ACTIVE_DAY_CYCLE_BONUS_JADE, "login_jade": login_jade, "total_jade": 7 * economy.DAILY_COMPLETION_JADE + economy.ACTIVE_DAY_CYCLE_BONUS_JADE + login_jade, "cycle_seals": economy.ACTIVE_DAY_CYCLE_BONUS_SEALS, "login_seals": login_seals, "total_seals": economy.ACTIVE_DAY_CYCLE_BONUS_SEALS + login_seals, "excludes": "Ads, first clears, achievements, one-time gifts, live campaigns and paid purchases. Seven fully claimed active daily sets plus seven login claims; not guaranteed calendar income."}
	var equipment: Node = root.get_node("EquipmentManager")
	for star: int in range(1, 6):
		var cap: int = star * 10
		var stones: int = 0
		for level: int in range(1, cap):
			stones += equipment.weapon_level_cost_at(level, cap)
		report.permanent_weapon_costs.append({"star": star, "cap": cap, "stones_level_1_to_cap": stones})
	if report.stages.size() != 26 or report.daily_rotation_samples.size() != 28:
		push_error("Cadence export requires exactly one complete sample per authored stage/date")
		quit(1)
		return
	var after: Dictionary = {"journey": journey.build_save_data(), "inventory": root.get_node("InventoryManager").item_counts, "equipment": equipment.build_equipment_save_data(), "daily": daily.build_save_data()}
	if before != after:
		push_error("Cadence export mutated player data")
		quit(1)
		return
	var path: String = OS.get_environment("JADE_PROGRESSION_CADENCE_OUTPUT")
	if path.is_empty():
		path = "user://progression-cadence.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("PROGRESSION_CADENCE_EXPORT=PASS; STAGES=", report.stages.size(), "; ROTATION_SAMPLES=", report.daily_rotation_samples.size(), "; PLAYER_STATE=UNCHANGED")
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit()
