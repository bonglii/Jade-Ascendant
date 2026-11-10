extends Node2D
class_name ThunderTalismanStrike

## Visual-only primary Thunder Talisman hit. Damage and chain targets stay
## authoritative in ThunderTalismanWeapon; this Node2D never deals damage.
## One CanvasItem draw instead of spawning Line2D and Tween nodes.

const Vfx = preload("res://scripts/effects/weapon_vfx_art.gd")
const EFFECT_DURATION: float = 0.24
const LIGHTNING_SEGMENTS: int = 9
const IMPACT_SEGMENTS: int = 36

@onready var talisman_sprite: AnimatedSprite2D = $TalismanSprite

var _target_local: Vector2 = Vector2.ZERO
var _bolt_points: PackedVector2Array = PackedVector2Array()
var _forks: Array[PackedVector2Array] = []
var _elapsed: float = 0.0
var _effect_active: bool = false
var _show_source_seal: bool = false


func _ready() -> void:
	set_process(false)
	talisman_sprite.visible = false


func setup(
	target_world_position: Vector2,
	show_talisman: bool = true
) -> void:
	if show_talisman:
		_align_to_player_combat_origin()

	_target_local = to_local(target_world_position)
	_show_source_seal = show_talisman
	_build_bolt_points()
	_elapsed = 0.0
	_effect_active = true

	talisman_sprite.visible = show_talisman
	if show_talisman:
		talisman_sprite.play("activate")

	set_process(true)
	queue_redraw()


func _align_to_player_combat_origin() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var combat_origin := player.get_node_or_null("CombatOrigin") as Node2D
	if combat_origin != null:
		global_position = combat_origin.global_position


func _build_bolt_points() -> void:
	_bolt_points.clear()
	_forks.clear()
	var length: float = _target_local.length()
	if length <= 0.001:
		return

	var direction: Vector2 = _target_local / length
	var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
	_bolt_points.append(Vector2.ZERO)

	for index in range(1, LIGHTNING_SEGMENTS):
		var ratio: float = float(index) / float(LIGHTNING_SEGMENTS)
		var alternating_sign: float = -1.0 if index % 2 == 0 else 1.0
		var amplitude: float = minf(13.0, 5.0 + length * 0.028)
		_bolt_points.append(
			_target_local * ratio
			+ perpendicular * amplitude * alternating_sign * sin(PI * ratio)
		)

	_bolt_points.append(_target_local)
	for index: int in [2, 4, 6]:
		var join: Vector2 = _bolt_points[index]
		var fork: Vector2 = perpendicular * (1.0 if index == 4 else -1.0)
		_forks.append(PackedVector2Array([join, join + direction * 7.0 + fork * 13.0,
			join + direction * 18.0 + fork * 17.0, join + direction * 25.0 + fork * 28.0]))


func _process(delta: float) -> void:
	if not _effect_active:
		return
	_elapsed += delta
	if _elapsed >= EFFECT_DURATION:
		_effect_active = false
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if not _effect_active:
		return

	var progress: float = clampf(_elapsed / EFFECT_DURATION, 0.0, 1.0)
	var remaining: float = 1.0 - progress
	var alpha: float = remaining * remaining
	var reduced: bool = Vfx.low_detail(self)

	# The actual casting origin stays distinct from the enemy impact endpoint.
	if _show_source_seal and not reduced:
		draw_arc(
			Vector2.ZERO, 12.0 + progress * 6.0, 0.0, TAU, 24,
			Color(0.56, 0.90, 1.0, 0.60 * alpha), 1.7, true
		)
		draw_arc(
			Vector2.ZERO, 18.0 + progress * 8.0, 0.0, TAU, 24,
			Color(0.56, 0.90, 1.0, 0.34 * alpha), 1.2, true
		)

	if _bolt_points.size() >= 2:
		if not reduced:
			draw_polyline(
				_bolt_points, Color(0.18, 0.52, 1.0, 0.16 * alpha),
				13.0, true
			)
		draw_polyline(
			_bolt_points, Color(0.30, 0.68, 1.0, 0.36 * alpha),
			6.5 if reduced else 7.0, true
		)
		draw_polyline(
			_bolt_points, Color(0.78, 0.96, 1.0, alpha),
			2.8, true
		)

	if not reduced:
		for fork: PackedVector2Array in _forks:
			draw_polyline(fork, Color(0.49, 0.79, 1.0, alpha * 0.64), 1.6, true)

	# The ring marks one real struck target; it is not an AoE danger indicator.
	var impact_radius: float = 8.0 * (1.0 + progress * 1.6)
	if not reduced:
		draw_arc(
			_target_local, impact_radius, 0.0, TAU, IMPACT_SEGMENTS,
			Color(0.24, 0.60, 1.0, 0.20 * alpha), 8.0, true
		)
	draw_arc(
		_target_local, impact_radius, 0.0, TAU, IMPACT_SEGMENTS,
		Color(0.62, 0.88, 1.0, 0.94 * alpha), 4.5, true
	)
	draw_circle(
		_target_local, 3.4 * remaining + 0.5,
		Color(0.92, 0.99, 1.0, 0.76 * alpha)
	)

	if not reduced:
		Vfx.curls(self, _target_local, impact_radius * 1.25, progress * 0.74,
			Color(0.71, 0.94, 1.0, alpha * 0.82), 3)
