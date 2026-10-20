extends SceneTree
## Actual authorities in an isolated user directory. No fake server credits.
var failures: int = 0
var checks: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("PREMIUM_REWARD_QA " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_premium_qa"): quit(2); return
	await create_timer(0.6).timeout
	var scene := Control.new()
	root.add_child(scene); current_scene = scene
	var achievements: Node = root.get_node("AchievementManager")
	var pavilion: Node = root.get_node("PavilionManager")
	var progression: Node = root.get_node("ProgressionManager")
	var saver: Node = root.get_node("SaveManager")
	var rewards: Node = root.get_node("RewardManager")
	var ops: Node = root.get_node("LiveOpsManager")
	var presenter: Node = root.get_node("RewardClaimResultPresenter")
	presenter._pending_entries.clear(); presenter._result_queue.clear(); presenter._close_popup()
	var before_jade: int = pavilion.get_local_celestial_jade()
	var before_stone: int = progression.spirit_stone
	achievements.set_progress_at_least("first_stage_clear",1)
	check(achievements.claim_reward("first_stage_clear"),"achievement claim succeeds")
	check(pavilion.get_local_celestial_jade() == before_jade + 10,"achievement premium applied once")
	check(progression.spirit_stone == before_stone + achievements.get_reward("first_stage_clear"),"stones unchanged from catalog")
	check(not achievements.claim_reward("first_stage_clear"),"spam does not regrant achievement")
	check(int(rewards.get_last_grant_result().applied_reward_data.get("celestial_jade",0)) == 10,"applied receipt includes Jade")
	var saved: Dictionary = saver.read_save_data("pavilion")
	check(int(saved.data.celestial_jade) == pavilion.get_local_celestial_jade(),"premium and claim persisted together")
	achievements.set_progress_at_least("first_boss_defeat",1)
	var stable_balance: int = pavilion.get_local_celestial_jade()
	saver.begin_save_write_barrier("premium_qa","controlled failure")
	check(not achievements.claim_reward("first_boss_defeat"),"blocked save rejects claim")
	check(not achievements.is_claimed("first_boss_defeat") and pavilion.get_local_celestial_jade() == stable_balance,"failed save never consumes or mints")
	saver.end_save_write_barrier("premium_qa")
	check(achievements.claim_reward("first_boss_defeat"),"retry recovers blocked achievement")
	await create_timer(0.3).timeout
	achievements.set_progress_at_least("art_master",1)
	check(achievements.claim_reward("art_master"),"third burst claim succeeds")
	await create_timer(1.2).timeout
	check(presenter._result_queue.is_empty(),"burst produces one result, no popup queue")
	check(int(presenter._active_result.get("claim_count",0)) == 3,"visible summary aggregates every claim")
	check(int(presenter._active_result.get("reward_data",{}).get("celestial_jade",0)) == 40,"summary exact applied Jade")
	presenter._close_popup(); presenter._pending_entries.clear(); presenter._result_queue.clear()
	var login_before: int = pavilion.get_local_celestial_jade()
	check(ops.claim_login_day(1),"login day one succeeds")
	check(pavilion.get_local_celestial_jade() == login_before+5,"login earned Jade committed")
	check(not ops.claim_login_day(1),"login replay blocked")
	check(int(ops.get_login_reward(7).celestial_jade) == 25 and int(ops.get_login_reward(7).pavilion_seal) == 1,"final login includes disclosed seal")
	check(rewards.get_reward_summary(ops.get_login_reward(7)).contains("Jade"),"universal reward copy includes premium")
	var quests: Node = root.get_node("DailyQuestManager")
	var ids: Array[String] = quests.get_daily_quest_ids()
	for id: String in ids: quests.set_progress_at_least(id,quests.get_target(id))
	var preview: Dictionary = pavilion.get_daily_completion_reward_preview()
	var daily_before: int = pavilion.get_local_celestial_jade()
	check(int(preview.get("celestial_jade",0)) == 20,"existing daily cadence preview is explicit")
	check(quests.claim_all_rewards() == ids.size(),"claim all grants every completed quest")
	await create_timer(0.3).timeout
	check(pavilion.get_local_celestial_jade() == daily_before+20,"daily completion grants existing amount exactly once")
	check(not pavilion._sync_daily_completion_bonus(),"cadence replay blocked")
	check(pavilion.get_daily_completion_reward_preview().is_empty(),"completed bonus no longer advertised")
	check(not saver.has_pending_transaction(),"no pending save journal")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	if current_scene != null: current_scene.queue_free(); current_scene = null
	for index: int in 8: await process_frame
	print("PREMIUM_REWARD_RELIABILITY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
