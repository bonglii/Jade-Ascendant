extends Node

## Achievement Manager
## Mengelola definisi achievement, progress permanen, status unlock,
## status reward claim, dan persistence achievement.
## Gameplay event hook akan dihubungkan pada langkah berikutnya.

signal achievement_progressed(
	achievement_id: String,
	current_progress: int,
	target_progress: int
)
signal achievement_unlocked(achievement_id: String)
signal achievement_claimed(achievement_id: String, spirit_stone_reward: int)

const SAVE_PATH: String = "user://achievements.save"
const SAVE_VERSION: int = 1

const ACHIEVEMENTS: Dictionary = {
	"first_blood":{"title":"First Blood","description":"Defeat your first enemy.","category":"combat","target":1,"reward":20},
	"enemy_slayer_50":{"title":"Enemy Slayer","description":"Defeat 50 enemies.","category":"combat","target":50,"reward":50},
	"cultivator_level_5":{"title":"Rising Cultivator","description":"Reach Level 5 during a run.","category":"progression","target":5,"reward":50},
	"first_stage_clear":{"title":"Path Opened","description":"Clear your first stage.","category":"journey","target":1,"reward":100},
	"first_boss_defeat":{"title":"Boss Breaker","description":"Defeat your first Stage Boss.","category":"boss","target":1,"reward":100},
	"cultivation_initiate":{"title":"Cultivation Initiate","description":"Purchase your first permanent cultivation upgrade.","category":"cultivation","target":1,"reward":50},
	"enemy_slayer_250":{"title":"Valley Sentinel","description":"Defeat 250 enemies.","category":"combat","target":250,"reward":100},
	"enemy_slayer_500":{"title":"Five Hundred Cuts","description":"Defeat 500 enemies.","category":"combat","target":500,"reward":160},
	"enemy_slayer_1000":{"title":"Thousandfold Intent","description":"Defeat 1,000 enemies.","category":"combat","target":1000,"reward":250},
	"enemy_slayer_2500":{"title":"Army-Breaking Intent","description":"Defeat 2,500 enemies.","category":"combat","target":2500,"reward":400},
	"enemy_slayer_5000":{"title":"Ten Thousand Blades' Echo","description":"Defeat 5,000 enemies.","category":"combat","target":5000,"reward":650},
	"cultivator_level_10":{"title":"Qi Condensation","description":"Reach Level 10 during a run.","category":"progression","target":10,"reward":100},
	"cultivator_level_15":{"title":"Golden Meridian","description":"Reach Level 15 during a run.","category":"progression","target":15,"reward":150},
	"cultivator_level_20":{"title":"Boundless Comprehension","description":"Reach Level 20 during a run.","category":"progression","target":20,"reward":200},
	"cultivator_level_25":{"title":"Heavenward Insight","description":"Reach Level 25 during a run.","category":"progression","target":25,"reward":320},
	"art_master":{"title":"Sevenfold Art","description":"Refine any combat art to Level 7.","category":"progression","target":1,"reward":100},
	"stage_1_1_clear":{"title":"Verdant First Step","description":"Clear Stage 1-1: Verdant Awakening.","category":"journey","target":1,"reward":40},
	"stage_1_2_clear":{"title":"Mist Piercer","description":"Clear Stage 1-2: Bamboo Mist Pass.","category":"journey","target":1,"reward":60},
	"stage_1_3_clear":{"title":"Broken Seal Mended","description":"Clear Stage 1-3: Ruined Jade Shrine.","category":"journey","target":1,"reward":80},
	"stage_1_4_clear":{"title":"Storm-Treader","description":"Clear Stage 1-4: Storm Peak Approach.","category":"journey","target":1,"reward":110},
	"stage_1_5_clear":{"title":"Celestial Gatebreaker","description":"Clear Stage 1-5: Sovereign's Celestial Gate.","category":"journey","target":1,"reward":150},
	"stage_1_6_clear":{"title":"Heart of Verdant Heaven","description":"Clear Stage 1-6 and defeat the Ascended Sovereign.","category":"journey","target":1,"reward":250},
	"chapter_one_master":{"title":"Sovereign Gate Conqueror","description":"Clear the first five Chapter 1 trials.","category":"journey","target":5,"reward":300},
	"verdant_heaven_ascendant":{"title":"Verdant Heaven Ascendant","description":"Clear all six Verdant Qi Valley trials.","category":"journey","target":6,"reward":450},
	"chapter_two_master":{"title":"Crimson Moon Conqueror","description":"Clear all five Chapter 2 trials.","category":"journey","target":5,"reward":450},
	"chapter_three_master":{"title":"Ascendant of Nine Heavens","description":"Clear all five Chapter 3 trials.","category":"journey","target":5,"reward":650},
	"jade_ascendant":{"title":"Jade Ascendant","description":"Clear fifteen unique journey stages.","category":"journey","target":15,"reward":900},
	"journey_complete_16":{"title":"Heaven-Treading Ascendant","description":"Clear all sixteen current journey stages.","category":"journey","target":16,"reward":1100},
	"trial_veteran_5":{"title":"Five Trials Tempered","description":"Complete 5 stages, including repeats.","category":"journey","target":5,"reward":80},
	"trial_veteran_10":{"title":"Ten Trials Tempered","description":"Complete 10 stages, including repeats.","category":"journey","target":10,"reward":140},
	"trial_veteran_30":{"title":"Thirty Trials Tempered","description":"Complete 30 stages, including repeats.","category":"journey","target":30,"reward":300},
	"trial_veteran_60":{"title":"Sixty Trials Tempered","description":"Complete 60 stages, including repeats.","category":"journey","target":60,"reward":520},
	"trial_veteran_100":{"title":"Hundredfold Tempering","description":"Complete 100 stages, including repeats.","category":"journey","target":100,"reward":850},
	"boss_slayer_10":{"title":"Ten Seals Broken","description":"Defeat 10 stage guardians.","category":"boss","target":10,"reward":180},
	"boss_slayer_25":{"title":"Guardian Breaker","description":"Defeat 25 stage guardians.","category":"boss","target":25,"reward":320},
	"boss_slayer_50":{"title":"Fifty Thrones Fallen","description":"Defeat 50 stage guardians.","category":"boss","target":50,"reward":600},
	"cultivation_adept":{"title":"Meridian Adept","description":"Own 10 permanent cultivation levels in total.","category":"cultivation","target":10,"reward":150},
	"cultivation_master_20":{"title":"Jade Meridian Master","description":"Own 20 permanent cultivation levels in total.","category":"cultivation","target":20,"reward":280},
	"cultivation_master_30":{"title":"Dao Foundation Eternal","description":"Own 30 permanent cultivation levels in total.","category":"cultivation","target":30,"reward":500},
}

const STAGE_CLEAR_ACHIEVEMENTS: Dictionary = {
	"1-1":"stage_1_1_clear","1-2":"stage_1_2_clear","1-3":"stage_1_3_clear",
	"1-4":"stage_1_4_clear","1-5":"stage_1_5_clear","1-6":"stage_1_6_clear",
}


var _progress_dirty: bool = false
var _save_left: float = 2.0
var achievement_progress: Dictionary = {}
var unlocked_achievement_ids: Array[String] = []
var claimed_achievement_ids: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_progress_entries()
	load_achievements()
	_validate_loaded_state()
	_connect_runtime_hooks()
	_connect_permanent_progress_hooks()
	_sync_existing_permanent_progress()
	_sync_extended_progress()
	print_achievement_status()

func _connect_runtime_hooks() -> void:
	var tree := get_tree()
	var node_added_callable := Callable(
		self,
		"_on_tree_node_added"
	)
	if not tree.node_added.is_connected(node_added_callable):
		tree.node_added.connect(node_added_callable)
	var enemy_spawners := tree.root.find_children(
		"EnemySpawner",
		"Node",
		true,
		false
	)
	for enemy_spawner in enemy_spawners:
		_try_connect_enemy_spawner(enemy_spawner)
	var players := tree.get_nodes_in_group("player")
	for player in players:
		_try_connect_player(player)

func _connect_permanent_progress_hooks() -> void:
	var stage_completed_callable := Callable(
		self,
		"_on_stage_completed"
	)
	if JourneyManager.has_signal("stage_completed"):
		if not JourneyManager.is_connected(
			"stage_completed",
			stage_completed_callable
		):
			JourneyManager.connect(
				"stage_completed",
				stage_completed_callable
			)
	else:
		push_warning(
			"AchievementManager: JourneyManager tidak memiliki "
			+ "signal stage_completed."
		)
	var cultivation_callable := Callable(
		self,
		"_on_cultivation_upgraded"
	)
	if ProgressionManager.has_signal("cultivation_upgraded"):
		if not ProgressionManager.is_connected(
			"cultivation_upgraded",
			cultivation_callable
		):
			ProgressionManager.connect(
				"cultivation_upgraded",
				cultivation_callable
			)
	else:
		push_warning(
			"AchievementManager: ProgressionManager tidak memiliki "
			+ "signal cultivation_upgraded."
		)

func _sync_existing_permanent_progress() -> void:
	if not JourneyManager.cleared_stage_keys.is_empty():
		set_progress_at_least("first_stage_clear", 1)
		set_progress_at_least("first_boss_defeat", 1)
	if (
		ProgressionManager.vitality_level > 0
		or ProgressionManager.sword_power_level > 0
		or ProgressionManager.swift_qi_level > 0
	):
		set_progress_at_least("cultivation_initiate", 1)

func _on_tree_node_added(node: Node) -> void:
	_try_connect_enemy_spawner(node)
	_try_connect_player(node)

func _try_connect_enemy_spawner(node: Node) -> void:
	if node == null:
		return
	if node.name != "EnemySpawner":
		return
	if node.has_signal("enemy_killed"):
		var enemy_killed_callable := Callable(
			self,
			"_on_enemy_killed"
		)
		if not node.is_connected(
			"enemy_killed",
			enemy_killed_callable
		):
			node.connect(
				"enemy_killed",
				enemy_killed_callable
			)
			DebugLogger.system(str(
				"AchievementManager terhubung ke EnemySpawner."
			))
	if node.has_signal("boss_spawned_signal"):
		var boss_spawned_callable := Callable(
			self,
			"_on_boss_spawned"
		)
		if not node.is_connected(
			"boss_spawned_signal",
			boss_spawned_callable
		):
			node.connect(
				"boss_spawned_signal",
				boss_spawned_callable
			)

func _try_connect_player(node: Node) -> void:
	if node == null:
		return
	if not node.is_in_group("player"):
		return
	if not node.has_signal("level_changed"):
		return
	var level_changed_callable := Callable(
		self,
		"_on_player_level_changed"
	)
	if not node.is_connected(
		"level_changed",
		level_changed_callable
	):
		node.connect(
			"level_changed",
			level_changed_callable
		)
	var current_level = node.get("level")
	if current_level != null:
		_on_player_level_changed(int(current_level))

func _on_enemy_killed() -> void:
	set_progress_at_least("first_blood", 1)
	for achievement_id: String in [
		"enemy_slayer_50","enemy_slayer_250","enemy_slayer_500",
		"enemy_slayer_1000","enemy_slayer_2500","enemy_slayer_5000"
	]:
		add_progress(achievement_id, 1)

func _on_player_level_changed(new_level: int) -> void:
	for achievement_id: String in [
		"cultivator_level_5","cultivator_level_10","cultivator_level_15",
		"cultivator_level_20","cultivator_level_25"
	]:
		set_progress_at_least(achievement_id, new_level)

func _on_boss_spawned(boss: Node) -> void:
	if boss == null:
		return
	if not boss.has_signal("boss_defeated"):
		return
	var boss_defeated_callable := Callable(
		self,
		"_on_boss_defeated"
	)
	if boss.is_connected(
		"boss_defeated",
		boss_defeated_callable
	):
		return
	boss.connect(
		"boss_defeated",
		boss_defeated_callable
	)

func _on_boss_defeated() -> void:
	set_progress_at_least("first_boss_defeat", 1)
	for achievement_id: String in ["boss_slayer_10","boss_slayer_25","boss_slayer_50"]:
		add_progress(achievement_id, 1)

func _on_stage_completed(
	chapter_id: int,
	stage_id: int,
	_was_first_clear: bool
) -> void:
	set_progress_at_least("first_stage_clear", 1)
	var stage_key: String = JourneyManager.get_stage_key(chapter_id, stage_id)
	if STAGE_CLEAR_ACHIEVEMENTS.has(stage_key):
		set_progress_at_least(str(STAGE_CLEAR_ACHIEVEMENTS[stage_key]), 1)
	for achievement_id: String in [
		"trial_veteran_5","trial_veteran_10","trial_veteran_30",
		"trial_veteran_60","trial_veteran_100"
	]:
		add_progress(achievement_id, 1)
	_sync_journey_achievement_progress()

func _on_cultivation_upgraded(
	_upgrade_id: String,
	_new_level: int
) -> void:
	set_progress_at_least("cultivation_initiate", 1)
	_sync_extended_progress()

func get_achievement_ids() -> Array[String]:
	var achievement_ids: Array[String] = []
	for raw_id in ACHIEVEMENTS.keys():
		achievement_ids.append(str(raw_id))
	achievement_ids.sort()
	return achievement_ids

func has_achievement(achievement_id: String) -> bool:
	return ACHIEVEMENTS.has(achievement_id)

func get_achievement_data(achievement_id: String) -> Dictionary:
	if not has_achievement(achievement_id):
		return {}
	var data: Dictionary = ACHIEVEMENTS[achievement_id]
	return data.duplicate(true)

func get_progress(achievement_id: String) -> int:
	if not has_achievement(achievement_id):
		return 0
	return int(achievement_progress.get(achievement_id, 0))

func get_target(achievement_id: String) -> int:
	if not has_achievement(achievement_id):
		return 0
	var data: Dictionary = ACHIEVEMENTS[achievement_id]
	return max(int(data.get("target", 0)), 0)

func get_reward(achievement_id: String) -> int:
	if not has_achievement(achievement_id):
		return 0
	var data: Dictionary = ACHIEVEMENTS[achievement_id]
	return max(int(data.get("reward", 0)), 0)

func is_unlocked(achievement_id: String) -> bool:
	return achievement_id in unlocked_achievement_ids

func is_claimed(achievement_id: String) -> bool:
	return achievement_id in claimed_achievement_ids

func is_claimable(achievement_id: String) -> bool:
	return (
		is_unlocked(achievement_id)
		and not is_claimed(achievement_id)
	)

func get_unlocked_count() -> int:
	return unlocked_achievement_ids.size()

func get_claimable_count() -> int:
	return get_claimable_ids().size()

func get_claimable_ids() -> Array[String]:
	var claimable_ids: Array[String] = []
	for achievement_id in unlocked_achievement_ids:
		if is_claimable(achievement_id):
			claimable_ids.append(achievement_id)
	claimable_ids.sort()
	return claimable_ids

func get_total_claimable_reward() -> int:
	var total_reward: int = 0
	for achievement_id in get_claimable_ids():
		total_reward += get_reward(achievement_id)
	return total_reward

func add_progress(achievement_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not has_achievement(achievement_id):
		push_warning(
			"AchievementManager: achievement tidak ditemukan: "
			+ achievement_id
		)
		return false
	if is_unlocked(achievement_id):
		return false
	var target := get_target(achievement_id)
	if target <= 0:
		return false
	var previous_progress := get_progress(achievement_id)
	var new_progress := mini(previous_progress + amount, target)
	if new_progress == previous_progress:
		return false
	achievement_progress[achievement_id] = new_progress
	achievement_progressed.emit(
		achievement_id,
		new_progress,
		target
	)
	if new_progress >= target:
		_unlock_achievement(achievement_id)
	else:
		_progress_dirty = true
	return true

func set_progress_at_least(
	achievement_id: String,
	progress_value: int
) -> bool:
	if progress_value <= 0:
		return false
	if not has_achievement(achievement_id):
		push_warning(
			"AchievementManager: achievement tidak ditemukan: "
			+ achievement_id
		)
		return false
	if is_unlocked(achievement_id):
		return false
	var target := get_target(achievement_id)
	if target <= 0:
		return false
	var previous_progress := get_progress(achievement_id)
	var new_progress := mini(maxi(progress_value, previous_progress), target)
	if new_progress == previous_progress:
		return false
	achievement_progress[achievement_id] = new_progress
	achievement_progressed.emit(
		achievement_id,
		new_progress,
		target
	)
	if new_progress >= target:
		_unlock_achievement(achievement_id)
	else:
		_progress_dirty = true
	return true

func claim_reward(achievement_id: String) -> bool:
	if not is_claimable(achievement_id):
		return false
	var reward := get_reward(achievement_id)
	var reward_data := RewardManager.create_reward_data(reward)
	if not RewardManager.is_valid_reward(
		RewardManager.SOURCE_ACHIEVEMENT,
		achievement_id,
		reward_data
	):
		push_error(
			"AchievementManager: reward tidak valid untuk "
			+ achievement_id
		)
		return false
	claimed_achievement_ids.append(achievement_id)
	var grant_result := RewardManager.grant_reward(
		RewardManager.SOURCE_ACHIEVEMENT,
		achievement_id,
		reward_data,
		{"achievements": build_save_data()}
	)
	if not bool(grant_result.get("success", false)):
		claimed_achievement_ids.erase(achievement_id)
		push_error(
			"AchievementManager: reward gagal diberikan. "
			+ str(grant_result.get("error", "unknown error"))
		)
		return false
	achievement_claimed.emit(achievement_id, reward)
	DebugLogger.system(str(
		"Achievement reward diklaim: ",
		achievement_id,
		" | Spirit Stone +",
		reward
	))
	return true

func claim_all_rewards() -> int:
	var claimable_ids := get_claimable_ids()
	if claimable_ids.is_empty():
		return 0
	var claimed_count: int = 0
	for achievement_id in claimable_ids:
		if claim_reward(achievement_id):
			claimed_count += 1
	return claimed_count

func _unlock_achievement(achievement_id: String) -> void:
	if is_unlocked(achievement_id):
		return
	unlocked_achievement_ids.append(achievement_id)
	achievement_progress[achievement_id] = get_target(achievement_id)
	save_achievements()
	achievement_unlocked.emit(achievement_id)
	var data := get_achievement_data(achievement_id)
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("ACHIEVEMENT UNLOCKED!"))
	DebugLogger.system(str("ID: ", achievement_id))
	DebugLogger.system(str("Title: ", data.get("title", achievement_id)))
	DebugLogger.system(str("Reward: ", get_reward(achievement_id), " Spirit Stone"))
	DebugLogger.system(str("=========================================="))

func _initialize_progress_entries() -> void:
	for achievement_id in get_achievement_ids():
		if not achievement_progress.has(achievement_id):
			achievement_progress[achievement_id] = 0

func _validate_loaded_state() -> void:
	var valid_unlocked: Array[String] = []
	for achievement_id in unlocked_achievement_ids:
		if not has_achievement(achievement_id):
			continue
		if achievement_id not in valid_unlocked:
			valid_unlocked.append(achievement_id)
	unlocked_achievement_ids = valid_unlocked
	var valid_claimed: Array[String] = []
	for achievement_id in claimed_achievement_ids:
		if not has_achievement(achievement_id):
			continue
		if achievement_id not in unlocked_achievement_ids:
			continue
		if achievement_id not in valid_claimed:
			valid_claimed.append(achievement_id)
	claimed_achievement_ids = valid_claimed
	for achievement_id in get_achievement_ids():
		var target := get_target(achievement_id)
		var progress := clampi(
			int(achievement_progress.get(achievement_id, 0)),
			0,
			target
		)
		if achievement_id in unlocked_achievement_ids:
			progress = target
		achievement_progress[achievement_id] = progress
	save_achievements()

func save_achievements() -> void:
	_progress_dirty = false
	var save_data: Dictionary = build_save_data()
	var io_result: Dictionary = SaveManager.write_save_data(
		"achievements",
		save_data
	)
	if not bool(io_result.get("success", false)):
		push_error(
			"AchievementManager: gagal menyimpan achievements.save."
		)

func load_achievements() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("achievements")
	if not bool(io_result.get("exists", false)):
		DebugLogger.system(str("Belum ada achievement save."))
		return
	if not bool(io_result.get("success", false)):
		push_warning(
			"AchievementManager: achievements.save tidak dapat dibuka."
		)
		return
	var save_data: Dictionary = io_result.get("data", {})
	var loaded_progress = save_data.get("progress", {})
	if loaded_progress is Dictionary:
		for raw_id in loaded_progress.keys():
			var achievement_id := str(raw_id)
			if not has_achievement(achievement_id):
				continue
			achievement_progress[achievement_id] = int(
				loaded_progress[raw_id]
			)
	unlocked_achievement_ids = _normalize_id_array(
		save_data.get("unlocked", [])
	)
	claimed_achievement_ids = _normalize_id_array(
		save_data.get("claimed", [])
	)

func _normalize_id_array(raw_value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not raw_value is Array:
		return normalized
	for raw_id in raw_value:
		var achievement_id := str(raw_id)
		if achievement_id.is_empty():
			continue
		if achievement_id not in normalized:
			normalized.append(achievement_id)
	return normalized

func print_achievement_status() -> void:
	DebugLogger.system(str("AchievementManager aktif!"))
	DebugLogger.system(str("Achievement Count: ", ACHIEVEMENTS.size()))
	DebugLogger.system(str("Achievement Unlocked: ", get_unlocked_count()))
	DebugLogger.system(str("Achievement Claimable: ", get_claimable_count()))

func _sync_extended_progress() -> void:
	_sync_journey_achievement_progress()

	var replay_seed: int = maxi(
		JourneyManager.cleared_stage_keys.size(),
		get_progress("trial_veteran_30")
	)
	for achievement_id: String in [
		"trial_veteran_5","trial_veteran_10","trial_veteran_30",
		"trial_veteran_60","trial_veteran_100"
	]:
		set_progress_at_least(achievement_id, replay_seed)

	var permanent_levels: int = (
		ProgressionManager.vitality_level
		+ ProgressionManager.sword_power_level
		+ ProgressionManager.swift_qi_level
	)
	for achievement_id: String in [
		"cultivation_adept","cultivation_master_20","cultivation_master_30"
	]:
		set_progress_at_least(achievement_id, permanent_levels)

	var boss_seed: int = maxi(
		JourneyManager.cleared_stage_keys.size(),
		get_progress("boss_slayer_10")
	)
	for achievement_id: String in ["boss_slayer_10","boss_slayer_25","boss_slayer_50"]:
		set_progress_at_least(achievement_id, boss_seed)

	var kill_seed: int = get_progress("enemy_slayer_1000")
	for achievement_id: String in ["enemy_slayer_500","enemy_slayer_2500","enemy_slayer_5000"]:
		set_progress_at_least(achievement_id, kill_seed)

	var level_seed: int = get_progress("cultivator_level_20")
	set_progress_at_least("cultivator_level_15", level_seed)
	set_progress_at_least("cultivator_level_25", level_seed)


func _sync_journey_achievement_progress() -> void:
	for raw_stage_key: Variant in STAGE_CLEAR_ACHIEVEMENTS.keys():
		var stage_key := str(raw_stage_key)
		if stage_key in JourneyManager.cleared_stage_keys:
			set_progress_at_least(str(STAGE_CLEAR_ACHIEVEMENTS[stage_key]), 1)

	var chapter_one_clears: int = _get_cleared_stage_count(1)
	set_progress_at_least("chapter_one_master", chapter_one_clears)
	set_progress_at_least("verdant_heaven_ascendant", chapter_one_clears)
	set_progress_at_least("chapter_two_master", _get_cleared_stage_count(2))
	set_progress_at_least("chapter_three_master", _get_cleared_stage_count(3))

	var unique_clears: int = JourneyManager.cleared_stage_keys.size()
	set_progress_at_least("jade_ascendant", unique_clears)
	set_progress_at_least("journey_complete_16", unique_clears)

func _get_cleared_stage_count(chapter_id: int) -> int:
	var cleared_count := 0
	for stage_id in JourneyManager.get_stage_ids(chapter_id):
		if JourneyManager.is_stage_cleared(chapter_id, int(stage_id)):
			cleared_count += 1
	return cleared_count

func _process(delta: float) -> void:
	_save_left -= delta
	if _save_left <= 0.0:
		_save_left = 2.0
		if _progress_dirty:
			save_achievements()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and _progress_dirty:
		save_achievements()

func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"progress": achievement_progress.duplicate(true),
		"unlocked": unlocked_achievement_ids.duplicate(),
		"claimed": claimed_achievement_ids.duplicate()
	}
