extends CanvasLayer
## Device preference only; never attached to a Google account or cloud save.
const PromptPanel=preload("res://scripts/ui/liveops/odyssey_panel.gd")
const PremiumButton=preload("res://scripts/ui/liveops/odyssey_button.gd")
var native: Object
var _tick: float=0.0
var _home_since: int=0
var _shade: Control
func _ready() -> void:
 layer=92
 if OS.get_name()!="Android" or not Engine.has_singleton("JadeMonetizationNativeBridge"): set_process(false); return
 native=Engine.get_singleton("JadeMonetizationNativeBridge")
 # Android JNI methods are callable but Object.has_method() is not a capability probe.
 # The release exporter verifies the notification-enabled native candidate.
func status() -> Dictionary:
 if native==null: return {"supported":false,"stage":"unavailable"}
 var result: Variant=JSON.parse_string(str(native.call("getUpdateNotificationStatus")))
 return result if result is Dictionary else {"supported":false,"stage":"unavailable"}
func enable(value: bool) -> void:
 if native!=null: native.call("setUpdateNotificationsEnabled",value)
func open_system_settings() -> void:
 if native!=null: native.call("openUpdateNotificationSettings")
func _safe_home() -> bool:
 var scene: Node=get_tree().current_scene
 if scene==null or scene.scene_file_path!="res://scenes/ui/main_menu.tscn" or get_tree().paused: return false
 var account: Node=get_node_or_null("/root/GoogleAccountManager")
 if account!=null and account.has_method("get_account_snapshot") and bool(account.call("get_account_snapshot").get("busy",false)): return false
 var transitions: Node=get_node_or_null("/root/SceneTransitionManager")
 if transitions!=null and bool(transitions.get("is_transitioning")): return false
 for canvas: Node in get_tree().root.find_children("*","CanvasLayer",true,false):
  if canvas==self or not (canvas as CanvasLayer).visible: continue
  var caption: String=str(canvas.name).to_lower()
  if "tutorial" in caption or "announcement" in caption or "onboarding" in caption: return false
 for control: Node in get_tree().root.find_children("*","Control",true,false):
  var caption: String=str(control.name).to_lower()
  if "popup" not in caption and "modal" not in caption and "overlay" not in caption and "dialog" not in caption and "tutorial" not in caption: continue
  var view: Control=control as Control
  if view is ColorRect and (view as ColorRect).color.a<=0.01: continue
  if view.modulate.a<=0.01: continue
  if view.is_visible_in_tree() and view.mouse_filter!=Control.MOUSE_FILTER_IGNORE and view.size.length()>20: return false
 return true
func _process(delta: float) -> void:
 _tick-=delta
 if _tick>0: return
 _tick=0.5
 if not _safe_home(): _home_since=0; return
 if _home_since==0: _home_since=Time.get_ticks_msec(); return
 if Time.get_ticks_msec()-_home_since<3000: return
 var data: Dictionary=status()
 if not data.get("supported",false) or data.get("education_shown",true): set_process(false); return
 _show_prompt(); set_process(false)
func _show_prompt() -> void:
 native.call("deferUpdateNotifications")
 var indonesian: bool=TranslationServer.get_locale().begins_with("id")
 _shade=ColorRect.new(); (_shade as ColorRect).color=Color(0.005,0.018,0.02,0.88); _shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(_shade)
 var panel:=PromptPanel.new(); panel.name="UpdateNoticeBoundedPanel"; panel.clip_contents=true; _shade.add_child(panel)
 var inset: StyleBox=panel.get_theme_stylebox("panel").duplicate(); inset.content_margin_left=64; inset.content_margin_right=64; inset.content_margin_top=56; inset.content_margin_bottom=56; panel.add_theme_stylebox_override("panel",inset)
 var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",10); panel.add_child(column)
 var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; scroll.clip_contents=true; column.add_child(scroll)
 var reading:=VBoxContainer.new(); reading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; reading.add_theme_constant_override("separation",14); scroll.add_child(reading)
 for item: Dictionary in [{"text":"KABAR DARI SANCTUARY" if indonesian else "NEWS FROM THE SANCTUARY","size":17},{"text":"Petualangan baru, jangan terlewat." if indonesian else "Be ready for the next adventure.","size":25},{"text":"Izinkan notifikasi untuk mengetahui update game. Ketuk notifikasi untuk membuka Play Store. Opsional—bisa diubah di Settings." if indonesian else "Get optional game update alerts. Tap an alert to open Play Store. You can change this anytime in Settings.","size":18}]:
  var text:=Label.new(); text.text=item.text; text.add_theme_font_size_override("font_size",item.size); text.add_theme_color_override("font_color",Color("f5e5bb")); text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; text.size_flags_horizontal=Control.SIZE_EXPAND_FILL; reading.add_child(text)
 var allow:=PremiumButton.new(); allow.text="AKTIFKAN NOTIFIKASI" if indonesian else "ENABLE UPDATE ALERTS"; allow.custom_minimum_size.y=66; allow.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; allow.pressed.connect(func() -> void: enable(true); _dismiss()); column.add_child(allow)
 var later:=PremiumButton.new(); later.text="LAIN KALI" if indonesian else "NOT NOW"; later.custom_minimum_size.y=58; later.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; later.pressed.connect(_dismiss); column.add_child(later)
 var fit: Callable=func() -> void:
  if not is_instance_valid(panel): return
  var area: Vector2=get_viewport().get_visible_rect().size
  var desired:=Vector2(minf(520,area.x-40),minf(560,area.y-48))
  panel.size=desired; panel.position=(area-desired)*0.5
 fit.call(); get_viewport().size_changed.connect(fit)
 _shade.tree_exiting.connect(func() -> void:
  if get_viewport().size_changed.is_connected(fit): get_viewport().size_changed.disconnect(fit))
func _dismiss() -> void:
 if is_instance_valid(_shade): _shade.queue_free()
 _shade=null
func _input(event: InputEvent) -> void:
 if is_instance_valid(_shade) and event.is_action_pressed("ui_cancel"): _dismiss(); get_viewport().set_input_as_handled()
