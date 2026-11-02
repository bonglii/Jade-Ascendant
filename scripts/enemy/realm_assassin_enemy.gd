extends "res://scripts/enemy/enemy_5.gd"
var realm_id: int=4
var _flank: float=1
func begin_wind_up() -> void:
 super()
 if realm_id==4 and is_winding_up:
  # Frost assassins flank a snapshot; fire assassins commit straight through it.
  var forward: Vector2=global_position.direction_to(player.global_position)
  dash_direction=global_position.direction_to(player.global_position+forward.orthogonal()*65*_flank)
  _flank=-_flank
  _update_facing_from_dash_direction()
