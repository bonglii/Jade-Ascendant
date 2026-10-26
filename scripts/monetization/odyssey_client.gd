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
var _ad_before: int=-1
var _ad_day: String=""
var ad_delivery_state: String="idle"
var _ad_expires_at: int=0
var _ad_attempts: int=0
var _ad_cancelled: bool=false
var _ad_earned_seen: bool=false
var _ad_cancelled_at: int=0
var _ad_reward_notice: Dictionary={}
var _ad_feedback_until: int=0
var _received_msec: int = 0
var run_authorized: bool = false
var _preparing_run: bool = false
var run_gate_error: String = ""
var _warm_next_at: int = 0
var _backgrounded: bool = false
var _prepared_ad: Dictionary={}
var _ad_open_requested: bool=false
var _ad_prepare_next: int=0

func server_time() -> int:
	return int(snapshot.get("server_time", 0)) + floori(float(maxi(0, Time.get_ticks_msec() - _received_msec)) / 1000.0)


func event_enabled() -> bool:
	var event: Variant=snapshot.get("event")
	return event is Dictionary and bool(event.get("enabled",false))

func event_active() -> bool:
	return event_enabled() and server_time()>=int(snapshot.event.get("starts_at",0)) and server_time()<int(snapshot.event.get("ends_at",0))

func purchase_bonus_active() -> bool:
	var event: Variant=snapshot.get("event")
	return not snapshot.is_empty() and event is Dictionary and bool(event.get("enabled",false)) and bool(event.get("purchases_enabled",false)) and server_time()>=int(event.get("starts_at",0)) and server_time()<int(event.get("ends_at",0)) and bool(snapshot.get("purchase_bonus",{}).get("active",false))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup_ads")
func _setup_ads() -> void:
	var ads: Node = get_node_or_null("/root/MonetizationManager")
	if ads != null:
		if not ads.is_connected("rewarded_request_finished",_ad_finished): ads.connect("rewarded_request_finished",_ad_finished)
		if ads.has_signal("rewarded_completed") and not ads.is_connected("rewarded_completed",_ad_earned): ads.connect("rewarded_completed",_ad_earned)
func _live_binding() -> String:
	var account_manager: Node = get_node_or_null("/root/GoogleAccountManager")
	return str(account_manager.call("get_monetization_account_binding")) if account_manager != null else ""
func _path() -> String:
	return "user://odyssey_" + _binding + ".json" if _binding.length() == 64 else ""
static func _whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high
static func _matches(value: Variant, pattern: String) -> bool:
	if not value is String: return false
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex.search(value) != null
static func canonical_command(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 4: return {}
	for key: String in ["event_id", "request_id", "revision", "action"]:
		if not value.has(key): return {}
	if not _matches(value.event_id, "^[a-z0-9_-]{3,48}$") or not _matches(value.request_id, "^[a-f0-9]{32}$") or not _whole(value.revision, 0, 10000): return {}
	if not value.action is Dictionary or not value.action.get("kind") is String: return {}
	var action: Dictionary = value.action
	var kind: String = action.kind
	var fields: Dictionary = {"sync": [], "missions_all": [], "task": ["task"], "arena_finish": ["trace", "abandon"], "roll": [], "ad_intent": [], "route": ["choice"], "counter": ["choice"], "mission": ["mission"], "milestone": ["milestone"], "buy_dice": ["pack"]}
	if not fields.has(kind) or action.size() != 1 + fields[kind].size(): return {}
	for field: String in fields[kind]:
		if not action.has(field): return {}
	match kind:
		"task":
			if action.task not in ["gifts","guardian"]: return {}
		"arena_finish":
			if not action.abandon is bool or not _matches(action.trace,"^[0-8]{0,600}$"): return {}
		"route":
			if action.choice not in ["safe", "challenge"]: return {}
		"counter":
			if not _whole(action.choice, 0, 2): return {}
		"mission":
			if not _whole(action.mission, 1, 5) or int(action.mission) not in [1, 3, 5]: return {}
		"milestone":
			if not _whole(action.milestone, 24, 72) or int(action.milestone) not in [24, 48, 72]: return {}
		"buy_dice":
			if not _whole(action.pack, 1, 5) or int(action.pack) not in [1, 5]: return {}
	var canonical: Dictionary = value.duplicate(true)
	canonical.revision = int(canonical.revision)
	for field: String in ["choice", "mission", "milestone", "pack"]:
		if canonical.action.has(field) and kind != "route": canonical.action[field] = int(canonical.action[field])
	return canonical
func _pending() -> Dictionary:
	if _path().is_empty() or not FileAccess.file_exists(_path()): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
	var command: Dictionary = canonical_command(data)
	return command if not command.is_empty() else {"error": "journal_unreadable"}
func _bridge() -> Object:
	if not Engine.has_singleton(SINGLETON): return null
	var native: Object = Engine.get_singleton(SINGLETON)
	if not native.call("has_java_method", "requestOdysseyV1") or not native.has_signal("odysseyResultV1"): return null
	if not native.is_connected("odysseyResultV1", _on_result): native.connect("odysseyResultV1", _on_result)
	return native
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: _backgrounded = true
	elif what == NOTIFICATION_APPLICATION_RESUMED: _backgrounded = false; _warm_next_at = Time.get_ticks_msec() + 1500

func _can_prewarm() -> bool:
	return is_inside_tree() and name == "OdysseyClient" and get_parent() == get_tree().root

func refresh_if_stale(max_age_ms: int = 60000) -> bool:
	if _binding == _live_binding() and not snapshot.is_empty() and Time.get_ticks_msec() - _received_msec < max_age_ms: return true
	return refresh()

func _prewarm_if_due() -> void:
	if not _can_prewarm() or _backgrounded or busy or _binding.length() != 64: return
	if Time.get_ticks_msec() < _warm_next_at: return
	if get_tree().get_first_node_in_group("player") != null: return
	_warm_next_at = Time.get_ticks_msec() + 15000
	if ad_waiting() or not _pending().is_empty(): return
	if not snapshot.is_empty() and Time.get_ticks_msec() - _received_msec < 30000: return
	refresh()

func _process(_delta: float) -> void:
	var live: String = _live_binding()
	if live != _binding:
		_binding = live; snapshot = {}; busy = false; run_authorized = false; _request_id = ""; _command = {}; _ad_nonce = ""; _poll_until = 0;_ad_before=-1;_ad_day="";ad_delivery_state="idle";_ad_expires_at=0;_ad_attempts=0;_ad_earned_seen=false;_ad_reward_notice={}
		_prepared_ad={};_ad_open_requested=false;_ad_prepare_next=0
		_load_ad_wait()
		_load_prepared_ad()
		_warm_next_at = Time.get_ticks_msec() + 1500
		status = "account_changed"; changed.emit()
	_prewarm_if_due()
	_prepare_ad_if_due()
	if busy and Time.get_ticks_msec() > _deadline:
		busy = false; status = "connection_timeout"
		if _command.get("action",{}).get("kind")=="ad_intent": ad_delivery_state="verification_unavailable"
		changed.emit()
	if not _ad_nonce.is_empty() and _ad_expires_at>0 and _ad_now()>_ad_expires_at:
		ad_delivery_state="expired";_clear_ad_wait();changed.emit()
	if _poll_until > Time.get_ticks_msec() and not busy and Time.get_ticks_msec() > _read_at:
		_ad_attempts+=1
		refresh()
func refresh() -> bool:
	if busy: return false
	var live: String = _live_binding()
	if live != _binding:
		_binding = live; snapshot = {}; run_authorized = false; _request_id = ""; _command = {}; _ad_nonce = ""; _poll_until = 0;_ad_before=-1;_ad_day="";ad_delivery_state="idle";_ad_expires_at=0;_ad_attempts=0;_ad_earned_seen=false;_ad_reward_notice={}
		_prepared_ad={};_ad_open_requested=false;_ad_prepare_next=0
		_load_ad_wait()
		_load_prepared_ad()
	if _binding.length() != 64: status = "google_sign_in_required"; changed.emit(); return false
	var pending: Dictionary = _pending()
	if pending.has("error"): status = "recovery_required"; changed.emit(); return false
	if pending.is_empty() and not snapshot.is_empty() and Time.get_ticks_msec()-_received_msec<15000 and not ad_waiting(): return true
	return _dispatch(pending)
func submit(action: Dictionary) -> bool:
	if busy or not event_enabled() or snapshot.get("event") == null or not _pending().is_empty() or _binding != _live_binding(): return false
	if _bridge() == null: status = "native_update_required"; changed.emit(); return false
	var command: Dictionary = canonical_command({"event_id": snapshot.event.id, "request_id": Crypto.new().generate_random_bytes(16).hex_encode(), "revision": snapshot.get("revision", 0), "action": action.duplicate(true)})
	if command.is_empty(): status = "invalid_command"; changed.emit(); return false
	var file: FileAccess = FileAccess.open(_path() + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(command)); file.flush()
	var error: Error = file.get_error(); file.close()
	if error != OK or DirAccess.rename_absolute(_path() + ".tmp", _path()) != OK: return false
	return _dispatch(command)
func _dispatch(command: Dictionary) -> bool:
	if not command.is_empty():
		command = canonical_command(command)
		if command.is_empty(): status = "recovery_required"; changed.emit(); return false
	var native: Object = _bridge()
	if native == null: status = "native_update_required"; changed.emit(); return false
	_command = command; _request_id = str(command.get("request_id", Crypto.new().generate_random_bytes(16).hex_encode()))
	busy = true; status = "sending_action" if not command.is_empty() and not snapshot.is_empty() else "refreshing" if not snapshot.is_empty() else "connecting"; _deadline = Time.get_ticks_msec() + 46000; _read_at = Time.get_ticks_msec() + (_ad_poll_delay(_ad_attempts) if not _ad_nonce.is_empty() else 4000)
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
		for field: String in ["missions","milestones"]:
			var normalized: Array[int]=[]
			for value: Variant in data.get("state",{}).get(field,[]): normalized.append(int(value))
			data.state[field]=normalized
		snapshot = data; _received_msec = Time.get_ticks_msec(); _command = {}; status = "connected"
		if action == "arena_finish":
			var arena_path: String="user://odyssey_arena_"+_binding+".json"
			if FileAccess.file_exists(arena_path): DirAccess.remove_absolute(arena_path)
		_observe_ad_delivery(data)
		if ad_waiting(): _read_at=Time.get_ticks_msec()+_ad_poll_delay(_ad_attempts)
		if action == "buy_dice":
			var paid: Node = get_node_or_null("/root/PavilionManager/PaidGameplayV2")
			if paid != null: paid.call("refresh")
		if action == "ad_intent" and data.get("ad_intent") is Dictionary:
			_prepared_ad={"nonce":str(data.ad_intent.nonce),"expires_at":int(data.ad_intent.expires_at),"owner":_binding,"event_id":str(data.get("event",{}).get("id","")),"day":str(data.state.get("day",""))}
			_persist_prepared_ad()
			if ad_waiting():_clear_prepared_ad()
			elif _ad_open_requested:_activate_prepared_ad()
			else:ad_delivery_state="idle"
		var mail: Node = get_node_or_null("/root/ServerMailManager")
		if mail != null and action in ["roll", "route", "counter", "milestone", "task", "missions_all", "arena_finish"]:
			if mail.has_method("hint_pending_delivery"): mail.call("hint_pending_delivery")
			elif mail.has_method("refresh"): mail.call("refresh", true)
	elif result_status in ["REVISION_OR_OWNERSHIP_CONFLICT", "INVALID_REQUEST"] and not _command.is_empty():
		# These HTTP responses confirm this id was not committed; uncertain
		# transport failures keep the exact durable request for recovery.
		if DirAccess.remove_absolute(_path()) == OK:
			_command = {}; call_deferred("refresh")
	if not success and action=="ad_intent": ad_delivery_state="verification_unavailable" if _ad_open_requested else "idle"
	finished.emit(action, success); changed.emit()
func _prepared_ad_path() -> String:return "user://odyssey_prepared_ad_"+_binding+".json" if _binding.length()==64 else ""
func _clear_prepared_ad() -> void:
	_prepared_ad={}
	if not _prepared_ad_path().is_empty() and FileAccess.file_exists(_prepared_ad_path()):DirAccess.remove_absolute(_prepared_ad_path())
func _persist_prepared_ad() -> void:
	if _prepared_ad_path().is_empty():return
	var file:=FileAccess.open(_prepared_ad_path(),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(_prepared_ad));file.close()
func _load_prepared_ad() -> void:
	if ad_waiting() or _prepared_ad_path().is_empty() or not FileAccess.file_exists(_prepared_ad_path()):return
	var file:=FileAccess.open(_prepared_ad_path(),FileAccess.READ)
	if file==null or file.get_length()>2048:return
	var data: Variant=JSON.parse_string(file.get_as_text())
	if data is Dictionary and data.get("owner")==_binding and _matches(data.get("nonce"),"^[a-f0-9]{32}$") and _whole(data.get("expires_at"),1,4102444800):_prepared_ad=data
func _prepared_ad_valid() -> bool:
	return event_active() and not _prepared_ad.is_empty() and _prepared_ad.get("owner")==_live_binding() and _prepared_ad.get("event_id")==snapshot.get("event",{}).get("id") and _prepared_ad.get("day")==snapshot.get("state",{}).get("day") and int(_prepared_ad.get("expires_at",0))>_ad_now()+15
func _activate_prepared_ad() -> bool:
	if not _prepared_ad_valid():return false
	_ad_before=int(snapshot.get("state",{}).get("daily_ads",0));_ad_day=str(snapshot.get("state",{}).get("day",""))
	_ad_nonce=str(_prepared_ad.nonce);_ad_expires_at=int(_prepared_ad.expires_at);_clear_prepared_ad();_ad_open_requested=false
	_ad_attempts=0;_ad_cancelled=false;_ad_earned_seen=false;ad_delivery_state="watching"
	if not _save_ad_wait():ad_delivery_state="journal_failed";_ad_nonce="";changed.emit();return false
	_show_ad();changed.emit();return true
func _prepare_ad_if_due() -> void:
	if not event_active():return
	if not _can_prewarm() or _backgrounded or busy or ad_waiting() or _binding.length()!=64 or snapshot.is_empty() or Time.get_ticks_msec()<_ad_prepare_next:return
	if get_tree().get_first_node_in_group("player")!=null or not _pending().is_empty():return
	if _prepared_ad_valid():return
	var event: Variant=snapshot.get("event")
	if not event is Dictionary or not bool(event.get("enabled",false)) or not bool(event.get("ads_enabled",false)) or _ad_now()<int(event.get("starts_at",0)) or _ad_now()>=int(event.get("ends_at",0)):return
	if int(snapshot.get("state",{}).get("daily_ads",0))>=2 or ad_metadata().get("configured",true)==false:return
	var ads: Node=get_node_or_null("/root/MonetizationManager")
	if ads==null or not bool(ads.call("rewarded_available","odyssey_roll")):return
	_ad_prepare_next=Time.get_ticks_msec()+60000;_ad_open_requested=false
	submit({"kind":"ad_intent"})
func watch_ad() -> bool:
	if not event_active() or not bool(snapshot.event.get("ads_enabled",false)):return false
	if busy and _command.get("action",{}).get("kind")=="ad_intent":_ad_open_requested=true;ad_delivery_state="preparing";changed.emit();return true
	var ads: Node = get_node_or_null("/root/MonetizationManager")
	if ad_waiting(): return false
	if snapshot.get("state",{}).get("ad_delivery",snapshot.get("ad_delivery",{})).get("configured",true)==false: ad_delivery_state="configuration_required";changed.emit();return false
	var expected: String=str(snapshot.get("state",{}).get("ad_delivery",snapshot.get("ad_delivery",{})).get("expected_unit",""))
	var unit: String=str(ProjectSettings.get_setting("monetization/admob/rewarded_ad_unit_id",""))
	if not expected.is_empty() and not unit.is_empty() and expected!=unit: ad_delivery_state="configuration_mismatch";changed.emit();return false
	if int(snapshot.get("state",{}).get("daily_ads",0))>=2: ad_delivery_state="limit_reached";changed.emit();return false
	if ads == null or not bool(ads.call("rewarded_available", "odyssey_roll")):
		ad_delivery_state = "unavailable"; changed.emit(); return false
	if _prepared_ad_valid():return _activate_prepared_ad()
	_ad_open_requested=true
	ad_delivery_state="preparing";changed.emit()
	var sent: bool=submit({"kind": "ad_intent"})
	if not sent: ad_delivery_state="unavailable";changed.emit()
	return sent
func _show_ad() -> void:
	if not event_active():_ad_open_requested=false;return
	var ads: Node = get_node_or_null("/root/MonetizationManager")
	if ads == null: return
	var provider: Node = ads.get("provider")
	if provider == null or not provider.has_method("prepare_odyssey_ssv"): ad_delivery_state="unavailable";_clear_ad_wait();return
	provider.call("prepare_odyssey_ssv", _ad_nonce)
	if not bool(ads.call("show_rewarded", "odyssey_roll")): ad_delivery_state="unavailable";_clear_ad_wait()
static func _ad_poll_delay(attempt: int) -> int:
	return [400,700,1200,2000,4000,8000,15000][clampi(attempt,0,6)]
func _ad_earned(placement: String) -> void:
	if placement!="odyssey_roll" or _ad_nonce.is_empty(): return
	_ad_earned_seen=true;_ad_cancelled=false;ad_delivery_state="verifying";_save_ad_wait()
	_poll_until=Time.get_ticks_msec()+maxi(0,_ad_expires_at-_ad_now())*1000;_read_at=0;_ad_attempts=0;changed.emit()
func ad_metadata() -> Dictionary:
	return snapshot.get("state",{}).get("ad_delivery",snapshot.get("ad_delivery",{}))
func ad_control() -> Dictionary:
	if ad_delivery_state=="preparing": return {"enabled":false,"text":"MENYIAPKAN IKLAN…"}
	if ad_waiting(): return {"enabled":false,"text":"MEMVERIFIKASI HADIAH…"}
	var used: int=int(snapshot.get("state",{}).get("daily_ads",0))
	if used>=2: return {"enabled":false,"text":"HADIAH HARI INI 2/2"}
	if ad_metadata().get("configured",true)==false: return {"enabled":false,"text":"IKLAN BELUM DIAKTIFKAN"}
	var ads: Node=get_node_or_null("/root/MonetizationManager")
	if ads==null: return {"enabled":false,"text":"IKLAN BELUM TERSEDIA"}
	var policy: Dictionary=ads.call("get_rewarded_policy_status","odyssey_roll") if ads.has_method("get_rewarded_policy_status") else {}
	var cooldown: int=int(policy.get("cooldown_remaining_seconds",0))
	if cooldown>0: return {"enabled":false,"text":"IKLAN BERIKUTNYA · %ds" % cooldown}
	var provider: Node=ads.get("provider")
	if provider!=null and provider.has_method("warm_rewarded_ad"): provider.call("warm_rewarded_ad")
	var ad_ready: bool=bool(ads.call("rewarded_available","odyssey_roll"))
	return {"enabled":ad_ready,"text":"+1 DADU · IKLAN %d/2" % used if ad_ready else "IKLAN DISIAPKAN…"}
func get_ad_reward_notice() -> Dictionary: return _ad_reward_notice.duplicate(true)
func acknowledge_ad_reward_notice(key: String) -> void:
	if str(_ad_reward_notice.get("key",""))==key: _ad_reward_notice={}
func _ad_finished(placement: String, result: String) -> void:
	if placement != "odyssey_roll" or _ad_nonce.is_empty(): return
	# SDK completion is presentation evidence, never a currency grant.
	_ad_cancelled=not _ad_earned_seen and result in ["cancelled","unavailable","failed","timeout"]
	if _ad_cancelled: _ad_cancelled_at=_ad_now()
	ad_delivery_state="verifying" if result=="completed" or _ad_earned_seen else "checking"
	_save_ad_wait()
	_poll_until=Time.get_ticks_msec()+maxi(0,_ad_expires_at-_ad_now())*1000;_read_at=0;_ad_attempts=0;changed.emit()
func ad_waiting() -> bool: return not _ad_nonce.is_empty()
func ad_feedback() -> String:
	match ad_delivery_state:
		"preparing": return "Menyiapkan verifikasi dan membuka iklan…"
		"limit_reached": return "2 hadiah iklan hari ini sudah diterima · tersedia lagi besok"
		"watching": return "Iklan sedang ditampilkan"
		"verifying","checking": return "Memverifikasi hadiah iklan…" if _ad_attempts<3 else "Hadiah masih diverifikasi · tidak perlu menonton ulang"
		"credited": return "+1 Dadu iklan terkonfirmasi server" if Time.get_ticks_msec()<_ad_feedback_until else ""
		"configuration_required": return "Hadiah iklan belum siap di server"
		"configuration_mismatch": return "Unit iklan tidak sesuai server · iklan tidak dibuka"
		"verification_unavailable": return "Verifikasi iklan belum siap · video belum dibuka"
		"expired": return "Konfirmasi iklan belum diterima · sinkronkan kembali"
		"journal_failed": return "Penyimpanan belum siap · iklan tidak dibuka"
		"unavailable": return "Iklan belum tersedia. Coba lagi nanti."
		"cancelled": return "Iklan dibatalkan · dadu tidak dipotong"
	return ""
func _ad_now() -> int: return server_time() if not snapshot.is_empty() else int(Time.get_unix_time_from_system())
func _ad_path() -> String: return "user://odyssey_ad_"+_binding+".json" if _binding.length()==64 else ""
func _save_ad_wait() -> bool:
	if _ad_path().is_empty(): return false
	var file:=FileAccess.open(_ad_path()+".tmp",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"owner":_binding,"nonce":_ad_nonce,"event_id":snapshot.get("event",{}).get("id",""),"expires_at":_ad_expires_at,"baseline":_ad_before,"day":_ad_day,"cancelled":_ad_cancelled,"earned":_ad_earned_seen,"cancelled_at":_ad_cancelled_at}));file.flush();var error: Error=file.get_error();file.close()
	return error==OK and DirAccess.rename_absolute(_ad_path()+".tmp",_ad_path())==OK
func _load_ad_wait() -> void:
	if _ad_path().is_empty() or not FileAccess.file_exists(_ad_path()): return
	var file:=FileAccess.open(_ad_path(),FileAccess.READ)
	if file==null or file.get_length()>2048: return
	var value: Variant=JSON.parse_string(file.get_as_text())
	if not value is Dictionary or value.get("owner")!=_binding or not _matches(value.get("nonce"),"^[a-f0-9]{32}$") or not _whole(value.get("expires_at"),1,4102444800): return
	if int(value.expires_at)<=_ad_now(): ad_delivery_state="expired";DirAccess.remove_absolute(_ad_path());return
	_ad_cancelled_at=int(value.get("cancelled_at",_ad_now()));_ad_earned_seen=bool(value.get("earned",false));_ad_cancelled=bool(value.get("cancelled",false));_ad_nonce=str(value.nonce);_ad_expires_at=int(value.expires_at);_ad_before=int(value.get("baseline",-1));_ad_day=str(value.get("day",""));ad_delivery_state="verifying";_ad_attempts=0
	_poll_until=Time.get_ticks_msec()+(_ad_expires_at-_ad_now())*1000;_read_at=0
func _clear_ad_wait() -> void:
	if not _ad_path().is_empty() and FileAccess.file_exists(_ad_path()): DirAccess.remove_absolute(_ad_path())
	_ad_nonce="";_ad_before=-1;_poll_until=0;_ad_expires_at=0
func _observe_ad_delivery(data: Dictionary) -> void:
	var receipt: Dictionary=data.get("state",{}).get("ad_delivery",data.get("ad_delivery",{}))
	if receipt.get("configured",true)==false and _ad_nonce.is_empty(): ad_delivery_state="configuration_required"
	if not _prepared_ad.is_empty() and str(receipt.get("nonce",""))==str(_prepared_ad.get("nonce","")) and receipt.get("stage") in ["credited","expired"]:_clear_prepared_ad()
	if _ad_nonce.is_empty(): return
	var same: bool=str(receipt.get("nonce",""))==_ad_nonce
	var confirmed: bool=same and receipt.get("stage")=="credited"
	# Older deployed workers expose authoritative daily counts but no receipt metadata.
	if receipt.is_empty(): confirmed=_ad_before>=0 and (int(data.state.get("daily_ads",0))>_ad_before or (str(data.state.get("day",""))!=_ad_day and int(data.state.get("daily_ads",0))>0))
	if confirmed:
		_ad_reward_notice={"key":_ad_nonce,"owner":_binding,"event_id":str(data.get("event",{}).get("id","")),"amount":1}
		ad_delivery_state="credited";_ad_feedback_until=Time.get_ticks_msec()+8000;_clear_ad_wait()
	elif same and receipt.get("stage")=="expired": ad_delivery_state="expired";_clear_ad_wait()
	elif _ad_cancelled and not _ad_earned_seen and _ad_now()-_ad_cancelled_at>=30: ad_delivery_state="cancelled";_clear_ad_wait()

func _gate_fail(reason: String) -> bool:
	run_gate_error=reason
	_preparing_run=false
	return false
func _connection_gate_reason() -> String:
	if status in ["ACCOUNT_HELD","paid_account_on_hold"]:return "ACCOUNT_HELD"
	if status in ["APP_CHECK_UNAVAILABLE","APP_CHECK_NOT_READY"]:return "APP_VERIFICATION_UNAVAILABLE"
	if status in ["AUTH_REQUIRED","AUTH_UNAVAILABLE","UNAUTHENTICATED"]:return "SIGN_IN_REQUIRED"
	return "CONNECTION_UNAVAILABLE"
func prepare_scene_run(continuing: bool) -> bool:
	if _preparing_run: run_gate_error="VERIFICATION_BUSY";return false
	run_gate_error="";_preparing_run=true;run_authorized=false
	var equipment: Node=get_node_or_null("/root/EquipmentManager")
	var armament: String=str(equipment.call("get_loadout_equipped_item_id","armament")) if equipment!=null else ""
	if continuing and equipment!=null:
		armament=str(equipment.get("active_run_loadout_snapshot").get("equipped_item_ids",{}).get("armament",""))
	if armament!="heavenweaver_compass":_preparing_run=false;return true
	var account_binding: String=_live_binding()
	if account_binding.length()!=64:return _gate_fail("SIGN_IN_REQUIRED")
	# A fresh authenticated read is already a lease. Reuse it instead of forcing
	# another event round trip on every Begin, while pending commands still recover.
	if _binding==account_binding and status in ["connected","refreshing"] and _pending().is_empty() and snapshot.get("compass_authorized",false)==true and Time.get_ticks_msec()-_received_msec<60000:
		run_authorized=true;_preparing_run=false;return true
	while busy:await get_tree().process_frame
	if account_binding!=_live_binding():return _gate_fail("ACCOUNT_CHANGED")
	if _pending().has("error"):return _gate_fail("RECOVERY_REQUIRED")
	var ok: bool=refresh()
	while busy:await get_tree().process_frame
	if account_binding!=_live_binding():return _gate_fail("ACCOUNT_CHANGED")
	if ok and status=="connected" and not snapshot.has("compass_authorized"):
		ok=refresh()
		while busy:await get_tree().process_frame
	if account_binding!=_live_binding():return _gate_fail("ACCOUNT_CHANGED")
	if not ok or status!="connected":return _gate_fail(_connection_gate_reason())
	if snapshot.get("state",{}).get("compass_verification")=="unavailable":return _gate_fail("COMPASS_VERIFICATION_UNAVAILABLE")
	if snapshot.get("compass_authorized",false)!=true:return _gate_fail("COMPASS_GRANT_REQUIRED")
	run_authorized=Time.get_ticks_msec()-_received_msec<=60000
	_preparing_run=false
	if not run_authorized:return _gate_fail("CONNECTION_UNAVAILABLE")
	return true
