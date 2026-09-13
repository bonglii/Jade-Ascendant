extends SceneTree

## Actual rendered gameplay, isolated saves. F12 writes the current viewport.
## This development utility is excluded from release exports.
var ready_to_capture: bool = false
var was_pressed: bool = false
var capturing: bool = false
var output_folder: String = ""

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var token: String = str(ProjectSettings.get_setting("jade_phase0/token", ""))
	if not OS.is_debug_build() or not token.begins_with("jade_phase0_") or OS.get_user_data_dir().replace("\\", "/").get_file() != token:
		push_error("Use AMBIL_SCREENSHOT.bat to isolate capture saves.")
		quit(2)
		return
	output_folder = str(ProjectSettings.get_setting("jade_phase0/capture_path", ""))
	if output_folder.is_empty() or not output_folder.is_absolute_path():
		quit(2)
		return
	root.size = Vector2i(1080, 1920)
	root.title = "Jade Ascendant | F12: Screenshot"
	var error: Error = change_scene_to_file("res://scenes/ui/main_menu.tscn")
	if error != OK:
		quit(1)
		return
	ready_to_capture = true

func _process(_delta: float) -> bool:
	var pressed: bool = Input.is_physical_key_pressed(KEY_F12)
	if ready_to_capture and pressed and not was_pressed and not capturing:
		_capture.call_deferred()
	was_pressed = pressed
	return false

func _capture() -> void:
	capturing = true
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var name: String = "JadeAscendant_%s_%d.png" % [timestamp, Time.get_ticks_msec()]
	var error: Error = screenshot.save_png(output_folder.path_join(name))
	if error == OK:
		print("Screenshot: ", output_folder.path_join(name), " | ", screenshot.get_width(), "x", screenshot.get_height())
	else:
		push_error("Screenshot could not be saved: " + str(error))
	capturing = false
