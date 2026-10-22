extends Node
## Profile-service progress backup; Google-owned, revisioned, opt-in restore.
## Paid wallet/gear continue to come ONLY from the IAP service.
signal changed
const Snapshot = preload("res://scripts/managers/progress_backup_snapshot.gd")
const DNS = preload("res://scripts/managers/trusted_profile_dns.gd")
const PATH: String = "/v1/player/progress-backup"
const LOCAL: String = "user://progress_backup_identity_v1.json"
var status: String = "sign_in_required"
var busy: bool = false
var remote: Dictionary = {}
var revision: int = 0
var updated_at: int = 0
var restore_committed: bool = false
var _auth: Node
var _http: HTTPRequest
var _owner: String = ""
var _local: Dictionary = {}
var _pending: Dictionary = {}
var _waiting: bool = false
var _nonce: int = 0
var _loaded: bool = false
var _next_auto: int = 0
var _refreshed_token: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parser := JSON.new()
	if FileAccess.file_exists(LOCAL):
		var file := FileAccess.open(LOCAL, FileAccess.READ)
		if file != null and file.get_length() <= 2048 and parser.parse(file.get_as_text()) == OK and parser.data is Dictionary: _local = parser.data
	PlayerIdentityManager.profile_changed.connect(_on_profile)
	call_deferred("_setup")
	var timer := Timer.new(); timer.wait_time = 15.0; timer.timeout.connect(_auto); add_child(timer); timer.start()

func _setup() -> void:
	var firebase: Node = get_node_or_null("/root/Firebase")
	if not OS.has_feature("android") or firebase == null: status = "android_required"; changed.emit(); return
	_auth = firebase.auth
	_auth.id_token_result.connect(_token)
	_auth.id_token_error.connect(func(_error: String):
		if _waiting: _fail("token_unavailable"))
	GoogleAccountManager.monetization_identity_changed.connect(func(_ready_identity: bool): _on_profile({}))
	_on_profile({})

func _live() -> String:
	return GoogleAccountManager.get_monetization_account_binding()

func _on_profile(_profile: Dictionary) -> void:
	var account_binding: String = _live()
	if account_binding != _owner:
		_nonce += 1
		if is_instance_valid(_http): _http.cancel_request()
		_owner = account_binding; busy = false; _waiting = false; _pending = {}; remote = {}; revision = 0; updated_at = 0; _loaded = false
		status = "sign_in_required" if account_binding.is_empty() else "checking"
		changed.emit()
	if not account_binding.is_empty() and not _loaded and not busy and _auth != null and PlayerIdentityManager.get_profile_snapshot().get("server_status") == "connected": refresh()

func get_status() -> Dictionary:
	var stage: String = "local_account_mismatch" if not _owner.is_empty() and not busy and str(_local.get("owner", "")) not in ["", _owner] else status
	return {"stage": stage, "owner_hint": GoogleAccountManager.get_known_account_hint(str(_local.get("owner", ""))) if stage=="local_account_mismatch" else "", "busy": busy, "revision": revision, "updated_at": updated_at, "remote_exists": not remote.is_empty(), "auto_enabled": _local.get("owner") == _owner and bool(_local.get("approved", false)), "domain_count": Snapshot.DOMAINS.size()}

func _idle_safe() -> bool:
	if restore_committed or SaveManager.is_progress_read_only() or SaveManager.has_pending_transaction() or SceneTransitionManager.is_transitioning: return false
	if JourneyManager.has_active_run() or SaveManager.has_save_file("checkpoint") or not EquipmentManager.active_run_loadout_snapshot.is_empty() or get_tree().get_first_node_in_group("player") != null: return false
	var paid: Node = PavilionManager.get("paid_gameplay") as Node
	return paid == null or (not bool(paid.get("busy")) and (paid.call("_read_pending") as Dictionary).is_empty())

func can_backup() -> bool:
	return _loaded and not busy and not _owner.is_empty() and _owner == _live() and str(_local.get("owner", "")) in ["", _owner] and _idle_safe() and (updated_at == 0 or int(Time.get_unix_time_from_system()) - updated_at >= 60)

func can_restore() -> bool:
	return _loaded and not busy and not remote.is_empty() and not _owner.is_empty() and _owner == _live() and _idle_safe()

func refresh() -> bool:
	if busy or _owner.is_empty() or _auth == null or restore_committed: return false
	_pending = {"kind": "read", "owner": _owner}
	return _start()

func backup_now() -> bool:
	if not can_backup(): return false
	var snapshot: Dictionary = Snapshot.capture()
	if snapshot.is_empty(): _fail("local_save_unavailable"); return false
	_pending = {"kind": "write", "owner": _owner, "body": {"expected_revision": revision, "request_id": Crypto.new().generate_random_bytes(16).hex_encode(), "snapshot": snapshot}}
	return _start()

func _start() -> bool:
	if _pending.owner != _live(): _fail("account_changed"); return false
	busy = true; _waiting = true; _refreshed_token = false; status = "syncing"; _nonce += 1
	var nonce: int = _nonce
	_auth.get_id_token(false)
	get_tree().create_timer(12.0).timeout.connect(func():
		if nonce == _nonce and _waiting: _fail("token_timeout"))
	changed.emit()
	return true

func _token(token: String) -> void:
	if not busy or not _waiting: return
	if _owner != _live(): _fail("account_changed"); return
	if token.length() > 8192 or not DNS.token_owner_matches(token, _owner): return
	_waiting = false
	if is_instance_valid(_http): _http.cancel_request(); _http.queue_free()
	_http = HTTPRequest.new(); _http.use_threads = true; _http.timeout = 30.0; _http.body_size_limit = Snapshot.MAX_BYTES + 4096; _http.max_redirects = 0
	add_child(_http); _http.request_completed.connect(_response.bind(_nonce, _owner))
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json", "Host: " + PlayerIdentityServerClient._endpoint_host(), "Authorization: Bearer " + token])
	var write: bool = _pending.kind == "write"
	var error: Error = _http.request(PlayerIdentityServerClient._prepare_route(_http, PATH), headers, HTTPClient.METHOD_POST if write else HTTPClient.METHOD_GET, JSON.stringify(_pending.body) if write else "")
	if error != OK: _fail("network_unavailable")

func _response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, nonce: int, account_binding: String) -> void:
	if nonce != _nonce or not busy: return
	if account_binding != _owner or account_binding != _live(): _fail("account_changed"); return
	if result != HTTPRequest.RESULT_SUCCESS: _fail("network_unavailable"); return
	if code == 401 and not _refreshed_token:
		_refreshed_token = true; _waiting = true; _auth.get_id_token(true)
		get_tree().create_timer(12.0).timeout.connect(func():
			if nonce == _nonce and _waiting: _fail("token_timeout"))
		return
	if code != 200:
		if code == 409: _local.approved = false; _save_local(); _loaded = false
		_fail("backup_conflict" if code == 409 else "backup_cooldown" if code == 429 else "backup_service_unavailable" if code == 503 else "backup_http_" + str(code)); return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary: _fail("invalid_response"); return
	var data: Dictionary = Snapshot.integer_tree(parser.data)
	if data.get("version") != 1 or data.get("owner_binding") != account_binding: _fail("invalid_response"); return
	if _pending.kind == "read":
		var value: Variant = data.get("backup")
		if value == null:
			remote = {}; revision = 0; updated_at = 0
		elif value is Dictionary and value.get("revision") is int and value.revision >= 1 and value.get("updated_at") is int and Snapshot.valid(value.get("snapshot")):
			remote = value.snapshot.duplicate(true); revision = value.revision; updated_at = value.updated_at
		else: _fail("incompatible_backup"); return
		_loaded = true
		if _local.get("owner") == account_binding and int(_local.get("revision", -1)) != revision: _local.approved = false; _save_local()
		status = "backup_available" if not remote.is_empty() else "no_backup"
	else:
		if data.get("revision") != int(_pending.body.expected_revision) + 1 or not data.get("updated_at") is int: _fail("invalid_response"); return
		remote = _pending.body.snapshot.duplicate(true); revision = data.revision; updated_at = data.updated_at
		_local = {"owner": account_binding, "revision": revision, "approved": true}; _save_local(); _loaded = true; status = "backed_up"
	busy = false; _pending = {}; _waiting = false; _next_auto = Time.get_ticks_msec() + 300000; changed.emit()

func _save_local() -> void:
	var file := FileAccess.open(LOCAL + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(_local)); file.flush(); var error: Error = file.get_error(); file.close()
	if error == OK: DirAccess.rename_absolute(LOCAL + ".tmp", LOCAL)

func _auto() -> void:
	if busy or not _loaded or _owner.is_empty() or _owner != _live() or _local.get("owner") != _owner or not bool(_local.get("approved", false)) or Time.get_ticks_msec() < _next_auto: return
	_next_auto = Time.get_ticks_msec() + 300000
	if can_backup(): backup_now()

func _fail(reason: String) -> void:
	_nonce += 1
	if is_instance_valid(_http): _http.cancel_request()
	if reason == "account_changed": _owner = _live(); remote = {}; revision = 0; updated_at = 0; _loaded = false
	busy = false; _waiting = false; _pending = {}; status = reason; _next_auto = Time.get_ticks_msec() + 300000; changed.emit()

func restore_and_close() -> bool:
	if not can_restore() or _owner != _live() or not Snapshot.valid(remote): return false
	var current: Dictionary = Snapshot.capture()
	if current.is_empty(): _fail("local_save_unavailable"); return false
	var dir: String = "user://progress_restore_backups"
	if DirAccess.make_dir_recursive_absolute(dir) != OK: _fail("backup_storage_unavailable"); return false
	var path: String = dir + "/" + Crypto.new().generate_random_bytes(16).hex_encode() + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: _fail("backup_storage_unavailable"); return false
	var before: String = JSON.stringify({"local_owner_binding": str(_local.get("owner", "unassigned")), "restore_owner_binding": _owner, "snapshot": current})
	file.store_string(before); file.flush(); var error: Error = file.get_error(); file.close()
	if error != OK or FileAccess.get_sha256(path) != before.sha256_text(): _fail("backup_storage_unavailable"); return false
	var entries: Array[Dictionary] = []
	for backup_filename: String in DirAccess.get_files_at(dir):
		if backup_filename.ends_with(".json") and backup_filename.trim_suffix(".json").length() == 32 and backup_filename.trim_suffix(".json").is_valid_hex_number(false): entries.append({"path": dir + "/" + backup_filename, "time": FileAccess.get_modified_time(dir + "/" + backup_filename)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.time) > int(b.time))
	for index: int in range(3, entries.size()):
		if str(entries[index].path) != path: DirAccess.remove_absolute(str(entries[index].path))
	# One durable journal replays exact target values after interruption, never additive grants.
	if not SaveManager.write_save_batch(remote.domains):
		_fail("restore_recovery_required")
		if SaveManager.has_pending_transaction(): restore_committed = true; get_tree().quit.call_deferred()
		return false
	restore_committed = true
	_local = {"owner": _owner, "revision": revision, "approved": true}; _save_local()
	var barrier: Dictionary = SaveManager.begin_save_write_barrier("progress_restore", "restart_after_restore")
	if not bool(barrier.get("success", false)): status = "restart_required"
	else: status = "restored_restart_required"
	changed.emit()
	get_tree().quit.call_deferred()
	return true
