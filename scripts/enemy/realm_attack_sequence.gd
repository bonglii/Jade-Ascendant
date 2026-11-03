extends Node2D
## One bounded CanvasItem for a complete cast; no particle nodes or per-hit timers.
const Patterns=preload("res://scripts/data/realm_attack_patterns.gd")
const MAX_ACTIVE: int=4
var pattern: String=""
var zones: Array[Dictionary]=[]
var damage: float=8
var realm_id: int=4
var caster: WeakRef
var age: float=0
var _draw_left: float=0
var _end: float=0
static func launch(host: Node, id: String, origin: Vector2, target: Vector2, amount: float, owner_actor: Node=null, boss_cast: bool=true) -> Node2D:
 if host==null or not Patterns.IDS.has(id):return null
 var tree: SceneTree=host.get_tree()
 var group: StringName=&"realm_boss_telegraph" if boss_cast else &"realm_mob_sequence"
 if tree.get_node_count_in_group(group)>=(2 if boss_cast else MAX_ACTIVE):return null
 var attack: Node2D=load("res://scripts/enemy/realm_attack_sequence.gd").new()
 attack.pattern=id;attack.zones=Patterns.build(id,origin,target);attack.damage=amount;attack.realm_id=int(Patterns.IDS[id])
 if owner_actor!=null:attack.caster=weakref(owner_actor)
 attack.add_to_group(group);attack.add_to_group("enemy_attack")
 host.add_child(attack)
 attack.top_level=true;attack.global_transform=Transform2D.IDENTITY
 return attack
func _reduced() -> bool:
 var settings: Node=get_tree().root.get_node_or_null("SettingsManager")
 return settings!=null and bool(settings.reduced_effects)
func _ready() -> void:
 z_index=6
 for z: Dictionary in zones:_end=maxf(_end,float(z.delay)+float(z.warning)+.24)
 queue_redraw()
func _process(delta: float) -> void:
 if caster!=null:
  var source: Node=caster.get_ref()
  if source==null or source.is_queued_for_deletion() or bool(source.get("is_dead")):queue_free();return
 age+=delta
 var player: Node2D=get_tree().get_first_node_in_group("player") as Node2D
 var impact: bool=false
 for z: Dictionary in zones:
  if not bool(z.hit) and age>=float(z.delay)+float(z.warning):
   z.hit=true
   impact=impact or (player!=null and Patterns.contains(z,player.global_position))
 if impact:
  var health: Node=player.get_node_or_null("PlayerHealth")
  if health!=null:health.take_damage(damage, "area") # At most once per cast frame, including overlapping zones.
 if age>=_end:queue_free();return
 _draw_left-=delta
 if _draw_left<=0:
  _draw_left=1.0/(15.0 if _reduced() else 30.0);queue_redraw()
func _draw() -> void:
 var tint: Color=Color(.48,.88,1) if realm_id==4 else Color(1,.59,.23)
 for z: Dictionary in zones:
  var t: float=age-float(z.delay)
  if t<0 or t>float(z.warning)+.24:continue
  var p: float=clampf(t/float(z.warning),0,1)
  var fade: float=1.0 if t<=float(z.warning) else 1.0-(t-float(z.warning))/.24
  var edge:=Color(tint,fade*(.55+p*.4))
  var fill:=Color(tint,fade*(.08+p*.12))
  draw_zone(z,fill,edge)
func draw_zone(z: Dictionary, fill: Color, edge: Color) -> void:
 var at: Vector2=z.at
 match z.kind:
  "disc":
   draw_circle(at,z.radius,fill);draw_arc(at,z.radius,0,TAU,40,edge,2.0,true)
   draw_line(at-Vector2(6,0),at+Vector2(6,0),edge,1.2,true)
  "lane":
   var direction: Vector2=z.aim;var normal: Vector2=direction.orthogonal()*float(z.width)
   var finish: Vector2=at+direction*float(z.reach)
   var points:=PackedVector2Array([at-normal,at+normal,finish+normal,finish-normal])
   draw_colored_polygon(points,fill);points.append(points[0]);draw_polyline(points,edge,2,true)
   # Travel chevrons stay inside the exact corridor.
   for i: int in 3:
    var c: Vector2=at+direction*float(z.reach)*(float(i)+1)/4
    draw_polyline(PackedVector2Array([c-direction*7-normal*.35,c,c-direction*7+normal*.35]),edge,1.1,true)
  "sector":
   var points:=PackedVector2Array([at]);var angle_v: float=Vector2(z.aim).angle()
   for i: int in 25:points.append(at+Vector2.from_angle(angle_v-float(z.angle)+float(z.angle)*2*i/24)*float(z.reach))
   draw_colored_polygon(points,fill);points.append(at);draw_polyline(points,edge,2,true)
  "ring":
   var start: float=float(z.gap)+float(z.gap_half)
   var finish: float=float(z.gap)+TAU-float(z.gap_half)
   for i: int in 40:
    var a: Vector2=Vector2.from_angle(lerpf(start,finish,float(i)/40))
    var b: Vector2=Vector2.from_angle(lerpf(start,finish,float(i+1)/40))
    draw_colored_polygon(PackedVector2Array([at+a*float(z.inner),at+a*float(z.outer),at+b*float(z.outer),at+b*float(z.inner)]),fill)
   for radius_v: float in [float(z.inner),float(z.outer)]:draw_arc(at,radius_v,start,finish,48,edge,2,true)
   for angle_v: float in [start,finish]:draw_line(at+Vector2.from_angle(angle_v)*float(z.inner),at+Vector2.from_angle(angle_v)*float(z.outer),edge,2,true)
