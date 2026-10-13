extends "res://scripts/weapon/returning_glaive_flight.gd"
var contact_ids: Array[int]=[]
func _hit(_player: Node2D,enemy: Node2D,phase_id: int,_multiplier: float) -> void:
 var key: String="%d:%d" % [phase_id,enemy.get_instance_id()]
 if hits.has(key):return
 hits[key]=true;contact_ids.append(enemy.get_instance_id())
