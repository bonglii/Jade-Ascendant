extends Node2D
class_name LinYueCombatPresentation

## Lin Yue Actual Combat Presentation
##
## Receives REAL WeaponManager attack events and renders a tiny source-focus /
## Qi-release cue directly from this CanvasItem. The effect uses a fixed pool of
## dictionaries and _draw(); it allocates no transient Nodes, Line2Ds, Tweens or
## Resources per attack. This keeps mobile combat presentation bounded and makes
## rapid scene replacement deterministic for the Phase 0 smoke runner.
##
## Presentation only:
## - no collision
## - no damage
## - no cooldown changes
## - no fake weapon trajectory
## - does not replace locomotion/hurt/death animation
## - tiny radius by design; never represents an AoE

const EFFECT_DURATION: float = 0.14
const MAX_ACTIVE_EFFECTS: int = 3
const RING_SEGMENTS: int = 24

var _effects: Array[Dictionary] = []
var _effect_cursor: int = 0

@onready var player: Node2D = get_parent()
@onready var weapon_manager: Node = player.get_node_or_null("WeaponManager")


func _ready() -> void:
	for _index in range(MAX_ACTIVE_EFFECTS):
		_effects.append({"left": 0.0})
	set_process(false)

	if weapon_manager == null:
		push_warning(
			"Lin Yue Combat Presentation: WeaponManager tidak ditemukan."
		)
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

	# No transient CanvasItems/Tweens exist, so teardown is immediate.
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
		var base_color: Color = effect.get(
			"color",
			Color(0.42, 0.88, 0.80, 0.70)
		)

		var ring_color := Color(base_color, base_color.a * fade)
		var release_base: Color = base_color.lightened(0.18)
		var release_color := Color(
			release_base,
			release_base.a * fade
		)
		var wisp_color := Color(
			base_color,
			base_color.a * fade * 0.82
		)

		var ring_radius: float = lerpf(7.0, 12.25, progress)
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			0.0,
			TAU,
			RING_SEGMENTS,
			ring_color,
			1.6,
			true
		)

		var release_start: Vector2 = direction * 4.0
		var release_end: Vector2 = direction * lerpf(
			18.0,
			21.25,
			progress
		)
		draw_line(
			release_start,
			release_end,
			release_color,
			2.4,
			true
		)

		var tangent: Vector2 = direction.rotated(PI * 0.5)
		for side_value in [-1.0, 1.0]:
			var side: float = float(side_value)
			var wisp_start: Vector2 = tangent * side * 4.0
			var wisp_end: Vector2 = (
				direction * lerpf(9.0, 10.5, progress)
				+ tangent * side * 7.0
			)
			draw_line(
				wisp_start,
				wisp_end,
				wisp_color,
				1.2,
				true
			)


func get_weapon_color(weapon_name: String) -> Color:
	match weapon_name:
		"Fire Orb":
			return Color(1.0, 0.52, 0.14, 0.76)
		"Thunder Talisman":
			return Color(0.70, 0.91, 1.0, 0.78)
		"Heavenly Sword Rain":
			return Color(0.82, 0.96, 1.0, 0.78)
		"Eight Trigrams Formation":
			return Color(0.48, 0.90, 0.60, 0.72)
		"Spirit Sword":
			return Color(0.38, 0.92, 0.84, 0.76)
		_:
			return Color(0.42, 0.88, 0.80, 0.70)
