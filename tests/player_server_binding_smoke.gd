extends SceneTree
class FakeAuth extends Node:
	var uid: String = "server_qa_owner_one"
	var requests: int = 0
	func is_signed_in() -> bool: return not uid.is_empty()
	func get_current_user_data() -> Dictionary: return {"uid":uid}
	func get_id_token(_force: bool) -> void: requests += 1

var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,tag: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SERVER_BINDING_FAIL " + tag)
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_profile_qa"):
		quit(2)
		return
	await create_timer(0.5).timeout
	var manager: Node = root.get_node("PlayerIdentityManager")
	var client: Node = root.get_node("PlayerIdentityServerClient")
	client._health_probe_enabled = false # Fixture callbacks do not make live GETs.
	client._prefer_ipv4 = false # Resolver outcomes are injected below.
	var saves: Node = root.get_node("SaveManager")
	check(client._http.use_threads,"HTTP worker thread enabled")
	check(client._http.timeout == 30.0,"finite mobile request budget")
	check(client.process_mode == Node.PROCESS_MODE_ALWAYS,"transport continues during gameplay pause")
	var auth := FakeAuth.new()
	root.add_child(auth)
	var owner: String = auth.uid.sha256_text()
	client._auth = auth
	client._owner = owner
	manager.set_server_context(owner,"pending")
	var local_uid: String = str(manager.get_profile_snapshot().player_uid)
	var before: Dictionary = {}
	for id: String in saves.get_save_domain_ids_for_scope("permanent"):
		var path: String = saves.get_save_path(id)
		before[id] = FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
	var good: Dictionary = JSON.parse_string('{"version":1,"public_uid":"JA123456789A","owner_binding":"'+owner+'"}')
	check(typeof(good.version) == TYPE_FLOAT,"real JSON numeric type exercised")
	for malformed: Dictionary in [ {"version":1,"public_uid":"JA123456789A","owner_binding":"wrong"}, {"version":1,"public_uid":"JA-123456789","owner_binding":owner}, {"version":2,"public_uid":"JA123456789A","owner_binding":owner}, {"version":true,"public_uid":"JA123456789A","owner_binding":owner} ]:
		check(not manager.accept_server_identity(owner,malformed),"reject malformed server response")
		check(str(manager.get_profile_snapshot().player_uid) == local_uid,"invalid response keeps local identity")
	check(client._health_http.timeout == 10.0 and client._health_http.body_size_limit == 2048,"bounded read-only health probe")
	check(client._stage_name(HTTPClient.STATUS_RESOLVING) == "dns","DNS stage identified")
	check(client._stage_name(HTTPClient.STATUS_CONNECTING) == "connect_tls","TCP/TLS stage identified without overclaim")
	check(client._stage_name(HTTPClient.STATUS_REQUESTING) == "request","request stage identified")
	var health_cases: Array[Dictionary] = [
		{"result":HTTPRequest.RESULT_SUCCESS,"code":200,"body":'{"service":"jade-player-identity","ready":true}',"suffix":"health_ok"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":200,"body":'{"service":"different","ready":true}',"suffix":"health_invalid"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":200,"body":"","suffix":"health_invalid"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":403,"body":"blocked","suffix":"health_http_403"},
		{"result":HTTPRequest.RESULT_TIMEOUT,"code":0,"body":"","suffix":"health_network_13_connect_tls"}]
	for fixture: Dictionary in health_cases:
		client._probe_running = true
		client._probe_failure = "register_timeout_request"
		client._probe_owner = owner
		client._health_network_stage = "connect_tls"
		client._on_health_response(int(fixture.result),int(fixture.code),PackedStringArray(),str(fixture.body).to_utf8_buffer())
		check(str(manager.get_profile_snapshot().server_status) == "register_timeout_request__"+str(fixture.suffix),"classify same-engine health probe")
		check(not bool(manager.get_profile_snapshot().server_registered),"health GET never creates server identity")
		check(str(manager.get_profile_snapshot().player_uid) == local_uid,"health probe preserves device identity")
		client._nonce += 1
	check(bool(saves.begin_save_write_barrier("server_binding_qa","maintenance").success),"write barrier")
	check(not manager.accept_server_identity(owner,good),"server UID not exposed before successful save")
	check(not bool(manager.get_profile_snapshot().server_registered),"failed save never claims registration")
	saves.end_save_write_barrier("server_binding_qa")
	client._busy = true
	client._pending_owner = owner
	client._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(good).to_utf8_buffer())
	check(str(manager.get_profile_snapshot().player_uid) == "JA123456789A","transport accepts real parsed JSON UID")
	check(str(manager.get_profile_snapshot().server_status) == "connected","connected only after valid saved response")
	manager.refresh_profile()
	check(str(manager.get_profile_snapshot().player_uid) == "JA123456789A","server cache survives reload")
	var saved_hash: String = FileAccess.get_sha256(saves.get_save_path("player_profile"))
	check(manager.accept_server_identity(owner,good),"idempotent server response")
	check(FileAccess.get_sha256(saves.get_save_path("player_profile")) == saved_hash,"same response causes no redundant disk writes")
	# Expected transport errors must be classified before parsing, with no engine
	# JSON errors and no change to an already assigned/cached public UID.
	var cases: Array[Dictionary] = [
		{"result":HTTPRequest.RESULT_TIMEOUT,"code":0,"body":"","status":"network_13"},
		{"result":HTTPRequest.RESULT_CANT_CONNECT,"code":0,"body":"","status":"network_2"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":401,"body":"","status":"http_401"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":503,"body":"Unknown error getting token","status":"http_503"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":200,"body":"","status":"empty_response"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":200,"body":"not JSON","status":"invalid_response"},
		{"result":HTTPRequest.RESULT_SUCCESS,"code":200,"body":"[]","status":"invalid_response"}]
	for fixture: Dictionary in cases:
		client._busy = true
		client._pending_owner = owner
		client._on_response(int(fixture.result),int(fixture.code),PackedStringArray(),str(fixture.body).to_utf8_buffer())
		check(str(manager.get_profile_snapshot().server_status) == str(fixture.status),"classify failed HTTP response")
		check(str(manager.get_profile_snapshot().player_uid) == "JA123456789A","failure retains cached server UID")
		client._nonce += 1
	client._busy = true
	client._token_waiting = true
	client._pending_owner = owner
	client._on_token("Unknown error getting token")
	check(str(manager.get_profile_snapshot().server_status) == "invalid_token","reject native error text as bearer token")
	client._nonce += 1
	var wrong_assignment: Dictionary = good.duplicate(true)
	wrong_assignment.public_uid = "JA987654321A"
	check(not manager.accept_server_identity(owner,wrong_assignment),"server cannot silently reassign known owner UID")
	client._busy = true
	client._pending_owner = owner
	auth.uid = "server_qa_owner_two"
	client._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(good).to_utf8_buffer())
	check(str(manager.get_profile_snapshot().player_uid) == local_uid,"late old-account response never leaks to new account")
	check(not bool(manager.get_profile_snapshot().server_registered),"new account has independent pending registration")
	client._busy = false
	client._token_waiting = false
	client._nonce += 1
	manager.set_server_context(owner,"offline")
	check(str(manager.get_profile_snapshot().player_uid) == "JA123456789A","original account cached UID available offline")
	manager.set_server_context("","sign_in_required")
	check(str(manager.get_profile_snapshot().player_uid) == local_uid,"signed-out state does not show previous account UID")
	for id: String in before:
		var path: String = saves.get_save_path(id)
		check(before[id] == (FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"),"gameplay save untouched " + id)
	manager.set_server_context(owner,"offline")
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await create_timer(0.5).timeout
	current_scene._open_profile_sheet()
	await create_timer(0.2).timeout
	var card: Node = current_scene.profile_sheet_body.get_node("PlayerIdentityCard")
	check(card._uid.text == "JA123456789A","real profile displays authoritative cached UID")
	check(card._uid_kind.text == "UID","registered identity label")
	manager.set_server_context(owner,"network_2")
	check(card._status.text.contains("network_2"),"safe network diagnostic visible in profile")
	manager.set_server_context(owner,"http_401")
	check(card._status.text.contains("401"),"HTTP failure visible in profile")
	manager.set_server_context(owner,"network_13")
	check(card._status.text.contains("timed out"),"timeout wording names the actual failure")
	manager.set_server_context(owner,"register_timeout_request__health_ok")
	check(card._status.text.contains("Game reached server"),"GET reachable vs POST timeout wording")
	manager.set_server_context(owner,"register_timeout_connect_tls__health_network_13_dns")
	check(card._status.text.contains("health_network_13_dns"),"probe phase code visible to diagnose phone")
	# Isolated resolver/route checks. No external request is started: FakeAuth
	# records token requests instead of issuing a token callback.
	auth.uid = "server_qa_owner_one"
	client._owner = owner
	client._busy = true
	client._dns_attempted = true
	client._complete_ipv4_resolution(owner,PackedStringArray(["2001:db8::1","127.0.0.1","invalid","104.21.1.1","104.21.1.1","172.67.1.1"]))
	check(client._ipv4_addresses == PackedStringArray(["104.21.1.1","172.67.1.1"]),"resolver selects unique valid IPv4 addresses only")
	check(client._ipv4_address == "104.21.1.1","first DNS-derived IPv4 selected")
	check(client._prepare_route(client._http,"/v1/player/register") == "https://104.21.1.1/v1/player/register","IPv4 socket route keeps endpoint path")
	check(client._route_tls_options().get_common_name_override() == client._endpoint_host(),"original TLS hostname and SNI retained")
	check(not client._route_tls_options().is_unsafe_client(),"IPv4 does not disable certificate verification")
	check(client._route_tls_options().get_trusted_ca_chain() == null,"production retains default CA trust")
	client._busy = false
	check(client._try_next_ipv4_route(),"second DNS-derived address available")
	check(client._ipv4_address == "172.67.1.1","alternative IPv4 route selected")
	check(not client._try_next_ipv4_route(),"bounded address rotation stops at end")
	client._ipv4_address = ""
	client._ipv4_addresses.clear()
	client._busy = false
	client._token_waiting = false
	client._nonce += 1
	check(client._prepare_route(client._http,"/health") == "https://"+client._endpoint_host()+"/health","hostname route remains fallback when IPv4 unavailable")
	var marker := ConfigFile.new()
	marker.set_value("qa","owner",owner)
	marker.save("user://server_binding_qa.cfg")
	current_scene.queue_free()
	current_scene = null
	client._auth = null
	auth.queue_free()
	await process_frame
	await process_frame
	print("SERVER_BINDING_QA checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
