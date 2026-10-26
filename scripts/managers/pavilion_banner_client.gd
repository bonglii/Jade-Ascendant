extends Node
## Public, read-only live configuration. No token, wallet or save writes.
signal configuration_changed
const ARTWORKS: Dictionary = {"sanctum":"res://assets/ui/pavilion/sanctum_premium/pavilion_unified.png","celestial_gate":"res://assets/ui/pavilion/sanctum_premium/celestial_gate.png"}
const BASE_RATES: Dictionary = {"common":6000,"rare":2900,"epic":900,"legendary":200}
var _banner: Dictionary = {}
var _revision: int = -1
var _expires_ticks: int = 0
var _http: HTTPRequest
var _busy: bool = false
var _refresh_ticks: int = 0
var _view: WeakRef
func _ready() -> void:
	_http=HTTPRequest.new()
	_http.use_threads=true
	_http.timeout=15.0
	_http.body_size_limit=16384
	_http.max_redirects=0
	add_child(_http)
	_http.request_completed.connect(_response)
	call_deferred("refresh")
func _process(_delta: float) -> void:
	if _expires_ticks>0 and Time.get_ticks_msec()>=_expires_ticks:
		_banner.clear();_expires_ticks=0;configuration_changed.emit()
	if OS.has_feature("android") and not get_tree().paused and get_tree().get_first_node_in_group("player")==null and Time.get_ticks_msec()>=_refresh_ticks: refresh()
	if _view!=null:
		var view: Variant=_view.get_ref()
		if is_instance_valid(view) and view.is_inside_tree() and Time.get_ticks_msec()>=_refresh_ticks: refresh()
func watch(view: Node) -> void:
	_view=weakref(view)
	refresh()
func refresh() -> void:
	if _busy or Time.get_ticks_msec()<_refresh_ticks: return
	_refresh_ticks=Time.get_ticks_msec()+60000
	# Desktop/headless QA never initiates production traffic.
	if not OS.has_feature("android"): return
	_busy=true
	var route: Node=get_node_or_null("/root/PlayerIdentityServerClient")
	if route==null: _busy=false;return
	var headers:=PackedStringArray(["Accept: application/json","X-Jade-Ascendant-Arsenal: v1","Host: "+route._endpoint_host(),"User-Agent: GodotEngine/4.7.2"])
	if _http.request(route._prepare_route(_http,"/v1/pavilion/banner"),headers)!=OK: _busy=false
func current() -> Dictionary:
	if _expires_ticks>0 and Time.get_ticks_msec()<_expires_ticks: return _banner.duplicate(true)
	return {}
func _integer(value: Variant,min_value: int,max_value: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==float(int(value)) and int(value)>=min_value and int(value)<=max_value
func _exact(value: Dictionary,keys: Array) -> bool:
	return value.size()==keys.size() and value.keys().all(func(key: Variant) -> bool: return key in keys)
func accept_snapshot(input: Variant) -> bool:
	if not input is Dictionary or not _exact(input,["version","revision","server_time","valid_until","banner"]): return false
	if not _integer(input.version,1,1) or not _integer(input.revision,0,2147483647) or int(input.revision)<_revision: return false
	if not _integer(input.server_time,1,4102444800) or not _integer(input.valid_until,int(input.server_time)+1,int(input.server_time)+300): return false
	var next: Dictionary={}
	if input.banner!=null:
		if not input.banner is Dictionary: return false
		var b: Dictionary=input.banner
		if not _exact(b,["id","title","subtitle","artwork","featured","rates","starts_at","ends_at","enabled"]): return false
		if not b.id is String or b.id.length()!=32 or not b.id.is_valid_hex_number(false): return false
		if not b.title is String or b.title.strip_edges().is_empty() or b.title.length()>60 or not b.subtitle is String or b.subtitle.strip_edges().is_empty() or b.subtitle.length()>100: return false
		if not b.artwork is String or not ARTWORKS.has(b.artwork) or not b.enabled is bool or not b.enabled: return false
		if not _integer(b.starts_at,0,int(input.server_time)) or not _integer(b.ends_at,int(input.server_time)+1,4102444800): return false
		if int(b.ends_at)-int(b.starts_at)>90*86400 or int(input.valid_until)>int(b.ends_at): return false
		if not b.featured is Array or b.featured.is_empty() or b.featured.size()>5: return false
		var seen: Array=[]
		for id: Variant in b.featured:
			if not id is String or id in seen or id not in EquipmentManager.get_item_ids() or str(EquipmentManager.get_item_data(id).get("rarity",""))!="legendary": return false
			seen.append(id)
		if not b.rates is Dictionary or not _exact(b.rates,BASE_RATES.keys()): return false
		var total: int=0
		for rarity: String in BASE_RATES:
			if not _integer(b.rates[rarity],1,10000): return false
			total+=int(b.rates[rarity])
		if total!=10000: return false
		next=b.duplicate(true)
	_revision=int(input.revision)
	_expires_ticks=Time.get_ticks_msec()+int(input.valid_until-input.server_time)*1000
	if next!=_banner:
		_banner=next
		configuration_changed.emit()
	return true
func _response(result: int,code: int,_headers: PackedStringArray,body: PackedByteArray) -> void:
	_busy=false
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200 or body.is_empty(): return
	var parser:=JSON.new()
	if parser.parse(body.get_string_from_utf8())==OK: accept_snapshot(parser.data)
