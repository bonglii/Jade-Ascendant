extends Node
## Authenticated server overlay. Ownership/balances never enter offline saves.
signal changed
signal finished(result: Dictionary)
const HASH: String = "16cfc8c6171f52bb60dfc76eb756769f6e13ce7122d87bec531bb46d75c8565a"
const Catalog = preload("res://scripts/data/equipment_catalog.gd")
const SLOTS: Array[String] = ["armament", "robe", "bracer", "boots", "pendant"]
const SINGLETON: String = "JadeMonetizationNativeBridge"
const SNAPSHOT_FIELDS: Array[String] = [
	"paid_gameplay_version", "account_binding", "catalog_hash", "state", "revision",
	"wallet", "inventory", "stars", "slots", "pity", "wish", "wish_guaranteed",
	"lifetime_pulls", "rates", "lease_seconds"
]
var snapshot: Dictionary = {}
var status: String = "not_connected"
var last_transport_stage: String = "not_started"
var busy: bool = false
var _request_id: String = ""
var _owner: String = ""
var _binding: String = ""
var _command: Dictionary = {}
var _deadline: int = 0
var _expires: int = 0
var _next_read: int = 0
var _clock: float = 0.0
var _run_started: bool = false
var _run_slots: Dictionary = {}
var _run_stars: Dictionary = {}
var _run_ref: Dictionary = {}
var _run_weapon_level: int = 0
var _run_prepared: bool = false
var _run_entered: bool = false
var _preparing_run: bool = false
var _last_result: Dictionary = {}

func _service(name_id: String) -> Node:
	return get_tree().root.get_node_or_null(NodePath(name_id)) if is_inside_tree() else null
func _live_binding() -> String:
	var account: Node = _service("GoogleAccountManager")
	return str(account.call("get_monetization_account_binding")) if account != null else ""
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
func _ready() -> void:
	call_deferred("_setup")
func _setup() -> void:
	var account: Node = _service("GoogleAccountManager")
	if account != null and not account.is_connected("monetization_identity_changed", _identity_changed):
		account.connect("monetization_identity_changed", _identity_changed)
	_identity_changed(false)
func _identity_changed(_ready_identity: bool) -> void:
	var live: String = _live_binding()
	if live != _binding:
		_binding = live
		_request_id = ""
		_command = {}
		busy = false
		_run_slots = {}; _run_stars = {}; _run_started = get_tree().get_first_node_in_group("player") != null
		if not _run_started: _reset_run()
		_last_result = {}
		last_transport_stage = "not_started"
		_invalidate("account_changed")
		finished.emit({"success": false, "error": "Account changed."})
	_next_read = 0
	call_deferred("refresh")
func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.5: return
	_clock = 0.0
	var now: int = Time.get_ticks_msec()
	var running: bool = get_tree().get_first_node_in_group("player") != null
	if running: _run_entered = true
	if running and not _run_started:
		_run_started = true
		_run_slots = snapshot.get("slots", {}).duplicate(true) if _fresh() else {}
		_run_stars = snapshot.get("stars", {}).duplicate(true) if _fresh() else {}
	elif not running and _run_entered and not _preparing_run:
		_reset_run()
	if busy and now >= _deadline:
		busy = false; _request_id = ""; _command = {}
		last_transport_stage = "REQUEST_TIMEOUT"
		_invalidate("request_timeout")
		finished.emit({"success": false, "error": "Connection interrupted. Recover the same request."})
	if not snapshot.is_empty() and now >= _expires: _invalidate("connection_required")
	if not busy and not _preparing_run and now >= _next_read:
		_next_read = now + 15000
		refresh()
func _invalidate(reason: String) -> void:
	snapshot = {}; _expires = 0; status = reason
	changed.emit()
func _fresh() -> bool:
	return not snapshot.is_empty() and _binding == _live_binding() and Time.get_ticks_msec() < _expires
func is_verified_ready() -> bool:
	return _fresh() and snapshot.get("state", "") == "ready"
func paid_balance() -> int:
	return int(snapshot.get("wallet", {}).get("balance", 0)) if _fresh() else 0
func checkout_ready() -> bool:
	return _fresh() and snapshot.get("state", "") in ["ready", "unfunded"] and not busy and _read_pending().is_empty()
func item_count(item_id: String) -> int:
	return int(snapshot.get("inventory", {}).get(item_id, 0)) if is_verified_ready() else 0
func selected_slot(slot: String, runtime: bool = false) -> String:
	if not is_verified_ready(): return ""
	if runtime and not _run_started and get_tree().get_first_node_in_group("player") != null:
		_run_started=true; _run_slots=snapshot.get("slots",{}).duplicate(true); _run_stars=snapshot.get("stars",{}).duplicate(true)
	var id: String = str((_run_slots if runtime and _run_started else snapshot.get("slots", {})).get(slot, ""))
	return id if item_count(id) > 0 else ""
func item_star(item_id: String, runtime: bool = false) -> int:
	if item_count(item_id) <= 0: return 0
	var star: int = int(snapshot.stars.get(item_id, 1))
	return mini(star, int(_run_stars.get(item_id, 1))) if runtime and _run_started else star
func can_summon(count: int) -> bool:
	return count in [1, 10] and is_verified_ready() and not busy and _read_pending().is_empty() and paid_balance() >= (100 if count == 1 else 900)
static func local_catalog_hash() -> String:
	var ids: Array = Catalog.ITEMS.keys(); ids.sort()
	var items: Array = []
	for id: String in ids:
		var item: Dictionary = Catalog.ITEMS[id]
		if not bool(item.get("retired", false)) and not bool(item.get("event_only", false)):
			items.append({"id": id, "rarity": item.rarity, "slot": item.slot})
	return JSON.stringify(items).sha256_text()
func _bridge() -> Object:
	if local_catalog_hash() != HASH or not Engine.has_singleton(SINGLETON): return null
	var native: Object = Engine.get_singleton(SINGLETON)
	for method: String in ["isPaidGameplayV2Configured", "requestPaidGameplayV2", "getPaidRunContractVersionV2"]:
		if not native.call("has_java_method", method): return null
	if int(native.call("getPaidRunContractVersionV2"))!=1: return null
	if not bool(native.call("isPaidGameplayV2Configured")) or not native.has_signal("paidGameplayResultV2"): return null
	if not native.is_connected("paidGameplayResultV2", _on_result): native.connect("paidGameplayResultV2", _on_result)
	return native
static func _hex(value: String) -> bool:
	var re := RegEx.new(); re.compile("^[a-f0-9]{64}$")
	return re.search(value) != null
static func _uuid(value: String) -> bool:
	var re := RegEx.new(); re.compile("^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$")
	return re.search(value) != null
func _new_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16: return ""
	bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128
	var h: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0,8), h.substr(8,4), h.substr(12,4), h.substr(16,4), h.substr(20,12)]
static func valid_command(cmd: Dictionary) -> bool:
	var kind: String=str(cmd.get("kind",""))
	var fields: Dictionary={"initialize":[],"summon":["pull_count"],"equip":["slot","item_id"],"refine":["item_id"],"wish":["item_id"],"run_start":["run_id","weapon_level"],"run_resume":["run_id"]}
	if not fields.has(kind) or cmd.size()!=3+fields[kind].size() or not _uuid(str(cmd.get("request_id",""))) or not _whole(cmd.get("expected_revision"),0,9007199254740989): return false
	for field: String in fields[kind]:
		if not cmd.has(field): return false
	if cmd.has("run_id") and (not cmd.run_id is String or not _uuid(cmd.run_id)): return false
	if kind=="run_start" and not _whole(cmd.get("weapon_level"),0,50): return false
	if kind=="initialize" and int(cmd.expected_revision)!=0: return false
	if kind=="summon" and (not _whole(cmd.get("pull_count"),1,10) or int(cmd.pull_count) not in [1,10]): return false
	if cmd.has("item_id"):
		if not cmd.item_id is String: return false
		var id: String=cmd.item_id
		if id!="" and (not Catalog.ITEMS.has(id) or bool(Catalog.ITEMS[id].get("retired",false))): return false
		if kind=="refine" and id=="": return false
		if kind=="wish" and id!="" and str(Catalog.ITEMS[id].rarity)!="legendary": return false
		if kind=="equip" and (cmd.get("slot") not in SLOTS or (id!="" and str(Catalog.ITEMS[id].slot)!=cmd.slot)): return false
	return true
static func canonical_command(cmd: Dictionary) -> Dictionary:
	if not valid_command(cmd): return {}
	var canonical: Dictionary = cmd.duplicate(true)
	canonical.expected_revision = int(canonical.expected_revision)
	for field: String in ["pull_count", "weapon_level"]:
		if canonical.has(field): canonical[field] = int(canonical[field])
	return canonical
func _journal_path() -> String:
	return "user://jade_paid_commands_v2_" + _binding + ".json" if _hex(_binding) else ""
func _read_pending() -> Dictionary:
	var path: String = _journal_path()
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2048: return {"error": "invalid_journal"}
	var value: Variant = _parse_json(file.get_as_text())
	if not value is Dictionary or value.size() != 3 or value.get("version") != 2 or value.get("binding") != _binding or not value.get("command") is Dictionary: return {"error": "invalid_journal"}
	var cmd: Dictionary = value.command
	if not valid_command(cmd) or JSON.stringify(cmd).length() > 1024: return {"error": "invalid_journal"}
	return canonical_command(cmd)
func _persist(cmd: Dictionary) -> bool:
	var path: String = _journal_path()
	if path.is_empty() or not valid_command(cmd) or not _read_pending().is_empty(): return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": 2, "binding": _binding, "command": canonical_command(cmd)})); file.flush()
	var error: Error = file.get_error(); file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK
func refresh() -> bool:
	if busy: return false
	var live: String = _live_binding()
	if live != _binding: _identity_changed(false); return false
	if not _hex(live): return false
	var pending: Dictionary = _read_pending()
	if pending.has("error"): _invalidate("recovery_required"); return false
	return _dispatch(pending)
func submit(kind: String, extra: Dictionary = {}) -> bool:
	if busy or not _read_pending().is_empty() or _binding != _live_binding(): return false
	if kind != "initialize" and not is_verified_ready(): return false
	if get_tree().get_first_node_in_group("player") != null and kind not in ["run_start", "run_resume"]: return false
	var saves: Node = _service("SaveManager")
	if saves == null or bool(saves.call("is_progress_read_only")) or bool(saves.call("has_pending_transaction")): return false
	if kind == "summon":
		var pavilion: Node = _service("PavilionManager")
		if pavilion == null or not bool(pavilion.call("is_summon_unlocked")) or not can_summon(int(extra.get("pull_count", 0))): return false
	if kind not in ["initialize", "summon", "equip", "refine", "wish", "run_start", "run_resume"]: return false
	if _bridge() == null: return false
	var cmd: Dictionary = {"request_id": _new_id(), "expected_revision": int(snapshot.get("revision", 0)), "kind": kind}
	for key: String in extra:
		if key in cmd: return false
		cmd[key] = extra[key]
	if not valid_command(cmd) or JSON.stringify(cmd).length() > 1024 or not _persist(cmd): return false
	return _dispatch(cmd)
func _dispatch(cmd: Dictionary) -> bool:
	var native: Object = _bridge()
	if native == null: _invalidate("transport_unavailable"); return false
	_owner = _binding; _command = canonical_command(cmd) if not cmd.is_empty() else {}
	_request_id = str(cmd.get("request_id", _new_id()))
	_last_result = {}
	busy = true; _deadline = Time.get_ticks_msec() + 48000; status = "loading"
	last_transport_stage = "request_in_flight"
	changed.emit()
	native.call("requestPaidGameplayV2", _request_id, "" if _command.is_empty() else JSON.stringify(_command))
	return true
static func _parse_json(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null
static func _whole(value: Variant, low: int = 0, high: int = 1000000000) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
static func valid_snapshot(value: Dictionary, binding: String) -> bool:
	for field: String in SNAPSHOT_FIELDS:
		if not value.has(field): return false
	if value.size() != SNAPSHOT_FIELDS.size() or value.get("paid_gameplay_version") != 2 or value.get("account_binding") != binding or value.get("catalog_hash") != HASH: return false
	if value.get("state") not in ["ready", "unfunded", "initialize_required"] or not _whole(value.get("revision"), 0, 9007199254740990) or value.get("lease_seconds") != 120: return false
	for field: String in ["wallet", "inventory", "stars", "slots", "pity", "rates"]:
		if not value.get(field) is Dictionary: return false
	if value.wallet.size() != 2 or not _whole(value.wallet.get("balance"),0,9007199254740991) or not _whole(value.wallet.get("revision"),0,9007199254740991): return false
	if value.inventory.size() > 56 or value.inventory.size() != value.stars.size(): return false
	for id: String in value.inventory:
		if not Catalog.ITEMS.has(id) or bool(Catalog.ITEMS[id].get("retired", false)) or not _whole(value.inventory[id], 1) or not _whole(value.stars.get(id),1,5): return false
	if value.slots.size() != 5: return false
	for slot: String in SLOTS:
		var id: Variant = value.slots.get(slot)
		if not id is String: return false
		if id != "" and (not value.inventory.has(id) or str(Catalog.ITEMS[id].slot) != slot): return false
	if value.pity.size() != 3 or not _whole(value.pity.get("rare_plus"),0,9) or not _whole(value.pity.get("epic_plus"),0,29) or not _whole(value.pity.get("legendary"),0,49): return false
	if value.rates.size() != 4: return false
	var rates: Dictionary = {"common": 6000, "rare": 2900, "epic": 900, "legendary": 200}
	for key: String in rates:
		if not _whole(value.rates.get(key), rates[key], rates[key]): return false
	if not value.get("wish") is String or not value.get("wish_guaranteed") is bool or not _whole(value.get("lifetime_pulls")): return false
	var wish: String = value.wish
	if not wish.is_empty() and (not Catalog.ITEMS.has(wish) or str(Catalog.ITEMS[wish].rarity) != "legendary" or bool(Catalog.ITEMS[wish].get("retired",false))): return false
	if bool(value.wish_guaranteed) and wish.is_empty(): return false
	if value.state != "ready" and (not value.inventory.is_empty() or int(value.revision) != 0): return false
	return true
func _on_result(request_id: String, success: bool, result_status: String, payload: String) -> void:
	if not busy or request_id != _request_id: return
	var cmd: Dictionary = _command.duplicate(true)
	busy = false; _request_id = ""; _command = {}
	var result: Dictionary = {"success": false, "error": "Verification unavailable. Retry recovery."}
	if _owner != _live_binding() or _owner != _binding:
		_invalidate("account_changed"); finished.emit(result); return
	# Preserve the native error category; never expose tokens or server payloads.
	var safe_stages: Array[String] = ["ACCOUNT_HELD", "BACKEND_NOT_READY", "UNAUTHENTICATED", "FORBIDDEN", "NETWORK_UNAVAILABLE", "REQUEST_TIMEOUT", "BUSY", "APP_CHECK_UNAVAILABLE", "APP_CHECK_NOT_READY", "AUTH_REQUIRED", "AUTH_UNAVAILABLE", "ACCOUNT_CHANGED", "REVISION_OR_OWNERSHIP_CONFLICT", "RATE_LIMITED", "HTTP_UNAVAILABLE", "INVALID_CONTRACT", "INVALID_RESPONSE", "PAID_GAMEPLAY_LOCKED"]
	last_transport_stage = result_status if result_status in safe_stages or result_status == "PAID_GAMEPLAY_VERIFIED" else "UNRECOGNIZED_RESPONSE"
	if not success:
		_next_read = Time.get_ticks_msec() + (60000 if result_status == "ACCOUNT_HELD" else 15000)
		_invalidate("account_held" if result_status == "ACCOUNT_HELD" else "verification_unavailable")
		result.error = "A refunded purchase requires account review." if result_status == "ACCOUNT_HELD" else "Wallet verification failed. Retry connection."
		finished.emit(result); return
	var parsed: Variant = _parse_json(payload) if result_status == "PAID_GAMEPLAY_VERIFIED" and payload.length() <= 32768 else null
	if not parsed is Dictionary or parsed.size() != 2 or not parsed.get("snapshot") is Dictionary or not valid_snapshot(parsed.snapshot, _binding):
		_invalidate("verification_unavailable"); finished.emit(result); return
	var next: Dictionary = parsed.snapshot
	if _fresh() and (int(next.revision) < int(snapshot.revision) or int(next.wallet.revision) < int(snapshot.wallet.revision)):
		_invalidate("stale_response"); finished.emit(result); return
	var op: Variant = parsed.get("operation")
	if cmd.is_empty():
		if op != null: _invalidate("invalid_response"); finished.emit(result); return
	else:
		if not op is Dictionary or op.size() != 3 or op.get("request_id") != cmd.request_id or op.get("kind") not in [cmd.kind, "not_committed"]:
			_invalidate("invalid_receipt"); finished.emit(result); return
		if op.kind in ["run_start", "run_resume"] and not valid_run_outcome(op.get("outcome"), next, str(cmd.run_id)):
			_invalidate("invalid_run_receipt"); finished.emit(result); return
		var pending: Dictionary = _read_pending()
		if pending != cmd or DirAccess.remove_absolute(_journal_path()) != OK:
			_invalidate("journal_unavailable"); finished.emit(result); return
		result = {"success": op.kind != "not_committed", "operation": op, "error": "State changed. No extra payment was taken." if op.kind == "not_committed" else ""}
		if op.kind == "summon" and op.get("outcome") is Dictionary:
			result.merge(op.outcome, true)
			result.merge({"payment_method": "paid_jade", "payment_amount": 100 if int(cmd.pull_count) == 1 else 900, "refinement_shards_gained": 0}, true)
	snapshot = next.duplicate(true); _expires = Time.get_ticks_msec() + 120000
	_next_read = Time.get_ticks_msec() + 60000; status = "verified"
	_last_result = result.duplicate(true)
	changed.emit(); finished.emit(result)
	if next.state == "initialize_required": call_deferred("submit", "initialize")

static func valid_run_ref(value: Variant) -> bool:
	return value is Dictionary and value.size() == 3 and value.get("version") == 1 and value.get("binding") is String and _hex(value.binding) and value.get("run_id") is String and _uuid(value.run_id)
static func valid_run_outcome(value: Variant, state: Dictionary, run_id: String) -> bool:
	if not value is Dictionary or value.size()!=4 or value.get("run_id")!=run_id or not _uuid(run_id): return false
	if not value.get("slots") is Dictionary or value.slots.size()!=5 or not value.get("stars") is Dictionary: return false
	var ids: Array[String]=[]
	for slot: String in SLOTS:
		var id: Variant=value.slots.get(slot)
		if not id is String: return false
		if id!="":
			if not Catalog.ITEMS.has(id) or str(Catalog.ITEMS[id].slot)!=slot or not state.get("inventory",{}).has(id) or not _whole(value.stars.get(id),1,5): return false
			ids.append(id)
	if value.stars.size()!=ids.size(): return false
	var arm: String=value.slots.armament
	return _whole(value.get("weapon_level"),0 if arm=="" else 1,0 if arm=="" else int(value.stars[arm])*10)
func _reset_run() -> void:
	_run_slots={}; _run_stars={}; _run_ref={}; _run_weapon_level=0
	_run_started=false; _run_prepared=false; _run_entered=false
func checkpoint_run_ref() -> Dictionary:
	return _run_ref.duplicate(true)
func can_checkpoint_run() -> bool:
	return _run_slots.is_empty() or _run_slots.values().all(func(id: Variant) -> bool: return id=="") or valid_run_ref(_run_ref)
func runtime_weapon_level(item_id: String) -> int:
	if not _run_prepared or selected_slot("armament",true)!=item_id: return 0
	return clampi(_run_weapon_level,1,item_star(item_id,true)*10)
func _checkpoint_for_gate() -> Dictionary:
	var script: Script=load("res://scripts/managers/checkpoint_manager.gd")
	var result: Dictionary=script.read_checkpoint_result()
	return result.get("data",{}) if bool(result.get("success",false)) else {}
func _await_transport() -> void:
	while busy: await get_tree().process_frame
func _seal_run(ref: Dictionary, frozen: Dictionary) -> void:
	_run_ref=ref.duplicate(true); _run_slots=frozen.get("slots",{}).duplicate(true)
	_run_stars=frozen.get("stars",{}).duplicate(true); _run_weapon_level=int(frozen.get("weapon_level",0))
	_run_prepared=true; _run_started=true; _run_entered=false
func prepare_scene_run(continuing: bool) -> bool:
	if _preparing_run: return false
	_preparing_run=true
	var ok: bool=await _prepare_scene_run(continuing)
	_preparing_run=false
	if not ok: _reset_run()
	return ok
func _prepare_scene_run(continuing: bool) -> bool:
	var saved: Dictionary=_checkpoint_for_gate() if continuing else {}
	if continuing and saved.is_empty(): return false
	var ref: Variant=saved.get("paid_run_ref",{})
	# Legacy/local checkpoints must never acquire the current hub's paid selection.
	if continuing and not saved.has("paid_run_ref"):
		_seal_run({},{}); return true
	if continuing and (not valid_run_ref(ref) or ref.binding!=_live_binding()): return false
	var account_binding: String=_live_binding()
	await _await_transport()
	if account_binding!=_live_binding(): return false
	if not _read_pending().is_empty():
		if not refresh(): return false
		await _await_transport()
		if account_binding!=_live_binding() or not _read_pending().is_empty(): return false
	if not continuing and not is_verified_ready():
		_seal_run({},{}); return true
	if continuing:
		if not refresh(): return false
		await _await_transport()
		if account_binding!=_live_binding() or not is_verified_ready(): return false
	var selected: Dictionary=snapshot.get("slots",{})
	if not continuing and selected.values().all(func(id: Variant) -> bool: return id==""):
		_seal_run({},{}); return true
	var run_id: String=str(ref.run_id) if continuing else _new_id()
	var extra: Dictionary={"run_id":run_id}
	if not continuing:
		var equipment: Node=_service("EquipmentManager")
		var arm: String=str(selected.get("armament",""))
		extra.weapon_level=0 if arm=="" else clampi(int(equipment.get("weapon_levels").get(arm,1)),1,item_star(arm)*10)
	if not submit("run_resume" if continuing else "run_start",extra): return false
	await _await_transport()
	if account_binding!=_live_binding() or not _last_result.get("success",false) or not _fresh(): return false
	var op: Dictionary=_last_result.get("operation",{})
	var frozen: Variant=op.get("outcome")
	if not valid_run_outcome(frozen,snapshot,run_id): return false
	_seal_run({"version":1,"binding":account_binding,"run_id":run_id},frozen)
	return true
