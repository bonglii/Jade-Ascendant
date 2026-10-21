extends SceneTree
## Conditional offense measurement with actual AI/hitboxes; not a survival/device test.
var defeated: bool=false
var phases: int=0
var rows: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_heavenly_trials_qa"):quit(2);return
 await process_frame
 var old: Node=root.get_node_or_null("HeavenlyTrialsClient")
 if old!=null:root.remove_child(old);old.free()
 var client: Node=load("res://tests/fixtures/heavenly_trials_client.gd").new();client.name="HeavenlyTrialsClient";root.add_child(client);client.set_process(false);client._owner="alice".sha256_text()
 for tier: int in [1,2,3]:await measure(client,tier)
 print("TRIALS_DURATION_ROWS ",JSON.stringify(rows))
 print("TRIALS_DURATION=MEASURED; CONDITIONAL_BUILD=true; PHONE_TESTED=false")
 if current_scene!=null:current_scene.free();current_scene=null
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit()
func measure(client: Node,tier: int) -> void:
 paused=false
 if current_scene!=null:current_scene.free();current_scene=null
 await process_frame
 var equipment: Node=root.get_node("EquipmentManager");var inventory: Node=root.get_node("InventoryManager");var progress: Node=root.get_node("ProgressionManager")
 equipment.active_run_loadout_snapshot.clear();equipment.weapon_levels.clear();equipment.ascension_stars.clear()
 for slot: String in equipment.get_slot_ids():equipment.equipped_item_ids[slot]=""
 for piece: String in preload("res://scripts/data/equipment_set_catalog.gd").get_piece_ids("moon_seal"):
  inventory.item_counts[piece]=1;equipment.ascension_stars[piece]=1;equipment.equipped_item_ids[str(equipment.get_item_data(piece).slot)]=piece
 var armament: String="nine_heavens_star_sword";inventory.item_counts[armament]=1;equipment.equipped_item_ids.armament=armament;equipment.ascension_stars[armament]=1;equipment.weapon_levels[armament]=10
 progress.sword_power_level=2+tier*2;progress.swift_qi_level=2+tier*2
 var now: int=int(Time.get_unix_time_from_system());var week: Dictionary={"id":"ht_probe_0","stage":5,"theme":"jade_wind","ends_at":now+604800}
 client.snapshot={"week":week,"server_time":now};client._received=Time.get_ticks_msec();client.launch_session={"id":"a".repeat(32),"week":week.id,"tier":tier,"started_at":now,"expires_at":now+900}
 root.get_node("GameSession").continue_game=false;seed(21102026)
 change_scene_to_file("res://scenes/levels/heavenly_trials.tscn");await create_timer(.1).timeout
 var world: Node=current_scene;world.ended=true;world.set_process(false)
 var player: CharacterBody2D=world.get_node("player_1");player.set_physics_process(false);player.experience_to_next_level=1000000
 player.get_node("PlayerHealth").rewarded_revive_invulnerable_until_msec=Time.get_ticks_msec()+3600000
 var spawner: Node=world.get_node("EnemySpawner");var wave: Node=world.get_node("WaveManager");spawner.set_process(false);wave.set_process(false);spawner.clear_normal_enemies();spawner.clear_enemy_attacks()
 var manager: Node=player.get_node("WeaponManager");manager.add_fire_orb();manager.add_thunder_talisman();manager.add_heavenly_sword_rain()
 for weapon: Weapon in manager.weapons:
  for step: int in range(2):weapon.upgrade()
 var stats: Node=player.get_node("PlayerStats")
 for step: int in range(4):stats.upgrade_power()
 for step: int in range(2):stats.upgrade_attack_speed()
 stats.sword_intent_level=1
 spawner.spawn_boss();var boss: Node2D=world._boss;var hp: float=float(boss.max_hp);boss.global_position=player.global_position+Vector2(160,0)
 defeated=false;phases=0;boss.boss_defeated.connect(func():defeated=true);boss.phase_changed.connect(func(_phase: int):phases+=1)
 var ticks: int=0
 while ticks<13680 and not defeated and is_instance_valid(boss):
  await physics_frame
  if defeated or not is_instance_valid(boss):break
  var angle: float=float(ticks)/60.0*.45
  var target: Vector2=boss.global_position+Vector2.from_angle(angle)*160
  player.velocity=(target-player.global_position).limit_length(player.get_effective_movement_speed()/60.0)*60.0;player.move_and_slide();ticks+=1
 var seconds: float=float(ticks)/60.0
 rows.append({"tier":tier,"boss_hp":hp,"won":defeated,"boss_seconds":seconds,"warmup_seconds":72,"conditional_total_seconds":72+seconds if defeated else null,"remaining_hp":float(boss.current_hp) if is_instance_valid(boss) else 0.0,"phases":phases})
 print("TRIALS_DURATION_ROW ",JSON.stringify(rows.back()))
