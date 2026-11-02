extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("EVENT_PREWARM "+label)
func run() -> void:
 create_timer(25.0).timeout.connect(func(): quit(1))
 if not OS.get_user_data_dir().contains("jade_mail_session_qa"):quit(2);return
 await process_frame
 var existing: Node=root.get_node("OdysseyClient");existing.name="ActualOdysseyClient"
 var client: Node=load("res://tests/fixtures/odyssey_prewarm_client.gd").new();client.name="OdysseyClient";root.add_child(client);client.set_process(false)
 client._binding=client.live_binding;client._warm_next_at=0
 client._prewarm_if_due()
 check(client.dispatches==[{}],"startup warmup dispatches one read without opening event screen")
 client.busy=false;client.snapshot={"owner_binding":client.live_binding,"event":{"enabled":true}};client._received_msec=Time.get_ticks_msec()
 check(client.refresh_if_stale() and client.dispatches.size()==1,"opening a fresh event uses existing snapshot")
 client._warm_next_at=0;client._prewarm_if_due()
 check(client.dispatches.size()==1,"background warmup respects snapshot TTL")
 client._received_msec=Time.get_ticks_msec()-180001;client._warm_next_at=0
 client.pending_command={"event_id":"dragon-test","request_id":"a".repeat(32),"revision":3,"action":{"kind":"ad_intent"}}
 var saved: Dictionary=client.pending_command.duplicate(true)
 client._prewarm_if_due()
 check(client.dispatches.size()==2 and client.dispatches[-1]==saved,"startup recovers the exact existing ad-intent ID without opening an SDK ad")
 client.busy=false;client.pending_command.action={"kind":"roll"};saved=client.pending_command.duplicate(true);client._warm_next_at=0;client._prewarm_if_due()
 check(client.dispatches.size()==3 and client.dispatches[-1]==saved,"startup recovers an existing durable mutation without generating a new command")
 client.busy=false;client.pending_command={};client._backgrounded=true;client._warm_next_at=0;client._prewarm_if_due()
 check(client.dispatches.size()==3,"no background network warmup while app is suspended")
 client._backgrounded=false;client._warm_next_at=0;client._prewarm_if_due()
 check(client.dispatches.size()==4 and client.dispatches[-1].is_empty(),"stale snapshot refresh remains read-only when no recovery exists")
 client.live_binding="new_owner".sha256_text();client._process(0.0)
 check(client.snapshot.is_empty() and not client.busy,"account change clears previous event snapshot")
 client.queue_free();existing.name="OdysseyClient";await process_frame
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 for index: int in 4:await process_frame
 print("ODYSSEY_PREWARM_SESSION checks=",checks," failures=",failures,"; EXACT_RECOVERY; ADS=NONE; PURCHASE=NONE")
 call_deferred("quit",1 if failures else 0)
