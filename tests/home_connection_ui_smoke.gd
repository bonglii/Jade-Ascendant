extends SceneTree
const Readiness = preload("res://scripts/managers/home_connection_readiness.gd")
var checks: int = 0
var failures: int = 0
class Status extends Node:
	signal changed(snapshot: Dictionary)
	var stage: String = "equipment_pending"
	var requests: int = 0
	func get_snapshot() -> Dictionary:
		return {"stage": stage, "equipment_ready": stage in ["ready", "profile_pending"], "can_retry": stage.ends_with("failed")}
	func status_text(stage_key: String, indonesian: bool) -> String:
		return str(Readiness.TEXT[stage_key][1 if indonesian else 0])
	func retry() -> void:
		requests += 1
func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(reason)
func frames() -> void:
	for frame in range(14):
		await process_frame
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_connection_combat_qa"):
		quit(2)
		return
	create_timer(70).timeout.connect(func(): quit(1))
	await frames()
	var identity: Node = root.get_node("PlayerIdentityManager")
	var production: Node = identity.get_node("ConnectionReadiness")
	production.name = "ParkedConnectionReadiness"
	production.set_process(false)
	var status := Status.new()
	status.name = "ConnectionReadiness"
	identity.add_child(status)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var settings: Node = root.get_node("SettingsManager")
	settings.reduced_effects = true
	for locale: String in ["en", "id"]:
		settings.language = locale
		for dimensions: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(648, 1152)]:
			root.size = dimensions
			change_scene_to_file("res://scenes/ui/main_menu.tscn")
			await frames()
			var home: Control = current_scene.get_node("HomeUI/HomeProductionOverlay")
			for stage: String in Readiness.TEXT:
				status.stage = stage
				status.changed.emit(status.get_snapshot())
				await process_frame
				check(home.profile_status.text == status.status_text(stage, locale == "id"), "Home reflects the current readiness stage")
				var label: Label = home.profile_status
				var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
				check(width <= label.size.x + 1, "Full readiness caption fits compact Home: %s %s %s %.1f/%.1f" % [locale, dimensions, stage, width, label.size.x])
			status.stage = "equipment_failed"
			status.changed.emit(status.get_snapshot())
			home._open_profile()
			await frames()
			var card: Control = current_scene.find_child("PlayerIdentityCard", true, false)
			check(card != null and card._server_connect.visible and not card._server_connect.disabled, "Home profile offers equipment retry even with a connected profile")
			var requests: int = status.requests
			card._server_connect.pressed.emit()
			check(status.requests == requests + 1, "Profile retry delegates to the existing connection coordinator")
			status.stage = "ready"
			status.changed.emit(status.get_snapshot())
			check(not card._server_connect.visible, "Ready state removes the redundant connection action")
			var overlay: Control = current_scene.profile_overlay
			var viewport := Rect2(Vector2.ZERO, Vector2(dimensions)).grow(1)
			check(viewport.encloses(overlay.get_global_rect()), "Profile overlay stays inside phone viewport")
			check(viewport.encloses(current_scene.profile_sheet_panel.get_global_rect()), "Profile sheet and close button fit the viewport")
			check(current_scene.profile_sheet_body.size.x <= current_scene.profile_scroll.size.x + 1, "Profile content fits its scroll width")
			current_scene._close_profile_sheet()
	current_scene.free()
	current_scene = null
	status.free()
	production.name = "ConnectionReadiness"
	production.set_process(true)
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print("HOME_CONNECTION_UI checks=%d failures=%d; HEADLESS_GEOMETRY=true" % [checks, failures])
	quit(1 if failures else 0)
