extends SceneTree
const DNS=preload("res://scripts/managers/trusted_profile_dns.gd")
class FakeAuth extends Node:
 var uid: String="profile_雪_qa"
 var forces: Array[bool]=[]
 func is_signed_in() -> bool:return not uid.is_empty()
 func get_current_user_data() -> Dictionary:return {"uid":uid}
 func get_id_token(force: bool) -> void:forces.append(force)
var checks: int=0
var failures: int=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("PROFILE_RESILIENCE_FAIL "+message)
func _initialize() -> void:run.call_deferred()
func token(uid: String,audience: String="jade-ascendant") -> String:
 var header: String=Marshalls.utf8_to_base64('{"alg":"RS256"}').replace("+","-").replace("/","_").trim_suffix("=").trim_suffix("=")
 var claims: String=Marshalls.utf8_to_base64(JSON.stringify({"iss":"https://securetoken.google.com/jade-ascendant","aud":audience,"sub":uid,"display_name":"林月"})).replace("+","-").replace("/","_").trim_suffix("=").trim_suffix("=")
 return header+"."+claims+".c2ln"
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_profile_resilience_qa"):quit(2);return
 await create_timer(.5).timeout
 for value: String in ["0.0.0.0","10.2.1.1","127.1.2.3","169.254.2.2","172.31.1.1","192.168.1.2","100.100.1.2","192.0.2.1","198.18.1.1","198.51.100.3","203.0.113.3","224.1.1.1","255.255.255.255","1.02.3.4","-1.2.3.4","::1"]:check(not DNS.public_ipv4(value),"reject private/reserved "+value)
 for value: String in ["1.1.1.1","8.8.8.8","104.21.21.160","172.67.199.90"]:check(DNS.public_ipv4(value),"accept public "+value)
 var hostname: String="jade-ascendant-player.jade-ascendant-studio.workers.dev"
 var payload: Dictionary={"Status":0,"Question":[{"name":hostname,"type":1}],"Answer":[{"name":hostname,"type":5,"data":"edge.example.","TTL":60},{"name":"edge.example.","type":1,"data":"104.21.21.160","TTL":120},{"name":"unrelated.example.","type":1,"data":"8.8.8.8","TTL":20}]}
 var decoded: Dictionary=DNS.decode(JSON.stringify(payload).to_utf8_buffer(),hostname)
 check(decoded.addresses==PackedStringArray(["104.21.21.160"]) and decoded.ttl==60,"related CNAME/A only, shortest TTL")
 payload.Answer[0].TTL=0;check(DNS.decode(JSON.stringify(payload).to_utf8_buffer(),hostname).ttl==0,"zero TTL respected")
 payload.Status=false;check(DNS.decode(JSON.stringify(payload).to_utf8_buffer(),hostname).is_empty(),"boolean DNS status rejected")
 payload.Status=0
 payload.Question[0].name="evil.example";check(DNS.decode(JSON.stringify(payload).to_utf8_buffer(),hostname).is_empty(),"question must match fixed hostname")
 payload.Question[0].name=hostname;payload.TC=true;check(DNS.decode(JSON.stringify(payload).to_utf8_buffer(),hostname).is_empty(),"truncated DNS rejected")
 check(DNS.decode(PackedByteArray([255,254]),hostname).is_empty(),"invalid UTF8 rejected")
 var auth:=FakeAuth.new();root.add_child(auth)
 var owner: String=auth.uid.sha256_text()
 check(DNS.token_owner_matches(token(auth.uid),owner),"Unicode owner correlated")
 check(not DNS.token_owner_matches(token("old-account"),owner),"old-account callback rejected")
 check(not DNS.token_owner_matches(token(auth.uid,"other-project"),owner),"wrong project rejected")
 check(not DNS.token_owner_matches("bad.token.value",owner),"malformed token rejected")
 # Mirror a real signed-in current profile; stale-token check must not emulate sign-out.
 root.get_node("PlayerIdentityServerClient")._auth=auth
 var mailer: Node=root.get_node("ServerMailManager")
 mailer._owner=owner;mailer._busy=true;mailer._waiting_token=true;mailer._pending={"kind":"list","owner":owner}
 mailer._on_token(token("old-account"))
 check(mailer._waiting_token and mailer._busy,"mail ignores late token without consuming pending request")
 check(mailer._pending.owner==owner,"mail keeps current owner binding")
 mailer._busy=false;mailer._waiting_token=false;mailer._pending={}
 var client: Node=load("res://tests/fixtures/profile_resilience_client.gd").new();root.add_child(client)
 await process_frame;await process_frame
 client._auth=auth;client._owner=owner
 client.connect_profile();check(auth.forces==[false],"normal hostname route requests token once")
 check(not client._prefer_ipv4,"healthy IPv6-only networks use normal hostname first")
 client._on_token(token("old-account"));check(client._token_waiting and client.sent==0,"late old token ignored without consuming pending callback")
 client._on_token(token(auth.uid));check(client.sent==1 and not client._token_waiting,"current token sent once")
 var nonce: int=client._nonce
 client._on_response(HTTPRequest.RESULT_SUCCESS,401,[],PackedByteArray(),nonce)
 check(auth.forces==[false,true] and client._token_waiting,"one forced fresh token after 401")
 client._on_token(token(auth.uid));client._on_response(HTTPRequest.RESULT_SUCCESS,401,[],PackedByteArray(),client._nonce)
 check(not client._busy and root.get_node("PlayerIdentityManager").get_profile_snapshot().server_status=="http_401","second 401 backs off")
 client._busy=true;client._pending_owner=owner
 client._on_response(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"version":1,"public_uid":"JA123456789A","owner_binding":owner}).to_utf8_buffer(),nonce)
 check(client._busy,"old HTTP completion ignored")
 client._on_response(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"version":1,"public_uid":"JA123456789A","owner_binding":owner}).to_utf8_buffer(),client._nonce)
 check(root.get_node("PlayerIdentityManager").get_profile_snapshot().server_status=="connected","validated registration persists identity")
 var count: int=auth.forces.size();client._refresh_auth();check(auth.forces.size()==count,"duplicate auth signal does not reconnect connected account")
 client._busy=true;client._pending_owner=owner;client._trusted_attempted=false
 client._on_response(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,0,[],PackedByteArray(),client._nonce)
 check(client.queries==1 and client._busy,"TLS failure starts finite encrypted DNS recovery")
 var dns_nonce: int=client._trusted_nonce
 client._on_trusted_dns(HTTPRequest.RESULT_SUCCESS,200,[],PackedByteArray(),dns_nonce-1,owner,0)
 check(client.queries==1,"stale DNS callback ignored")
 client._on_trusted_dns(HTTPRequest.RESULT_SUCCESS,302,[],PackedByteArray(),dns_nonce,owner,0)
 check(client.queries==2 and client._trusted_provider==1,"redirect is denied, second fixed resolver tried")
 payload.TC=false;payload.Answer[0].TTL=0
 client._on_trusted_dns(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify(payload).to_utf8_buffer(),dns_nonce,owner,1)
 check(client._ipv4_address=="104.21.21.160" and client._token_waiting,"zero TTL answer usable for one current attempt")
 check(not client._route_tls_options().is_unsafe_client() and client._route_tls_options().get_common_name_override()==hostname,"original SNI/certificate preserved")
 check(client.get_connection_snapshot().route=="encrypted_dns","cached route diagnostic preserves resolver origin")
 check(not JSON.stringify(client.get_connection_snapshot()).contains(owner),"connection diagnostics contain no account binding")
 var signed: String=token(auth.uid);check(not JSON.stringify(client.get_connection_snapshot()).contains(signed),"diagnostics contain no token")
 # Signal bursts must respect retry backoff; explicit retry remains available.
 client._failed("http_503")
 count=auth.forces.size()
 for i: int in range(20):client._refresh_auth()
 check(auth.forces.size()==count and client.get_connection_snapshot().retry_in_seconds>0,"duplicate auth signals do not bypass retry backoff")
 client.connect_profile()
 check(auth.forces.size()==count+1,"explicit retry bypasses wait")
 client._on_token(token(auth.uid))
 client._ipv4_addresses=PackedStringArray(["104.21.21.160","172.67.199.90"])
 client._ipv4_address=client._ipv4_addresses[0];client._ipv4_index=0;client._trusted_attempted=true
 var query_count: int=client.queries
 client._on_response(HTTPRequest.RESULT_CANT_CONNECT,0,[],PackedByteArray(),client._nonce)
 check(client._ipv4_address=="172.67.199.90" and client._token_waiting,"POST failure tries second validated address before restarting DNS")
 check(client.queries==query_count,"address failover does not amplify DNS requests")
 client._on_token(token(auth.uid))
 client._on_response(HTTPRequest.RESULT_CANT_CONNECT,0,[],PackedByteArray(),client._nonce)
 check(not client._busy,"exhausted recovery routes back off")
 client._nonce+=1;client._busy=false;client.queue_free();auth.queue_free()
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("PROFILE_RESILIENCE checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
