extends SceneTree
## Native input and responsive regression; all data belongs to a disposable fixture.
var checks: int=0
var failures: int=0
func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("RELEASE_UI "+message)
func frames(count: int=5) -> void:
 for i: int in range(count):await process_frame
func _initialize() -> void:run.call_deferred()
func tap(point: Vector2) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.pressed=true;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await frames(1)
 e.pressed=false;e.button_mask=0;root.push_input(e,true);await frames()
func swipe(point: Vector2,distance: float=-100.0) -> void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.pressed=true;e.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(e,true);await frames(1)
 for i: int in range(1,9):
  var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(0,distance)*float(i)/8;motion.relative=Vector2(0,distance/8);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true);await frames(1)
 e.pressed=false;e.button_mask=0;e.position=point+Vector2(0,distance);root.push_input(e,true);await frames()
func fits(button: Button) -> bool:
 return button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x<=button.size.x-button.get_theme_stylebox("normal").get_minimum_size().x+1
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_release_ui_qa"):quit(2);return
 create_timer(100).timeout.connect(func():quit(1))
 await frames(10)
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 var prefs: Node=root.get_node("SettingsManager")
 prefs.reduced_effects=true
 var onboarding:=ConfigFile.new();onboarding.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:onboarding.set_value("tutorials",key,true)
 onboarding.save("user://jade_onboarding.cfg")
 var guide: Node=root.get_node_or_null("RefineOnboarding")
 if guide!=null:guide.completed=true;guide.set_process(false)
 var save: Node=root.get_node("SaveManager")
 var before: Array=[root.get_node("InventoryManager").item_counts.duplicate(),root.get_node("PavilionManager").get_local_celestial_jade(),root.get_node("ProgressionManager").spirit_stone]
 for language: String in ["en","id"]:
  prefs.language=language
  change_scene_to_file("res://scenes/ui/settings_screen.tscn");await frames(20)
  var settings: Node=current_scene
  var scroll: ScrollContainer=settings._settings_scroll
  var toggle: Button=settings.find_child("AccountRecoveryToggle",true,false)
  var tools: Control=settings.find_child("AccountRecoveryTools",true,false)
  check(not tools.visible,"recovery controls start collapsed")
  for size: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
   root.size=size;await frames(12)
   if not tools.visible:
    scroll.ensure_control_visible(toggle);await frames()
    await tap(toggle.get_global_rect().get_center())
   check(tools.visible,"native release opens recovery settings "+str(size)+language)
   scroll.ensure_control_visible(settings._backup_save);await frames()
   var button: Button=settings._backup_save
   check(button.size.x>=150 and button.size.y>=48 and fits(button),"complete backup label and target "+str(size)+language)
   check(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()),"backup action inside visible reader")
   check(fits(settings._backup_restore),"restore label fully fits")
   var offset: int=scroll.scroll_vertical
   var remaining: float=scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page-offset
   await swipe(button.get_global_rect().get_center(),-100 if remaining>120 else 100)
   print("RELEASE_SCROLL size=",size," before=",offset," after=",scroll.scroll_vertical," max=",scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page)
   check(absi(scroll.scroll_vertical-offset)>20,"first swipe from actual cloud action scrolls")
   check(settings.find_children("*","ConfirmationDialog",true,false).is_empty(),"swipe never opens save confirmation")
   check(scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"hidden scrollbar keeps scrolling enabled")
 # Home uses one contextual primary action and actual saved checkpoint identity.
 var journey: Node=root.get_node("JourneyManager")
 journey.unlocked_stage_keys=["1-1","1-2","1-3"];journey.cleared_stage_keys=["1-1","1-3"]
 var checkpoint: Dictionary={"version":1,"chapter_id":1,"stage_id":2,"survival_time":45.0,"wave":2,"wave_timer":3.0,"difficulty_level":1,"player_level":2,"experience":5,"experience_to_next_level":10}
 check(save.write_save_data("checkpoint",checkpoint).success,"isolated real checkpoint committed")
 prefs.language="en";change_scene_to_file("res://scenes/ui/main_menu.tscn");await frames(20)
 var home: Node=current_scene;var presenter: Node=home.get_node("HomeUI/HomeProductionOverlay")
 for size: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  root.size=size;await frames(12)
  check(presenter._goal.action=="continue" and presenter.next_path_label.text.contains("1-2") and fits(presenter.journey_button),"saved stage Continue is readable "+str(size))
  presenter.lower_scroll.scroll_vertical=0;await frames()
  var area: Rect2=presenter.journey_button.get_global_rect().intersection(presenter.lower_scroll.get_global_rect())
  check(area.size.y>=30,"primary action initially reachable")
  var room: float=presenter.lower_scroll.get_v_scroll_bar().max_value-presenter.lower_scroll.get_v_scroll_bar().page
  await swipe(area.get_center())
  print("HOME_SWIPE size=",size," room=",room," after=",presenter.lower_scroll.scroll_vertical," area=",area," room_after=",presenter.lower_scroll.get_v_scroll_bar().max_value-presenter.lower_scroll.get_v_scroll_bar().page," scroll_rect=",presenter.lower_scroll.get_global_rect())
  # Input can settle deferred minimum sizes. Require a real first swipe for
  # the effective range; when content fits, verify every panel is contained.
  var actual_room: float=presenter.lower_scroll.get_v_scroll_bar().max_value-presenter.lower_scroll.get_v_scroll_bar().page
  if actual_room>1:check(presenter.lower_scroll.scroll_vertical>=minf(20,actual_room-1),"primary card swipe actually scrolls on compact screen")
  else:
   # Hidden panels can retain an old allocated VBox rectangle. Inspect the
   # visible panels, not unused container space from the previous resolution.
   for panel: Control in presenter.lower_stack.get_children():
    if panel.is_visible_in_tree():check(presenter.lower_scroll.get_global_rect().grow(1).encloses(panel.get_global_rect()),"visible Home panel fits "+panel.name+str(size)+str(panel.get_global_rect()))
  check(current_scene==home and not root.get_node("SceneTransitionManager").is_transitioning,"first primary-button swipe never starts run")
 checkpoint.defeat_pending=true;save.write_save_data("checkpoint",checkpoint);await frames(10)
 check(presenter._goal.action=="journey" and presenter._goal.stage==2,"ended run yields to next available stage")
 save._transaction_fault=true;presenter._refresh_all();await frames()
 check(presenter._goal.action=="recovery" and presenter._goal.button=="OPEN SETTINGS" and presenter.journey_button.text=="REVIEW SAVE ›" and not presenter.continue_button.visible,"short recovery caption still routes to Settings and blocks Continue/stage start")
 save._transaction_fault=false
 # All journal modes use the shared scroll reader; inspect actual compact cards.
 change_scene_to_file("res://scenes/ui/skill_book_screen.tscn");await frames(15)
 var library: Node=current_scene
 var journal: GDScript=load("res://scripts/companion/player_journal.gd")
 root.size=Vector2i(320,568);await frames()
 for page: String in ["tools","presets","goal","bosses","runs","summons","agenda"]:
  var sheet: Control=journal.open(library,page);await frames(10)
  check(Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(sheet._panel.get_global_rect()),"compact journal frame "+page)
  check(sheet._scroll.size.y>=120,"usable journal reader "+page)
  check(sheet._heading.get_line_count()<=2,"journal heading never breaks into a vertical letter stack "+page)
  for action: Button in sheet._body.find_children("*","Button",true,false):
   if page=="presets":check(fits(action),"complete compact preset action")
  check(journal.open(library,page)==sheet,"journal tap spam reuses owned sheet")
  if page=="goal":
   var button: Button=sheet._body.get_children().filter(func(n: Node):return n is Button)[0]
   var before_goal: String=root.get_node("PlayerCompanion").state.goal
   await swipe(button.get_global_rect().get_center())
   check(sheet._scroll.scroll_vertical>20 and root.get_node("PlayerCompanion").state.goal==before_goal,"native goal-button swipe scrolls without selecting")
  sheet.close();await frames()
 change_scene_to_file("res://scenes/ui/training_ground.tscn");await frames(15)
 var practice: Node=current_scene
 for size: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=size;await frames(12)
  check(Rect2(Vector2.ZERO,Vector2(size)).grow(1).encloses(practice._panel.get_global_rect()),"training controls fit "+str(size))
  check(practice._skills.size.x<=practice._panel.size.x and practice._levels.size.y>=44,"training dropdown fits without prototype clipping")
  check(practice._joystick.get_global_rect().position.y>=practice._panel.get_global_rect().end.y,"joystick cannot capture training controls")
 # Queued Hero work must stop when the owning page is detached.
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await frames(20)
 var hero: Node=current_scene;var count: int=hero._build_count
 hero._queue_refresh();current_scene=null;root.remove_child(hero);await frames(10)
 check(hero._build_count==count,"detached Hero does not rebuild or resolve absolute nodes")
 hero.queue_free();await frames()
 check(before==[root.get_node("InventoryManager").item_counts,root.get_node("PavilionManager").get_local_celestial_jade(),root.get_node("ProgressionManager").spirit_stone],"layout and native swipes neither buy nor grant goods")
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("RELEASE_UI checks=",checks," failures=",failures)
 quit(1 if failures else 0)
