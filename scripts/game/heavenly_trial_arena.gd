extends "res://scripts/world/chapter_one_stage.gd"
## Same movement, skill choices and authored bosses; independent weekly session.
var elapsed: float=0
var ended: bool=false
var _trial: Node
var _boss: Node2D
var _save_left: float=12
var _hazard_left: float=7
var _theme: String="jade_wind"
var _resuming: Dictionary={}
func _enter_tree() -> void:
 # Base courtyard setup only; never begin or complete a Journey run.
 super._enter_tree()
 var guide: CanvasItem=get_node_or_null("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")
 if guide!=null:guide.set_script(null);guide.visible=false
 _trial=get_node_or_null("/root/HeavenlyTrialsClient")
 if _trial==null or _trial.launch_session.is_empty():return
 var session: Dictionary=_trial.launch_session
 stage_id=int(session.get("week_config",_trial.snapshot.get("week",{})).get("stage",1))
 _theme=str(session.get("week_config",_trial.snapshot.get("week",{})).get("theme","jade_wind"))
 stage_profile=JourneyManager.get_stage_data(int(session.tier),stage_id).duplicate(true)
 # Weekly encounters retain authored attack timings, hitboxes and presentation.
 # Shorter warmup limits crowd count; no extra campaign/elite rewards.
 stage_profile.enemy_cap=36;stage_profile.spawn_interval=1.6;stage_profile.elite_schedule={}
 stage_profile.hazard_kind=0
 get_node("EnemySpawner").configure_stage_profile(stage_profile)
 get_node("WaveManager").wave_duration=8.0
 get_node("WaveManager").final_wave=10
 get_node("DifficultyManager").difficulty_interval=60.0
 if GameSession.continue_game:_resuming=_trial.checkpoint_data()
func _ready() -> void:
 super._ready()
 if _trial==null or _trial.launch_session.is_empty():
  get_tree().paused=false;SceneTransitionManager.transition_to("res://scenes/ui/main_menu.tscn");return
 _trial.launching=false
 var label: Label=get_node("HUD/ScreenRoot/HUDSafeArea/StageIdentity")
 label.text="HEAVENLY TRIALS · TIER %d"%int(_trial.launch_session.tier)
 get_node("EnemySpawner").boss_spawned_signal.connect(_boss_spawned)
 if not _resuming.is_empty():elapsed=float(_resuming.get("trials_elapsed",0))
 SceneTransitionManager.set_back_handler(_leave)
 call_deferred("_resume_boss")
func _resume_boss() -> void:
 if bool(_resuming.get("trials_boss_phase",false)) and not ended:get_node("EnemySpawner").spawn_boss()
func _boss_spawned(actor: Node2D) -> void:
 _boss=actor
 if bool(_resuming.get("trials_boss_phase",false)):
  var saved: float=float(_resuming.get("trials_boss_hp",0))
  if saved>0:
   actor.current_hp=minf(saved,float(actor.max_hp))
   actor.update_phase()
   actor.health_changed.emit(float(actor.current_hp),float(actor.max_hp))
func boss_health() -> float:return float(_boss.current_hp) if is_instance_valid(_boss) else 0.0
func boss_phase() -> bool:return is_instance_valid(_boss) and boss_health()>0
func _process(delta: float) -> void:
 if ended or _trial==null:return
 elapsed+=delta;_save_left-=delta;_hazard_left-=delta
 if elapsed>=300 or _trial.server_time()>int(_trial.launch_session.expires_at):finish_heavenly_trial(false);return
 if _save_left<=0:_save_left=15;get_node("CheckPointManager").save_checkpoint()
 if _hazard_left<=0 and is_instance_valid(player):
  _hazard_left=9
  var hazard: Node2D=preload("res://scripts/game/heavenly_trial_rule.gd").new()
  hazard.theme_id=_theme;hazard.tier=int(_trial.launch_session.tier);hazard.global_position=player.global_position
  add_child(hazard)
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_PAUSED and is_node_ready() and not ended:get_node("CheckPointManager").save_checkpoint()
func _leave() -> void:
 if ended:return
 if not get_node("CheckPointManager").save_checkpoint():return
 get_tree().paused=false
 SceneTransitionManager.transition_to("res://scenes/ui/heavenly_trials_screen.tscn")
func finish_heavenly_trial(won: bool) -> void:
 if ended or _trial==null:return
 ended=true
 var ledger: Node=get_node("player_1/WeaponManager/RunCombatLedger");ledger.frozen=true
 var damage: float=0
 for value: Variant in ledger.totals.values():damage+=float(value)
 won=won and int(ledger.deaths)==0
 var report: Dictionary={"session_id":str(_trial.launch_session.id),"won":won,"time_ms":mini(900000,int(elapsed*1000)),"hits":int(ledger.hp_hits),"deaths":int(ledger.deaths),"damage":mini(1000000000,int(damage))}
 # Persist the report before leaving; retries retain this exact request/identity.
 if not _trial.action("finish",report,str(_trial.launch_session.week)):
  ended=false;ledger.frozen=false;return
 _trial.last_result={"won":won,"tier":int(_trial.launch_session.tier),"time_ms":report.time_ms,"hits":int(ledger.hp_hits),"deaths":int(ledger.deaths),"week":str(_trial.launch_session.week)}
 _trial.delete_trial_checkpoint()
 get_node("SurvivalManager").game_running=false
 get_tree().paused=false
 SceneTransitionManager.transition_to("res://scenes/ui/heavenly_trials_screen.tscn",{"title":"TRIAL CLEARED" if won else "TRIAL COMPLETE","subtitle":"Securing your weekly result"})

func _exit_tree() -> void:
 if is_instance_valid(_trial):_trial.launching=false
 if not SaveManager.has_save_file("checkpoint"):EquipmentManager.active_run_loadout_snapshot.clear()
