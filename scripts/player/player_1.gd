extends CharacterBody2D

signal level_changed(new_level: int)

## Player
## Mengelola movement, targeting, experience, level progression,
## dan upgrade yang menjadi bagian langsung dari Player selama run.

const MOVEMENT_SPEED_MULTIPLIER: float = 1.10
const SPIRITUAL_INSIGHT_BONUS: float = 0.15
const SPIRITUAL_INSIGHT_MAX_LEVEL: int = 5

@export var speed: float = 200.0

var experience: int = 0
var level: int = 1
var experience_to_next_level: int = 10

var movement_speed_level: int = 0
var spiritual_insight_level: int = 0

var facing_direction: String = "down"

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_stats = $PlayerStats
@onready var weapon_manager = $WeaponManager

func _ready() -> void:
	CombatFeedback.register_actor(self)
	_play_animation_if_available("idle_" + facing_direction)

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	var keyboard_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	if keyboard_direction.length_squared() > direction.length_squared():
		direction = keyboard_direction
	velocity = direction * get_effective_movement_speed()
	move_and_slide()

	update_facing(direction)
	update_animation(direction)

func get_effective_movement_speed() -> float:
	return (
		speed
		* EquipmentManager.get_movement_speed_multiplier()
	)

func update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	if absf(direction.x) > absf(direction.y):
		facing_direction = "right" if direction.x > 0.0 else "left"
	else:
		facing_direction = "down" if direction.y > 0.0 else "up"

func update_animation(direction: Vector2) -> void:
	var animation_prefix: String = "idle_" if direction == Vector2.ZERO else "walk_"
	_play_animation_if_available(animation_prefix + facing_direction)

func _play_animation_if_available(animation_name: String) -> void:
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return
	if animated_sprite.animation == animation_name and animated_sprite.is_playing():
		return
	animated_sprite.play(animation_name)

func find_nearest_enemy() -> Node2D:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	for enemy_node: Node in enemies:
		if not enemy_node is Node2D:
			continue

		var enemy: Node2D = enemy_node as Node2D

		if not enemy.has_method("take_damage"):
			continue

		if enemy.is_queued_for_deletion():
			continue

		var distance_squared: float = (
			global_position.distance_squared_to(
				enemy.global_position
			)
		)

		if distance_squared < nearest_distance:
			nearest_distance = distance_squared
			nearest_enemy = enemy

	return nearest_enemy

## Meningkatkan movement speed Player selama run.
func upgrade_movement_speed() -> void:
	movement_speed_level += 1
	speed *= MOVEMENT_SPEED_MULTIPLIER

	DebugLogger.system(str("Movement Speed Level: ", movement_speed_level))
	DebugLogger.system(str("Player Movement Speed: ", speed))

## Meningkatkan jumlah EXP yang diterima Player selama run.
func upgrade_spiritual_insight() -> void:
	if spiritual_insight_level >= SPIRITUAL_INSIGHT_MAX_LEVEL:
		DebugLogger.system(str(
            "Spiritual Insight sudah mencapai level maksimum."
		))
		return

	spiritual_insight_level += 1

	DebugLogger.system(str(
		"Spiritual Insight Level: ",
		spiritual_insight_level
	))

	DebugLogger.system(str(
		"EXP Multiplier: ",
		get_experience_multiplier()
	))

## Memeriksa apakah Spiritual Insight masih dapat ditingkatkan.
func can_upgrade_spiritual_insight() -> bool:
	return (
		spiritual_insight_level
		< SPIRITUAL_INSIGHT_MAX_LEVEL
	)

## Menghasilkan multiplier EXP berdasarkan level Spiritual Insight.
func get_experience_multiplier() -> float:
	var insight_multiplier: float = (
		1.0
		+ (
			spiritual_insight_level
			* SPIRITUAL_INSIGHT_BONUS
		)
	)
	return (
		insight_multiplier
		* EquipmentManager.get_experience_multiplier()
	)

func level_up() -> void:
	level += 1
	experience -= experience_to_next_level
	experience_to_next_level = int(
		experience_to_next_level * 1.2
	)
	level_changed.emit(level)
	_apply_level_up_equipment_recovery()
	CombatFeedback.pulse(global_position, "level")
	AudioManager.play_sfx("level")

	DebugLogger.system(str("LEVEL UP!"))
	DebugLogger.system(str("Level: ", level))
	DebugLogger.system(str("EXP berikutnya: ", experience_to_next_level))

	var hud: Node = get_parent().get_node("HUD")
	hud.level_up_panel.show_level_up()


func _apply_level_up_equipment_recovery() -> void:
	var heal_amount: float = EquipmentManager.get_secondary_bonus(
		"level_up_heal_flat",
		4.0
	)
	if heal_amount <= 0.0:
		return
	var health: PlayerHealth = get_node_or_null("PlayerHealth") as PlayerHealth
	if health == null:
		return
	health.heal(heal_amount)
	DebugLogger.progression(
		"Equipment Level Recovery: +%.1f HP" % heal_amount
	)

func add_experience(amount: int) -> void:
	var final_experience: float = (
		amount * get_experience_multiplier()
	)

	var rounded_experience: int = int(
		round(final_experience)
	)

	experience += rounded_experience

	DebugLogger.progression(
        "EXP: +%d -> +%d | %d/%d"
		% [
			amount,
			rounded_experience,
			experience,
			experience_to_next_level
		]
	)

	if experience >= experience_to_next_level:
		level_up()

func resolve_pending_level_up() -> void:
	if not get_tree().paused and experience >= experience_to_next_level:
		level_up()
