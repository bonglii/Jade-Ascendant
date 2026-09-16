extends Node

## Player Stats
## Mengelola Power, Attack Speed,
## Sword Intent Critical Strike,
## dan state synergy selama run.
## Permanent upgrade diterapkan dari ProgressionManager
## saat game dimulai.

const POWER_PER_LEVEL: float = 0.10
const SWORD_POWER_PER_LEVEL: float = 0.10
const SWIFT_QI_COOLDOWN_MULTIPLIER: float = 0.95

const SWORD_INTENT_CRIT_CHANCE_PER_LEVEL: float = 0.05
const SWORD_INTENT_CRIT_DAMAGE_MULTIPLIER: float = 2.0
const SWORD_INTENT_MAX_LEVEL: int = 5
const EquipmentSetRuntime = preload("res://scripts/data/equipment_set_runtime.gd")

var power_level: int = 0
var power_multiplier: float = 1.0

var attack_speed_level: int = 0
var attack_cooldown: float = 1.0
var minimum_attack_cooldown: float = 0.2

var sword_intent_level: int = 0

var sword_dao_resonance_unlocked: bool = false
var yin_yang_reversal_unlocked: bool = false
var heavenly_tribulation_unlocked: bool = false

func _ready() -> void:
	apply_permanent_sword_power()
	apply_permanent_swift_qi()

## Menghasilkan final damage untuk sistem lama.
## Tetap mengembalikan float agar seluruh weapon existing
## tetap kompatibel tanpa perubahan.
func calculate_damage(base_damage: float) -> float:
	var damage_result: Dictionary = (
		calculate_damage_result(base_damage)
	)

	return float(
		damage_result["damage"]
	)

## Menghasilkan damage beserta metadata Critical Hit.
## Digunakan oleh sistem yang membutuhkan informasi
## apakah damage tersebut merupakan Critical Hit.
func calculate_damage_result(
	base_damage: float
) -> Dictionary:
	var equipment_damage_multiplier: float = (
		EquipmentManager.get_damage_multiplier()
		+ EquipmentSetRuntime.get_bonus("damage_bonus")
	)
	var final_damage: float = (
		base_damage
		* power_multiplier
		* equipment_damage_multiplier
	)

	var conditional_damage_bonus: float = 0.0
	if _is_player_moving():
		conditional_damage_bonus += EquipmentSetRuntime.get_capped_combined_secondary_bonus(
			"moving_damage_bonus",
			0.08
		)
	elif _is_player_stationary():
		conditional_damage_bonus += EquipmentSetRuntime.get_bonus(
			"stationary_damage_bonus"
		)
	if _is_low_health():
		conditional_damage_bonus += EquipmentSetRuntime.get_capped_combined_secondary_bonus(
			"low_health_damage_bonus",
			0.10
		)
	elif _is_high_health():
		conditional_damage_bonus += EquipmentSetRuntime.get_bonus(
			"high_health_damage_bonus"
		)
	final_damage *= 1.0 + conditional_damage_bonus

	var is_critical: bool = roll_critical_hit()

	if is_critical:
		final_damage *= (
			SWORD_INTENT_CRIT_DAMAGE_MULTIPLIER
			+ EquipmentSetRuntime.get_capped_combined_secondary_bonus(
				"critical_damage_bonus",
				0.15
			)
		)

		DebugLogger.combat(
			"CRITICAL HIT | Damage: %.1f"
			% final_damage
		)

	return {
		"damage": final_damage,
		"is_critical": is_critical
	}

## Menentukan apakah satu damage event menghasilkan Critical Hit.
func roll_critical_hit() -> bool:
	var critical_chance: float = (
		get_critical_chance()
	)

	if critical_chance <= 0.0:
		return false

	return randf() < critical_chance

## Menghasilkan Critical Chance berdasarkan level Sword Intent.
func get_critical_chance() -> float:
	var critical_chance: float = (
		(
			sword_intent_level
			* SWORD_INTENT_CRIT_CHANCE_PER_LEVEL
		)
		+ EquipmentManager.get_critical_chance_bonus()
		+ EquipmentSetRuntime.get_bonus("critical_chance_bonus")
	)
	if _is_low_health():
		critical_chance += EquipmentSetRuntime.get_capped_combined_secondary_bonus(
			"low_health_critical_chance_bonus",
			0.05
		)
	return clampf(critical_chance, 0.0, 1.0)

## Signature equipment can react to current run state without entering checkpoint data.
func _is_player_moving() -> bool:
	var actor := get_parent() as CharacterBody2D
	if actor == null:
		return false
	return actor.velocity.length_squared() > 1.0

func _is_player_stationary() -> bool:
	var actor := get_parent() as CharacterBody2D
	if actor == null:
		return false
	return actor.velocity.length_squared() <= 1.0

func _is_low_health() -> bool:
	var health_node: Node = get_parent().get_node_or_null("PlayerHealth")
	if health_node == null:
		return false
	var maximum: float = float(health_node.get("max_health"))
	if maximum <= 0.0:
		return false
	var current: float = float(health_node.get("current_health"))
	return current / maximum <= 0.5

func _is_high_health() -> bool:
	var health_node: Node = get_parent().get_node_or_null("PlayerHealth")
	if health_node == null:
		return false
	var maximum: float = float(health_node.get("max_health"))
	if maximum <= 0.0:
		return false
	var current: float = float(health_node.get("current_health"))
	return current / maximum >= 0.80

## Meningkatkan Sword Intent hingga level maksimum.
func upgrade_sword_intent() -> void:
	if not can_upgrade_sword_intent():
		return

	sword_intent_level += 1

	DebugLogger.system(str(
		"Sword Intent Level: ",
		sword_intent_level
	))

	DebugLogger.system(str(
		"Critical Chance: ",
		get_critical_chance() * 100.0,
		"%"
	))

## Memeriksa apakah Sword Intent masih dapat ditingkatkan.
func can_upgrade_sword_intent() -> bool:
	return (
		sword_intent_level
		< SWORD_INTENT_MAX_LEVEL
	)

## Membuka Sword Dao Resonance selama run.
func unlock_sword_dao_resonance() -> void:
	if sword_dao_resonance_unlocked:
		return

	sword_dao_resonance_unlocked = true

	DebugLogger.system(str("Sword Dao Resonance Unlocked!"))

## Memeriksa apakah Sword Dao Resonance sudah dimiliki.
func has_sword_dao_resonance() -> bool:
	return sword_dao_resonance_unlocked

## Membuka Yin-Yang Reversal selama run.
func unlock_yin_yang_reversal() -> void:
	if yin_yang_reversal_unlocked:
		return

	yin_yang_reversal_unlocked = true

	DebugLogger.system(str("Yin-Yang Reversal Unlocked!"))

## Memeriksa apakah Yin-Yang Reversal sudah dimiliki.
func has_yin_yang_reversal() -> bool:
	return yin_yang_reversal_unlocked

## Membuka Heavenly Tribulation selama run.
func unlock_heavenly_tribulation() -> void:
	if heavenly_tribulation_unlocked:
		return

	heavenly_tribulation_unlocked = true

	DebugLogger.system(str("Heavenly Tribulation Unlocked!"))

## Memeriksa apakah Heavenly Tribulation sudah dimiliki.
func has_heavenly_tribulation() -> bool:
	return heavenly_tribulation_unlocked

## Menerapkan bonus Power permanen dari Sword Power.
func apply_permanent_sword_power() -> void:
	var permanent_bonus: float = (
		ProgressionManager.sword_power_level
		* SWORD_POWER_PER_LEVEL
	)

	power_multiplier += permanent_bonus

	DebugLogger.system(str(
		"Permanent Sword Power Level: ",
		ProgressionManager.sword_power_level
	))

	DebugLogger.system(str(
		"Initial Power Multiplier: ",
		power_multiplier
	))

## Menerapkan bonus Attack Speed permanen dari Swift Qi.
func apply_permanent_swift_qi() -> void:
	for i in range(ProgressionManager.swift_qi_level):
		attack_cooldown *= SWIFT_QI_COOLDOWN_MULTIPLIER

	attack_cooldown = max(
		attack_cooldown,
		minimum_attack_cooldown
	)

	DebugLogger.system(str(
		"Permanent Swift Qi Level: ",
		ProgressionManager.swift_qi_level
	))

	DebugLogger.system(str(
		"Initial Attack Cooldown: ",
		attack_cooldown
	))

	DebugLogger.system(str(
		"Initial Attack Speed: ",
		1.0 / attack_cooldown,
		" attacks/sec"
	))

## Meningkatkan Power selama run sebesar 10%.
func upgrade_power() -> void:
	power_level += 1
	power_multiplier += POWER_PER_LEVEL

	DebugLogger.system(str(
		"Power Level: ",
		power_level
	))

	DebugLogger.system(str(
		"Power Multiplier: ",
		power_multiplier
	))

## Meningkatkan Attack Speed selama run.
## Upgrade berhenti ketika cooldown floor existing sudah tercapai.
func upgrade_attack_speed() -> void:
	if not can_upgrade_attack_speed():
		DebugLogger.system(str("Attack Speed sudah mencapai batas efektif."))
		return

	attack_speed_level += 1
	attack_cooldown *= 0.9

	attack_cooldown = max(
		attack_cooldown,
		minimum_attack_cooldown
	)

	DebugLogger.system(str(
		"Attack Speed Level: ",
		attack_speed_level
	))

	DebugLogger.system(str(
		"Attack Cooldown: ",
		attack_cooldown
	))

	DebugLogger.system(str(
		"Attack Speed: ",
		1.0 / attack_cooldown,
		" attacks/sec"
	))

## Memeriksa apakah Attack Speed masih memberi manfaat nyata.
func can_upgrade_attack_speed() -> bool:
	return (
		attack_cooldown
		> minimum_attack_cooldown + 0.0001
	)
