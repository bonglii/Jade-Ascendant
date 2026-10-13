extends SpiritSwordWeapon

const Flight = preload("res://scripts/weapon/returning_glaive_flight.gd")

func _ready() -> void:
	super._ready()
	cooldown = 2.1

func attack(player: Node2D, target: Node2D) -> void:
	if not is_instance_valid(player) or not Flight.living(target): return
	var position_snapshot: Vector2 = target.global_position
	for i: int in range(2 if level >= 5 else 1):
		var flight := Flight.new()
		player.get_parent().add_child(flight)
		flight.configure(player, position_snapshot, base_damage, level, 1.0 if i == 0 else -1.0, 0.0 if i == 0 else 0.16)
	AudioManager.play_sfx("sword")
