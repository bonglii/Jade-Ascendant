extends Node

## Weapon Manager
## Mengelola weapon aktif, attack timer,
## cooldown, penambahan weapon,
## dan upgrade weapon selama run.

signal weapon_attack_triggered(
	weapon_name: String,
	target_position: Vector2
)

const EquipmentSetRuntime = preload("res://scripts/data/equipment_set_runtime.gd")

var weapons: Array[Weapon] = []
var attack_timers: Dictionary = {}

@onready var player: Node2D = get_parent()
@onready var player_stats = player.get_node("PlayerStats")

func _ready() -> void:
	DebugLogger.system(str("WeaponManager aktif!"))
	initialize_weapons()

## Membuat weapon awal yang dimiliki Player.
## Starter production sengaja hanya Spirit Sword Lv1; weapon lain diperoleh
## sebagai pilihan breakthrough selama run atau dipulihkan dari checkpoint.
func initialize_weapons() -> void:
	var spirit_sword := SpiritSwordWeapon.new()

	add_child(spirit_sword)
	add_weapon(spirit_sword)

	attack_timers[spirit_sword] = 0.0

## Memberikan Fire Orb kepada Player sebagai acquisition runtime.
func add_fire_orb() -> void:
	if get_weapon_by_name("Fire Orb") != null:
		return

	var fire_orb := FireOrbWeapon.new()

	add_child(fire_orb)
	add_weapon(fire_orb)

	attack_timers[fire_orb] = fire_orb.cooldown

	DebugLogger.system(str("Fire Orb diperoleh!"))

func _process(delta: float) -> void:
	var target: Node2D = null
	for weapon in weapons:
		if weapon == null:
			continue

		if not attack_timers.has(weapon):
			continue

		attack_timers[weapon] -= delta

		if attack_timers[weapon] <= 0.0:
			if not is_instance_valid(target) or not target.is_in_group("enemy"):
				target = player.find_nearest_enemy()

			if target:
				if weapon.weapon_name == "Spirit Sword":
					AudioManager.play_sfx("sword")
				elif weapon.weapon_name == "Fire Orb":
					AudioManager.play_sfx("fire")
				var attack_target_position: Vector2 = target.global_position
				weapon.attack(player, target)
				weapon_attack_triggered.emit(
					weapon.weapon_name,
					attack_target_position
				)

				attack_timers[weapon] = (
					get_weapon_cooldown(weapon)
				)

## Menambahkan weapon ke daftar weapon aktif.
func add_weapon(weapon: Weapon) -> void:
	if weapon == null:
		return

	if weapon in weapons:
		return

	weapons.append(weapon)

	DebugLogger.system(str(
		"Weapon ditambahkan: ",
		weapon.weapon_name
	))

## Memberikan Thunder Talisman kepada Player.
func add_thunder_talisman() -> void:
	if get_weapon_by_name("Thunder Talisman") != null:
		return

	var thunder_talisman := ThunderTalismanWeapon.new()

	add_child(thunder_talisman)
	add_weapon(thunder_talisman)

	attack_timers[thunder_talisman] = (
		thunder_talisman.cooldown
	)

	DebugLogger.system(str("Thunder Talisman diperoleh!"))

## Memberikan Yin-Yang Blades kepada Player.
func add_yin_yang_blades() -> void:
	if get_weapon_by_name("Yin-Yang Blades") != null:
		return

	var yin_yang_blades := YinYangBladesWeapon.new()

	add_child(yin_yang_blades)
	add_weapon(yin_yang_blades)

	yin_yang_blades.activate(player)

	DebugLogger.system(str("Yin-Yang Blades diperoleh!"))

## Memberikan Heavenly Sword Rain kepada Player.
func add_heavenly_sword_rain() -> void:
	if get_weapon_by_name("Heavenly Sword Rain") != null:
		return

	var heavenly_sword_rain := HeavenlySwordRainWeapon.new()

	add_child(heavenly_sword_rain)
	add_weapon(heavenly_sword_rain)

	attack_timers[heavenly_sword_rain] = (
		heavenly_sword_rain.cooldown
	)

	DebugLogger.system(str("Heavenly Sword Rain diperoleh!"))

## Memberikan Eight Trigrams Formation kepada Player.
func add_eight_trigrams_formation() -> void:
	if get_weapon_by_name("Eight Trigrams Formation") != null:
		return

	var eight_trigrams_formation := (
		EightTrigramsFormationWeapon.new()
	)

	add_child(eight_trigrams_formation)
	add_weapon(eight_trigrams_formation)

	attack_timers[eight_trigrams_formation] = (
		eight_trigrams_formation.cooldown
	)

	DebugLogger.system(str("Eight Trigrams Formation diperoleh!"))

## Menghapus weapon dari daftar weapon aktif.
func remove_weapon(weapon: Weapon) -> void:
	if weapon in weapons:
		weapons.erase(weapon)
		attack_timers.erase(weapon)

		DebugLogger.system(str(
			"Weapon dihapus: ",
			weapon.weapon_name
		))

## Mengembalikan seluruh weapon aktif.
func get_weapons() -> Array[Weapon]:
	return weapons

## Mencari weapon berdasarkan nama.
func get_weapon_by_name(weapon_name: String) -> Weapon:
	for weapon in weapons:
		if weapon.weapon_name == weapon_name:
			return weapon

	return null

## Meningkatkan level weapon berdasarkan nama.
func upgrade_weapon(weapon_name: String) -> void:
	var weapon = get_weapon_by_name(weapon_name)

	if weapon == null:
		DebugLogger.system(str(
			"Weapon tidak ditemukan: ",
			weapon_name
		))
		return

	weapon.upgrade()
	if int(weapon.get("level")) >= 7:
		AchievementManager.set_progress_at_least("art_master", 1)

## Menghitung cooldown final weapon berdasarkan Attack Speed Player.
func get_weapon_cooldown(weapon: Weapon) -> float:
	if weapon == null:
		return 1.0

	var base_cooldown: float = weapon.cooldown

	var attack_cooldown: float = (
		player_stats.attack_cooldown
	)

	if attack_cooldown <= 0.0:
		return base_cooldown

	var cooldown_reduction: float = EquipmentSetRuntime.get_capped_combined_secondary_bonus(
		"attack_cooldown_reduction",
		0.10
	)
	var equipment_cooldown_multiplier: float = maxf(
		1.0 - cooldown_reduction,
		0.50
	)
	var final_cooldown: float = (
		base_cooldown
		* attack_cooldown
		* equipment_cooldown_multiplier
	)

	return max(final_cooldown, 0.1)
