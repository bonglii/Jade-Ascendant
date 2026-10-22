extends Node
## Bounded local companion data. No balances, grants, authentication or cloud authority.
signal changed
# Public rollout stays closed until the documented privacy/staging gate is completed.
# Independent of all nine live IAP gates. Local journals never require telemetry.
const METRICS_ROLLOUT_APPROVED: bool=false
const FILE: String = "user://jade_companion_v1.json"
const METRIC_QUEUE_MAX: int = 100 # Bounded offline opt-in queue; upload batches remain 20.
const GearProjection = preload("res://scripts/companion/equipment_projection.gd")
const Catalog = preload("res://scripts/data/equipment_catalog.gd")
const Report = preload("res://scripts/data/run_review.gd")
var state: Dictionary = {}
var account_key: String = ""
var _busy: bool = false
var _owner_override: String = "" # Isolated fixture only; never accepted from network.
var _pending_runs: Dictionary = {}
func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 _reload()
 PavilionManager.summon_completed.connect(func(result: Dictionary):
  if bool(result.get("success",false)):record_summons(result,"paid" if result.get("operation",{}).get("kind","") in ["summon","seal_summon"] else "free"))
 GoogleAccountManager.account_state_changed.connect(func(_snapshot: Dictionary): _reload())
 # Stage clear is confirmed by Journey; boss death alone is not a committed victory.
 JourneyManager.stage_completed.connect(_stage_completed)
 get_tree().scene_changed.connect(_scene_changed)
 _metric("session_start",0,0)
func live_owner() -> String:
 if not _owner_override.is_empty() and OS.get_user_data_dir().contains("jade_event_touch_qa"): return _owner_override
 var binding: String = GoogleAccountManager.get_monetization_account_binding()
 return binding if binding.length()==64 else ("guest:"+str(PlayerIdentityManager.get_profile_snapshot().get("player_uid","local"))).sha256_text()
func _empty() -> Dictionary:
 return {"presets":{},"goal":"","summons":[],"runs":[],"seen_bosses":[],"metrics_opt_in":false,"metrics":[],"metric_seen":[]}
func _read(path: String) -> Dictionary:
 var file := FileAccess.open(path, FileAccess.READ)
 if file==null or file.get_length()>262144: return {}
 var parsed: Variant = JSON.parse_string(file.get_as_text())
 return parsed if parsed is Dictionary and parsed.get("version")==1 and parsed.get("account_key")==live_owner() and parsed.get("data") is Dictionary else {}
func _path() -> String: return FILE.trim_suffix(".json")+"_"+live_owner()+".json"
func _reload() -> void:
 var next: String = live_owner()
 if account_key==next and not state.is_empty(): return
 account_key=next
 var raw: Dictionary = _read(_path())
 if raw.is_empty(): raw=_read(_path()+".bak")
 state=_clean(raw.get("data",{}));_pending_runs.clear();changed.emit()
func _clean(raw: Dictionary) -> Dictionary:
 var out: Dictionary = _empty()
 var presets: Variant = raw.get("presets",{})
 if presets is Dictionary:
  for key: String in ["0","1","2"]:
   var row: Variant=presets.get(key)
   if not row is Dictionary or not row.get("name") is String or row.name.length()>24 or not valid_slots(row.get("slots")): continue
   out.presets[key]={"name":row.name,"slots":row.slots.duplicate(),"server":row.get("server",{}).duplicate() if row.get("server") is Dictionary else {}}
 var goal: Variant=raw.get("goal","")
 if goal is String and (goal.is_empty() or Catalog.ITEMS.has(goal) or goal.begins_with("set:") and goal.trim_prefix("set:") in preload("res://scripts/data/equipment_set_catalog.gd").SET_ORDER): out.goal=goal
 for key: String in ["summons","runs","metrics"]:
  var rows: Variant=raw.get(key,[])
  if not rows is Array: continue
  for row: Variant in rows.slice(0,10 if key=="runs" else 100):
   if not row is Dictionary or JSON.stringify(row).length()>16000: continue
   if key=="summons" and (not Catalog.ITEMS.has(str(row.get("item_id",""))) or not row.get("id") is String or str(row.id).length()>96 or row.get("source") not in ["free","paid"] or not number(row.get("time"),0,4102444800) or not row.get("duplicate") is bool): continue
   if key=="runs" and not valid_run(row): continue
   if key=="metrics" and not valid_metric(row): continue
   out[key].append(row.duplicate(true))
 var seen: Variant=raw.get("seen_bosses",[])
 if seen is Array:
  for value: Variant in seen.slice(0,30):
   if value is String and value.length()<=8 and value not in out.seen_bosses: out.seen_bosses.append(value)
 var seen_metrics: Variant=raw.get("metric_seen",[])
 if seen_metrics is Array:
  for value: Variant in seen_metrics.slice(0,200):
   if value is String and value.length()==32 and value.is_valid_hex_number(false):out.metric_seen.append(value)
 out.metrics_opt_in=raw.get("metrics_opt_in",false)==true
 return out
func number(value: Variant, low: float, high: float) -> bool:
 return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=low and float(value)<=high
func valid_metric(row: Dictionary) -> bool:
 if not row.get("id") is String or row.id.length()!=32 or not row.id.is_valid_hex_number(false) or row.get("kind") not in ["session_start","tutorial_complete","stage_enter","stage_clear","stage_defeat","stage_leave"]:return false
 if not number(row.get("seconds"),0,86400) or float(row.seconds)!=floorf(float(row.seconds)):return false
 if not number(row.get("chapter"),0,5) or not number(row.get("stage"),0,6):return false
 var chapter: int=int(row.chapter);var stage: int=int(row.stage)
 if float(chapter)!=float(row.chapter) or float(stage)!=float(row.stage):return false
 return chapter>=1 and stage>=1 and stage<=(6 if chapter==1 else 5) if row.kind.begins_with("stage_") else chapter==0 and stage==0
func valid_run(row: Dictionary) -> bool:
 if not row.get("id") is String or row.id.length()>96 or row.get("outcome") not in ["victory","defeat"] or not row.get("facts") is Dictionary or not valid_slots(row.get("slots")):return false
 if not number(row.get("time"),0,4102444800) or not number(row.get("chapter"),1,5) or not number(row.get("stage"),1,6):return false
 var facts: Dictionary=row.facts
 if not number(facts.get("seconds"),0,86400) or not number(facts.get("level"),1,10000) or not facts.get("damage") is Array or not facts.get("skills") is Array or facts.damage.size()>64 or facts.skills.size()>64:return false
 for item: Variant in facts.damage:
  if not item is Dictionary or not item.get("name") is String or item.name.length()>120 or not number(item.get("damage"),0,1.0e30):return false
 for item: Variant in facts.skills:
  if not item is Dictionary or not item.get("name") is String or item.name.length()>120 or not number(item.get("level"),0,100):return false
 return true
func valid_slots(value: Variant) -> bool:
 if not value is Dictionary or value.size()!=5: return false
 for slot: String in EquipmentManager.get_slot_ids():
  var id: Variant=value.get(slot)
  if not id is String or not id.is_empty() and (not Catalog.ITEMS.has(id) or Catalog.ITEMS[id].slot!=slot or Catalog.ITEMS[id].get("retired",false)): return false
 return true
func commit(next: Dictionary) -> bool:
 if _busy or SaveManager.is_progress_read_only() or SaveManager.has_pending_transaction() or account_key!=live_owner(): return false
 _busy=true
 var path: String=_path()
 var data: String=JSON.stringify({"version":1,"account_key":account_key,"data":_clean(next)})
 var file := FileAccess.open(path+".tmp", FileAccess.WRITE)
 if file==null: _busy=false;return false
 file.store_string(data);file.flush();var error: Error=file.get_error();file.close()
 if error==OK and FileAccess.get_sha256(path+".tmp")!=data.sha256_text(): error=ERR_FILE_CORRUPT
 if error==OK:
  if FileAccess.file_exists(path):
   if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
   error=DirAccess.rename_absolute(path,path+".bak")
  if error==OK:
   error=DirAccess.rename_absolute(path+".tmp",path)
   if error!=OK and FileAccess.file_exists(path+".bak"): DirAccess.rename_absolute(path+".bak",path)
 _busy=false
 if error!=OK: return false
 state=_clean(next);changed.emit();return true
func save_preset(index: int, title: String) -> bool:
 if index not in [0,1,2] or not EquipmentManager.can_modify_equipment(): return false
 var paid: Dictionary={}
 for slot: String in EquipmentManager.get_slot_ids(): paid[slot]=EquipmentManager._paid_selected_v2(slot)
 var next: Dictionary=state.duplicate(true)
 next.presets[str(index)]={"name":title.strip_edges().left(24),"slots":GearProjection.slots(),"server":paid}
 return commit(next)
func preset_problem(index: int) -> String:
 var row: Dictionary=state.presets.get(str(index),{})
 if row.is_empty(): return "empty"
 if not EquipmentManager.can_modify_equipment(): return "save_or_run_busy"
 for slot: String in EquipmentManager.get_slot_ids():
  var paid: String=EquipmentManager._paid_selected_v2(slot)
  if paid!=str(row.get("server",{}).get(slot,"")): return "match_server_armory"
  var id: String=str(row.slots[slot])
  if not paid.is_empty():
   if id!=paid: return "match_server_armory"
  elif not id.is_empty() and not InventoryManager.owns_item(id): return "item_not_owned"
 return ""
func apply_preset(index: int) -> bool:
 if not preset_problem(index).is_empty(): return false
 return EquipmentManager.apply_local_preset(state.presets[str(index)].slots)
func set_goal(id: String) -> bool:
 var next: Dictionary=state.duplicate(true);next.goal=id
 if _clean(next).goal!=id: return false
 return commit(next)
func goal_progress() -> Dictionary:
 var goal: String=str(state.get("goal",""))
 if goal.is_empty(): return {}
 var ids: Array[String]=[]
 var sets=preload("res://scripts/data/equipment_set_catalog.gd")
 if goal.begins_with("set:"): ids=sets.get_piece_ids(goal.trim_prefix("set:"))
 else: ids.append(goal)
 var missing: Array[String]=[]
 for id: String in ids:
  var paid: Node=EquipmentManager._paid_v2()
  if not InventoryManager.owns_item(id) and not (paid!=null and int(paid.call("item_count",id))>0): missing.append(id)
 return {"id":goal,"total":ids.size(),"owned":ids.size()-missing.size(),"missing":missing}
func record_summons(result: Dictionary, source: String) -> void:
 if source not in ["free","paid"]: return
 var request_id: String=str(result.get("operation",{}).get("request_id",result.get("request_id",result.get("operation_id",""))))
 if request_id.is_empty(): request_id=Crypto.new().generate_random_bytes(16).hex_encode()
 var next: Dictionary=state.duplicate(true)
 var index: int=0
 for value: Variant in result.get("results",[]):
  if not value is Dictionary: continue
  var id: String=str(value.get("item_id",""));var entry_id: String=(request_id+":"+str(index)).sha256_text();index+=1
  if not Catalog.ITEMS.has(id) or next.summons.any(func(row: Dictionary):return row.id==entry_id): continue
  next.summons.push_front({"id":entry_id,"time":int(Time.get_unix_time_from_system()),"item_id":id,"duplicate":bool(value.get("duplicate",false)),"source":source})
 commit(next)
func _scene_changed() -> void:
 for run_id: String in _pending_runs:
  var entry: Dictionary=_pending_runs[run_id]
  if not state.runs.any(func(row: Dictionary):return row.id==run_id):_metric("stage_leave",entry.chapter,entry.stage,0,run_id)
 _pending_runs.clear()
 var world: Node=get_tree().current_scene
 if world==null or not world.scene_file_path.begins_with("res://scenes/levels/") or world.has_method("finish_heavenly_trial"): return
 call_deferred("_attach_run",world.get_instance_id())
func runtime_slots() -> Dictionary:
 var out: Dictionary={}
 for slot: String in EquipmentManager.get_slot_ids():out[slot]=EquipmentManager.get_runtime_equipped_item_id(slot)
 return out
func _attach_run(world_id: int) -> void:
 var world: Node=instance_from_id(world_id)
 if not is_instance_valid(world) or world!=get_tree().current_scene: return
 var id: String=JourneyManager.m7d_run_id
 if id.is_empty(): return
 var player: Node=world.get_node_or_null("player_1")
 if player==null: return
 var entry: Dictionary={"id":id,"chapter":JourneyManager.active_run_chapter_id,"stage":JourneyManager.active_run_stage_id,"slots":runtime_slots(),"account_key":account_key}
 _pending_runs[id]=entry
 var health: Node=player.get_node("PlayerHealth")
 health.died.connect(func(): _capture_run.call_deferred(world_id,id,"defeat"))
 var spawner: Node=world.get_node_or_null("EnemySpawner")
 if spawner!=null and spawner.has_signal("boss_spawned_signal"):
  spawner.connect("boss_spawned_signal",func(_boss: Node):
   _see_boss(entry.chapter,entry.stage))
 _metric("stage_enter",entry.chapter,entry.stage,0,id)
func _stage_completed(chapter: int, stage: int, _first_clear: bool) -> void:
 # The Journey signal fires after its progression save request, while the winning
 # world is still live. Never record an uncommitted boss-death as a clear.
 var world: Node=get_tree().current_scene
 if not is_instance_valid(world) or not world.scene_file_path.begins_with("res://scenes/levels/"):return
 var world_id: int=world.get_instance_id()
 for id: String in _pending_runs:
  var entry: Dictionary=_pending_runs[id]
  if entry.chapter==chapter and entry.stage==stage and entry.account_key==account_key:
   _capture_run(world_id,id,"victory")
   return
func _see_boss(chapter: int, stage: int) -> void:
 var key: String="%d-%d"%[chapter,stage]
 if key in state.seen_bosses: return
 var next: Dictionary=state.duplicate(true);next.seen_bosses.append(key);commit(next)
func _capture_run(world_id: int,id: String,outcome: String) -> void:
 var world: Node=instance_from_id(world_id)
 var entry: Dictionary=_pending_runs.get(id,{})
 if not is_instance_valid(world) or entry.is_empty() or entry.account_key!=account_key or account_key!=live_owner(): return
 var facts: Dictionary=Report.capture(world)
 if facts.is_empty(): return
 var next: Dictionary=state.duplicate(true)
 var row: Dictionary={"id":id,"time":int(Time.get_unix_time_from_system()),"chapter":entry.chapter,"stage":entry.stage,"outcome":outcome,"facts":facts,"slots":entry.slots}
 # A revived run replaces its earlier defeat; one run never becomes several rewards/records.
 next.runs=next.runs.filter(func(old: Dictionary):return old.id!=id)
 next.runs.push_front(row)
 if commit(next): _metric("stage_"+("clear" if outcome=="victory" else "defeat"),entry.chapter,entry.stage,int(facts.seconds),id)
func set_metrics_enabled(enabled: bool) -> bool:
 if enabled and not METRICS_ROLLOUT_APPROVED:return false
 var next: Dictionary=state.duplicate(true);next.metrics_opt_in=enabled
 if not enabled: next.metrics=[]
 var ok: bool=commit(next)
 if ok and enabled: _metric("session_start",0,0)
 return ok
func _metric(kind: String, chapter: int, stage: int, seconds: int=0,event_key: String="") -> void:
 if not METRICS_ROLLOUT_APPROVED or not bool(state.get("metrics_opt_in",false)): return
 var event_id: String=(kind+":"+event_key).sha256_text().left(32) if not event_key.is_empty() else Crypto.new().generate_random_bytes(16).hex_encode()
 if event_id in state.metric_seen:return
 var next: Dictionary=state.duplicate(true)
 next.metric_seen.push_front(event_id)
 next.metrics.append({"id":event_id,"kind":kind,"chapter":chapter,"stage":stage,"seconds":clampi(seconds,0,86400)})
 # Without trimming the oldest entry first, _clean() silently discards every
 # newly appended event once the original queue reaches its limit.
 while next.metrics.size()>METRIC_QUEUE_MAX: next.metrics.pop_front()
 commit(next)
