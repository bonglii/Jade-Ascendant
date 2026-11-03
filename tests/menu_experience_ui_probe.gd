extends SceneTree
## Native render fixture controller. Lives only in disposable QA userdata.
var _last: String=""
var _busy: bool=false
var _journal: Control
func _initialize() -> void:call_deferred("begin")
func frames(count: int=12) -> void:
 for i: int in range(count):await process_frame
func begin() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"):quit(2);return
 await frames()
 if Input.has_method("set_emulate_touch_from_mouse"):Input.call("set_emulate_touch_from_mouse",true);print("UI_TOUCH_FROM_MOUSE_ENABLED available=",DisplayServer.is_touchscreen_available())
 root.get_node("PlayerCompanion").state.seen_bosses=["1-1","1-2","1-3"]
 change_scene_to_file("res://scenes/ui/training_ground.tscn");await frames(16)
 print("PLAYER_CONTENT_UI_READY")
func _process(_delta: float) -> bool:
 var path: String=OS.get_environment("JADE_UI_COMMAND_FILE")
 if _busy or path.is_empty() or not FileAccess.file_exists(path):return false
 var text: String=FileAccess.get_file_as_string(path)
 if text==_last:return false
 _last=text;var command: Variant=JSON.parse_string(text)
 if command is Dictionary:_busy=true;apply.call_deferred(command)
 return false
func apply(command: Dictionary) -> void:
 var settings: Node=root.get_node("SettingsManager")
 if command.has("language"):settings.set_presentation("language",str(command.language))
 if command.has("width"):root.size=Vector2i(int(command.width),int(command.height))
 if command.get("dismiss_guide",false) and current_scene!=null:
  for candidate: Node in current_scene.find_children("*","Node",true,false):
   if candidate.get_script()!=null and str(candidate.get_script().resource_path)=="res://scripts/ui/refine_onboarding.gd":candidate._dismiss(true)
   if candidate.has_method("_finish_onboarding"):candidate._finish_onboarding()
  await frames(6)
 if command.has("scene"):
  paused=false;_journal=null
  var scenes: Dictionary={"hero":"res://scenes/ui/equipment_screen.tscn","cultivate":"res://scenes/ui/cultivation_menu.tscn","events":"res://scenes/ui/event_center_screen.tscn","mail":"res://scenes/ui/mailbox_screen.tscn","odyssey":"res://scenes/ui/odyssey_screen.tscn","treasury":"res://scenes/ui/celestial_treasury_screen.tscn","realm":"res://scenes/ui/chapter_select.tscn","achievements":"res://scenes/ui/achievement_screen.tscn","court":"res://scenes/ui/training_ground.tscn","home":"res://scenes/ui/main_menu.tscn","builds":"res://scenes/ui/skill_book_screen.tscn","daily":"res://scenes/ui/daily_quest_screen.tscn","pavilion":"res://scenes/ui/pavilion_screen.tscn","settings":"res://scenes/ui/settings_screen.tscn","trials":"res://scenes/ui/heavenly_trials_screen.tscn"}
  if command.scene=="trials":
   var client: Node=root.get_node("HeavenlyTrialsClient");client.set_process(false);client.busy=false;client.status="connected"
   client._received=Time.get_ticks_msec()
   client.snapshot={"campaign":{"id":"fixture","enabled":true},"week":{"id":"fixture-week","index":0,"theme":"jade_wind","stage":1,"ruleset_version":2,"starts_at":int(Time.get_unix_time_from_system())-60,"ends_at":int(Time.get_unix_time_from_system())+86400,"reward":{"celestial_jade":12,"pavilion_seal":1,"spirit_stone":145}},"server_time":int(Time.get_unix_time_from_system()),"progress":[],"previous_progress":[],"unlock_tier":3,"ads_ready":false,"shop_ready":false}
  if command.get("unlocked",false):
   var cleared: Array[String]=["1-1","1-2","1-3","1-4","1-5"]
   root.get_node("JourneyManager").cleared_stage_keys=cleared # Explicit presentation fixture, never a live grant.
  change_scene_to_file(scenes.get(command.scene,scenes.court));await frames(20)
  if command.scene=="builds":current_scene._set_mode("BUILDS");await frames(8)
 if command.get("seed_gear",false):
  var slots: Dictionary={}
  for slot: String in root.get_node("EquipmentManager").get_slot_ids():slots[slot]=""
  var owned: Array=root.get_node("EquipmentManager").get_item_ids_for_slot("armament")
  if not owned.is_empty():
   root.get_node("InventoryManager").add_item(str(owned[0]),1);slots.armament=str(owned[0])
  root.get_node("PlayerCompanion").state.presets["0"]={"name":"Author fixture · Boss","slots":slots,"server":{}}
  await frames(5)
 if command.has("training_mode"):
  current_scene._mode_picker.select(int(command.training_mode));current_scene._select_mode(int(command.training_mode));await frames(6)
 if command.has("guide"):
  load("res://scripts/experience/menu_guide.gd").open(current_scene,str(command.guide),{"index":0});await frames(8)
 if command.get("close_guide",false):
  var guide: Node=current_scene.get_node_or_null("ExperienceGuide")
  if guide!=null:guide.close();await frames(5)
 if command.get("contrast",false):settings.set_presentation("high_contrast_warnings",true)
 if command.has("library_mode"):
  current_scene._set_mode(str(command.library_mode));await frames(8)
 if command.has("journal_page"):
  _journal=load("res://scripts/companion/player_journal.gd").open(current_scene,str(command.journal_page));await frames(10)
 if command.has("skill_detail"):
  current_scene._open_skill_detail(str(command.skill_detail));await frames(8)
 if command.has("equipment_detail"):
  current_scene._open_equipment_detail(str(command.equipment_detail));await frames(8)
 if command.has("mode") and current_scene.has_method("_select_mode"):current_scene._mode_picker.select(int(command.mode));current_scene._select_mode(int(command.mode));await frames(10)
 if command.get("setup",false):current_scene._configure();await frames(10)
 if command.get("start",false):current_scene._start();await frames(30)
 if command.has("story"):load("res://scripts/ui/chronicle_reader.gd").open(current_scene,str(command.story));await frames(12)
 if command.get("rewards",false):current_scene._open_rewards();await frames(10)
 if command.get("compare",false):
  var companion: Node=root.get_node("PlayerCompanion")
  var slots: Dictionary={"armament":"","robe":"","bracer":"","boots":"","pendant":""}
  var facts: Dictionary={"seconds":68.0,"level":9,"hits":41,"hp_loss":396.0,"incoming_complete":true,"metrics_complete":true,"damage_partial":false,"damage":[{"id":"spirit_sword","name":"Spirit Sword","damage":948.0},{"id":"fire_orb","name":"Fire Orb","damage":431.0}],"skills":[]}
  companion.state.runs=[{"id":"a".repeat(32),"chapter":1,"stage":1,"outcome":"defeat","time":1793620800,"slots":slots,"facts":facts.duplicate(true)},{"id":"b".repeat(32),"chapter":1,"stage":1,"outcome":"defeat","time":1793617200,"slots":slots,"facts":facts.duplicate(true)}]
  companion.state.runs[1].facts.seconds=60.0;companion.state.runs[1].facts.hits=45
  _journal=load("res://scripts/companion/player_journal.gd").open(current_scene,"runs");await frames(10);_journal._compare_runs();await frames(12)
 if command.has("choice"):
  var chooser: Node=current_scene.player.get_node("WeaponManager/RunPathChoices")
  var id: bool=settings.language=="id"
  if command.choice=="boon":chooser._offer("boon","ALTAR DUA ANGIN" if id else "ALTAR OF TWO WINDS",[["ember","SUMPAH BARA · +12% damage langsung art, −10% gerak." if id else "EMBER OATH · +12% direct art damage, −10% movement."],["wind","SUMPAH ANGIN · +10% gerak, −8% damage langsung art." if id else "WIND OATH · +10% movement, −8% direct art damage."],["none","JAGA KESEIMBANGAN · tanpa berkah atau penalti." if id else "KEEP MY BALANCE · no boon or penalty."]])
  else:chooser._offer("spirit_sword","Spirit Sword · PILIH JALUR" if id else "Spirit Sword · CHOOSE A PATH",[["focus","FOKUS PENJAGA · +20% damage langsung ke boss, −10% ke musuh lain." if id else "GUARDIAN FOCUS · +20% direct damage to bosses, −10% to other enemies."],["sweep","SAPUAN LEMBAH · +15% damage langsung ke musuh lain, −10% ke boss." if id else "VALLEY SWEEP · +15% direct damage to other enemies, −10% to bosses."],["balanced","ART SEIMBANG · pertahankan damage asli." if id else "BALANCED ART · retain the original damage."]])
  await frames(12)
 if command.get("force_guide",false):
  for area: Node in current_scene.find_children("*","Control",true,false):
   if area.has_method("_tutorial_key_for_scene") and area._tutorial_key_for_scene()=="home":
    area._tutorial_key="home";area._tutorial_step_index=0;area._build_onboarding_overlay();area._refresh_onboarding_step()
  await frames(10)
 if command.get("insets",false):
  for area: Control in current_scene.find_children("*","Control",true,false):
   if area.has_method("refresh_safe_area"):area.offset_top=24;area.offset_bottom=-32
  await frames(10)
 if command.get("scroll_bottom",false):
  for scroll: ScrollContainer in current_scene.find_children("*","ScrollContainer",true,false):
   if scroll.is_visible_in_tree():scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
  await frames(8)
 if command.has("scroll_to"):
  var target: Control=current_scene.find_child(str(command.scroll_to),true,false)
  var scroll: ScrollContainer=preload("res://scripts/ui/mobile_scroll_policy.gd").ancestor(target) if target!=null else null
  if scroll!=null:
   scroll.ensure_control_visible(target);await frames(3)
   scroll.scroll_vertical+=180
  await frames(8)
 if command.has("capture"):
  await RenderingServer.frame_post_draw
  var path: String=OS.get_environment("JADE_UI_CAPTURE_DIR").path_join(str(command.capture)+".png")
  var metadata: Dictionary={"fixture":true,"scene":current_scene.name,"paused":paused,"quiet_vfx":settings.quiet_player_vfx,"window":DisplayServer.window_get_size(),"root_size":root.size,"viewport":root.get_visible_rect().size,"scrolls":[],"option_popup_open":false}
  if current_scene.has_method("_configure"):
   metadata.setup_open=current_scene._setup.visible;metadata.running=current_scene._running;metadata.mode=current_scene.mode;metadata.art_index=current_scene._skills.selected;metadata.joystick_input=current_scene._joystick.is_processing_input()
   metadata.run_paths=current_scene.player.get_node("WeaponManager").run_paths.duplicate(true)
  if is_instance_valid(_journal):metadata.compare_a=_journal._compare_a;metadata.compare_b=_journal._compare_b
  for scroll: ScrollContainer in current_scene.find_children("*","ScrollContainer",true,false):
   if scroll.is_visible_in_tree():metadata.scrolls.append({"name":scroll.name,"position":scroll.scroll_vertical,"maximum":scroll.get_v_scroll_bar().max_value,"page":scroll.get_v_scroll_bar().page})
  metadata.popups=[]
  for option: OptionButton in current_scene.find_children("*","OptionButton",true,false):
   if option.get_popup().visible:
    metadata.option_popup_open=true
    var popup: PopupMenu=option.get_popup()
    metadata.popups.append({"owner":option.name,"position":[popup.position.x,popup.position.y],"size":[popup.size.x,popup.size.y],"embedded":popup.is_embedded(),"count":popup.item_count})
  metadata.controls=[]
  for control: Control in current_scene.find_children("*","Control",true,false):
   if control.is_visible_in_tree() and (control is BaseButton or (control is PanelContainer and preload("res://scripts/ui/mobile_scroll_policy.gd").ancestor(control)!=null)):metadata.controls.append({"name":control.name,"text":str(control.get("text")) if control is BaseButton else "","under_scroll":preload("res://scripts/ui/mobile_scroll_policy.gd").ancestor(control)!=null,"physical":[control.get_global_rect().position.x*root.size.x/root.get_visible_rect().size.x,control.get_global_rect().position.y*root.size.y/root.get_visible_rect().size.y,control.size.x*root.size.x/root.get_visible_rect().size.x,control.size.y*root.size.y/root.get_visible_rect().size.y],"rect":control.get_global_rect(),"screen":control.get_global_transform_with_canvas().origin})
  var proof:=FileAccess.open(path.trim_suffix(".png")+".json",FileAccess.WRITE);proof.store_string(JSON.stringify(metadata,"  "));proof.close()
  var captured: Image=root.get_texture().get_image()
  if captured.get_size()!=root.size:push_error("UI_CAPTURE_DIMENSION_MISMATCH")
  var error: Error=captured.save_png(path)
  print("UI_CAPTURE ",command.capture," error=",error," viewport=",root.get_visible_rect().size)
 if command.get("quit",false):
  paused=false;await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  _journal=null
  if current_scene!=null:current_scene.queue_free();current_scene=null
  await frames(4);quit();return
 print("UI_COMMAND_DONE ",str(command.get("id","")))
 _busy=false
