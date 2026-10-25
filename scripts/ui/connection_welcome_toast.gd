extends CanvasLayer
## Session-only presentation. Identity/server status remains authoritative.
## Owned by the persistent identity manager, never by a menu or account signal.
const FRAME: Texture2D = preload("res://assets/ui/home/sanctuary/frame_compact.png")
const SEAL: Texture2D = preload("res://assets/branding/boot_seal.png")
const SERIF: Font = preload("res://assets/ui/library/fonts/archive_serif.ttf")
const ENTER: float = 0.30
const HOLD: float = 3.0
const EXIT: float = 0.25
const MENUS: Array[String] = ["main_menu","cultivation_menu","equipment_screen","daily_quest_screen","pavilion_screen"]
var _identity: Node
var _latest: Dictionary = {}
var _pending: bool = false
var _shown_once: bool = false
var _active: bool = false
var _focused: bool = true
var _shown_uid: String = ""
var _age: float = 0.0
var _poll: float = 0.0
var _target: Vector2
var _panel: Panel
var _heading: Label
var _nickname: Label
var _subtitle: Label
var _seal: TextureRect
var _life: ProgressBar
var _badge: Label
var _frame: NinePatchRect

func _ready() -> void:
 layer = 85 # Below announcements/transitions; no input interception.
 process_mode = Node.PROCESS_MODE_ALWAYS
 _identity = get_parent()
 _build()
 get_viewport().size_changed.connect(_layout)
 _identity.connect("profile_changed",_profile_changed)
 _profile_changed(_identity.call("get_profile_snapshot"))

func _profile_changed(profile: Dictionary) -> void:
 _latest = profile.duplicate()
 if _active:
  if str(profile.get("player_uid","")) != _shown_uid:
   _finish()
  else:
   _copy_text()
   _layout()
 _pending = not _shown_once and bool(profile.get("ready",false)) and bool(profile.get("server_registered",false)) and str(profile.get("scope","")) == "server" and str(profile.get("server_status","")) == "connected" and not str(profile.get("display_name","")).strip_edges().is_empty()
 set_process(_pending or _active)

func _settings() -> Node:
 return get_node_or_null("/root/SettingsManager")

func _copy_text() -> void:
 var settings: Node = _settings()
 var id: bool = settings != null and str(settings.get("language")) == "id"
 _heading.text = "Selamat datang kembali," if id else "Welcome back,"
 var nickname: String = str(_latest.get("display_name","")).strip_edges()
 _nickname.text = nickname if nickname.to_lower().begins_with("cultivator ") else "Cultivator " + nickname
 _subtitle.text = "Akun berhasil terhubung." if id else "Account connected."

func _can_present() -> bool:
 var scene: Node = get_tree().current_scene
 var transition: Node = get_node_or_null("/root/SceneTransitionManager")
 if not _focused or scene == null or get_tree().paused or (transition != null and bool(transition.get("is_transitioning"))): return false
 if scene.scene_file_path.get_file().get_basename() not in MENUS: return false
 var announcements: CanvasLayer = get_node_or_null("/root/AnnouncementCenter") as CanvasLayer
 if announcements != null and announcements.visible: return false
 for item: Node in scene.find_children("*","Control",true,false):
  var control: Control = item as Control
  var key: String = str(control.name).to_lower()
  if ("popup" in key or "modal" in key or "overlay" in key or "dialog" in key) and control.is_visible_in_tree() and control.modulate.a > 0.01 and control.size.length() > 20.0 and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
   if control is ColorRect and (control as ColorRect).color.a <= 0.01: continue
   return false
 return true

func _process(delta: float) -> void:
 if not _active:
  _poll -= delta
  if not _pending or _poll > 0.0: return
  _poll = 0.2
  if not _can_present(): return
  _shown_once = true
  _pending = false
  _shown_uid = str(_latest.player_uid)
  _active = true
  _age = 0.0
  _copy_text()
  _layout()
  _panel.show()
 if not _can_present():
  _finish()
  return
 _age += delta
 if _age >= ENTER + HOLD + EXIT:
  _finish()
  return
 _animate()

func _animate() -> void:
 var fraction: float = clampf(_age / ENTER,0.0,1.0)
 if _age > ENTER + HOLD: fraction = 1.0 - clampf((_age - ENTER - HOLD) / EXIT,0.0,1.0)
 var settings: Node = _settings()
 var reduced: bool = settings != null and bool(settings.get("reduced_effects"))
 var eased: float = 1.0 - pow(1.0 - fraction,3.0)
 _panel.position = _target if reduced else Vector2(_target.x,lerpf(-_panel.size.y - 8.0,_target.y,eased))
 _panel.modulate.a = fraction if reduced else minf(1.0,fraction * 3.0)
 _life.value = clampf(1.0 - maxf(0.0,_age - ENTER) / HOLD,0.0,1.0)

func _finish() -> void:
 _active = false
 _panel.hide()
 set_process(_pending and not _shown_once)

func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
  _focused = false
  if _active: _finish()
 elif what in [NOTIFICATION_APPLICATION_RESUMED,NOTIFICATION_APPLICATION_FOCUS_IN]:
  _focused = true

static func safe_rect(view: Rect2, window: Vector2i, device: Rect2i) -> Rect2:
 if window.x <= 0 or window.y <= 0 or device.size.x <= 0 or device.size.y <= 0: return view
 var ratio: Vector2 = view.size / Vector2(window)
 var mapped := Rect2(view.position + Vector2(device.position) * ratio,Vector2(device.size) * ratio)
 return view.intersection(mapped)

func _layout() -> void:
 if not is_instance_valid(_panel): return
 var area: Rect2 = get_viewport().get_visible_rect()
 if OS.has_feature("android") or OS.has_feature("ios"):
  area = safe_rect(area,DisplayServer.window_get_size(),DisplayServer.get_display_safe_area())
 _layout_area(area)

func _layout_area(area: Rect2) -> void:
 var width: float = minf(600.0,maxf(1.0,area.size.x - 28.0))
 var scale_value: float = clampf(width / 600.0,0.78,1.0)
 var padding: float = 20.0 * scale_value
 var seal_size: float = 66.0 * scale_value
 var text_x: float = padding + seal_size + 12.0
 var text_width: float = maxf(1.0,width - text_x - padding)
 var heading_size: int = roundi(21.0 * scale_value)
 while heading_size > 13 and SERIF.get_string_size(_heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,heading_size).x > text_width: heading_size -= 1
 _heading.add_theme_font_size_override("font_size",heading_size)
 var name_size: int = roundi(25.0 * scale_value)
 _nickname.add_theme_font_size_override("font_size",name_size)
 _subtitle.add_theme_font_size_override("font_size",roundi(17.0 * scale_value))
 var top: float = 16.0 * scale_value
 var heading_height: float = SERIF.get_height(heading_size) + 3.0
 var name_height: float = SERIF.get_height(name_size) + 4.0
 if SERIF.get_string_size(_nickname.text,HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x > text_width: name_height *= 2.0
 var subtitle_height: float = 23.0 * scale_value
 var total: float = top + heading_height + name_height + subtitle_height + 22.0
 _panel.size = Vector2(width,total)
 _heading.position = Vector2(text_x,top)
 _heading.size = Vector2(text_width,heading_height)
 _nickname.position = Vector2(text_x,top + heading_height)
 _nickname.size = Vector2(text_width,name_height)
 _subtitle.position = Vector2(text_x,top + heading_height + name_height + 2.0)
 _subtitle.size = Vector2(text_width,subtitle_height)
 _seal.position = Vector2(padding,(total - seal_size) * 0.5 - 3.0)
 _seal.size = Vector2(seal_size,seal_size)
 _badge.position = _seal.position + Vector2(seal_size - 21.0,seal_size - 21.0)
 _badge.size = Vector2(24,24)
 _life.position = Vector2(padding + 4.0,total - 13.0)
 _life.size = Vector2(width - 2.0 * padding - 8.0,2.0)
 _frame.size = _panel.size
 _target = area.position + Vector2((area.size.x - width) * 0.5,12.0)
 _animate()

func _label(font: Font, color: Color) -> Label:
 var label := Label.new()
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_override("font",font)
 label.add_theme_color_override("font_color",color)
 label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 _panel.add_child(label)
 return label

func _build() -> void:
 _panel = Panel.new()
 _panel.name = "ConnectionWelcomeToast"
 _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _panel.hide()
 add_child(_panel)
 var fill := StyleBoxFlat.new()
 fill.bg_color = Color(0.014,0.10,0.095,0.98)
 fill.border_color = Color(0.70,0.58,0.32,0.8)
 fill.set_border_width_all(1)
 fill.set_corner_radius_all(16)
 _panel.add_theme_stylebox_override("panel",fill)
 _frame = NinePatchRect.new()
 _frame.texture = FRAME
 _frame.draw_center = false
 _frame.patch_margin_left = 32; _frame.patch_margin_right = 32
 _frame.patch_margin_top = 26; _frame.patch_margin_bottom = 26
 _frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _panel.add_child(_frame)
 _seal = TextureRect.new()
 var atlas := AtlasTexture.new()
 atlas.atlas = SEAL
 atlas.region = Rect2(139,112,235,288)
 _seal.texture = atlas
 _seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 _seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 _seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _panel.add_child(_seal)
 _heading = _label(SERIF,Color(0.96,0.92,0.80))
 _nickname = _label(SERIF,Color(1.0,0.91,0.66))
 _nickname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _nickname.max_lines_visible = 2
 _subtitle = _label(ThemeDB.fallback_font,Color(0.55,0.88,0.77))
 _badge = _label(ThemeDB.fallback_font,Color(0.65,1.0,0.80))
 _badge.text = "✓"
 _badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 _badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 _badge.add_theme_font_size_override("font_size",19)
 var badge_style := StyleBoxFlat.new()
 badge_style.bg_color = Color(0.02,0.20,0.15)
 badge_style.border_color = Color(0.74,0.64,0.37)
 badge_style.set_border_width_all(1)
 badge_style.set_corner_radius_all(12)
 _badge.add_theme_stylebox_override("normal",badge_style)
 _life = ProgressBar.new()
 _life.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _life.show_percentage = false
 _life.max_value = 1.0
 var track := StyleBoxFlat.new()
 track.bg_color = Color(0.11,0.24,0.20)
 var ink := StyleBoxFlat.new()
 ink.bg_color = Color(0.46,0.87,0.69)
 _life.add_theme_stylebox_override("background",track)
 _life.add_theme_stylebox_override("fill",ink)
 _panel.add_child(_life)
