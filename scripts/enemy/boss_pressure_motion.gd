extends RefCounted
## Pressure between casts. No teleport, no changes to HP/damage/cooldowns.
static func desired_velocity(boss: CharacterBody2D, target: Node2D, clock: float, side: float) -> Vector2:
 if not is_instance_valid(target): return Vector2.ZERO
 var offset: Vector2=target.global_position-boss.global_position
 var distance: float=offset.length()
 if distance<1.0:return Vector2.ZERO
 var direction: Vector2=offset/distance
 var manager: Node=target.get_node_or_null("WeaponManager")
 var reachable: float=preload("res://scripts/data/weapon_reach.gd").BOSS
 if manager!=null:reachable=minf(float(manager.maximum_attack_range),float(manager.boss_attack_range))
 # Close into actual player reach, leaving a margin for both bodies and aim refresh.
 var engage: float=maxf(48.0,minf(reachable*.76,float(boss.melee_distance)+45.0))
 var role: int=int(boss.get_meta("boss_pressure_role",0))
 if role in [0,4]:engage=minf(engage,float(boss.melee_distance)*.85)
 var chase: float=clampf((distance-engage)/55.0,0.0,1.0)
 # Never anchor in the gap outside player attack range, regardless of ranged AI radius.
 if distance>reachable*.90:return direction*float(boss.speed)
 var orbit: float=[.18,.72,.30,.48,.42][role]
 var pulse: float=.65+.35*sin(clock*(1.4+role*.12))
 var radial: float=chase
 if distance<engage-20.0 and role in [1,3]:radial=-.22
 if distance<64.0:return Vector2.ZERO
 var motion: Vector2=direction*radial+direction.orthogonal()*side*orbit*pulse
 return motion.limit_length(1.0)*float(boss.speed)*(.85 if boss.current_phase==1 else 1.0)
