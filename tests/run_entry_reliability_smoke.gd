extends SceneTree
const Hints=preload("res://scripts/managers/account_hint_store.gd")
const Messages=preload("res://scripts/data/run_entry_messages.gd")
const Paid=preload("res://scripts/monetization/paid_gameplay_v2.gd")
var checks: int=0
var failures: int=0
class PaidGate extends "res://tests/fixtures/paid_gameplay_manager_v2.gd":
 var saved: Dictionary={}
 func _checkpoint_for_gate() -> Dictionary:return saved.duplicate(true)
class EventGate extends "res://scripts/monetization/odyssey_client.gd":
 var live: String="a".repeat(64)
 var replies: Dictionary={}
 var dispatch_count: int=0
 var pending_test: Dictionary={}
 var fail_status: String=""
 func _ready() -> void:set_process(false)
 func _live_binding() -> String:return live
 func _pending() -> Dictionary:return pending_test.duplicate(true)
 func _dispatch(command: Dictionary) -> bool:
  dispatch_count+=1;_command=command;_request_id="1".repeat(32);busy=true
  _on_result.call_deferred(_request_id,fail_status.is_empty(),"OK" if fail_status.is_empty() else fail_status,JSON.stringify(replies));return true
class RefusingEvent extends Node:
 var run_gate_error: String="COMPASS_GRANT_REQUIRED"
 func prepare_scene_run(_continuing: bool) -> bool:return false
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("RUN_ENTRY "+caption)
func settle(count: int=10) -> void:
 for i: int in range(count):await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(70).timeout.connect(func():quit(1))
 await settle()
 check(Hints.mask_email("cultivator3388@gmail.com")=="••••3388@gmail.com","only email suffix is retained")
 for bad: Variant in [null,{},"bad", "name@example.com\nBAD", "x@domain.com"]:check(Hints.mask_email(bad).is_empty(),"bad email does not become a hint")
 Hints.remember("a".repeat(64),"cultivator3388@gmail.com")
 check(Hints.lookup("a".repeat(64))=="••••3388@gmail.com","known masked hint survives file roundtrip")
 check(not FileAccess.get_file_as_string(Hints.PATH).contains("cultivator"),"hint store contains no raw email")
 check(Hints.lookup("b".repeat(64)).is_empty(),"unknown account never gets another account hint")
 for reason: String in ["CONNECTION_UNAVAILABLE","COMPASS_GRANT_REQUIRED","COMPASS_VERIFICATION_UNAVAILABLE","RECOVERY_REQUIRED","APP_VERIFICATION_UNAVAILABLE"]:
  check(not Messages.view(reason,"en","••••3388@gmail.com").body.contains("••••3388"),"only proven mismatch displays owner hint "+reason)
 check(Messages.view("ACCOUNT_MISMATCH","id",Hints.lookup("a".repeat(64))).body.contains("••••3388"),"mismatch includes known previous email suffix")
 check(Messages.view("ACCOUNT_MISMATCH","en").body.contains("not recorded"),"legacy unknown email is explained honestly")
 var paid:=PaidGate.new();root.add_child(paid)
 paid.saved={"paid_run_ref":{"version":1,"binding":"a".repeat(64),"run_id":"12345678-1234-4234-8234-123456789abc"}}
 paid.test_binding="b".repeat(64)
 check(not await paid.prepare_scene_run(true) and paid.run_gate_error=="ACCOUNT_MISMATCH","different binding is a real account mismatch")
 check(paid.run_gate_owner_hint=="••••3388@gmail.com","original account is identified using bounded local metadata")
 paid.test_binding="";check(not await paid.prepare_scene_run(true) and paid.run_gate_error=="SIGN_IN_REQUIRED","missing identity is not account mismatch")
 paid.saved={};check(not await paid.prepare_scene_run(true) and paid.run_gate_error=="CHECKPOINT_UNAVAILABLE","missing checkpoint has its own reason")
 paid.last_transport_stage="APP_CHECK_UNAVAILABLE";check(paid._transport_gate_reason()=="APP_VERIFICATION_UNAVAILABLE","App Check failure does not accuse Google login")
 paid.queue_free();await settle()
 var eq: Node=root.get_node("EquipmentManager");eq.equipped_item_ids.armament="heavenweaver_compass"
 root.get_node("InventoryManager").add_item("heavenweaver_compass",1)
 var client:=EventGate.new();root.add_child(client);client._binding=client.live
 client.snapshot={"compass_authorized":true};client._received_msec=Time.get_ticks_msec();client.status="connected"
 check(await client.prepare_scene_run(false) and client.dispatch_count==0,"fresh account-owned Compass lease avoids a new request")
 client._received_msec=Time.get_ticks_msec()-70000
 client.replies={"owner_binding":client.live,"compass_authorized":true,"state":{"missions":[],"milestones":[],"compass_verification":"verified"}}
 check(await client.prepare_scene_run(false) and client.dispatch_count==1,"expired lease refreshes before combat")
 client.snapshot={};client.replies.compass_authorized=false;client.replies.state.compass_verification="not_granted"
 check(not await client.prepare_scene_run(false) and client.run_gate_error=="COMPASS_GRANT_REQUIRED","inventory without authoritative grant has a specific reason")
 client.replies.state.compass_verification="unavailable"
 check(not await client.prepare_scene_run(false) and client.run_gate_error=="COMPASS_VERIFICATION_UNAVAILABLE","server grant outage is not missing ownership")
 client.snapshot={"compass_authorized":true};client._received_msec=Time.get_ticks_msec();client.status="ACCOUNT_HELD";client.fail_status="ACCOUNT_HELD"
 check(not await client.prepare_scene_run(false) and client.run_gate_error=="ACCOUNT_HELD","explicit hold cannot reuse a cached positive lease")
 client.snapshot={};client.fail_status="APP_CHECK_UNAVAILABLE"
 check(not await client.prepare_scene_run(false) and client.run_gate_error=="APP_VERIFICATION_UNAVAILABLE","event App Check failure retains its category")
 client.fail_status="UNAUTHENTICATED"
 check(not await client.prepare_scene_run(false) and client.run_gate_error=="SIGN_IN_REQUIRED","event token rejection has a sign-in category")
 client.queue_free();await settle()
 var transition: Node=root.get_node("SceneTransitionManager")
 var hub:=Control.new();root.add_child(hub);current_scene=hub
 for dimensions: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=dimensions
  var notice: Control=preload("res://scripts/ui/run_verification_notice.gd").open(transition,"ACCOUNT_MISMATCH",Hints.lookup("a".repeat(64)))
  await settle(16)
  var paper: Control=notice.find_child("VerificationPaper",true,false)
  check(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(paper.get_global_rect()),"notice remains inside phone "+str(dimensions))
  check(paper.get_global_rect().encloses(notice.find_child("VerificationScroll",true,false).get_global_rect()),"description scroll stays inside frame "+str(dimensions))
  notice.close();await settle()
 current_scene=null;hub.queue_free();await settle()
 var original: Node=root.get_node("OdysseyClient");original.name="OriginalOdysseyClient";original.set_process(false)
 var refusing:=RefusingEvent.new();refusing.name="OdysseyClient";root.add_child(refusing)
 var saver: Node=root.get_node("SaveManager");saver.write_save_data("checkpoint",{"fixture_sentinel":"preserve until gates pass"})
 var before: Dictionary=saver.read_save_data("checkpoint").data.duplicate(true)
 var journey: Node=root.get_node("JourneyManager");journey.select_stage(1,1);journey.clear_active_run()
 var stage: Control=load("res://scenes/ui/stage_select.tscn").instantiate();root.add_child(stage);current_scene=stage;await settle()
 stage._start_selected_stage();stage._start_selected_stage()
 while transition.is_transitioning:await process_frame
 check(current_scene==stage and not paused,"refused weapon leaves old menu usable")
 check(saver.read_save_data("checkpoint").data==before,"new-run failure preserves old checkpoint exactly")
 check(not journey.has_active_run(),"failed entry does not create a phantom active Journey")
 check(transition.get_node_or_null("PaidRunNotice")!=null,"specific gate failure opens one styled notice")
 transition.get_node("PaidRunNotice").close()
 current_scene=null;stage.queue_free();refusing.queue_free();await settle();original.name="OdysseyClient"
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("RUN_ENTRY_RELIABILITY checks=",checks," failures=",failures)
 quit(1 if failures else 0)
