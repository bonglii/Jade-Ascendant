extends Node
## Existing verified Profile HTTPS route; optional aggregate reporting never blocks play.
signal changed
const DNS=preload("res://scripts/managers/trusted_profile_dns.gd")
var agenda: Dictionary={}
var status: String="idle"
var _agenda_http: HTTPRequest
var _http: HTTPRequest
var _auth: Node
var _waiting: bool=false
var _busy: bool=false
var _owner_key: String=""
var _nonce: int=0
var _batch: Array=[]
var _retry_at: int=0
var _agenda_at: int=0
var _refreshed: bool=false
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 PlayerCompanion.changed.connect(_on_changed)
 call_deferred("_setup")
 var timer:=Timer.new();timer.wait_time=45;timer.timeout.connect(_tick);add_child(timer);timer.start()
func _setup() -> void:
 if DisplayServer.get_name()=="headless":return
 refresh_agenda()
 var firebase: Node=get_node_or_null("/root/Firebase")
 if not OS.has_feature("android") or firebase==null:return
 _auth=firebase.auth;_auth.id_token_result.connect(_token)
 _auth.id_token_error.connect(func(_error: String):if _waiting:_finish("token_unavailable"))
 _tick()
func _on_changed() -> void:
 var binding: String=GoogleAccountManager.get_monetization_account_binding()
 if _owner_key!=binding or not bool(PlayerCompanion.state.get("metrics_opt_in",false)):
  _nonce+=1;_waiting=false;_busy=false;_batch=[]
  if is_instance_valid(_http):_http.cancel_request()
  _owner_key=binding
func _tick() -> void:
 if agenda.is_empty():refresh_agenda()
 if _busy or _auth==null or Time.get_ticks_msec()<_retry_at or not bool(PlayerCompanion.state.get("metrics_opt_in",false)) or PlayerCompanion.state.get("metrics",[]).is_empty() or SaveManager.is_progress_read_only():return
 var key: String=GoogleAccountManager.get_monetization_account_binding()
 if key.length()!=64 or key!=PlayerCompanion.account_key:return
 _owner_key=key;_batch=PlayerCompanion.state.metrics.slice(0,20).duplicate(true)
 _busy=true;_waiting=true;_refreshed=false;_nonce+=1
 var nonce: int=_nonce
 _auth.get_id_token(false)
 get_tree().create_timer(12).timeout.connect(func():if nonce==_nonce and _waiting:_finish("token_timeout"))
func _token(token: String) -> void:
 if not _waiting or not _busy or _owner_key!=GoogleAccountManager.get_monetization_account_binding() or not bool(PlayerCompanion.state.get("metrics_opt_in",false)):return
 if token.length()>8192 or not DNS.token_owner_matches(token,_owner_key):return
 _waiting=false
 if is_instance_valid(_http):_http.queue_free()
 _http=HTTPRequest.new();_http.use_threads=true;_http.timeout=12;_http.body_size_limit=4096;_http.max_redirects=0;add_child(_http)
 _http.request_completed.connect(_response.bind(_nonce,_owner_key))
 var headers:=PackedStringArray(["Accept: application/json","Content-Type: application/json","Host: "+PlayerIdentityServerClient._endpoint_host(),"Authorization: Bearer "+token])
 var error: Error=_http.request(PlayerIdentityServerClient._prepare_route(_http,"/v1/player/gameplay-metrics"),headers,HTTPClient.METHOD_POST,JSON.stringify({"version":1,"events":_batch}))
 if error!=OK:_finish("network_unavailable")
func _response(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray,nonce: int,key: String) -> void:
 if nonce!=_nonce or key!=PlayerCompanion.account_key or key!=GoogleAccountManager.get_monetization_account_binding():return
 if result!=HTTPRequest.RESULT_SUCCESS:_finish("network_unavailable");return
 if code==401 and not _refreshed:
  _refreshed=true;_waiting=true;_auth.get_id_token(true)
  get_tree().create_timer(12).timeout.connect(func():if nonce==_nonce and _waiting:_finish("token_timeout"))
  return
 var data: Variant=JSON.parse_string(body.get_string_from_utf8())
 if code!=200 or not data is Dictionary or data.get("version")!=1 or data.get("owner_binding")!=key or not data.get("accepted") is Array:_finish("service_unavailable");return
 var ids: Array=[]
 for row: Dictionary in _batch:ids.append(row.id)
 if data.accepted.any(func(value: Variant):return not value is String or value not in ids):_finish("invalid_response");return
 var next: Dictionary=PlayerCompanion.state.duplicate(true)
 next.metrics=next.metrics.filter(func(row: Dictionary):return row.id not in data.accepted)
 # Server receipts do not authorize changes to gameplay. A failed local write
 # must not be advertised as a fully persisted sync; retry is idempotent.
 if not PlayerCompanion.commit(next):
  _finish("receipt_pending_local_save")
  return
 _finish("reported" if not data.accepted.is_empty() else "server_limit_or_no_acceptance")
func _finish(stage: String) -> void:
 _busy=false;_waiting=false;_batch=[];status=stage;_retry_at=Time.get_ticks_msec()+300000;changed.emit()
func refresh_agenda() -> void:
 if DisplayServer.get_name()=="headless" or Time.get_ticks_msec()<_agenda_at:return
 _agenda_at=Time.get_ticks_msec()+60000
 if is_instance_valid(_agenda_http):_agenda_http.queue_free()
 _agenda_http=HTTPRequest.new();_agenda_http.use_threads=true;_agenda_http.timeout=12;_agenda_http.body_size_limit=16384;_agenda_http.max_redirects=0;add_child(_agenda_http)
 _agenda_http.request_completed.connect(func(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray):
  if result!=HTTPRequest.RESULT_SUCCESS or code!=200:return
  var data: Variant=JSON.parse_string(body.get_string_from_utf8())
  if not data is Dictionary or data.get("version")!=1 or not data.get("events") is Array or data.events.size()>12:return
  for event: Variant in data.events:
   if not event is Dictionary or event.get("kind") not in ["odyssey","heavenly_trials"] or not event.get("title") is String or event.title.length()>120 or typeof(event.get("starts_at")) not in [TYPE_INT,TYPE_FLOAT] or typeof(event.get("ends_at")) not in [TYPE_INT,TYPE_FLOAT]:return
  agenda=data;changed.emit())
 _agenda_http.request(PlayerIdentityServerClient._prepare_route(_agenda_http,"/v1/player/agenda"),PackedStringArray(["Accept: application/json","Host: "+PlayerIdentityServerClient._endpoint_host()]))
