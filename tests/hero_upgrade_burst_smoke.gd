extends SceneTree
var checks: int=0
var failures: int=0
var screen: Control
var eq: Node
var inv: Node
var progression: Node
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("HERO_UPGRADE_BURST_FAILURE "+label)
func settle() -> void:await create_timer(.12).timeout
func frames() -> void:await process_frame;await process_frame
func unrelated_press() -> void:pass
func _initialize() -> void:run.call_deferred()
func action(name_value: String) -> Button:return screen.sheet_actions.find_child(name_value,true,false) as Button
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_hero_qa"):quit(2);return
 await create_timer(.4).timeout
 root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(648,1152)
 inv=root.get_node("InventoryManager");eq=root.get_node("EquipmentManager");progression=root.get_node("ProgressionManager")
 eq.active_run_loadout_snapshot.clear();progression.spirit_stone=200000
 for id: String in eq.get_item_ids():inv.item_counts[id]=8
 for id: String in ["nine_heavens_star_sword","sovereign_mantle","tribulation_bracer","cloudtreader_boots","ascendant_heart"]:eq.equip_item(id)
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await settle();screen=current_scene
 screen.sort_id=2;screen._refresh_all();await settle()
 for id: String in ["sovereign_mantle","solar_edict_bracer","bamboo_weave_robe","moonthread_robe","ward_keeper_robe","nine_heavens_star_sword","jade_binding_chain","celestial_returning_glaive"]:
  screen._show_detail(id);await settle()
  var panel: int=screen.sheet_panel.get_instance_id();var body: int=screen.sheet_body.get_instance_id();var grid: int=screen.grid.get_instance_id()
  screen.sheet_scroll.scroll_vertical=40;await settle();var position: int=screen.sheet_scroll.scroll_vertical
  for i: int in range(4):
   var star: int=eq.get_item_star(id);var count: int=inv.get_item_count(id);var stones: int=progression.spirit_stone
   var button: Button=action("AscendAction");var stale: Callable=button.get_meta("hero_action")
   button.pressed.emit();button.pressed.emit();button.pressed.emit()
   var level_button: Button=action("LevelAction")
   var old_level: int=eq.get_item_weapon_level(id)
   if level_button!=null:level_button.pressed.emit()
   await frames()
   check(eq.get_item_star(id)==star+1 and inv.get_item_count(id)==count-1,"exactly one identical duplicate consumed "+id)
   check(progression.spirit_stone==stones and eq.get_item_weapon_level(id)==old_level,"mixed star/level burst executes one displayed action "+id)
   stale.call();await frames()
   check(eq.get_item_star(id)==star+1 and inv.get_item_count(id)==count-1,"stale star callback cannot buy another upgrade "+id)
   check(screen.sheet_panel.get_instance_id()==panel and screen.sheet_body.get_instance_id()==body and screen.grid.get_instance_id()==grid,"upgrade retains popup/body/backpack "+id)
   check(screen.sheet_scroll.scroll_vertical==position,"description scroll retained "+id)
   check(screen.detail_values.stars.text==screen._stars(star+1),"popup reflects committed star "+id)
   check(screen.card_buttons[id].get_node("ItemRank").text==screen._stars(star+1),"backpack star follows upgrade "+id)
  check(action("AscendAction").disabled and action("AscendAction").text=="BINTANG MAX","max star action disabled "+id)
  var copies: int=inv.get_item_count(id);action("AscendAction").pressed.emit();await frames();check(inv.get_item_count(id)==copies,"MAX ignores synthetic extra press "+id)
 # Three weapon families, including both premium weapons, share the same guard.
 for id: String in ["nine_heavens_star_sword","jade_binding_chain","celestial_returning_glaive"]:
  screen._show_detail(id);await settle()
  var panel: int=screen.sheet_panel.get_instance_id();var grid: int=screen.grid.get_instance_id()
  var steps: int=49 if id=="nine_heavens_star_sword" else 12
  for i: int in range(steps):
   var level: int=eq.get_item_weapon_level(id);var cost: int=eq.get_weapon_level_cost(id);var stones: int=progression.spirit_stone
   var button: Button=action("LevelAction");var stale: Callable=button.get_meta("hero_action")
   button.pressed.emit();button.pressed.emit();button.pressed.emit();await frames()
   check(eq.get_item_weapon_level(id)==level+1 and progression.spirit_stone==stones-cost,"single committed level/cost per burst "+id)
   stale.call();await frames();check(eq.get_item_weapon_level(id)==level+1 and progression.spirit_stone==stones-cost,"stale level callback rejected "+id)
   check(screen.sheet_panel.get_instance_id()==panel and screen.grid.get_instance_id()==grid,"level upgrade keeps popup/backpack "+id)
   check(screen.detail_values.level.text.begins_with("LEVEL WEAPON %d / 50"%(level+1)),"level/cap label refreshed "+id)
  if steps==49:check(action("LevelAction").disabled and action("LevelAction").text=="LEVEL MAX 50","weapon cap button disabled")
 # Resource limits and failed writes never present a purchased upgrade.
 screen._show_detail("jade_binding_chain");await settle()
 progression.spirit_stone=0;screen._sync_detail_loadout()
 action("LevelAction").pressed.connect(unrelated_press);screen._sync_detail_loadout()
 check(action("LevelAction").pressed.is_connected(unrelated_press),"action rebinding preserves unrelated sound/FX callbacks")
 var level_before: int=eq.get_item_weapon_level("jade_binding_chain")
 action("LevelAction").pressed.emit();await frames();check(eq.get_item_weapon_level("jade_binding_chain")==level_before,"insufficient stones rejected")
 progression.add_spirit_stone(10000);await settle()
 check(not action("LevelAction").disabled,"wallet save refreshes a disabled level action in place")
 var saver: Node=root.get_node("SaveManager");saver.begin_save_write_barrier("hero_qa","upgrade burst failure fixture")
 screen._sync_detail_loadout();var before: Dictionary=eq.build_equipment_save_data().duplicate(true);var stones_before: int=progression.spirit_stone
 action("LevelAction").pressed.emit();await frames()
 check(eq.build_equipment_save_data()==before and progression.spirit_stone==stones_before,"failed/blocked write never mutates level or wallet")
 saver.end_save_write_barrier("hero_qa");screen._sync_detail_loadout()
 inv.item_counts["bamboo_weave_robe"]=1;eq.ascension_stars["bamboo_weave_robe"]=1
 screen._show_detail("bamboo_weave_robe");await settle();action("AscendAction").pressed.emit();await frames()
 check(inv.get_item_count("bamboo_weave_robe")==1 and eq.get_item_star("bamboo_weave_robe")==1,"missing identical duplicate preserves primary")
 # Replacement/close invalidates callbacks even when returning to the same item.
 screen._show_detail("jade_binding_chain");await settle();var stale: Callable=action("LevelAction").get_meta("hero_action")
 screen._close_detail();screen._show_detail("jade_binding_chain");await settle();before=eq.build_equipment_save_data().duplicate(true)
 stale.call();await frames();check(eq.build_equipment_save_data()==before,"old popup generation cannot upgrade reopened item")
 for id: String in ["bamboo_weave_robe","moonthread_robe","ward_keeper_robe","sovereign_mantle"]:
  eq.equip_item(id);await frames()
  var card: Button=screen.card_buttons[id]
  check(card.get_node("EquippedMark").visible,"equipped treatment works across rarities "+id)
  check(card.get_theme_stylebox("normal").texture.resource_path.ends_with("relic_card_"+str(eq.get_item_data(id).rarity)+".svg"),"highlight preserves rarity skin "+id)
 for viewport: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.size=viewport;await settle();screen._close_detail();await settle()
  for id: String in screen.card_buttons:
   var card: Button=screen.card_buttons[id];var mark: Control=card.get_node_or_null("EquippedMark")
   if mark==null:continue
   check(mark.visible==(id in screen._equipped_ids()),"equipped visual matches authoritative loadout "+id)
   if mark.visible:
    var badge: Control=mark.get_node("EquippedBadge");var label: Label=badge.get_node("EquippedCaption")
    check(badge.get_global_rect().end.x<=card.get_global_rect().end.x+1 and label.size.x<=card.size.x,"active badge fits narrow card "+str(viewport))
 # Repeated stats/demo entry remains single; material counts refresh in place.
 screen._show_stats();await settle();var stats_panel: int=screen.sheet_panel.get_instance_id();screen._show_stats();await frames();check(screen.sheet_panel.get_instance_id()==stats_panel,"repeated Stats tap is idempotent")
 inv.item_counts["refinement_shard"]=2;screen._show_detail("refinement_shard");await settle();var material_panel: int=screen.sheet_panel.get_instance_id()
 inv.item_counts["refinement_shard"]=3;inv.inventory_changed.emit("refinement_shard",3);await settle()
 check(screen.sheet_panel.get_instance_id()==material_panel and screen.detail_values.material.text.ends_with("3"),"material quantity updates without popup recreation")
 screen._show_detail("jade_binding_chain");await settle();var demo: Button=screen.sheet_body.get_node("DemoAction") as Button
 var old_demo: Callable=demo.get_meta("hero_action")
 old_demo.call();old_demo.call();await frames()
 check(screen.get_children().filter(func(node: Node):return node.name=="JadeBindingPreview").size()==1,"duplicate Demo entry remains single")
 screen.get_node("JadeBindingPreview").queue_free();await frames();screen._close_detail();old_demo.call();await frames()
 check(screen.get_node_or_null("JadeBindingPreview")==null,"closed popup demo callback rejected")
 print("HERO_UPGRADE_BURST_CHECKS=",checks,";FAILURES=",failures)
 quit(1 if failures else 0)
