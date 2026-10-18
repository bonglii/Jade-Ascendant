extends Node
## Server event overlay. Never grants dice/rewards from local ad callbacks.
signal changed
signal finished(action: String, success: bool)
const SINGLETON: String = "JadeMonetizationNativeBridge"
var snapshot: Dictionary = {}
var status: String = "not_connected"
var busy: bool = false
var _binding: String = ""
var _request_id: String = ""
var _command: Dictionary = {}
var _deadline: int = 0
var _read_at: int = 0
var _poll_until: int = 0
var _ad_nonce: String = ""
var _received_msec: int = 0
var run_authorized: bool = false
var _preparing_run: bool = false

func server_time() -> int:
	return int(snapshot.get("server_time", 0)) + floori(float(maxi(0, Time.get_ticks_msec() - _received_msec)) / 1000.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup_ads")
func _setup_ads() -> void:
	var ads: Node = get_node_or_null("/root/MonetizationManager")
	if ads != null:
		ads.rewarded_request_finished.connect(_ad_finished)
func _live_binding() -> String:
	var account_manager: Node = get_node_or_null("/root/GoogleAccountManager")
	return str(account_manager.call("get_monetization_account_binding")) if account_manager != null else ""
func _path() -> String:
	return "user://odyssey_" + _binding + ".json" if _binding.length() == 64 else ""
func _pending() -> Dictionary:
	if _path().is_empty() or not FileAccess.file_exists(_path()): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	return data if data is Dictionary else {"error": "journal_unreadable"}
func _bridge() -> Object:
	if not Engine.has_singleton(SINGLETON): return null
	var native: Object = Engine.get_singleton(SINGLETON)
	if not native.call("has_java_method", "requestOdysseyV1") or not native.has_signal("odysseyResultV1"): return null
	if not native.is_connected("odysseyResultV1", _on_result): native.connect("odysseyResultV1", _on_result)
	return native
func _process(_delta: float) -> void:
	var live: String = _live_binding()
	if live != _binding:
		_binding = live; snapshot = {}; busy = false; run_authorized = false; _request_id = ""; _command = {}; _ad_nonce = ""; _poll_until = 0
		status = "account_changed"; changed.emit()
	if busy and Time.get_ticks_msec() > _deadline:
		busy = false; status = "connection_timeout"; changed.emit()
	if _poll_until > Time.get_ticks_msec() and not busy and Time.get_ticks_msec() > _read_at:
		refresh()
func refresh() -> bool:
	if busy: return false
	var live: String = _live_binding()
	if live != _binding:
		_binding = live; snapshot = {}; run_authorized = false; _request_id = ""; _command = {}; _ad_nonce = ""; _poll_until = 0
	if _binding.length() != 64: status = "google_sign_in_required"; changed.emit(); return false
	var pending: Dictionary = _pending()
	if pending.has("error"): status = "recovery_required"; changed.emit(); return false
	return _dispatch(pending)
func submit(action: Dictionary) -> bool:
	if busy or snapshot.get("event") == null or not _pending().is_empty() or _binding != _live_binding(): return false
	if _bridge() == null: status = "native_update_required"; changed.emit(); return false
	var command: Dictionary = {"event_id": snapshot.event.id, "request_id": Crypto.new().generate_random_bytes(16).hex_encode(), "revision": int(snapshot.get("revision", 0)), "action": action.duplicate(true)}
	var file: FileAccess = FileAccess.open(_path() + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(command)); file.flush()
	var error: Error = file.get_error(); file.close()
	if error != OK or DirAccess.rename_absolute(_path() + ".tmp", _path()) != OK: return false
	return _dispatch(command)
func _dispatch(command: Dictionary) -> bool:
	var native: Object = _bridge()
	if native == null: status = "native_update_required"; changed.emit(); return false
	_command = command; _request_id = str(command.get("request_id", Crypto.new().generate_random_bytes(16).hex_encode()))
	busy = true; status = "connecting"; _deadline = Time.get_ticks_msec() + 46000; _read_at = Time.get_ticks_msec() + 4000
	changed.emit(); native.call("requestOdysseyV1", _request_id, "" if command.is_empty() else JSON.stringify(command)); return true
func _on_result(request_id: String, success: bool, result_status: String, payload: String) -> void:
	if request_id != _request_id or _binding != _live_binding(): return
	busy = false; status = result_status
	var action: String = str(_command.get("action", {}).get("kind", "read"))
	if success:
		var data: Variant = JSON.parse_string(payload)
		if not data is Dictionary or data.get("owner_binding") != _binding: status = "invalid_snapshot"; changed.emit(); return
		if not _command.is_empty() and DirAccess.remove_absolute(_path()) != OK:
			status = "journal_cleanup_required"; changed.emit(); return
		snapshot = data; _received_msec = Time.get_ticks_msec(); _command = {}; status = "connected"
		if action == "buy_dice":
			var paid: Node = get_node_or_null("/root/PavilionManager/PaidGameplayV2")
			if paid != null: paid.call("refresh")
		if action == "ad_intent" and data.get("ad_intent") is Dictionary:
			_ad_nonce = str(data.ad_intent.nonce)
			_show_ad()
		var mail: Node = get_node_or_null("/root/ServerMailManager")
		if mail != null and action in ["roll", "route", "counter", "milestone"] and mail.has_method("refresh"): mail.call("refresh", true)
	elif result_status in ["REVISION_OR_OWNERSHIP_CONFLICT", "INVALID_REQUEST"] and not _command.is_empty():
		# These HTTP responses confirm this id was not committed; uncertain
		# transport failures keep the exact durable request for recovery.
		if DirAccess.remove_absolute(_path()) == OK:
			_command = {}; snapshot = {}; call_deferred("refresh")
	finished.emit(action, success); changed.emit()
func watch_ad() -> bool:
	var ads: Node = get_node_or_null("/root/MonetizationManager")
	if ads == null or not bool(ads.call("rewarded_available", "odyssey_roll")):
		status = "ad_not_available"; changed.emit(); return false
	return submit({"kind": "ad_intent"})
func _show_ad() -> void:
	var ads: Node = get_node_or_null("/root/MonetizationManager")
	if ads == null: return
	var provider: Node = ads.get("provider")
	if provider == null or not provider.has_method("prepare_odyssey_ssv"): status = "ad_not_available"; return
	provider.call("prepare_odyssey_ssv", _ad_nonce)
	if not bool(ads.call("show_rewarded", "odyssey_roll")): status = "ad_not_available"
func _ad_finished(placement: String, _result: String) -> void:
	if placement != "odyssey_roll": return
	# Closing/watching is not proof. Poll for Google's signed server receipt.
	_poll_until = Time.get_ticks_msec() + 120000; _read_at = 0
	status = "waiting_for_ad_verification"; changed.emit()

func prepare_scene_run(continuing: bool) -> bool:
	if _preparing_run: return false
	_preparing_run = true; run_authorized = false
	var equipment: Node = get_node_or_null("/root/EquipmentManager")
	var armament: String = str(equipment.call("get_loadout_equipped_item_id", "armament")) if equipment != null else ""
	if continuing and equipment != null:
		armament = str(equipment.get("active_run_loadout_snapshot").get("equipped_item_ids",{}).get("armament",""))
	if armament != "heavenweaver_compass": _preparing_run = false; return true
	var account_binding: String = _live_binding()
	while busy: await get_tree().process_frame
	var ok: bool = refresh()
	while busy: await get_tree().process_frame
	# An uncertain command is recovered with its exact ID before reading a lease.
	if ok and status == "connected" and not snapshot.has("compass_authorized"):
		ok = refresh()
		while busy: await get_tree().process_frame
	run_authorized = ok and status == "connected" and account_binding == _live_binding() and snapshot.get("compass_authorized",false) == true and Time.get_ticks_msec() - _received_msec <= 60000
	_preparing_run = false
	return run_authorized
