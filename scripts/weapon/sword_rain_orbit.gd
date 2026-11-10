extends Node2D

const BLADE: Texture2D = preload("res://assets/weapons/sword/heavenly_sword_rain_jian_64x96.png")
const BLADE_SIZE := Vector2(22.0, 33.0)
const LIFT_TIME := 0.24

var count: int = 2
var cooldown_progress: float = 1.0
var released: int = 0
var _angle: float = 0.0
var _lifts: Array[Vector3] = []

func release(amount: int) -> void:
	for index in range(released, mini(count, released + amount)):
		var origin := _blade_position(index)
		_lifts.append(Vector3(origin.x, origin.y, 0.0))
	released = mini(count, released + amount)

func _process(delta: float) -> void:
	_angle = fposmod(_angle + delta * 2.0, TAU)
	for index in range(_lifts.size() - 1, -1, -1):
		_lifts[index].z += delta
		if _lifts[index].z >= LIFT_TIME:
			_lifts.remove_at(index)
	queue_redraw()

func _blade_position(index: int) -> Vector2:
	var angle := _angle + TAU * float(index) / maxi(1, count)
	return Vector2(cos(angle) * 34.0, sin(angle) * 16.0 - 5.0)

func _draw() -> void:
	for index in range(count):
		var opacity := 1.0
		if index < released:
			var delay := 0.43 + 0.35 * float(index) / maxi(1, released - 1)
			opacity = smoothstep(delay, delay + 0.17, cooldown_progress)
		var origin := _blade_position(index)
		var shade := 0.76 if origin.y < -5.0 else 1.0
		draw_texture_rect(BLADE, Rect2(origin - BLADE_SIZE * 0.5, BLADE_SIZE), false, Color(0.84, 1.0, 1.0, opacity * shade))
	for lift in _lifts:
		var progress := lift.z / LIFT_TIME
		var origin := Vector2(lift.x * (1.0 - progress * 0.25), lift.y - 67.0 * progress * progress)
		draw_set_transform(origin, PI)
		draw_texture_rect(BLADE, Rect2(-BLADE_SIZE * 0.5, BLADE_SIZE), false, Color(0.78, 1.0, 1.0, 1.0 - progress))
	draw_set_transform(Vector2.ZERO)
