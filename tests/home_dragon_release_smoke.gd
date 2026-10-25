extends SceneTree
var Cast: Script
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("HOME_DRAGON_RELEASE "+message)
func frames(count: int=5) -> void:
 for frame: int in count:await process_frame
func capture(file_name: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("JADE_HOME_DRAGON_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("JADE_HOME_DRAGON_CAPTURE")+"/"+file_name+".png")
func label_fits(label: Label) -> bool:
 var font: Font=label.get_theme_font("font")
 var pixels: int=label.get_theme_font_size("font_size")
 var lines: int=label.get_line_count()
 if lines>maxi(1,label.max_lines_visible) and label.max_lines_visible>0:return false
 if font.get_height(pixels)*lines>label.size.y+2:return false
 if label.autowrap_mode==TextServer.AUTOWRAP_OFF:return font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x<=label.size.x+1
 return true
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(90).timeout.connect(func():push_error("HOME_DRAGON_TIMEOUT");quit(1))
 await frames(8)
 Cast=load("res://scripts/weapon/heavenweaver_compass_cast.gd")
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.free()
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg");root.get_node("RefineOnboarding").completed=true
 var journey: Node=root.get_node("JourneyManager")
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):journey.unlocked_stage_keys.append(journey.get_stage_key(chapter,stage))
 journey.selected_chapter_id=2;journey.selected_stage_id=1
 var save: Node=root.get_node("SaveManager")
 var saved: Dictionary={"version":1,"chapter_id":2,"stage_id":1,"survival_time":45.0,"wave":2,"wave_timer":3.0,"difficulty_level":1,"player_level":2,"experience":5,"experience_to_next_level":10}
 check(save.write_save_data("checkpoint",saved).success,"isolated saved run")
 root.size=Vector2i(720,1600);change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(22)
 var p: Node=current_scene.get_node("HomeUI/HomeProductionOverlay");p.set_process(false)
 var progression: Node=root.get_node("ProgressionManager")
 var pavilion: Node=root.get_node("PavilionManager")
 var inventory: Node=root.get_node("InventoryManager")
 var before: Array=[progression.spirit_stone,pavilion.get_celestial_jade(),inventory.item_counts.duplicate(true),save.read_save_data("checkpoint").data.duplicate(true)]
 for language: String in ["en","id"]:
  root.get_node("SettingsManager").language=language;TranslationServer.set_locale(language)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600),Vector2i(896,504)]:
   root.size=dims;await frames(9);p._refresh_journey();p._layout_sanctuary();await frames(3)
   check(p._goal.action=="continue" and p.journey_button.text==("LANJUT ›" if language=="id" else "CONTINUE ›"),"short Continue preserves saved-run destination")
   check(p.chapter_label.text.contains("2-1") and not p.next_path_label.visible and not p.goal_hint.visible,"stage retained once; no repeated paragraph")
   check(p.continue_button.visible and p.journey_button.size.y>=44 and p.continue_button.size.y>=44,"chapters remain available with touch targets")
   check(not p.journey_button.get_rect().intersects(p.continue_button.get_rect()),"separate Continue/Chapters actions")
   for chapter: int in journey.get_chapter_ids():
    p.realm_title.text=tr(str(journey.get_chapter_data(chapter).get("display_name","")));p._fit_realm_copy()
    check(label_fits(p.realm_title),"actual realm name fits "+str(chapter)+language+str(dims))
   p._refresh_journey()
   for key: String in ["heavenly_trials","boss_hunt","pilgrimage","heavenly_ladder","treasure_hunt","five_elements","odyssey"]:
    p._apply_feature(key,"",{"current":3,"total":3},1,2);await frames(1)
    check(p.event_card.get_node("EventKind").text=="EVENT 1/2","one short event index")
    for label: Label in [p.event_card.get_node("FeaturedTitle"),p.event_card.get_node("EventKind"),p.boss_progress,p.event_action]:
     check(Rect2(Vector2.ZERO,p.event_card.size).grow(-12).encloses(label.get_rect()),"event text stays inside painted frame "+label.name)
     check(label_fits(label),"event copy fully readable "+key+" "+label.name+str(dims)+language)
   var client: Node=root.get_node("OdysseyClient")
   var old_snapshot: Dictionary=client.snapshot.duplicate(true)
   var now: int=client.server_time()
   client.snapshot={"server_time":now,"event":{"enabled":true,"starts_at":now-60,"ends_at":now+3600},"state":{"day":Time.get_datetime_string_from_unix_time(now).substr(0,10),"daily_rolls":1,"missions":[]}}
   p._apply_feature("odyssey","",{"current":1,"total":12},1,2)
   check(p.feature_dot.visible and p.event_action.text==("AMBIL ›" if language=="id" else "CLAIM ›"),"actual earned mission makes short Claim action")
   check(label_fits(p.boss_reward) and label_fits(p.event_action),"earned state fits without hiding reward meaning")
   if dims.x in [390,720]:await capture("home-claim-"+language+"-"+str(dims.x))
   client.snapshot=old_snapshot
   check(label_fits(p.chapter_label),"chapter identity fits")
   if dims.x in [390,720]:await capture("home-"+language+"-"+str(dims.x))
 check([progression.spirit_stone,pavilion.get_celestial_jade(),inventory.item_counts,save.read_save_data("checkpoint").data]==before,"copy/layout reads never change economy or saved run")
 # Source image is one continuous painting; render a shared mesh edge for the
 # whole neck rather than testing that two cropped pictures merely overlap.
 current_scene.queue_free();current_scene=null;await frames(5)
 root.size=Vector2i(648,480);await frames(5)
 var world:=Node2D.new();root.add_child(world)
 var background:=Sprite2D.new();background.texture=load("res://assets/world/boss_arena/jade_ritual_dais.png");background.position=Vector2(324,240);background.scale=Vector2.ONE*.7;world.add_child(background)
 var courier: Node2D=Cast.new();world.add_child(courier);courier.set_physics_process(false);courier._resize_heads(2,Vector2.ZERO)
 for reduced: bool in [false,true]:
  root.get_node("SettingsManager").reduced_effects=reduced
  for step: int in 120:
   courier.age+=1.0/60.0
   for index: int in courier.heads.size():
    var head: Dictionary=courier.heads[index]
    head.point=Vector2(290+sin(step*.04)*80,180+index*140)
    head.angle=sin(step*.055)*2.7
    courier._update_dragon(head,1.0/60.0,index)
    if step in [0,30,60,90,119]:
     var arrays: Array=head.mesh.mesh.surface_get_arrays(0)
     var vertices: PackedVector2Array=arrays[Mesh.ARRAY_VERTEX]
     var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
     var triangles: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
     check(courier.get_child_count()==2 and not head.has("face"),"one mesh per dragon; no cropped head sprite")
     check(uv[0].x==1.0 and uv[uv.size()-1].x==0.0,"full painting including face and tail")
     check(vertices.size()==(head.spine.size()+2)*2,"bounded shared-edge strip")
     check(is_equal_approx(uv[4].x,courier.DRAGON_NECK_U),"body and face meet at exact source neck")
     check(triangles.size()==(head.spine.size()+1)*6,"no missing triangles at neck")
     check(vertices[4].distance_to(vertices[5])>54.0 and vertices[4].distance_to(vertices[5])<54.5,"neck has the same painted width")
     for i: int in range(2,uv.size(),2):check(uv[i].x<uv[i-2].x and vertices[i].is_finite(),"finite ordered strip without UV reset")
   if step in [30,60,90] and not reduced:await capture("dragon-turn-"+str(step))
 world.free();await frames(5)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("HOME_DRAGON_RELEASE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
