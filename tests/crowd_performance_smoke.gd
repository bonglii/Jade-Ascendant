extends SceneTree
var checks: int=0
var failures: int=0
class Victim extends Node2D:
 var dead: bool=false
 var status_reads: int=0
 var is_dead: bool:
  get:
   status_reads+=1
   return dead
 func take_damage(_value: float) -> void:pass
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CROWD_PERF_FAIL "+label)
func old_sweep(flight: Node,start: Vector2,finish: Vector2,player: Node2D,enemies: Array[Node],phase_id: int) -> void:
 for enemy: Node in enemies:
  if not flight.living(enemy):continue
  var reach: float=flight.boss_range if enemy.is_in_group("boss") else flight.normal_range
  if enemy.global_position.distance_to(player.global_position)>reach:continue
  var closest: Vector2=Geometry2D.get_closest_point_to_segment(enemy.global_position,start,finish)
  if closest.distance_to(enemy.global_position)<=flight.HIT_RADIUS:flight._hit(player,enemy,phase_id,1.0)
func old_nearest(player: Node2D,enemies: Array[Node],maximum: float,boss_maximum: float) -> Node2D:
 var nearest: Node2D=null
 var distance_sq: float=maximum*maximum
 for enemy: Node in enemies:
  if not enemy is Node2D or enemy.is_queued_for_deletion() or bool(enemy.get("is_dead")) or not enemy.has_method("take_damage"):continue
  var candidate: float=player.global_position.distance_squared_to(enemy.global_position)
  if candidate>distance_sq or (candidate>boss_maximum*boss_maximum and enemy.is_in_group("boss")):continue
  if nearest==null or candidate<distance_sq:distance_sq=candidate;nearest=enemy
 return nearest
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_crowd_qa"):quit(2);return
 await create_timer(.5).timeout
 var window: RefCounted=load("res://scripts/debug/combat_perf_window.gd").new()
 for value: float in [10,20,30,40,60]:window.add(value)
 var snapshot: Dictionary=window.snapshot()
 check(snapshot.count==5 and snapshot.mean_ms==32 and snapshot.p95_ms==60 and snapshot.max_ms==60,"frame statistics preserve slow frames")
 check(snapshot.over_33==2 and snapshot.over_50==1,"stutter thresholds are strict")
 window.add(-1);window.add(INF);window.add(NAN);check(window.count==5,"invalid samples excluded")
 for i: int in range(5000):window.add(16)
 check(window.samples.size()==window.CAPACITY and window.count==5005,"storage remains bounded while full counters survive")
 window.reset();check(window.snapshot().count==0 and window.samples.is_empty(),"sampling reset has no stale percentile")
 window.add(16,2,3);window.add(16,4,7)
 snapshot=window.snapshot();check(snapshot.process_mean_ms==3 and snapshot.physics_mean_ms==5 and snapshot.physics_max_ms==7,"CPU monitor aggregates cover the sampling window")
 var manager: Node=load("res://scripts/weapon/weapon_manager.gd").new()
 manager._debug_last_frame_usec=123
 manager._notification(Node.NOTIFICATION_PAUSED)
 check(manager._debug_last_frame_usec==0,"deliberate pause invalidates frame baseline")
 manager.free()
 var player: Node2D=load("res://scripts/player/player_1.gd").new();player.process_mode=Node.PROCESS_MODE_DISABLED
 var sprite:=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D";player.add_child(sprite)
 for name_value: String in ["PlayerStats","WeaponManager"]:
  var child:=Node.new();child.name=name_value;player.add_child(child)
 root.add_child(player)
 var enemies: Array[Node]=[]
 var rng:=RandomNumberGenerator.new();rng.seed=13102026
 for i: int in range(800):
  var enemy:=Victim.new();root.add_child(enemy);enemy.add_to_group("enemy")
  enemy.position=Vector2(rng.randf_range(-1800,1800),rng.randf_range(-1800,1800));enemy.dead=i%17==0
  if i%13==0:enemy.add_to_group("boss")
  enemies.append(enemy)
 # Boundary fixtures: exact tangent, point sweep, dead target, normal/boss range.
 for pos: Vector2 in [Vector2(100,24),Vector2(100,24.001),Vector2(320,0),Vector2(230,0),Vector2.ZERO]:
  var enemy:=Victim.new();root.add_child(enemy);enemy.add_to_group("enemy");enemy.position=pos;enemies.append(enemy)
 var script: Script=load("res://tests/crowd_sweep_fixture.gd")
 var optimized: Node=script.new();var reference: Node=script.new();root.add_child(optimized);root.add_child(reference)
 optimized.set_physics_process(false);reference.set_physics_process(false)
 for i: int in range(90):
  player.position=Vector2(rng.randf_range(-80,80),rng.randf_range(-80,80))
  var start: Vector2=Vector2.ZERO if i==0 else Vector2(rng.randf_range(-300,300),rng.randf_range(-300,300))
  var finish: Vector2=Vector2(200,0) if i==0 else start if i%4==0 else Vector2(rng.randf_range(-300,300),rng.randf_range(-300,300))
  optimized.hits.clear();optimized.contact_ids.clear();reference.hits.clear();reference.contact_ids.clear()
  var phase_id: int=i%4
  old_sweep(reference,start,finish,player,enemies,phase_id)
  optimized._sweep(start,finish,player,enemies,phase_id,1.0)
  check(optimized.contact_ids==reference.contact_ids,"sweep preserves exact contacts and order "+str(i))
  optimized._sweep(start,finish,player,enemies,phase_id,1.0)
  check(optimized.contact_ids==reference.contact_ids,"same phase never repeats damage "+str(i))
  check(player.find_nearest_enemy(320,230)==old_nearest(player,enemies,320,230),"nearest preserves living target/range/ties "+str(i))
 for enemy: Node in enemies:enemy.status_reads=0
 optimized.hits.clear();optimized._sweep(Vector2.ZERO,Vector2(200,0),player,enemies,0,1.0)
 var optimized_reads: int=0
 for enemy: Node in enemies:optimized_reads+=enemy.status_reads;enemy.status_reads=0
 reference.hits.clear();old_sweep(reference,Vector2.ZERO,Vector2(200,0),player,enemies,0)
 var reference_reads: int=0
 for enemy: Node in enemies:reference_reads+=enemy.status_reads
 check(optimized_reads<reference_reads/5,"broad phase reduces expensive status queries in crowds")
 print("CROWD_STATUS_READS old=",reference_reads," optimized=",optimized_reads)
 var start_usec: int=Time.get_ticks_usec()
 for i: int in range(100):
  reference.hits.clear();reference.contact_ids.clear();old_sweep(reference,Vector2.ZERO,Vector2(200,0),player,enemies,0)
 var before_usec: int=Time.get_ticks_usec()-start_usec
 start_usec=Time.get_ticks_usec()
 for i: int in range(100):
  optimized.hits.clear();optimized.contact_ids.clear();optimized._sweep(Vector2.ZERO,Vector2(200,0),player,enemies,0,1.0)
 print("CROWD_SWEEP_CPU_US old=",before_usec," optimized=",Time.get_ticks_usec()-start_usec," enemies=",enemies.size()," repetitions=100")
 for enemy: Node in enemies:enemy.queue_free()
 player.queue_free();optimized.queue_free();reference.queue_free();await process_frame
 print("CROWD_PERFORMANCE_CHECKS=",checks,";FAILURES=",failures)
 quit(0 if failures==0 else 1)
