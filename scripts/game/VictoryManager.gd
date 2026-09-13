extends Node

## Victory Manager
## Menangani kemenangan satu kali saat Boss dikalahkan, menyelesaikan
## active Stage melalui JourneyManager, memberikan reward kemenangan,
## menghapus checkpoint run, dan menampilkan Victory UI.

var victory_processed: bool = false
var current_boss_reward_source_id: String = ""

@onready var enemy_spawner: Node = (
	get_parent().get_node_or_null("EnemySpawner")
)
@onready var checkpoint_manager: Node = (
	get_parent().get_node_or_null("CheckPointManager")
)
@onready var victory_ui: Node = (
	get_parent().get_node_or_null("VictoryUI")
)

func _ready() -> void:
	if enemy_spawner == null:
		push_error(str("ERROR: EnemySpawner tidak ditemukan di VictoryManager!"))
		return

	if not enemy_spawner.has_signal("boss_spawned_signal"):
		push_error(str("ERROR: EnemySpawner tidak memiliki boss_spawned_signal!"))
		return

	var boss_spawned_callable := Callable(
		self,
		"_on_boss_spawned"
	)

	if not enemy_spawner.is_connected(
		"boss_spawned_signal",
		boss_spawned_callable
	):
		enemy_spawner.connect(
			"boss_spawned_signal",
			boss_spawned_callable
		)

	DebugLogger.system(str("VictoryManager aktif!"))

func _on_boss_spawned(boss: Node) -> void:
	if boss == null:
		return

	current_boss_reward_source_id = resolve_boss_reward_source_id(
		boss
	)

	if not boss.has_signal("boss_defeated"):
		push_error(str("ERROR: Boss tidak memiliki signal boss_defeated!"))
		return

	var boss_defeated_callable := Callable(
		self,
		"_on_boss_defeated"
	)

	if not boss.is_connected(
		"boss_defeated",
		boss_defeated_callable
	):
		boss.connect(
			"boss_defeated",
			boss_defeated_callable
		)

	DebugLogger.system(str("VictoryManager terhubung ke Boss!"))
	DebugLogger.system(str(
		"Boss Reward Source terdeteksi: ",
		current_boss_reward_source_id
	))

func _on_boss_defeated() -> void:
	var other_end: Node = get_parent().get_node_or_null("GameOverManager")
	if other_end != null and bool(other_end.get("game_over_triggered")):
		return
	if victory_processed:
		return

	victory_processed = true
	AudioManager.play_sfx("victory")

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("VICTORY!"))
	DebugLogger.system(str("=========================================="))

	route_boss_defeat_reward()
	var stage_completion := complete_journey_stage()
	if not grant_victory_reward(stage_completion):
		get_tree().paused = true
		if victory_ui != null:
			victory_ui.call("show_victory")
		return
	if bool(stage_completion.get("completed", false)):
		JourneyManager.stage_completed.emit(int(stage_completion["chapter_id"]), int(stage_completion["stage_id"]), bool(stage_completion["was_first_clear"]))

	if (
		checkpoint_manager != null
		and checkpoint_manager.has_method("delete_checkpoint")
	):
		checkpoint_manager.call("delete_checkpoint")
	else:
		push_error(str("ERROR: CheckPointManager tidak valid!"))

	if victory_ui != null and victory_ui.has_method("show_victory"):
		victory_ui.call("show_victory")
	else:
		push_error(str("ERROR: VictoryUI tidak valid!"))

	get_tree().paused = true

## Menyelesaikan active Stage tanpa mengambil alih data milik
## JourneyManager. Reward kemenangan tetap diberikan pada test run yang
## dibuka langsung dari Level_1, tetapi progres Stage hanya dicatat jika
## run dimulai melalui flow Journey yang valid.
func complete_journey_stage() -> Dictionary:
	var completion_result: Dictionary = {
		"completed": false,
		"chapter_id": 0,
		"stage_id": 0,
		"was_first_clear": false
	}
	if not JourneyManager.has_active_run():
		DebugLogger.system(str(
			"WARNING: Victory tidak memiliki active Journey run. ",
			"Stage clear tidak dicatat."
		))
		return completion_result

	var completed_chapter_id: int = (
		JourneyManager.active_run_chapter_id
	)
	var completed_stage_id: int = (
		JourneyManager.active_run_stage_id
	)
	var unlocked_before: Array = (
		JourneyManager.unlocked_stage_keys.duplicate()
	)

	var was_first_clear: bool = (
		JourneyManager.complete_active_stage(false)
	)
	completion_result = {
		"completed": true,
		"chapter_id": completed_chapter_id,
		"stage_id": completed_stage_id,
		"was_first_clear": was_first_clear
	}
	var newly_unlocked_stage_keys: Array = []

	for stage_key in JourneyManager.unlocked_stage_keys:
		if stage_key not in unlocked_before:
			newly_unlocked_stage_keys.append(str(stage_key))

	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("STAGE CLEAR TERSIMPAN!"))
	DebugLogger.system(str("Chapter: ", completed_chapter_id))
	DebugLogger.system(str("Stage: ", completed_stage_id))
	DebugLogger.system(str("First Clear: ", was_first_clear))
	DebugLogger.system(str(
		"Stage Cleared: ",
		JourneyManager.is_stage_cleared(
			completed_chapter_id,
			completed_stage_id
		)
	))
	DebugLogger.system(str("New Stage Unlocked: ", newly_unlocked_stage_keys))
	DebugLogger.system(str("Active Run Dibersihkan: ", not JourneyManager.has_active_run()))
	DebugLogger.system(str("=========================================="))
	return completion_result

## Mengambil source ID eksplisit dari Boss. Nama node hanya menjadi
## fallback agar Boss lama tetap kompatibel sampai diberi ID permanen.
func resolve_boss_reward_source_id(boss: Node) -> String:
	if boss == null:
		return ""
	if boss.has_method("get_reward_source_id"):
		var explicit_source_id := str(
			boss.call("get_reward_source_id")
		)
		explicit_source_id = explicit_source_id.strip_edges()
		if not explicit_source_id.is_empty():
			return explicit_source_id
	return str(boss.name).to_snake_case()

## Menyelesaikan Boss sebagai reward source terpisah dari Stage Clear.
## Payload kosong adalah state valid sampai duplicate-to-shard/refinement
## siap menangani repeatable Boss drop tanpa memenuhi inventory mentah.
func route_boss_defeat_reward() -> bool:
	var source_id := current_boss_reward_source_id.strip_edges()
	if source_id.is_empty():
		push_error(
			"VictoryManager: Boss reward source tidak ditemukan."
		)
		return false
	var reward_defined := (
		RewardManager.has_boss_reward_definition(source_id)
	)
	var reward_data := RewardManager.get_boss_reward(source_id)
	var has_reward_payload := RewardManager.has_reward_payload(
		reward_data
	)
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("BOSS REWARD SOURCE RESOLVED!"))
	DebugLogger.system(str("Boss Source: ", source_id))
	DebugLogger.system(str("Reward Definition: ", reward_defined))
	DebugLogger.system(str("Additional Reward Payload: ", has_reward_payload))
	if not reward_defined:
		DebugLogger.system(str("Boss Reward Status: belum dikonfigurasi"))
		DebugLogger.system(str("=========================================="))
		return true
	if not has_reward_payload:
		DebugLogger.system(str("Boss Reward Status: menunggu duplicate refinement"))
		DebugLogger.system(str("=========================================="))
		return true
	var grant_result := RewardManager.grant_reward(
		RewardManager.SOURCE_BOSS_DEFEAT,
		source_id,
		reward_data
	)
	var reward_granted := bool(
		grant_result.get("success", false)
	)
	DebugLogger.system(str("Boss Reward Granted: ", reward_granted))
	DebugLogger.system(str("=========================================="))
	if not reward_granted:
		push_error(
			"VictoryManager: Boss reward gagal diberikan. "
			+ str(grant_result.get("error", "unknown error"))
		)
	return reward_granted

## Memilih reward first/repeat clear dari catalog RewardManager lalu
## menyalurkannya melalui satu transaction contract.
func grant_victory_reward(stage_completion: Dictionary) -> bool:
	var was_first_clear := false
	var clear_type := RewardManager.get_stage_clear_type(
		was_first_clear
	)
	var source_id := "direct_level_victory_" + clear_type
	var reward_data := RewardManager.get_default_stage_clear_reward(
		was_first_clear
	)
	if bool(stage_completion.get("completed", false)):
		var chapter_id := int(
			stage_completion.get("chapter_id", 0)
		)
		var stage_id := int(
			stage_completion.get("stage_id", 0)
		)
		was_first_clear = bool(
			stage_completion.get("was_first_clear", false)
		)
		clear_type = RewardManager.get_stage_clear_type(
			was_first_clear
		)
		source_id = (
			"chapter_%d_stage_%d_%s"
			% [chapter_id, stage_id, clear_type]
		)
		reward_data = RewardManager.get_stage_clear_reward(
			chapter_id,
			stage_id,
			was_first_clear
		)
	var grant_result := RewardManager.grant_reward(
		RewardManager.SOURCE_STAGE_CLEAR,
		source_id,
		reward_data,
		RewardManager.get_run_end_domains()
	)
	var reward_granted := bool(
		grant_result.get("success", false)
	)
	if not reward_granted:
		push_error(
			"VictoryManager: reward gagal diberikan. "
			+ str(grant_result.get("error", "unknown error"))
		)
		return false
	var spirit_stone_amount := int(
		reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)
	)
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("VICTORY REWARD ROUTED!"))
	DebugLogger.system(str("Reward Source: ", source_id))
	DebugLogger.system(str("Clear Type: ", clear_type))
	DebugLogger.system(str("Spirit Stone +", spirit_stone_amount))
	DebugLogger.system(str("Total Spirit Stone: ", ProgressionManager.spirit_stone))
	DebugLogger.system(str("=========================================="))
	return true
