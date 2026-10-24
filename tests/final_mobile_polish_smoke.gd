extends SceneTree
const EventArt=preload("res://scripts/ui/liveops/event_identity_catalog.gd")
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FINAL_MOBILE_FAIL "+label)
func frames(count: int=5) -> void:
 for frame: int in count:await process_frame
func capture(name_value: String) -> void:
 if DisplayServer.get_name()=="headless" or OS.get_environment("JADE_FINAL_CAPTURE").is_empty():return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("JADE_FINAL_CAPTURE")+"/"+name_value+".png")
func mouse(at: Vector2,down: bool) -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;event.position=at;root.push_input(event,true)
func swipe(at: Vector2,distance: float) -> void:
 mouse(at,true);await frames(1)
 for i: int in range(1,9):
  var event:=InputEventMouseMotion.new();event.position=at+Vector2(0,-distance*i/8.0);event.relative=Vector2(0,-distance/8.0);event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true);await frames(1)
 mouse(at+Vector2(0,-distance),false);await frames(6)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 await frames(8)
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 var prewarm: Node=root.get_node_or_null("MenuResourcePrewarm")
 if prewarm!=null:prewarm.free()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var config:=ConfigFile.new();config.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:config.set_value("tutorials",key,true)
 config.save("user://jade_onboarding.cfg");root.get_node("RefineOnboarding").completed=true
 var ops: Node=root.get_node("LiveOpsManager");ops.set_process(false)
 var progression: Node=root.get_node("ProgressionManager");var before: int=progression.spirit_stone
 if "--restart-mail" in OS.get_cmdline_user_args():
  check("liveops:mail:claim:welcome_initiate" in ops._get_ledger(),"historical marker survives actual process restart")
  check(ops.get_mail_ids().is_empty() and ops.MAIL_ORDER.is_empty(),"restart does not recreate automatic mail")
  check(not ops.claim_mail("welcome_initiate") and progression.spirit_stone==before,"restart cannot claim retired grant")
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  print("FINAL_MOBILE_RESTART checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1);return
 check(ops.MAIL_ORDER.is_empty() and ops.MAIL_CATALOG.is_empty(),"local automatic mail retired")
 check(ops.get_mail_ids().is_empty() and not ops.claim_mail("welcome_initiate"),"retired welcome cannot manufacture currency")
 check(progression.spirit_stone==before,"retirement leaves existing balance untouched")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(720,1600)]:
  root.size=dims;change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(18)
  var home: Node=current_scene;var p: Node=home.get_node("HomeUI/HomeProductionOverlay");p.set_process(false)
  p.realm_title.text="CRIMSON MOON SECT";p.journey_button.text="CONTINUE RUN ›";p.continue_button.show();p._layout_sanctuary();await frames(6)
  var primary: Rect2=p.journey_button.get_rect();var chapters: Rect2=p.continue_button.get_rect()
  check(primary.size.y>=44 and primary.size.y<=maxf(62,dims.x*.09),"compact primary target remains tappable "+str(dims))
  if dims.x>=560:
   check(chapters.position.y-primary.end.y>=6 and chapters.position.y-primary.end.y<=14,"Continue/Chapters grouped with short gap "+str(dims))
  else:check(not primary.intersects(chapters),"compact horizontal actions do not overlap")
  var heading: Control=p.lower_stack.get_node("EventsHeading")
  var gap: float=p.event_card.position.y-(heading.position.y+heading.size.y)
  check(gap>=0 and gap<=8,"event heading and banner stay close "+str(dims))
  check(p.all_events_button.size.y<=heading.size.y+1,"All Events frame stays inside compact heading")
  var nav: Control=home.get_node("HomeUI/HubNav")
  for index: int in range(5):
   check(not nav.tab_labels[index].visible and nav.tab_labels[index].text.is_empty(),"icon-only tab "+str(index))
   check(absf(nav.tab_icons[index].get_rect().get_center().y-nav.size.y*.5)<1,"nav icon centered")
   check(not nav.tab_buttons[index].accessibility_name.is_empty() and nav.tab_buttons[index].size.y>=44,"nav keeps meaning and touch target")
  if dims.x in [390,720]:await capture("home-continue-"+str(dims.x))
  if dims.x==320:
   var previous: int=p.lower_scroll.scroll_vertical
   await swipe(p.journey_button.get_global_rect().get_center(),120)
   check(p.lower_scroll.scroll_vertical>previous and current_scene==home,"first Home swipe scrolls without navigation")
 # Actual production event pages, with both focused and compact route entries.
 for scene: String in ["celestial_treasure_hunt_screen","path_of_five_elements_screen"]:
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(720,1600)]:
   root.size=dims
   ops.open_live_popup("res://scenes/ui/"+scene+".tscn");await frames(18)
   var page: Control=ops._active_live_popup
   var markers: int=0
   for control: Node in page.find_children("*","Label",true,false):
    var label: Label=control as Label
    if bool(label.get_meta("jade_keep_inline",false)):
     markers+=1
     check(label.autowrap_mode==TextServer.AUTOWRAP_OFF and label.get_line_count()<=1,"route marker remains horizontal "+label.text)
     check(label.size.x+1>=label.get_minimum_size().x,"inline label receives reserved width")
   check(markers>=5,"event uses shared marker/badge rule "+scene)
   var scrolls: Array[Node]=page.find_children("*","ScrollContainer",true,false)
   check(not scrolls.is_empty(),"event content remains scrollable")
   if not scrolls.is_empty():
    var scroll: ScrollContainer=scrolls.back() as ScrollContainer
    var initial: int=scroll.scroll_vertical
    var overflow: bool=scroll.get_v_scroll_bar().max_value>scroll.get_v_scroll_bar().page+1
    var origin: Vector2=scroll.get_global_rect().get_center()
    if dims.x in [390,720]:await capture(scene+"-"+str(dims.x))
    await swipe(origin,150)
    check(scroll.scroll_vertical>initial if overflow else scroll.scroll_vertical==initial,"event first swipe respects actual overflow "+scene+str(dims))
   ops.close_live_popup();await frames(3)
 # Test auth-independent legacy markers survive without recreating their mail.
 var ledger: Array[String]=ops._get_ledger().duplicate()
 ledger.append("liveops:mail:claim:welcome_initiate")
 check(ops._commit_ledger(ledger),"historical claim marker remains persistable")
 check("liveops:mail:claim:welcome_initiate" in ops._get_ledger() and ops.get_mail_ids().is_empty(),"historical reward stays recorded without synthetic inbox")
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("FINAL_MOBILE_POLISH checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
