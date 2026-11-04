extends SceneTree
var checks: int = 0
var failures: int = 0
const Prefs = preload("res://scripts/ui/joystick_prefs.gd")
class Home extends Control:
 var checkpoint: bool = false
 func _has_checkpoint() -> bool: return checkpoint
class Idle extends Node:
 func get_auto_popup_min_offline_seconds() -> int: return 60
 func get_claimable_units() -> int: return 1
func check(ok: bool, reason: String) -> void:
 checks += 1
 if not ok: failures += 1;push_error(reason)
func settle() -> void:
 for frame in range(8): await process_frame
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("qa"): quit(2);return
 await settle()
 var home := Home.new();home.scene_file_path = "res://scenes/ui/main_menu.tscn"
 root.add_child(home);current_scene = home
 var idle := Idle.new();root.add_child(idle)
 var presenter: Node = load("res://tests/fixtures/polish_idle_presenter.gd").new();root.add_child(presenter);presenter.manager = idle;presenter._auto_gap_seconds = 120
 home.checkpoint = true;presenter._maybe_auto_open()
 check(presenter.opened == 0 and presenter._auto_shown, "Continue precedes the offline claim")
 home.checkpoint = false;presenter._maybe_auto_open()
 check(presenter.opened == 0, "Deferred offline popup never surprises a returning player after Continue")
 presenter._auto_shown = false
 var save: Node = root.get_node("SaveManager")
 save.begin_save_write_barrier("polish-completion-qa", "recovery fixture");presenter._maybe_auto_open()
 check(presenter.opened == 0 and presenter._auto_shown, "Save recovery precedes offline claims")
 save.end_save_write_barrier("polish-completion-qa")
 presenter._auto_shown = false
 var overlay := Control.new();overlay.name = "HomeProductionOverlay";overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE;home.add_child(overlay)
 check(not presenter._home_has_open_sheet(home), "Decorative Home overlay is not a modal")
 var sheet := Control.new();sheet.name = "LinYueProfileOverlay";sheet.mouse_filter = Control.MOUSE_FILTER_STOP;home.add_child(sheet)
 presenter._maybe_auto_open()
 check(presenter.opened == 0 and presenter._auto_shown, "Player-opened sheet wins over automatic claim")
 sheet.hide();presenter._auto_shown = false
 presenter._maybe_auto_open();presenter._maybe_auto_open()
 check(presenter.opened == 1, "Eligible unobstructed Home opens offline claim once")
 presenter.free();idle.free();home.free();current_scene = null
 var settings: Node = root.get_node("SettingsManager")
 for locale: String in ["en", "id"]:
  settings.language = locale
  for dimensions: Vector2i in [Vector2i(360,640), Vector2i(412,915)]:
   var viewport := SubViewport.new();viewport.size = dimensions;root.add_child(viewport)
   var page: Control = load("res://scenes/ui/settings_screen.tscn").instantiate();viewport.add_child(page);await settle()
   var preview: Control = page.joystick_preview
   check(preview.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Preview allows native parent scrolling")
   check(page.language_choice.get_parent() != page.fps_choice.get_parent(), "Language and performance are grouped separately")
   for size_index: int in range(3):
    Prefs.save_preferences(size_index, 0.4, size_index);await settle()
    var radius: float = 72.0 * Prefs.get_size_factor()
    check(is_equal_approx(preview.base_radius, radius), "Preview uses real combat size factor")
    check(is_equal_approx(preview.modulate.a, 0.4), "Preview uses saved opacity")
    check(preview.control_mode == size_index, "Preview follows movement mode")
    check(Rect2(Vector2.ZERO, preview.size).encloses(Rect2(preview.floating_center-Vector2.ONE*(radius+10), Vector2.ONE*(radius+10)*2)), "Joystick art fits compact card")
   Input.action_press("ui_right")
   page.free()
   check(Input.is_action_pressed("ui_right"), "Closing preview never releases gameplay input")
   Input.action_release("ui_right")
   viewport.free();await settle()
 Prefs.save_preferences(1,1.0,Prefs.DEFAULT_MODE)
 print("POLISH_COMPLETION checks=%d failures=%d" % [checks,failures])
 quit(1 if failures else 0)
