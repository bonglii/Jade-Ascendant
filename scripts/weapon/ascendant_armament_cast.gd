extends Node2D
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
var flashes: Array[Vector2]=[]
var flash_times: Array[float]=[]
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
 flashes.append(enemy.global_position-origin);flash_times.append(age)
 if flashes.size()>12:flashes.pop_front();flash_times.pop_front()
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
 var reduced: bool=get_tree().root.get_node("SettingsManager").reduced_effects
 if mode=="phoenix_war_fan":
  if icon!=null and age<.25:
   draw_set_transform(Vector2.ZERO,aim.angle()+PI*.5)
   draw_texture_rect(icon,Rect2(-Vector2(38,38),Vector2(76,76)),false,Color(1,1,1,1-age/.25));draw_set_transform(Vector2.ZERO)
  for feather: Dictionary in feathers:
   if feather.spent:continue
   var at: Vector2=Vector2(feather.position)-origin
   var direction: Vector2=feather.direction
   if not reduced:draw_line(at-direction*26,at,Color(1,.39,.09,.32),7,true)
   draw_line(at-direction*16,at,Color(1,.74,.29),2.8,true)
   var normal: Vector2=direction.orthogonal()
   var contour:=PackedVector2Array([at+direction*7,at+direction*1+normal*3,at-direction*6+normal*5,at-direction*15+normal*4,at-direction*22+normal*1,at-direction*14-normal*3,at-direction*7-normal*4])
   draw_colored_polygon(contour,Color(1,.31,.08,.88))
   draw_polyline(PackedVector2Array([at-direction*21,at-direction*7+normal*1.5,at+direction*5]),Color(1,.89,.48),1.5,true)
   for rib: int in range(3):
    var along: Vector2=at-direction*(3+rib*5)
    draw_line(along-direction*4+normal*3.5,along,Color(1,.69,.23,.8),.9,true)
   if not reduced:draw_circle(at+direction*3,1.2,Color(1,.99,.85))
 elif mode=="void_piercer_spear":
  var width: float=18+3*int(level>=3)+3*int(level>=7)
  if age<.3:
   draw_line(Vector2.ZERO,aim*cast_reach,Color(.67,.55,1,.4),1.5,true)
   draw_line(aim.orthogonal()*width,aim*cast_reach+aim.orthogonal()*width,Color(.81,.70,1,.12),1,true)
   draw_line(-aim.orthogonal()*width,aim*cast_reach-aim.orthogonal()*width,Color(.81,.70,1,.12),1,true)
   if icon!=null:
    draw_set_transform(aim*28,aim.angle()+PI*.25)
    draw_texture_rect(icon,Rect2(-Vector2(56,56),Vector2(112,112)),false);draw_set_transform(Vector2.ZERO)
  else:
   var fade: float=clampf((.78-age)/.45,0,1)
   if icon!=null and age<.53:
    var thrust_at: Vector2=aim*lerpf(28,cast_reach-24,clampf((age-.30)/.18,0,1))
    draw_set_transform(thrust_at,aim.angle()+PI*.25)
    draw_texture_rect(icon,Rect2(-Vector2(56,56),Vector2(112,112)),false,Color(1,1,1,fade));draw_set_transform(Vector2.ZERO)
   if not reduced:draw_line(Vector2.ZERO,aim*cast_reach,Color(.32,.19,.70,.32*fade),width*1.4,true)
   draw_line(Vector2.ZERO,aim*cast_reach,Color(.77,.71,1,fade),3,true)
   for index: int in range(5):
    var at: Vector2=aim*(30+index*(cast_reach-60)/4.0)
    draw_polyline(PackedVector2Array([at-aim*9+aim.orthogonal()*6,at+aim*6,at-aim*9-aim.orthogonal()*6]),Color(1,.87,.58,fade),1.3,true)
 else:
  if icon!=null:draw_texture_rect(icon,Rect2(Vector2(-25,12),Vector2(50,50)),false,Color(1,1,1,clampf((2.9-age)/.4,0,1)))
  # The disc flashes precisely when a pulse applies its damage; the outgoing
  # ring is its fading aftermath, not a separate promised collision.
  for pulse: int in range(pulses):
   var since: float=age-(.2+pulse*.55)
   if since<0 or since>.55:continue
   var fade: float=1-since/.55
   draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(1,.79,.35,fade*.65),2,true)
   if not reduced:
    draw_circle(Vector2.ZERO,radius,Color(.32,.83,.93,fade*.07))
    for rune: int in range(8):
     var angle: float=rune*TAU/8
     var at:=Vector2(cos(angle),sin(angle))*radius*.82
     draw_arc(at,3,0,TAU,8,Color(1,.87,.55,fade*.35),1,true)
    draw_arc(Vector2.ZERO,radius*(.25+.75*since/.55),0,TAU,48,Color(.48,.85,1,fade*.55),1.6,true)
 for index: int in range(flashes.size()):
  var fade: float=clampf(1.0-(age-flash_times[index])/.25,0,1)
  if fade>0:draw_arc(flashes[index],5,0,TAU,10,Color(1,.89,.58,.65*fade),1.4,true)
