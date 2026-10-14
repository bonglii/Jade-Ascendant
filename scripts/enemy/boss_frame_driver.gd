extends Node
## Single frame owner: footsteps use actual travel; cast frames use real action timing.
const STRIDE_DISTANCE: float = 48.0
var sprite: AnimatedSprite2D
var boss: Node2D
var previous_position: Vector2
var stride_distance: float = 0.0
var action: String = ""
var duration: float = 0.0
var elapsed: float = 0.0
var commit: float = 0.48
var frozen_facing: bool = false
func _ready() -> void:
 boss=get_parent();sprite=boss.get_node("AnimatedSprite2D")
 previous_position=boss.global_position
 process_physics_priority=10
 _pose("idle",0, bool(boss.facing_left))
func play_action(kind: String, length: float, release_fraction: float=.48) -> void:
 action=kind;duration=maxf(length,.01);elapsed=0.0
 commit=clampf(release_fraction,.05,.95);frozen_facing=bool(boss.facing_left)
 stride_distance=0.0
 _pose(action,0,frozen_facing)
func _physics_process(delta: float) -> void:
 var distance: float=boss.global_position.distance_to(previous_position)
 previous_position=boss.global_position
 if bool(boss.is_dead):
  action="";stride_distance=0.0;sprite.pause();return
 if not action.is_empty():
  elapsed=minf(duration,elapsed+delta)
  var progress: float=elapsed/duration
  var index: int=mini(2,int(progress/commit*3.0)) if progress<commit else mini(5,3+int((progress-commit)/(1.0-commit)*3.0))
  _pose(action,index,frozen_facing)
  if elapsed>=duration:action="";stride_distance=0.0
  return
 if distance>.04 and distance<24.0 and float(boss.visual_action_timer)<=0.0 and float(boss.phase_transition_timer)<=0.0:
  stride_distance=fmod(stride_distance+distance,STRIDE_DISTANCE)
  _pose("walk",int(stride_distance/STRIDE_DISTANCE*6.0),bool(boss.facing_left))
 else:
  stride_distance=0.0
  _pose("idle",0,bool(boss.facing_left))
func _pose(kind: String, index: int, left: bool) -> void:
 var name_value:=StringName(kind+("_left" if left else "_right"))
 if not sprite.sprite_frames.has_animation(name_value):return
 sprite.pause()
 if sprite.animation!=name_value:sprite.animation=name_value
 sprite.flip_h=left
 sprite.set_frame_and_progress(clampi(index,0,sprite.sprite_frames.get_frame_count(name_value)-1),0.0)
