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

## Normal enemies remain reachable at short screen distance. Boss targets
## require a closer approach: the smallest configured boss ranged-AI radius
## across Chapters 1-3 is 240 px, so 230 px prevents free off-screen damage.
@export_range(120.0, 500.0, 10.0) var maximum_attack_range: float = 320.0
@export_range(100.0, 500.0, 10.0) var boss_attack_range: float = 230.0

## Reuse one nearest enemy for all weapon cooldowns until this short interval
## expires. Retarget immediately if the cached enemy dies or leaves the radius.
const TARGET_REFRESH_INTERVAL: float = 0.12
const DEBUG_SAMPLE_INTERVAL: float = 12.0
const CAST_COOLDOWN_FLOORS: Dictionary = {
	"jade_binding_chain": 1.25,
	"celestial_returning_glaive": 1.75
}
const MAX_CAST_TEMPO_DAMAGE_MULTIPLIER: float = 5.0

var weapons: Array[Weapon] = []
var attack_timers: Dictionary = {}
var _cached_target: Node2D = null
var _target_refresh_remaining: float = 0.0
const CombatPerfWindow = preload("res://scripts/debug/combat_perf_window.gd")
var _debug_frames: RefCounted = CombatPerfWindow.new()
var _debug_last_frame_usec: int = 0
var _debug_elapsed: float = 0.0
var _target_searches: int = 0
var _fired_attacks: int = 0

@onready var player: Node2D = get_parent()
@onready var player_stats = player.get_node("PlayerStats")

func _ready() -> void:
	DebugLogger.system(str("WeaponManager aktif!"))
	var ledger: Node=preload("res://scripts/weapon/run_combat_ledger.gd").new()
	ledger.name="RunCombatLedger"
	add_child(ledger)
	initialize_weapons()

## Membuat weapon awal yang dimiliki Player.
## Internal weapon_name tetap Spirit Sword untuk kompatibilitas checkpoint v1.
## Reviewed armaments select their own starter attack; checkpoint identity stays stable.
func initialize_weapons() -> void:
	var runtime_armament_id: String = EquipmentManager.get_runtime_equipped_item_id(
		EquipmentManager.SLOT_ARMAMENT
	)
	var spirit_sword: SpiritSwordWeapon = SpiritSwordWeapon.new()
	if runtime_armament_id == "jade_binding_chain":
		spirit_sword.free()
		spirit_sword = preload("res://scripts/weapon/jade_binding_chain_weapon.gd").new()
	elif runtime_armament_id == "celestial_returning_glaive":
		spirit_sword.free()
		spirit_sword = preload("res://scripts/weapon/celestial_returning_glaive_weapon.gd").new()
	spirit_sword.configure_armament(runtime_armament_id)

	add_child(spirit_sword)
	add_weapon(spirit_sword)

	attack_timers[spirit_sword] = 0.0

	DebugLogger.system(str(
		"Starter Armament Combat Identity: ",
		spirit_sword.get_combat_display_name(),
		" | Equipment ID: ",
		runtime_armament_id if not runtime_armament_id.is_empty() else "default"
	))

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
	_target_refresh_remaining -= delta
	_log_combat_sample(delta)

	var target: Node2D = null
	for weapon in weapons:
		if weapon == null or not is_instance_valid(weapon):
			continue
		if not attack_timers.has(weapon):
			continue

		attack_timers[weapon] -= delta
		if attack_timers[weapon] > 0.0:
			continue

		# A projectile/instant hit from the previous weapon can kill this target
		# in the same frame. Revalidate before every attack in the batch.
		if not _is_target_attackable(target):
			target = _get_attack_target()
		if target == null:
			# Keep the old ready-to-fire timer: moving back into range fires
			# immediately, without spending cooldown on empty space.
			continue

		if weapon.weapon_name == "Spirit Sword" and str(weapon.get("armament_id")) not in ["jade_binding_chain", "celestial_returning_glaive"]:
			AudioManager.play_sfx("sword")
		elif weapon.weapon_name == "Fire Orb":
			AudioManager.play_sfx("fire")
		var attack_target_position: Vector2 = target.global_position
		weapon.attack(player, target)
		weapon_attack_triggered.emit(
			weapon.get_combat_display_name() if weapon.weapon_name == "Spirit Sword" and str(weapon.get("armament_id")) in ["jade_binding_chain", "celestial_returning_glaive"] else weapon.weapon_name,
			attack_target_position
		)
		_fired_attacks += 1
		attack_timers[weapon] = get_weapon_cooldown(weapon)


func _is_target_attackable(target: Variant) -> bool:
	# IMPORTANT:
	# A previous weapon in the same frame may kill/free the current target.
	# Keep this parameter untyped until validity is checked; otherwise Godot
	# performs the Node2D argument type check before entering this function and
	# throws when the Variant contains a previously-freed Object.
	if target == null or not is_instance_valid(target):
		return false
	if not target is Node2D:
		return false

	var target_node := target as Node2D
	if target_node.is_queued_for_deletion() or bool(target_node.get("is_dead")):
		return false
	if not target_node.is_in_group("enemy"):
		return false

	var allowed_range: float = maximum_attack_range
	if target_node.is_in_group("boss"):
		allowed_range = minf(maximum_attack_range, boss_attack_range)

	return (
		player.global_position.distance_squared_to(target_node.global_position)
		<= allowed_range * allowed_range
	)


func _get_attack_target() -> Node2D:
	var previous_target_lost: bool = (
		_cached_target != null and not _is_target_attackable(_cached_target)
	)
	if _target_refresh_remaining > 0.0 and not previous_target_lost:
		# Negative results are also cached: avoid 60 group scans/second
		# when every enemy is outside the permitted attack range.
		return _cached_target

	_target_refresh_remaining = TARGET_REFRESH_INTERVAL
	_cached_target = player.find_nearest_enemy(
		maximum_attack_range,
		minf(maximum_attack_range, boss_attack_range)
	)
	_target_searches += 1
	if not _is_target_attackable(_cached_target):
		_cached_target = null
	return _cached_target


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED:
		# A deliberate pause/hit-stop must not become a false slow frame.
		_debug_last_frame_usec = 0

func _log_combat_sample(delta: float) -> void:
	if not OS.is_debug_build():
		return
	var now_usec: int = Time.get_ticks_usec()
	if _debug_last_frame_usec > 0:
		_debug_frames.add(float(now_usec - _debug_last_frame_usec) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS)*1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
	_debug_last_frame_usec = now_usec
	_debug_elapsed += delta
	if _debug_elapsed < DEBUG_SAMPLE_INTERVAL:
		return
	_debug_elapsed = 0.0
	DebugLogger.system(
		(
			"CombatPerf | FPS: %.0f | Enemies: %d | Target scans: %d | "
			+ "Auto-attacks: %d | Normal: %.0f px | Boss: %.0f px"
		) % [
			Engine.get_frames_per_second(),
			get_tree().get_nodes_in_group("enemy").size(),
			_target_searches,
			_fired_attacks,
			maximum_attack_range,
			boss_attack_range
		]
	)
	var frames: Dictionary = _debug_frames.snapshot()
	DebugLogger.system(
		"CrowdPerf | Frames: %d | Mean: %.2f ms | P95: %.2f ms | Max: %.2f ms | >33ms: %d | >50ms: %d | Process avg: %.2f ms | Physics avg/max: %.2f/%.2f ms | Draw calls: %d | Collision pairs: %d | Hostile attacks: %d" % [
			int(frames.count), float(frames.mean_ms), float(frames.p95_ms), float(frames.max_ms), int(frames.over_33), int(frames.over_50),
			float(frames.process_mean_ms), float(frames.physics_mean_ms), float(frames.physics_max_ms),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)),
			get_tree().get_nodes_in_group("enemy_attack").size()
		]
	)
	_debug_frames.reset()
	_target_searches = 0
	_fired_attacks = 0

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
	var requested: float = get_requested_weapon_cooldown(weapon)
	return maxf(requested, float(CAST_COOLDOWN_FLOORS.get(_cast_armament_id(weapon), 0.1)))


## Attack Speed exceeding a deliberate cast cadence increases potency instead
## of spawning extra casts. Damage is snapshotted by each weapon at launch.
func get_cast_tempo_damage_multiplier(weapon: Weapon) -> float:
	if not CAST_COOLDOWN_FLOORS.has(_cast_armament_id(weapon)):
		return 1.0
	var requested: float = get_requested_weapon_cooldown(weapon)
	var actual: float = maxf(requested, float(CAST_COOLDOWN_FLOORS[_cast_armament_id(weapon)]))
	return clampf(actual / requested, 1.0, MAX_CAST_TEMPO_DAMAGE_MULTIPLIER)


func _cast_armament_id(weapon: Weapon) -> String:
	if weapon == null or weapon.weapon_name != "Spirit Sword":
		return ""
	return str(weapon.get("armament_id"))


func get_requested_weapon_cooldown(weapon: Weapon) -> float:
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

	return maxf(final_cooldown, 0.1)
