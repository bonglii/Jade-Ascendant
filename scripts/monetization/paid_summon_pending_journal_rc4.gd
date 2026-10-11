extends RefCounted
## Crash-safe request ID journal. Not a Jade, inventory or equipment save.
## NEVER creates ownership; responses must be verified by the native transport.
const JOURNAL: String = "user://jade_paid_summon_pending_v1.json"
const MAX_SIZE: int = 512
const UUID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

static func _valid_hex(value: String) -> bool:
	if value.length() != 64:
		return false
	var re := RegEx.new()
	return re.compile("^[0-9a-f]{64}$") == OK and re.search(value) != null

static func _valid_uuid(value: String) -> bool:
	var re := RegEx.new()
	return re.compile(UUID_PATTERN) == OK and re.search(value) != null

static func read_pending() -> Dictionary:
	if not FileAccess.file_exists(JOURNAL):
		return {}
	var f := FileAccess.open(JOURNAL, FileAccess.READ)
	if f == null or f.get_length() < 2 or f.get_length() > MAX_SIZE:
		return {"error": "unreadable_journal"}
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return {"error": "invalid_journal"}
	var d: Dictionary = data
	if d.size() != 4 or d.get("version") != 1:
		return {"error": "invalid_journal"}
	if not (d.get("account_binding") is String) or not _valid_hex(d["account_binding"]):
		return {"error": "invalid_journal"}
	if not (d.get("request_id") is String) or not _valid_uuid(d["request_id"]):
		return {"error": "invalid_journal"}
	if not (typeof(d.get("pull_count")) in [TYPE_INT, TYPE_FLOAT]) or float(d["pull_count"]) not in [1.0, 10.0]:
		return {"error": "invalid_journal"}
	d["pull_count"] = int(d["pull_count"])
	return d.duplicate(true)

static func _uuid4() -> String:
	var crypto := Crypto.new()
	var v: PackedByteArray = crypto.generate_random_bytes(16)
	if v.size() != 16:
		return ""
	v[6] = (int(v[6]) & 15) | 64
	v[8] = (int(v[8]) & 63) | 128
	var s: String = v.hex_encode()
	return "%s-%s-%s-%s-%s" % [s.substr(0, 8), s.substr(8, 4), s.substr(12, 4), s.substr(16, 4), s.substr(20, 12)]

static func create_pending(binding: String, pull_count: int) -> Dictionary:
	if not _valid_hex(binding) or pull_count not in [1, 10]:
		return {"error": "invalid_request"}
	var existing: Dictionary = read_pending()
	if not existing.is_empty():
		if existing.has("error"):
			return existing
		if existing["account_binding"] != binding:
			return {"error": "another_account_has_pending_request"}
		return existing # Reuse SAME UUID after crash; never create a second charge.
	var request_id: String = _uuid4()
	if not _valid_uuid(request_id):
		return {"error": "secure_uuid_failed"}
	var d: Dictionary = {"version": 1, "account_binding": binding, "request_id": request_id, "pull_count": pull_count}
	var temp: String = JOURNAL + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return {"error": "journal_write_failed"}
	f.store_string(JSON.stringify(d))
	f.flush()
	f.close()
	var moved: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(JOURNAL))
	if moved != OK:
		return {"error": "journal_commit_failed"}
	return d

static func clear_committed(binding: String, request_id: String) -> bool:
	var data: Dictionary = read_pending()
	if data.is_empty() or data.has("error"):
		return false
	if data.get("account_binding") != binding or data.get("request_id") != request_id:
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(JOURNAL)) == OK
