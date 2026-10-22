extends RefCounted
## Cached texture skins. Layout never changes reward, attacks or combat timing.
static var textures: Dictionary = {}
static func skin(palette: String, fill: bool = false) -> StyleBoxTexture:
 var key: String = palette + ("_fill" if fill else "_frame")
 if not textures.has(key): textures[key] = load("res://assets/ui/combat/ascendant_v3/%s.svg" % key)
 var style := StyleBoxTexture.new()
 style.texture = textures[key]
 style.texture_margin_left = 12 if fill else 24
 style.texture_margin_right = 12 if fill else 24
 style.texture_margin_top = 8 if fill else 18
 style.texture_margin_bottom = 8 if fill else 18
 style.content_margin_left = 0 if fill else 14
 style.content_margin_right = 0 if fill else 14
 style.content_margin_top = 0 if fill else 10
 style.content_margin_bottom = 0 if fill else 10
 return style
static func apply(hud: Node) -> void:
 var safe: Control = hud.get_node_or_null("ScreenRoot/HUDSafeArea")
 if safe == null: return
 var top: PanelContainer = safe.get_node_or_null("TopHUD")
 if top != null:
  top.add_theme_stylebox_override("panel",skin("jade"))
  var content: VBoxContainer = top.get_node_or_null("Margin/Content")
  if content != null and not content.has_node("JourneyRow"):
   var journey := HBoxContainer.new()
   journey.name = "JourneyRow"
   journey.add_theme_constant_override("separation",8)
   content.add_child(journey)
   var status: HBoxContainer = content.get_node_or_null("StatusRow")
   for node_name: String in ["WaveBadge","TimerBadge","PauseButton"]:
    var item: Control = status.get_node_or_null(node_name) if status != null else null
    if item != null:
     item.reparent(journey)
     item.size_flags_horizontal = Control.SIZE_EXPAND_FILL if node_name != "PauseButton" else Control.SIZE_SHRINK_END
   var exp: Control = status.get_node_or_null("EXPGroup") if status != null else null
   if exp != null: exp.custom_minimum_size.x = 0
  for label: Label in top.find_children("*","Label",true,false):
   label.custom_minimum_size.x = 0
   label.add_theme_font_size_override("font_size",17 if label.name != "LevelLabel" else 20)
 var boss: PanelContainer = safe.get_node_or_null("BossPanel")
 if boss != null:
  boss.add_theme_stylebox_override("panel",skin("crimson"))
  boss.clip_contents = true
  var bar: ProgressBar = hud.get("boss_hp_bar") as ProgressBar
  if bar != null: bar.add_theme_stylebox_override("fill",skin("crimson",true))
  for label: Label in boss.find_children("*","Label",true,false):
   label.custom_minimum_size.x = 0
   if label.name in ["BossPhaseLabel","BossHPLabel"]:
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    label.max_lines_visible = 1
   else:
    label.max_lines_visible = 2
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
  if not boss.has_meta("ascendant_geometry_bound"):
   boss.set_meta("ascendant_geometry_bound",true)
   var boss_id: int = boss.get_instance_id()
   var safe_id: int = safe.get_instance_id()
   var resize: Callable = func() -> void: boss_layout_by_id.call_deferred(boss_id,safe_id)
   boss.minimum_size_changed.connect(resize)
   safe.resized.connect(resize)
   if top != null: top.resized.connect(resize)
  boss_layout(boss,safe)
  boss_layout_by_id.call_deferred(boss.get_instance_id(),safe.get_instance_id())
static func boss_layout_by_id(boss_id: int,safe_id: int) -> void:
 var boss: Control = instance_from_id(boss_id) as Control
 var safe: Control = instance_from_id(safe_id) as Control
 if boss == null or safe == null or boss.is_queued_for_deletion() or safe.is_queued_for_deletion():return
 boss_layout(boss,safe)
static func boss_layout(boss: Control, safe: Control) -> void:
 var top: Control = safe.get_node_or_null("TopHUD")
 var y: float = top.get_rect().end.y + 10 if top != null else 150
 boss.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 boss.position = Vector2(12,y)
 boss.size.x = maxf(220,safe.size.x-24)
 boss.size.y = maxf(96,boss.get_combined_minimum_size().y)
 boss.pivot_offset = boss.size*0.5
