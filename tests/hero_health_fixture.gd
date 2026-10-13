extends "res://scripts/player/PlayerHealth.gd"
## Load only after QA autoload initialization; production damage method is inherited.
func _ready() -> void:
 max_health=100;current_health=100
