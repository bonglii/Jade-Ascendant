extends Node
## Serial coordinator only. Existing managers still own delivery leases and atomic reward receipts.
signal changed
var authority: Node
var active: bool=false
var paused: bool=false
var total: int=0
var claimed: int=0
var skipped: int=0
var message: String=""
var _owner: String=""
var _ids: Array[String]=[]
var _current: String=""
var _sent: bool=false
var _sent_at: int=0
var _tick: float=0.0
var _reward: Dictionary={}
func _ready()->void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 RewardManager.reward_granted.connect(_capture_reward)
func _live_owner()->String: return PlayerIdentityServerClient._current_owner()
func _eligible(entry: Dictionary)->bool:
 return not entry.is_empty() and not (entry.get("reward",{}) as Dictionary).is_empty() and not bool(entry.get("claimed",false)) and bool(entry.get("can_claim",true)) and not bool(entry.get("expired",false)) and not bool(entry.get("cancelled",false)) and not bool(entry.get("blocked_on_other_device",false))
func available()->int:
 if authority==null: return 0
 var count: int=0
 for entry: Dictionary in authority.get_mail_entries():
  if _eligible(entry): count+=1
 return count
func start()->void:
 if active and not paused: return
 if SaveManager.is_progress_read_only(): message="Save hanya-baca · klaim ditunda";changed.emit();return
 if active and paused and _owner==_live_owner(): paused=false;_sent=false;message="Melanjutkan klaim…";changed.emit();return
 _owner=_live_owner();_ids.clear();_current="";_sent=false;_reward={};claimed=0;skipped=0
 for entry: Dictionary in authority.get_mail_entries():
  if _eligible(entry): _ids.append(str(entry.id))
 total=_ids.size();active=total>0;paused=false;message="Mengambil %d surat…" % total if active else "Tidak ada attachment yang bisa diklaim";changed.emit()
func owns_reward(id: String)->bool:
 if not active or _current.is_empty() or _owner!=_live_owner(): return false
 return id==("live_ops_mail_server_"+_current.trim_prefix("server:") if _current.begins_with("server:") else "live_ops_mail_"+_current)
func _capture_reward(_type: String,id: String,data: Dictionary)->void:
 if not owns_reward(id): return
 var applied: Dictionary=RewardManager.get_last_grant_result()
 if bool(applied.get("success",false)) and str(applied.get("source_type",""))==_type and str(applied.get("source_id",""))==id and applied.get("applied_reward_data") is Dictionary: data=applied.applied_reward_data
 for key: String in ["spirit_stone","celestial_jade","pavilion_seal","hero_exp"]:
  if int(data.get(key,0))>0: _reward[key]=int(_reward.get(key,0))+int(data[key])
 if data.get("items") is Dictionary:
  if not _reward.has("items"): _reward.items={}
  for key: String in data.items: _reward.items[key]=int(_reward.items.get(key,0))+int(data.items[key])
func _process(delta: float)->void:
 if not active: return
 if _owner!=_live_owner(): active=false;paused=false;_ids.clear();_current="";_reward={};message="Akun berubah · klaim dihentikan";changed.emit();return
 if paused: return
 _tick-=delta
 if _tick>0: return
 _tick=0.2
 if _owner!=_live_owner(): active=false;paused=false;_ids.clear();_current="";_reward={};message="Akun berubah · klaim dihentikan";changed.emit();return
 if SaveManager.is_progress_read_only(): paused=true;message="Save hanya-baca · tekan Claim All untuk lanjut";changed.emit();return
 if get_tree().get_first_node_in_group("player")!=null: return
 if not _current.is_empty():
  var entry: Dictionary=authority.get_mail(_current)
  if bool(entry.get("claimed",false)):
   claimed+=1;_current="";_sent=false;message="Diklaim %d/%d" % [claimed,total];changed.emit()
  elif not _eligible(entry): skipped+=1;_current="";_sent=false
  elif _sent:
   if _current.begins_with("server:") and ServerMailManager.is_busy_for(_current): return
   if Time.get_ticks_msec()-_sent_at<1000: return
   var status: String=ServerMailManager.get_status()
   if _current.begins_with("server:") and status in ["Mail expired or cancelled","Claim started on another device"]: skipped+=1;_current="";_sent=false
   else: paused=true;message="Diklaim %d/%d · tekan LANJUTKAN untuk mencoba sisanya" % [claimed,total];changed.emit();return
 if _current.is_empty():
  if _ids.is_empty(): _complete();return
  _current=_ids.pop_front()
  if not _eligible(authority.get_mail(_current)): skipped+=1;_current="";return
 if not _sent:
  _sent=true;_sent_at=Time.get_ticks_msec()
  if not bool(authority.claim_mail(_current)): _sent=false;paused=true;message="Klaim tertunda · tekan LANJUTKAN";changed.emit()
func _complete()->void:
 active=false;paused=false;message="%d surat diklaim%s" % [claimed," · %d dilewati" % skipped if skipped>0 else ""];changed.emit()
 if _reward.is_empty(): return
 for node: Node in get_tree().root.get_children():
  var script: Script=node.get_script()
  if script!=null and script.resource_path=="res://scripts/ui/reward_claim_result_presenter.gd" and node.has_method("show_claimed_reward"):
   node.call("show_claimed_reward","MAILBOX · CLAIM ALL",_reward.duplicate(true));break
 _reward={}
