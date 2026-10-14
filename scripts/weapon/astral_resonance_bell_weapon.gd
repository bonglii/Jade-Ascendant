extends SpiritSwordWeapon
const Cast=preload("res://scripts/weapon/ascendant_armament_cast.gd")
func _ready() -> void:
 super._ready()
 cooldown=3.0
func attack(player: Node2D,target: Node2D) -> void:
 if not Cast.living(target) or not is_instance_valid(player):return
 if get_tree().get_nodes_in_group("ascendant_armament_cast").size()>=Cast.MAX_ACTIVE_CASTS:return
 var cast:=Cast.new()
 player.get_parent().add_child(cast)
 var manager: Node=player.get_node_or_null("WeaponManager")
 var tempo: float=manager.get_cast_tempo_damage_multiplier(self) if manager!=null else 1.0
 cast.configure(player,target,"astral_resonance_bell",level,base_damage*EquipmentManager.get_weapon_level_multiplier(armament_id)*tempo)
