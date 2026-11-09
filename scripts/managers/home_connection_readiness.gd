extends Node
## Observes existing authorities. Readiness never grants money or equipment.
signal changed(snapshot: Dictionary)

const HOME: String = "res://scenes/ui/main_menu.tscn"
const TEXT: Dictionary = {
	"local": ["LOCAL PLAY", "MAIN LOKAL"],
	"plugin_unavailable": ["GOOGLE ERROR", "GOOGLE GAGAL"],
	"identity_pending": ["CONNECTING", "KONEKSI AKUN"],
	"identity_failed": ["RETRY LOGIN", "ULANG LOGIN"],
	"equipment_pending": ["SYNC GEAR", "SINKRON GEAR"],
	"equipment_failed": ["RETRY SYNC", "ULANG SINKRON"],
	"recovery_pending": ["RECOVERY", "PEMULIHAN"],
	"account_held": ["ACCOUNT REVIEW", "REVIEW AKUN"],
	"profile_pending": ["SYNC PROFILE", "SINKRON PROFIL"],
	"profile_failed": ["RETRY PROFILE", "ULANG PROFIL"],
	"ready": ["READY TO PLAY", "SIAP BERMAIN"]
}
var _last: Dictionary = {}
var _poll_left: float = 0.0

func _service(service_name: String) -> Node:
	return get_tree().root.get_node_or_null(NodePath(service_name))

func _android() -> bool:
	return OS.has_feature("android")

func _paid() -> Node:
	var pavilion: Node = _service("PavilionManager")
	return pavilion.get("paid_gameplay") if pavilion != null else null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_scene_changed)
	# All autoloads are available before this deferred preparation begins.
	retry.call_deferred(false)

func _scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path == HOME:
		retry(false)

func retry(user_requested: bool = true) -> void:
	if not _android() or get_tree().get_first_node_in_group("player") != null:
		return
	var account: Node = _service("GoogleAccountManager")
	if account == null:
		return
	account.refresh_provider()
	if account.get_monetization_account_binding().is_empty():
		account.ensure_monetization_identity()
		return
	var profile: Node = _service("PlayerIdentityServerClient")
	var identity: Node = _service("PlayerIdentityManager")
	if profile != null and identity.get_profile_snapshot().get("server_status") != "connected":
		var connection: Dictionary = profile.get_connection_snapshot()
		if bool(connection.get("can_retry", false)) and (user_requested or int(connection.get("retry_in_seconds", 0)) == 0):
			profile.connect_profile()
	var paid: Node = _paid()
	if paid != null and not bool(paid.get("busy")):
		paid.prepare_connection(user_requested)

func get_snapshot() -> Dictionary:
	if not _android():
		return {"stage": "local", "equipment_ready": true, "can_retry": false}
	var account: Node = _service("GoogleAccountManager")
	var auth: Dictionary = account.get_account_snapshot() if account != null else {}
	if not bool(auth.get("native_ready", false)):
		if account != null and account.can_enter_local_without_identity():
			return {"stage": "local", "equipment_ready": true, "can_retry": false}
		return {"stage": "plugin_unavailable", "equipment_ready": false, "can_retry": false}
	if account.get_monetization_account_binding().is_empty():
		var pending: bool = bool(auth.get("busy", false))
		return {"stage": "identity_pending" if pending else "identity_failed", "equipment_ready": false, "can_retry": not pending}
	var paid: Node = _paid()
	if paid == null:
		return {"stage": "equipment_failed", "equipment_ready": false, "can_retry": true}
	var pending_command: bool = bool(paid.mutation_pending())
	var equipment_ready: bool = bool(paid.connection_ready()) and not pending_command
	if not equipment_ready:
		var busy: bool = bool(paid.get("busy"))
		var preparing: bool = busy or str(paid.get("status")) in ["not_connected", "account_changed"]
		var stage: String = "equipment_pending" if preparing else "equipment_failed"
		if pending_command:
			stage = "recovery_pending"
		if str(paid.get("last_transport_stage")) == "ACCOUNT_HELD":
			stage = "account_held"
		return {"stage": stage, "equipment_ready": false, "can_retry": not preparing and stage != "account_held"}
	var identity: Node = _service("PlayerIdentityManager")
	var status: String = str(identity.get_profile_snapshot().get("server_status", "pending"))
	if status == "connected":
		return {"stage": "ready", "equipment_ready": true, "can_retry": false}
	var profile: Node = _service("PlayerIdentityServerClient")
	var profile_busy: bool = status in ["pending", "connecting", "registering", "resolving_ipv4", "checking_connection"] or (profile != null and bool(profile.get_connection_snapshot().get("busy", false)))
	return {"stage": "profile_pending" if profile_busy else "profile_failed", "equipment_ready": true, "can_retry": not profile_busy}

func status_text(stage: String, indonesian: bool) -> String:
	return str(TEXT.get(stage, TEXT.equipment_failed)[1 if indonesian else 0])

func _process(delta: float) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.scene_file_path != HOME:
		return
	_poll_left -= delta
	if _poll_left > 0.0:
		return
	_poll_left = 0.25
	var snapshot: Dictionary = get_snapshot()
	if snapshot != _last:
		_last = snapshot.duplicate()
		changed.emit(snapshot)
