extends Node

## Server mail cache is presentation only. Reward + permanent receipt markers
## are committed together through LiveOpsManager and RewardManager's journal.
signal server_mail_changed
const DOMAIN: String = "server_mail"
var _state: Dictionary = {}
var _owner: String = ""
var _auth_node: Node
var _http: HTTPRequest
var _queue: Array[Dictionary] = []
var _pending: Dictionary = {}
var _busy: bool = false
var _waiting_token: bool = false
var _nonce: int = 0
var _refreshing: bool = false
var _incoming: Array[Dictionary] = []
var _status: String = "Sign in to receive server mail"
var _server_time: int = 0
var _observed_ticks: int = 0
var _read_attempts: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 30.0
	_http.body_size_limit = 1048576
	_http.max_redirects = 0
	add_child(_http)
	_http.request_completed.connect(_on_response)
	PlayerIdentityManager.profile_changed.connect(_on_profile)
	call_deferred("_initialize")
	var timer := Timer.new()
	timer.wait_time = 60.0
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()

func _load_state() -> void:
	var saved: Dictionary = SaveManager.read_save_data(DOMAIN)
	if bool(saved.get("success",false)) and bool(saved.get("exists",false)):
		var loaded_state: Dictionary = saved.get("data",{})
		if _valid_id(str(loaded_state.get("installation_id",""))) and loaded_state.get("cache") is Dictionary:
			_state = loaded_state.duplicate(true)
			return
		_status = "Mail save unavailable"
		return
	var path: String = SaveManager.get_save_path(DOMAIN)
	if bool(saved.get("exists",false)) or FileAccess.file_exists(path+".backup") or FileAccess.file_exists(path+".tmp") or FileAccess.file_exists(path+".rollback") or SaveManager.is_save_write_blocked(DOMAIN):
		_status = "Mail save unavailable"
		return
	var data: Dictionary = {"version":1,"installation_id":Crypto.new().generate_random_bytes(16).hex_encode(),"cache":{}}
	if bool(SaveManager.write_save_data(DOMAIN,data).get("success",false)):
		_state = data

func _initialize() -> void:
	var firebase: Node = get_node_or_null("/root/Firebase")
	if not OS.has_feature("android") or firebase == null:
		return
	_auth_node = firebase.auth
	_auth_node.id_token_result.connect(_on_token)
	_auth_node.id_token_error.connect(func(_error: String):
		if _waiting_token: _fail("Sign-in token unavailable"))
	_on_profile(PlayerIdentityManager.get_profile_snapshot())

func _current_owner() -> String:
	return PlayerIdentityServerClient._current_owner()

func _on_profile(snapshot: Dictionary) -> void:
	var current: String = _current_owner()
	if current != _owner:
		_nonce += 1
		_http.cancel_request()
		_queue.clear()
		_read_attempts.clear()
		_pending.clear()
		_busy = false
		_waiting_token = false
		_refreshing = false
		_incoming.clear()
		_owner = current
		_server_time = 0
		_status = "Sign in to receive server mail" if current.is_empty() else "Server mail ready"
		_emit_changed()
	if bool(snapshot.get("server_registered",false)) and str(snapshot.get("server_status","")) == "connected":
		refresh()

func _valid_id(value: String) -> bool:
	if value.length() != 32: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true

func get_status() -> String:
	return _status

func _mail_time() -> int:
	return _server_time + maxi(0,int(float(Time.get_ticks_msec()-_observed_ticks)/1000.0)) if _server_time > 0 else 0

func get_mail_ids() -> Array[String]:
	var result: Array[String] = []
	var cache: Dictionary = _state.get("cache",{})
	var entries: Variant = cache.get(_owner,[])
	if _owner.is_empty() or not entries is Array: return result
	for entry: Variant in entries:
		if entry is Dictionary and _valid_mail(entry): result.append("server:"+str(entry.mail_id))
	return result

func _has_local_receipt(mail_id: String) -> bool:
	var marker: String = "liveops:server_mail:claim:"+_owner+":"+mail_id
	return marker in PavilionManager.state.get("claimed_milestone_ids",[])

func get_mail(id: String) -> Dictionary:
	var raw_id: String = id.trim_prefix("server:")
	var cache: Dictionary = _state.get("cache",{})
	var entries: Variant = cache.get(_owner,[])
	if not entries is Array or _owner.is_empty(): return {}
	for entry: Variant in entries:
		if entry is Dictionary and _valid_mail(entry) and str(entry.get("mail_id","")) == raw_id:
			var mail: Dictionary = entry.duplicate(true)
			if _has_local_receipt(raw_id): mail.claimed = true
			if not bool(mail.get("pending",false)) and _mail_time() > 0 and int(mail.get("expires_at",0)) <= _mail_time():
				mail.expired = true
				mail.can_claim = false
			return mail
	return {}

func is_busy_for(id: String) -> bool:
	if _busy and str(_pending.get("id","")) == id: return true
	for item: Dictionary in _queue:
		if str(item.get("id","")) == id: return true
	return false

func refresh() -> void:
	if _refreshing or _owner.is_empty() or _state.is_empty() or _auth_node == null: return
	if not bool(PlayerIdentityManager.get_profile_snapshot().get("server_registered",false)): return
	_refreshing = true
	_incoming.clear()
	if not _enqueue("list","",{},""): _refreshing = false

func claim_mail(id: String) -> bool:
	var mail: Dictionary = get_mail(id)
	if mail.is_empty() or bool(mail.get("claimed",false)) or not bool(mail.get("can_claim",false)) or is_busy_for(id) or SaveManager.is_progress_read_only(): return false
	return _enqueue("claim",id,{"mail_id":id.trim_prefix("server:"),"installation_id":_state.get("installation_id","")})

func mark_read(id: String) -> bool:
	var mail: Dictionary = get_mail(id)
	if mail.is_empty(): return false
	if bool(mail.get("read",false)): return true
	if Time.get_ticks_msec()-int(_read_attempts.get(id,-15000)) < 15000: return false
	_read_attempts[id] = Time.get_ticks_msec()
	return _enqueue("read",id,{"mail_id":id.trim_prefix("server:")})

func mark_all_read() -> bool:
	if get_mail_ids().is_empty(): return true
	return _enqueue("read_all","",{})

func can_delete_mail(id: String) -> bool:
	var mail: Dictionary = get_mail(id)
	return not mail.is_empty() and not is_busy_for(id) and not bool(mail.get("pending",false)) and not bool(mail.get("blocked_on_other_device",false)) and (bool(mail.get("claimed",false)) or bool(mail.get("expired",false)) or bool(mail.get("cancelled",false)))

func delete_mail(id: String) -> bool:
	return _enqueue("delete",id,{"mail_id":id.trim_prefix("server:")}) if can_delete_mail(id) else false

func _enqueue(kind: String,id: String,payload: Dictionary,cursor: String = "") -> bool:
	if _owner.is_empty() or _state.is_empty() or _auth_node == null or _queue.size() >= 64: return false
	var key: String = kind+":"+id+":"+cursor
	if _busy and str(_pending.get("key","")) == key: return true
	for item: Dictionary in _queue:
		if str(item.get("key","")) == key: return true
	_queue.append({"kind":kind,"id":id,"payload":payload,"cursor":cursor,"key":key,"owner":_owner,"refreshed_token":false})
	call_deferred("_start_next")
	_emit_changed()
	return true

func _start_next() -> void:
	if _busy or _queue.is_empty(): return
	if _owner != _current_owner(): _on_profile(PlayerIdentityManager.get_profile_snapshot()); return
	_pending = _queue.pop_front()
	if str(_pending.owner) != _owner: call_deferred("_start_next"); return
	_busy = true
	_waiting_token = true
	_nonce += 1
	var nonce: int = _nonce
	_status = "Syncing server mail"
	_auth_node.get_id_token(bool(_pending.get("refreshed_token",false)))
	get_tree().create_timer(10.0).timeout.connect(func():
		if _nonce == nonce and _waiting_token: _fail("Sign-in token timed out"))
	_emit_changed()

func _on_token(token: String) -> void:
	if not _waiting_token or not _busy: return
	_waiting_token = false
	if _owner != _current_owner(): _on_profile(PlayerIdentityManager.get_profile_snapshot()); return
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$")
	if token.length() > 8192 or pattern.search(token) == null: _fail("Invalid sign-in token"); return
	var kind: String = str(_pending.kind)
	var path: String = "/v1/mail/"+kind
	if kind == "list": path += "?installation_id="+str(_state.installation_id)+"&after="+str(_pending.cursor)
	var headers := PackedStringArray(["Content-Type: application/json","Accept: application/json","User-Agent: GodotEngine/4.7.2","Host: "+PlayerIdentityServerClient._endpoint_host(),"X-Jade-Owner-Binding: "+_owner,"X-Jade-Mail-Features: gifts-v2","X-Jade-Equipment-Catalog: jade-chain-v1","X-Jade-Returning-Glaive: v1","X-Jade-Client-Version: "+str(ProjectSettings.get_setting("application/config/version","1.0.6")),"Authorization: Bearer "+token])
	var error: Error = _http.request(PlayerIdentityServerClient._prepare_route(_http,path),headers,HTTPClient.METHOD_GET if kind == "list" else HTTPClient.METHOD_POST,"" if kind == "list" else JSON.stringify(_pending.payload))
	if error != OK: _fail("Server request could not start")

func _on_response(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if not _busy: return
	if _owner != _current_owner(): _on_profile(PlayerIdentityManager.get_profile_snapshot()); return
	if result != HTTPRequest.RESULT_SUCCESS: _fail("Offline · retry server sync"); return
	if code == 401 and not bool(_pending.get("refreshed_token",false)):
		var again: Dictionary = _pending.duplicate(true)
		again.refreshed_token = true
		_queue.push_front(again)
		_finish()
		return
	var parsed := JSON.new()
	if body.is_empty() or parsed.parse(body.get_string_from_utf8()) != OK or not parsed.data is Dictionary: _fail("Invalid server response"); return
	var data: Dictionary = parsed.data
	if code == 409 and str(data.get("error","")) == "account_changed" and not bool(_pending.get("refreshed_token",false)):
		var again: Dictionary = _pending.duplicate(true)
		again.refreshed_token = true
		_queue.push_front(again)
		_finish()
		return
	if code != 200:
		var message: String = "Server mail HTTP "+str(code)
		if str(data.get("error","")) == "claimed_on_other_device": message = "Claim started on another device"
		if str(data.get("error","")) == "mail_unavailable": message = "Mail expired or cancelled"
		_fail(message)
		return
	if str(data.get("owner_binding","")) != _owner: _fail("Mail account mismatch"); return
	var kind: String = str(_pending.kind)
	if kind not in ["list","read_all"] and str(data.get("mail_id","")) != str(_pending.id).trim_prefix("server:"): _fail("Mail response mismatch"); return
	if kind in ["read","read_all","delete"] and data.get("ok") != true: _fail("Mail action not confirmed"); return
	if kind == "list":
		if not _accept_page(data): _fail("Invalid mail catalog"); return
	elif kind == "claim":
		if not _apply_delivery(data): _fail("Claim could not be saved · retry after restart"); return
	elif kind == "ack":
		_update_cache(str(_pending.id),"claimed")
	elif kind == "delete":
		_update_cache(str(_pending.id),"deleted")
	elif kind == "read":
		_update_cache(str(_pending.id),"read")
	elif kind == "read_all":
		for id: String in get_mail_ids(): _update_cache(id,"read",false)
		_persist_cache()
	_status = "Server mail synced"
	_finish()

func _accept_page(data: Dictionary) -> bool:
	if typeof(data.get("version")) not in [TYPE_INT,TYPE_FLOAT] or float(data.version) != 1.0 or not data.get("entries") is Array or (data.entries as Array).size() > 40: return false
	if typeof(data.get("server_time")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.server_time)) or float(data.server_time) <= 0 or floorf(float(data.server_time)) != float(data.server_time): return false
	var cursor: String = str(data.get("next_cursor",""))
	if not cursor.is_empty() and not _valid_id(cursor): return false
	if not cursor.is_empty() and cursor <= str(_pending.cursor): return false
	for raw: Variant in data.entries:
		if not raw is Dictionary or not _valid_mail(raw): return false
		for old: Dictionary in _incoming:
			if str(old.mail_id) == str(raw.mail_id): return false
		_incoming.append((raw as Dictionary).duplicate(true))
	if _incoming.size() > 2000: return false
	_server_time = int(data.get("server_time",0))
	_observed_ticks = Time.get_ticks_msec()
	if not cursor.is_empty(): return _enqueue("list","",{},cursor)
	_refreshing = false
	_incoming.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.created_at) > int(b.created_at))
	var cache: Dictionary = _state.get("cache",{}).duplicate(true)
	cache[_owner] = _incoming.duplicate(true)
	_state.cache = cache
	_persist_cache()
	for mail: Dictionary in _incoming:
		if bool(mail.get("pending",false)) and _has_local_receipt(str(mail.mail_id)) and _valid_id(str(mail.get("receipt_id",""))):
			_enqueue("ack",str(mail.id),{"mail_id":mail.mail_id,"installation_id":_state.installation_id,"receipt_id":mail.receipt_id})
	return true

func _valid_reward(reward: Dictionary) -> bool:
	for key: Variant in reward:
		if str(key) not in ["spirit_stone","items","celestial_jade","pavilion_seal"]: return false
	if not reward.has("spirit_stone") or not reward.get("items") is Dictionary: return false
	var has_grant: bool = false
	for pair: Array in [["spirit_stone",100000],["celestial_jade",10000],["pavilion_seal",100]]:
		var raw: Variant = reward.get(pair[0],0)
		if typeof(raw) not in [TYPE_INT,TYPE_FLOAT]: return false
		var amount: float = float(raw)
		if not is_finite(amount) or amount < 0 or amount > int(pair[1]) or floorf(amount) != amount: return false
		if amount > 0: has_grant = true
	var equipment_count: int = 0
	for key: Variant in reward.items:
		var id: String = str(key)
		var maximum: int = 500 if id == "refinement_shard" else 1
		if id != "refinement_shard":
			if not EquipmentManager.has_item_definition(id): return false
			equipment_count += 1
			if equipment_count > 5: return false
		var raw: Variant = reward.items[key]
		if typeof(raw) not in [TYPE_INT,TYPE_FLOAT]: return false
		var amount: float = float(raw)
		if not is_finite(amount) or amount < 1 or amount > maximum or floorf(amount) != amount: return false
		has_grant = true
	return has_grant

func _valid_mail(mail: Dictionary) -> bool:
	if not _valid_id(str(mail.get("mail_id",""))) or str(mail.get("id","")) != "server:"+str(mail.mail_id): return false
	for pair: Array in [["title",100],["body",4000],["sender",60]]:
		if not mail.get(pair[0]) is String or str(mail[pair[0]]).length() > int(pair[1]): return false
	for key: String in ["created_at","expires_at"]:
		if typeof(mail.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(mail[key])) or floorf(float(mail[key])) != float(mail[key]): return false
	for key: String in ["read","claimed","pending","can_claim","blocked_on_other_device","cancelled","expired"]:
		if not mail.get(key) is bool: return false
	if not mail.get("reward") is Dictionary: return false
	return (mail.reward as Dictionary).is_empty() or _valid_reward(mail.reward)

func _apply_delivery(data: Dictionary) -> bool:
	var id: String = str(_pending.id).trim_prefix("server:")
	if str(data.get("mail_id","")) != id: return false
	if str(data.get("delivery_state","")) == "claimed":
		_update_cache("server:"+id,"claimed")
		return true
	if str(data.get("delivery_state","")) != "pending" or str(data.get("installation_id","")) != str(_state.installation_id) or not _valid_id(str(data.get("receipt_id",""))) or not data.get("reward") is Dictionary or not _valid_reward(data.reward): return false
	var authority: Node = get_node_or_null("/root/LiveOpsManager")
	if authority == null or not authority.apply_server_mail_reward(_owner,id,data.reward): return false
	_enqueue("ack","server:"+id,{"mail_id":id,"installation_id":_state.installation_id,"receipt_id":data.receipt_id})
	_update_cache("server:"+id,"applied")
	return true

func _update_cache(id: String,action: String,persist: bool = true) -> void:
	var entries: Array = (_state.get("cache",{}) as Dictionary).get(_owner,[]).duplicate(true)
	for i: int in range(entries.size()-1,-1,-1):
		if str(entries[i].get("id","")) != id: continue
		if action == "deleted": entries.remove_at(i)
		elif action == "read": entries[i].read = true
		else:
			entries[i].claimed = true
			entries[i].can_claim = false
			entries[i].pending = action == "applied"
	_state.cache[_owner] = entries
	if persist: _persist_cache()

func _persist_cache() -> void:
	# A failed cache write does not replay rewards; the authoritative local receipt
	# remains in the same journaled Pavilion transaction as the wallet changes.
	SaveManager.write_save_data(DOMAIN,_state)

func _fail(message: String) -> void:
	if str(_pending.get("kind","")) == "list":
		_refreshing = false
		_incoming.clear()
	_status = message
	_finish()

func _finish() -> void:
	_busy = false
	_waiting_token = false
	_pending.clear()
	_emit_changed()
	call_deferred("_start_next")

func _emit_changed() -> void:
	server_mail_changed.emit()
	var authority: Node = get_node_or_null("/root/LiveOpsManager")
	if authority != null: authority.live_ops_changed.emit()
