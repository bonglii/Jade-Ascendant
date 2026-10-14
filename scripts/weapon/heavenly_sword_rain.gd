extends Area2D
class_name HeavenlySwordRain

signal successful_impact(
	impact_position: Vector2,
	base_damage: float
)

const DEFAULT_TELEGRAPH_DURATION: float = 0.35
const DEFAULT_ACTIVE_DURATION: float = 0.12
const VFX_SEGMENTS: int = 40
const IMPACT_VISUAL_DURATION: float = 0.26
const CelArt = preload("res://scripts/effects/combat_cel_art.gd")

const SWORD_START_Y: float = -76.0
const SWORD_IMPACT_Y: float = -6.0

var strike_damage: float = 0.0
var strike_radius: float = 32.0
var telegraph_duration: float = DEFAULT_TELEGRAPH_DURATION
var active_duration: float = DEFAULT_ACTIVE_DURATION
var player_stats: Node = null
var has_impacted: bool = false
var _impact_visual_elapsed: float = 0.0

var telegraph_ring: Line2D = null
var middle_ring: Line2D = null
var inner_marker: Line2D = null
var descent_glow: Line2D = null

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)
@onready var sword_sprite: Sprite2D = (
	get_node_or_null("Sprite2D")
)


func _ready() -> void:
	preload("res://scripts/effects/skill_instance_polish.gd").install(self, "heavenly_sword_rain")
	z_index = 2
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	set_process(false)

	apply_strike_radius()
	create_telegraph_visual()

	await get_tree().create_timer(
		telegraph_duration,
		false
	).timeout

	impact()

	await get_tree().create_timer(
		active_duration,
		false
	).timeout

	monitoring = false
	await get_tree().create_timer(maxf(IMPACT_VISUAL_DURATION - active_duration, 0.001),false).timeout
	queue_free()


func setup(
	damage: float,
	radius: float,
	stats: Node
) -> void:
	strike_damage = damage
	strike_radius = radius
	player_stats = stats


func apply_strike_radius() -> void:
	if collision_shape == null:
		push_error(
			"CollisionShape2D tidak ditemukan pada Heavenly Sword Rain."
		)
		return

	var source_shape := (
		collision_shape.shape
		as CircleShape2D
	)
	if source_shape == null:
		push_error(
			"Heavenly Sword Rain membutuhkan CircleShape2D."
		)
		return

	var circle_shape := (
		source_shape.duplicate()
		as CircleShape2D
	)
	if circle_shape == null:
		push_error(
			"CircleShape2D Heavenly Sword Rain gagal diduplikasi."
		)
		return

	collision_shape.shape = circle_shape
	circle_shape.radius = strike_radius


func create_ring_points(
	ring_radius: float,
	segment_count: int = VFX_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segment_count: int = max(
		segment_count,
		3
	)

	for index in range(safe_segment_count + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(safe_segment_count)
		)
		points.append(
			Vector2.RIGHT.rotated(angle)
			* ring_radius
		)

	return points


func _make_line(
	points: PackedVector2Array,
	width: float,
	color: Color
) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.points = points
	add_child(line)
	return line


func create_telegraph_visual() -> void:
	# Outer ring is EXACT gameplay radius: no false telegraph.
	telegraph_ring = _make_line(
		create_ring_points(strike_radius),
		2.6,
		Color(0.66, 0.90, 1.0, 0.74)
	)
	middle_ring = _make_line(
		create_ring_points(strike_radius * 0.70),
		1.5,
		Color(0.80, 0.95, 1.0, 0.46)
	)
	inner_marker = _make_line(
		create_ring_points(strike_radius * 0.34),
		1.2,
		Color(0.92, 0.99, 1.0, 0.42)
	)

	var tween := create_tween()
	tween.set_parallel(true)

	for ring in [
		telegraph_ring,
		middle_ring,
		inner_marker
	]:
		tween.tween_property(
			ring,
			"scale",
			Vector2.ONE,
			telegraph_duration
		)

	if sword_sprite != null:
		sword_sprite.texture = CelArt.frame("blades",0)
		sword_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var target_scale: Vector2 = Vector2(.32,.38)

		sword_sprite.position.y = SWORD_START_Y
		sword_sprite.scale = target_scale * 0.78
		sword_sprite.modulate.a = 0.22

		tween.tween_property(
			sword_sprite,
			"position:y",
			SWORD_IMPACT_Y,
			telegraph_duration
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN
		)
		tween.tween_property(
			sword_sprite,
			"scale",
			target_scale * 1.06,
			telegraph_duration
		)
		tween.tween_property(
			sword_sprite,
			"modulate:a",
			1.0,
			telegraph_duration
		)


func hide_telegraph_visual() -> void:
	for line in [
		telegraph_ring,
		middle_ring,
		inner_marker,
		descent_glow
	]:
		if line != null:
			line.visible = false


func create_impact_visual() -> void:
	# The impact is a single bounded CanvasItem drawing; no per-hit Line2Ds.
	# Radius never exceeds strike_radius / the actual CircleShape2D hit area.
	_impact_visual_elapsed = 0.0
	set_process(true)
	queue_redraw()

	if sword_sprite != null:
		var fade := create_tween()
		fade.tween_property(
			sword_sprite, "modulate:a", 0.0, IMPACT_VISUAL_DURATION
		)


func _process(delta: float) -> void:
	if not has_impacted:
		return
	_impact_visual_elapsed += delta
	queue_redraw()
	if _impact_visual_elapsed >= IMPACT_VISUAL_DURATION:
		set_process(false)


func _draw() -> void:
	if not has_impacted: return
	var t: float = clampf(_impact_visual_elapsed / IMPACT_VISUAL_DURATION,0,1)
	var fade: float = pow(1.0-t,1.6)
	var reduced: bool = SettingsManager.reduced_effects
	CelArt.paint(self,"impacts",4,Vector2.ZERO,Vector2.ONE*strike_radius*lerpf(1.15,2.0,1.0-pow(1.0-t,2)),0,fade)
	if not reduced:
		CelArt.paint(self,"blades",3,Vector2.ZERO,Vector2.ONE*strike_radius*1.75,t*.22,fade*.72)
	# Single true-radius boundary; the painted plume is purely vertical debris.
	draw_arc(Vector2.ZERO,strike_radius*lerpf(.4,1,t),0,TAU,40,Color(.62,.9,1,fade*.60),1.2,true)


func impact() -> void:
	if has_impacted:
		return

	has_impacted = true
	AudioManager.play_sfx("sword")

	hide_telegraph_visual()
	create_impact_visual()

	if player_stats == null:
		return

	var hit_successful: bool = false

	for body in get_overlapping_bodies():
		if damage_target(body):
			hit_successful = true

	if hit_successful:
		successful_impact.emit(
			global_position,
			strike_damage
		)


func damage_target(target: Node) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false

	var final_damage: float = (
		player_stats.calculate_damage(
			strike_damage
		)
	)

	var applied: float = preload("res://scripts/weapon/run_combat_ledger.gd").apply_hit(target,final_damage,"heavenly_sword_rain")

	DebugLogger.combat(
		"Heavenly Sword Rain Hit | Damage: %.1f"
		% final_damage
	)

	return applied > 0.0
