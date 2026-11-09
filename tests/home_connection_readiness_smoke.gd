extends SceneTree
const Paid = preload("res://scripts/monetization/paid_gameplay_v2.gd")
const Readiness = preload("res://scripts/managers/home_connection_readiness.gd")
var checks: int = 0
var failures: int = 0

class Account extends Node:
	var native_available: bool = true
	var busy: bool = false
	var binding: String = "a".repeat(64)
	var preparations: int = 0
	var guest_selected: bool = false
	func get_account_snapshot() -> Dictionary:
		return {"native_ready": native_available, "busy": busy}
	func get_monetization_account_binding() -> String:
		return binding
	func can_enter_local_without_identity() -> bool:
		return guest_selected
	func refresh_provider() -> void:
		pass
	func ensure_monetization_identity() -> void:
		preparations += 1

class Profile extends Node:
	var status: String = "connected"
	var busy: bool = false
	var requests: int = 0
	func get_profile_snapshot() -> Dictionary:
		return {"server_status": status}
	func get_connection_snapshot() -> Dictionary:
		return {"busy": busy, "can_retry": not busy}
	func connect_profile() -> void:
		busy = true
		requests += 1

class Pavilion extends Node:
	var paid_gameplay: Node

class Observer extends Readiness:
	var services: Dictionary = {}
	var android: bool = true
	func _ready() -> void:
		set_process(false)
	func _service(service_name: String) -> Node:
		return services.get(service_name)
	func _android() -> bool:
		return android

class PaidFixture extends Paid:
	var live: String = "a".repeat(64)
	var native: Object
	var checkpoint: Dictionary = {}
	var entry_account: Node
	func _ready() -> void:
		set_process(false)
	func _live_binding() -> String:
		return live
	func _bridge() -> Object:
		return native
	func _service(service_name: String) -> Node:
		if service_name == "GoogleAccountManager" and entry_account != null:
			return entry_account
		return super._service(service_name)
	func _checkpoint_for_gate() -> Dictionary:
		return checkpoint

class Bridge extends RefCounted:
	var manager: Node
	var state: Dictionary
	var calls: Array[Dictionary] = []
	var mode: String = "reply"
	func requestPaidGameplayV2(id: String, raw: String) -> void:
		calls.append({"id": id, "raw": raw})
		if mode == "hold":
			return
		if mode == "fail":
			manager.call_deferred("_on_result", id, false, "NETWORK_UNAVAILABLE", "")
			return
		reply(id, raw)
	func reply(id: String, raw: String) -> void:
		var operation: Variant = null
		if not raw.is_empty():
			var command: Dictionary = JSON.parse_string(raw)
			var outcome: Variant = null
			if command.kind == "initialize":
				state.state = "ready"
			elif command.kind == "run_start":
				var stars: Dictionary = {}
				for item: String in state.slots.values():
					if not item.is_empty():
						stars[item] = state.stars[item]
				outcome = {"run_id": command.run_id, "slots": state.slots.duplicate(), "stars": stars, "weapon_level": command.weapon_level}
			state.revision = int(state.revision) + 1
			operation = {"request_id": command.request_id, "kind": command.kind, "outcome": outcome}
		manager.call_deferred("_on_result", id, true, "PAID_GAMEPLAY_VERIFIED", JSON.stringify({"snapshot": state, "operation": operation}))

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)

func state() -> Dictionary:
	return {"paid_gameplay_version": 2, "account_binding": "a".repeat(64), "catalog_hash": Paid.HASH, "state": "ready", "revision": 0, "wallet": {"balance": 1500, "revision": 1}, "inventory": {"cloudstep_boots": 2}, "stars": {"cloudstep_boots": 2}, "slots": {"armament": "", "robe": "", "bracer": "", "boots": "cloudstep_boots", "pendant": ""}, "pity": {"rare_plus": 0, "epic_plus": 10, "legendary": 10}, "wish": "", "wish_guaranteed": false, "lifetime_pulls": 10, "rates": {"common": 6000, "rare": 2900, "epic": 900, "legendary": 200}, "lease_seconds": 120}

func run() -> void:
	if not OS.get_user_data_dir().contains("jade_connection_combat_qa"):
		quit(2)
		return
	create_timer(70).timeout.connect(func(): quit(1))
	await process_frame
	var account := Account.new()
	var profile := Profile.new()
	var pavilion := Pavilion.new()
	var observer := Observer.new()
	var paid := PaidFixture.new()
	var native := Bridge.new()
	native.manager = paid
	native.state = state()
	paid.native = native
	paid._binding = paid.live
	pavilion.paid_gameplay = paid
	observer.services = {"GoogleAccountManager": account, "PlayerIdentityManager": profile, "PlayerIdentityServerClient": profile, "PavilionManager": pavilion}
	for node: Node in [account, profile, pavilion, observer, paid]:
		root.add_child(node)
	check(observer.get_snapshot().stage == "equipment_pending", "Profile connection alone does not declare readiness")
	native.mode = "hold"
	observer.retry()
	observer.retry()
	check(native.calls.size() == 1, "Startup and Home retries coalesce the same pending read")
	check(observer.get_snapshot().stage == "equipment_pending", "Pending equipment has its own status")
	native.reply(native.calls[0].id, native.calls[0].raw)
	await process_frame
	await process_frame
	check(observer.get_snapshot().stage == "ready", "Confirmed profile and wallet/equipment declare ready")
	var count: int = native.calls.size()
	observer.retry()
	check(native.calls.size() == count, "Home re-entry reuses the current verified snapshot")
	profile.status = "connecting"
	profile.busy = true
	check(observer.get_snapshot().stage == "profile_pending" and observer.get_snapshot().equipment_ready, "Profile delay is distinguished from run equipment readiness")
	profile.busy = false
	profile.status = "network_13"
	check(observer.get_snapshot().stage == "profile_failed" and observer.get_snapshot().can_retry, "Failed profile offers retry")
	profile.status = "connected"
	paid.live = "b".repeat(64)
	check(not observer.get_snapshot().equipment_ready, "Account switch invalidates readiness immediately")
	paid.live = "a".repeat(64)
	account.native_available = false
	check(observer.get_snapshot().stage == "plugin_unavailable", "Missing native plugin is reported distinctly")
	observer.android = false
	check(observer.get_snapshot().stage == "local", "Desktop keeps local presentation")
	observer.android = true
	account.native_available = true
	account.binding = ""
	account.busy = true
	check(observer.get_snapshot().stage == "identity_pending", "Auth preparation has its own status")
	account.busy = false
	check(observer.get_snapshot().stage == "identity_failed", "Auth failure stops indefinite connecting UI")
	account.binding = paid.live
	for key: String in Readiness.TEXT:
		check(not str(Readiness.TEXT[key][0]).is_empty() and not str(Readiness.TEXT[key][1]).is_empty(), "Readiness labels cover both languages")
	paid.snapshot = {}
	native.mode = "reply"
	check(await paid.prepare_scene_run(false), "Cold run entry fetches and verifies account equipment")
	check(paid.selected_slot("boots", true) == "cloudstep_boots", "First combat loadout includes newly verified equipment")
	check(native.calls[-2].raw == "" and JSON.parse_string(native.calls[-1].raw).kind == "run_start", "Verified read precedes run authorization")
	paid._reset_run()
	paid.snapshot = {}
	native.mode = "fail"
	check(not await paid.prepare_scene_run(false), "Failed verification never silently starts a different local loadout")
	check(not paid._run_prepared and paid.run_gate_error == "CONNECTION_UNAVAILABLE", "Entry failure retains a concrete connection reason")
	paid.snapshot = state()
	paid._expires = Time.get_ticks_msec() + 120000
	native.state = state()
	native.mode = "hold"
	var started: int = Time.get_ticks_msec()
	check(not await paid.prepare_scene_run(false), "Uncertain run authorization returns to an interactive menu")
	check(Time.get_ticks_msec() - started < 13500 and paid.run_gate_error == "VERIFICATION_PENDING", "Foreground wait is bounded while request stays recoverable")
	check(paid.busy and FileAccess.file_exists(paid._journal_path()), "Foreground timeout preserves in-flight request and durable journal")
	var original_request: Dictionary = native.calls[-1]
	native.reply(original_request.id, original_request.raw)
	await process_frame
	await process_frame
	check(not FileAccess.file_exists(paid._journal_path()) and paid.connection_ready(), "Late matching receipt safely completes the original request")
	paid._reset_run()
	paid.snapshot = {}
	native.mode = "reply"
	native.state = state()
	native.state.state = "initialize_required"
	native.state.inventory = {}
	native.state.stars = {}
	native.state.slots.boots = ""
	check(await paid.prepare_scene_run(false), "New-account initialization completes before run entry")
	check(paid.connection_ready() and paid.snapshot.state == "ready", "Initialization response is confirmed before readiness")
	paid._reset_run()
	paid.snapshot = {}
	native.state.state = "unfunded"
	native.state.revision = 0
	check(await paid.prepare_scene_run(false), "Confirmed empty account may play with local equipment")
	paid._reset_run()
	paid.snapshot = {}
	paid._next_read = Time.get_ticks_msec() + 15000
	count = native.calls.size()
	check(not paid.prepare_connection(false) and native.calls.size() == count, "Automatic preparation respects transport backoff")
	check(paid.prepare_connection(true), "Explicit retry can recover before backoff expires")
	await process_frame
	await process_frame
	paid.snapshot = {}
	paid.live = ""
	paid._binding = ""
	account.binding = ""
	account.busy = true
	paid.entry_account = account
	native.state = state()
	create_timer(0.05).timeout.connect(func():
		account.busy = false
		account.binding = "a".repeat(64)
		paid.live = account.binding)
	check(await paid.prepare_scene_run(false), "Slow initial identity completes before equipment verification")
	check(account.preparations > 0 and paid._run_slots.boots == "cloudstep_boots", "Early auth preparation preserves the server loadout")
	paid._reset_run()
	paid.live = ""
	paid._binding = ""
	paid.snapshot = {}
	account.native_available = false
	check(not await paid.prepare_scene_run(false) and paid.run_gate_error == "NATIVE_LOGIN_UNAVAILABLE", "Native failure cannot silently replace an account loadout with local play")
	account.guest_selected = true
	check(await paid.prepare_scene_run(false) and paid._run_ref.is_empty(), "Explicit Guest entry remains available without native services")
	paid.entry_account = null
	paid._reset_run()
	paid.checkpoint = {"legacy": true}
	check(await paid.prepare_scene_run(true) and paid._run_ref.is_empty(), "Legacy local Continue retains its own equipment source")
	paid._reset_run()
	paid.live = ""
	paid._binding = ""
	paid.snapshot = {}
	check(await paid.prepare_scene_run(false) and paid._run_ref.is_empty(), "Guest without native services can start a local run")
	for node: Node in [observer, paid, pavilion, profile, account]:
		node.free()
	print("HOME_CONNECTION_READINESS checks=%d failures=%d" % [checks, failures])
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	quit(1 if failures else 0)
