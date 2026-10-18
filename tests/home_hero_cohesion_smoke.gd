extends SceneTree
var checks: int=0
var failures: int=0
var activations: int=0
func _initialize() -> void:
 _run.call_deferred()
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error('HOME_HERO_COHESION '+label)
func frames(count: int=6) -> void:
 for index: int in range(count):await process_frame
func inside(inner: Rect2,outer: Rect2) -> bool:
 return outer.grow(1).encloses(inner)
func activated() -> void:activations+=1
func effective_z(item: CanvasItem) -> int:
 var total: int=0
 var current: Node=item
 while current is CanvasItem:
  total+=(current as CanvasItem).z_index
  if not (current as CanvasItem).z_as_relative:break
  current=current.get_parent()
 return total
func capture(file: String) -> void:
 if DisplayServer.get_name()=='headless':return
 await RenderingServer.frame_post_draw
 var folder: String=OS.get_environment('JADE_COHESION_RENDER_DIR')
 if folder.is_empty():return
 DirAccess.make_dir_recursive_absolute(folder)
 root.get_texture().get_image().save_png(folder+'/'+file)
func _run() -> void:
 if not OS.get_user_data_dir().contains('jade_ui_cohesion_qa'):quit(2);return
 create_timer(80).timeout.connect(func():push_error('COHESION_WATCHDOG');quit(3))
 await frames(3)
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var config:=ConfigFile.new();config.set_value('meta','version',2)
 for key: String in ['home','equipment','pavilion']:config.set_value('tutorials',key,true)
 config.save('user://jade_onboarding.cfg')
 var guide: Node=root.get_node('RefineOnboarding');guide.completed=true;guide.set_process(false)
 var prewarm: Node=root.get_node_or_null('MenuResourcePrewarm')
 if prewarm!=null:prewarm.queue_free()
 var journey: Node=root.get_node('JourneyManager')
 var equipment: Node=root.get_node('EquipmentManager')
 var inventory: Node=root.get_node('InventoryManager')
 var progression: Node=root.get_node('ProgressionManager')
 var pavilion: Node=root.get_node('PavilionManager')
 var before: Array=[progression.spirit_stone,pavilion.get_celestial_jade(),inventory.item_counts.duplicate(true)]
 change_scene_to_file('res://scenes/ui/main_menu.tscn');await frames(14)
 var presenter: Node=current_scene.get_node('HomeUI/HomeProductionOverlay')
 for viewport: Vector2i in [Vector2i(648,1152),Vector2i(390,844),Vector2i(320,568),Vector2i(896,504)]:
  root.size=viewport;await frames(9)
  var profile_rect: Rect2=Rect2(Vector2.ZERO,presenter.profile_shortcut.size)
  for text: Control in [presenter.profile_name,presenter.profile_rank,presenter.profile_status,presenter.profile_exp]:
   check(inside(text.get_rect(),profile_rect),'profile child contained '+str(viewport)+' '+str(text.name))
  check(not presenter.profile_shortcut.get_rect().intersects(presenter.mailbox_button.get_rect()),'profile/mail separated')
  check(not presenter.mailbox_button.get_rect().intersects(presenter.settings_shortcut.get_rect()),'mail/settings separated')
  check(presenter.mailbox_button.size.x>=56 and presenter.settings_shortcut.size.x>=56,'larger header hit targets')
  check(presenter.all_events_button.size.x>=125 and presenter.all_events_button.size.y>=56,'All Events substantial hit target')
  check(presenter.all_events_button.text.contains('EVENTS'),'All Events explicit label')
  for window: Panel in [presenter.realm_window,presenter.event_window]:
   check(inside(window.get_rect(),Rect2(Vector2.ZERO,window.get_parent().size)),'art aperture remains inside frame')
   var glass: Control=window.get_parent().get_node('SanctuaryGlass')
   check(window.position.x>=9 and window.position.y>=9 and inside(glass.get_rect(),Rect2(Vector2.ZERO,window.get_parent().size)),'art and fill have contained safe insets')
   check(window.clip_children==CanvasItem.CLIP_CHILDREN_ONLY and window.clip_contents,'rounded and rectangular clipping')
  check(presenter.journey_card.get_node('SanctuaryFrame').get_index()>presenter.realm_window.get_index(),'frame above realm art')
  presenter._capture_press(presenter.all_events_button)
  var drag:=InputEventScreenDrag.new();drag.relative=Vector2(24,0)
  presenter._track_gesture(drag,presenter.all_events_button)
  var count: int=activations
  presenter._activate(Callable(self,'activated'),presenter.all_events_button)
  check(activations==count,'scroll cannot activate All Events')
  presenter._capture_press(presenter.all_events_button)
  presenter._activate(Callable(self,'activated'),presenter.all_events_button)
  check(activations==count+1,'tap still activates All Events')
 root.size=Vector2i(648,1152);await frames()
 for chapter: int in [1,3,5]:
  journey.selected_chapter_id=chapter;presenter._refresh_journey();await frames(2)
  check(presenter.realm_vista.texture.resource_path.ends_with('realm_%02d.png'%chapter),'actual selected realm art '+str(chapter))
 await capture('home-polished.png')
 check([progression.spirit_stone,pavilion.get_celestial_jade(),inventory.item_counts]==before,'Home presentation does not alter economy')
 inventory.item_counts['wanderer_jade_jian']=3
 inventory.item_counts['bamboo_weave_robe']=3
 progression.spirit_stone=100000
 equipment.active_run_loadout_snapshot.clear()
 var counts: Dictionary=inventory.item_counts.duplicate(true)
 var stones: int=progression.spirit_stone
 change_scene_to_file('res://scenes/ui/equipment_screen.tscn');await frames(14)
 var hero: Node=current_scene
 check(not hero.card_buttons.is_empty(),'real backpack built')
 for card: Button in hero.card_buttons.values():check(card.get_node_or_null('DuplicateCount')==null,'equipment multiplicity badge removed')
 var sword: Button=hero.card_buttons['wanderer_jade_jian']
 var dot: Panel=sword.get_node('RefineReadyDot')
 check(dot.visible,'refine eligibility notification retained')
 hero._show_detail('wanderer_jade_jian');await frames(14)
 check(effective_z(dot)<effective_z(hero.detail),'refine dot is below description modal')
 check(hero.detail_values.copies.text.contains('2'),'exact duplicate information retained in detail')
 await capture('hero-description-polished.png')
 hero._close_detail();await frames(4)
 check(dot.visible,'closing modal retains notification')
 check(inventory.item_counts==counts and progression.spirit_stone==stones,'opening description consumes no items or currency')
 await preload('res://tests/qa_runtime_teardown.gd').stop_audio(self)
 current_scene.queue_free();await frames(8)
 print('HOME_HERO_COHESION_CHECKS=',checks,'; FAILURES=',failures)
 quit(0 if failures==0 else 1)
