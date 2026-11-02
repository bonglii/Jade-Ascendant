extends Node
var applications: int = 0
var damage: float = 0
func take_damage(amount: float) -> void:
	applications += 1
	damage += amount
