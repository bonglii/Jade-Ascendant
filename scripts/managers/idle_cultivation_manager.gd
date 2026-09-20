extends Node

## Offline Cultivation / Spirit Meditation.
## Accrual is wall-clock based, capped, progression-scaled, and claim commits
## reward + idle timestamp atomically through RewardManager/SaveManager.
signal idle_state_changed
signal idle_reward_claimed(reward_data: Dictionary)
signal offline_gap_detected(seconds: int)

const SAVE_VERSION: int = 1
const SAVE_DOMAIN: String = "idle_cultivation"
const ACCRUAL_CAP_SECONDS: int = 12 * 60 * 60
const CLAIM_UNIT_SECONDS: int = 10 * 60
const AUTO_POPUP_MIN_OFFLINE_SECONDS: int = 30 * 60
const MAX_PROGRESS_TIER: int = 16
const REWARDED_DOUBLE_MULTIPLIER: int = 2
const MAX_PROCESSED_REWARDED_GRANTS: int = 32
const Presenter = preload("res://scripts/ui/idle_cultivation_presenter.gd")

var state: Dictionary = {}
var _session_offline_seconds: int = 0
var _clock_rollback_detected: bool = false
var _pending_rewarded_claim: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_or_initialize_state()
	var presenter: Node = Presenter.new()
	presenter.name = "IdleCultivationPresenter"
	add_child(presenter)
	DebugLogger.system(str(
		"IdleCultivationManager aktif | Tier: ",
		get_progress_tier(),
		" | Offline gap: ",
		_session_offline_seconds,
		"s"
	))


func _system_now() -> int:
	return maxi(int(Time.get_unix_time_from_system()), 0)


func _default_state(now_unix: int) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"last_claim_unix": now_unix,
		"last_observed_unix": now_unix,
		"lifetime_claim_seconds": 0,
		"shard_progress_units": 0,
		"processed_rewarded_grant_ids": [],
	}


func _normalize_state(raw_state: Dictionary, now_unix: int) -> Dictionary:
	var normalized: Dictionary = _default_state(now_unix)
	normalized["last_claim_unix"] = maxi(
		int(raw_state.get("last_claim_unix", now_unix)),
		0
	)
	normalized["last_observed_unix"] = maxi(
		int(raw_state.get(
			"last_observed_unix",
			normalized["last_claim_unix"]
		)),
		0
	)
	normalized["lifetime_claim_seconds"] = maxi(
		int(raw_state.get("lifetime_claim_seconds", 0)),
		0
	)
	normalized["shard_progress_units"] = maxi(
		int(raw_state.get("shard_progress_units", 0)),
		0
	)
	var processed: Array[String] = []
	var raw_processed: Variant = raw_state.get(
		"processed_rewarded_grant_ids",
		[]
	)
	if raw_processed is Array:
		for raw_id: Variant in raw_processed:
			var grant_id := str(raw_id).strip_edges()
			if grant_id.is_empty() or grant_id in processed:
				continue
			processed.append(grant_id)
			if processed.size() >= MAX_PROCESSED_REWARDED_GRANTS:
				break
	normalized["processed_rewarded_grant_ids"] = processed
	if int(normalized["last_observed_unix"]) < int(normalized["last_claim_unix"]):
		normalized["last_observed_unix"] = normalized["last_claim_unix"]
	return normalized


func _load_or_initialize_state() -> void:
	var now_unix: int = _system_now()
	var result: Dictionary = SaveManager.read_save_data(SAVE_DOMAIN)
	if bool(result.get("success", false)):
		state = _normalize_state(result.get("data", {}), now_unix)
		var previous_observed: int = int(state["last_observed_unix"])
		if now_unix >= previous_observed:
			_session_offline_seconds = now_unix - previous_observed
			state["last_observed_unix"] = now_unix
		else:
			_clock_rollback_detected = true
			_session_offline_seconds = 0
		_save_state()
		return
	if bool(result.get("exists", false)):
		# SaveManager already protects a corrupt/future save from overwrite.
		state = _default_state(now_unix)
		return
	state = _default_state(now_unix)
	_save_state()


func _save_state() -> bool:
	if SaveManager.is_save_write_blocked(SAVE_DOMAIN):
		return false
	state["version"] = SAVE_VERSION
	var result: Dictionary = SaveManager.write_save_data(
		SAVE_DOMAIN,
		state.duplicate(true)
	)
	return bool(result.get("success", false))


func _accepted_now() -> int:
	return maxi(_system_now(), int(state.get("last_observed_unix", 0)))


func is_unlocked() -> bool:
	return JourneyManager.cleared_stage_keys.size() > 0


func get_progress_tier() -> int:
	if not is_unlocked():
		return 0
	return clampi(
		JourneyManager.cleared_stage_keys.size(),
		1,
		MAX_PROGRESS_TIER
	)


func get_accrual_cap_seconds() -> int:
	return ACCRUAL_CAP_SECONDS


func get_claim_unit_seconds() -> int:
	return CLAIM_UNIT_SECONDS


func get_session_offline_seconds() -> int:
	return _session_offline_seconds


func get_auto_popup_min_offline_seconds() -> int:
	return AUTO_POPUP_MIN_OFFLINE_SECONDS


func is_clock_rollback_detected() -> bool:
	return _clock_rollback_detected


func get_claimable_seconds() -> int:
	if not is_unlocked() or state.is_empty():
		return 0
	var elapsed: int = maxi(
		_accepted_now() - int(state.get("last_claim_unix", _accepted_now())),
		0
	)
	return mini(elapsed, ACCRUAL_CAP_SECONDS)


func get_claimable_units() -> int:
	return floori(
		float(get_claimable_seconds())
		/ float(CLAIM_UNIT_SECONDS)
	)


func get_rates_for_tier(raw_tier: int) -> Dictionary:
	var tier: int = clampi(raw_tier, 1, MAX_PROGRESS_TIER)
	var stone_per_hour: int = 48 + (tier - 1) * 6
	var hero_exp_per_hour: int = (
		12
		+ floori(float(tier - 1) / 3.0) * 6
	)
	var shard_interval_units: int = 0
	if tier >= 16:
		shard_interval_units = 6
	elif tier >= 11:
		shard_interval_units = 9
	elif tier >= 6:
		shard_interval_units = 12
	elif tier >= 3:
		shard_interval_units = 18
	return {
		"tier": tier,
		"spirit_stone_per_hour": stone_per_hour,
		"hero_exp_per_hour": hero_exp_per_hour,
		"shard_interval_units": shard_interval_units,
	}


func get_tier_title(raw_tier: int) -> String:
	var tier: int = clampi(raw_tier, 1, MAX_PROGRESS_TIER)
	if tier >= 16:
		return "ASCENDANT MEDITATION"
	if tier >= 11:
		return "STAR PALACE RESONANCE"
	if tier >= 6:
		return "GOLDEN CORE FLOW"
	if tier >= 3:
		return "JADE MERIDIAN FLOW"
	return "VERDANT BREATH"


func preview_reward_for_seconds(
	seconds: int,
	raw_tier: int,
	starting_shard_progress_units: int = 0
) -> Dictionary:
	var tier: int = clampi(raw_tier, 1, MAX_PROGRESS_TIER)
	var capped_seconds: int = clampi(seconds, 0, ACCRUAL_CAP_SECONDS)
	var units: int = floori(
		float(capped_seconds)
		/ float(CLAIM_UNIT_SECONDS)
	)
	var claim_seconds: int = units * CLAIM_UNIT_SECONDS
	var rates: Dictionary = get_rates_for_tier(tier)
	var stones_per_unit: int = floori(
		float(int(rates["spirit_stone_per_hour"])) / 6.0
	)
	var hero_exp_per_unit: int = floori(
		float(int(rates["hero_exp_per_hour"])) / 6.0
	)
	var shard_interval: int = int(rates["shard_interval_units"])
	var next_shard_progress: int = 0
	var shard_amount: int = 0
	if shard_interval > 0:
		var total_shard_units: int = maxi(
			starting_shard_progress_units,
			0
		) + units
		shard_amount = floori(
			float(total_shard_units) / float(shard_interval)
		)
		next_shard_progress = total_shard_units % shard_interval
	var items: Dictionary = {}
	if shard_amount > 0:
		items[InventoryManager.REFINEMENT_SHARD] = shard_amount
	var reward_data: Dictionary = RewardManager.create_reward_data(
		units * stones_per_unit,
		items,
		units * hero_exp_per_unit
	)
	return {
		"reward_data": reward_data,
		"claim_seconds": claim_seconds,
		"claim_units": units,
		"next_shard_progress_units": next_shard_progress,
		"tier": tier,
		"rates": rates,
	}


func get_claim_preview() -> Dictionary:
	var tier: int = get_progress_tier()
	if tier <= 0:
		return {
			"reward_data": RewardManager.create_reward_data(),
			"claim_seconds": 0,
			"claim_units": 0,
			"next_shard_progress_units": int(
				state.get("shard_progress_units", 0)
			),
			"tier": 0,
			"rates": {},
		}
	return preview_reward_for_seconds(
		get_claimable_seconds(),
		tier,
		int(state.get("shard_progress_units", 0))
	)


func claim_idle_reward() -> Dictionary:
	if has_pending_rewarded_double_claim():
		return {
			"success": false,
			"error": "Rewarded claim is already in progress."
		}
	if not is_unlocked():
		return {"success": false, "error": "Meditation is still locked."}
	if SaveManager.is_progress_read_only():
		return {"success": false, "error": "Progress save is read-only."}
	var preview: Dictionary = get_claim_preview()
	var claim_seconds: int = int(preview.get("claim_seconds", 0))
	if claim_seconds < CLAIM_UNIT_SECONDS:
		return {"success": false, "error": "Not enough meditation time yet."}

	var accepted_now: int = _accepted_now()
	var raw_elapsed: int = maxi(
		accepted_now - int(state["last_claim_unix"]),
		0
	)
	var capped_elapsed: int = mini(raw_elapsed, ACCRUAL_CAP_SECONDS)
	var remainder_seconds: int = maxi(capped_elapsed - claim_seconds, 0)
	var next_state: Dictionary = state.duplicate(true)
	next_state["version"] = SAVE_VERSION
	next_state["last_claim_unix"] = accepted_now - remainder_seconds
	next_state["last_observed_unix"] = accepted_now
	next_state["lifetime_claim_seconds"] = (
		int(state.get("lifetime_claim_seconds", 0))
		+ claim_seconds
	)
	next_state["shard_progress_units"] = int(
		preview.get("next_shard_progress_units", 0)
	)

	var source_id: String = "meditation_%d_%d" % [
		int(next_state["lifetime_claim_seconds"]),
		accepted_now,
	]
	var reward_data: Dictionary = preview.get("reward_data", {})
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_IDLE_CULTIVATION,
		source_id,
		reward_data,
		{SAVE_DOMAIN: next_state}
	)
	if not bool(result.get("success", false)):
		return result
	state = next_state
	_clock_rollback_detected = false
	idle_state_changed.emit()
	var applied_reward: Dictionary = result.get(
		"applied_reward_data",
		reward_data
	)
	idle_reward_claimed.emit(applied_reward.duplicate(true))
	return result


func get_rewarded_double_multiplier() -> int:
	return REWARDED_DOUBLE_MULTIPLIER


func _multiply_reward_data(
	reward_data: Dictionary,
	multiplier: int
) -> Dictionary:
	var safe_multiplier: int = maxi(multiplier, 1)
	var multiplied_items: Dictionary = {}
	var raw_items: Variant = reward_data.get(
		RewardManager.REWARD_KEY_ITEMS,
		{}
	)
	if raw_items is Dictionary:
		for raw_item_id: Variant in raw_items.keys():
			multiplied_items[str(raw_item_id)] = (
				int(raw_items[raw_item_id]) * safe_multiplier
			)
	return RewardManager.create_reward_data(
		int(reward_data.get(
			RewardManager.REWARD_KEY_SPIRIT_STONE,
			0
		)) * safe_multiplier,
		multiplied_items,
		int(reward_data.get(
			RewardManager.REWARD_KEY_HERO_EXP,
			0
		)) * safe_multiplier
	)


func preview_rewarded_double_for_seconds(
	seconds: int,
	raw_tier: int,
	starting_shard_progress_units: int = 0
) -> Dictionary:
	var preview: Dictionary = preview_reward_for_seconds(
		seconds,
		raw_tier,
		starting_shard_progress_units
	)
	var doubled: Dictionary = preview.duplicate(true)
	doubled["reward_data"] = _multiply_reward_data(
		preview.get("reward_data", {}),
		REWARDED_DOUBLE_MULTIPLIER
	)
	return doubled


func get_rewarded_double_preview() -> Dictionary:
	var tier: int = get_progress_tier()
	if tier <= 0:
		return get_claim_preview()
	return preview_rewarded_double_for_seconds(
		get_claimable_seconds(),
		tier,
		int(state.get("shard_progress_units", 0))
	)


func has_pending_rewarded_double_claim() -> bool:
	return not _pending_rewarded_claim.is_empty()


func prepare_rewarded_double_claim() -> bool:
	if (
		has_pending_rewarded_double_claim()
		or not is_unlocked()
		or SaveManager.is_progress_read_only()
	):
		return false
	var preview: Dictionary = get_claim_preview()
	var claim_seconds: int = int(preview.get("claim_seconds", 0))
	if claim_seconds < CLAIM_UNIT_SECONDS:
		return false
	var accepted_now: int = _accepted_now()
	var raw_elapsed: int = maxi(
		accepted_now - int(state["last_claim_unix"]),
		0
	)
	var capped_elapsed: int = mini(raw_elapsed, ACCRUAL_CAP_SECONDS)
	var remainder_seconds: int = maxi(
		capped_elapsed - claim_seconds,
		0
	)
	var next_state: Dictionary = state.duplicate(true)
	next_state["version"] = SAVE_VERSION
	next_state["last_claim_unix"] = accepted_now - remainder_seconds
	next_state["last_observed_unix"] = accepted_now
	next_state["lifetime_claim_seconds"] = (
		int(state.get("lifetime_claim_seconds", 0))
		+ claim_seconds
	)
	next_state["shard_progress_units"] = int(
		preview.get("next_shard_progress_units", 0)
	)
	_pending_rewarded_claim = {
		"accepted_now": accepted_now,
		"claim_seconds": claim_seconds,
		"next_state": next_state,
		"reward_data": _multiply_reward_data(
			preview.get("reward_data", {}),
			REWARDED_DOUBLE_MULTIPLIER
		)
	}
	return true


func cancel_pending_rewarded_double_claim() -> void:
	_pending_rewarded_claim.clear()


func apply_verified_rewarded_double_claim(
	provider_grant_id: String
) -> Dictionary:
	var normalized_id: String = provider_grant_id.strip_edges()
	if normalized_id.is_empty():
		return {"success": false, "error": "Verified rewarded grant id is required."}
	if _pending_rewarded_claim.is_empty():
		return {"success": false, "error": "No rewarded meditation claim is pending."}
	if SaveManager.is_progress_read_only():
		_pending_rewarded_claim.clear()
		return {"success": false, "error": "Progress save is read-only."}

	var processed: Array[String] = []
	var raw_processed: Variant = state.get(
		"processed_rewarded_grant_ids",
		[]
	)
	if raw_processed is Array:
		for raw_id: Variant in raw_processed:
			processed.append(str(raw_id))
	if normalized_id in processed:
		_pending_rewarded_claim.clear()
		return {"success": false, "error": "Verified rewarded grant was already consumed."}

	var next_state_variant: Variant = _pending_rewarded_claim.get(
		"next_state",
		{}
	)
	if not next_state_variant is Dictionary:
		_pending_rewarded_claim.clear()
		return {"success": false, "error": "Rewarded meditation snapshot is invalid."}
	var next_state: Dictionary = (
		next_state_variant as Dictionary
	).duplicate(true)
	if next_state.is_empty():
		_pending_rewarded_claim.clear()
		return {"success": false, "error": "Rewarded meditation snapshot is invalid."}

	processed.append(normalized_id)
	while processed.size() > MAX_PROCESSED_REWARDED_GRANTS:
		processed.remove_at(0)
	next_state["processed_rewarded_grant_ids"] = processed

	var reward_variant: Variant = _pending_rewarded_claim.get(
		"reward_data",
		{}
	)
	var reward_data: Dictionary = (
		(reward_variant as Dictionary).duplicate(true)
		if reward_variant is Dictionary
		else {}
	)
	var result: Dictionary = RewardManager.grant_reward(
		RewardManager.SOURCE_IDLE_CULTIVATION,
		"rewarded_double:" + normalized_id,
		reward_data,
		{SAVE_DOMAIN: next_state}
	)
	_pending_rewarded_claim.clear()
	if not bool(result.get("success", false)):
		return result

	state = next_state
	_clock_rollback_detected = false
	idle_state_changed.emit()
	var applied_reward: Dictionary = result.get(
		"applied_reward_data",
		reward_data
	)
	idle_reward_claimed.emit(applied_reward.duplicate(true))
	return result


func _observe_now_and_save() -> void:
	if state.is_empty():
		return
	var now_unix: int = _system_now()
	var previous_observed: int = int(state.get("last_observed_unix", 0))
	if now_unix < previous_observed:
		_clock_rollback_detected = true
		return
	state["last_observed_unix"] = now_unix
	_save_state()


func _capture_resume_gap() -> void:
	if state.is_empty():
		return
	var now_unix: int = _system_now()
	var previous_observed: int = int(state.get("last_observed_unix", 0))
	if now_unix < previous_observed:
		_clock_rollback_detected = true
		_session_offline_seconds = 0
		return
	_session_offline_seconds = now_unix - previous_observed
	state["last_observed_unix"] = now_unix
	_save_state()
	if _session_offline_seconds > 0:
		offline_gap_detected.emit(_session_offline_seconds)


func _notification(what: int) -> void:
	if what in [
		NOTIFICATION_APPLICATION_PAUSED,
		NOTIFICATION_WM_CLOSE_REQUEST,
	]:
		_observe_now_and_save()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_capture_resume_gap()
