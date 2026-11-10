extends SpiritSwordWeapon

const Needle = preload("res://scripts/weapon/gale_parasol_needle.gd")
const Wind = preload("res://scripts/weapon/gale_parasol_wave.gd")
const Reach = preload("res://scripts/data/weapon_reach.gd")
const Sets = preload("res://scripts/data/equipment_set_catalog.gd")
const SetRuntime = preload("res://scripts/data/equipment_set_runtime.gd")
const CLOSED = preload("res://assets/ui/equipment/galeweave/parasol_closed.png")
const OPEN = preload("res://assets/ui/equipment/galeweave/parasol_open.png")

const CROWD_RADIUS: float = 108.0
const CROWD_SPREAD: float = PI * 0.375
const SCAN_INTERVAL: float = 0.12
const WIND_COOLDOWN: float = 4.2
const OPEN_TIME: float = 0.48

var _parasol: Sprite2D
var _wind_remaining: float = 0.0
var _open_remaining: float = 0.0
var _scan_remaining: float = 0.0

func _ready() -> void:
	super._ready()
	cooldown = 0.95
	base_damage = 8.5
	_parasol = Sprite2D.new()
	_parasol.z_index = 2
	_show_canopy(false)
	get_parent().get_parent().add_child.call_deferred(_parasol)

func _exit_tree() -> void:
	if is_instance_valid(_parasol):
		_parasol.queue_free()

func _show_canopy(open: bool) -> void:
	_parasol.texture = OPEN if open else CLOSED
	_parasol.scale = Vector2.ONE * (0.20 if open else 0.19)
	_parasol.position = Vector2(14, -30) if open else Vector2(15, -13)
	_parasol.rotation = 0.0 if open else 0.30

func blocks_needle() -> bool:
	return _open_remaining > 0.0

func tick_opening(player: Node2D, delta: float) -> bool:
	if blocks_needle():
		_open_remaining -= delta
		if not blocks_needle():
			_show_canopy(false)
	_wind_remaining -= delta
	_scan_remaining -= delta
	if _wind_remaining > 0.0 or _scan_remaining > 0.0:
		return false
	_scan_remaining = SCAN_INTERVAL

	var nearby: Array[Node2D] = []
	var crowd_count: int = 0
	var first_angle: float = 0.0
	var min_angle: float = 0.0
	var max_angle: float = 0.0
	for candidate in get_tree().get_nodes_in_group("enemy"):
		if not Wind.living(candidate):
			continue
		var enemy := candidate as Node2D
		var offset: Vector2 = enemy.global_position - player.global_position
		var distance_sq: float = offset.length_squared()
		if distance_sq > Wind.RADIUS * Wind.RADIUS:
			continue
		nearby.append(enemy)
		if distance_sq > CROWD_RADIUS * CROWD_RADIUS:
			continue
		var angle: float = offset.angle()
		if crowd_count == 0:
			first_angle = angle
		var relative: float = angle_difference(first_angle, angle)
		min_angle = minf(min_angle, relative)
		max_angle = maxf(max_angle, relative)
		crowd_count += 1
	if crowd_count < 3 or max_angle - min_angle < CROWD_SPREAD:
		return false

	var full_set: bool = _set_pieces() >= 4
	var wave: Node2D = Wind.new()
	wave.configure(player, nearby, _scaled_damage() * 0.82, 57.0 if full_set else 42.0)
	player.get_parent().add_child(wave)
	wave.global_position = player.global_position
	_wind_remaining = WIND_COOLDOWN
	_open_remaining = OPEN_TIME
	_show_canopy(true)
	if full_set:
		player.activate_parasol_windstep()
	return true

func attack(player: Node2D, target: Node2D) -> void:
	if blocks_needle() or not Wind.living(target):
		return
	var socket := player.get_node_or_null("CombatOrigin") as Node2D
	var origin: Vector2 = socket.global_position if socket != null else player.global_position
	var direction: Vector2 = origin.direction_to(target.global_position)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var needle: Node2D = Needle.new()
	needle.configure(direction, Reach.normal(player), Reach.boss(player),
		player.player_stats.calculate_damage_result(_scaled_damage()),
		3 if _set_pieces() >= 3 else 2, player.player_stats.has_sword_dao_resonance())
	player.get_parent().add_child(needle)
	needle.global_position = origin
	needle.rotation = direction.angle()

func _scaled_damage() -> float:
	return (base_damage * EquipmentManager.get_weapon_level_multiplier(armament_id)
		* get_parent().get_cast_tempo_damage_multiplier(self))

func _set_pieces() -> int:
	return Sets.get_piece_count("galeweave", SetRuntime.get_equipped_item_ids())
