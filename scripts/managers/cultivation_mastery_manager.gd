extends Node
signal changed
const Catalog=preload("res://scripts/data/cultivation_mastery_catalog.gd")
const DOMAIN: String="cultivation_mastery"
var state: Dictionary={}
var ready_state: bool=false
var last_error: String=""
var _writing: bool=false
var _health: WeakRef
var _live_run: String=""
var _previous_hp: float=0
var _trial_invalid: bool=false
var _pulse_cooldown: float=0
var _splash_inflight: bool=false
var _prepared_rollback: Dictionary={}
var trial_hud: Label
func _ready() -> void:
 load_state()
 JourneyManager.stage_completed.connect(_on_stage_completed)
 get_tree().node_added.connect(_on_node_added)
func _process(delta: float) -> void:_pulse_cooldown=maxf(0,_pulse_cooldown-delta)
func _fresh() -> Dictionary:
 return {"version":1,"choices":{"vitality":"","sword_power":"","swift_qi":""},"realm":0,"clears":0,"best_hits":4,"run":{},"trial":{}}
func _valid_choices(value: Variant) -> bool:
 if not value is Dictionary or value.size()!=3:return false
 for path: String in Catalog.PATHS:
  if not value.has(path) or not value[path] is String:return false
  if value[path]!="" and not Catalog.eligible_choice(path,value[path]):return false
 return true
func _valid(data: Variant) -> bool:
 if not data is Dictionary or data.get("version")!=1 or not _valid_choices(data.get("choices")):return false
 for key: String in ["realm","clears","best_hits"]:
  if not data.get(key) is int:return false
 if data.realm not in [0,1] or data.clears<0 or data.clears>1000000 or data.best_hits<0 or data.best_hits>4:return false
 for key: String in ["run","trial"]:
  if not data.get(key) is Dictionary:return false
 if not data.run.is_empty():
  if not _valid_nonce(data.run.get("id","")) or not _valid_choices(data.run.get("choices")):return false
 if not data.trial.is_empty():
  if not _valid_nonce(data.trial.get("id","")) or data.trial.get("status","") not in ["running","failed","interrupted","complete"]:return false
  if not data.trial.get("hits") is int or data.trial.hits<0 or data.trial.hits>4:return false
 return true
func _valid_nonce(id: Variant) -> bool:return id is String and id.length()==32 and id.is_valid_hex_number(false)
func load_state() -> void:
 ready_state=false;state={}
 var result: Dictionary=SaveManager.read_save_data(DOMAIN)
 if bool(result.get("success",false)) and _valid(result.get("data")):state=result.data.duplicate(true);ready_state=true
 elif not bool(result.get("exists",false)) and not FileAccess.file_exists(SaveManager.get_save_backup_path(DOMAIN)):
  ready_state=_commit(_fresh())
 else:
  var backup: Dictionary=SaveManager.read_save_backup(DOMAIN)
  if str(result.get("integrity_issue",""))!="unsupported_schema" and _valid(backup.get("data")) and bool(SaveManager.recover_save_from_backup(DOMAIN).get("success",false)):
   state=backup.data.duplicate(true);ready_state=true
 if not ready_state:last_error="Mastery save perlu recovery. Progres lain tidak diubah.";return
 if state.trial.get("status","")=="running":
  var interrupted: Dictionary=state.duplicate(true);interrupted.trial.status="interrupted";_commit(interrupted)
func _commit(candidate: Dictionary) -> bool:
 if _writing or not _valid(candidate) or SaveManager.is_progress_read_only():return false
 _writing=true
 var success: bool=bool(SaveManager.write_save_data(DOMAIN,candidate).get("success",false))
 if success:state=candidate.duplicate(true);ready_state=true;changed.emit()
 else:last_error="Penyimpanan gagal. Pilihan/realm tidak berubah."
 _writing=false;return success
func path_maxed(path: String) -> bool:
 return path in Catalog.PATHS and int(ProgressionManager.get(path+"_level"))>=10
func can_choose(path: String) -> bool:return ready_state and path_maxed(path) and not _writing and EquipmentManager.can_modify_equipment()
func choose(path: String,id: String,expected: String) -> bool:
 if not can_choose(path) or not Catalog.eligible_choice(path,id) or str(state.choices[path])!=expected:return false
 if state.choices[path]==id:return true
 var next: Dictionary=state.duplicate(true)
 # Freeze an existing checkpoint before any new hub choice, including old saves.
 if SaveManager.has_save_file("checkpoint") and _valid_nonce(JourneyManager.m7d_run_id) and next.run.get("id","")!=JourneyManager.m7d_run_id:
  next.run={"id":JourneyManager.m7d_run_id,"choices":_fresh().choices}
 next.choices[path]=id
 return _commit(next)
func get_run_choices(read_only: bool = false) -> Dictionary:
 if not ready_state or not JourneyManager.has_active_run():return {}
 var id: String=JourneyManager.m7d_run_id
 if not _valid_nonce(id):return {}
 if state.run.get("id","")==id:return state.run.choices.duplicate(true)
 if SaveManager.has_save_file("checkpoint"):return {}
 var candidate: Dictionary=state.duplicate(true);var choices: Dictionary=state.choices.duplicate(true)
 for path: String in Catalog.PATHS:
  if not path_maxed(path):choices[path]=""
 candidate.run={"id":id,"choices":choices}
 if read_only:return choices
 return choices if _commit(candidate) else {}
func trial_ready() -> bool:
 if not ready_state or _writing or SaveManager.is_progress_read_only() or SaveManager.has_pending_transaction():return false
 if SaveManager.has_save_file("checkpoint") or get_tree().get_first_node_in_group("player")!=null:return false
 if not JourneyManager.is_stage_unlocked(1,5):return false
 for path: String in Catalog.PATHS:
  if not path_maxed(path) or state.choices[path]=="":return false
 return true
func prepare_trial() -> String:
 if not trial_ready():last_error="Perlu 3 jalur MAX, 3 mastery aktif, Stage 1–5 terbuka, dan tidak ada checkpoint aktif.";return ""
 var id: String=JourneyManager._m7d_new_run_nonce()
 if not _valid_nonce(id):return ""
 var old_journey: Dictionary=JourneyManager.build_save_data();var old_state: Dictionary=state.duplicate(true)
 var journey: Dictionary=old_journey.duplicate(true)
 journey.selected_chapter_id=1;journey.selected_stage_id=5;journey.active_run_chapter_id=1;journey.active_run_stage_id=5;journey.m7d_run_id=id
 var candidate: Dictionary=state.duplicate(true);candidate.trial={"id":id,"status":"running","hits":0};candidate.run={"id":id,"choices":state.choices.duplicate(true)}
 _writing=true
 var ok: bool=SaveManager.write_save_batch({DOMAIN:candidate,"journey":journey})
 if ok:
  _prepared_rollback={"state":old_state,"journey":old_journey};state=candidate
  for key: String in ["selected_chapter_id","selected_stage_id","active_run_chapter_id","active_run_stage_id","m7d_run_id"]:JourneyManager.set(key,journey[key])
  _trial_invalid=false;changed.emit()
 else:last_error="Ujian belum dimulai: save gagal."
 _writing=false
 return str(JourneyManager.get_stage_data(1,5).get("scene_path","")) if ok else ""
func cancel_prepared_trial() -> void:
 if _prepared_rollback.is_empty():return
 if SaveManager.write_save_batch({DOMAIN:_prepared_rollback.state,"journey":_prepared_rollback.journey}):
  state=_prepared_rollback.state
  for key: String in ["selected_chapter_id","selected_stage_id","active_run_chapter_id","active_run_stage_id","m7d_run_id"]:JourneyManager.set(key,_prepared_rollback.journey[key])
 else:_trial_invalid=true;last_error="Recovery diperlukan setelah transisi gagal."
 _prepared_rollback.clear();changed.emit()
func _on_node_added(node: Node) -> void:
 if node.get_script()!=null and node.get_script().resource_path=="res://scripts/player/PlayerHealth.gd":_attach_health.call_deferred(node)
func _attach_health(health: Node) -> void:
 if EquipmentManager.is_practice():return
 if not is_instance_valid(health) or not health.get_parent().is_in_group("player"):return
 _health=weakref(health);_live_run=JourneyManager.m7d_run_id;_previous_hp=float(health.current_health);_pulse_cooldown=0
 if not health.health_changed.is_connected(_on_health_changed):health.health_changed.connect(_on_health_changed)
 if state.get("trial",{}).get("status","")=="running" and state.trial.id==_live_run:
  var layer:=CanvasLayer.new();layer.name="MasteryTrialHUD";layer.layer=12;health.get_tree().current_scene.add_child(layer)
  trial_hud=Label.new();trial_hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);trial_hud.offset_left=16;trial_hud.offset_right=-16;trial_hud.offset_top=84;trial_hud.offset_bottom=120;trial_hud.add_theme_font_size_override("font_size",14)
  trial_hud.add_theme_color_override("font_color",Color(.98,.79,.32));layer.add_child(trial_hud);_update_trial_hud()
func _update_trial_hud() -> void:
 if is_instance_valid(trial_hud):
  var status: String=str(state.trial.get("status",""))
  trial_hud.text="GOLDEN CORE • TRIAL CLEAR" if status=="complete" else ("TRIAL FAILED • RUN CONTINUES" if status!="running" else "TRIBULATION • HP HITS %d/3"%int(state.trial.get("hits",0)))
func _on_health_changed(hp: float,_max_hp: float) -> void:
 if ready_state and state.trial.get("status","")=="running" and state.trial.id==_live_run and hp<_previous_hp:
  var candidate: Dictionary=state.duplicate(true);candidate.trial.hits=mini(4,int(candidate.trial.hits)+1)
  if candidate.trial.hits>3 or hp<=0:candidate.trial.status="failed"
  if not _commit(candidate):_trial_invalid=true
  _update_trial_hud()
 _previous_hp=hp
func _on_stage_completed(chapter: int,stage: int,_first: bool) -> void:
 if not ready_state or _trial_invalid or state.trial.get("status","")!="running" or state.trial.id!=_live_run or chapter!=1 or stage!=5 or int(state.trial.get("hits",4))>3:return
 var health: Node=_health.get_ref() if _health!=null else null
 var scene: Node=get_tree().current_scene;var victory: Node=scene.get_node_or_null("VictoryManager") if scene!=null else null
 if health==null or health.is_dead or victory==null or not bool(victory.get("victory_processed")):return
 if scene.scene_file_path!=str(JourneyManager.get_stage_data(1,5).get("scene_path","")):return
 var candidate: Dictionary=state.duplicate(true);candidate.realm=1;candidate.clears=mini(1000000,int(candidate.clears)+1);candidate.best_hits=mini(int(candidate.best_hits),int(candidate.trial.hits));candidate.trial.status="complete"
 _commit(candidate);_prepared_rollback.clear();_update_trial_hud()
func on_enemy_hit(actor: Node2D,amount: float) -> void:
 if amount<=0 or not is_finite(amount) or _splash_inflight or _pulse_cooldown>0 or get_tree().paused or actor.has_meta("jade_set_dot_inflight"):return
 if not actor.is_in_group("enemy") or get_run_choices().get("sword_power","")!="pulse":return
 _pulse_cooldown=3;_splash_inflight=true
 var count: int=0
 for target: Node in get_tree().get_nodes_in_group("enemy"):
  if target==actor or target.has_meta("jade_set_dot_inflight") or not target is Node2D or not target.has_method("take_damage") or target.is_queued_for_deletion():continue
  if actor.global_position.distance_to(target.global_position)>80:continue
  target.set_meta("jade_set_dot_inflight",true);target.take_damage(amount*.15)
  if is_instance_valid(target):target.remove_meta("jade_set_dot_inflight")
  count+=1
  if count>=3:break
 var fx: Node2D=preload("res://scripts/effects/cultivation_mastery_pulse.gd").new();get_tree().current_scene.add_child(fx);fx.global_position=actor.global_position
 _splash_inflight=false
