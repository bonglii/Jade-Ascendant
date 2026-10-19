extends SceneTree
var Screen: GDScript
var Client: GDScript
var Sim: GDScript
var Dice: GDScript
var Arena: GDScript
var Batch: GDScript
class Native extends RefCounted:
 var sent: Array=[]
 func requestOdysseyV1(id: String,body: String)->void: sent.append([id,body])
class Event extends Node:
 signal changed
 signal finished(action: String,success: bool)
 var snapshot: Dictionary={}
 var status: String="connected"
 var busy: bool=false
 var last_action: Dictionary={}
 func refresh()->bool: return true
 func server_time()->int: return 1800000000
 func submit(action: Dictionary)->bool: last_action=action;busy=true;status="sending_action";changed.emit();return true
 func purchase_bonus_active()->bool: return bool(snapshot.get("purchase_bonus",{}).get("active",false))
class Authority extends Node:
 var entries: Array[Dictionary]=[]
 var grants: int=0
 var requests: Array[String]=[]
 func get_mail_entries()->Array[Dictionary]: return entries.duplicate(true)
 func get_mail(id: String)->Dictionary:
  for entry: Dictionary in entries:
   if entry.id==id: return entry.duplicate(true)
  return {}
 func claim_mail(id: String)->bool:
  requests.append(id)
  if id.begins_with("server:"):
   if id not in get_tree().root.get_node("ServerMailManager").pending_ids: get_tree().root.get_node("ServerMailManager").pending_ids.append(id)
   return true
  return grant(id)
 func grant(id: String)->bool:
  for entry: Dictionary in entries:
   if entry.id==id:
    if bool(entry.get("claimed",false)): return true
    entry.claimed=true;grants+=int(entry.reward.spirit_stone)
    get_tree().root.get_node("RewardManager").reward_granted.emit("pavilion","live_ops_mail_server_"+id.trim_prefix("server:") if id.begins_with("server:") else "live_ops_mail_"+id,entry.reward)
    get_tree().root.get_node("ServerMailManager").pending_ids.erase(id);return true
  return false
func _initialize()->void: call_deferred("run")
func check(value: bool,reason: String)->void:
 if not value: push_error(reason);quit(1)
func _mail(id: String,flags: Dictionary={})->Dictionary:
 var entry: Dictionary={"id":id,"reward":{"spirit_stone":10,"items":{}},"claimed":false,"can_claim":true};entry.merge(flags,true);return entry
func run()->void:
 var server_mail: Node=root.get_node("ServerMailManager");var save_manager: Node=root.get_node("SaveManager");var identity: Node=root.get_node("PlayerIdentityServerClient")
 create_timer(25).timeout.connect(func()->void: quit(1))
 Screen=load("res://scripts/ui/odyssey_screen.gd");Client=load("res://scripts/monetization/odyssey_client.gd");Sim=load("res://scripts/ui/liveops/odyssey_arena_sim.gd");Dice=load("res://scripts/ui/liveops/odyssey_dice.gd");Arena=load("res://scripts/ui/liveops/odyssey_arena.gd");Batch=load("res://scripts/ui/liveops/mailbox_claim_batch.gd")
 # The client and backend use exactly the same integer physics, not invented win flags.
 var vectors: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/odyssey_arena_vectors.json"))
 for item: Dictionary in vectors:
  var state: Dictionary=Sim.initial(int(item.seed))
  for digit: String in str(item.trace): Sim.step(state,int(digit))
  for key: String in state:
   if typeof(state[key])==TYPE_BOOL: check(state[key]==item.state[key],"Arena bool parity: "+key)
   else: check(int(state[key])==int(item.state[key]),"Arena numeric parity: "+key)
 check(Client.canonical_command({"event_id":"dragon-test","request_id":"a".repeat(32),"revision":0,"action":{"kind":"arena_finish","trace":"0".repeat(600),"abandon":false}}).size()==4,"Arena command must be bounded and journalable")
 check(Client.canonical_command({"event_id":"dragon-test","request_id":"a".repeat(32),"revision":0,"action":{"kind":"arena_finish","trace":"9","abandon":false}}).is_empty(),"Reject invalid movement input")
 root.get_node("SettingsManager").reduced_effects=false
 var die: Control=Dice.new();root.add_child(die);die.start();die.resolve(6)
 for n: int in range(20): die._process(0.05)
 check(die.rolling,"Die should not settle before the readable spin")
 for n: int in range(10): die._process(0.05)
 check(not die.rolling and die.face==6,"Die must reveal the authoritative face once")
 die.queue_free();root.get_node("SettingsManager").reduced_effects=true;await process_frame
 for dimensions: Vector2i in [Vector2i(360,640),Vector2i(412,915),Vector2i(648,1152),Vector2i(840,400)]:
  var view:=SubViewport.new();view.size=dimensions;root.add_child(view)
  var client:=Event.new();client.name="OdysseyClient";root.add_child(client)
  client.snapshot={"owner_binding":"a".repeat(64),"event":{"id":"dragon-test","enabled":true,"purchases_enabled":true,"starts_at":1799999900,"ends_at":1801000000},"state":{"tickets":3,"daily_rolls":5,"missions":[1],"milestones":[],"daily_gifts":3,"daily_guardians":0,"task_claims":[],"day":"2027-01-15","rolls":12,"position":0},"purchase_bonus":{"active":true,"offers":[{"product_id":"jade_satchel_550","jade":550,"dice":3,"claimed":false}]}}
  var screen: Control=Screen.new();screen.size=Vector2(dimensions);view.add_child(screen);await process_frame;await process_frame
  screen._missions();await process_frame;await process_frame
  check(screen._mission_handles.size()==6,"Six daily rows must be present")
  var handles: Array=screen._mission_handles
  check(handles[0].button.disabled and handles[1].button.disabled,"Login and claimed mission must not remain claimable")
  check(not handles[2].button.disabled and not handles[4].button.disabled,"Available roll/material missions should be claimable")
  var panel: Control=screen._modal_panel;check(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(panel.get_global_rect()),"Popup must remain within the viewport")
  for handle: Dictionary in handles: check(handle.button.get_global_rect().end.x<=panel.get_global_rect().end.x-16,"Mission claim button overflow")
  client.busy=true;client.status="refreshing";client.changed.emit()
  for poll: int in range(8):
   check(not handles[2].button.disabled and not screen.missions_button.disabled and not screen.roll.disabled,"Read-only polls must not flicker enabled controls")
   client.busy=false;client.status="connected";client.changed.emit();client.busy=true;client.status="refreshing";client.changed.emit()
  screen.roll.pressed.emit();screen.roll.pressed.emit();check(screen._queued_action.get("kind")=="roll","The actual enabled Roll button queues exactly one action during a read")
  screen._queued_action={}
  screen._submit({"kind":"mission","mission":3});check(screen._queued_action.get("mission")==3,"Tap during a read should queue once")
  screen._queued_action={};client.busy=false;client.status="connected";client.changed.emit()
  handles[2].button.pressed.emit();check(is_instance_valid(screen.modal),"Claim must preserve the open mission sheet")
  check(handles[2].button.disabled and screen._mission_all.disabled,"Pending action must fence all duplicate taps")
  client.busy=false;client.status="connected";client.snapshot.state.missions=[1,3];client.changed.emit()
  check(handles[2].button.disabled and handles[2].button.text=="DIKLAIM","Claimed status should refresh without rebuilding the sheet")
  screen._close_modal();screen._journey_rewards();await process_frame;await process_frame
  check(screen._modal_panel.size.y<=float(dimensions.y),"Journey sheet height")
  screen._close_modal();screen._shop();await process_frame;await process_frame
  check(screen._modal_panel.size.x<=float(dimensions.x),"Shop width")
  screen._close_modal()
  client.busy=true;client.status="refreshing";screen._routes();await process_frame
  var route: Button=screen.modal.find_children("*","Button",true,false).filter(func(node: Node)->bool:return node.text=="QUIET GROVE")[0]
  route.pressed.emit();route.pressed.emit();check(screen._queued_action.get("kind")=="route","Route tap during a read queues once instead of disappearing")
  screen._queued_action={};screen._confirm_pack(1,10);await process_frame
  var confirm: Button=screen.modal.find_children("*","Button",true,false).filter(func(node: Node)->bool:return node.text.begins_with("CONFIRM ·"))[0]
  confirm.pressed.emit();confirm.pressed.emit();check(screen._queued_action.get("kind")=="buy_dice","Jade exchange queues the confirmed action once during a read")
  client.busy=false;client.status="connected";screen._process(0.0)
  check(client.last_action.get("kind")=="buy_dice" and screen._queued_action.is_empty(),"Queued exchange dispatches once after the read")
  screen._queued_action={};client.busy=false;client.status="connected";screen._close_modal()
  var arena: Control=Arena.new();arena.client=client;arena.battle={"mode":"arena","seed":917,"started_at":1800000000,"deadline":1800000180};arena.size=Vector2(dimensions);view.add_child(arena);await process_frame
  arena.set_process(false);check(arena._pad().x+arena._radius()<arena._retreat.position.x,"Joystick must not overlap Retreat on a narrow phone")
  arena.queue_free()
  client.busy=false;client.status="connected";client.snapshot.state.battle={"mode":"arena","seed":917,"started_at":1800000000,"deadline":1800000180}
  screen._battle();await process_frame
  var active_arena: Control=screen._arena;active_arena._finish(true)
  check(is_instance_valid(screen._arena) and screen._arena==active_arena,"Arena must remain visible while its result awaits confirmation")
  client.busy=false;client.snapshot.state.battle=null;client.changed.emit()
  check(screen._arena==null,"Arena closes after authoritative result confirms")
  screen.queue_free();client.queue_free();view.queue_free();await process_frame
 for file: String in ["scripts/ui/liveops/mailbox_screen.gd","scripts/ui/reward_claim_result_presenter.gd","scripts/ui/reward_delivery_presenter.gd"]:
  var script: GDScript=load("res://"+file)
  check(script!=null and script.can_instantiate(),"Mailbox integration source must compile: "+file)
 var result_script: GDScript=load("res://scripts/ui/reward_claim_result_presenter.gd")
 var result_presenter: Node=result_script.new()
 var merged: Dictionary=result_presenter._merge_rewards({"celestial_jade":100,"pavilion_seal":2},{"celestial_jade":50,"pavilion_seal":1})
 check(int(merged.get("celestial_jade",0))==150 and int(merged.get("pavilion_seal",0))==3,"Claim All summary must preserve Jade and Pavilion Seals")
 result_presenter.free()
 # Bulk claims serialize existing authorities, stop on uncertain failures, and resume without duplicate grants.
 var authority:=Authority.new();authority.name="LiveOpsManager";root.add_child(authority)
 authority.entries=[_mail("local_a"),_mail("local_b"),_mail("server:c"),_mail("claimed",{"claimed":true}),_mail("expired",{"expired":true}),_mail("blocked",{"blocked_on_other_device":true})]
 var batch: Node=Batch.new();batch.authority=authority;batch.name="MailboxClaimBatch";authority.add_child(batch);batch.set_process(false)
 batch.start();batch.start();check(batch.total==3,"Bulk selection must exclude claimed, expired and blocked letters")
 for n: int in range(3): batch._process(0.3)
 check(authority.grants==20 and server_mail.is_busy_for("server:c"),"Server claim must stay serialized and ungranted until confirmation")
 check(batch.owns_reward("live_ops_mail_server_c") and not batch.owns_reward("live_ops_mail_other"),"Suppress only this batch's exact reward source")
 server_mail.pending_ids.clear();server_mail.status="Offline";batch._sent_at=Time.get_ticks_msec()-2000;batch._process(0.3)
 check(batch.paused,"Uncertain network failure must pause the bulk coordinator")
 batch.start();batch._process(0.3);authority.grant("server:c");batch._process(0.3)
 check(not batch.active and batch.claimed==3 and authority.grants==30,"Bulk completion without duplicate credits")
 batch.start();check(not batch.active and authority.grants==30,"Bulk replay must be a no-op")
 authority.entries.append(_mail("later"));save_manager.blocked=true;batch.start();check(not batch.active,"Read-only save must block bulk claims")
 save_manager.blocked=false;batch.start();identity.binding="b".repeat(64);batch._process(0.3);check(not batch.active,"Account switch must cancel bulk state")
 authority.queue_free();await process_frame
 print("ODYSSEY_RELIABILITY_UI=PASS; FOUR_VIEWPORTS; SIX_DAILIES; CLAIM_FENCES; STABLE_SHEET; DICE_PACING; ARENA_PARITY; JOYSTICK_BOUNDS; MAIL_BULK_RETRY_OWNERSHIP")
 quit()
