extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("PUBLIC_READINESS_UI " + label)
func frames(count: int = 8) -> void:
	for i: int in range(count): await process_frame
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_paid_v2_qa"): quit(2); return
	create_timer(30.0).timeout.connect(func(): push_error("PUBLIC_READINESS_UI_TIMEOUT"); quit(1))
	await frames()
	for language: String in ["en", "id"]:
		root.get_node("SettingsManager").set("language", language)
		change_scene_to_file("res://scenes/ui/settings_screen.tscn"); await frames(16)
		var screen: Node = current_scene
		var tools: Control=screen.find_child("AccountRecoveryTools",true,false)
		var expand: Button=screen.find_child("AccountRecoveryToggle",true,false)
		check(not tools.visible,"recovery details start collapsed")
		expand.pressed.emit();await frames()
		check(tools.is_visible_in_tree(),"test actual opened recovery panel")
		for size: Vector2i in [Vector2i(320, 568), Vector2i(390, 844), Vector2i(648, 1152)]:
			root.size = size; await frames()
			var save: Button = screen.get("_backup_save")
			var restore: Button = screen.get("_backup_restore")
			check(save != null and restore != null and save.disabled and restore.disabled, "signed-out actions disabled")
			var canvas: Vector2 = save.get_viewport_rect().size
			print("PUBLIC_READINESS_LAYOUT window=%s canvas=%s button=%s" % [str(size), str(canvas), str(save.size)])
			check(save.size.x <= canvas.x - 20 and restore.size.x <= canvas.x - 20 and save.size.y >= 48, "backup actions fit stretched mobile canvas")
			var font: Font = save.get_theme_font("font")
			var style: StyleBox = save.get_theme_stylebox("normal")
			check(font.get_string_size(save.text, HORIZONTAL_ALIGNMENT_LEFT, -1, save.get_theme_font_size("font_size")).x <= save.size.x - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT), "backup button text is complete")
			check(save.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE and restore.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE, "release-only actions respect scrolling")
		var report: String = screen.call("get_support_summary")
		check(not report.contains("Version=\n") and report.contains("Version code=") and report.contains("Build IAP target="), "support has explicit version/build fields")
		check(report.contains("Progress backup domains=9") and report.contains("Paid checkout ready="), "support separates unfunded checkout from ready gameplay")
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	current_scene.queue_free(); await frames(2)
	print("PUBLIC_READINESS_UI checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
