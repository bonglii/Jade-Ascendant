extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("LOADOUT_PROFILE_FAILURE "+label)
func settle() -> void:await create_timer(.12).timeout
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.4).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 var inv: Node=root.get_node("InventoryManager");var eq: Node=root.get_node("EquipmentManager")
 eq.active_run_loadout_snapshot.clear()
 for id: String in eq.get_item_ids():inv.item_counts[id]=3
 for id: String in ["nine_heavens_star_sword","sovereign_mantle","tribulation_bracer","cloudtreader_boots","ascendant_heart"]:eq.equip_item(id)
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await settle()
 var screen: Control=current_scene
 screen._show_detail("sovereign_mantle");await settle()
 var popup_id: int=screen.sheet_panel.get_instance_id();var grid_id: int=screen.grid.get_instance_id();var page_id: int=screen.page.get_instance_id()
 var filter: int=screen.filter_menu.get_instance_id()
 var counts: Dictionary=inv.item_counts.duplicate(true);var stars: Dictionary=eq.ascension_stars.duplicate(true);var levels: Dictionary=eq.weapon_levels.duplicate(true)
 screen.sheet_scroll.scroll_vertical=70;await settle()
 var popup_scroll: int=screen.sheet_scroll.scroll_vertical
 screen.scroll.scroll_vertical=80;await settle()
 var page_scroll: int=screen.scroll.scroll_vertical
 for i: int in range(100):
  var action: Button=screen.sheet_actions.find_child("EquipAction",true,false) as Button
  var was_equipped: bool="sovereign_mantle" in screen._equipped_ids()
  action.pressed.emit();action.pressed.emit()
  await process_frame;await process_frame
  var equipped: bool="sovereign_mantle" in screen._equipped_ids()
  check(equipped!=was_equipped,"one toggle per duplicate event burst %d"%i)
  check(screen.sheet_panel.get_instance_id()==popup_id and screen.grid.get_instance_id()==grid_id and screen.page.get_instance_id()==page_id and screen.filter_menu.get_instance_id()==filter,"no page/popup reconstruction %d"%i)
  check(screen.sheet_scroll.scroll_vertical==popup_scroll and screen.scroll.scroll_vertical==page_scroll,"both scroll offsets survive %d"%i)
  check(action.text==("LEPAS" if equipped else "PASANG"),"action reads committed loadout %d"%i)
  check(screen.card_buttons["sovereign_mantle"].get_node("EquippedMark").visible==equipped,"backpack marker matches slot %d"%i)
  check(screen.detail_set_header.text.ends_with("4/4" if equipped else "3/4"),"set resonance follows armor %d"%i)
 var save: Dictionary=root.get_node("SaveManager").read_save_data("equipment")
 check(save.get("data",{}).get("equipped_item_ids",{})==eq.equipped_item_ids,"saved equipment matches final rapid-toggle state")
 check(counts==inv.item_counts and stars==eq.ascension_stars and levels==eq.weapon_levels,"toggle never consumes inventory/stars/levels")
 # Stale callbacks and old layout coroutines must not act on a newer selection.
 screen._show_detail("sovereign_mantle");screen._show_detail("jade_binding_chain")
 screen._equip_selected("sovereign_mantle",true)
 await settle()
 check(screen.selected_item_id=="jade_binding_chain" and screen.sheet_panel.self_modulate.a==1.0,"newest modal wins deferred layout race")
 check(screen.sheet_panel.get_global_rect().end.y<=screen.detail.get_global_rect().end.y+1,"rapid replacement modal remains inside safe area")
 screen._show_stats();screen._close_detail();await settle();check(screen.detail==null,"closing invalidates old deferred layouts")
 change_scene_to_file("res://scenes/ui/main_menu.tscn");await settle()
 var home: Node=current_scene.get_node("HomeUI/HomeProductionOverlay")
 var identity: Node=root.get_node("PlayerIdentityManager");var progression: Node=root.get_node("ProgressionManager")
 identity._state.display_name="Kultivator Giok Abadi"
 identity.set_server_context("","sign_in_required")
 check(home.profile_name.text=="Kultivator Giok Abadi","identity signal updates real player name")
 check(home.profile_rank.text.begins_with("Lv."),"shortcut shows permanent hero level and rank")
 check(home.profile_exp.value==progression.get_hero_progress_ratio(),"EXP uses progression authority")
 identity._state.server_bindings={"a".repeat(64):"JA0123456789"}
 identity.set_server_context("a".repeat(64),"connected")
 check(home.profile_status.text.contains("ONLINE"),"connection signal updates badge")
 check(home.profile_shortcut.tooltip_text.contains("JA0123456789"),"tooltip exposes current server UID")
 progression.hero_experience_total=340
 progression.hero_progress_changed.emit(progression.get_hero_level(),progression.get_hero_current_level_experience(),progression.get_hero_experience_to_next_level())
 check(home.profile_rank.text.begins_with("Lv.03") and is_equal_approx(home.profile_exp.value,progression.get_hero_progress_ratio()),"live EXP changes update rank and progress without rebuilding")
 progression.hero_experience_total=progression.get_hero_total_experience_cap()
 progression.hero_progress_changed.emit(50,0,0)
 check(home.profile_rank.text.begins_with("Lv.50") and home.profile_status.text.begins_with("MAX") and is_equal_approx(home.profile_exp.value,1.0),"maximum level is shown correctly")
 var expected_name: String=home.profile_name.text
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=viewport;await settle()
  var card: Rect2=home.profile_shortcut.get_global_rect()
  var settings: Rect2=home.get_node("HomeSettingsButton").get_global_rect()
  check(card.end.x<=settings.position.x,"profile keeps Settings reachable "+str(viewport))
  check(home.profile_name.get_global_rect().end.x<=card.end.x,"long name is ellipsized inside card "+str(viewport))
  check(home.profile_exp.get_global_rect().end.y<=card.end.y,"EXP bar fits card "+str(viewport))
  check(home.profile_name.text==expected_name,"no destructive visual truncation "+str(viewport))
 var before_profile: Dictionary=identity.get_profile_snapshot().duplicate(true)
 var before_progress: Dictionary=progression.build_progression_save_data().duplicate(true)
 home.profile_shortcut.pressed.emit();await settle()
 check(current_scene.profile_overlay.visible,"shortcut opens existing real profile sheet")
 home.profile_shortcut.pressed.emit();await settle()
 check(current_scene.get_children().filter(func(node: Node):return node.name=="LinYueProfileOverlay").size()==1,"repeat press does not duplicate overlay")
 check(identity.get_profile_snapshot()==before_profile and progression.build_progression_save_data()==before_progress,"profile interaction never changes identity/progression")
 print("HERO_LOADOUT_PROFILE_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
