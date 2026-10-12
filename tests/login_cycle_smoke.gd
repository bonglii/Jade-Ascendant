extends SceneTree

## Run only in a disposable QA project with user:// isolated before autoloads.
## See docs/checkpoints/LOGIN_CYCLE_2026-10-12.md for the tested environment.
var checks: int = 0
var failures: int = 0
var live_ops: Node
var reentrant_day: int = 0
var rewardmanager: Variant
var savemanager: Variant
var pavilionmanager: Variant
var inventorymanager: Variant
var progressionmanager: Variant

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("LOGIN_CYCLE_FAILURE " + tag)

func _reward_callback(_source: String, _id: String, _reward: Dictionary) -> void:
	if reentrant_day == 0:
		return
	_check(not live_ops.claim_login_day(reentrant_day), "reentrant claim rejected")
	_check(not live_ops._record_active_date("2099-01-30"), "reentrant rollover rejected")

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("jade_login_cycle_qa"):
		push_error("LOGIN_CYCLE_QA requires isolated user:// before startup")
		quit(2)
		return
	await create_timer(0.5).timeout
	live_ops = root.get_node("LiveOpsManager")
	progressionmanager = root.get_node("ProgressionManager")
	inventorymanager = root.get_node("InventoryManager")
	pavilionmanager = root.get_node("PavilionManager")
	savemanager = root.get_node("SaveManager")
	rewardmanager = root.get_node("RewardManager")
	live_ops.set_process(false)
	if "--verify-restart" in OS.get_cmdline_user_args():
		_check(live_ops.get_login_cycle_id() == 4, "restart cycle identity")
		_check(live_ops.get_active_login_day_count() == 7, "restart day")
		_check(live_ops.is_new_player_event_complete(), "restart claims")
		var stones: int = progressionmanager.spirit_stone
		_check(not live_ops.claim_login_day(7), "restart duplicate rejected")
		_check(progressionmanager.spirit_stone == stones, "restart no extra reward")
		_check(live_ops._record_active_date("2099-01-29"), "restart next cycle")
		_check(live_ops.get_login_cycle_id() == 5 and live_ops.get_active_login_day_count() == 1, "restart rollover to day 1")
		_check(not live_ops.is_login_day_claimed(1), "restart new cycle unclaimed")
		_finish()
		return

	# A completed old cycle retries rollover after a blocked activity write,
	# even though the local date has not changed between polling attempts.
	var old_ledger: Array[String] = []
	for day: int in range(1, 8):
		old_ledger.append(live_ops.ACTIVE_PREFIX + "2000-01-%02d" % day)
		old_ledger.append(live_ops.LOGIN_CLAIM_PREFIX + str(day))
	_check(live_ops._commit_ledger(old_ledger), "seed old completed cycle")
	savemanager.begin_save_write_barrier("login_cycle_qa", "isolated test")
	live_ops._process(20.0)
	_check(live_ops.get_login_cycle_id() == 1, "poll blocked save retains cycle")
	savemanager.end_save_write_barrier("login_cycle_qa")
	live_ops._process(20.0)
	_check(live_ops.get_login_cycle_id() == 2 and live_ops.get_active_login_day_count() == 1, "same-date poll retries rollover")
	live_ops._process(20.0)
	_check(live_ops.get_active_login_day_count() == 1, "poll idempotent")
	old_ledger.erase(live_ops.LOGIN_CLAIM_PREFIX + "7")
	_check(live_ops._commit_ledger(old_ledger), "seed overdue final reward")
	_check(live_ops.claim_login_day(7), "overdue final claim")
	_check(live_ops.get_login_cycle_id() == 2 and live_ops.get_active_login_day_count() == 1, "overdue final claim rolls today")
	_check(live_ops.get_login_claimable_count() == 1, "new day 1 ready after overdue claim")
	_check(live_ops.LOGIN_CLAIM_PREFIX + "7" in live_ops._get_ledger(), "overdue reward marker retained")

	# Legacy finished activity with one unclaimed reward; preserve unrelated mail.
	var ledger: Array[String] = ["liveops:mail:read:celestial_path_notice"]
	for day: int in range(1, 8):
		ledger.append(live_ops.ACTIVE_PREFIX + "2099-01-%02d" % day)
		if day < 7:
			ledger.append(live_ops.LOGIN_CLAIM_PREFIX + str(day))
	_check(live_ops._commit_ledger(ledger), "seed legacy save")
	_check(live_ops.get_login_cycle_id() == 1, "legacy cycle")
	_check(live_ops.get_active_login_day_count() == 7, "legacy progress")
	_check(live_ops.is_login_day_claimed(1), "legacy claim preserved")
	_check(not live_ops._record_active_date("2099-01-08"), "unclaimed reward holds cycle")
	_check(not live_ops.claim_login_day(0) and not live_ops.claim_login_day(8), "invalid claim day")
	_check(not live_ops._record_active_date("2099-02-30"), "invalid date")
	_check(not live_ops._record_active_date("2099-01-06"), "backward date")

	rewardmanager.reward_granted.connect(_reward_callback)
	reentrant_day = 7
	_check(live_ops.claim_login_day(7), "legacy final reward")
	reentrant_day = 0
	_check(live_ops.is_new_player_event_complete(), "legacy complete")
	_check(not live_ops._record_active_date("2099-01-07"), "same-day rollover denied")

	_check(change_scene_to_file("res://scenes/ui/new_player_event_screen.tscn") == OK, "open event UI")
	await process_frame
	await process_frame
	var event_screen: Control = current_scene
	_check(event_screen._displayed_cycle_id == 1, "UI legacy cycle")

	savemanager.begin_save_write_barrier("login_cycle_qa", "isolated test")
	_check(not live_ops._record_active_date("2099-01-08"), "read-only rollover denied")
	_check(live_ops.get_login_cycle_id() == 1, "failed rollover retains cycle")
	savemanager.end_save_write_barrier("login_cycle_qa")

	# Three full repeating cycles, including claim retry and journal consistency.
	for cycle: int in range(2, 5):
		for day: int in range(1, 8):
			var date_key: String = "2099-01-%02d" % ((cycle - 1) * 7 + day)
			_check(live_ops._record_active_date(date_key), "record cycle/day")
			_check(live_ops.get_login_cycle_id() == cycle, "cycle identity")
			_check(live_ops.get_active_login_day_count() == day, "cycle day")
			_check(not live_ops._record_active_date(date_key), "duplicate date")
			_check(not live_ops.is_login_day_claimed(day), "fresh scoped claim")
			if day == 1:
				_check(event_screen._selected_day == 1 and event_screen._displayed_cycle_id == cycle, "open UI rollover selects day 1")
				_check(not live_ops.is_login_day_unlocked(2), "next reward locked")
				_check(not live_ops.claim_login_day(2), "locked claim denied")
				var before: Dictionary = pavilionmanager.state.duplicate(true)
				savemanager.begin_save_write_barrier("login_cycle_qa", "isolated test")
				_check(not live_ops.claim_login_day(1), "read-only claim denied")
				_check(pavilionmanager.state == before, "failed claim keeps ledger")
				savemanager.end_save_write_barrier("login_cycle_qa")
			var reward: Dictionary = live_ops.get_login_reward(day)
			var stones: int = progressionmanager.spirit_stone
			var shards: int = inventorymanager.get_item_count("refinement_shard")
			reentrant_day = day
			_check(live_ops.claim_login_day(day), "claim reward")
			reentrant_day = 0
			_check(progressionmanager.spirit_stone == stones + int(reward.spirit_stone), "exact stone delta")
			_check(inventorymanager.get_item_count("refinement_shard") == shards + int(reward.items.get("refinement_shard", 0)), "exact shard delta")
			_check(not live_ops.claim_login_day(day), "duplicate claim denied")
			_check(progressionmanager.spirit_stone == stones + int(reward.spirit_stone), "duplicate adds nothing")
			var read: Dictionary = savemanager.read_save_data("pavilion")
			_check(read.get("success", false) and read.data == pavilionmanager.state, "disk/runtime consistent")
			_check(live_ops.LOGIN_CYCLE_CLAIM_PREFIX + "%d:%d" % [cycle, day] in read.data.claimed_milestone_ids, "scoped marker persisted")
			_check(not savemanager.has_pending_transaction(), "journal cleared")
		_check(live_ops.is_new_player_event_complete(), "cycle complete")
		_check(not live_ops._record_active_date("2099-01-%02d" % (cycle * 7)), "complete cycle cannot reset same day")
	_check("liveops:mail:read:celestial_path_notice" in live_ops._get_ledger(), "unrelated marker preserved")
	_check(live_ops.LOGIN_CLAIM_PREFIX + "7" in live_ops._get_ledger(), "legacy marker retained")
	_finish()

func _finish() -> void:
	# Let presentation callbacks from the real reward manager finish naturally.
	await create_timer(3.0).timeout
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await process_frame
	await process_frame
	print("LOGIN_CYCLE_QA checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
