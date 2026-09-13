extends Node

## Daily Quest Manager
## Mengelola definisi Daily Quest, progress harian, status completion,
## status reward claim, dan reset aman berdasarkan tanggal lokal perangkat.
## Gameplay event hook terhubung secara event-driven melalui signal existing.

signal daily_quest_progressed(
	quest_id: String,
	current_progress: int,
	target_progress: int
)
signal daily_quest_completed(quest_id: String)
signal daily_quest_claimed(quest_id: String, spirit_stone_reward: int)
signal daily_quests_reset(date_key: String)

const SAVE_PATH: String = "user://daily_quests.save"
const SAVE_VERSION: int = 1

const DAILY_QUESTS: Dictionary = {
	"defeat_20_enemies": {
		"title": "Daily Extermination",
		"description": "Defeat 20 enemies.",
		"category": "combat",
		"target": 20,
		"reward": 25
	},
	"reach_level_5": {
		"title": "Daily Cultivation",
		"description": "Reach Level 5 during a run.",
		"category": "progression",
		"target": 5,
		"reward": 25
	},
	"clear_1_stage": {
		"title": "Daily Ascension",
		"description": "Clear 1 stage.",
		"category": "journey",
		"target": 1,
		"reward": 50
	},
	"defeat_50_enemies": {"title": "Bamboo Patrol", "description": "Defeat 50 enemies.", "category": "combat", "target": 50, "reward": 35},
	"defeat_100_enemies": {"title": "Guard the Valley", "description": "Defeat 100 enemies.", "category": "combat", "target": 100, "reward": 45},
	"reach_level_7": {"title": "Quiet Comprehension", "description": "Reach Level 7 during a run.", "category": "progression", "target": 7, "reward": 35},
	"reach_level_10": {"title": "Deep Meditation", "description": "Reach Level 10 during a run.", "category": "progression", "target": 10, "reward": 45},
	"clear_2_stages": {"title": "Walk the Jade Path", "description": "Clear 2 stages, including repeats.", "category": "journey", "target": 2, "reward": 70},
	"clear_3_stages": {"title": "Three Seals", "description": "Clear 3 stages, including repeats.", "category": "journey", "target": 3, "reward": 90}
}

const LEGACY_QUEST_IDS: Array[String] = ["defeat_20_enemies", "reach_level_5", "clear_1_stage"]
var active_quest_ids: Array[String] = LEGACY_QUEST_IDS.duplicate()
var _date_check_left: float = 30.0
var _save_left: float = 2.0
var _progress_dirty: bool = false
var active_date_key: String = ""
var quest_progress: Dictionary = {}
var completed_quest_ids: Array[String] = []
var claimed_quest_ids: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_progress_entries()
	load_daily_quests()
	_apply_daily_reset_if_needed()
	_validate_loaded_state()
	_connect_runtime_hooks()
	save_daily_quests()
	print_daily_quest_status()

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
			"DailyQuestManager: JourneyManager tidak memiliki "
			+ "signal stage_completed."
		)

func _on_tree_node_added(node: Node) -> void:
	_try_connect_enemy_spawner(node)
	_try_connect_player(node)

func _try_connect_enemy_spawner(node: Node) -> void:
	if node == null:
		return
	if node.name != "EnemySpawner":
		return
	if not node.has_signal("enemy_killed"):
		return
	var enemy_killed_callable := Callable(
		self,
		"_on_enemy_killed"
	)
	if node.is_connected(
		"enemy_killed",
		enemy_killed_callable
	):
		return
	node.connect(
		"enemy_killed",
		enemy_killed_callable
	)
	DebugLogger.system(str("DailyQuestManager terhubung ke EnemySpawner."))

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
	if node.is_connected(
		"level_changed",
		level_changed_callable
	):
		return
	node.connect(
		"level_changed",
		level_changed_callable
	)
	DebugLogger.system(str("DailyQuestManager terhubung ke Player level_changed."))

func _on_enemy_killed() -> void:
	_progress_category("combat", 1, false)

func _on_player_level_changed(new_level: int) -> void:
	_progress_category("progression", new_level, true)

func _on_stage_completed(_chapter_id: int, _stage_id: int, _was_first_clear: bool) -> void:
	_progress_category("journey", 1, false)

func _progress_category(category: String, value: int, at_least: bool) -> void:
	refresh_daily_date()
	for quest_id in get_daily_quest_ids():
		if str(DAILY_QUESTS[quest_id].get("category", "")) != category:
			continue
		if at_least:
			set_progress_at_least(quest_id, value)
		else:
			add_progress(quest_id, value)

func get_daily_quest_ids() -> Array[String]:
	return active_quest_ids.duplicate()

func has_daily_quest(quest_id: String) -> bool:
	return DAILY_QUESTS.has(quest_id)

func get_daily_quest_data(quest_id: String) -> Dictionary:
	if not has_daily_quest(quest_id):
		return {}
	var data: Dictionary = DAILY_QUESTS[quest_id]
	return data.duplicate(true)

func get_progress(quest_id: String) -> int:
	if not has_daily_quest(quest_id):
		return 0
	return int(quest_progress.get(quest_id, 0))

func get_target(quest_id: String) -> int:
	if not has_daily_quest(quest_id):
		return 0
	var data: Dictionary = DAILY_QUESTS[quest_id]
	return max(int(data.get("target", 0)), 0)

func get_reward(quest_id: String) -> int:
	if not has_daily_quest(quest_id):
		return 0
	var data: Dictionary = DAILY_QUESTS[quest_id]
	return max(int(data.get("reward", 0)), 0)

func is_completed(quest_id: String) -> bool:
	return quest_id in completed_quest_ids

func is_claimed(quest_id: String) -> bool:
	return quest_id in claimed_quest_ids

func is_claimable(quest_id: String) -> bool:
	return quest_id in active_quest_ids and is_completed(quest_id) and not is_claimed(quest_id)

func get_completed_count() -> int:
	return completed_quest_ids.size()

func get_claimable_count() -> int:
	return get_claimable_ids().size()

func get_claimable_ids() -> Array[String]:
	var claimable_ids: Array[String] = []
	for quest_id in completed_quest_ids:
		if is_claimable(quest_id):
			claimable_ids.append(quest_id)
	claimable_ids.sort()
	return claimable_ids

func get_total_claimable_reward() -> int:
	var total_reward: int = 0
	for quest_id in get_claimable_ids():
		total_reward += get_reward(quest_id)
	return total_reward

func add_progress(quest_id: String, amount: int = 1) -> bool:
	if quest_id not in active_quest_ids:
		return false
	if amount <= 0:
		return false
	if not has_daily_quest(quest_id):
		push_warning(
			"DailyQuestManager: quest tidak ditemukan: "
			+ quest_id
		)
		return false
	if is_completed(quest_id):
		return false
	var target := get_target(quest_id)
	if target <= 0:
		return false
	var previous_progress := get_progress(quest_id)
	var new_progress := mini(
		previous_progress + amount,
		target
	)
	if new_progress == previous_progress:
		return false
	quest_progress[quest_id] = new_progress
	daily_quest_progressed.emit(
		quest_id,
		new_progress,
		target
	)
	if new_progress >= target:
		_complete_daily_quest(quest_id)
	else:
		_progress_dirty = true
	return true

func set_progress_at_least(
	quest_id: String,
	progress_value: int
) -> bool:
	if quest_id not in active_quest_ids:
		return false
	if progress_value <= 0:
		return false
	if not has_daily_quest(quest_id):
		push_warning(
			"DailyQuestManager: quest tidak ditemukan: "
			+ quest_id
		)
		return false
	if is_completed(quest_id):
		return false
	var target := get_target(quest_id)
	if target <= 0:
		return false
	var previous_progress := get_progress(quest_id)
	var new_progress := mini(
		maxi(progress_value, previous_progress),
		target
	)
	if new_progress == previous_progress:
		return false
	quest_progress[quest_id] = new_progress
	daily_quest_progressed.emit(
		quest_id,
		new_progress,
		target
	)
	if new_progress >= target:
		_complete_daily_quest(quest_id)
	else:
		_progress_dirty = true
	return true

func claim_reward(quest_id: String) -> bool:
	refresh_daily_date()
	if not is_claimable(quest_id):
		return false
	var reward := get_reward(quest_id)
	var source_id := active_date_key + "_" + quest_id
	var reward_data := RewardManager.create_reward_data(reward)
	if not RewardManager.is_valid_reward(
		RewardManager.SOURCE_DAILY_QUEST,
		source_id,
		reward_data
	):
		push_error(
			"DailyQuestManager: reward tidak valid untuk "
			+ quest_id
		)
		return false
	claimed_quest_ids.append(quest_id)
	var grant_result := RewardManager.grant_reward(
		RewardManager.SOURCE_DAILY_QUEST,
		source_id,
		reward_data,
		{"daily_quests": build_save_data()}
	)
	if not bool(grant_result.get("success", false)):
		claimed_quest_ids.erase(quest_id)
		push_error(
			"DailyQuestManager: reward gagal diberikan. "
			+ str(grant_result.get("error", "unknown error"))
		)
		return false
	daily_quest_claimed.emit(quest_id, reward)
	DebugLogger.system(str(
		"Daily Quest reward diklaim: ",
		quest_id,
		" | Spirit Stone +",
		reward
	))
	return true

func claim_all_rewards() -> int:
	var claimable_ids := get_claimable_ids()
	if claimable_ids.is_empty():
		return 0
	var claimed_count: int = 0
	for quest_id in claimable_ids:
		if claim_reward(quest_id):
			claimed_count += 1
	return claimed_count

func _complete_daily_quest(quest_id: String) -> void:
	if is_completed(quest_id):
		return
	completed_quest_ids.append(quest_id)
	quest_progress[quest_id] = get_target(quest_id)
	save_daily_quests()
	daily_quest_completed.emit(quest_id)
	var data := get_daily_quest_data(quest_id)
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("DAILY QUEST COMPLETED!"))
	DebugLogger.system(str("ID: ", quest_id))
	DebugLogger.system(str("Title: ", data.get("title", quest_id)))
	DebugLogger.system(str("Reward: ", get_reward(quest_id), " Spirit Stone"))
	DebugLogger.system(str("=========================================="))

func _initialize_progress_entries() -> void:
	for quest_id in get_daily_quest_ids():
		if not quest_progress.has(quest_id):
			quest_progress[quest_id] = 0

func _apply_daily_reset_if_needed() -> void:
	var current_date_key := get_current_date_key()
	if not active_date_key.is_empty() and active_date_key >= current_date_key:
		return
	active_date_key = current_date_key
	active_quest_ids = _pick_quests_for_date(active_date_key)
	quest_progress.clear()
	completed_quest_ids.clear()
	claimed_quest_ids.clear()
	_initialize_progress_entries()
	daily_quests_reset.emit(active_date_key)
	DebugLogger.system(str(
		"DailyQuestManager reset untuk tanggal: ",
		active_date_key
	))

func _validate_loaded_state() -> void:
	var valid_completed: Array[String] = []
	for quest_id in completed_quest_ids:
		if not has_daily_quest(quest_id):
			continue
		if quest_id not in valid_completed:
			valid_completed.append(quest_id)
	completed_quest_ids = valid_completed
	var valid_claimed: Array[String] = []
	for quest_id in claimed_quest_ids:
		if not has_daily_quest(quest_id):
			continue
		if quest_id not in completed_quest_ids:
			continue
		if quest_id not in valid_claimed:
			valid_claimed.append(quest_id)
	claimed_quest_ids = valid_claimed
	for quest_id in get_daily_quest_ids():
		var target := get_target(quest_id)
		var progress := clampi(
			int(quest_progress.get(quest_id, 0)),
			0,
			target
		)
		if quest_id in completed_quest_ids:
			progress = target
		quest_progress[quest_id] = progress

func get_current_date_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0))
	]

func save_daily_quests() -> void:
	_progress_dirty = false
	var save_data: Dictionary = build_save_data()
	var io_result: Dictionary = SaveManager.write_save_data(
		"daily_quests",
		save_data
	)
	if not bool(io_result.get("success", false)):
		push_error(
			"DailyQuestManager: gagal menyimpan daily_quests.save."
		)

func load_daily_quests() -> void:
	var io_result: Dictionary = SaveManager.read_save_data("daily_quests")
	if not bool(io_result.get("exists", false)):
		DebugLogger.system(str("Belum ada daily quest save."))
		return
	if not bool(io_result.get("success", false)):
		push_warning(
			"DailyQuestManager: daily_quests.save tidak dapat dibuka."
		)
		return
	var save_data: Dictionary = io_result.get("data", {})
	active_date_key = str(
		save_data.get("date_key", "")
	)
	var saved_active: Array[String] = _normalize_id_array(save_data.get("active_quest_ids", LEGACY_QUEST_IDS))
	active_quest_ids.clear()
	for quest_id in saved_active:
		if has_daily_quest(quest_id) and quest_id not in active_quest_ids:
			active_quest_ids.append(quest_id)
	if active_quest_ids.size() != 3:
		active_quest_ids = LEGACY_QUEST_IDS.duplicate()
	var loaded_progress = save_data.get("progress", {})
	if loaded_progress is Dictionary:
		for raw_id in loaded_progress.keys():
			var quest_id := str(raw_id)
			if not has_daily_quest(quest_id):
				continue
			quest_progress[quest_id] = int(
				loaded_progress[raw_id]
			)
	completed_quest_ids = _normalize_id_array(
		save_data.get("completed", [])
	)
	claimed_quest_ids = _normalize_id_array(
		save_data.get("claimed", [])
	)

func _normalize_id_array(raw_value: Variant) -> Array[String]:
	var normalized: Array[String] = []
	if not raw_value is Array:
		return normalized
	for raw_id in raw_value:
		var quest_id := str(raw_id)
		if quest_id.is_empty():
			continue
		if quest_id not in normalized:
			normalized.append(quest_id)
	return normalized

func print_daily_quest_status() -> void:
	DebugLogger.system(str("DailyQuestManager aktif!"))
	DebugLogger.system(str("Daily Date: ", active_date_key))
	DebugLogger.system(str("Daily Quest Count: ", DAILY_QUESTS.size()))
	DebugLogger.system(str("Daily Quest Completed: ", get_completed_count()))
	DebugLogger.system(str("Daily Quest Claimable: ", get_claimable_count()))

func _pick_quests_for_date(date_key: String) -> Array[String]:
	# Stable across reopen/reinstall; no global RNG is consumed by daily rotation.
	var result: Array[String] = []
	var groups: Array = [
		["defeat_20_enemies", "defeat_50_enemies", "defeat_100_enemies"],
		["reach_level_5", "reach_level_7", "reach_level_10"],
		["clear_1_stage", "clear_2_stages", "clear_3_stages"]
	]
	var seed_value: int = 0
	for byte in date_key.to_utf8_buffer():
		seed_value = (seed_value * 31 + int(byte)) % 100003
	for index in range(groups.size()):
		result.append(str(groups[index][(seed_value + index * 5) % 3]))
	return result

func refresh_daily_date() -> void:
	var previous: String = active_date_key
	_apply_daily_reset_if_needed()
	if previous != active_date_key:
		save_daily_quests()

func _process(delta: float) -> void:
	_date_check_left -= delta
	_save_left -= delta
	if _date_check_left <= 0.0:
		_date_check_left = 30.0
		refresh_daily_date()
	if _save_left <= 0.0:
		_save_left = 2.0
		if _progress_dirty:
			save_daily_quests()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST] and _progress_dirty:
		save_daily_quests()

func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"date_key": active_date_key,
		"active_quest_ids": active_quest_ids.duplicate(),
		"progress": quest_progress.duplicate(true),
		"completed": completed_quest_ids.duplicate(),
		"claimed": claimed_quest_ids.duplicate()
	}
