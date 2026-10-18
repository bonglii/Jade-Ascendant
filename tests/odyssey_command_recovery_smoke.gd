extends SceneTree
const Client = preload("res://scripts/monetization/odyssey_client.gd")
class Transport:
	extends RefCounted
	var raw: String = ""
	var request_id: String = ""
	func requestOdysseyV1(id: String, body: String) -> void:
		request_id = id
		raw = body
class Harness:
	extends Client
	var transport := Transport.new()
	func _path() -> String: return "user://odyssey_recovery_fixture.json"
	func _bridge() -> Object: return transport
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		push_error(label)
		quit(1)
		assert(false, label)
func command(action: Dictionary) -> Dictionary:
	return {"event_id": "dragon-odyssey-1", "request_id": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "revision": 3, "action": action}
func _initialize() -> void:
	for action: Dictionary in [{"kind":"sync"}, {"kind":"roll"}, {"kind":"ad_intent"}, {"kind":"route","choice":"safe"}, {"kind":"route","choice":"challenge"}, {"kind":"counter","choice":0}, {"kind":"counter","choice":2}, {"kind":"mission","mission":1}, {"kind":"mission","mission":3}, {"kind":"mission","mission":5}, {"kind":"milestone","milestone":24}, {"kind":"milestone","milestone":48}, {"kind":"milestone","milestone":72}, {"kind":"buy_dice","pack":1}, {"kind":"buy_dice","pack":5}]:
		var fresh: Dictionary = command(action)
		var restored: Variant = JSON.parse_string(JSON.stringify(fresh))
		check(typeof(restored.revision) == TYPE_FLOAT, "reproduce JSON journal float decoding")
		var canonical: Dictionary = Client.canonical_command(restored)
		check(not canonical.is_empty(), "valid recovered action")
		check(JSON.stringify(canonical) == JSON.stringify(fresh), "identical canonical wire after recovery")
		check(canonical.request_id == fresh.request_id and canonical.event_id == fresh.event_id, "stable retry identity")
		for field: String in ["choice", "mission", "milestone", "pack"]:
			if canonical.action.has(field) and action.kind != "route": check(typeof(canonical.action[field]) == TYPE_INT, "native numeric field is integer")
	for invalid: Dictionary in [{"kind":"buy_dice","pack":1.5}, {"kind":"buy_dice","pack":2}, {"kind":"buy_dice","pack":1,"price":0}, {"kind":"roll","die":6}, {"kind":"counter","choice":-1}, {"kind":"counter","choice":1.2}, {"kind":"mission","mission":2}, {"kind":"milestone","milestone":25}, {"kind":"route","choice":"free"}, {"kind":"ad_success"}, {"kind":"buy_dice","pack":"1"}]:
		check(Client.canonical_command(command(invalid)).is_empty(), "reject unsupported action")
	for invalid_revision: Variant in [1.5, -1, 10001, "3", true, INF, NAN]:
		var bad: Dictionary = command({"kind":"roll"}); bad.revision = invalid_revision
		check(Client.canonical_command(bad).is_empty(), "reject invalid revision")
	check(Client.canonical_command({}).is_empty(), "reject empty journal")
	check(Client.canonical_command(null).is_empty(), "reject non-object journal")
	var extra: Dictionary = command({"kind":"roll"}); extra["die"] = 6
	check(Client.canonical_command(extra).is_empty(), "reject extra envelope field")
	var harness := Harness.new()
	var original: Dictionary = command({"kind":"buy_dice", "pack":5})
	var file := FileAccess.open(harness._path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(original)); file.close()
	var pending: Dictionary = harness._pending()
	check(typeof(pending.revision) == TYPE_INT and typeof(pending.action.pack) == TYPE_INT, "real pending journal normalized")
	check(harness._dispatch(pending), "recovered command dispatched")
	check(harness.transport.raw == JSON.stringify(original), "bridge gets original integer command")
	check(harness.transport.request_id == original.request_id, "retry does not regenerate ID")
	check(FileAccess.file_exists(harness._path()), "uncertain journal retained until server confirms")
	DirAccess.remove_absolute(harness._path())
	harness.free()
	print("ODYSSEY_COMMAND_RECOVERY=PASS; CHECKS=", checks, "; ALL_ACTIONS=15; REQUEST_ID_PRESERVED; NETWORK=NONE; SAVES=UNTOUCHED")
	quit()
