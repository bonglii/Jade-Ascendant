extends "res://tests/pavilion_layout_review.gd"
const PaidFixture=preload("res://tests/fixtures/paid_gameplay_manager_v2.gd")
const PaidContract=preload("res://scripts/monetization/paid_gameplay_v2.gd")
class Bridge extends Node:
 signal readonly_requested(request_id: String)
 var id: String=""
 var body: String=""
 func requestPaidGameplayV2(request_id: String, raw: String) -> void:
  id=request_id;body=raw
  if raw.is_empty():readonly_requested.emit(request_id)
var paid: Node
var bridge: Bridge
var paid_state: Dictionary
func answer(kind: String) -> void:
 paid_state.revision+=1
 paid._on_result(bridge.id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":paid_state,"operation":{"request_id":bridge.id,"kind":kind,"outcome":null}}))
func wallet_contract() -> void:
 var manager: Node=root.get_node("HubResourceBarManager")
 var bar: Control=manager._resource_bar
 check(bar.get_node("ResourceRow").get_child_count()==4,"four wallet balances")
 check(manager._jade_value.text.ends_with("139"),"earned jade never includes paid balance")
 check(manager._paid_jade_value.text.ends_with("1.5K") or manager._paid_jade_value.text.ends_with("1500"),"verified paid Jade displayed separately")
 for cell: Control in bar.get_node("ResourceRow").get_children():
  check(bar.get_global_rect().grow(1).encloses(cell.get_global_rect()),"wallet cell remains inside frame")
  var label: Label=manager._cell_value_label(cell)
  var longest: float=0
  for line: String in label.text.split("\n"):longest=maxf(longest,label.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x)
  check(longest<=label.size.x+1,"wallet label fits without ellipsis")
func review_sizes() -> Array[Vector2i]:
 if "--quick" in OS.get_cmdline_user_args():return [Vector2i(320,568),Vector2i(390,844)]
 return [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(648,1440),Vector2i(720,1600)]
func review_locales() -> Array[String]:return ["id","en"]
func native_pavilion(_screen: Control) -> void:pass
func native_hero(_screen: Control) -> void:pass
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_six_fixes_qa"):quit(2);return
 create_timer(100).timeout.connect(func():push_error("Six fixes UI watchdog");quit(3))
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 root.get_node("RefineOnboarding").completed=true
 var conf:=ConfigFile.new();conf.set_value("meta","version",2)
 for id: String in ["pavilion","equipment"]:conf.set_value("tutorials",id,true)
 conf.save("user://jade_onboarding.cfg")
 var pavilion: Node=root.get_node("PavilionManager")
 var equipment: Node=root.get_node("EquipmentManager")
 var inventory: Node=root.get_node("InventoryManager")
 var journey: Node=root.get_node("JourneyManager")
 for ch: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(ch):journey.cleared_stage_keys.append(journey.get_stage_key(ch,stage))
 pavilion.state.celestial_jade=139;pavilion.state.pavilion_seals=0;pavilion.state.starter_seals_claimed=true
 var original_paid: Node=pavilion.paid_gameplay;original_paid.set_process(false)
 bridge=Bridge.new();root.add_child(bridge);paid=PaidFixture.new();root.add_child(paid)
 paid.test_bridge=bridge;paid._binding="a".repeat(64)
 paid_state={"paid_gameplay_version":2,"account_binding":"a".repeat(64),"catalog_hash":PaidContract.HASH,"state":"ready","revision":0,"wallet":{"balance":1500,"revision":1},"inventory":{"cloudstep_boots":3,"nine_heavens_star_sword":2},"stars":{"cloudstep_boots":2,"nine_heavens_star_sword":1},"slots":{"armament":"","robe":"","bracer":"","boots":"","pendant":""},"pity":{"rare_plus":0,"epic_plus":10,"legendary":10},"wish":"","wish_guaranteed":false,"lifetime_pulls":10,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}
 check(PaidContract.valid_snapshot(paid_state,"a".repeat(64)),"fixture uses validated production paid snapshot")
 paid.refresh();paid._on_result(bridge.id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":paid_state,"operation":null}))
 # Model a real server answering background GETs during the multi-size review.
 # Mutations are still acknowledged only by the explicit assertions below.
 bridge.readonly_requested.connect(func(id: String) -> void:paid._on_result(id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":paid_state,"operation":null})),CONNECT_DEFERRED)
 pavilion.paid_gameplay=paid
 inventory.item_counts={"mistveil_jian":1,"nine_heavens_star_sword":1}
 var local_boot: String=""
 for id: String in equipment.get_item_ids_for_slot("boots"):
  if id!="cloudstep_boots":local_boot=id;break
 inventory.item_counts[local_boot]=1
 var local_inventory: Dictionary=inventory.item_counts.duplicate(true)
 var before: Dictionary=wallet()
 check(equipment.get_backpack_item_ids().count("nine_heavens_star_sword")==1,"same item across both ledgers becomes one card")
 check(equipment.get_backpack_item_count("nine_heavens_star_sword")==3,"all retained copies visible through one item")
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
 output="res://.local/six_review";DirAccess.make_dir_recursive_absolute(output)
 for locale: String in review_locales():
  root.get_node("SettingsManager").set_presentation("language",locale)
  for dims: Vector2i in review_sizes():
   root.size=dims;change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await frames(24)
   var screen: Control=current_scene
   check(screen.focus_pages.keys()==["summon"],"forge removed and aura held from tab/page tree")
   for tab: String in ["summon"]:
    screen._select_focus_tab(tab);await frames(16)
    check(Contract.inspect(screen).is_empty(),locale+str(dims)+tab+str(Contract.inspect(screen)))
    record("%s-%d-%d-%s"%[locale,dims.x,dims.y,tab])
   screen._select_focus_tab("summon");screen._select_summon_mode(true);await frames(20)
   check(screen._focus_target.is_visible_in_tree() and not screen._focus_target.disabled,"paid target button accessible")
   check(Contract.inspect(screen).is_empty(),"paid page fits "+locale+str(dims))
   await native_pavilion(screen)
   wallet_contract();record("%s-%d-%d-paid"%[locale,dims.x,dims.y])
   if dims.x==390:
    for category: String in ["weapon","set"]:
     screen._open_target_picker(category);await frames(18)
     check(Contract.inspect_sheet(screen).is_empty(),"paid picker fits "+category)
     check(screen._target_overlay.find_child("Target_nine_heavens_star_sword",true,false)!=null if category=="weapon" else screen._target_overlay.find_child("TargetChoices",true,false)!=null,"same weapon/set target browser")
     record(locale+"-paid-target-"+category);screen._close_target_picker();await frames()
   check(wallet()==before and inventory.item_counts==local_inventory,"all browsing remains read-only")
   change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await frames(24)
   var hero: Control=current_scene
   check(hero.card_buttons.has("cloudstep_boots") and hero.card_buttons.has("mistveil_jian"),"earned and paid equipment share backpack")
   check(hero.card_buttons.size()==4,"duplicate ID rendered once")
   check(hero.content.find_child("ServerArmory",true,false)==null,"no second armory menu")
   hero._show_detail("cloudstep_boots");await frames(18)
   check(hero.detail_open and hero.selected_item_id=="cloudstep_boots","paid equipment uses same item sheet")
   check(hero.get_global_rect().grow(1).encloses(hero.sheet_panel.get_global_rect()),"shared detail sheet fits")
   check(hero.sheet_actions.find_child("EquipAction",true,false)!=null,"paid equipment uses normal equip action")
   record("%s-%d-%d-backpack-detail"%[locale,dims.x,dims.y]);hero._close_detail();await frames()
   check(hero.scroll.size.y>=44,"backpack retains a scrollable reader")
   record("%s-%d-%d-backpack"%[locale,dims.x,dims.y])
   await native_hero(hero)
 # Confirm a paid wish through the actual durable command + verified receipt path.
 root.size=Vector2i(390,844);change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await frames(24)
 var screen: Control=current_scene;screen._select_summon_mode(true);await frames()
 screen._open_target_picker("weapon");await frames();screen._target_button_down();screen._choose_browser_target("nine_heavens_star_sword",screen._target_epoch);await frames()
 check(not paid.busy and paid.snapshot.wish=="","target selection waits for confirmation")
 screen._confirm_focus_target("nine_heavens_star_sword","",true)
 check(paid.busy and JSON.parse_string(bridge.body).kind=="wish","confirm dispatches server wish mutation")
 check(pavilion.get_wish_target_item_id()!= "nine_heavens_star_sword","paid selection cannot alter earned target")
 paid_state.wish="nine_heavens_star_sword";answer("wish");await frames()
 check(screen.focal_name.text.contains("Nine Heavens") and paid.snapshot.wish=="nine_heavens_star_sword","only receipt updates paid featured relic")
 var saved: Dictionary=inventory.item_counts.duplicate(true)
 check(equipment.equip_backpack_item("cloudstep_boots"),"equip paid item from unified action")
 paid_state.slots.boots="cloudstep_boots";answer("equip");await frames()
 check(equipment.get_loadout_equipped_item_id("boots")=="cloudstep_boots","verified equip reflected in normal slots")
 check(equipment.ascend_backpack_item("cloudstep_boots"),"normal refine action routes verified duplicate")
 paid_state.inventory.cloudstep_boots=2;paid_state.stars.cloudstep_boots=3;answer("refine");await frames()
 check(equipment.get_backpack_item_star("cloudstep_boots")==3,"confirmed paid refinement displayed")
 check(equipment.equip_backpack_item(local_boot),"replacement automatically clears remote slot")
 check(str(equipment.equipped_item_ids.boots)!=local_boot,"local replacement waits for server receipt")
 paid_state.slots.boots="";answer("equip");await frames()
 check(equipment.get_loadout_equipped_item_id("boots")==local_boot,"one replacement action finishes after acknowledgement")
 check(inventory.item_counts==saved,"paid ownership never copied into offline inventory")
 check(not pavilion.acquire_equipment("nine_heavens_star_sword",true),"retired forge route cannot spend or grant")
 check(pavilion.get_local_celestial_jade()==139 and paid.paid_balance()==1500,"target/equip/refine cannot spend Jade")
 pavilion.paid_gameplay=original_paid
 print("SIX_FIXES_UI checks=%d failures=%d; NATIVE_GUI=%s; PHONE=NOT_TESTED"%[checks,failures,str(DisplayServer.get_name()!="headless")])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
