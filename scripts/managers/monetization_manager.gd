extends Node

## Provider boundary for a later monetized build. The shipping offline provider
## exposes no purchase buttons, ads or fake restore promises. Reward completion
## is a distinct provider signal; closing an ad never grants a reward.
signal rewarded_completed(placement: String)
signal operation_finished(status: String)
signal entitlements_changed(product_ids: Array[String])
signal analytics_event(event_id: String, properties: Dictionary)
const OfflineProvider = preload("res://scripts/monetization/offline_provider.gd")
var provider: Node
var request_sequence: int = 0
var active_request: int = -1
var active_placement: String = ""
var reward_consumed: bool = false
var last_reward_at: int = -60000
var timeout_left: float = 0.0
var placement_counts: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_attach_provider(OfflineProvider.new())

func _attach_provider(next_provider: Node) -> void:
	if is_instance_valid(provider):
		provider.queue_free()
	provider = next_provider
	add_child(provider)
	provider.connect("reward_confirmed", _on_reward_confirmed)
	provider.connect("request_finished", _on_request_finished)
	provider.connect("entitlements_received", _on_entitlements_received)

func use_test_provider(test_provider: Node) -> bool:
	if not OS.is_debug_build() or active_request >= 0:
		return false
	_attach_provider(test_provider)
	return true

func rewarded_available(placement: String) -> bool:
	return active_request < 0 and int(placement_counts.get(placement, 0)) < 1 and Time.get_ticks_msec() - last_reward_at >= 60000 and bool(provider.call("rewarded_available", placement))

func show_rewarded(placement: String) -> bool:
	# A real adapter must also supply consent, persistent daily/run caps and
	# verified entitlement handling before this can become a shipping placement.
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

func _on_reward_confirmed(request_id: int) -> void:
	if request_id != active_request or active_request < 0 or reward_consumed:
		return
	reward_consumed = true
	last_reward_at = Time.get_ticks_msec()
	placement_counts[active_placement] = int(placement_counts.get(active_placement, 0)) + 1
	rewarded_completed.emit(active_placement)
	analytics_event.emit("reward_confirmed", {"placement": active_placement})

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
