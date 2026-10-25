extends SceneTree
const Paid = preload("res://scripts/monetization/paid_gameplay_v2.gd")
const Fixture = preload("res://tests/fixtures/paid_gameplay_manager_v2.gd")
var checks: int = 0
var failures: int = 0
var paid: Node
var bridge: Node
var pavilion: Node
var view: Control
class Bridge extends Node:
 var id: String = ""
 var commands: Array[Dictionary] = []
 func requestPaidGameplayV2(request_id: String, body: String) -> void:
  id = request_id
  if not body.is_empty(): commands.append(JSON.parse_string(body))
func check(ok: bool, caption: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("GEAR_SUMMON_FAIL " + caption)
func frames(n: int = 4) -> void:
 for i: int in range(n): await process_frame
func _initialize() -> void: run.call_deferred()
func snapshot(balance: int=2000,revision: int=0) -> Dictionary:
 return {"paid_gameplay_version":2,"account_binding":paid.test_binding,"catalog_hash":Paid.HASH,"state":"ready","revision":revision,"wallet":{"balance":balance,"revision":revision},"inventory":{},"stars":{},"slots":{"armament":"","robe":"","bracer":"","boots":"","pendant":""},"pity":{"rare_plus":0,"epic_plus":0,"legendary":0},"wish":"","wish_guaranteed":false,"lifetime_pulls":0,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}
func reply(balance: int=2000,revision: int=0) -> void:
 paid._on_result(bridge.id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":snapshot(balance,revision),"operation":null}))
func load_verified_wallet(balance: int=2000) -> void:
 check(paid.refresh(),"begin verified read")
 reply(balance,int(paid.snapshot.get("revision",0))+1)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"): quit(2); return
 create_timer(100).timeout.connect(func() -> void: quit(1))
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 var cfg:=ConfigFile.new();cfg.set_value("meta","version",2)
 for id: String in ["home","equipment","pavilion"]: cfg.set_value("tutorials",id,true)
 cfg.save("user://jade_onboarding.cfg")
 root.get_node("RefineOnboarding").set_process(false)
 root.get_node("RefineOnboarding").completed=true
 root.get_node("SettingsManager").language="id"
 root.get_node("JourneyManager").cleared_stage_keys=["1-1","1-2","1-3","1-4","1-5"]
 pavilion=root.get_node("PavilionManager")
 var original: Node=pavilion.paid_gameplay
 paid=Fixture.new();bridge=Bridge.new();root.add_child(bridge);root.add_child(paid)
 paid.test_bridge=bridge;paid._binding="a".repeat(64);pavilion.paid_gameplay=paid
 pavilion.state.celestial_jade=10000;pavilion.state.pavilion_seals=100
 load_verified_wallet()
 check(paid.refresh(),"start periodic wallet read")
 if "--repro" in OS.get_cmdline_user_args():
  print("PAVILION_REFRESH_REPRO local_summon_ready=",pavilion.can_summon(1)," read_busy=",paid.busy)
  pavilion.paid_gameplay=original
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  quit();return
 check(pavilion.can_summon(1) and pavilion.can_summon(10),"ordinary read does not disable local summon")
 check(paid.verified_read_in_flight() and paid.can_queue_summon_after_read(10),"only a fresh verified background read permits one intent")
 check(not paid.submit("summon",{"pull_count":1}),"core authority still rejects direct mutation while read is busy")
 check(not FileAccess.file_exists(paid._journal_path()),"background read does not create a spend journal")
 change_scene_to_file("res://scenes/ui/pavilion_screen.tscn");await frames(18)
 view=current_scene
 check(not view.summon_one_button.disabled and not view.summon_ten_button.disabled,"actual primary buttons remain enabled during read")
 check(not view._paid_buttons[0].disabled and not view._paid_buttons[1].disabled,"paid buttons retain eligibility during fresh read")
 view._summon_paid(10);view._summon_paid(1);view._summon_paid(10)
 check(view._queued_paid_intent.get("count")==10 and bridge.commands.is_empty(),"spam retains one unsent ten-pull intent")
 check(view.summon_one_button.disabled and view.summon_ten_button.disabled,"explicit queued action holds competing local summon/reveal on this page")
 reply(2000,7);await frames()
 check(bridge.commands.size()==1,"read completion dispatches one mutation only")
 if bridge.commands.size()!=1:
  pavilion.paid_gameplay=original
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  quit(1);return
 check(int(bridge.commands[-1].expected_revision)==7 and int(bridge.commands[-1].pull_count)==10,"new server revision, not pre-refresh revision, is persisted")
 check(paid.mutation_pending() and not pavilion.can_summon(1),"real/durable mutation remains serialized")
 view._summon_paid(1)
 check(bridge.commands.size()==1,"actual mutation rejects a second press")
 paid._on_result(bridge.id,false,"NETWORK_UNAVAILABLE","")
 check(FileAccess.file_exists(paid._journal_path()),"a submitted request keeps durable recovery evidence on failure")
 DirAccess.remove_absolute(paid._journal_path()) # Isolated fake transport only.
 load_verified_wallet();await frames()
 var before: int=bridge.commands.size()
 paid.refresh();view._summon_paid(10);reply(5,8);await frames()
 check(bridge.commands.size()==before and view._queued_paid_intent.is_empty() and not view._paid_reveal_busy,"reduced balance cancels unsent intent without a spend")
 load_verified_wallet();await frames();paid.refresh();view._summon_paid(1)
 paid._on_result(bridge.id,false,"ACCOUNT_HELD","");await frames()
 check(bridge.commands.size()==before and view._queued_paid_intent.is_empty() and not view._paid_reveal_busy,"held account clears queued intent without bypassing authority")
 load_verified_wallet();await frames();paid.refresh();view._summon_paid(1)
 paid.test_binding="b".repeat(64);paid._identity_changed(false);await frames()
 check(view._queued_paid_intent.is_empty() and bridge.commands.size()==before,"account switch cancels the old intent")
 reply()
 paid.test_binding="a".repeat(64);paid._identity_changed(false);await frames();reply();await frames()
 var trials: Node=root.get_node("HeavenlyTrialsClient");trials.set_process(false);trials.snapshot={"bonus_seals":1}
 paid.refresh();view._refresh_paid_summons();view._summon_trial_seal();view._summon_trial_seal()
 check(bool(view._queued_paid_intent.get("seal",false)) and bridge.commands.size()==before,"bonus Seal also queues one intent during read")
 reply(2000,9);await frames()
 check(bridge.commands.size()==before+1 and bridge.commands[-1].kind=="seal_summon","bonus Seal uses its original authenticated command")
 paid._on_result(bridge.id,false,"NETWORK_UNAVAILABLE","");DirAccess.remove_absolute(paid._journal_path());load_verified_wallet();await frames()
 before=bridge.commands.size()
 paid.refresh();view._summon_paid(1)
 change_scene_to_file("res://scenes/ui/equipment_screen.tscn");await frames(12);reply(2000,20);await frames()
 check(bridge.commands.size()==before and not FileAccess.file_exists(paid._journal_path()),"leaving the page discards unsent intent without a late spend")
 var inv: Node=root.get_node("InventoryManager");var gear: Node=root.get_node("EquipmentManager")
 inv.item_counts.celestial_aegis_boots=2;inv.item_counts.nine_heavens_star_sword=1
 view=current_scene;view._show_detail("celestial_aegis_boots");await frames()
 var path_label: Label=view.detail.find_child("UpgradePathLabel",true,false) as Label
 check(path_label!=null and path_label.text.contains("hanya untuk senjata"),"armor explicitly explains star-only progression")
 check(view.sheet_actions.find_child("LevelAction",true,false)==null and gear.get_weapon_level_cap("celestial_aegis_boots")==0,"no invented permanent armor levels or balance changes")
 view._close_detail();view._show_detail("nine_heavens_star_sword");await frames()
 check(view.sheet_actions.find_child("LevelAction",true,false)!=null and gear.get_weapon_level_cap("nine_heavens_star_sword")==10,"weapon retains real level action and star-based cap")
 check(view.detail_values.level.text.contains("LEVEL WEAPON"),"weapon level is visible near the top of its detail")
 pavilion.paid_gameplay=original
 print("GEAR_SUMMON_RELIABILITY checks=%d failures=%d"%[checks,failures])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
