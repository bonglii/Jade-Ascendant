extends Node

## Server mail cache is presentation only. Reward + permanent receipt markers
## are committed together through LiveOpsManager and RewardManager's journal.
signal server_mail_changed
const DOMAIN: String = "server_mail"
const AUTO_SYNC_SECONDS: int=180
const OPEN_STALE_SECONDS: int=60
const MIN_SYNC_GAP_MSEC: int=15000
var _next_refresh_msec: int=0
var _last_started_msec: int=-MIN_SYNC_GAP_MSEC
var _last_success_msec: int=-AUTO_SYNC_SECONDS*1000
var _list_failures: int=0
var _backgrounded: bool=false
var _state: Dictionary = {}
var _owner: String = ""
var _auth_node: Node
var _http: Node
var _queue: Array[Dictionary] = []
var _pending: Dictionary = {}
var _busy: bool = false
var _waiting_token: bool = false
var _cached_token: String = ""
var _cached_token_until: int = 0
var _nonce: int = 0
var _refreshing: bool = false
var _incoming: Array[Dictionary] = []
var _status: String = "Sign in to receive server mail"
var _server_time: int = 0
var _observed_ticks: int = 0
var _read_attempts: Dictionary = {}
var _deleted_during_refresh: Dictionary = {}
var _operation_started_at: int = 0
var _last_elapsed_ms: int = 0
var _last_operation: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_state()
	_http = preload("res://scripts/network/mail_https_session.gd").new()
	_http.timeout = 30.0
	_http.body_size_limit = 1048576
	add_child(_http)
	_http.request_completed.connect(_on_response)
	PlayerIdentityManager.profile_changed.connect(_on_profile)
	call_deferred("_initialize")
	var timer := Timer.new()
	timer.name = "MailAutoSync"
	timer.wait_time = 15.0
	timer.timeout.connect(_poll_auto_sync)
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
		_deleted_during_refresh.clear()
		_pending.clear()
		_busy = false
		_waiting_token = false
		_refreshing = false
		_incoming.clear()
		_next_refresh_msec=0
		_last_started_msec=-MIN_SYNC_GAP_MSEC
		_last_success_msec=-AUTO_SYNC_SECONDS*1000
		_list_failures=0
		_cached_token = ""
		_cached_token_until = 0
		_owner = current
		var notices: Node = get_node_or_null("/root/AnnouncementCenter")
		if notices != null: notices.set_account_owner(current)
		_server_time = 0
		_status = "Sign in to receive server mail" if current.is_empty() else "Server mail ready"
		_emit_changed()
	if bool(snapshot.get("server_registered",false)) and str(snapshot.get("server_status","")) == "connected":
		_flush_pending_reads()
		refresh()

func _valid_id(value: String) -> bool:
	if value.length() != 32: return false
	for character: String in value:
		if not "0123456789abcdef".contains(character): return false
	return true

func get_status() -> String:
	return _status

func get_announcement_owner() -> String:
	return _owner

func is_announcement_seen(id: String) -> bool:
	var seen: Variant = _state.get("announcement_seen", {})
	if not seen is Dictionary: return false
	var ids: Variant = seen.get(_owner, [])
	return ids is Array and id in ids

func dismiss_announcement(id: String, account_owner: String) -> bool:
	if account_owner != _owner or account_owner.is_empty() or not _valid_id(id): return false
	var data: Dictionary = _state.duplicate(true)
	var raw: Variant = data.get("announcement_seen", {})
	var seen: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	var raw_ids: Variant = seen.get(account_owner, [])
	var ids: Array = raw_ids.duplicate() if raw_ids is Array else []
	if id not in ids: ids.append(id)
	while ids.size() > 500: ids.pop_front()
	if not seen.has(account_owner) and seen.size() >= 32: seen.erase(seen.keys()[0])
	seen[account_owner] = ids
	data.announcement_seen = seen
	var saved: bool = not data.is_empty() and bool(SaveManager.write_save_data(DOMAIN, data).get("success", false))
	if saved: _state = data
	_enqueue("announcement_read", id, {"announcement_id": id})
	return saved

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
	for part: Dictionary in _pending.get("parts",[]):
		if str(part.id) == id: return true
	for item: Dictionary in _queue:
		if str(item.get("id","")) == id: return true
	return false

func is_delivery_busy_for(id: String) -> bool:
	if _busy and str(_pending.get("kind", "")) not in ["list", "read", "read_all", "announcement_read"]:
		if str(_pending.get("id", "")) == id: return true
		for part: Dictionary in _pending.get("parts", []):
			if str(part.id) == id: return true
	for item: Dictionary in _queue:
		if str(item.get("id", "")) == id and str(item.kind) not in ["list", "read", "read_all", "announcement_read"]: return true
	return false

func get_session_status() -> Dictionary:
	return {"connections": int(_http.get("connection_count")) if _http != null else 0,
		"reused_requests": int(_http.get("reused_requests")) if _http != null else 0,
		"last_operation": _last_operation, "last_elapsed_ms": _last_elapsed_ms,
		"cache_letters": get_mail_ids().size(), "busy": _busy}

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_backgrounded=true
	elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
		_backgrounded=false
		if is_node_ready():refresh.call_deferred(true)

func _poll_auto_sync() -> void:
	_flush_pending_reads()
	refresh()

func _server_registered() -> bool:
	return bool(PlayerIdentityManager.get_profile_snapshot().get("server_registered",false))

func _refresh_due(now: int,on_open: bool=false) -> bool:
	if _backgrounded or _refreshing or now-_last_started_msec<MIN_SYNC_GAP_MSEC:return false
	if now>=_next_refresh_msec:return true
	return on_open and _list_failures==0 and now-_last_success_msec>=OPEN_STALE_SECONDS*1000

func refresh(on_open: bool=false) -> void:
	if _owner.is_empty() or _state.is_empty() or _auth_node==null:return
	if not _server_registered():return
	var now: int=Time.get_ticks_msec()
	if not _refresh_due(now,on_open):return
	_refreshing=true
	_deleted_during_refresh.clear()
	_incoming.clear()
	if _enqueue("list","",{},""):
		_last_started_msec=now
		_next_refresh_msec=now+AUTO_SYNC_SECONDS*1000
	else:
		_refreshing=false
		_next_refresh_msec=now+MIN_SYNC_GAP_MSEC

func claim_mail(id: String) -> bool:
	var mail: Dictionary = get_mail(id)
	if mail.is_empty() or bool(mail.get("claimed",false)) or not bool(mail.get("can_claim",false)) or is_delivery_busy_for(id) or SaveManager.is_progress_read_only(): return false
	return _enqueue("claim",id,{"mail_id":id.trim_prefix("server:"),"installation_id":_state.get("installation_id","")})

func _pending_read_ids() -> Array:
	var owners: Variant = _state.get("read_pending", {})
	if not owners is Dictionary: return []
	var ids: Variant = owners.get(_owner, [])
	return ids.duplicate() if ids is Array else []

func _set_pending_read_ids(ids: Array) -> void:
	var raw: Variant = _state.get("read_pending", {})
	var owners: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	if not owners.has(_owner) and owners.size() >= 32: owners.erase(owners.keys()[0])
	owners[_owner] = ids
	_state.read_pending = owners

func _flush_pending_reads() -> void:
	if _backgrounded or _owner.is_empty() or _owner != _current_owner() or _auth_node == null: return
	var sent: int = 0
	for raw_id: Variant in _pending_read_ids():
		var id: String = str(raw_id)
		if not _valid_id(id) or get_mail("server:" + id).is_empty(): continue
		if _queue.size() >= 48 or sent >= 8: break
		_enqueue("read", "server:" + id, {"mail_id": id})
		sent += 1

func mark_read(id: String) -> bool:
	var mail: Dictionary = get_mail(id)
	if mail.is_empty(): return false
	if bool(mail.get("read",false)): return true
	var raw_id: String = id.trim_prefix("server:")
	var ids: Array = _pending_read_ids()
	if raw_id not in ids:
		if ids.size() >= 2000: return false
		ids.append(raw_id)
		_set_pending_read_ids(ids)
	# Read status is non-economic: show it immediately, then reconcile on server.
	# Keep the intent with the owner so an offline close/restart cannot lose it.
	_update_cache(id, "read")
	_enqueue("read",id,{"mail_id":raw_id})
	_emit_changed()
	return true

func mark_all_read() -> bool:
	if get_mail_ids().is_empty(): return true
	var ids: Array = _pending_read_ids()
	for id: String in get_mail_ids():
		var raw_id: String = id.trim_prefix("server:")
		if raw_id not in ids and ids.size() < 2000: ids.append(raw_id)
		_update_cache(id,"read",false)
	_set_pending_read_ids(ids)
	_persist_cache()
	_emit_changed()
	return _enqueue("read_all","",{})

func can_delete_mail(id: String) -> bool:
	var mail: Dictionary = get_mail(id)
	return not mail.is_empty() and not is_delivery_busy_for(id) and not bool(mail.get("pending",false)) and not bool(mail.get("blocked_on_other_device",false)) and ((mail.get("reward", {}) as Dictionary).is_empty() or bool(mail.get("claimed",false)) or bool(mail.get("expired",false)) or bool(mail.get("cancelled",false)))

func delete_mail(id: String) -> bool:
	return _enqueue("delete",id,{"mail_id":id.trim_prefix("server:")}) if can_delete_mail(id) else false

func is_deleting_all_completed() -> bool:
	if _busy and str(_pending.get("kind","")) == "delete_all": return true
	for item: Dictionary in _queue:
		if str(item.get("kind","")) == "delete_all": return true
	return false

func delete_all_completed() -> bool:
	return _enqueue("delete_all","",{})

func _enqueue(kind: String,id: String,payload: Dictionary,cursor: String = "") -> bool:
	if _owner.is_empty() or _state.is_empty() or _auth_node == null or _queue.size() >= 64: return false
	var key: String = kind+":"+id+":"+cursor
	if _busy and str(_pending.get("key","")) == key: return true
	for item: Dictionary in _queue:
		if str(item.get("key","")) == key: return true
	if kind in ["claim","delete","delete_all"] and _busy and str(_pending.get("kind",""))=="list" and Time.get_ticks_msec()-_operation_started_at>=1500:
		var interrupted: Dictionary=_pending.duplicate(true)
		_http.cancel_request();_nonce+=1;_waiting_token=false;_busy=false;_pending={}
		_queue.push_front(interrupted)
	_queue.append({"kind":kind,"id":id,"payload":payload,"cursor":cursor,"key":key,"owner":_owner,"refreshed_token":false})
	if kind == "read_all": _queue[-1].read_ids = _pending_read_ids()
	call_deferred("_start_next")
	_emit_changed()
	return true

func _start_next() -> void:
	if _busy or _queue.is_empty(): return
	if _owner != _current_owner(): _on_profile(PlayerIdentityManager.get_profile_snapshot()); return
	# User mutations and durable acknowledgements must not wait behind background
	# pagination or cosmetic read receipts. Preserve FIFO within each priority.
	var best: int = 0
	for index: int in _queue.size():
		if _request_priority(str(_queue[index].kind)) < _request_priority(str(_queue[best].kind)): best = index
	_pending = _queue[best]
	_queue.remove_at(best)
	if str(_pending.owner) != _owner: call_deferred("_start_next"); return
	var kind: String = str(_pending.kind)
	if kind in ["claim","ack"]:
		var parts: Array[Dictionary] = [_pending.duplicate(true)]
		while parts.size() < 8:
			var next: int = -1
			for index: int in _queue.size():
				if str(_queue[index].kind) == kind and str(_queue[index].owner) == _owner: next = index; break
			if next < 0: break
			parts.append(_queue[next]); _queue.remove_at(next)
		if parts.size() > 1:
			_pending.parts = parts
			_pending.kind = kind + "_batch"
			var entries: Array = []
			for part: Dictionary in parts: entries.append(part.payload)
			_pending.payload = {"entries":entries}
	_busy = true
	_operation_started_at = Time.get_ticks_msec()
	_waiting_token = true
	_nonce += 1
	var nonce: int = _nonce
	_status = "Claiming attachments…" if kind.begins_with("claim") else "Confirming received attachments…" if kind.begins_with("ack") else "Deleting completed mail…" if kind.begins_with("delete") else "Updating inbox in background" if not get_mail_ids().is_empty() else "Connecting mailbox…"
	if not bool(_pending.get("refreshed_token",false)) and not _cached_token.is_empty() and Time.get_ticks_msec() < _cached_token_until:
		_on_token(_cached_token)
	else:
		_auth_node.get_id_token(bool(_pending.get("refreshed_token",false)))
	get_tree().create_timer(10.0).timeout.connect(func():
		if _nonce == nonce and _waiting_token: _fail("Sign-in token timed out"))
	_emit_changed()

func _on_token(token: String) -> void:
	if not _waiting_token or not _busy: return
	if _owner != _current_owner(): _on_profile(PlayerIdentityManager.get_profile_snapshot()); return
	if not preload("res://scripts/managers/trusted_profile_dns.gd").token_owner_matches(token, _owner): return
	_waiting_token = false
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$")
	if token.length() > 8192 or pattern.search(token) == null: _fail("Invalid sign-in token"); return
	_cached_token = token
	_cached_token_until = _token_cache_deadline(token)
	var kind: String = str(_pending.kind)
	var path: String = "/v1/mail/"+kind
	if kind == "list": path += "?installation_id="+str(_state.installation_id)+"&after="+str(_pending.cursor)
	var headers := PackedStringArray(["Content-Type: application/json","Accept: application/json","User-Agent: GodotEngine/4.7.2","Host: "+PlayerIdentityServerClient._endpoint_host(),"X-Jade-Owner-Binding: "+_owner,"X-Jade-Mail-Features: gifts-v2","X-Jade-Odyssey: v1","X-Jade-Announcements: v1","X-Jade-Equipment-Catalog: jade-chain-v1","X-Jade-Returning-Glaive: v1","X-Jade-Ascendant-Arsenal: v1","X-Jade-Client-Version: "+str(preload("res://scripts/debug/build_metadata.gd").read().version_name),"Authorization: Bearer "+token])
	var error: Error = _http.request(PlayerIdentityServerClient._prepare_route(_http,path),headers,HTTPClient.METHOD_GET if kind == "list" else HTTPClient.METHOD_POST,"" if kind == "list" else JSON.stringify(_pending.payload))
	if error != OK: _fail("Server request could not start")

func _token_cache_deadline(token: String) -> int:
	# Decode expiry only to bound an in-memory cache. The server still verifies
	# signature, issuer, audience, ownership and expiry on every operation.
	var part: String = token.get_slice(".", 1).replace("-", "+").replace("_", "/")
	part += "=".repeat((4-part.length()%4)%4)
	var claims: Variant = JSON.parse_string(Marshalls.base64_to_raw(part).get_string_from_utf8())
	var seconds: int = 45
	if claims is Dictionary and typeof(claims.get("exp")) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(claims.exp)):
		seconds = clampi(int(claims.exp) - int(Time.get_unix_time_from_system()) - 90, 0, 3000)
	return Time.get_ticks_msec() + seconds*1000

func _request_priority(kind: String) -> int:
	if kind.begins_with("ack"): return 0
	if kind.begins_with("claim"): return 1
	if kind.begins_with("delete"): return 2
	return 4 if kind == "list" else 3

func _on_response(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if not _busy: return
	if _owner != _current_owner(): _on_profile(PlayerIdentityManager.get_profile_snapshot()); return
	if result != HTTPRequest.RESULT_SUCCESS: _fail("Offline · automatic retry scheduled"); return
	if code == 401:
		_cached_token = ""
		_cached_token_until = 0
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
	if kind not in ["list","read_all","announcement_read","claim_batch","ack_batch","delete_all"] and str(data.get("mail_id","")) != str(_pending.id).trim_prefix("server:"): _fail("Mail response mismatch"); return
	if kind == "announcement_read" and (str(data.get("announcement_id", "")) != str(_pending.id) or data.get("ok") != true): _fail("Announcement response mismatch"); return
	if kind in ["read","read_all","delete","delete_all"] and data.get("ok") != true: _fail("Mail action not confirmed"); return
	if kind in ["claim_batch","ack_batch"]:
		var parts: Array = _pending.get("parts",[])
		if not data.get("entries") is Array or data.entries.size() != parts.size(): _fail("Invalid mail batch response"); return
		for index: int in parts.size():
			var entry: Variant = data.entries[index]
			if not entry is Dictionary or str(entry.get("mail_id","")) != str(parts[index].id).trim_prefix("server:") or not entry.get("success") is bool: _fail("Mail batch identity mismatch"); return
		var original: Dictionary = _pending.duplicate(true)
		for index: int in parts.size():
			var entry: Dictionary = data.entries[index]
			if not bool(entry.success): continue
			_pending.id = parts[index].id
			if kind == "claim_batch":
				if not _apply_delivery(entry,false): _pending = original; _fail("Claim could not be saved · retry after restart"); return
			else: _update_cache(str(parts[index].id),"claimed",false)
		_pending = original
		_persist_cache()
	elif kind == "delete_all":
		for id: String in get_mail_ids():
			if can_delete_mail(id): _update_cache(id,"deleted",false)
		_persist_cache()
	elif kind == "list":
		if not _accept_page(data): _fail("Invalid mail catalog"); return
	elif kind == "claim":
		if not _apply_delivery(data): _fail("Claim could not be saved · retry after restart"); return
	elif kind == "ack":
		_update_cache(str(_pending.id),"claimed")
	elif kind == "delete":
		_update_cache(str(_pending.id),"deleted")
	elif kind == "read":
		var reads: Array = _pending_read_ids()
		reads.erase(str(_pending.id).trim_prefix("server:"))
		_set_pending_read_ids(reads)
		_update_cache(str(_pending.id),"read")
	elif kind == "read_all":
		var reads: Array = _pending_read_ids()
		for id: Variant in _pending.get("read_ids", []): reads.erase(id)
		_set_pending_read_ids(reads)
		_persist_cache()
	_status = "Completed mail cleared" if kind == "delete_all" else "Server mail synced"
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
	_last_success_msec=Time.get_ticks_msec()
	_next_refresh_msec=_last_success_msec+AUTO_SYNC_SECONDS*1000
	_list_failures=0
	_incoming = _incoming.filter(func(mail: Dictionary) -> bool: return not _deleted_during_refresh.has(str(mail.mail_id)))
	_incoming.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.created_at) > int(b.created_at))
	var cache: Dictionary = _state.get("cache",{}).duplicate(true)
	var present: Dictionary = {}
	var server_read: Dictionary = {}
	for mail: Dictionary in _incoming:
		present[str(mail.mail_id)] = true
		if bool(mail.read): server_read[str(mail.mail_id)] = true
	var pending_reads: Array = _pending_read_ids().filter(func(id: Variant) -> bool: return present.has(str(id)) and not server_read.has(str(id)))
	_set_pending_read_ids(pending_reads)
	var locally_read: Dictionary = {}
	for previous: Variant in cache.get(_owner, []):
		if previous is Dictionary and bool(previous.get("read", false)): locally_read[str(previous.get("mail_id", ""))] = true
	for id: Variant in _pending_read_ids(): locally_read[str(id)] = true
	for mail: Dictionary in _incoming:
		if locally_read.has(str(mail.mail_id)): mail.read = true
	cache[_owner] = _incoming.duplicate(true)
	_state.cache = cache
	_persist_cache()
	if data.has("announcements"):
		var notices: Node = get_node_or_null("/root/AnnouncementCenter")
		if notices != null: notices.accept_snapshot(_owner, data.announcements, _server_time)
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

func _apply_delivery(data: Dictionary,persist_cache: bool = true) -> bool:
	var id: String = str(_pending.id).trim_prefix("server:")
	if str(data.get("mail_id","")) != id: return false
	if str(data.get("delivery_state","")) == "claimed":
		_update_cache("server:"+id,"claimed")
		return true
	if str(data.get("delivery_state","")) != "pending" or str(data.get("installation_id","")) != str(_state.installation_id) or not _valid_id(str(data.get("receipt_id",""))) or not data.get("reward") is Dictionary or not _valid_reward(data.reward): return false
	var authority: Node = get_node_or_null("/root/LiveOpsManager")
	if authority == null or not authority.apply_server_mail_reward(_owner,id,data.reward): return false
	_enqueue("ack","server:"+id,{"mail_id":id,"installation_id":_state.installation_id,"receipt_id":data.receipt_id})
	_update_cache("server:"+id,"applied",persist_cache)
	return true

func _update_cache(id: String,action: String,persist: bool = true) -> void:
	var entries: Array = (_state.get("cache",{}) as Dictionary).get(_owner,[]).duplicate(true)
	for i: int in range(entries.size()-1,-1,-1):
		if str(entries[i].get("id","")) != id: continue
		if action == "deleted":
			_deleted_during_refresh[id.trim_prefix("server:")] = true
			var reads: Array = _pending_read_ids()
			reads.erase(id.trim_prefix("server:"))
			_set_pending_read_ids(reads)
			for index: int in range(_queue.size()-1,-1,-1):
				if str(_queue[index].kind) == "read" and str(_queue[index].id) == id: _queue.remove_at(index)
			entries.remove_at(i)
		elif action == "read": entries[i].read = true
		else:
			entries[i].claimed = true
			entries[i].can_claim = false
			entries[i].pending = action == "applied"
			if action == "claimed":
				# The existing server ACK also marks this letter read.
				entries[i].read = true
				var reads: Array = _pending_read_ids()
				reads.erase(id.trim_prefix("server:")); _set_pending_read_ids(reads)
				for index: int in range(_queue.size()-1,-1,-1):
					if str(_queue[index].kind) == "read" and str(_queue[index].id) == id: _queue.remove_at(index)
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
		_list_failures=mini(_list_failures+1,4)
		_next_refresh_msec=Time.get_ticks_msec()+mini(60*(1<<(_list_failures-1)),300)*1000
	_status = message
	_finish()

func _finish() -> void:
	_last_elapsed_ms = maxi(0, Time.get_ticks_msec() - _operation_started_at)
	_last_operation = str(_pending.get("kind", ""))
	_busy = false
	_waiting_token = false
	_pending.clear()
	_emit_changed()
	call_deferred("_start_next")

func _emit_changed() -> void:
	server_mail_changed.emit()
	var authority: Node = get_node_or_null("/root/LiveOpsManager")
	if authority != null: authority.live_ops_changed.emit()

func hint_pending_delivery() -> void:
	# An outbox write can complete after the event response. Respect the existing
	# sync gap, but check soon rather than leaving new rewards until the 3-minute poll.
	var due: int=maxi(Time.get_ticks_msec()+1200,_last_started_msec+MIN_SYNC_GAP_MSEC)
	_next_refresh_msec=mini(_next_refresh_msec,due) if _next_refresh_msec>0 else due
