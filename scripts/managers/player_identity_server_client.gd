extends Node

## Authenticated profile-only HTTP transport. Tokens stay in memory, no logs.
## No purchases, rewards, Cloud Save, or account merging are performed here.
const ENDPOINT: String = "https://jade-ascendant-player.jade-ascendant-studio.workers.dev/v1/player/register"
var _auth: Node
var _http: HTTPRequest
var _owner: String = ""
var _pending_owner: String = ""
var _busy: bool = false
var _token_waiting: bool = false
var _nonce: int = 0
var _retry_seconds: float = 15.0
var _health_http: HTTPRequest
var _health_probe_enabled: bool = true
var _probe_running: bool = false
var _probe_failure: String = ""
var _probe_owner: String = ""
var _last_network_stage: String = "unknown"
var _health_network_stage: String = "unknown"
var _prefer_ipv4: bool = true
var _ipv4_addresses: PackedStringArray = PackedStringArray()
var _ipv4_address: String = ""
var _ipv4_index: int = 0
var _ipv4_resolved_at: int = 0
var _dns_attempted: bool = false
var _dns_item: int = -1
var _dns_owner: String = ""
var _dns_started_at: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 30.0
	_http.body_size_limit = 4096
	_http.max_redirects = 0
	add_child(_http)
	_http.request_completed.connect(_on_response)
	_health_http = HTTPRequest.new()
	_health_http.use_threads = true
	_health_http.timeout = 10.0
	_health_http.body_size_limit = 2048
	_health_http.max_redirects = 0
	add_child(_health_http)
	_health_http.request_completed.connect(_on_health_response)
	call_deferred("_initialize_auth")

func _process(_delta: float) -> void:
	if _dns_item >= 0:
		var dns_status: int = IP.get_resolve_item_status(_dns_item)
		if dns_status == IP.RESOLVER_STATUS_DONE:
			var addresses := PackedStringArray(IP.get_resolve_item_addresses(_dns_item))
			_complete_ipv4_resolution(_dns_owner,addresses)
		elif dns_status == IP.RESOLVER_STATUS_ERROR or Time.get_ticks_msec()-_dns_started_at >= 5000:
			_complete_ipv4_resolution(_dns_owner,PackedStringArray())
		return
	if _probe_running:
		var health_status: int = _health_http.get_http_client_status()
		if health_status != HTTPClient.STATUS_DISCONNECTED: _health_network_stage = _stage_name(health_status)
	elif _busy and not _token_waiting:
		var request_status: int = _http.get_http_client_status()
		if request_status != HTTPClient.STATUS_DISCONNECTED: _last_network_stage = _stage_name(request_status)

func _stage_name(status: int) -> String:
	match status:
		HTTPClient.STATUS_RESOLVING: return "dns"
		HTTPClient.STATUS_CONNECTING: return "connect_tls"
		HTTPClient.STATUS_CONNECTED: return "connected"
		HTTPClient.STATUS_REQUESTING: return "request"
		HTTPClient.STATUS_BODY: return "body"
		_: return "stage_"+str(status)

func _initialize_auth() -> void:
	var firebase: Node = get_node_or_null("/root/Firebase")
	if not OS.has_feature("android") or firebase == null or not Engine.has_singleton("GodotFirebaseAndroid"):
		PlayerIdentityManager.set_server_context("","android_required")
		return
	_auth = firebase.auth
	_auth.id_token_result.connect(_on_token)
	_auth.id_token_error.connect(_on_token_error)
	_auth.auth_state_changed.connect(func(_signed_in: bool,_data: Dictionary): _refresh_auth())
	GoogleAccountManager.account_state_changed.connect(func(_snapshot: Dictionary): _refresh_auth())
	GoogleAccountManager.monetization_identity_changed.connect(func(_identity_ready: bool): _refresh_auth())
	_refresh_auth()

func _current_owner() -> String:
	if _auth == null or not _auth.is_signed_in(): return ""
	var data: Dictionary = _auth.get_current_user_data()
	var uid: String = str(data.get("uid",""))
	return uid.sha256_text() if not uid.is_empty() else ""

func _refresh_auth() -> void:
	var current: String = _current_owner()
	if current != _owner:
		_nonce += 1
		_http.cancel_request()
		_health_http.cancel_request()
		_clear_dns_item()
		_dns_attempted = not _ipv4_address.is_empty()
		_probe_running = false
		_busy = false
		_token_waiting = false
		_owner = current
		_pending_owner = ""
		_retry_seconds = 15.0
	PlayerIdentityManager.set_server_context(_owner,"pending" if not _owner.is_empty() else "sign_in_required")
	if not _owner.is_empty() and not _busy: connect_profile()

func connect_profile() -> void:
	if _busy or _auth == null: return
	if _current_owner() != _owner:
		_refresh_auth()
		return
	if _owner.is_empty(): return
	if _dns_attempted and Time.get_ticks_msec()-_ipv4_resolved_at > 300000:
		_ipv4_address = ""
		_ipv4_addresses.clear()
		_dns_attempted = false
	if _prefer_ipv4 and _ipv4_address.is_empty() and not _dns_attempted:
		_begin_ipv4_resolution()
		return
	_busy = true
	_token_waiting = true
	_pending_owner = _owner
	_last_network_stage = "unknown"
	_nonce += 1
	var nonce: int = _nonce
	PlayerIdentityManager.set_server_context(_owner,"connecting")
	_auth.get_id_token(false)
	get_tree().create_timer(10.0).timeout.connect(func():
		if nonce == _nonce and _token_waiting: _failed("token_timeout"))

func _on_token(token: String) -> void:
	if not _busy or not _token_waiting: return
	_token_waiting = false
	if _current_owner() != _pending_owner:
		_refresh_auth()
		return
	var token_pattern := RegEx.new()
	token_pattern.compile("^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+$")
	if token.is_empty() or token.length() > 8192 or token_pattern.search(token) == null:
		_failed("invalid_token")
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"User-Agent: GodotEngine/4.7.2",
		"Host: "+_endpoint_host(),
		"Authorization: Bearer "+token])
	var error: Error = _http.request(_prepare_route(_http,"/v1/player/register"),headers,HTTPClient.METHOD_POST,"{}")
	if error != OK: _failed("request_start_"+str(error))

func _on_token_error(_message: String) -> void:
	if _busy and _token_waiting: _failed("token_error")

func _on_response(result: int, code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if not _busy: return
	if _current_owner() != _pending_owner:
		_refresh_auth()
		return
	# Failed HTTP requests may have no body. parse_string emits an engine error
	# for empty/malformed JSON, hiding the actual transport failure in the debugger.
	if result != HTTPRequest.RESULT_SUCCESS:
		if result == HTTPRequest.RESULT_TIMEOUT and _health_probe_enabled:
			_begin_health_probe("register_timeout_"+("ipv4_" if not _ipv4_address.is_empty() else "hostname_")+_last_network_stage)
			return
		_failed("network_"+str(result))
		return
	if code != 200:
		_failed("http_"+str(code))
		return
	if body.is_empty():
		_failed("empty_response")
		return
	var parser := JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		_failed("invalid_response")
		return
	if not PlayerIdentityManager.accept_server_identity(_pending_owner,parser.data):
		_failed("identity_response_rejected")
		return
	_busy = false
	_retry_seconds = 15.0
	PlayerIdentityManager.set_server_context(_owner,"connected")

func _begin_health_probe(failure_code: String) -> void:
	# Read-only, same-host GET with no credential. It never registers an identity
	# and cannot mark the account connected; it isolates GET reachability vs POST.
	_probe_running = true
	_probe_failure = failure_code
	_probe_owner = _pending_owner
	_health_network_stage = "unknown"
	PlayerIdentityManager.set_server_context(_owner,"checking_connection")
	var health_url: String = _prepare_route(_health_http,"/health")
	var error: Error = _health_http.request(health_url,["Accept: application/json","User-Agent: GodotEngine/4.7.2","Host: "+_endpoint_host()])
	if error != OK:
		_probe_running = false
		_failed(_probe_failure+"__health_start_"+str(error))

func _on_health_response(result: int, code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	if not _probe_running: return
	_probe_running = false
	if _current_owner() != _probe_owner:
		_refresh_auth()
		return
	if result != HTTPRequest.RESULT_SUCCESS and _try_next_ipv4_route(): return
	var suffix: String = "health_network_"+str(result)+"_"+_health_network_stage
	if result == HTTPRequest.RESULT_SUCCESS:
		if code != 200:
			suffix = "health_http_"+str(code)
		else:
			var parser := JSON.new()
			var healthy: bool = parser.parse(body.get_string_from_utf8()) == OK and parser.data is Dictionary and str(parser.data.get("service","")) == "jade-player-identity" and parser.data.get("ready") == true
			suffix = "health_ok" if healthy else "health_invalid"
	_failed(_probe_failure+"__"+suffix)

func _endpoint_host() -> String:
	return ENDPOINT.trim_prefix("https://").get_slice("/",0)

func _prepare_route(request: HTTPRequest, path: String) -> String:
	if _ipv4_address.is_empty():
		request.set_tls_options(_route_tls_options())
		return "https://"+_endpoint_host()+path
	# Connect to DNS-derived IPv4 while validating and sending TLS SNI for the
	# original hostname. The Host header is also original. Never use client_unsafe.
	request.set_tls_options(_route_tls_options())
	return "https://"+_ipv4_address+path

func _route_tls_options() -> TLSOptions:
	return TLSOptions.client() if _ipv4_address.is_empty() else TLSOptions.client(null,_endpoint_host())

func _begin_ipv4_resolution() -> void:
	_busy = true
	_token_waiting = false
	_dns_attempted = true
	_dns_owner = _owner
	_dns_started_at = Time.get_ticks_msec()
	_dns_item = IP.resolve_hostname_queue_item(_endpoint_host(),IP.TYPE_IPV4)
	PlayerIdentityManager.set_server_context(_owner,"resolving_ipv4")
	if _dns_item < 0: _complete_ipv4_resolution(_dns_owner,PackedStringArray())

func _clear_dns_item() -> void:
	if _dns_item >= 0:
		IP.erase_resolve_item(_dns_item)
		_dns_item = -1

func _complete_ipv4_resolution(expected_owner: String, addresses: PackedStringArray) -> void:
	_clear_dns_item()
	_dns_attempted = true
	if expected_owner != _owner or expected_owner != _current_owner():
		_busy = false
		_refresh_auth()
		return
	_ipv4_addresses.clear()
	for address: String in addresses:
		if address.is_valid_ip_address() and not address.contains(":") and address != "0.0.0.0" and not address.begins_with("127.") and not _ipv4_addresses.has(address):
			_ipv4_addresses.append(address)
		if _ipv4_addresses.size() >= 4: break
	_ipv4_index = 0
	_ipv4_address = _ipv4_addresses[0] if not _ipv4_addresses.is_empty() else ""
	_ipv4_resolved_at = Time.get_ticks_msec()
	_busy = false
	connect_profile()

func _try_next_ipv4_route() -> bool:
	if _ipv4_address.is_empty() or _ipv4_index+1 >= _ipv4_addresses.size(): return false
	_ipv4_index += 1
	_ipv4_address = _ipv4_addresses[_ipv4_index]
	_busy = false
	connect_profile() # Obtain a fresh token for the still-current account.
	return true

func _failed(reason: String = "offline") -> void:
	_busy = false
	_token_waiting = false
	PlayerIdentityManager.set_server_context(_owner,reason)
	var nonce: int = _nonce
	var retry: float = _retry_seconds
	_retry_seconds = minf(120.0,_retry_seconds*2.0)
	get_tree().create_timer(retry).timeout.connect(func():
		if nonce == _nonce and not _busy and _current_owner() == _owner: connect_profile())
