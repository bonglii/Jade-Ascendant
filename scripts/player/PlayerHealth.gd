class_name PlayerHealth
extends Node

## Player Health
## Mengelola HP Player, damage, heal, death,
## bonus HP permanen dari Vitality,
## Body Refinement, Qi Shield, Iron Body,
## dan Blood Qi selama run.

signal health_changed(current_health: float, max_health: float)
signal qi_shield_blocked(remaining_charges: int)
signal died

const BODY_REFINEMENT_HP_PER_LEVEL: float = 2.0
const QI_SHIELD_CHARGE_PER_LEVEL: int = 1
const IRON_BODY_REDUCTION_PER_LEVEL: float = 0.05
const IRON_BODY_MAX_LEVEL: int = 5
const BLOOD_QI_BASE_KILLS_REQUIRED: int = 20
const BLOOD_QI_KILL_REDUCTION_PER_LEVEL: int = 2
const BLOOD_QI_HEAL_AMOUNT: float = 1.0
const BLOOD_QI_MAX_LEVEL: int = 5
const EquipmentSetRuntime = preload("res://scripts/data/equipment_set_runtime.gd")

@export var max_health: float = 10.0
@export var health_per_vitality_level: float = 5.0

var current_health: float
var is_dead: bool = false
var body_refinement_level: int = 0
var qi_shield_level: int = 0
var qi_shield_charges: int = 0
var iron_body_level: int = 0
var blood_qi_level: int = 0
var blood_qi_kill_progress: int = 0

func _ready() -> void:
	apply_permanent_vitality()
	apply_equipment_max_health()
	current_health = max_health
	qi_shield_charges = int(EquipmentSetRuntime.get_capped_combined_secondary_bonus(
		"starting_shield_charges",
		2.0
	))

	health_changed.emit(
		current_health,
		max_health
	)

	DebugLogger.system(str("Player Max HP: ", max_health))
	DebugLogger.system(str("Vitality Level: ", ProgressionManager.vitality_level))

	connect_blood_qi_kill_tracker()

## Menghubungkan Blood Qi ke event kill terpusat dari EnemySpawner.
func connect_blood_qi_kill_tracker() -> void:
	var enemy_spawner := get_tree().get_first_node_in_group(
		"enemy_spawner"
	)

	if enemy_spawner == null:
		enemy_spawner = get_tree().current_scene.get_node_or_null(
			"EnemySpawner"
		)

	if enemy_spawner == null:
		push_error(str(
			"ERROR: Blood Qi tidak menemukan EnemySpawner!"
		))
		return

	if not enemy_spawner.has_signal("enemy_killed"):
		push_error(str(
			"ERROR: EnemySpawner tidak memiliki signal enemy_killed!"
		))
		return

	enemy_spawner.enemy_killed.connect(
		_on_enemy_killed
	)

	DebugLogger.system(str("Blood Qi terhubung ke EnemySpawner!"))

## Memproses progress kill Blood Qi dan memicu recovery saat threshold tercapai.
func _on_enemy_killed() -> void:
	if blood_qi_level <= 0:
		return

	var kills_required := get_blood_qi_kills_required()

	blood_qi_kill_progress += 1

	DebugLogger.progression(
		"Blood Qi Kill Progress: %d/%d"
		% [
			blood_qi_kill_progress,
			kills_required
		]
	)

	if blood_qi_kill_progress < kills_required:
		return

	blood_qi_kill_progress = 0

	heal(BLOOD_QI_HEAL_AMOUNT + EquipmentSetRuntime.get_capped_combined_secondary_bonus(
		"blood_qi_heal_bonus",
		0.75
	))

	DebugLogger.progression(
		"Blood Qi Recovery | HP: %.1f/%.1f"
		% [
			current_health,
			max_health
		]
	)

## Menambahkan bonus Max HP berdasarkan level Vitality permanen.
func apply_permanent_vitality() -> void:
	var vitality_bonus: float = (
		ProgressionManager.vitality_level
		* health_per_vitality_level
	)

	max_health += vitality_bonus

## Menambahkan bonus Max HP dari equipment permanen dan set resonance.
func apply_equipment_max_health() -> void:
	var equipment_bonus := (
		EquipmentManager.get_total_max_health_bonus()
		+ EquipmentSetRuntime.get_bonus("max_health_flat")
	)
	max_health += equipment_bonus
	if equipment_bonus > 0.0:
		DebugLogger.system(str(
			"Equipment Max HP Bonus: +",
			equipment_bonus
		))

## Meningkatkan Max HP dan Current HP selama run.
func upgrade_body_refinement() -> void:
	body_refinement_level += 1

	max_health += BODY_REFINEMENT_HP_PER_LEVEL
	current_health += BODY_REFINEMENT_HP_PER_LEVEL
	current_health = min(
		current_health,
		max_health
	)

	health_changed.emit(
		current_health,
		max_health
	)

	DebugLogger.system(str(
		"Body Refinement Level: ",
		body_refinement_level
	))

	DebugLogger.system(str(
		"Player HP: ",
		current_health,
		"/",
		max_health
	))

## Menambahkan satu Qi Shield Charge setiap kali upgrade dipilih.
func upgrade_qi_shield() -> void:
	qi_shield_level += 1
	qi_shield_charges += QI_SHIELD_CHARGE_PER_LEVEL

	DebugLogger.system(str(
		"Qi Shield Level: ",
		qi_shield_level
	))

	DebugLogger.system(str(
		"Qi Shield Charges: ",
		qi_shield_charges
	))

## Meningkatkan damage reduction Iron Body selama run.
func upgrade_iron_body() -> void:
	if iron_body_level >= IRON_BODY_MAX_LEVEL:
		DebugLogger.system(str(
			"Iron Body sudah mencapai level maksimum."
		))
		return

	iron_body_level += 1

	DebugLogger.system(str(
		"Iron Body Level: ",
		iron_body_level
	))

	DebugLogger.system(str(
		"Damage Reduction: ",
		get_iron_body_reduction() * 100.0,
		"%"
	))

## Memeriksa apakah Iron Body masih dapat ditingkatkan.
func can_upgrade_iron_body() -> bool:
	return (
		iron_body_level
		< IRON_BODY_MAX_LEVEL
	)

## Menghasilkan damage reduction berdasarkan level Iron Body.
func get_iron_body_reduction() -> float:
	return (
		iron_body_level
		* IRON_BODY_REDUCTION_PER_LEVEL
	)

## Memproses damage yang diterima Player.
func take_damage(amount: float) -> void:
	if is_dead or amount <= 0 or not is_finite(amount):
		return

	if qi_shield_charges > 0:
		consume_qi_shield()
		return

	var damage_reduction: float = (
		get_iron_body_reduction()
	)

	var final_damage: float = (
		amount
		* (1.0 - damage_reduction)
	)

	current_health -= final_damage
	CombatFeedback.hit(get_parent(), final_damage)

	current_health = max(
		current_health,
		0.0
	)

	DebugLogger.combat(
		"Player Damage: %.1f -> %.1f | HP: %.1f/%.1f"
		% [
			amount,
			final_damage,
			current_health,
			max_health
		]
	)

	health_changed.emit(
		current_health,
		max_health
	)

	if current_health <= 0:
		die()

## Mengonsumsi satu Qi Shield charge dan mengirim event actual block.
func consume_qi_shield() -> void:
	qi_shield_charges -= 1
	CombatFeedback.pulse(get_parent().global_position, "reversal")
	AudioManager.play_sfx("shield")

	DebugLogger.combat(
		"Qi Shield Block | Charges: %d | HP: %.1f/%.1f"
		% [
			qi_shield_charges,
			current_health,
			max_health
		]
	)

	qi_shield_blocked.emit(
		qi_shield_charges
	)

## Menambahkan HP tanpa melewati Max HP.
func heal(amount: float) -> void:
	if is_dead or amount <= 0:
		return

	current_health += amount

	current_health = min(
		current_health,
		max_health
	)

	health_changed.emit(
		current_health,
		max_health
	)

## Mengembalikan jumlah kill yang dibutuhkan untuk memicu recovery Blood Qi.
func get_blood_qi_kills_required() -> int:
	if blood_qi_level <= 0:
		return 0

	var clamped_level := clampi(
		blood_qi_level,
		1,
		BLOOD_QI_MAX_LEVEL
	)

	return (
		BLOOD_QI_BASE_KILLS_REQUIRED
		- (
			(clamped_level - 1)
			* BLOOD_QI_KILL_REDUCTION_PER_LEVEL
		)
	)

## Menaikkan level Blood Qi hingga batas maksimum.
func upgrade_blood_qi() -> void:
	if not can_upgrade_blood_qi():
		return

	blood_qi_level += 1

	DebugLogger.system(str(
		"Blood Qi Level: ",
		blood_qi_level
	))

	DebugLogger.system(str(
		"Blood Qi Kills Required: ",
		get_blood_qi_kills_required()
	))

## Memeriksa apakah Blood Qi masih dapat ditingkatkan.
func can_upgrade_blood_qi() -> bool:
	return (
		blood_qi_level
		< BLOOD_QI_MAX_LEVEL
	)

## Menangani kematian Player.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	CombatFeedback.death(get_parent())
	var sprite: CanvasItem = get_parent().get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite != null:
		sprite.hide()
	DebugLogger.system(str("PLAYER MATI!"))
	died.emit()
