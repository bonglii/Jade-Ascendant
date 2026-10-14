extends SceneTree
## Reproducible offensive benchmark, not a phone/full-run survival test.
const MAX_SECONDS: float=300.0
var rows: Array[Dictionary]=[]
var checks: int=0
var failures: int=0
var defeated: bool=false
var last_hp: float=0.0
var phases: int=0
var dodge_pilot: bool=false
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BOSS_DURATION_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_duration_qa"):quit(2);return
 await process_frame
 root.get_node("SettingsManager").reduced_effects=true
 dodge_pilot=OS.get_environment("JADE_DURATION_DODGE")=="1"
 var selected_stages: Array=["5-5"] if dodge_pilot else ["4-1","4-5","5-1","5-5"]
 for stage_key: String in selected_stages:
  for build: String in ["entry_sword","focused_chain","focused_glaive"]:
   await measure(stage_key,build)
 var output: Dictionary={"rows":rows,"checks":checks,"failures":failures,"limit_seconds":MAX_SECONDS,"method":"Actual authored boss AI, movement, hitboxes, phase ward and production weapon manager at60Hz. Deterministic scripted orbit pilot, radius160, capped real movement speed. Player damage suppressed through test-only revive protection; boss offense kept active. Boss-only conditional offensive duration; not survival, phone time or a demonstrated obtainable full-run build.","seed":14102026,"pilot":"retreat_3_of_10s" if dodge_pilot else "continuous_orbit","builds":{"entry_sword":{"set":"moon_seal","equipment_stars":1,"armament":"nine_heavens_star_sword","weapon_level":10,"permanent_sword_power":6,"permanent_swift_qi":6,"run_weapons":4,"run_weapon_level":4,"run_power":4,"run_attack_speed":3,"run_crit":2,"skill_choices":24},"focused_chain":{"set":"nine_heavens","equipment_stars":2,"armament":"jade_binding_chain","weapon_level":20,"permanent_sword_power":10,"permanent_swift_qi":10,"run_weapons":6,"run_weapon_level":5,"run_power":4,"run_attack_speed":4,"run_crit":3,"skill_choices":40},"focused_glaive":{"same_as":"focused_chain","armament":"celestial_returning_glaive"}},"no_synergies_or_mastery_selected":true}
 var path: String=OS.get_environment("JADE_DURATION_OUTPUT")
 if not path.is_empty():
  var file:=FileAccess.open(path,FileAccess.WRITE)
  check(file!=null,"output opened")
  if file!=null:
   output.checks=checks;output.failures=failures
   file.store_string(JSON.stringify(output,"\t"));file.close()
 print("BOSS_DURATION_PROBE checks=",checks," failures=",failures)
 quit(1 if failures else 0)
func measure(stage_key: String,build: String) -> void:
 paused=false
 if current_scene!=null:
  var old: Node=current_scene;current_scene=null;old.queue_free()
  await process_frame;await process_frame
 var eq: Node=root.get_node("EquipmentManager")
 var progress: Node=root.get_node("ProgressionManager")
 var inv: Node=root.get_node("InventoryManager")
 var entry: bool=build=="entry_sword"
 var armament: String="nine_heavens_star_sword" if entry else ("jade_binding_chain" if build=="focused_chain" else "celestial_returning_glaive")
 eq.active_run_loadout_snapshot.clear();eq.weapon_levels.clear();eq.ascension_stars.clear()
 for slot: String in eq.get_slot_ids():eq.equipped_item_ids[slot]=""
 for id: String in preload("res://scripts/data/equipment_set_catalog.gd").get_piece_ids("moon_seal" if entry else "nine_heavens"):
  inv.item_counts[id]=1;eq.ascension_stars[id]=1 if entry else 2
  eq.equipped_item_ids[str(eq.get_item_data(id).slot)]=id
 inv.item_counts[armament]=1;eq.equipped_item_ids.armament=armament;eq.ascension_stars[armament]=1 if entry else 2;eq.weapon_levels[armament]=10 if entry else 20
 progress.sword_power_level=6 if entry else 10;progress.swift_qi_level=6 if entry else 10
 root.get_node("GameSession").start_new_game()
 seed(14102026)
 check(change_scene_to_file("res://scenes/levels/stage_"+stage_key.replace("-","_")+".tscn")==OK,"scene "+stage_key)
 await create_timer(.2).timeout
 var world: Node=current_scene
 var player: CharacterBody2D=world.get_node("player_1")
 world.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 var spawner: Node=world.get_node("EnemySpawner")
 var wave: Node=world.get_node("WaveManager")
 spawner.set_process(false);wave.set_process(false)
 if world.has_method("_process"):world.set_process(false) # No preboss arena hazards.
 spawner.clear_normal_enemies();spawner.clear_enemy_attacks()
 for node: Node in get_nodes_in_group("qi_pickup"):node.queue_free()
 await process_frame
 player.set_physics_process(false)
 player.experience_to_next_level=1000000
 var health: Node=player.get_node("PlayerHealth")
 health.rewarded_revive_invulnerable_until_msec=Time.get_ticks_msec()+3600000
 var manager: Node=player.get_node("WeaponManager")
 manager.add_fire_orb();manager.add_thunder_talisman();manager.add_heavenly_sword_rain()
 if not entry:manager.add_yin_yang_blades();manager.add_eight_trigrams_formation()
 for weapon: Weapon in manager.weapons:
  while weapon.level < (4 if entry else 5):weapon.upgrade()
 var stats: Node=player.get_node("PlayerStats")
 for i: int in range(4):stats.upgrade_power()
 for i: int in range(3 if entry else 4):stats.upgrade_attack_speed()
 stats.sword_intent_level=2 if entry else 3
 check(eq.get_runtime_equipped_item_id("armament")==armament and eq.get_item_weapon_level(armament)==(10 if entry else 20),"actual gear "+build)
 manager.set_process(false)
 wave.current_wave=10
 spawner.spawn_boss()
 var boss: Node2D=get_first_node_in_group("boss")
 check(boss!=null,"authored boss "+stage_key)
 if boss==null:return
 var hp: float=float(boss.max_hp)
 var preboss: float=float(wave.wave_duration)*(wave.final_wave-1)
 boss.global_position=player.global_position+Vector2(160,0)
 defeated=false;last_hp=hp;phases=0
 boss.boss_defeated.connect(func():defeated=true)
 boss.health_changed.connect(func(value: float,_max: float):last_hp=value)
 boss.phase_changed.connect(func(_phase: int):phases+=1)
 manager.set_process(true)
 var ticks: int=0
 var in_range: int=0
 while ticks<18000 and not defeated and is_instance_valid(boss):
  await physics_frame
  if defeated or not is_instance_valid(boss):break
  var elapsed: float=ticks/60.0
  var radius: float=310.0 if dodge_pilot and fmod(elapsed,10.0)<3.0 else 160.0
  var desired: Vector2=boss.global_position+Vector2(cos(elapsed*.45),sin(elapsed*.45))*radius
  var offset: Vector2=desired-player.global_position
  player.velocity=offset.limit_length(player.get_effective_movement_speed()/60.0)*60.0
  player.move_and_slide()
  if player.global_position.distance_to(boss.global_position)<=manager.boss_attack_range:in_range+=1
  ticks+=1
 var duration: float=ticks/60.0
 check(last_hp<hp,"actual damage "+stage_key+" "+build)
 var row: Dictionary={"stage":stage_key,"build":build,"pilot":"retreat_3_of_10s" if dodge_pilot else "continuous_orbit","boss_hp":hp,"boss_defeated":defeated,"elapsed_seconds":duration,"remaining_hp":last_hp,"phase_transitions":phases,"in_attack_range_fraction":float(in_range)/maxi(ticks,1),"preboss_seconds":preboss,"conditional_total_combat_seconds":preboss+duration if defeated else null,"effective_hp_damage_per_second":(hp-last_hp)/maxf(duration,.001)}
 rows.append(row)
 print("DURATION_ROW ",JSON.stringify(row))
 manager.set_process(false);paused=false
