extends Node

## Provider boundary for monetized builds. Android may attach the AdMob adapter;
## desktop/editor and unsupported runtimes stay on the safe offline provider.
signal rewarded_completed(placement: String)
signal verified_rewarded_completed(placement: String, grant_id: String)
signal rewarded_request_finished(placement: String, status: String)
signal reward_delivery_finished(
	placement: String,
	success: bool,
	amount: int,
	message: String
)
signal operation_finished(status: String)
signal entitlements_changed(product_ids: Array[String])
signal analytics_event(event_id: String, properties: Dictionary)

const OfflineProvider = preload("res://scripts/monetization/offline_provider.gd")
const AdMobProvider = preload("res://scripts/monetization/admob_provider.gd")
const PavilionRewardedBridge = preload(
	"res://scripts/monetization/pavilion_rewarded_bridge.gd"
)
const OfflineCultivationRewardedBridge = preload(
	"res://scripts/monetization/offline_cultivation_rewarded_bridge.gd"
)
const GameOverRewardedBridge = preload(
	"res://scripts/monetization/game_over_rewarded_bridge.gd"
)
const PolicyStore = preload("res://scripts/monetization/monetization_policy_store.gd")

const REWARD_COOLDOWN_MSEC: int = 60000
const REWARD_COOLDOWN_SECONDS: int = 60
const DAILY_PLACEMENT_LIMIT: int = 1
const GAME_OVER_REVIVE_PLACEMENT: String = "game_over_revive"
const GAME_OVER_REVIVE_DAILY_LIMIT: int = 999999

var provider: Node
var policy_store: RefCounted
var request_sequence: int = 0
var active_request: int = -1
var active_placement: String = ""
var active_grant_id: String = ""
var reward_consumed: bool = false

var last_reward_at: int = -REWARD_COOLDOWN_MSEC
var last_reward_unix: int = 0
var policy_day_bucket: int = -1
var timeout_left: float = 0.0
var placement_counts: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	policy_store = PolicyStore.new()
	_load_policy_state()
	_attach_provider(OfflineProvider.new())

	var pavilion_rewarded_bridge: Node = PavilionRewardedBridge.new()
	pavilion_rewarded_bridge.name = "PavilionRewardedBridge"
	add_child(pavilion_rewarded_bridge)

	var idle_rewarded_bridge: Node = (
		OfflineCultivationRewardedBridge.new()
	)
	idle_rewarded_bridge.name = "OfflineCultivationRewardedBridge"
	add_child(idle_rewarded_bridge)

	var game_over_rewarded_bridge: Node = GameOverRewardedBridge.new()
	game_over_rewarded_bridge.name = "GameOverRewardedBridge"
	add_child(game_over_rewarded_bridge)

	if OS.get_name() == "Android":
		call_deferred("_activate_android_provider")


func _activate_android_provider() -> void:
	if OS.get_name() != "Android" or active_request >= 0:
		return
	_attach_provider(AdMobProvider.new())


func _attach_provider(next_provider: Node) -> void:
	if is_instance_valid(provider):
		provider.queue_free()

	provider = next_provider
	provider.connect("reward_confirmed", _on_reward_confirmed)
	provider.connect("request_finished", _on_request_finished)
	provider.connect("entitlements_received", _on_entitlements_received)
	add_child(provider)


func use_test_provider(test_provider: Node) -> bool:
	if not OS.is_debug_build() or active_request >= 0:
		return false
	_attach_provider(test_provider)
	return true


func get_rewarded_daily_limit(placement: String) -> int:
	if placement == GAME_OVER_REVIVE_PLACEMENT:
		return GAME_OVER_REVIVE_DAILY_LIMIT
	return DAILY_PLACEMENT_LIMIT


func get_rewarded_cooldown_seconds(placement: String) -> int:
	if placement == GAME_OVER_REVIVE_PLACEMENT:
		return 0
	return REWARD_COOLDOWN_SECONDS


func get_rewarded_cooldown_msec(placement: String) -> int:
	return get_rewarded_cooldown_seconds(placement) * 1000


func rewarded_available(placement: String) -> bool:
	_sync_policy_day()
	var now_unix: int = _get_unix_time()
	var cooldown_seconds: int = get_rewarded_cooldown_seconds(placement)
	var cooldown_msec: int = get_rewarded_cooldown_msec(placement)
	var daily_limit: int = get_rewarded_daily_limit(placement)
	var persistent_cooldown_ready: bool = (
		last_reward_unix <= 0
		or now_unix - last_reward_unix >= cooldown_seconds
	)
	return (
		active_request < 0
		and int(placement_counts.get(placement, 0)) < daily_limit
		and Time.get_ticks_msec() - last_reward_at >= cooldown_msec
		and persistent_cooldown_ready
		and bool(provider.call("rewarded_available", placement))
	)


func is_rewarded_request_active(placement: String) -> bool:
	return (
		active_request >= 0
		and active_placement == placement
	)


func get_rewarded_policy_status(placement: String) -> Dictionary:
	_sync_policy_day()
	var now_unix: int = _get_unix_time()
	var placement_claims: int = int(placement_counts.get(placement, 0))
	var daily_limit: int = get_rewarded_daily_limit(placement)
	var cooldown_seconds: int = get_rewarded_cooldown_seconds(placement)
	var cooldown_remaining: int = 0
	if last_reward_unix > 0 and cooldown_seconds > 0:
		cooldown_remaining = maxi(
			cooldown_seconds - (now_unix - last_reward_unix),
			0
		)
	var provider_ready: bool = bool(
		provider.call("rewarded_available", placement)
	)
	return {
		"available": (
			active_request < 0
			and placement_claims < daily_limit
			and cooldown_remaining <= 0
			and provider_ready
		),
		"placement_claims": placement_claims,
		"daily_limit": daily_limit,
		"cooldown_remaining_seconds": cooldown_remaining,
		"provider_ready": provider_ready
	}


func show_rewarded(placement: String) -> bool:
	if not rewarded_available(placement):
		operation_finished.emit("unavailable")
		return false

	var grant_id: String = _create_reward_grant_id()
	if grant_id.is_empty():
		operation_finished.emit("internal_error")
		return false

	request_sequence += 1
	active_request = request_sequence
	active_placement = placement
	active_grant_id = grant_id
	reward_consumed = false
	timeout_left = 90.0
	analytics_event.emit("reward_requested", {"placement": placement})
	provider.call_deferred("show_rewarded", active_request, placement)
	return true


func privacy_options_required() -> bool:
	if not is_instance_valid(provider):
		return false
	if not provider.has_method("privacy_options_required"):
		return false
	return bool(provider.call("privacy_options_required"))


func show_privacy_options() -> bool:
	if active_request >= 0 or not is_instance_valid(provider):
		return false
	if not provider.has_method("show_privacy_options"):
		return false
	return bool(provider.call("show_privacy_options"))


func get_provider_runtime_status() -> Dictionary:
	if not is_instance_valid(provider):
		return {"provider": "none", "state": "missing"}
	if provider.has_method("get_runtime_status"):
		var status: Variant = provider.call("get_runtime_status")
		if status is Dictionary:
			return (status as Dictionary).duplicate(true)
	return {"provider": provider.name, "state": "unknown"}


func publish_reward_delivery_result(
	placement: String,
	success: bool,
	amount: int,
	message: String
) -> void:
	reward_delivery_finished.emit(
		placement,
		success,
		amount,
		message
	)


func _on_reward_confirmed(request_id: int) -> void:
	if request_id != active_request or active_request < 0 or reward_consumed:
		return

	reward_consumed = true
	last_reward_at = Time.get_ticks_msec()
	last_reward_unix = _get_unix_time()
	_sync_policy_day(false)
	placement_counts[active_placement] = int(placement_counts.get(active_placement, 0)) + 1

	if not _save_policy_state():
		push_error("MonetizationManager: persistent reward policy gagal disimpan.")
		analytics_event.emit(
			"reward_policy_save_failed",
			{"placement": active_placement}
		)

	var completed_placement: String = active_placement
	var completed_grant_id: String = active_grant_id
	if completed_grant_id.is_empty():
		push_error(
			"MonetizationManager: verified rewarded callback tanpa grant id."
		)
	else:
		verified_rewarded_completed.emit(
			completed_placement,
			completed_grant_id
		)

	rewarded_completed.emit(completed_placement)
	analytics_event.emit(
		"reward_confirmed",
		{"placement": completed_placement}
	)


func _on_request_finished(request_id: int, status: String) -> void:
	if request_id != active_request:
		return
	var finished_placement: String = active_placement
	active_request = -1
	active_placement = ""
	active_grant_id = ""
	timeout_left = 0.0
	rewarded_request_finished.emit(finished_placement, status)
	operation_finished.emit(status)


func purchase(_product_id: String) -> bool:
	operation_finished.emit("unavailable")
	return false


func restore_purchases() -> void:
	provider.call("restore_entitlements")


func _on_entitlements_received(product_ids: Array[String]) -> void:
	entitlements_changed.emit(product_ids.duplicate())


func _process(delta: float) -> void:
	if active_request < 0:
		return
	timeout_left -= delta
	if timeout_left <= 0.0:
		_on_request_finished(active_request, "timeout")


func _load_policy_state() -> void:
	var state: Dictionary = policy_store.call("load_state")
	policy_day_bucket = int(state.get("day_bucket", _get_day_bucket(_get_unix_time())))
	last_reward_unix = maxi(int(state.get("last_reward_unix", 0)), 0)
	var stored_counts: Variant = state.get("placement_counts", {})
	placement_counts = stored_counts.duplicate(true) if stored_counts is Dictionary else {}
	_sync_policy_day()


func _sync_policy_day(persist_change: bool = true) -> void:
	var current_day: int = _get_day_bucket(_get_unix_time())
	if policy_day_bucket < 0:
		policy_day_bucket = current_day
		return

	if current_day <= policy_day_bucket:
		return

	policy_day_bucket = current_day
	placement_counts.clear()
	if persist_change and not _save_policy_state():
		push_warning("MonetizationManager: daily reward policy rollover belum tersimpan.")


func _save_policy_state() -> bool:
	return bool(
		policy_store.call(
			"save_state",
			{
				"version": 1,
				"day_bucket": policy_day_bucket,
				"last_reward_unix": last_reward_unix,
				"placement_counts": placement_counts.duplicate(true)
			}
		)
	)


func _create_reward_grant_id() -> String:
	var crypto := Crypto.new()
	var random_bytes: PackedByteArray = crypto.generate_random_bytes(16)
	if random_bytes.size() != 16:
		push_error(
			"MonetizationManager: gagal membuat rewarded grant nonce."
		)
		return ""
	return random_bytes.hex_encode()


func _get_unix_time() -> int:
	return maxi(int(floor(Time.get_unix_time_from_system())), 0)


func _get_day_bucket(unix_time: int) -> int:
	return int(float(unix_time) / 86400.0)
