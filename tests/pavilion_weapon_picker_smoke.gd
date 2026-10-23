extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PAVILION_PICKER_FAILURE "+label)
func settle() -> void:await create_timer(.15).timeout
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.4).timeout
 var journey: Node=root.get_node("JourneyManager");var pavilion: Node=root.get_node("PavilionManager");var equipment: Node=root.get_node("EquipmentManager")
 journey.cleared_stage_keys.clear()
 check(pavilion.get_summon_pool_by_rarity().values().all(func(a: Array):return a.is_empty()),"pool closed before 1-5")
 for stage: int in range(1,5):journey.cleared_stage_keys.append(journey.get_stage_key(1,stage))
 check(pavilion.get_wish_target_options().is_empty(),"targets still locked at 1-4")
 journey.cleared_stage_keys.append(journey.get_stage_key(1,5))
 var pool: Dictionary=pavilion.get_summon_pool_by_rarity();var count: int=0
 for rarity: String in pool:count+=pool[rarity].size()
 var eligible: Array[String]=[]
 for id: String in equipment.get_item_ids():
  if not bool(equipment.get_item_data(id).get("event_only",false)):eligible.append(id)
 check(count==eligible.size(),"all non-event equipment opens at 1-5")
 for id: String in eligible:check(id in pool[str(equipment.get_item_data(id).rarity)],"correct rarity pool "+id)
 for id: String in ["jade_binding_chain","celestial_returning_glaive","nine_heavens_star_sword","void_piercer_spear"]:check(id in pavilion.get_wish_target_options(),"weapon target open at 1-5 "+id)
 check(not pavilion.is_item_unlocked("celestial_returning_glaive"),"shop/forge stage gate kept separate")
 pavilion.state.pavilion_seals=50;pavilion.state.starter_seals_claimed=true
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await settle();await settle()
 var screen: Control=current_scene
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  root.size=viewport;await settle()
  screen._show_drop_rates_overlay();await settle()
  var overlay: ColorRect=screen.locked_rates_overlay;var panel: PanelContainer=overlay.get_meta("panel")
  check(panel.size.y<overlay.size.y*.8,"rates compact "+str(viewport))
  check(panel.get_global_rect().end.x<=overlay.get_global_rect().end.x+1 and panel.get_global_rect().end.y<=overlay.get_global_rect().end.y+1,"rates inside safe area "+str(viewport))
  check(panel.find_child("CompactFooter",true,false).get_child_count()==1,"close outside scroll")
  screen._back();await settle();check(screen.locked_rates_overlay==null,"Back dismisses rates")
  screen._open_target_picker("weapon");await settle()
  overlay=screen._target_overlay;panel=overlay.get_meta("panel")
  check(panel.get_global_rect().end.x<=overlay.get_global_rect().end.x+1,"picker width fits "+str(viewport))
  for id: String in ["jade_binding_chain","celestial_returning_glaive","nine_heavens_star_sword","void_piercer_spear"]:
   var button: Button=overlay.find_child("Target_"+id,true,false)
   check(button!=null and not button.disabled,"weapon selectable "+id+str(viewport))
  screen._open_target_picker("set");await settle()
  check(screen._target_overlay.find_child("Target_sovereign_mantle",true,false)!=null,"set piece browser available")
  screen._back();await settle();check(screen._target_overlay==null,"Back dismisses browser")
 root.size=Vector2i(648,1152);await settle()
 screen._open_target_picker("weapon");await settle()
 var epoch: int=screen._target_epoch
 var old_target: String=pavilion.get_wish_target_item_id()
 screen._target_press_pos=screen.get_global_mouse_position()+Vector2(50,0)
 screen._choose_browser_target("jade_binding_chain",epoch)
 check(pavilion.get_wish_target_item_id()==old_target,"drag gesture never changes target or resets Fate")
 screen._target_button_down()
 screen._choose_browser_target("jade_binding_chain",epoch);await settle()
 check(pavilion.get_wish_target_item_id()=="jade_binding_chain","select weapon outside featured banner")
 screen._open_target_picker("weapon");await settle()
 screen._choose_browser_target("celestial_returning_glaive",epoch);await settle()
 check(pavilion.get_wish_target_item_id()=="jade_binding_chain","stale selection callback rejected")
 screen._choose_browser_target("celestial_returning_glaive",screen._target_epoch);await settle()
 check(pavilion.get_wish_target_item_id()=="celestial_returning_glaive","second weapon selected through manager")
 check(not bool(pavilion.state.get("wish_fate_guaranteed",false)),"target change keeps existing Fate reset policy")
 var forced: String=pavilion._choose_item_for_rarity("legendary",pool,true,pavilion.state)
 check(forced=="celestial_returning_glaive","hard pity honors selected weapon")
 screen._show_drop_rates_overlay();await settle();root.size=Vector2i(320,568);await settle();await settle()
 var resized_overlay: ColorRect=screen.locked_rates_overlay;var resized_panel: PanelContainer=resized_overlay.get_meta("panel")
 check(resized_panel.get_global_rect().end.x<=resized_overlay.get_global_rect().end.x+1 and resized_panel.get_global_rect().end.y<=resized_overlay.get_global_rect().end.y+1,"open popup refits after viewport resize")
 screen._close_rates_overlay();root.size=Vector2i(648,1152);await settle();screen._open_target_picker("weapon");await settle()
 root.size=Vector2i(320,568);await settle();await settle()
 check(screen._target_overlay.find_child("TargetChoices",true,false).columns==1,"open picker changes to one column on narrow resize")
 screen._close_target_picker()
 var before: int=pavilion.get_lifetime_pulls();var result: Dictionary=pavilion.summon_equipment(1)
 check(bool(result.get("success",false)) and pavilion.get_lifetime_pulls()==before+1,"gacha actually works after clear 1-5")
 print("PAVILION_WEAPON_PICKER_CHECKS=",checks,";FAILURES=",failures)
 current_scene.queue_free();current_scene=null
 await settle()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
