class_name Weapon
extends Node

# ==========================================
# BASIC WEAPON DATA
# ==========================================

@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var cooldown: float = 1.0

# ==========================================
# ATTACK
# ==========================================

func attack(_player: Node2D, _target: Node2D) -> void:
	pass
