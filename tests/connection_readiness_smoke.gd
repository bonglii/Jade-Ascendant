extends SceneTree
const Paid=preload("res://scripts/monetization/paid_gameplay_v2.gd")
const Event=preload("res://scripts/monetization/odyssey_client.gd")
class Native extends RefCounted:
 var sent: Array[Dictionary]=[]
 func requestPaidGameplayV2(id: String,body: String) -> void:sent.append({"kind":"paid","id":id,"body":body})
 func requestOdysseyV1(id: String,body: String) -> void:sent.append({"kind":"event","id":id,"body":body})
class PaidHarness extends Paid:
 var live: String="a".repeat(64)
 var native:=Native.new()
 func _ready() -> void:set_process(false)
 func _live_binding() -> String:return live
 func _bridge() -> Object:return native
class EventHarness extends Event:
 var live: String="e".repeat(64)
 var native:=Native.new()
 func _ready() -> void:set_process(false)
 func _live_binding() -> String:return live
 func _bridge() -> Object:return native
 func _can_prewarm() -> bool:return true
var checks: int=0
var failures: int=0
var evidence: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CONNECTION_READINESS "+label)
func state(owner: String) -> Dictionary:
 return {"paid_gameplay_version":2,"account_binding":owner,"catalog_hash":Paid.HASH,"state":"ready","revision":0,"wallet":{"balance":1500,"revision":1},"inventory":{"cloudstep_boots":2},"stars":{"cloudstep_boots":2},"slots":{"armament":"","robe":"","bracer":"","boots":"","pendant":""},"pity":{"rare_plus":0,"epic_plus":10,"legendary":10},"wish":"","wish_guaranteed":false,"lifetime_pulls":10,"rates":{"common":6000,"rare":2900,"epic":900,"legendary":200},"lease_seconds":120}
func event_data(owner: String) -> Dictionary:
 var now: int=int(Time.get_unix_time_from_system())
 return {"owner_binding":owner,"server_time":now,"event":{"id":"dragon-readiness","enabled":true,"purchases_enabled":false,"starts_at":now-60,"ends_at":now+3600},"state":{"tickets":3,"day":Time.get_date_string_from_system(true),"missions":[],"milestones":[]}}
func put(path: String,value: Variant) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_connection_combat_qa"):quit(2);return
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 var paid:=PaidHarness.new();root.add_child(paid);paid._binding=paid.live
 check(not paid.can_summon(1),"unverified paid state never allows a summon")
 paid.snapshot=state(paid.live);paid._expires=Time.get_ticks_msec()+120000
 check(Paid.valid_snapshot(paid.snapshot,paid.live),"fixture uses production paid snapshot schema")
 var expires: int=paid._expires
 check(paid.refresh_if_stale() and paid.native.sent.is_empty(),"opening paid page reuses a current verified read")
 paid._identity_changed(true)
 check(paid.native.sent.is_empty() and paid._expires==expires,"repeated identity signals do not fetch or extend a lease")
 paid._expires=Time.get_ticks_msec()+100000
 check(paid.refresh_if_stale() and paid.native.sent.size()==1,"stale read starts exactly one request")
 paid.refresh_if_stale();paid.refresh_if_stale()
 check(paid.native.sent.size()==1 and paid.native.sent[0].body=="","concurrent readiness requests coalesce into one GET")
 paid._on_result(paid._request_id,true,"PAID_GAMEPLAY_VERIFIED",JSON.stringify({"snapshot":state(paid.live),"operation":null}))
 check(paid.can_summon(1) and paid.paid_balance()==1500,"only validated read restores paid authority")
 paid._expires=Time.get_ticks_msec()-1
 check(not paid.can_summon(1) and paid.paid_balance()==0,"expired paid lease never becomes spendable")
 paid.snapshot=state(paid.live);paid._expires=Time.get_ticks_msec()+120000;paid.live="b".repeat(64)
 check(not paid.is_verified_ready(),"account switch invalidates authority before the next frame")
 paid.free()
 var client:=EventHarness.new();root.add_child(client)
 client._binding=client.live
 for path: String in [client._path(),client._preview_path()]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 client._binding=""
 var started: int=Time.get_ticks_msec();client._process(0)
 check(client.native.sent.size()==1 and client.busy,"event prewarm starts on the identity frame")
 evidence.initial_dispatch_ms=Time.get_ticks_msec()-started
 client._on_result(client._request_id,true,"ODYSSEY_VERIFIED",JSON.stringify(event_data(client.live)))
 check(client.status=="connected" and not client.get_event_preview().is_empty(),"confirmed event metadata becomes available for fast discovery")
 var received: int=client._received_msec
 var sent_before: int=client.native.sent.size()
 check(client.refresh() and client.native.sent.size()==sent_before and client._received_msec==received,"owner fresh reads coalesce without extending the server observation")
 client._received_msec=Time.get_ticks_msec()-20000;client._warm_next_at=0;client._prewarm_if_due()
 check(client.native.sent.size()==sent_before,"owner thirty-second prewarm TTL is retained")
 client._received_msec=Time.get_ticks_msec()-30001;client._warm_next_at=0;client._prewarm_if_due()
 check(client.native.sent.size()==sent_before+1 and client.busy,"stale thirty-second discovery refreshes once")
 client._on_result(client._request_id,true,"ODYSSEY_VERIFIED",JSON.stringify(event_data(client.live)))
 var cache: String=client._preview_path()
 var text: String=FileAccess.get_file_as_string(cache)
 check(not text.contains("wallet") and not text.contains("tickets") and not text.contains("inventory") and not text.contains("missions"),"preview cache contains no money, progress or rewards")
 client.snapshot={};client.status="connecting";client._load_event_preview()
 check(not client.get_event_preview().is_empty(),"restart can display an active known event while connecting")
 check(not client.event_enabled() and not client.submit({"kind":"roll"}),"preview never enables a roll or other event mutation")
 var saved: Dictionary=JSON.parse_string(text)
 var bad: Dictionary=saved.duplicate(true);bad.binding="f".repeat(64);put(cache,bad);client._load_event_preview()
 check(client.get_event_preview().is_empty(),"another account's metadata is rejected")
 bad=saved.duplicate(true);bad.observed_unix=int(Time.get_unix_time_from_system())-901;put(cache,bad);client._load_event_preview()
 check(client.get_event_preview().is_empty(),"old discovery metadata expires after fifteen minutes")
 bad=saved.duplicate(true);bad.event.ends_at=int(Time.get_unix_time_from_system())-1;put(cache,bad);client._load_event_preview()
 check(client.get_event_preview().is_empty(),"expired event cannot reappear from cache")
 bad=saved.duplicate(true);bad.wallet={"balance":1000000};put(cache,bad);client._load_event_preview()
 check(client.get_event_preview().is_empty(),"extra authority fields invalidate discovery metadata")
 put(cache,saved);client._load_event_preview();client.live="f".repeat(64)
 check(client.get_event_preview().is_empty(),"event discovery is fenced immediately on account switch")
 client.live="e".repeat(64);client._load_event_preview()
 # A crash can leave an authorized action journal before the event tile is visible.
 var command: Dictionary={"event_id":"dragon-readiness","request_id":"d".repeat(32),"revision":3,"action":{"kind":"roll"}}
 put(client._path(),command);client.busy=false;client._request_id="";client.snapshot={};client._warm_next_at=0
 var count: int=client.native.sent.size();client._prewarm_if_due()
 check(client.native.sent.size()==count+1,"pending durable action no longer blocks event prewarm")
 evidence.recovered_wire={"request_id":client.native.sent[-1].id,"raw":client.native.sent[-1].body,"expected":JSON.stringify(command)}
 check(client.native.sent[-1].id==command.request_id and client.native.sent[-1].body==JSON.stringify(command),"recovery preserves the original request and integer command wire")
 check(FileAccess.file_exists(client._path()) and not client.event_enabled(),"uncertain recovery keeps its journal and cannot invent an event")
 client._on_result(client._request_id,true,"ODYSSEY_VERIFIED",JSON.stringify(event_data(client.live)))
 check(not FileAccess.file_exists(client._path()),"only an acknowledged recovery removes the pending action")
 # Recovery still precedes a fresh snapshot, retaining the original action ID.
 client.snapshot=event_data(client.live);client._received_msec=Time.get_ticks_msec();client._warm_next_at=0
 command.request_id="c".repeat(32);put(client._path(),command);count=client.native.sent.size();client._prewarm_if_due()
 check(client.native.sent.size()==count+1 and client.native.sent[-1].id==command.request_id,"fresh coalescing never suppresses exact pending-command recovery")
 client._on_result(client._request_id,true,"ODYSSEY_VERIFIED",JSON.stringify(event_data(client.live)))
 client.snapshot=event_data(client.live);client.snapshot.event.enabled=false;client._store_event_preview()
 check(not FileAccess.file_exists(cache) and client.get_event_preview().is_empty(),"verified pause removes cached event discovery")
 evidence.readiness={"preview_authority":"NONE","paid_lease_seconds":120,"pending_request_preserved":true,"external_network":"NONE"}
 client.free();await process_frame
 print("CONNECTION_READINESS checks=%d failures=%d evidence=%s"%[checks,failures,JSON.stringify(evidence)])
 var file:=FileAccess.open("user://connection-readiness.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"));file.close()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
