extends Node2D
class_name LinYueCombatPresentation

## Signature player-side cast presentation.
## Receives actual WeaponManager attack events. It never owns damage/collision.
## The node is aligned to player CombatOrigin in player_1.tscn.
##
## Design rule:
## - player-origin cue is centered on CombatOrigin
## - target AoE/range is NEVER represented here
## - all drawing is pooled and allocation-free during _draw()

const EFFECT_DURATION: float = 0.24
const MAX_ACTIVE_EFFECTS: int = 5
const RING_SEGMENTS: int = 32

var _effects: Array[Dictionary] = []
var _effect_cursor: int = 0

@onready var player: Node2D = get_parent()
@onready var weapon_manager: Node = player.get_node_or_null("WeaponManager")


func _ready() -> void:
	for _index in range(MAX_ACTIVE_EFFECTS):
		_effects.append({"left": 0.0})

	set_process(false)

	if weapon_manager == null:
		push_warning("Lin Yue Combat Presentation: WeaponManager tidak ditemukan.")
		return

	if not weapon_manager.has_signal("weapon_attack_triggered"):
		push_warning(
			"Lin Yue Combat Presentation: signal weapon_attack_triggered tidak tersedia."
		)
		return

	if not weapon_manager.weapon_attack_triggered.is_connected(
		_on_weapon_attack_triggered
	):
		weapon_manager.weapon_attack_triggered.connect(
			_on_weapon_attack_triggered
		)


func _exit_tree() -> void:
	if (
		is_instance_valid(weapon_manager)
		and weapon_manager.has_signal("weapon_attack_triggered")
		and weapon_manager.weapon_attack_triggered.is_connected(
			_on_weapon_attack_triggered
		)
	):
		weapon_manager.weapon_attack_triggered.disconnect(
			_on_weapon_attack_triggered
		)

	_effects.clear()
	set_process(false)


func _on_weapon_attack_triggered(
	weapon_name: String,
	target_position: Vector2
) -> void:
	if _effects.is_empty():
		return

	var release_direction: Vector2 = global_position.direction_to(
		target_position
	)
	if release_direction.length_squared() <= 0.0001:
		release_direction = Vector2.RIGHT

	var effect: Dictionary = _effects[_effect_cursor]
	_effect_cursor = (_effect_cursor + 1) % _effects.size()

	effect.clear()
	effect["left"] = EFFECT_DURATION
	effect["direction"] = release_direction.normalized()
	effect["weapon_name"] = weapon_name
	effect["color"] = get_weapon_color(weapon_name)

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	var any_active: bool = false

	for effect: Dictionary in _effects:
		var left: float = maxf(
			float(effect.get("left", 0.0)) - delta,
			0.0
		)
		effect["left"] = left

		if left > 0.0:
			any_active = true

	queue_redraw()

	if not any_active:
		set_process(false)


func _draw() -> void:
	for effect: Dictionary in _effects:
		var left: float = float(effect.get("left", 0.0))
		if left <= 0.0:
			continue

		var progress: float = clampf(
			1.0 - left / EFFECT_DURATION,
			0.0,
			1.0
		)
		var fade: float = 1.0 - progress
		var direction: Vector2 = effect.get(
			"direction",
			Vector2.RIGHT
		)
		var weapon_name: String = str(
			effect.get("weapon_name", "")
		)
		var base_color: Color = effect.get(
			"color",
			Color(0.42, 0.88, 0.80, 0.80)
		)

		_draw_common_release(
			progress,
			fade,
			direction,
			base_color
		)

		if SettingsManager.reduced_effects:
			continue

		match weapon_name:
			"Spirit Sword":
				_draw_spirit_sword_signature(
					progress,
					fade,
					direction
				)
			"Fire Orb":
				_draw_fire_orb_signature(
					progress,
					fade,
					direction
				)
			"Thunder Talisman":
				_draw_thunder_talisman_signature(
					progress,
					fade,
					direction
				)
			"Heavenly Sword Rain":
				_draw_sword_rain_signature(
					progress,
					fade
				)
			"Eight Trigrams Formation":
				_draw_trigrams_signature(
					progress,
					fade
				)


func _draw_common_release(
	progress: float,
	fade: float,
	direction: Vector2,
	base_color: Color
) -> void:
	var ring_color := Color(
		base_color.r,
		base_color.g,
		base_color.b,
		base_color.a * fade
	)
	var pale: Color = base_color.lightened(0.28)
	var pale_color := Color(
		pale.r,
		pale.g,
		pale.b,
		pale.a * fade
	)

	var inner_radius: float = lerpf(8.0, 16.0, progress)
	var outer_radius: float = lerpf(13.0, 22.0, progress)

	draw_arc(
		Vector2.ZERO,
		inner_radius,
		0.0,
		TAU,
		RING_SEGMENTS,
		ring_color,
		2.3,
		true
	)

	draw_arc(
		Vector2.ZERO,
		outer_radius,
		-PI * 0.72,
		PI * 0.18,
		20,
		Color(
			base_color.r,
			base_color.g,
			base_color.b,
			base_color.a * fade * 0.48
		),
		1.4,
		true
	)

	draw_arc(
		Vector2.ZERO,
		outer_radius,
		PI * 0.28,
		PI * 1.18,
		20,
		Color(
			base_color.r,
			base_color.g,
			base_color.b,
			base_color.a * fade * 0.48
		),
		1.4,
		true
	)

	var release_start: Vector2 = direction * 4.0
	var release_end: Vector2 = direction * lerpf(
		22.0,
		30.0,
		progress
	)

	draw_line(
		release_start,
		release_end,
		pale_color,
		3.0,
		true
	)

	var tangent: Vector2 = direction.rotated(PI * 0.5)
	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		draw_line(
			tangent * side * 4.0,
			direction * lerpf(11.0, 15.0, progress)
			+ tangent * side * 10.0,
			Color(
				base_color.r,
				base_color.g,
				base_color.b,
				base_color.a * fade * 0.72
			),
			1.5,
			true
		)


func _draw_spirit_sword_signature(
	progress: float,
	fade: float,
	direction: Vector2
) -> void:
	var jade := Color(0.40, 1.0, 0.88, 0.88 * fade)
	var pale := Color(0.88, 1.0, 0.97, 0.92 * fade)
	var tangent: Vector2 = direction.rotated(PI * 0.5)

	var center: Vector2 = direction * 11.0
	draw_line(
		center - direction * 10.0,
		center + direction * 16.0,
		pale,
		2.3,
		true
	)
	draw_line(
		center - tangent * 6.0,
		center + tangent * 6.0,
		jade,
		1.7,
		true
	)

	var tip: Vector2 = center + direction * lerpf(
		13.0,
		19.0,
		progress
	)
	draw_line(
		tip - tangent * 4.0 - direction * 6.0,
		tip,
		jade,
		1.5,
		true
	)
	draw_line(
		tip + tangent * 4.0 - direction * 6.0,
		tip,
		jade,
		1.5,
		true
	)


func _draw_fire_orb_signature(
	progress: float,
	fade: float,
	direction: Vector2
) -> void:
	var orange := Color(1.0, 0.38, 0.06, 0.80 * fade)
	var gold := Color(1.0, 0.82, 0.28, 0.90 * fade)
	var center: Vector2 = direction * 12.0

	draw_circle(
		center,
		lerpf(5.0, 8.0, progress),
		Color(1.0, 0.28, 0.04, 0.20 * fade)
	)
	draw_arc(
		center,
		lerpf(7.0, 11.0, progress),
		0.0,
		TAU,
		24,
		gold,
		2.0,
		true
	)

	for index in range(6):
		var ray_direction := Vector2.RIGHT.rotated(
			float(index) * TAU / 6.0
		)
		draw_line(
			center + ray_direction * 7.0,
			center + ray_direction * lerpf(
				12.0,
				17.0,
				progress
			),
			orange,
			1.7,
			true
		)


func _draw_thunder_talisman_signature(
	progress: float,
	fade: float,
	direction: Vector2
) -> void:
	var cyan := Color(0.55, 0.91, 1.0, 0.92 * fade)
	var pale := Color(0.90, 0.98, 1.0, 0.96 * fade)
	var center: Vector2 = direction * 9.0
	var radial := direction
	var tangent := direction.rotated(PI * 0.5)

	var size: float = lerpf(8.0, 12.0, progress)
	var diamond := PackedVector2Array([
		center + radial * size,
		center + tangent * size * 0.72,
		center - radial * size,
		center - tangent * size * 0.72,
		center + radial * size
	])
	draw_polyline(
		diamond,
		cyan,
		2.0,
		true
	)

	draw_line(
		center - tangent * 5.0 - radial * 3.0,
		center + tangent * 2.0,
		pale,
		1.6,
		true
	)
	draw_line(
		center + tangent * 2.0,
		center - tangent * 1.0 + radial * 6.0,
		pale,
		1.6,
		true
	)


func _draw_sword_rain_signature(
	progress: float,
	fade: float
) -> void:
	var celestial := Color(0.72, 0.94, 1.0, 0.88 * fade)
	var pale := Color(0.94, 0.99, 1.0, 0.96 * fade)

	draw_arc(
		Vector2.ZERO,
		lerpf(15.0, 24.0, progress),
		0.0,
		TAU,
		28,
		celestial,
		1.7,
		true
	)

	draw_line(
		Vector2(0.0, -22.0),
		Vector2(0.0, 16.0),
		pale,
		2.2,
		true
	)
	draw_line(
		Vector2(-6.0, 7.0),
		Vector2(6.0, 7.0),
		celestial,
		1.7,
		true
	)

	for side_value in [-1.0, 1.0]:
		var side: float = float(side_value)
		draw_line(
			Vector2(side * 11.0, -15.0),
			Vector2(side * 7.0, 10.0),
			Color(
				celestial.r,
				celestial.g,
				celestial.b,
				0.55 * fade
			),
			1.3,
			true
		)


func _draw_trigrams_signature(
	progress: float,
	fade: float
) -> void:
	var jade := Color(0.42, 0.96, 0.66, 0.82 * fade)
	var gold := Color(0.96, 0.78, 0.34, 0.72 * fade)
	var radius: float = lerpf(15.0, 23.0, progress)

	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		32,
		jade,
		1.8,
		true
	)

	for index in range(8):
		var direction := Vector2.RIGHT.rotated(
			float(index) * TAU / 8.0
		)
		var tangent := direction.rotated(PI * 0.5)
		var center := direction * radius * 0.78

		draw_line(
			center - tangent * 4.0,
			center + tangent * 4.0,
			gold,
			1.3,
			true
		)


func get_weapon_color(weapon_name: String) -> Color:
	match weapon_name:
		"Fire Orb":
			return Color(1.0, 0.52, 0.14, 0.86)
		"Thunder Talisman":
			return Color(0.70, 0.91, 1.0, 0.90)
		"Heavenly Sword Rain":
			return Color(0.82, 0.96, 1.0, 0.90)
		"Eight Trigrams Formation":
			return Color(0.48, 0.90, 0.60, 0.84)
		"Spirit Sword":
			return Color(0.38, 0.92, 0.84, 0.88)
		_:
			return Color(0.42, 0.88, 0.80, 0.82)
