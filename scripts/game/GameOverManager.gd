extends Node

## Game Over Manager
## Menangani akhir run saat Player mati, reward kegagalan,
## pembersihan active Journey run, penghapusan checkpoint,
## dan tampilan Game Over.

var game_over_triggered: bool = false
var defeat_finalized: bool = false
var rewarded_revive_pending: bool = false

@onready var player = get_tree().get_first_node_in_group("player")
@onready var checkpoint_manager = get_parent().get_node_or_null("CheckPointManager")
@onready var game_over_ui = get_parent().get_node_or_null("GameOverUI")
@onready var wave_manager = get_parent().get_node_or_null("WaveManager")

func _ready() -> void:
	if player == null:
		push_error(str("ERROR: Player tidak ditemukan di GameOverManager!"))
		return
	var player_health = player.get_node_or_null("PlayerHealth")
	if player_health == null:
		push_error(str("ERROR: PlayerHealth tidak ditemukan di GameOverManager!"))
		return
	player_health.died.connect(_on_player_died)
	DebugLogger.system(str("GameOverManager aktif!"))

## Menangani Game Over satu kali saat Player mati.
func _on_player_died() -> void:
	var other_end: Node = get_parent().get_node_or_null("VictoryManager")
	if other_end != null and bool(other_end.get("victory_processed")):
		return
	if game_over_triggered:
		return

	game_over_triggered = true
	defeat_finalized = false
	rewarded_revive_pending = false

	AudioManager.play_sfx("defeat")
	if player is Node2D:
		CombatFeedback.death(player as Node2D, false, false)
		var player_sprite: AnimatedSprite2D = (
			player.get_node_or_null("AnimatedSprite2D")
			as AnimatedSprite2D
		)
		if player_sprite != null:
			player_sprite.visible = false

	DebugLogger.system("==========================================")
	DebugLogger.system("GAME OVER • REVIVE WINDOW")
	DebugLogger.system("==========================================")

	if checkpoint_manager != null:
		if not bool(checkpoint_manager.mark_defeat_pending()):
			push_warning(
				"GameOverManager: gagal menandai defeat_pending; "
				+ "checkpoint akan dihapus untuk mencegah Continue exploit."
			)
			checkpoint_manager.delete_checkpoint()
	else:
		push_error("ERROR: CheckpointManager tidak ditemukan di GameOverManager!")

	if game_over_ui != null:
		game_over_ui.show_game_over()
	else:
		push_error("ERROR: GameOverUI tidak ditemukan!")

	get_tree().paused = true


func can_request_rewarded_revive() -> bool:
	if (
		not game_over_triggered
		or defeat_finalized
		or rewarded_revive_pending
		or SaveManager.is_progress_read_only()
	):
		return false
	if checkpoint_manager == null:
		return false
	return bool(checkpoint_manager.can_use_rewarded_revive())


func has_rewarded_revive_been_used() -> bool:
	if checkpoint_manager == null:
		return false
	return not bool(checkpoint_manager.can_use_rewarded_revive())


func prepare_rewarded_revive() -> bool:
	if not can_request_rewarded_revive():
		return false
	rewarded_revive_pending = true
	return true


func cancel_pending_rewarded_revive() -> void:
	rewarded_revive_pending = false


func apply_verified_rewarded_revive(grant_id: String) -> Dictionary:
	var normalized_grant_id: String = grant_id.strip_edges()
	if normalized_grant_id.is_empty():
		return {
			"success": false,
			"error": "Verified revive grant id is required."
		}
	if not rewarded_revive_pending:
		return {
			"success": false,
			"error": "No rewarded revive request is pending."
		}
	if (
		defeat_finalized
		or not game_over_triggered
	):
		rewarded_revive_pending = false
		return {
			"success": false,
			"error": "Rewarded revive is no longer available."
		}
	if checkpoint_manager == null:
		rewarded_revive_pending = false
		return {
			"success": false,
			"error": "Checkpoint manager is unavailable."
		}

	var player_health: PlayerHealth = (
		player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)
	if player_health == null:
		rewarded_revive_pending = false
		return {
			"success": false,
			"error": "Player health is unavailable."
		}

	if not bool(checkpoint_manager.can_use_rewarded_revive()):
		rewarded_revive_pending = false
		return {
			"success": false,
			"error": "Rewarded revive was already used for this run."
		}
	if not player_health.revive_from_rewarded():
		rewarded_revive_pending = false
		return {
			"success": false,
			"error": "Player could not be revived."
		}

	checkpoint_manager.mark_rewarded_revive_used()
	checkpoint_manager.clear_defeat_pending()
	game_over_triggered = false
	defeat_finalized = false
	rewarded_revive_pending = false

	# Persist the revived state immediately. If persistence fails, remove the
	# checkpoint rather than leaving a resumable snapshot that could restore a
	# second ad revive after force-close.
	if not bool(checkpoint_manager.save_checkpoint()):
		push_warning(
			"GameOverManager: revived checkpoint gagal disimpan; "
			+ "Continue dinonaktifkan untuk run ini."
		)
		checkpoint_manager.delete_checkpoint()
		checkpoint_manager.mark_rewarded_revive_used()

	if game_over_ui != null and game_over_ui.has_method("hide_after_revive"):
		game_over_ui.hide_after_revive()
	else:
		if game_over_ui != null:
			game_over_ui.hide()

	get_tree().paused = false

	DebugLogger.system(str(
		"REWARDED REVIVE APPLIED | Grant: ",
		normalized_grant_id
	))
	return {
		"success": true,
		"grant_id": normalized_grant_id,
		"health_ratio": PlayerHealth.REWARDED_REVIVE_HEALTH_RATIO,
		"protection_msec": PlayerHealth.REWARDED_REVIVE_INVULNERABILITY_MSEC
	}


func finalize_defeat() -> bool:
	if defeat_finalized:
		return true

	rewarded_revive_pending = false
	if not grant_failure_reward():
		return false

	_clear_active_journey_run()
	if checkpoint_manager != null:
		DebugLogger.system("CheckpointManager: final defeat cleanup.")
		if not bool(checkpoint_manager.delete_checkpoint()):
			return false

	defeat_finalized = true
	return true


## Membersihkan identitas Journey run saat run berakhir karena kematian.
func _clear_active_journey_run() -> void:
	if not JourneyManager.has_active_run():
		DebugLogger.system(str("Journey active run sudah kosong."))
		return
	var ended_chapter_id := JourneyManager.active_run_chapter_id
	var ended_stage_id := JourneyManager.active_run_stage_id
	JourneyManager.clear_active_run()
	DebugLogger.system(str(
		"Journey active run dibersihkan: Chapter ",
		ended_chapter_id,
		" Stage ",
		ended_stage_id,
		" | Active Run: ",
		JourneyManager.has_active_run()
	))

## Menyalurkan reward parsial berdasarkan wave melalui RewardManager.
func grant_failure_reward() -> bool:
	if wave_manager == null:
		push_error(str(
			"ERROR: WaveManager tidak ditemukan untuk reward Game Over!"
		))
		return false
	var reached_wave := int(wave_manager.current_wave)
	var reward_tier_id := (
		RewardManager.get_game_over_reward_tier_id(reached_wave)
	)
	var source_id := get_failure_reward_source_id(
		reached_wave,
		reward_tier_id
	)
	var reward_data := RewardManager.get_game_over_reward(
		reached_wave
	)
	var spirit_stone_amount := int(
		reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)
	)
	DebugLogger.system(str("=========================================="))
	DebugLogger.system(str("GAME OVER REWARD ROUTED!"))
	DebugLogger.system(str("Reward Source: ", source_id))
	DebugLogger.system(str("Reward Tier: ", reward_tier_id))
	DebugLogger.system(str("Wave Reached: ", reached_wave))
	if not RewardManager.has_reward_payload(reward_data):
		DebugLogger.system(str("Spirit Stone +0"))
		DebugLogger.system(str("Reward Status: tidak ada reward untuk wave ini"))
		return SaveManager.write_save_batch(RewardManager.get_run_end_domains())
	var grant_result := RewardManager.grant_reward(
		RewardManager.SOURCE_GAME_OVER,
		source_id,
		reward_data,
		RewardManager.get_run_end_domains()
	)
	var reward_granted := bool(
		grant_result.get("success", false)
	)
	if not reward_granted:
		push_error(
			"GameOverManager: reward gagal diberikan. "
			+ str(grant_result.get("error", "unknown error"))
		)
		DebugLogger.system(str("=========================================="))
		return false
	DebugLogger.system(str("Spirit Stone +", spirit_stone_amount))
	DebugLogger.system(str("Total Spirit Stone: ", ProgressionManager.spirit_stone))
	DebugLogger.system(str("=========================================="))
	return true

## Membentuk identitas transaksi sebelum active Journey run dibersihkan.
func get_failure_reward_source_id(
	wave: int,
	reward_tier_id: String
) -> String:
	if JourneyManager.has_active_run():
		return (
			"chapter_%d_stage_%d_wave_%d_%s"
			% [
				JourneyManager.active_run_chapter_id,
				JourneyManager.active_run_stage_id,
				wave,
				reward_tier_id
			]
		)
	return "direct_level_wave_%d_%s" % [wave, reward_tier_id]

## Compatibility wrapper untuk caller/test lama tanpa memiliki nominal lokal.
func get_failure_reward(wave: int) -> int:
	var reward_data := RewardManager.get_game_over_reward(wave)
	return int(
		reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)
	)
