extends SceneTree
## Production physics, HP loss and ledger; isolated author fixture, not phone FPS.
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
var checks: int=0
var failures: int=0
var evidence: Dictionary={}
var player: Node2D
var stats: Node
var boss: Node2D
var changes: Array[float]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CONNECTION_COMBAT_HITS "+label)
func frames(count: int=3) -> void:
 for i: int in count:await physics_frame
func target_at(at: Vector2,large: bool=true) -> Node2D:
 var target: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate()
 target.max_hp=1000000;target.position=at;current_scene.add_child(target)
 target.set_physics_process(false);target.set_process(false)
 if large:
  var shape:=CircleShape2D.new();shape.radius=220
  target.get_node("CollisionShape2D").shape=shape
  target.get_node("CollisionShape2D").position=Vector2.ZERO
 return target
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_connection_combat_qa"):quit(2);return
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 root.get_node("GameSession").start_new_game()
 change_scene_to_file("res://scenes/levels/level_1.tscn");await create_timer(.4,true).timeout
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 for name_value: String in ["EnemySpawner","WaveManager","DifficultyManager"]:current_scene.get_node(name_value).process_mode=Node.PROCESS_MODE_DISABLED
 player=current_scene.get_node("player_1");player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
 stats=player.get_node("PlayerStats");stats.sword_intent_level=0
 var equipment: Node=root.get_node("EquipmentManager")
 equipment.active_run_loadout_snapshot={};equipment.equipped_item_ids={"armament":"","robe":"","bracer":"","boots":"","pendant":""}
 var weapon: Node=load("res://scripts/weapon/yin_yang_blades_weapon.gd").new()
 player.get_node("WeaponManager").add_child(weapon);weapon.activate(player);weapon.set_process(false)
 boss=target_at(player.get_node("CombatOrigin").global_position)
 boss.health_changed.connect(func(hp: float,_max_hp: float):changes.append(hp))
 var before: float=boss.current_hp
 await frames(5)
 var legacy: bool="--legacy-yin" in OS.get_cmdline_user_args()
 check(changes.size()==(1 if legacy else 2),"independent real Area2D contacts from both blades")
 check(before-boss.current_hp>0,"real boss HP decreased")
 var first_loss: float=before-boss.current_hp
 await frames(8)
 check(changes.size()==(1 if legacy else 2),"one blade cannot hit again every overlap frame")
 evidence.yin_yang={"legacy":legacy,"blade_count":weapon.blades.size(),"hp_loss":first_loss,"actual_hp_events":changes.size()}
 if legacy:
  print("LEGACY_YIN_REPRO checks=%d failures=%d evidence=%s"%[checks,failures,JSON.stringify(evidence)])
  weapon.queue_free();boss.queue_free();await process_frame
  current_scene.queue_free();current_scene=null;await process_frame
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0);return
 weapon.update_hit_cooldowns(weapon.HIT_INTERVAL+.01);await frames(3)
 check(changes.size()==4,"both blades hit again after their own cooldown")
 weapon.clear_blades();check(weapon.hit_cooldowns.is_empty(),"rebuilding removes old blade cooldown state")
 weapon.queue_free();boss.queue_free();await process_frame;await frames()
 # Two physical Spirit Sword projectiles landing on one actual boss in one tick.
 boss=target_at(player.global_position+Vector2(480,0));changes.clear()
 boss.health_changed.connect(func(hp: float,_max_hp: float):changes.append(hp))
 var shots: Array[Node2D]=[]
 before=boss.current_hp
 for i: int in 2:
  var shot: Node2D=load("res://scenes/weapons/spirit_sword.tscn").instantiate()
  shot.damage=13;shot.speed=0;shot.direction=Vector2.ZERO;shot.pierce=2;shot.position=boss.position
  current_scene.add_child(shot);shots.append(shot)
 await frames(5)
 check(changes.size()==2 and is_equal_approx(before-boss.current_hp,26.0),"two swords count as two actual 13-damage hits")
 for shot: Node2D in shots:shot._on_body_entered(boss)
 check(changes.size()==2,"one sword cannot recount the same target")
 evidence.spirit_sword={"projectiles":2,"hp_loss":before-boss.current_hp,"actual_hp_events":changes.size()}
 for shot: Node2D in shots:shot.queue_free()
 boss.queue_free();await process_frame;await frames()
 # The level-5 production launcher must aim both swords at a lone boss.
 boss=target_at(player.global_position+Vector2(160,0),false);changes.clear()
 boss.health_changed.connect(func(hp: float,_max_hp: float):changes.append(hp))
 var sword: Node=load("res://scripts/weapon/spirit_sword_weapon.gd").new()
 sword.level=5;player.get_node("WeaponManager").add_child(sword)
 before=boss.current_hp;sword.attack(player,boss)
 await create_timer(.6,true).timeout
 check(changes.size()>=2 and before>boss.current_hp,"production level-5 second sword reaches a single real boss")
 evidence.spirit_sword_level5={"hp_loss":before-boss.current_hp,"actual_hp_events":changes.size()}
 sword.queue_free();boss.queue_free();await process_frame;await frames()
 # Real gems are collected through their normal XP rounding path before boss signal.
 player.experience=0;player.experience_to_next_level=1000000000
 var expected: int=0
 for i: int in 20:
  var gem: Node2D=load("res://scenes/pickups/xp_gem.tscn").instantiate()
  gem.experience_value=i%5+1;gem.position=player.position+Vector2(5000+i*40,5000)
  current_scene.add_child(gem)
  expected+=int(round(gem.experience_value*player.get_experience_multiplier()))
 await frames(2)
 check(get_node_count_in_group("qi_pickup")==20,"twenty distant gems remain before boss entry")
 var spawner: Node=current_scene.get_node("EnemySpawner")
 var at_spawn: Array[int]=[]
 spawner.boss_spawned_signal.connect(func(new_boss: Node) -> void:
  # This case measures entry/XP, not boss AI; freeze the spawned actor as well.
  new_boss.set_process(false);new_boss.set_physics_process(false)
  at_spawn.append(get_node_count_in_group("qi_pickup")))
 spawner.spawn_boss()
 check(at_spawn==[0],"boss signal sees zero leftover crystals")
 check(player.experience==expected,"all existing XP retained with per-gem multipliers/rounding")
 check(spawner.collect_boss_entry_crystals()==0 and player.experience==expected,"boss collection is idempotent")
 evidence.boss_entry={"gems":20,"expected_xp":expected,"actual_xp":player.experience,"remaining_at_boss_spawn":at_spawn}
 var before_overflow: int=player.experience
 for i: int in 175:
  var gem: Node2D=load("res://scenes/pickups/xp_gem.tscn").instantiate();gem.experience_value=2;gem.position=player.position+Vector2(7000+i*30,7000);current_scene.add_child(gem)
 var capped: int=get_node_count_in_group("qi_pickup")
 var overflow_expected: int=0
 for gem: Node in get_nodes_in_group("qi_pickup"):overflow_expected+=int(round(gem.experience_value*player.get_experience_multiplier()))
 check(capped==160,"overflow merges preserve a bounded set of live pickups in the same frame")
 check(spawner.collect_boss_entry_crystals()==160 and get_node_count_in_group("qi_pickup")==0,"capped field is fully collected without waiting for deferred deletion")
 check(player.experience-before_overflow==overflow_expected,"merged overflow keeps its full normal XP value")
 evidence.boss_entry.overflow={"spawned":175,"active_cap":capped,"actual_xp":player.experience-before_overflow,"expected_xp":overflow_expected}
 # Aura is held without deleting the player's cosmetic ownership or charging currency.
 var pavilion: Node=root.get_node("PavilionManager")
 var original_cosmetics: Dictionary=pavilion.state.duplicate(true)
 var retained_id: String="plain"
 for id: String in pavilion.COSMETICS:
  if id!="plain":retained_id=id;break
 pavilion.state.cosmetic_id=retained_id
 if retained_id not in pavilion.state.owned_cosmetics:pavilion.state.owned_cosmetics.append(retained_id)
 var saved: Dictionary=pavilion.state.duplicate(true)
 var balance: int=root.get_node("ProgressionManager").spirit_stone
 check(not pavilion.is_aura_feature_enabled(),"aura feature is held")
 check(not pavilion.acquire_cosmetic("plain") and not pavilion.select_cosmetic("plain"),"held cosmetic actions cannot write or spend")
 check(pavilion.state==saved and root.get_node("ProgressionManager").spirit_stone==balance,"aura ownership, selection and balance preserved")
 player.get_node("PavilionAuraPresentation")._sync_aura()
 check(not player.get_node("PavilionAuraPresentation").visible,"saved aura is not rendered")
 check(player.get_node("PavilionAuraPresentation")._visual==null,"held aura does not load its visual resources")
 check(pavilion.get_cosmetic_id()==retained_id and pavilion.is_cosmetic_owned(retained_id),"previously owned non-plain aura remains in the save")
 pavilion.state=original_cosmetics
 print("CONNECTION_COMBAT_HITS checks=%d failures=%d; evidence=%s"%[checks,failures,JSON.stringify(evidence)])
 var file:=FileAccess.open("user://connection-combat-hits.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence},"\t"));file.close()
 # Release the run coroutine's local scene/resource references before shutdown.
 finish.call_deferred()
func finish() -> void:
 current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 current_scene.queue_free();await process_frame;current_scene=null
 boss=null;player=null;stats=null;changes.clear()
 # Area deletion is deferred by the physics server, independently of render frames.
 await physics_frame;await physics_frame
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 call_deferred("quit",1 if failures else 0)
