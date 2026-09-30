extends "res://scripts/enemy/enemy_spawner.gd"

## Realm IV/V combat adapter. Keeps production WaveManager, kills, XP,
## actor scripts, boss handoff and checkpoint signals unchanged.
## Applied BEFORE add_child so each actor's _ready sees its authored damage.
const FrostRoster = preload("res://scripts/data/chapter_four_enemy_visual_catalog.gd")
const SolarRoster = preload("res://scripts/data/chapter_five_enemy_visual_catalog.gd")
const RealmStormEliteScript = preload("res://scripts/enemy/realm_storm_elite.gd")
const RealmCastEnemyScript = preload("res://scripts/enemy/realm_cast_enemy.gd")
const RealmGuardianEnemyScript = preload("res://scripts/enemy/realm_guardian_enemy.gd")


func get_stage_enemy_visual_entry(archetype_id: int, is_elite: bool = false) -> Dictionary:
	var visual_set: String = str(stage_profile.get("enemy_visual_set", ""))
	if visual_set == str(FrostRoster.VISUAL_SET_ID):
		return FrostRoster.get_elite(archetype_id) if is_elite else FrostRoster.get_enemy(archetype_id)
	if visual_set == str(SolarRoster.VISUAL_SET_ID):
		return SolarRoster.get_elite(archetype_id) if is_elite else SolarRoster.get_enemy(archetype_id)
	return super.get_stage_enemy_visual_entry(archetype_id, is_elite)


func apply_stage_enemy_identity(entity: Node, archetype_id: int, is_elite: bool = false) -> void:
	if entity == null:
		return
	var entry: Dictionary = get_stage_enemy_visual_entry(archetype_id, is_elite)
	if entry.is_empty():
		super.apply_stage_enemy_identity(entity, archetype_id, is_elite)
		return
	# The base EnemySpawner calls this BEFORE difficulty HP/speed are assigned
	# and before _ready. Realm-only script swaps cannot discard scaled stats.
	if not is_elite and archetype_id == 4:
		entity.set_script(RealmCastEnemyScript)
	elif not is_elite and archetype_id == 6:
		entity.set_script(RealmGuardianEnemyScript)
	var sprite: AnimatedSprite2D = entity.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var frames: SpriteFrames = entry.get("sprite_frames") as SpriteFrames
	if sprite != null and frames != null:
		sprite.sprite_frames = frames
	var display_name: String = str(entry.get("display_name", ""))
	if not display_name.is_empty():
		entity.set_meta("encounter_display_name", display_name)
	if entity.has_method("configure_encounter_presentation"):
		entity.call("configure_encounter_presentation", entry)
	if not is_elite and archetype_id == 2 and entity is RealmRangedEnemy:
		# Hostile projectile's palette follows the same stage-owned visual set.
		(entity as RealmRangedEnemy).realm_visual_theme = StringName(
			str(stage_profile.get("enemy_visual_set", "frostveil"))
		)
	_apply_realm_combat_profile(entity, archetype_id, is_elite)


func _apply_realm_combat_profile(entity: Node, archetype_id: int, is_elite: bool) -> void:
	# HP/speed remain owned by EnemySpawner's existing DifficultyManager path;
	# only attack pressure/cadence and special projectile damage live here.
	var damage_scale: float = float(stage_profile.get(
		"elite_damage_multiplier" if is_elite else "enemy_damage_multiplier", 1.0
	))
	var cadence_scale: float = float(stage_profile.get("enemy_cadence_multiplier", 1.0))
	damage_scale = clampf(damage_scale, 0.80, 1.60)
	cadence_scale = clampf(cadence_scale, 0.86, 1.06)
	if is_elite:
		match archetype_id:
			1:
				entity.set("contact_damage", 5.0 * damage_scale)
				entity.set("contact_damage_cooldown", maxf(0.85, 1.0 * cadence_scale))
			2:
				entity.set("lightning_damage", 10.0 * damage_scale)
				entity.set("lightning_telegraph_duration", maxf(0.85, 0.75 / cadence_scale))
				entity.set("lightning_cooldown", maxf(2.15, 2.5 * cadence_scale))
		return
	match archetype_id:
		1:
			entity.set("contact_damage", 10.0 * damage_scale)
			entity.set("contact_damage_cooldown", maxf(0.70, 0.75 * cadence_scale))
		2:
			# Our dedicated realm ranged actor owns actual spawned projectile damage.
			# Never set a nonexistent projectile_damage on the base caster.
			if entity is RealmRangedEnemy:
				var caster: RealmRangedEnemy = entity as RealmRangedEnemy
				caster.realm_projectile_damage = 2.0 * damage_scale
				caster.realm_projectile_speed = 210.0 if int(stage_profile.get("realm_id", 4)) == 4 else 225.0
			entity.set("attack_cooldown", maxf(1.65, 2.0 * cadence_scale))
		3:
			entity.set("contact_damage", 6.0 * damage_scale)
			entity.set("contact_damage_cooldown", maxf(0.55, 0.6 * cadence_scale))
		4:
			entity.set("explosion_damage", 6.0 * damage_scale)
			entity.set("cast_cooldown", maxf(2.35, 3.0 * cadence_scale))
			entity.set("telegraph_duration", maxf(0.85, 0.8 / cadence_scale))
		5:
			entity.set("dash_damage", 12.0 * damage_scale)
			entity.set("dash_cooldown", maxf(2.65, 3.0 * cadence_scale))
			entity.set("wind_up_duration", maxf(0.48, 0.45 / cadence_scale))
		6:
			entity.set("qi_pulse_damage", 6.0 * damage_scale)
			entity.set("qi_pulse_cooldown", maxf(2.45, 3.0 * cadence_scale))
			entity.set("qi_pulse_wind_up", maxf(0.55, 0.5 / cadence_scale))


## Realm IV/V-only lightning override. Explicitly preserves the production
## Elite wave gate, stats, spawn position, death wiring and difficulty scaling.
## Using a local script on the still-unparented node prevents changing the
## LightningStrike asset used by Chapters I-III.
func spawn_elite_enemy_2() -> bool:
	if elite_enemy_2_scene == null:
		push_error("RealmEnemySpawner: missing elite_enemy_2 scene.")
		return false
	var elite_enemy: CharacterBody2D = elite_enemy_2_scene.instantiate() as CharacterBody2D
	if elite_enemy == null:
		push_error("RealmEnemySpawner: elite scene is not CharacterBody2D.")
		return false
	# Do this BEFORE health/difficulty fields are assigned; set_script() may
	# reinitialize script properties and must never undo stage scaling.
	elite_enemy.set_script(RealmStormEliteScript)
	configure_top_down_character_body(elite_enemy)
	apply_profile_elite_scaling(elite_enemy)
	apply_stage_enemy_identity(elite_enemy, 2, true)
	get_parent().add_child(elite_enemy)
	elite_enemy.global_position = get_random_spawn_position()
	connect_enemy_defeated_signal(elite_enemy)
	DebugLogger.system("Realm %d-%d | elite 2 | %s" % [
		int(stage_profile.get("realm_id", 4)),
		int(stage_profile.get("stage_id", 1)),
		get_enemy_display_name(elite_enemy)
	])
	return true
