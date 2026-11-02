extends Node2D
## Body-bound presentation, shared by the IV/V roster. Never marks a hit area.
const MAX_ACTIVE: int=64
static var active: int=0
var actor: Node2D
var chapter: int=4
var role: int=1
var age: float=0
var _tick: float=0
var _properties: Dictionary={}
var _charge: float=0
static func install(entity: Node2D, realm: int, archetype: int) -> void:
 if active>=MAX_ACTIVE or entity.has_node("RealmActorFinish"):return
 var finish: Node2D=load("res://scripts/enemy/realm_actor_finish.gd").new()
 finish.chapter=realm;finish.role=archetype;finish.name="RealmActorFinish";entity.add_child(finish)
func _ready() -> void:
 active+=1;actor=get_parent();z_index=-3;show_behind_parent=true
 for property: Dictionary in actor.get_property_list():_properties[str(property.name)]=true
 # Dephase idle wisps across the crowd; no RNG consumed by presentation.
 age=float(actor.get_instance_id()%37)*.11
func _exit_tree() -> void:active=maxi(0,active-1)
func _process(delta: float) -> void:
 age+=delta;_tick-=delta
 if _tick>0:return
 _tick=.10 if SettingsManager.reduced_effects else .05
 _charge=0
 for field: String in ["pending_release","cast_visual_timer","wind_up_timer","qi_pulse_wind_up_timer","visual_action_timer"]:
  if _properties.has(field) and float(actor.get(field))>0:_charge=1;break
 queue_redraw()
func _draw() -> void:
 if actor==null or bool(actor.get("is_dead")):return
 # Grounded feet and an unobtrusive silhouette accent, without circular wards.
 draw_set_transform(Vector2(0,13),0,Vector2(1,.26))
 draw_circle(Vector2.ZERO,17 if role<7 else 23,Color(0,.018,.025,.26))
 draw_set_transform(Vector2.ZERO)
 if SettingsManager.reduced_effects:return
 var tint:=Color(.50,.87,1,.19+_charge*.13) if chapter==4 else Color(1,.62,.26,.18+_charge*.14)
 for side: float in [-1.0,1.0]:
  var points:=PackedVector2Array()
  for i: int in 9:
   var t: float=float(i)/8
   var bend: float=sin(t*PI+age*1.3+side)*3
   points.append(Vector2(side*(12+sin(t*PI)*6)+bend,-3-t*(31+role)))
  draw_polyline(points,tint,1.3,true)
