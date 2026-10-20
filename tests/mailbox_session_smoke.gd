extends SceneTree
class Auth extends Node:
 var calls: int = 0
 func get_id_token(_force: bool) -> void: calls += 1
class Wire extends Node:
 signal request_completed(result: int,code: int,headers: PackedStringArray,bytes: PackedByteArray)
 var sent: Array[Dictionary] = []
 func set_tls_options(_value: TLSOptions) -> void: pass
 func cancel_request() -> void: pass
 func request(url: String,_headers: PackedStringArray,method: int,body: String) -> Error:
  sent.append({"url":url,"method":method,"body":body});return OK
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
 checks+=1
 if not value: failures+=1;push_error("MAIL_SESSION "+label)
func mail(id: String,reward: bool=true) -> Dictionary:
 return {"id":"server:"+id,"mail_id":id,"title":"Mailbox QA","body":"A readable letter.","sender":"QA","reward":{"spirit_stone":10,"items":{}} if reward else {},"created_at":1700000000,"expires_at":1900000000,"read":false,"claimed":false,"pending":false,"can_claim":reward,"blocked_on_other_device":false,"cancelled":false,"expired":false}
func encoded(data: Dictionary) -> String:
 return Marshalls.raw_to_base64(JSON.stringify(data).to_utf8_buffer()).replace("+","-").replace("/","_").trim_suffix("=").trim_suffix("=")
func jwt(expiry: int) -> String:
 return encoded({"alg":"RS256"})+"."+encoded({"sub":"mail_session_owner","iss":"https://securetoken.google.com/jade-ascendant","aud":"jade-ascendant","exp":expiry})+".ZmFrZV9zaWduYXR1cmU"
func respond(server: Node,data: Dictionary,code: int=200) -> void:
 server._on_response(HTTPRequest.RESULT_SUCCESS,code,PackedStringArray(),JSON.stringify(data).to_utf8_buffer())
func run() -> void:
 create_timer(25.0).timeout.connect(func(): quit(1))
 if not OS.get_user_data_dir().contains("jade_mail_session_qa"):quit(2);return
 await create_timer(.3).timeout
 var server: Node=load("res://tests/fixtures/mail_session_manager.gd").new();root.add_child(server);server.set_process(false)
 var wire:=Wire.new();server.add_child(wire);server._http.queue_free();server._http=wire
 var auth:=Auth.new();server.add_child(auth);server._auth_node=auth
 var owner: String=server.fixture_owner
 server._owner=owner
 server._state={"installation_id":"1".repeat(32),"cache":{owner:[]}}
 var a: Dictionary=mail("%032x" % 30001);var b: Dictionary=mail("%032x" % 30002);var notice: Dictionary=mail("%032x" % 30003,false)
 root.get_node("ServerMailManager")._owner=owner
 server._on_profile({"server_registered":true,"server_status":"connected"});server._start_next()
 check(server._pending.kind=="list" and auth.calls==1,"startup prepares mailbox before any screen exists")
 var token: String=jwt(int(Time.get_unix_time_from_system())+3600)
 server._on_token(token)
 check(wire.sent.size()==1,"startup makes one authenticated inbox read")
 check(server._cached_token_until-Time.get_ticks_msec()>2900000,"token cache bounded by real expiry instead of fixed45seconds")
 check(server._token_cache_deadline(jwt(int(Time.get_unix_time_from_system())+30))<=Time.get_ticks_msec()+5,"near-expired token never receives a fresh45second cache")
 respond(server,{"owner_binding":owner,"version":1,"server_time":int(Time.get_unix_time_from_system()),"entries":[a,b,notice],"next_cursor":""})
 check(server.get_mail_ids().size()==3,"startup fills owner cache")
 server.refresh(true);check(server._queue.is_empty(),"opening fresh mailbox does not force another request")
 check(server.mark_read(a.id),"opening a letter records read intent")
 check(bool(server.get_mail(a.id).read) and a.mail_id in server._pending_read_ids(),"unread indicator clears locally while read sync is durable")
 check(not server.is_delivery_busy_for(a.id),"cosmetic read does not lock Claim")
 check(server.claim_mail(a.id),"claim can queue while cosmetic read is pending")
 server._start_next();check(server._pending.kind=="claim","user claim takes priority over cosmetic read")
 check(auth.calls==1 and wire.sent.size()==2,"claim reuses owner token acquired at startup")
 var before: int=root.get_node("ProgressionManager").spirit_stone
 respond(server,{"owner_binding":owner,"mail_id":a.mail_id,"installation_id":"1".repeat(32),"receipt_id":"%032x" % 40001,"delivery_state":"pending","reward":a.reward})
 check(root.get_node("ProgressionManager").spirit_stone==before+10,"only confirmed server delivery grants real fixture reward")
 check(server._has_local_receipt(a.mail_id),"claim journal retains permanent per-mail marker")
 server._start_next();check(server._pending.kind=="ack","receipt acknowledgement gets priority")
 respond(server,{"owner_binding":owner,"mail_id":a.mail_id,"delivery_state":"claimed"})
 check(server._queue.is_empty() and server._pending_read_ids().is_empty(),"existing server ACK replaces redundant cosmetic read")
 check(auth.calls==1 and wire.sent.size()==3,"claim and ACK did not reacquire identity")
 check(not server.claim_mail(a.id),"repeated claim cannot replay reward")
 check(server.can_delete_mail(notice.id),"empty notice is deletable immediately")
 # A stale catalog page cannot undo a read performed while the fetch was pending.
 check(server.mark_read(b.id),"second letter opened")
 server._pending={"kind":"list","id":"","cursor":""};server._refreshing=true;server._incoming.clear()
 check(server._accept_page({"version":1,"server_time":int(Time.get_unix_time_from_system()),"entries":[b],"next_cursor":""}),"stale page remains valid protocol")
 check(bool(server.get_mail(b.id).read),"stale read=false cannot resurrect unread dot")
 var restored: Node=load("res://tests/fixtures/mail_session_manager.gd").new();restored._load_state();restored._owner=owner
 check(bool(restored.get_mail(b.id).read) and b.mail_id in restored._pending_read_ids(),"read flag and pending intent survive real save reload")
 restored.free()
 # Restore fixture cache and verify bounded batching across background reads.
 server._queue.clear();server._pending={};server._busy=false
 var letters: Array=[]
 for index: int in 8: letters.append(mail("%032x" % (31000+index)))
 server._state.cache[owner]=letters
 server._enqueue("list","",{},"")
 server._enqueue("read",letters[0].id,{"mail_id":letters[0].mail_id})
 for entry: Dictionary in letters: check(server.claim_mail(entry.id),"queue letter for one burst")
 server._start_next();check(server._pending.kind=="claim_batch" and server._pending.parts.size()==8,"eight claims remain grouped despite background work at queue front")
 # No fake success for Delete All; keep cache until confirmed response.
 server._queue.clear();server._pending={};server._busy=false
 server._state.cache[owner]=[notice]
 check(server.delete_all_completed(),"delete all queues")
 check(server.get_mail_ids().size()==1,"queued deletion does not hide mail before confirmation")
 server._start_next();respond(server,{"owner_binding":owner,"ok":true,"deleted_count":1})
 check(server.get_mail_ids().is_empty(),"confirmed delete clears eligible notice")
 server._pending={"kind":"list","id":"","cursor":""};server._refreshing=true;server._incoming.clear()
 check(server._accept_page({"version":1,"server_time":int(Time.get_unix_time_from_system()),"entries":[notice],"next_cursor":""}),"old page validates after deletion")
 check(server.get_mail_ids().is_empty(),"stale list cannot resurrect confirmed deleted letter")
 server._queue.clear();server._pending={};server._busy=false
 server._state.cache[owner]=[a.duplicate(true),b.duplicate(true)]
 server.mark_all_read();server._start_next()
 server._state.cache[owner].append(notice.duplicate(true));server.mark_read(notice.id)
 respond(server,{"owner_binding":owner,"ok":true})
 check(notice.mail_id in server._pending_read_ids() and a.mail_id not in server._pending_read_ids(),"read-all confirmation preserves read intent created after request")
 # Auth rejection drops memory token and requests one explicit refresh only.
 server._state.cache[owner]=[b];server._enqueue("read",b.id,{"mail_id":b.mail_id});server._start_next()
 respond(server,{"error":"unauthenticated"},401);server._start_next()
 check(server._cached_token.is_empty() and auth.calls==2 and server._pending.refreshed_token,"401 invalidates cache and refreshes exactly once")
 server.fixture_owner="other-owner".sha256_text();server._on_token(token)
 check(server._queue.is_empty() and not server._busy and server._cached_token.is_empty(),"account switch cancels old operations and token")
 check(root.get_node("ProgressionManager").spirit_stone==before+10,"read delete retry and owner change never grant again")
 root.get_node("ServerMailManager")._owner=""
 server.queue_free();await process_frame
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 for index: int in 4:await process_frame
 print("MAILBOX_SESSION checks=",checks," failures=",failures,"; NATIVE_TRANSPORT=DOUBLE; REAL_LOCAL_REWARD_JOURNAL")
 call_deferred("quit",1 if failures else 0)
