extends SceneTree
var checks: int = 0
var failures: int = 0
var taps: int = 0
func check(ok: bool, caption: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("WELCOME_FAIL " + caption)
func frames(count_value: int = 6) -> void:
 for i: int in range(count_value): await process_frame
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"): quit(2); return
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 var cfg := ConfigFile.new()
 cfg.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]: cfg.set_value("tutorials",key,true)
 cfg.save("user://jade_onboarding.cfg")
 root.get_node("RefineOnboarding").set_process(false)
 root.get_node("RefineOnboarding").completed = true
 var identity: Node = root.get_node("PlayerIdentityManager")
 var toast: Node = identity.get_node("ConnectionWelcomeToast")
 check(not toast._shown_once and not toast._active,"a real fresh process begins unused, including after the prior process displayed it")
 change_scene_to_file("res://scenes/ui/main_menu.tscn")
 await frames(20)
 root.get_node("SettingsManager").language = "id"
 identity.rename_player("Ming Yue")
 var owner: String = "a".repeat(64)
 identity.set_server_context(owner,"connecting")
 check(identity.accept_server_identity(owner,{"version":1,"owner_binding":owner,"public_uid":"JA0123456789"}),"use acknowledged actual profile binding")
 toast._process(0.21)
 check(not toast._shown_once,"registration alone without connected state never welcomes")
 var blocker := ColorRect.new()
 blocker.name = "FixtureModal"
 blocker.size = Vector2(280,200)
 current_scene.add_child(blocker)
 identity.set_server_context(owner,"connected")
 toast._process(0.21)
 check(toast._pending and not toast._shown_once,"defer while a real modal is visible")
 blocker.hide()
 toast._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 toast._process(0.21)
 check(not toast._shown_once,"startup connection waits while the app is backgrounded")
 toast._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 toast._process(0.21)
 check(toast._shown_once and toast._active,"first successful connection displays once after menu is safe")
 check(toast._nickname.text == "Cultivator Ming Yue","use game nickname, not Google email, UID or sample name")
 check(toast._heading.text == "Selamat datang kembali,","localized greeting matches approved design")
 check(toast._panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,"card never blocks menu input")
 var tap_target := Button.new()
 tap_target.name = "WelcomeTapTarget"
 tap_target.z_index = 4000
 tap_target.position = toast._target + Vector2(90,20)
 tap_target.size = Vector2(180,60)
 tap_target.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
 current_scene.add_child(tap_target)
 tap_target.pressed.connect(func() -> void: taps += 1)
 await frames(2)
 var point: Vector2 = tap_target.get_global_rect().get_center()
 var down := InputEventMouseButton.new()
 down.button_index = MOUSE_BUTTON_LEFT; down.button_mask = MOUSE_BUTTON_MASK_LEFT
 down.pressed = true; down.position = point
 root.push_input(down,true)
 await frames(1)
 var up := InputEventMouseButton.new()
 up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = point
 root.push_input(up,true)
 await frames(2)
 check(taps == 1,"real GUI tap reaches the button underneath the visible toast")
 tap_target.queue_free()

 for child: Node in toast._panel.get_children():
  if child is Control: check(child.mouse_filter == Control.MOUSE_FILTER_IGNORE,"all decorative descendants pass touches")
 check(toast.find_children("*","AudioStreamPlayer",true,false).is_empty(),"no connection sound player")
 var age_before: float = float(toast._age)
 identity.set_server_context(owner,"connected")
 check(is_equal_approx(float(toast._age),age_before),"duplicate connected event cannot restart animation or lifetime")
 identity.rename_player("Cultivator Jade")
 check(toast._nickname.text == "Cultivator Jade","default/prefixed nickname does not double Cultivator")
 identity.rename_player("山海明月青云流风星辰清泉落雪飞花长空")
 for width: float in [360.0,405.0,648.0]:
  toast._layout_area(Rect2(0,30,width,1000))
  check(toast._panel.size.x <= width - 27.0,"phone width stays inside safe horizontal border")
  check(toast._nickname.size.x > 0 and toast._nickname.position.x + toast._nickname.size.x < toast._panel.size.x,"long nickname stays inside the frame")
  check(toast._subtitle.position.y + toast._subtitle.size.y <= toast._panel.size.y - 13.0,"subtitle never overflows the frame or lifetime line")
  check(toast._nickname.max_lines_visible == 2,"long nicknames wrap at most two lines with ellipsis")
 var safe: Rect2 = toast.safe_rect(Rect2(0,0,648,1152),Vector2i(1080,1920),Rect2i(0,80,1080,1800))
 check(is_equal_approx(safe.position.y,48.0) and safe.end.y <= 1152.0,"Android notch coordinates map into viewport units")
 root.get_node("SettingsManager").reduced_effects = true
 toast._layout_area(safe)
 toast._animate()
 check(toast._panel.position == toast._target,"reduced effects removes travel motion")
 toast._process(4.0)
 check(not toast._active and not toast._panel.visible,"dismiss after the three-second hold and transition")
 for state: String in ["retrying","connected","connected"]: identity.set_server_context(owner,state)
 toast._process(0.3)
 check(not toast._active and toast._shown_once,"reconnect cannot replay a consumed greeting")
 toast._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 toast._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
 toast._process(0.3)
 check(not toast._active,"returning from background is not a new app launch")
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn")
 await frames(12)
 check(identity.get_node("ConnectionWelcomeToast") == toast,"menu changes retain the same session guard")
 identity.set_server_context("b".repeat(64),"connected")
 toast._process(0.3)
 check(not toast._active,"account changes do not welcome twice per app launch")
 print("CONNECTION_WELCOME checks=%d failures=%d" % [checks,failures])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
