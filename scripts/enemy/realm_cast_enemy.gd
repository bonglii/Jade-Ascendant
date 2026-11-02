extends "res://scripts/enemy/enemy_4.gd"

## Isolated Realm IV/V Qi Caster visual adapter. All existing targeting,
## pattern count/spacing, damage and cast timing are inherited unchanged.
const RealmQiExplosionScript = preload("res://scripts/enemy/realm_qi_explosion.gd")


func _spawn_qi_explosion_at(target_position: Vector2) -> void:
	var explosion: QiExplosion = QI_EXPLOSION.instantiate() as QiExplosion
	if explosion == null:
		push_error("RealmCastEnemy: missing QiExplosion scene.")
		return
	# Swap presentation script BEFORE entering the tree, then assign the
	# stage values. No changes to the base explosion's hit contract.
	explosion.set_script(RealmQiExplosionScript)
	explosion.telegraph_duration = telegraph_duration
	explosion.base_damage = explosion_damage
	explosion.explosion_radius = explosion_radius
	explosion.presentation_theme = presentation_theme
	var world: Node = get_tree().current_scene
	if world == null:
		explosion.queue_free()
		return
	world.add_child(explosion)
	explosion.global_position = target_position

func spawn_telegraph() -> void:
	# Each chapter now uses an independent snapshot sequence, not III's ring or II's trident.
	var id: String = "rime_corridor" if presentation_theme == &"frostveil" else "cinder_trail"
	preload("res://scripts/enemy/realm_attack_sequence.gd").launch(get_tree().current_scene, id, global_position, cast_target_position, explosion_damage, self, false)
