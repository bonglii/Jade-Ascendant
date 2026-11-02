extends "res://scripts/enemy/elite_enemy_2.gd"

## One Realm-only override; unrelated elite lightning in Chapters I-III
## continues to use the original production scene and visuals.
const RealmStrikeScript = preload("res://scripts/enemy/realm_lightning_strike.gd")


func spawn_lightning_strike() -> void:
	var id: String = "oracle_mirrors" if presentation_theme == &"frostveil" else "oracle_sunfall"
	preload("res://scripts/enemy/realm_attack_sequence.gd").launch(get_tree().current_scene, id, global_position, cast_target_position, lightning_damage, self, false)
