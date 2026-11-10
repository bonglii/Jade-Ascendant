extends Node2D
const Vfx = preload("res://scripts/effects/weapon_vfx_art.gd")
const Reach=preload("res://scripts/data/weapon_reach.gd")
## Three separate readable mechanics share bounded bookkeeping, not attack geometry.
const Ledger=preload("res://scripts/weapon/run_combat_ledger.gd")
const Slow=preload("res://scripts/weapon/jade_binding_slow.gd")
const MAX_ACTIVE_CASTS: int=8
var mode: String=""
var level: int=1
var amount: float=10
var cast_reach: float=Reach.NORMAL
var age: float=0
var origin: Vector2
var aim: Vector2=Vector2.RIGHT
var player_ref: WeakRef
var feathers: Array[Dictionary]=[]
var fan_hits: Dictionary={}
var phases_done: Dictionary={}
var pulses: int=2
var radius: float=75
var resonance_used: bool=false
var icon: Texture2D
static func living(value: Variant) -> bool:
 return is_instance_valid(value) and value is Node2D and value.is_inside_tree() and not value.is_queued_for_deletion() and value.is_in_group("enemy") and not bool(value.get("is_dead")) and value.has_method("take_damage")
func configure(player: Node2D,target: Node2D,id: String,run_level: int,damage: float) -> void:
 mode=id;level=run_level;amount=damage;player_ref=weakref(player)
 cast_reach=Reach.normal(player)
 origin=player.global_position;global_position=origin;aim=origin.direction_to(target.global_position)
 if aim==Vector2.ZERO:aim=Vector2.RIGHT
 z_index=7;add_to_group("ascendant_armament_cast")
 var path: String="res://assets/ui/equipment/expansion_20261014/"+mode+".png"
 if ResourceLoader.exists(path):icon=load(path)
 if mode=="phoenix_war_fan":
  get_tree().root.get_node("AudioManager").play_sfx("phoenix_fan")
  var count: int=3+int(level>=3)+int(level>=5)+2*int(level>=7)
  var side_index: int=0
  for index: int in range(count):
   var central: bool=index==floori(count/2.0)
   var angle: float=0.0
   if not central:
    angle=(.26+.12*floori(side_index/2.0))*(1 if side_index%2==0 else -1)
    side_index+=1
   feathers.append({"position":origin,"direction":aim.rotated(angle),"hits":{},"spent":false,"central":index==floori(count/2.0)})
 elif mode=="astral_resonance_bell":
  pulses=2+int(level>=3)+int(level>=7)
  radius=75+20*int(level>=3)+20*int(level>=5)+20*int(level>=7)
func _physics_process(delta: float) -> void:
 var player: Variant=player_ref.get_ref()
 if not is_instance_valid(player) or player.is_queued_for_deletion():queue_free();return
 age+=delta
 if mode=="phoenix_war_fan":_advance_fan(player,delta)
 elif mode=="void_piercer_spear":
  if age>=.30 and not phases_done.has(0):
   phases_done[0]=true;get_tree().root.get_node("AudioManager").play_sfx("void_thrust");_thrust(player,2.2)
  if level>=5 and age>=.48 and not phases_done.has(1):
   phases_done[1]=true;_thrust(player,.66)
 elif mode=="astral_resonance_bell":
  for pulse: int in range(pulses):
   if age>=.20+pulse*.55 and not phases_done.has(pulse):
    phases_done[pulse]=true;
    if pulse==0:get_tree().root.get_node("AudioManager").play_sfx("astral_bell")
    _pulse(player,pulse)
 var lifetime: float=maxf(1.10,cast_reach/300.0+.10) if mode=="phoenix_war_fan" else .78 if mode=="void_piercer_spear" else .20+(pulses-1)*.55+.65
 if age>=lifetime:queue_free();return
 queue_redraw()
func reachable(enemy: Node2D,player: Node2D) -> bool:
 return enemy.global_position.distance_squared_to(origin)<=pow(Reach.limit(player,enemy),2)
func _hit(player: Node2D,enemy: Node2D,multiplier: float,resonance: bool=false) -> void:
 if not living(enemy) or not reachable(enemy,player):return
 var stats: Node=player.get("player_stats")
 if stats==null:return
 var result: Dictionary=stats.calculate_damage_result(amount*multiplier)
 if resonance and not resonance_used and bool(result.is_critical) and stats.has_sword_dao_resonance():
  result.damage*=1.4;resonance_used=true
 CombatFeedback.mark_next_hit_critical(enemy,bool(result.is_critical))
 Ledger.apply_hit(enemy,float(result.damage),mode)
func _advance_fan(player: Node2D,delta: float) -> void:
 var enemies: Array[Node]=get_tree().get_nodes_in_group("enemy")
 for feather: Dictionary in feathers:
  if feather.spent:continue
  var start: Vector2=feather.position
  var finish: Vector2=start+Vector2(feather.direction)*300*delta
  var candidates: Array[Node2D]=[]
  for node: Node in enemies:
   if not living(node) or not reachable(node,player):continue
   var id: int=node.get_instance_id()
   if feather.hits.has(id) or int(fan_hits.get(id,0))>=2:continue
   var closest: Vector2=Geometry2D.get_closest_point_to_segment(node.global_position,start,finish)
   if closest.distance_squared_to(node.global_position)<=18*18:candidates.append(node)
  candidates.sort_custom(func(a: Node2D,b: Node2D):return a.global_position.distance_squared_to(start)<b.global_position.distance_squared_to(start))
  for enemy: Node2D in candidates:
   if feather.hits.size()>=(2 if level>=5 else 1):break
   var id: int=enemy.get_instance_id()
   feather.hits[id]=true;fan_hits[id]=int(fan_hits.get(id,0))+1
   _hit(player,enemy,.90,bool(feather.central))
  feather.position=finish
  if feather.hits.size()>=(2 if level>=5 else 1) or origin.distance_squared_to(finish)>cast_reach*cast_reach:feather.spent=true
func _thrust(player: Node2D,multiplier: float) -> void:
 var candidates: Array[Node2D]=[]
 var width: float=18+3*int(level>=3)+3*int(level>=7)
 for node: Node in get_tree().get_nodes_in_group("enemy"):
  if not living(node) or not reachable(node,player):continue
  var closest: Vector2=Geometry2D.get_closest_point_to_segment(node.global_position,origin,origin+aim*cast_reach)
  if closest.distance_squared_to(node.global_position)<=width*width:candidates.append(node)
 candidates.sort_custom(func(a: Node2D,b: Node2D):return a.global_position.distance_squared_to(origin)<b.global_position.distance_squared_to(origin))
 for index: int in range(mini(candidates.size(),8)):_hit(player,candidates[index],multiplier,multiplier>1)
func _pulse(player: Node2D,pulse: int) -> void:
 var targets: Array[Node2D]=[]
 for node: Node in get_tree().get_nodes_in_group("enemy"):
  if living(node) and reachable(node,player) and node.global_position.distance_squared_to(origin)<=radius*radius:targets.append(node)
 targets.sort_custom(func(a: Node2D,b: Node2D):return a.global_position.distance_squared_to(origin)<b.global_position.distance_squared_to(origin))
 for index: int in range(mini(targets.size(),12)):
  var enemy: Node2D=targets[index]
  _hit(player,enemy,.80,pulse==pulses-1)
  if living(enemy):Slow.apply(enemy,.4,.85,.95)
func _draw() -> void:
 var low: bool = Vfx.low_detail(self)
 match mode:
  "phoenix_war_fan": _draw_fan(low)
  "void_piercer_spear": _draw_spear(low)
  "astral_resonance_bell": _draw_bell(low)

func _draw_fan(low: bool) -> void:
 if icon != null and age < 0.25:
  draw_set_transform(Vector2.ZERO, aim.angle() + PI * 0.5)
  draw_texture_rect(icon, Rect2(-Vector2(38, 38), Vector2(76, 76)), false, Color(1, 1, 1, 1 - age / 0.25))
  draw_set_transform(Vector2.ZERO)
 for feather: Dictionary in feathers:
  if feather.spent:
   continue
  var at: Vector2 = Vector2(feather.position) - origin
  var direction: Vector2 = feather.direction
  var normal: Vector2 = direction.orthogonal()
  if not low:
   Vfx.ribbon(self, at, direction, Vector2(42, 15), Color(1, 0.30, 0.06, 0.45),
    Color(1, 0.65, 0.22, 0.73), 1.0 if direction.cross(aim) >= 0 else -1.0)
  var contour := PackedVector2Array([at + direction * 7, at + direction + normal * 3,
   at - direction * 6 + normal * 5, at - direction * 22 + normal,
   at - direction * 14 - normal * 3, at - direction * 7 - normal * 4])
  draw_colored_polygon(contour, Color(1, 0.31, 0.08, 0.88))
  draw_polyline(PackedVector2Array([at - direction * 21, at - direction * 7 + normal * 1.5,
   at + direction * 5]), Color(1, 0.89, 0.48), 1.5, true)

func _draw_spear(low: bool) -> void:
 var width: float = 18 + 3 * int(level >= 3) + 3 * int(level >= 7)
 var edge: Vector2 = aim.orthogonal() * width
 var tip: Vector2 = aim * cast_reach
 if age < 0.30:
  var charge: float = clampf(age / 0.30, 0.0, 1.0)
  draw_line(Vector2.ZERO, tip, Color(0.73, 0.64, 1.0, 0.38 + charge * 0.22), 1.5, true)
  draw_line(edge, tip + edge, Color(0.81, 0.70, 1.0, 0.37), 1.0, true)
  draw_line(-edge, tip - edge, Color(0.81, 0.70, 1.0, 0.37), 1.0, true)
  _draw_spear_icon(aim * 28, 1.0)
  return
 var strike_age: float = age - (0.48 if level >= 5 and age >= 0.48 else 0.30)
 var fade: float = pow(clampf(1.0 - strike_age / 0.30, 0.0, 1.0), 1.5)
 if age < 0.53:
  _draw_spear_icon(aim * lerpf(28, cast_reach - 24, clampf((age - 0.30) / 0.18, 0.0, 1.0)), fade)
 draw_line(Vector2.ZERO, tip, Color(0.84, 0.79, 1.0, fade), 2.8, true)
 if not low:
  for index in range(3):
   var at: Vector2 = aim * cast_reach * (0.30 + 0.29 * index)
   Vfx.ribbon(self, at, aim, Vector2(minf(cast_reach * 0.28, 83), width * 1.4),
    Color(0.53, 0.40, 0.93, fade * 0.46), Color(0.84, 0.82, 1.0, fade * 0.60),
    1.0 if index % 2 == 0 else -1.0)

func _draw_spear_icon(at: Vector2, alpha: float) -> void:
 if icon == null:
  return
 draw_set_transform(at, aim.angle() + PI * 0.25)
 draw_texture_rect(icon, Rect2(-Vector2(56, 56), Vector2(112, 112)), false, Color(1, 1, 1, alpha))
 draw_set_transform(Vector2.ZERO)

func _draw_bell(low: bool) -> void:
 if icon != null:
  draw_texture_rect(icon, Rect2(Vector2(-25, 12), Vector2(50, 50)), false, Color(1, 1, 1, clampf((2.9 - age) / 0.4, 0.0, 1.0)))
 # The disc matches the actual pulse radius. Its curls stay inside.
 for pulse: int in range(pulses):
  var since: float = age - (0.20 + pulse * 0.55)
  if since < 0.0 or since > 0.55:
   continue
  var fade: float = 1.0 - since / 0.55
  draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1, 0.79, 0.35, fade * 0.65), 2.0, true)
  if not low:
   Vfx.curls(self, Vector2.ZERO, radius * lerpf(0.35, 1.0, since / 0.55),
    age * 1.25, Color(0.55, 0.88, 1.0, fade * 0.70), 6)
