extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CULT_PERF_FAIL "+message)
func frames(count: int=4) -> void:
 for i: int in range(count):await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.5).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var progression: Node=root.get_node("ProgressionManager")
 var baseline: Dictionary=progression.build_progression_save_data().duplicate(true)
 for width: int in [360,648,900]:
  root.size=Vector2i(width,1152)
  change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await scene_changed
  var screen: Control=current_scene
  check(screen.result_layer==null,"unused result modal stays unbuilt")
  check(screen.body_content.modulate.a==0.0,"entry hides unsettled text")
  var first_visible_rects: Dictionary={}
  for i: int in range(45):
   await process_frame
   if screen.body_content.modulate.a>0.0 and first_visible_rects.is_empty():
    for label: Node in screen.body_content.find_children("*","Label",true,false):
     # Formation owns intentional animated ornaments; text itself stays fixed.
     first_visible_rects[label.get_instance_id()]=label.get_global_rect()
  var stable: bool=true
  for label: Node in screen.body_content.find_children("*","Label",true,false):
   if first_visible_rects.has(label.get_instance_id()) and not label.get_global_rect().is_equal_approx(first_visible_rects[label.get_instance_id()]):stable=false
  check(stable,"visible text never shifts after first reveal")
  var panel: Control=screen.mastery_panel
  var header: Node=panel.body.get_child(0)
  var grids: Array=panel.choice_grids.duplicate()
  check(grids.size()==3,"all mastery choices built before reveal")
  check(screen.body_content.modulate.a==1.0 and screen.body_content.scale==Vector2.ONE,"entry fades at final scale")
  var font_sizes: Array=[]
  for label: Node in panel.find_children("*","Label",true,false):font_sizes.append(label.get_theme_font_size("font_size"))
  # Height-only changes and repeated width breakpoint updates preserve node identities.
  for i: int in range(12):
   panel.size.y+=1;panel.resized.emit()
  await frames()
  check(panel.body.get_child(0)==header,"height resize never reconstructs mastery")
  check(panel.choice_grids==grids,"choices retain identity on resize")
  panel.size.x=420;panel._layout_choices()
  for grid: GridContainer in grids:check(grid.columns==1,"narrow layout updates in place")
  panel.size.x=600;panel._layout_choices()
  for grid: GridContainer in grids:check(grid.columns==2,"wide layout updates in place")
  var sizes_after: Array=[]
  for label: Node in panel.find_children("*","Label",true,false):sizes_after.append(label.get_theme_font_size("font_size"))
  check(font_sizes==sizes_after,"responsive layout never changes mastery font sizes")
  check(panel.body.get_child(0)==header,"width changes never refresh page")
  # Data notifications still refresh and preserve current status.
  panel.status="Performance test status";panel.queue_refresh();await frames()
  check(panel.body.get_child(0)!=header,"actual state refresh remains functional")
  check(panel.body.get_child(panel.body.get_child_count()-1).text==panel.status,"status refresh is current")
  screen._show_result("vitality",1,2,10,100,90);await frames(60)
  var modal: Control=screen.result_layer
  check(modal!=null and modal.visible and modal.modulate.a==1.0,"first lazy modal settles and reveals")
  check(screen.result_panel.size.x<=root.size.x-20 and screen.result_panel.position.x>=0,"modal remains inside phone width")
  screen._hide_result();await frames(40)
  check(not modal.visible,"lazy modal closes")
  screen._show_result("sword_power",2,3,20,90,70);await frames(60)
  check(screen.result_layer==modal and modal.visible,"later result reuses modal without rebuilding")
  check(progression.build_progression_save_data()==baseline,"presentation cannot mutate economy or upgrades")
 var warm: Node=root.get_node("MenuResourcePrewarm")
 check("res://scenes/ui/cultivation_menu.tscn" in warm.FAST_NAV_SCENES,"cultivation participates in retained prewarm")
 # Leave during pending intro: no detached coroutine or stale refresh can reach the next page.
 change_scene_to_file("res://scenes/ui/cultivation_menu.tscn");await scene_changed
 current_scene._show_result("vitality",1,2,10,100,90)
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(12)
 check(current_scene.scene_file_path.ends_with("main_menu.tscn"),"rapid departure keeps destination page")
 await create_timer(4).timeout
 print("CULTIVATION_PERFORMANCE_SMOKE checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
