extends SceneTree
const Catalog=preload("res://scripts/data/skill_catalog.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,why: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("INTERFACE_CONSISTENCY "+why)
func frames(n: int=12) -> void:
 for i: int in n:await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(90).timeout.connect(func():quit(1))
 await frames()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var cfg:=ConfigFile.new();cfg.set_value("meta","version",2)
 for id: String in ["home","equipment","pavilion"]:cfg.set_value("tutorials",id,true)
 cfg.save("user://jade_onboarding.cfg")
 root.get_node("RefineOnboarding").completed=true
 root.get_node("RefineOnboarding").set_process(false)
 root.get_node("SettingsManager").reduced_effects=true
 for id: String in Catalog.UPGRADE_IDS:
  check(ResourceLoader.exists(Catalog.get_icon_path(id)),"catalog art exists "+id)
 for arm: String in ["jade_binding_chain","celestial_returning_glaive","heavenweaver_compass"]:
  check(Catalog.get_icon_path("spirit_sword",arm)!=Catalog.get_icon_path("sword_dao_resonance",arm),"resonance is distinct from equipped weapon "+arm)
 var resonance: Texture2D=load(Catalog.get_icon_path("sword_dao_resonance"))
 var pixels: Image=resonance.get_image()
 check(pixels.get_pixel(0,0).a==0,"new resonance art has transparent corner")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=dims;await frames()
  var expected: Rect2
  var label_sizes: Array[int]=[]
  for name: String in ["cultivation_menu","equipment_screen","daily_quest_screen","pavilion_screen","main_menu"]:
   change_scene_to_file("res://scenes/ui/"+name+".tscn");await frames(28)
   var nav: Control=current_scene.find_child("HubNav",true,false)
   check(nav!=null,"shared navigation exists "+name)
   if nav==null:continue
   var rect: Rect2=nav.get_global_rect()
   check(is_equal_approx(rect.size.y,88),"same88px navigation height "+name+str(dims))
   if expected.size==Vector2.ZERO:expected=rect
   check(rect.is_equal_approx(expected),"same safe-area navigation bounds "+name+str(dims))
   var sizes: Array[int]=[]
   for label: Label in nav.tab_labels:sizes.append(label.get_theme_font_size("font_size"))
   if label_sizes.is_empty():label_sizes=sizes
   check(sizes==label_sizes,"same navigation label sizes "+name+str(dims))
   if name=="main_menu":
    var label: Label=current_scene.find_child("FeaturedTitle",true,false)
    var tag: Label=current_scene.find_child("EventKind",true,false)
    check(label.get_theme_font_size("font_size")>=21,"event title readable on phone")
    check(tag.get_theme_font_size("font_size")>=14,"event category readable on phone")
    check(label.get_parent().get_global_rect().encloses(label.get_global_rect()),"event title inside its frame")
    var capture: String=OS.get_environment("JADE_INTERFACE_CAPTURE_DIR")
    if not capture.is_empty() and DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(capture+"/home-"+str(dims.x)+".png")
   if name=="equipment_screen":
    var capture: String=OS.get_environment("JADE_INTERFACE_CAPTURE_DIR")
    if not capture.is_empty() and DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(capture+"/hero-"+str(dims.x)+".png")
 if current_scene!=null:current_scene.queue_free()
 await frames()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("INTERFACE_CONSISTENCY checks=",checks," failures=",failures)
 quit(1 if failures else 0)
