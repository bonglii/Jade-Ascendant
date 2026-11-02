extends SceneTree
const Patterns=preload("res://scripts/data/realm_attack_patterns.gd")
const Sequence=preload("res://scripts/enemy/realm_attack_sequence.gd")
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
const Sets=preload("res://scripts/data/equipment_set_catalog.gd")
var checks: int=0
var failures: int=0
var player: Node2D
var stats: Node
var targets: Array[Node]=[]
var formation: Node2D
var evidence: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("SIX_COMBAT "+label)
func reset_targets() -> void:
 for enemy: Node in targets:
  enemy.current_hp=enemy.max_hp
  var status: Node=enemy.get_node_or_null("EquipmentSetStatus")
  if status!=null:status.free()
 player.get_node("WeaponManager/RunCombatLedger").totals.clear()
 stats.pending_critical_feedback=false
func legacy_pulse() -> void:
 for body: Node in formation.get_overlapping_bodies():
  if is_instance_valid(body) and body.has_method("take_damage"):
   Ledger.apply_hit(body,stats.calculate_damage(formation.base_damage),"eight_trigrams_formation")
func damage_state() -> Array:
 var values: Array=[]
 for enemy: Node in targets:
  var status: Node=enemy.get_node_or_null("EquipmentSetStatus")
  values.append([enemy.current_hp,status.tick_damage if status!=null else 0,status.ticks_left if status!=null else 0])
 values.append(player.get_node("WeaponManager/RunCombatLedger").snapshot())
 return values
func clear_sequences() -> void:
 for attack: Node in get_nodes_in_group("realm_boss_telegraph")+get_nodes_in_group("realm_mob_sequence"):attack.free()
func review_attack(_boss: Node2D, _attack: Node, _id: String) -> void:pass
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_six_fixes_qa"):quit(2);return
 create_timer(85,true).timeout.connect(func():push_error("Six combat watchdog");quit(3))
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 change_scene_to_file("res://scenes/levels/level_1.tscn");await create_timer(.4,true).timeout
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed();paused=false
 for name_v: String in ["EnemySpawner","WaveManager","DifficultyManager"]:current_scene.get_node(name_v).process_mode=Node.PROCESS_MODE_DISABLED
 player=current_scene.get_node("player_1");player.set_physics_process(false);player.get_node("WeaponManager").set_process(false)
 stats=player.get_node("PlayerStats");stats.sword_intent_level=5
 var health: Node=player.get_node("PlayerHealth");health.max_health=100000;health.current_health=100000;health.qi_shield_charges=0
 for i: int in 120:
  var enemy: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate()
  enemy.max_hp=1.0e7;current_scene.add_child(enemy);enemy.global_position=player.global_position+Vector2((i%12-6)*3,(i/12-5)*3)
  enemy.set_physics_process(false)
  if i%3==0:enemy.damage_reduction_sources[123]=.5
  targets.append(enemy)
 formation=load("res://scenes/weapons/eight_trigrams_formation.tscn").instantiate()
 formation.setup(8,150,60,.75,stats);current_scene.add_child(formation);formation.global_position=player.global_position;formation.set_physics_process(false)
 await physics_frame;await physics_frame;await physics_frame;await process_frame
 check(formation.get_overlapping_bodies().size()==120,"120 actual physics overlaps")
 var equipment: Node=root.get_node("EquipmentManager")
 var cases: Array[String]=[""]
 for id: String in Sets.SET_ORDER:
  if str(Sets.get_active_passive(Sets.get_piece_ids(id)).get("kind","")) in ["poison","burn","bleed","frost","verdict"]:cases.append(id)
 var timing: Dictionary={}
 for set_id: String in cases:
  equipment.active_run_loadout_snapshot={};equipment.equipped_item_ids={"armament":"mistveil_jian","robe":"","bracer":"","boots":"","pendant":""}
  if not set_id.is_empty():
   for id: String in Sets.get_piece_ids(set_id):equipment.equipped_item_ids[equipment.get_item_data(id).slot]=id
  reset_targets();seed(9151);var started: int=Time.get_ticks_usec();legacy_pulse();var before_usec: int=Time.get_ticks_usec()-started
  var reference: Array=damage_state()
  reset_targets();seed(9151);started=Time.get_ticks_usec();formation._apply_damage_pulse();var after_usec: int=Time.get_ticks_usec()-started
  check(damage_state()==reference,"per-target damage/crit/reduction/status/ledger parity "+set_id)
  check(equipment._combat_batch_depth==0 and preload("res://scripts/data/equipment_set_runtime.gd")._batch_depth==0,"no cache escapes the synchronous pulse")
  check(get_node_count_in_group("equipment_set_status")<=64,"status cap preserved")
  timing["none" if set_id.is_empty() else set_id]={"unbatched_us":before_usec,"batched_us":after_usec}
 evidence["trigram_cpu"]=timing
 # All production 4/5 boss IDs are distinct and never invoke I-III's attack set.
 var used: Array[String]=[]
 for catalog: Script in [preload("res://scripts/data/chapter_four_catalog.gd"),preload("res://scripts/data/chapter_five_catalog.gd")]:
  for stage: int in catalog.STAGES:
   var profile: Dictionary=catalog.get_stage(stage)
   var boss: Node2D=load("res://scenes/enemy/boss_realm_%d.tscn"%int(profile.realm_id)).instantiate()
   boss.configure_encounter(profile);current_scene.add_child(boss);boss.global_position=player.global_position+Vector2(150,0);boss.set_physics_process(false)
   check(boss.has_node("BossFrameDriver") and boss.has_node("RealmActorFinish"),"painted animation and roster polish active "+str(profile.boss_name))
   var footprint: Transform2D=boss.get_node("CollisionShape2D").transform
   for id: String in boss.authored_patterns+[boss.boss_signature]:
    check(Patterns.IDS.has(id) and id not in used,"unique boss pattern "+id);used.append(id)
    clear_sequences();boss._cast_realm_pattern(id,player.global_position)
    check(get_node_count_in_group("realm_boss_telegraph")==1,"actual runtime launches "+id)
    var attack: Node=get_first_node_in_group("realm_boss_telegraph")
    check(attack.pattern==id and attack.zones.size()>0 and attack.zones.size()<=6,"bounded authored sequence "+id)
    await review_attack(boss,attack,id)
    check(boss.get_node("CollisionShape2D").transform==footprint,"body action never animates hitbox")
   clear_sequences();boss.current_phase=2;boss._first_phase_two_signature_pending=true;boss.ranged_attack_timer=0;boss.try_ranged_attack()
   check(get_first_node_in_group("realm_boss_telegraph").pattern==boss.boss_signature,"phase2 showcases own signature")
   boss.is_dead=true
   get_first_node_in_group("realm_boss_telegraph")._process(.01)
   check(get_first_node_in_group("realm_boss_telegraph").is_queued_for_deletion(),"boss death cancels unreleased sequence")
   clear_sequences();boss.free()
 for id: String in Patterns.IDS:
  var zones: Array[Dictionary]=Patterns.build(id,Vector2.ZERO,Vector2(230,0))
  var points: Array=[]
  for zone: Dictionary in zones:
   check(float(zone.warning)>=1.0,"full second of locked warning "+id)
   match zone.kind:
    "disc":check(Patterns.contains(zone,zone.at) and not Patterns.contains(zone,zone.at+Vector2(float(zone.radius)+1,0)),"disc border matches damage")
    "lane":check(Patterns.contains(zone,zone.at+zone.aim*40) and not Patterns.contains(zone,zone.at-zone.aim*1),"lane endpoints match damage")
    "sector":check(Patterns.contains(zone,zone.at+zone.aim*50) and not Patterns.contains(zone,zone.at-zone.aim*50),"fan counterplay behind caster")
    "ring":check(not Patterns.contains(zone,zone.at) and not Patterns.contains(zone,zone.at+Vector2.from_angle(zone.gap)*(zone.inner+zone.outer)*.5),"safe center and visible open gap")
   var record: Dictionary=zone.duplicate();record.at=[zone.at.x,zone.at.y]
   if zone.has("aim"):record.aim=[zone.aim.x,zone.aim.y]
   points.append(record)
  evidence[id]=points
 # Sample an actual impact before/after warning, plus pause, expiry and scene budget.
 clear_sequences()
 var cast: Node=Sequence.launch(current_scene,"ember_spear_run",player.global_position-Vector2(150,0),player.global_position,7)
 cast.set_process(false);health.hit_guard_remaining=0
 var hp: float=health.current_health
 var cast_age: float=cast.age
 paused=true;await create_timer(.04,true).timeout
 check(cast.age==cast_age,"pause freezes the sequence")
 paused=false
 cast._process(.99);check(health.current_health==hp,"warning itself cannot hit")
 cast._process(.02);check(health.current_health<hp,"actual first impact applies once")
 hp=health.current_health;health.hit_guard_remaining=0;cast._process(.01);check(health.current_health==hp,"same impact cannot repeat")
 clear_sequences()
 for i: int in 5:Sequence.launch(current_scene,"frost_pincer",Vector2.ZERO,Vector2.RIGHT,7)
 check(get_node_count_in_group("realm_boss_telegraph")==2,"at most two concurrent boss sequences")
 clear_sequences()
 for chapter: int in [4,5]:
  var spawner: Node=load("res://scripts/enemy/realm_enemy_spawner.gd").new();spawner.configure_stage_profile({"realm_id":chapter,"enemy_visual_set":"frostveil" if chapter==4 else "solar_nirvana"})
  for role: int in range(1,7):
   var entity: Node2D=load("res://scenes/enemy/realm_ranged_enemy.tscn" if role==2 else "res://scenes/enemy/enemy_%d.tscn"%role).instantiate()
   spawner.apply_stage_enemy_identity(entity,role);current_scene.add_child(entity);entity.global_position=player.global_position+Vector2(200,0);entity.set_physics_process(false)
   check(entity.has_node("RealmActorFinish"),"all normal role visuals polished "+str(chapter)+"/"+str(role))
   if role==2:
    entity.locked_aim=player.global_position;entity.use_locked_aim=true;entity.shoot_projectile()
    check(get_node_count_in_group("realm_mob_projectile")>0,"realm projectiles actually spawned")
   if role==4:
    entity.cast_target_position=player.global_position;entity.spawn_telegraph()
    check(get_node_count_in_group("realm_mob_sequence")>0,"caster uses new chapter sequence")
   entity.free();clear_sequences()
  spawner.free()
 DirAccess.make_dir_recursive_absolute("res://.local/six_review")
 var file:=FileAccess.open("res://.local/six_review/combat.json",FileAccess.WRITE);file.store_string(JSON.stringify(evidence));file.close()
 print("TRIGRAM_PARITY_CPU="+JSON.stringify(timing))
 print("SIX_FIXES_COMBAT checks=%d failures=%d; NATIVE_GUI=%s; PHONE=NOT_TESTED"%[checks,failures,str(DisplayServer.get_name()!="headless")])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
