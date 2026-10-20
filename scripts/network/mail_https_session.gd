extends Node
## One verified TLS connection for successive mailbox operations. Transport only:
## no wallet writes, retries of uncertain POSTs, redirects or stored credentials.
signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)
const HOST: String = "jade-ascendant-player.jade-ascendant-studio.workers.dev"
const TrustedDNS = preload("res://scripts/managers/trusted_profile_dns.gd")
var timeout: float = 20.0
var body_size_limit: int = 1048576
var _client: HTTPClient = HTTPClient.new()
var _target: String = ""
var _active: bool = false
var _sent: bool = false
var _has_headers: bool = false
var _started: int = 0
var _last_activity: int = 0
var _method: int = HTTPClient.METHOD_GET
var _path: String = ""
var _headers: PackedStringArray = PackedStringArray()
var _body: String = ""
var _response_code: int = 0
var _response_headers: PackedStringArray = PackedStringArray()
var _response_body: PackedByteArray = PackedByteArray()
var connection_count: int = 0
var reused_requests: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_client.blocking_mode_enabled = false
	_client.read_chunk_size = 32768

func _port() -> int: return 443
func _clock() -> int: return Time.get_ticks_msec()
func _verified_tls() -> TLSOptions: return TLSOptions.client(null, HOST)
func _allowed_target(host: String) -> bool: return host == HOST or TrustedDNS.public_ipv4(host)
func _client_status() -> int: return _client.get_status()
# Compatibility with the shared route builder. Actual TLS is always constructed
# here with certificate validation and the original profile hostname.
func set_tls_options(_options: TLSOptions) -> void: pass
func get_http_client_status() -> int: return _client_status()

func request(url: String, headers: PackedStringArray, method: int = HTTPClient.METHOD_GET, body: String = "") -> Error:
	if _active: return ERR_BUSY
	if not url.begins_with("https://"): return ERR_INVALID_PARAMETER
	var relative: String = url.trim_prefix("https://")
	var slash: int = relative.find("/")
	if slash < 1: return ERR_INVALID_PARAMETER
	var host: String = relative.substr(0, slash)
	var path: String = relative.substr(slash)
	if not _allowed_target(host) or not path.begins_with("/v1/mail/"): return ERR_INVALID_PARAMETER
	if host != _target:
		_client.close(); _target = host
	elif _client_status() == HTTPClient.STATUS_CONNECTED:
		# Detect an idle close before sending. Never replay an uncertain POST.
		_client.poll()
	_active = true; _sent = false; _has_headers = false
	_started = _clock(); _method = method; _path = path; _body = body
	_headers = headers.duplicate()
	_response_code = 0; _response_headers.clear(); _response_body.clear()
	if _client_status() == HTTPClient.STATUS_CONNECTED:
		reused_requests += 1
	elif _client_status() not in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		_client.close()
		var error: Error = _client.connect_to_host(_target, _port(), _verified_tls())
		if error != OK:
			_active = false; _forget_request(); return error
		connection_count += 1
	return OK

func cancel_request() -> void:
	_active = false; _client.close(); _target = ""; _forget_request()

func _exit_tree() -> void: cancel_request()
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and not _active: cancel_request()

func _forget_request() -> void:
	_headers.clear(); _body = ""; _path = ""; _sent = false; _has_headers = false
	_response_body.clear(); _response_headers.clear(); _response_code = 0

func _complete(result: int) -> void:
	var code: int = _response_code
	var headers: PackedStringArray = _response_headers.duplicate()
	var bytes: PackedByteArray = _response_body.duplicate()
	_active = false; _last_activity = _clock(); _forget_request()
	if result != HTTPRequest.RESULT_SUCCESS: _client.close()
	request_completed.emit(result, code, headers, bytes)

func _process(_delta: float) -> void:
	if not _active:
		if _client_status() == HTTPClient.STATUS_CONNECTED:
			_client.poll()
			if _clock() - _last_activity > 240000: cancel_request()
		return
	if _clock() - _started >= int(timeout * 1000.0): _complete(HTTPRequest.RESULT_TIMEOUT); return
	var error: Error = _client.poll()
	var phase: int = _client_status()
	if phase == HTTPClient.STATUS_CONNECTED and not _sent:
		var outgoing := PackedStringArray()
		for header: String in _headers:
			var key: String = header.get_slice(":",0).strip_edges().to_lower()
			if key not in ["host","connection","accept-encoding"]: outgoing.append(header)
		outgoing.append("Host: " + HOST)
		outgoing.append("Connection: keep-alive")
		outgoing.append("Accept-Encoding: identity")
		_sent = true
		if _client.request(_method, _path, outgoing, _body) != OK:
			_complete(HTTPRequest.RESULT_CONNECTION_ERROR)
		return
	if _sent and not _has_headers and _client.has_response():
		_response_code = _client.get_response_code()
		_response_headers = _client.get_response_headers()
		_has_headers = true
		if _client.get_response_body_length() > body_size_limit: _complete(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED); return
	if _has_headers:
		for index: int in 8:
			if _client_status() != HTTPClient.STATUS_BODY: break
			var chunk: PackedByteArray = _client.read_response_body_chunk()
			if chunk.is_empty(): break
			if _response_body.size() + chunk.size() > body_size_limit: _complete(HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED); return
			_response_body.append_array(chunk)
			_client.poll()
		phase = _client_status()
		if phase != HTTPClient.STATUS_BODY:
			var expected: int = _client.get_response_body_length()
			if phase == HTTPClient.STATUS_CONNECTED or (phase == HTTPClient.STATUS_DISCONNECTED and expected >= 0 and _response_body.size() == expected):
				_complete(HTTPRequest.RESULT_SUCCESS); return
	if error != OK or phase in [HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR, HTTPClient.STATUS_DISCONNECTED]:
		_complete(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR if phase == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR else HTTPRequest.RESULT_CANT_RESOLVE if phase == HTTPClient.STATUS_CANT_RESOLVE else HTTPRequest.RESULT_CONNECTION_ERROR)
