extends RefCounted
## One safe coordinate space and one visual language for pre-warning/arrival.
const MODAL_Z: int=200
const SERIF: Font=preload("res://assets/ui/library/fonts/archive_serif.ttf")
const Profiles=preload("res://scripts/data/boss_premium_catalog.gd")
static func fit(panel: Control,safe_area: Control) -> void:
 if not is_instance_valid(panel) or not is_instance_valid(safe_area):return
 var width: float=maxf(220,minf(560,safe_area.size.x-28))
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 panel.custom_minimum_size=Vector2.ZERO
 panel.clip_contents=true
 for label: Label in panel.find_children("*","Label",true,false):
  label.custom_minimum_size.x=0
  label.max_lines_visible=2 if label.name in ["NoticeBossName","NoticeWarningTitle"] else 1
  label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var top: float=18
 for node_name: String in ["TopHUD","BossPanel"]:
  var strip: Control=safe_area.get_node_or_null(node_name)
  if strip!=null and strip!=panel and strip.visible:top=maxf(top,strip.get_rect().end.y+12)
 var height: float=(154 if width<340 else 138) if panel.name=="BossPreWarning" else (142 if width<340 else 126)
 panel.size=Vector2(width,height)
 panel.position=Vector2((safe_area.size.x-width)*.5,minf(top,maxf(0,safe_area.size.y-height-20)))
 panel.pivot_offset=panel.size*.5
static func settle(panel: Control,safe_area: Control) -> void:fit(panel,safe_area)

class Crest extends Control:
 const SEAL: Texture2D=preload("res://assets/ui/wuxia/stage_boss.png")
 var portrait: Texture2D
 func _ready() -> void:
  mouse_filter=Control.MOUSE_FILTER_IGNORE
  resized.connect(queue_redraw)
 func _draw() -> void:
  var side: float=68 if size.x<340 else 80
  var box:=Rect2(12,(size.y-side)*.5,side,side)
  draw_texture_rect(SEAL,box,false,Color(1,.87,.67))
  if portrait!=null:
   var inner:=box.grow(-11)
   draw_texture_rect(portrait,inner,false)

static func decorate(panel: Control,accent: Color,boss_name: String="") -> void:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color(.035,.018,.027,.97) if panel.name=="BossPreWarning" else Color(.008,.035,.039,.97)
 style.border_color=Color(accent,.45);style.set_border_width_all(1);style.set_corner_radius_all(12)
 style.shadow_color=Color(.01,.005,.005,.22);style.shadow_size=5
 style.content_margin_left=0;style.content_margin_right=0;style.content_margin_top=0;style.content_margin_bottom=0
 panel.add_theme_stylebox_override("panel",style)
 var margin: MarginContainer=panel.get_child(0) as MarginContainer
 if margin!=null:
  margin.add_theme_constant_override("margin_left",92 if panel.get_parent().size.x<380 else 108)
  margin.add_theme_constant_override("margin_right",22)
  margin.add_theme_constant_override("margin_top",14)
  margin.add_theme_constant_override("margin_bottom",14)
 for label: Label in panel.find_children("*","Label",true,false):
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
  if label.name in ["NoticeBossName","NoticeWarningTitle"]:
   label.add_theme_font_override("font",SERIF)
   label.add_theme_font_size_override("font_size",21 if panel.get_parent().size.x<380 else 24)
   label.add_theme_color_override("font_color",Color(1,.93,.76))
  else:label.add_theme_font_size_override("font_size",11)
 # Keep existing labels/reveal lifecycle. Only decorative prototype chips and
 # redundant separator rules are hidden; no extra timer or input router.
 if panel.name=="BossPreWarning" and margin!=null:
  var row: HBoxContainer=margin.get_child(0) as HBoxContainer
  if row!=null:
   row.get_child(0).visible=false;row.get_child(2).visible=false
 for node: Node in panel.find_children("*","ColorRect",true,false):
  if node.name in ["LineLeft","LineRight"] or panel.name=="EncounterBanner":node.visible=false
 var frame: Control=panel.get_node_or_null("CeremonialFrame")
 if frame==null:
  frame=preload("res://scripts/ui/home_sanctuary_art.gd").frame(panel,true)
  frame.name="CeremonialFrame";frame.self_modulate=Color(1,.88,.69)
 var crest: Crest=panel.get_node_or_null("BossCrest") as Crest
 if crest==null:crest=Crest.new();crest.name="BossCrest";panel.add_child(crest)
 var profile: Dictionary=Profiles.get_profile(boss_name)
 if not profile.is_empty() and str(crest.get_meta("portrait_name",""))!=boss_name:
  var atlas: Texture2D=load("res://assets/enemy/boss_2d/atlas_%d_%d.png"%[int(profile.chapter),int(profile.stage)])
  if atlas!=null:
   var cell:=Rect2i(0,int(atlas.get_height()/6.0),int(atlas.get_width()/6.0),int(atlas.get_height()/6.0))
   var occupied: Rect2i=atlas.get_image().get_region(cell).get_used_rect()
   var crop_width: float=maxf(1,minf(float(occupied.size.x)*.72,float(occupied.size.y)*.56))
   var crop_height: float=crop_width
   var portrait:=AtlasTexture.new();portrait.atlas=atlas
   portrait.region=Rect2(occupied.position.x+(occupied.size.x-crop_width)*.5,cell.position.y+occupied.position.y,crop_width,crop_height)
   portrait.filter_clip=true;crest.portrait=portrait;crest.set_meta("portrait_name",boss_name)
   crest.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR

 crest.queue_redraw()
