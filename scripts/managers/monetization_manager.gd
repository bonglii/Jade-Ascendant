extends Node

## Provider boundary for monetized builds. Android may attach the AdMob adapter;
## desktop/editor and unsupported runtimes stay on the safe offline provider.
signal rewarded_completed(placement: String)
signal operation_finished(status: String)
signal entitlements_changed(product_ids: Array[String])
signal analytics_event(event_id: String, properties: Dictionary)

const OfflineProvider = preload("res://scripts/monetization/offline_provider.gd")
const AdMobProvider = preload("res://scripts/monetization/admob_provider.gd")
const PolicyStore = preload("res://scripts/monetization/monetization_policy_store.gd")

const REWARD_COOLDOWN_MSEC: int = 60000
const REWARD_COOLDOWN_SECONDS: int = 60
const DAILY_PLACEMENT_LIMIT: int = 1

var provider: Node
var policy_store: RefCounted
var request_sequence: int = 0
var active_request: int = -1
var active_placement: String = ""
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


func rewarded_available(placement: String) -> bool:
	_sync_policy_day()
	var now_unix: int = _get_unix_time()
	var persistent_cooldown_ready: bool = (
		last_reward_unix <= 0
		or now_unix - last_reward_unix >= REWARD_COOLDOWN_SECONDS
	)
	return (
		active_request < 0
		and int(placement_counts.get(placement, 0)) < DAILY_PLACEMENT_LIMIT
		and Time.get_ticks_msec() - last_reward_at >= REWARD_COOLDOWN_MSEC
		and persistent_cooldown_ready
		and bool(provider.call("rewarded_available", placement))
	)


func show_rewarded(placement: String) -> bool:
	if not rewarded_available(placement):
		operation_finished.emit("unavailable")
		return false

	request_sequence += 1
	active_request = request_sequence
	active_placement = placement
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

	rewarded_completed.emit(active_placement)
	analytics_event.emit(
		"reward_confirmed",
		{"placement": active_placement}
	)


func _on_request_finished(request_id: int, status: String) -> void:
	if request_id != active_request:
		return
	active_request = -1
	active_placement = ""
	timeout_left = 0.0
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


func _get_unix_time() -> int:
	return maxi(int(floor(Time.get_unix_time_from_system())), 0)


func _get_day_bucket(unix_time: int) -> int:
	return int(float(unix_time) / 86400.0)
