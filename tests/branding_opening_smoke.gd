extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BRANDING_QA " + label)
func _run() -> void:
	if not OS.get_user_data_dir().contains("jade_branding_isolated_qa"):
		quit(2)
		return
	var packed: PackedScene = load("res://scenes/system/boot.tscn")
	var boot: Control = packed.instantiate()
	root.add_child(boot)
	current_scene = boot
	var start: int = Time.get_ticks_msec()
	while (current_scene == boot or current_scene == null) and Time.get_ticks_msec() - start < 5000:
		await process_frame
	var signed_in: bool = "--signed-in" in OS.get_cmdline_user_args()
	_check(current_scene != boot, "startup completed")
	_check(current_scene != null and current_scene.name == ("MainDestination" if signed_in else "AccountDestination"), "Google versus Guest routing preserved")
	_check(root.get_node("GoogleAccountManager").refreshes == 1, "one identity refresh")
	_check(Time.get_ticks_msec() - start >= (130 if "--reduced" in OS.get_cmdline_user_args() else 620), "brief presentation minimum")
	var art: Control = packed.instantiate()
	art.set_script(null)
	root.add_child(art)
	for viewport: Vector2i in [Vector2i(360,640),Vector2i(390,844),Vector2i(648,1152),Vector2i(1152,648),Vector2i(360,480)]:
		root.size = viewport
		await process_frame
		await process_frame
		var presentation: Control = art.get_node("Presentation")
		var logo: Control = presentation.get_node("Lockup")
		var status: Control = presentation.get_node("Status")
		var studio: Control = presentation.get_node("Studio")
		_check(Rect2(Vector2.ZERO, art.size).encloses(logo.get_rect()), "logo inside viewport " + str(viewport))
		_check(not logo.get_rect().intersects(status.get_rect()), "no logo/status overlap " + str(viewport))
		_check(Rect2(Vector2.ZERO, art.size).encloses(studio.get_rect()), "studio within viewport " + str(viewport))
	var presentation: Control = art.get_node("Presentation")
	presentation.show_failure()
	_check(presentation.get_node("Retry").visible, "local load failure has retry")
	presentation.clear_failure()
	_check(not presentation.get_node("Retry").visible, "retry returns to loading presentation")
	_check(presentation.get_node("Lockup").texture.get_width() == 1024, "real logo asset imported")
	art.queue_free()
	await process_frame
	print("BRANDING_OPENING_QA=", "PASS" if failures == 0 else "FAIL", "; CHECKS=", checks, "; FAILURES=", failures)
	quit(0 if failures == 0 else 1)
