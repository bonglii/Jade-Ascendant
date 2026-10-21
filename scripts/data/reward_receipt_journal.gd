extends RefCounted
## Local display cache, never a wallet, grant authority or cloud-save domain.
const LIMIT: int=30
var owner_hash: String=""
var entries: Array[Dictionary]=[]
var seen: Array[String]=[]
var dirty: bool=false
func path() -> String:return "user://reward_receipts_"+owner_hash+".json" if not owner_hash.is_empty() else ""
func bind_owner(owner: String) -> void:
 var next: String=owner.sha256_text()
 if next==owner_hash:return
 flush();owner_hash=next;entries.clear();seen.clear();dirty=false
 for candidate: String in [path(),path()+".bak"]:
  if not FileAccess.file_exists(candidate):continue
  var file:=FileAccess.open(candidate,FileAccess.READ)
  if file==null or file.get_length()>65536:continue
  var data: Variant=JSON.parse_string(file.get_as_text())
  if not data is Dictionary or data.get("version")!=1 or data.get("owner")!=owner_hash or not data.get("entries") is Array or not data.get("seen") is Array:continue
  if data.entries.size()>LIMIT or data.seen.size()>80:continue
  var valid: bool=true
  for entry: Variant in data.entries:
   if not entry is Dictionary or not entry.get("source") is String or entry.source.length()>64 or not _whole(entry.get("time"),1,4102444800) or not _whole(entry.get("count"),1,10000) or not entry.get("reward") is Dictionary or clean(entry.reward).is_empty():valid=false;break
  for key: Variant in data.seen:
   if not key is String or key.length()!=64 or not key.is_valid_hex_number(false):valid=false;break
  if not valid:continue
  for entry: Dictionary in data.entries:entries.append({"source":entry.source,"time":int(entry.time),"count":int(entry.count),"reward":clean(entry.reward)})
  for key: String in data.seen:seen.append(key)
  break
static func _whole(value: Variant, low: int, high: int) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
static func clean(reward: Dictionary) -> Dictionary:
 var result: Dictionary={}
 for key: String in ["spirit_stone","hero_exp","celestial_jade","pavilion_seal"]:
  if _whole(reward.get(key),1,1000000000000):result[key]=int(reward[key])
 var items: Dictionary={}
 if reward.get("items") is Dictionary and reward.items.size()<=64:
  for id: Variant in reward.items:
   if id is String and id.length()<=64 and id!="refinement_shard" and _whole(reward.items[id],1,1000000):items[id]=int(reward.items[id])
 if not items.is_empty():result.items=items
 return result
func record(source: String, receipt_key: String, reward: Dictionary, stamp: int) -> bool:
 if owner_hash.is_empty() or stamp<=0:return false
 var key: String=receipt_key.sha256_text();var payload: Dictionary=clean(reward)
 if key in seen or payload.is_empty():return false
 seen.push_front(key);seen.resize(mini(80,seen.size()))
 if not entries.is_empty() and str(entries[0].source)==source and stamp>=int(entries[0].time) and stamp-int(entries[0].time)<=2:
  var merged: Dictionary=entries[0].reward.duplicate(true)
  for field: String in ["spirit_stone","hero_exp","celestial_jade","pavilion_seal"]:
   var sum_value: int=int(merged.get(field,0))+int(payload.get(field,0))
   if sum_value>0:merged[field]=mini(1000000000000,sum_value)
  var items: Dictionary=merged.get("items",{}).duplicate()
  for id: String in payload.get("items",{}):items[id]=mini(1000000,int(items.get(id,0))+int(payload.items[id]))
  if not items.is_empty():merged.items=items
  entries[0].reward=merged;entries[0].count=mini(10000,int(entries[0].count)+1);entries[0].time=stamp
 else:entries.push_front({"source":source.left(64),"time":stamp,"count":1,"reward":payload})
 entries.resize(mini(LIMIT,entries.size()));dirty=true;return true
func flush() -> bool:
 if not dirty or path().is_empty():return true
 var file:=FileAccess.open(path()+".tmp",FileAccess.WRITE)
 if file==null:return false
 var payload: String=JSON.stringify({"version":1,"owner":owner_hash,"entries":entries,"seen":seen})
 while payload.to_utf8_buffer().size()>65536 and entries.size()>1:
  entries.pop_back();payload=JSON.stringify({"version":1,"owner":owner_hash,"entries":entries,"seen":seen})
 file.store_string(payload);file.flush()
 var error: Error=file.get_error();file.close()
 if error!=OK:return false
 if FileAccess.file_exists(path()) and DirAccess.copy_absolute(path(),path()+".bak")!=OK:return false
 if DirAccess.rename_absolute(path()+".tmp",path())!=OK:return false
 dirty=false;return true
