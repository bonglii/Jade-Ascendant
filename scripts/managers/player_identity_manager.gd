extends Node

## Public, device-local player identity. Never an authentication credential or
## reward authority. Google sign-in does not switch local gameplay/profile saves.
## The local-profile scope deliberately stays outside the locked cloud contract.
signal profile_changed(snapshot: Dictionary)

const DOMAIN: String = "player_profile"
const VERSION: int = 1
const MIN_NAME_LENGTH: int = 3
const MAX_NAME_LENGTH: int = 20
const UID_ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
var _state: Dictionary = {}
var _pending_identity: Dictionary = {}
var _status: String = "unavailable"
var _writing: bool = false
var _active_server_owner: String = ""
var _server_status: String = "pending"

func _ready() -> void:
	refresh_profile()

func get_profile_snapshot() -> Dictionary:
	var bindings: Dictionary = _state.get("server_bindings",{})
	var server_uid: String = str(bindings.get(_active_server_owner,""))
	return {
		"ready": not _state.is_empty(), "player_uid": server_uid if not server_uid.is_empty() else str(_state.get("player_uid", "")).replace("-",""),
		"display_name": str(_state.get("display_name", "")), "status": _status,
		"scope": "server" if not server_uid.is_empty() else "local_profile", "server_registered": not server_uid.is_empty(), "server_status": _server_status
	}

func set_server_context(owner_binding: String, status: String) -> void:
	_active_server_owner = owner_binding if owner_binding.length() == 64 and owner_binding.is_valid_hex_number(false) else ""
	_server_status = status
	profile_changed.emit(get_profile_snapshot())

func accept_server_identity(expected_owner: String, response: Dictionary) -> bool:
	if _writing or _state.is_empty() or expected_owner != _active_server_owner or expected_owner.is_empty(): return false
	# HTTP JSON numbers parse as floats in Godot; disk schema stays integer.
	if typeof(response.get("version")) not in [TYPE_INT,TYPE_FLOAT] or float(response.version) != 1.0 or str(response.get("owner_binding","")) != expected_owner: return false
	var uid: String = str(response.get("public_uid",""))
	if not _valid_server_uid(uid): return false
	var bindings: Dictionary = _state.get("server_bindings",{}).duplicate(true)
	if bindings.has(expected_owner): return str(bindings[expected_owner]) == uid
	if bindings.size() >= 32: return false
	bindings[expected_owner] = uid
	var candidate: Dictionary = _state.duplicate(true)
	candidate.server_bindings = bindings
	_writing = true
	var result: Dictionary = SaveManager.write_save_data(DOMAIN,candidate)
	if bool(result.get("success",false)):
		_state = candidate
		profile_changed.emit(get_profile_snapshot())
	_writing = false
	return bool(result.get("success",false))

func _valid_server_uid(uid: String) -> bool:
	if uid.length() != 12 or not uid.begins_with("JA"): return false
	for character: String in uid.substr(2):
		if not UID_ALPHABET.contains(character): return false
	return true

func refresh_profile() -> void:
	if _writing: return
	_writing = true
	_state = {}
	var result: Dictionary = SaveManager.read_save_data(DOMAIN)
	var payload: Variant = result.get("data", {})
	if bool(result.get("success", false)) and _valid_payload(payload):
		_state = payload.duplicate(true)
		_status = "ready"
	else:
		var backup_exists: bool = FileAccess.file_exists(SaveManager.get_save_backup_path(DOMAIN))
		var interrupted_write: bool = FileAccess.file_exists(SaveManager.get_save_path(DOMAIN)+".tmp") or FileAccess.file_exists(SaveManager.get_save_path(DOMAIN)+".rollback")
		var future_schema: bool = str(result.get("integrity_issue", "")) == "unsupported_schema"
		if not future_schema and backup_exists:
			var backup: Dictionary = SaveManager.read_save_backup(DOMAIN)
			if bool(backup.get("success", false)) and _valid_payload(backup.get("data", {})):
				var recovered: Dictionary = SaveManager.recover_save_from_backup(DOMAIN)
				if bool(recovered.get("success", false)):
					_state = backup.data.duplicate(true)
					_status = "recovered"
		if _state.is_empty():
			if bool(result.get("exists", false)) or backup_exists or interrupted_write:
				# Corruption/future versions must not silently mint a replacement UID.
				_status = "recovery_required"
			else:
				if _pending_identity.is_empty(): _pending_identity = _new_identity()
				if not _pending_identity.is_empty() and bool(SaveManager.write_save_data(DOMAIN, _pending_identity).get("success", false)):
					_state = _pending_identity.duplicate(true)
					_pending_identity = {}
					_status = "ready"
				else:
					_status = "save_failed"
	if not _state.is_empty() and _is_legacy_uid(str(_state.player_uid)):
		var compact: Dictionary = _state.duplicate(true)
		compact.legacy_player_uid = _state.player_uid
		compact.player_uid = _compact_uid(str(_state.player_uid))
		if bool(SaveManager.write_save_data(DOMAIN,compact).get("success",false)):
			_state = compact
		else:
			# Expose the old persisted UID until migration can commit safely.
			_status = "migration_pending"
	profile_changed.emit(get_profile_snapshot())
	_writing = false

func validate_name(raw_name: String) -> Dictionary:
	# Reject invisible/control characters before trimming; no hidden bidi aliases.
	for i: int in range(raw_name.length()):
		var code: int = raw_name.unicode_at(i)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x061c,0x200b,0x200c,0x200d,0x200e,0x200f,0xfeff] or (code >= 0x202a and code <= 0x202e) or (code >= 0x2060 and code <= 0x206f):
			return {"valid": false, "code": "characters", "name": ""}
	var normalized_name: String = raw_name.strip_edges()
	while normalized_name.contains("  "): normalized_name = normalized_name.replace("  ", " ")
	if normalized_name.length() < MIN_NAME_LENGTH or normalized_name.length() > MAX_NAME_LENGTH:
		return {"valid": false, "code": "length", "name": normalized_name}
	var pattern := RegEx.new()
	pattern.compile("^[\\p{L}\\p{N}][\\p{L}\\p{M}\\p{N} ._'’-]*$")
	if pattern.search(normalized_name) == null:
		return {"valid": false, "code": "characters", "name": normalized_name}
	return {"valid": true, "code": "valid", "name": normalized_name}

func rename_player(raw_name: String) -> Dictionary:
	if _writing: return {"success": false, "code": "busy"}
	if _state.is_empty(): return {"success": false, "code": "unavailable"}
	var validation: Dictionary = validate_name(raw_name)
	if not bool(validation.valid): return {"success": false, "code": validation.code}
	if str(validation.name) == str(_state.display_name): return {"success": true, "code": "unchanged"}
	_writing = true
	var candidate: Dictionary = _state.duplicate(true)
	candidate.display_name = validation.name
	var result: Dictionary = SaveManager.write_save_data(DOMAIN, candidate)
	if not bool(result.get("success", false)):
		_writing = false
		return {"success": false, "code": "save_failed"}
	_state = candidate
	profile_changed.emit(get_profile_snapshot())
	_writing = false
	return {"success": true, "code": "saved"}

func _new_identity() -> Dictionary:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16: return {}
	var hex: String = bytes.hex_encode().to_upper()
	var legacy_uid: String = "JA-%s-%s-%s-%s" % [hex.substr(0,8),hex.substr(8,8),hex.substr(16,8),hex.substr(24,8)]
	return {"version": VERSION, "player_uid": _compact_uid(legacy_uid), "legacy_player_uid": legacy_uid, "display_name": "Cultivator " + hex.right(4)}

func _is_legacy_uid(uid: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^JA-[0-9A-F]{8}-[0-9A-F]{8}-[0-9A-F]{8}-[0-9A-F]{8}$")
	return pattern.search(uid) != null

func _compact_uid(legacy_uid: String) -> String:
	if not _is_legacy_uid(legacy_uid): return ""
	var hex: String = legacy_uid.substr(3).replace("-","")
	var encoded: String = ""
	var buffer: int = 0
	var bits: int = 0
	# Encode the first 80 random bits as 16 unambiguous base-32 characters.
	for i: int in range(10):
		buffer = (buffer << 8) | hex.substr(i*2,2).hex_to_int()
		bits += 8
		while bits >= 5:
			bits -= 5
			encoded += UID_ALPHABET[(buffer >> bits) & 31]
		buffer &= (1 << bits)-1
	return "JA-%s-%s-%s-%s" % [encoded.substr(0,4),encoded.substr(4,4),encoded.substr(8,4),encoded.substr(12,4)]

func _valid_payload(payload: Variant) -> bool:
	if not payload is Dictionary: return false
	if typeof(payload.get("version")) != TYPE_INT or payload.version != VERSION: return false
	if not payload.get("player_uid") is String or not payload.get("display_name") is String: return false
	if not _is_legacy_uid(str(payload.player_uid)):
		if not payload.get("legacy_player_uid") is String: return false
		var expected: String = _compact_uid(str(payload.legacy_player_uid))
		if expected.is_empty() or expected != str(payload.player_uid): return false
	if payload.has("server_bindings"):
		if not payload.server_bindings is Dictionary or payload.server_bindings.size() > 32: return false
		for binding_key: Variant in payload.server_bindings:
			if not binding_key is String or binding_key.length() != 64 or not binding_key.is_valid_hex_number(false): return false
			if not payload.server_bindings[binding_key] is String or not _valid_server_uid(str(payload.server_bindings[binding_key])): return false
	var valid: Dictionary = validate_name(payload.display_name)
	return bool(valid.valid) and str(valid.name) == str(payload.display_name)
