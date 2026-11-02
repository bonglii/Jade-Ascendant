extends Node2D
## Training support role. Uses authored enemy HP and its existing reduction contract.
var _left: float=0.0
var _protected: Array[Node]=[]
func _process(delta: float) -> void:
 _left-=delta
 if _left>0:return
 _left=.25
 for actor: Node in _protected:
  if is_instance_valid(actor):actor.damage_reduction_sources.erase("practice_ward")
 _protected.clear()
 for actor: Node in get_tree().get_nodes_in_group("companion_training_target"):
  if actor==get_parent() or not actor is Node2D or actor.global_position.distance_to(global_position)>160:continue
  actor.damage_reduction_sources["practice_ward"]=.35;_protected.append(actor)
 queue_redraw()
func _draw() -> void:
 draw_arc(Vector2.ZERO,160,0,TAU,40,Color(.40,.95,.72,.35),2,true)
 draw_polyline(PackedVector2Array([Vector2(0,-45),Vector2(12,-28),Vector2(0,-11),Vector2(-12,-28),Vector2(0,-45)]),Color(.92,.80,.42),3,true)
 for actor: Node2D in _protected:
  if is_instance_valid(actor):draw_line(Vector2(0,-28),to_local(actor.global_position)+Vector2(0,-20),Color(.4,.9,.7,.32),1.5,true)
func _exit_tree() -> void:
 for actor: Node in _protected:
  if is_instance_valid(actor):actor.damage_reduction_sources.erase("practice_ward")
