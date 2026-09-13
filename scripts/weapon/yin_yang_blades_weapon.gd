extends Weapon
class_name YinYangBladesWeapon

## Yin-Yang Blades
## Persistent weapon yang menciptakan beberapa spiritual blade
## dan menggerakkannya mengelilingi Player.
##
## Weapon mengontrol progression, damage, shared hit cooldown,
## serta runtime state Yin-Yang Reversal.
## Blade individual hanya mengontrol orbit
## serta mendeteksi body yang bersentuhan.

const BLADE_SCENE: PackedScene = preload(
	"res://scenes/weapons/yin_yang_blade.tscn"
)

const MAX_LEVEL: int = 7

const BASE_DAMAGE: float = 8.0
const DAMAGE_PER_LEVEL: float = 3.0

const BASE_BLADE_COUNT: int = 2
const MAX_BLADE_COUNT: int = 5

const BASE_ORBIT_RADIUS: float = 80.0
const BASE_ORBIT_SPEED: float = PI
const HIT_INTERVAL: float = 0.5

const REVERSAL_DURATION: float = 4.0
const REVERSAL_ORBIT_SPEED_MULTIPLIER: float = 1.5
const REVERSAL_ORBIT_RADIUS_MULTIPLIER: float = 1.2
const REVERSAL_DAMAGE_MULTIPLIER: float = 1.25

var level: int = 1
var blade_count: int = BASE_BLADE_COUNT

var player: Node2D = null
var player_stats: Node = null
var player_health: PlayerHealth = null

var blades: Array[YinYangBlade] = []
var hit_cooldowns: Dictionary = {}

var reversal_active: bool = false
var reversal_time_remaining: float = 0.0

func _init() -> void:
	weapon_name = "Yin-Yang Blades"
	cooldown = 1.0

	apply_level_stats()

func _process(delta: float) -> void:
	update_hit_cooldowns(delta)
	update_reversal(delta)

## Mengaktifkan weapon dan menghubungkannya dengan Player.
func activate(owner_player: Node2D) -> void:
	if owner_player == null:
		return

	player = owner_player

	player_stats = player.get_node_or_null(
		"PlayerStats"
	)

	player_health = player.get_node_or_null(
		"PlayerHealth"
	) as PlayerHealth

	if player_stats == null:
		push_error(
			"PlayerStats tidak ditemukan untuk Yin-Yang Blades."
		)
		return

	if player_health == null:
		push_error(
			"PlayerHealth tidak ditemukan untuk Yin-Yang Blades."
		)
		return

	connect_qi_shield_block_event()
	rebuild_blades()

## Menghubungkan actual Qi Shield block ke runtime Reversal.
func connect_qi_shield_block_event() -> void:
	if player_health == null:
		return

	if player_health.qi_shield_blocked.is_connected(
		_on_qi_shield_blocked
	):
		return

	player_health.qi_shield_blocked.connect(
		_on_qi_shield_blocked
	)

## Menaikkan level Yin-Yang Blades hingga level maksimum.
func upgrade() -> bool:
	if level >= MAX_LEVEL:
		DebugLogger.system(str("Yin-Yang Blades sudah mencapai level maksimum."))
		return false

	var previous_blade_count: int = blade_count

	level += 1

	apply_level_stats()

	if blade_count != previous_blade_count:
		rebuild_blades()

	print_upgrade_status()

	return true

## Menerapkan damage dan jumlah blade berdasarkan level saat ini.
func apply_level_stats() -> void:
	level = clamp(
		level,
		1,
		MAX_LEVEL
	)

	damage = (
		BASE_DAMAGE
		+ DAMAGE_PER_LEVEL * float(level - 1)
	)

	blade_count = min(
		BASE_BLADE_COUNT
		+ int(floor(float(level - 1) / 2.0)),
		MAX_BLADE_COUNT
	)

## Membuat ulang seluruh blade berdasarkan jumlah blade aktif.
func rebuild_blades() -> void:
	clear_blades()

	if player == null:
		return

	if blade_count <= 0:
		return

	var angle_step: float = (
		TAU / float(blade_count)
	)

	for blade_index in range(blade_count):
		var blade := (
			BLADE_SCENE.instantiate()
			as YinYangBlade
		)

		if blade == null:
			continue

		blade.orbit_radius = get_current_orbit_radius()
		blade.orbit_speed = get_current_orbit_speed()
		blade.orbit_angle = (
			angle_step * float(blade_index)
		)

		blade.set_polarity(
			&"yin"
			if blade_index % 2 == 0
			else &"yang"
		)

		blade.set_reversal_visual(
			reversal_active
		)

		blade.body_contacted.connect(
			_on_blade_body_contacted
		)

		player.add_child.call_deferred(blade)

		blades.append(blade)

	DebugLogger.system(str(
		"Yin-Yang Blades dibuat: ",
		blades.size()
	))

## Memproses permintaan damage dari blade.
func damage_target(target: Node) -> void:
	if target == null:
		return

	if not is_instance_valid(target):
		return

	if not target.has_method("take_damage"):
		return

	if player_stats == null:
		return

	var target_id: int = target.get_instance_id()

	if hit_cooldowns.has(target_id):
		return

	var damage_before_player_stats: float = (
		get_current_damage()
	)

	var final_damage: float = (
		player_stats.calculate_damage(
			damage_before_player_stats
		)
	)

	target.take_damage(final_damage)

	hit_cooldowns[target_id] = HIT_INTERVAL

	DebugLogger.combat(
		"Yin-Yang Blade Hit | Damage: %.1f"
		% final_damage
	)

## Mengaktifkan atau me-refresh Yin-Yang Reversal.
func activate_reversal() -> void:
	if not can_use_reversal():
		return

	reversal_active = true
	reversal_time_remaining = REVERSAL_DURATION

	apply_current_orbit_stats()

	DebugLogger.combat(
		"YIN-YANG REVERSAL ACTIVE | Duration: %.1f"
		% REVERSAL_DURATION
	)

## Mengakhiri Yin-Yang Reversal dan mengembalikan orbit normal.
func deactivate_reversal() -> void:
	if not reversal_active:
		return

	reversal_active = false
	reversal_time_remaining = 0.0

	apply_current_orbit_stats()

	DebugLogger.combat(
		"YIN-YANG REVERSAL ENDED"
	)

## Memeriksa ownership sebelum Reversal dapat digunakan.
func can_use_reversal() -> bool:
	if player_stats == null:
		return false

	if not player_stats.has_method(
		"has_yin_yang_reversal"
	):
		return false

	return player_stats.has_yin_yang_reversal()

## Memperbarui durasi runtime Yin-Yang Reversal.
func update_reversal(delta: float) -> void:
	if not reversal_active:
		return

	reversal_time_remaining -= delta

	if reversal_time_remaining > 0.0:
		return

	deactivate_reversal()

## Menghasilkan damage Yin-Yang Blades sesuai runtime state.
func get_current_damage() -> float:
	if not reversal_active:
		return damage

	return (
		damage
		* REVERSAL_DAMAGE_MULTIPLIER
	)

## Menghasilkan orbit speed sesuai runtime state.
func get_current_orbit_speed() -> float:
	if not reversal_active:
		return BASE_ORBIT_SPEED

	return (
		BASE_ORBIT_SPEED
		* REVERSAL_ORBIT_SPEED_MULTIPLIER
	)

## Menghasilkan orbit radius sesuai runtime state.
func get_current_orbit_radius() -> float:
	if not reversal_active:
		return BASE_ORBIT_RADIUS

	return (
		BASE_ORBIT_RADIUS
		* REVERSAL_ORBIT_RADIUS_MULTIPLIER
	)

## Menerapkan orbit runtime state kepada seluruh blade aktif.
func apply_current_orbit_stats() -> void:
	var current_orbit_speed: float = (
		get_current_orbit_speed()
	)

	var current_orbit_radius: float = (
		get_current_orbit_radius()
	)

	for blade in blades:
		if not is_instance_valid(blade):
			continue

		blade.orbit_speed = current_orbit_speed
		blade.orbit_radius = current_orbit_radius
		blade.set_reversal_visual(
			reversal_active
		)

## Memperbarui cooldown damage setiap target.
func update_hit_cooldowns(delta: float) -> void:
	var target_ids: Array = hit_cooldowns.keys()

	for target_id in target_ids:
		hit_cooldowns[target_id] -= delta

		if hit_cooldowns[target_id] <= 0.0:
			hit_cooldowns.erase(target_id)

## Menghapus seluruh blade orbit yang sedang aktif.
func clear_blades() -> void:
	for blade in blades:
		if is_instance_valid(blade):
			blade.queue_free()

	blades.clear()

## Menampilkan status progression setelah upgrade.
func print_upgrade_status() -> void:
	DebugLogger.system(str(
		"Yin-Yang Blades Level: ",
		level
	))

	DebugLogger.system(str(
		"Yin-Yang Blades Damage: ",
		damage
	))

	DebugLogger.system(str(
		"Yin-Yang Blades Blade Count: ",
		blade_count
	))

## Menerima actual Qi Shield block dari PlayerHealth.
func _on_qi_shield_blocked(
	_remaining_charges: int
) -> void:
	activate_reversal()

## Menerima body yang sedang bersentuhan dengan blade.
func _on_blade_body_contacted(body: Node) -> void:
	damage_target(body)
