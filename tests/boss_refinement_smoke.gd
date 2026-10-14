extends SceneTree
const Profiles=preload("res://scripts/data/boss_premium_catalog.gd")
const Motion=preload("res://scripts/enemy/boss_pressure_motion.gd")
var checks: int=0
var failures: int=0
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("BOSS_REFINEMENT_FAIL "+label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_boss_refinement_qa"):quit(2);return
 root.size=Vector2i(648,1152)
 check(change_scene_to_file("res://scenes/levels/level_1.tscn")==OK,"actual arena loads")
 await create_timer(.3).timeout
 current_scene.get_node("EnemySpawner").process_mode=Node.PROCESS_MODE_DISABLED
 current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed()
 paused=false
 check(not paused,"fixture releases actual tutorial pause")
 var player: Node2D=current_scene.get_node("player_1")
 player.set_physics_process(false)
 player.get_node("WeaponManager").set_process(false)
 player.get_node("PlayerHealth").max_health=100000
 player.get_node("PlayerHealth").current_health=100000
 var count: int=0
 for catalog: Script in Profiles.Chapters:
  for stage: int in catalog.STAGES:
   var data: Dictionary=catalog.STAGES[stage]
   var boss: CharacterBody2D=load("res://scenes/enemy/boss_1.tscn").instantiate()
   if int(data.get("realm_id",0))>=4:boss.set_script(load("res://scripts/enemy/realm_boss.gd"))
   boss.configure_encounter(data)
   current_scene.add_child(boss)
   boss.set_physics_process(false)
   var sprite: AnimatedSprite2D=boss.get_node("AnimatedSprite2D")
   var footprint: Transform2D=boss.get_node("CollisionShape2D").transform
   check(boss.has_node("PremiumBossPresentation"),"all-realm presentation "+str(data.boss_name))
   check(bool(boss.get_meta("refined_boss_art",false)),"new atlas installed "+str(data.boss_name))
   check(sprite.sprite_frames.get_frame_count(&"walk_right")==4,"alternating walk poses")
   check(sprite.sprite_frames.get_frame_count(&"melee_right")==4,"committed action poses")
   var texture: AtlasTexture=sprite.sprite_frames.get_frame_texture(&"walk_right",0)
   check(texture.filter_clip and texture.atlas.get_width()==1024 and texture.atlas.get_height()==1280,"bounded active-realm atlas")
   for phase: int in [1,2]:
    boss.current_phase=phase
    boss.position=player.position+Vector2(265,0)
    boss.visual_action_timer=0;boss.phase_transition_timer=0;boss._ranged_cast_pending=false
    boss.attack_timer=1000;boss.ranged_attack_timer=1000;boss.shockwave_timer=1000
    var direction: Vector2=Motion.desired_velocity(boss,player,1.0,1.0)
    check(direction.dot(player.position-boss.position)>0,"closes player-range gap phase"+str(phase))
    if int(boss.get_meta("boss_pressure_role",0)) in [0,4]:
     boss.position=player.position+Vector2(boss.melee_distance+5,0)
     check(Motion.desired_velocity(boss,player,1,1).dot(player.position-boss.position)>0,"guard/sovereign closes toward melee")
     boss.position=player.position+Vector2(265,0)
    boss.set_physics_process(true)
    await create_timer(1.5).timeout
    boss.set_physics_process(false)
    check(boss.global_position.distance_to(player.global_position)<230,"actual reach within1.5s "+str(data.boss_name))
    check(player.get_node("WeaponManager")._is_target_attackable(boss),"player target becomes attackable")
    check(boss.get_node("CollisionShape2D").transform==footprint,"movement does not animate collider")
   boss.visual_action_timer=.4;boss.velocity=Vector2(100,0)
   boss.update_behavior();check(boss.velocity==Vector2.ZERO,"cast recovery remains intentional")
   boss.phase_transition_timer=.3;boss._physics_process(.016)
   check(boss.velocity==Vector2.ZERO,"phase ward remains stationary")
   boss.visual_action_timer=0;sprite.animation=&"idle_right";boss.facing_left=true;boss._play_idle_animation()
   check(sprite.flip_h,"actual facing mirrors art")
   boss.is_dead=true;boss._physics_process(.016)
   check(boss.velocity==Vector2.ZERO,"dead boss stops")
   boss.free();count+=1
 var melee: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate()
 current_scene.add_child(melee);melee.set_physics_process(false)
 melee.position=player.position+Vector2(80,0)
 var health: Node=player.get_node("PlayerHealth")
 health.qi_shield_charges=0
 var hp: float=health.current_health
 melee.attack_player();melee.attack_player()
 check(melee._melee_cast_pending and health.current_health==hp,"melee anticipation has no immediate/double hit")
 paused=true;await create_timer(.3,true).timeout
 check(health.current_health==hp and melee._melee_cast_pending,"melee anticipation pauses with combat")
 paused=false;await create_timer(.25).timeout
 check(health.current_health<hp and not melee._melee_cast_pending,"one impact after visible swing")
 hp=health.current_health;melee.attack_player()
 var player_origin: Vector2=player.position
 player.position+=Vector2(1000,0)
 await create_timer(.25).timeout
 check(health.current_health==hp,"stepping outside actual melee range dodges")
 player.position=player_origin;melee.attack_player();melee.current_phase=2
 await create_timer(.25).timeout
 check(health.current_health==hp,"phase cancels old melee impact")
 melee.attack_player();melee.is_dead=true
 await create_timer(.25).timeout
 check(health.current_health==hp,"dead boss cannot land deferred melee")
 melee.free()
 check(count==26,"all26 encounters")
 print("BOSS_REFINEMENT_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
