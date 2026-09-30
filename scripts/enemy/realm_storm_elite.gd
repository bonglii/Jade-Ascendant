extends "res://scripts/enemy/elite_enemy_2.gd"

## One Realm-only override; unrelated elite lightning in Chapters I-III
## continues to use the original production scene and visuals.
const RealmStrikeScript = preload("res://scripts/enemy/realm_lightning_strike.gd")


func spawn_lightning_strike() -> void:
	var lightning_strike: LightningStrike = LIGHTNING_STRIKE.instantiate() as LightningStrike
	if lightning_strike == null:
		push_error("RealmStormElite: failed to instantiate LightningStrike.")
		return
	# Swap only presentation methods. Script derives from LightningStrike.
	lightning_strike.set_script(RealmStrikeScript)
	lightning_strike.telegraph_duration = lightning_telegraph_duration
	lightning_strike.base_damage = lightning_damage
	lightning_strike.strike_radius = lightning_radius
	lightning_strike.presentation_theme = presentation_theme
	var world_scene: Node = get_tree().current_scene
	if world_scene == null:
		lightning_strike.queue_free()
		return
	world_scene.add_child(lightning_strike)
	lightning_strike.global_position = cast_target_position
