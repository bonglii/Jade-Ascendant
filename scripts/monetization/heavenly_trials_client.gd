extends Node
## Weekly challenge transport. No UI callback can create currency or paid goods.
signal changed
signal finished(kind: String, success: bool)
const BRIDGE: String="JadeMonetizationNativeBridge"
var snapshot: Dictionary={}
var last_result: Dictionary={}
var status: String="preparing"
var busy: bool=false
var launching: bool=false
var launch_session: Dictionary={}
var _owner: String=""
var _request: String=""
var _command: Dictionary={}
var _deadline: int=0
var _next_read: int=0
var _received: int=0
var _backgrounded: bool=false
var _ad_pending: String=""
var _ad_poll_until: int=0
var _ad_next_poll: int=0
var ad_status: String="idle"
var _requested_ad: bool=false
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 call_deferred("_setup_ads")
 SceneTransitionManager.transition_failed.connect(_transition_failed)
 call_deferred("_setup_store")
func _binding() -> String:
 var identity: Node=get_node_or_null("/root/GoogleAccountManager")
 return str(identity.call("get_monetization_account_binding")) if identity!=null else ""
func _path() -> String:return "user://heavenly_trials_"+_owner+".json" if _owner.length()==64 else ""
func _id() -> String:return Crypto.new().generate_random_bytes(16).hex_encode()
func _bridge() -> Object:
 if not Engine.has_singleton(BRIDGE):return null
 var native: Object=Engine.get_singleton(BRIDGE)
 if not native.call("has_java_method","requestHeavenlyTrialsV1") or not native.has_signal("heavenlyTrialsResultV1"):return null
 if not native.is_connected("heavenlyTrialsResultV1",_result):native.connect("heavenlyTrialsResultV1",_result)
 return native
func _pending() -> Dictionary:
 if _path().is_empty() or not FileAccess.file_exists(_path()):return {}
 if FileAccess.get_file_as_bytes(_path()).size()>2048:return {"error":"journal_unreadable"}
 var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(_path()))
 if not value is Dictionary or value.get("owner")!=_owner or not value.get("command") is Dictionary:return {"error":"journal_unreadable"}
 return value.command
func _persist(command: Dictionary) -> bool:
 if _path().is_empty():return false
 var file:=FileAccess.open(_path()+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"owner":_owner,"command":command}));file.flush()
 var error: Error=file.get_error();file.close()
 return error==OK and DirAccess.rename_absolute(_path()+".tmp",_path())==OK
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_PAUSED:_backgrounded=true
 elif what==NOTIFICATION_APPLICATION_RESUMED:_backgrounded=false;_next_read=Time.get_ticks_msec()+1000
func _process(_delta: float) -> void:
 var current: String=_binding()
 if current!=_owner:
  _owner=current;snapshot={};last_result={};busy=false;_request="";_command={};launching=false;launch_session={};_ad_pending="";_ad_poll_until=0;_requested_ad=false;ad_status="idle";_next_read=Time.get_ticks_msec()+1500;status="preparing";_load_ad_wait();changed.emit()
 if busy and Time.get_ticks_msec()>_deadline:busy=false;status="retrying";_next_read=Time.get_ticks_msec()+5000;changed.emit()
 if not busy and not _backgrounded and _owner.length()==64 and Time.get_ticks_msec()>=_next_read and get_tree().get_first_node_in_group("player")==null:
  _next_read=Time.get_ticks_msec()+20000;refresh()
 if ad_status=="verifying_reward" and _ad_poll_until>0 and _ad_poll_until<=Time.get_ticks_msec():ad_status="delivery_pending";changed.emit()
 if _ad_poll_until>Time.get_ticks_msec() and not busy and Time.get_ticks_msec()>=_ad_next_poll:
  _ad_next_poll=Time.get_ticks_msec()+8000;refresh()
func server_time() -> int:return int(snapshot.get("server_time",0))+int(float(maxi(0,Time.get_ticks_msec()-_received))/1000.0)
func refresh() -> bool:
 if busy or _owner!=_binding() or _owner.length()!=64:return false
 var pending: Dictionary=_pending()
 if pending.has("error"):status="recovery_required";changed.emit();return false
 if pending.is_empty() and not snapshot.is_empty() and Time.get_ticks_msec()-_received<20000 and _ad_pending.is_empty():return true
 return _dispatch(pending)
func action(kind: String,args: Dictionary={},week_id: String="") -> bool:
 if not event_enabled() and kind not in ["finish","abandon"]:return false
 if (busy and not _command.is_empty()) or _owner!=_binding() or snapshot.is_empty() or not _pending().is_empty():return false
 var week: Variant=snapshot.get("week")
 if week_id.is_empty():
  if not week is Dictionary:return false
  week_id=str(week.id)
 var command: Dictionary={"request_id":_id(),"week_id":week_id,"action":{"kind":kind}}
 for key: String in args:
  if key=="kind":return false
  command.action[key]=args[key]
 if not _persist(command):status="save_unavailable";changed.emit();return false
 if busy:status="securing_action";changed.emit();return true
 # Once journaled, the action is accepted even when transport must retry.
 if not _dispatch(command):_next_read=Time.get_ticks_msec()+1500
 return true
func _dispatch(command: Dictionary) -> bool:
 var native: Object=_bridge()
 if native==null:status="native_update_required";changed.emit();return false
 _command=command;_request=str(command.get("request_id",_id()));busy=true;_deadline=Time.get_ticks_msec()+48000
 native.call("requestHeavenlyTrialsV1",_request,JSON.stringify(command) if not command.is_empty() else "")
 changed.emit();return true
static func valid_snapshot(value: Variant,account_binding: String) -> bool:
 if not value is Dictionary or value.get("version")!=1 or value.get("owner_binding")!=account_binding:return false
 for key: String in ["progress","previous_progress"]:
  if not value.get(key) is Array or value[key].size()>3:return false
  for progress: Variant in value[key]:
   if not progress is Dictionary or progress.get("owner")!=account_binding or int(progress.get("tier",0)) not in [1,2,3]:return false
 return value.get("server_time") is float or value.get("server_time") is int
func _result(request_id: String,success: bool,result_status: String,payload: String) -> void:
 if not busy or request_id!=_request or _owner!=_binding():return
 busy=false;var kind: String=str(_command.get("action",{}).get("kind","read"))
 if not success:
  status=result_status.to_lower();_next_read=Time.get_ticks_msec()+15000
  if result_status in ["REVISION_OR_OWNERSHIP_CONFLICT","INVALID_REQUEST"] and not _command.is_empty():
   if DirAccess.remove_absolute(_path())==OK:_command={};_next_read=Time.get_ticks_msec()+1000
  changed.emit();finished.emit(kind,false)
  if kind=="read" and not _pending().is_empty():call_deferred("refresh")
  return
 var data: Variant=JSON.parse_string(payload)
 if not valid_snapshot(data,_owner):status="invalid_server_response";changed.emit();return
 snapshot=data;_received=Time.get_ticks_msec();status="connected";_next_read=_received+60000
 if not _command.is_empty():DirAccess.remove_absolute(_path())
 _command={}
 _sync_ad(data)
 changed.emit();finished.emit(kind,true)
 if kind=="ad_intent" and _requested_ad:_requested_ad=false;_show_prepared_ad()

 if kind=="read" and not _pending().is_empty():call_deferred("refresh")
 if kind=="claim_all":
  var mail: Node=get_node_or_null("/root/ServerMailManager")
  if mail!=null:mail.call("refresh",true)
func event_enabled() -> bool:
 return snapshot.get("campaign") is Dictionary and bool(snapshot.campaign.get("enabled",false))
func ready_count() -> int:
 if not event_enabled():return 0
 var count: int=0
 for key: String in ["progress","previous_progress"]:
  for row: Dictionary in snapshot.get(key,[]):
   if int(row.get("clears",0))>0 and int(row.get("claimed",0))==0:count+=1
 return count
func is_available() -> bool:
 var week: Variant=snapshot.get("week");var campaign: Variant=snapshot.get("campaign")
 return week is Dictionary and campaign is Dictionary and bool(campaign.get("enabled",false)) and server_time()>=int(week.starts_at) and server_time()<int(week.ends_at)
func _checkpoint_path() -> String:return "user://heavenly_trial_run_"+_owner+".json" if _owner.length()==64 else ""
func checkpoint_data() -> Dictionary:
 var path: String=_checkpoint_path()
 if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size()>196608:return {}
 var envelope: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 var session: Variant=snapshot.get("session")
 if not envelope is Dictionary or envelope.get("owner")!=_owner or not envelope.get("payload") is String or not session is Dictionary:return {}
 var payload: String=envelope.payload
 if str(envelope.get("digest",""))!=payload.sha256_text():return {}
 # Binary Variant inside the checked envelope retains int and Vector2 types.
 # Object decoding stays disabled. This is a local checkpoint, never a grant.
 var decoded: Variant=Marshalls.base64_to_variant(payload,false)
 if not decoded is Dictionary:return {}
 var data: Dictionary=decoded
 if data.get("trials_session")!=session.get("id") or server_time()>int(session.get("expires_at",0)):return {}
 return preload("res://scripts/managers/checkpoint_manager.gd").normalize_checkpoint_save_data(data)
func write_checkpoint(data: Dictionary) -> bool:
 if _checkpoint_path().is_empty():return false
 var payload: String=Marshalls.variant_to_base64(data,false)
 if payload.length()>180000:return false
 var file:=FileAccess.open(_checkpoint_path()+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"owner":_owner,"payload":payload,"digest":payload.sha256_text()}));file.flush()
 var error: Error=file.get_error();file.close()
 return error==OK and DirAccess.rename_absolute(_checkpoint_path()+".tmp",_checkpoint_path())==OK
func delete_trial_checkpoint() -> bool:
 return not FileAccess.file_exists(_checkpoint_path()) or DirAccess.remove_absolute(_checkpoint_path())==OK
func launch(continuing: bool) -> bool:
 if not is_available() or launching or busy or not snapshot.get("session") is Dictionary or SaveManager.has_save_file("checkpoint") or SaveManager.is_progress_read_only():return false
 launch_session=snapshot.session.duplicate(true)
 if continuing and checkpoint_data().is_empty():status="saved_attempt_unavailable";changed.emit();return false
 if continuing:EquipmentManager.active_run_loadout_snapshot=checkpoint_data().get("trials_loadout",{}).duplicate(true)
 else:EquipmentManager.active_run_loadout_snapshot=EquipmentManager.build_active_run_loadout_snapshot()
 launching=true;GameSession.continue_game=continuing
 var error: Error=SceneTransitionManager.transition_to("res://scenes/levels/heavenly_trials.tscn",{"title":"Heavenly Trials","subtitle":"Entering the weekly challenge"})
 if error!=OK:launching=false;GameSession.continue_game=false
 return error==OK

func _setup_ads() -> void:
 var ads: Node=get_node_or_null("/root/MonetizationManager")
 if ads!=null and not ads.is_connected("rewarded_request_finished",_ad_closed):ads.connect("rewarded_request_finished",_ad_closed)
func _ad_provider() -> Node:
 var ads: Node=get_node_or_null("/root/MonetizationManager")
 return ads.get("provider") if ads!=null else null
func _sync_ad(data: Dictionary) -> void:
 var provider: Node=_ad_provider()
 if provider!=null and provider.has_method("configure_trials_unit") and bool(data.get("ads_ready",false)):
  if provider.call("configure_trials_unit",str(data.get("ad_unit",""))):provider.call("warm_rewarded_ad","heavenly_trials_bonus")
 var intent: Variant=data.get("ad")
 if not intent is Dictionary:return
 if str(intent.id)==_ad_pending and int(intent.get("consumed_at",0))>0:
  ad_status="reward_granted";_clear_ad_wait()
  var ads: Node=get_node_or_null("/root/MonetizationManager")
  if ads!=null:ads.call("publish_reward_delivery_result","heavenly_trials_bonus",true,600,"Bonus Stones secured in Mail")
  var mail: Node=get_node_or_null("/root/ServerMailManager")
  if mail!=null:mail.call("refresh",true)
 elif str(intent.id)==_ad_pending and server_time()>int(intent.get("expires_at",0)):
  ad_status="expired";_clear_ad_wait()
func watch_bonus(tier: int) -> bool:
 if not is_available() or not bool(snapshot.campaign.get("ads_enabled",false)):return false
 if busy or not _ad_pending.is_empty() or not is_available() or not bool(snapshot.get("ads_ready",false)):return false
 var ads: Node=get_node_or_null("/root/MonetizationManager")
 if ads==null or not bool(ads.call("rewarded_available","heavenly_trials_bonus")):ad_status="preparing_ad";changed.emit();return false
 var intent: Variant=snapshot.get("ad")
 if intent is Dictionary and int(intent.tier)==tier and int(intent.consumed_at)==0 and int(intent.expires_at)>server_time():return _show_prepared_ad()
 _requested_ad=true
 if not action("ad_intent",{"tier":tier}):_requested_ad=false;return false
 return true
func _show_prepared_ad() -> bool:
 if not is_available():return false
 var intent: Variant=snapshot.get("ad");var provider: Node=_ad_provider();var ads: Node=get_node_or_null("/root/MonetizationManager")
 if not intent is Dictionary or provider==null or ads==null or _owner!=_binding() or not provider.has_method("prepare_trials_ssv"):return false
 _ad_pending=str(intent.id)
 if not _save_ad_wait():_ad_pending="";ad_status="save_unavailable";changed.emit();return false
 provider.call("prepare_trials_ssv",_ad_pending)
 if not ads.call("show_rewarded","heavenly_trials_bonus"):_clear_ad_wait();ad_status="ad_unavailable";changed.emit();return false
 ad_status="watching";changed.emit();return true
func _ad_closed(placement: String,_result_status: String) -> void:
 if placement!="heavenly_trials_bonus" or _ad_pending.is_empty():return
 # Closure is not a reward receipt. Only signed SSV and an outbox grant confirm it.
 ad_status="verifying_reward";_ad_poll_until=Time.get_ticks_msec()+20000;_ad_next_poll=Time.get_ticks_msec()+1500;changed.emit()

func mutation_busy() -> bool:return (busy and not _command.is_empty()) or not _pending().is_empty()
func _ad_wait_path() -> String:return "user://heavenly_trials_ad_"+_owner+".json" if _owner.length()==64 else ""
func _save_ad_wait() -> bool:
 if _ad_wait_path().is_empty():return false
 var file:=FileAccess.open(_ad_wait_path()+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"owner":_owner,"nonce":_ad_pending}));file.flush();var error: Error=file.get_error();file.close()
 return error==OK and DirAccess.rename_absolute(_ad_wait_path()+".tmp",_ad_wait_path())==OK
func _load_ad_wait() -> void:
 if _ad_wait_path().is_empty() or not FileAccess.file_exists(_ad_wait_path()):return
 if FileAccess.get_file_as_bytes(_ad_wait_path()).size()>1024:return
 var data: Variant=JSON.parse_string(FileAccess.get_file_as_string(_ad_wait_path()))
 if data is Dictionary and data.get("owner")==_owner and str(data.get("nonce","")).length()==32:
  _ad_pending=str(data.nonce);ad_status="verifying_reward";_ad_poll_until=Time.get_ticks_msec()+20000;_ad_next_poll=Time.get_ticks_msec()+1500
func _clear_ad_wait() -> void:
 _ad_pending="";_ad_poll_until=0
 if not _ad_wait_path().is_empty() and FileAccess.file_exists(_ad_wait_path()):DirAccess.remove_absolute(_ad_wait_path())
func _transition_failed(scene_path: String,_error: int) -> void:
 if scene_path=="res://scenes/levels/heavenly_trials.tscn":
  launching=false;GameSession.continue_game=false;status="run_verification_retry";changed.emit()
func _setup_store() -> void:
 var pavilion: Node=get_node_or_null("/root/PavilionManager")
 if pavilion!=null and not pavilion.is_connected("billing_purchase_state_changed",_purchase_state):pavilion.connect("billing_purchase_state_changed",_purchase_state)
func _purchase_state(product: String,purchase_status: String,_message: String) -> void:
 if product=="heavenly_trials_support_550" and purchase_status=="wallet_credited":_next_read=Time.get_ticks_msec()+500;changed.emit()
