extends Area2D
class_name QiExplosion

## Qi Explosion
## Area serangan milik Qi Caster.
##
## Semantic VFX:
## - Telegraph menunjukkan radius bahaya SEBELUM damage.
## - Active impact selalu terlihat ketika damage window terjadi,
##   baik Player terkena maupun berhasil dodge.
## - Tidak ada permanent area marker setelah serangan selesai.
##
## Gameplay values tetap sama.

const TELEGRAPH_SEGMENTS: int = 48
const IMPACT_VISUAL_DURATION: float = 0.18

const VERDANT_TELEGRAPH_FILL := Color(0.18, 0.88, 0.82, 0.12)
const CRIMSON_TELEGRAPH_FILL := Color(0.88, 0.16, 0.18, 0.14)
const VERDANT_TELEGRAPH_EDGE := Color(0.40, 1.0, 0.88, 0.72)
const CRIMSON_TELEGRAPH_EDGE := Color(1.0, 0.34, 0.30, 0.78)
const VERDANT_TELEGRAPH_INNER := Color(0.56, 1.0, 0.92, 0.34)
const CRIMSON_TELEGRAPH_INNER := Color(1.0, 0.52, 0.34, 0.38)
const VERDANT_IMPACT_FLASH := Color(0.58, 1.0, 0.84, 0.72)
const CRIMSON_IMPACT_FLASH := Color(1.0, 0.40, 0.28, 0.76)
const VERDANT_IMPACT_RING := Color(0.42, 1.0, 0.78, 0.95)
const CRIMSON_IMPACT_RING := Color(1.0, 0.24, 0.24, 0.96)
const VERDANT_IMPACT_STREAK := Color(0.72, 1.0, 0.88, 0.90)
const CRIMSON_IMPACT_STREAK := Color(1.0, 0.68, 0.36, 0.92)
const NINE_HEAVENS_TELEGRAPH_FILL := Color(0.48, 0.34, 0.86, 0.13)
const NINE_HEAVENS_TELEGRAPH_EDGE := Color(0.88, 0.76, 0.98, 0.78)
const NINE_HEAVENS_TELEGRAPH_INNER := Color(0.96, 0.82, 0.50, 0.42)
const NINE_HEAVENS_IMPACT_FLASH := Color(0.84, 0.72, 1.0, 0.76)
const NINE_HEAVENS_IMPACT_RING := Color(0.96, 0.84, 0.50, 0.96)
const NINE_HEAVENS_IMPACT_STREAK := Color(0.76, 0.60, 1.0, 0.92)

@export var explosion_radius: float = 42.0
@export var telegraph_duration: float = 0.8
@export var base_damage: float = 6.0

var has_impacted: bool = false
var telegraph_outline: Line2D = null
var telegraph_inner_ring: Line2D = null
var presentation_theme: StringName = &"verdant_qi"

@onready var telegraph_visual: Polygon2D = (
	get_node_or_null("TelegraphVisual")
)

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)

func _presentation_color(
	verdant: Color,
	crimson: Color,
	nine_heavens: Color
) -> Color:
	if presentation_theme == &"crimson_moon":
		return crimson
	if presentation_theme == &"nine_heavens":
		return nine_heavens
	return verdant

func _ready() -> void:
	add_to_group("enemy_attack")

	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false

	setup_collision_radius()
	create_telegraph_visual()

	await get_tree().create_timer(
		telegraph_duration,
		false
	).timeout

	if not is_inside_tree():
		return

	impact()

## Menyesuaikan collision radius dengan radius explosion.
func setup_collision_radius() -> void:
	if collision_shape == null:
		push_error(
			"Qi Explosion tidak menemukan CollisionShape2D."
		)
		return

	var source_shape := (
		collision_shape.shape
		as CircleShape2D
	)

	if source_shape == null:
		push_error(
			"Qi Explosion membutuhkan CircleShape2D."
		)
		return

	var circle_shape := (
		source_shape.duplicate()
		as CircleShape2D
	)

	if circle_shape == null:
		push_error(
			"CircleShape2D Qi Explosion gagal diduplikasi."
		)
		return

	collision_shape.shape = circle_shape
	circle_shape.radius = explosion_radius

## Membuat points lingkaran tertutup untuk Line2D.
func create_ring_points(
	radius: float,
	segment_count: int = TELEGRAPH_SEGMENTS
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
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	return points

## Telegraph = area fill tipis + outline radius gameplay.
func create_telegraph_visual() -> void:
	if telegraph_visual == null:
		push_error(
			"Qi Explosion tidak menemukan TelegraphVisual."
		)
		return

	var polygon_points := PackedVector2Array()

	for index in range(TELEGRAPH_SEGMENTS):
		var angle: float = (
			TAU
			* float(index)
			/ float(TELEGRAPH_SEGMENTS)
		)

		polygon_points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * explosion_radius
		)

	telegraph_visual.polygon = polygon_points
	telegraph_visual.z_index = 1

	## Danger area mengikuti hostile chapter theme; fill tetap tipis
	## supaya tidak menutupi karakter/pickup di bawahnya.
	telegraph_visual.color = _presentation_color(
		VERDANT_TELEGRAPH_FILL,
		CRIMSON_TELEGRAPH_FILL,
		NINE_HEAVENS_TELEGRAPH_FILL
	)

	telegraph_outline = Line2D.new()
	telegraph_outline.z_index = 6
	telegraph_outline.width = 2.2
	telegraph_outline.default_color = _presentation_color(
		VERDANT_TELEGRAPH_EDGE,
		CRIMSON_TELEGRAPH_EDGE,
		NINE_HEAVENS_TELEGRAPH_EDGE
	)
	telegraph_outline.antialiased = true
	telegraph_outline.points = create_ring_points(
		explosion_radius
	)
	add_child(telegraph_outline)

	telegraph_inner_ring = Line2D.new()
	telegraph_inner_ring.z_index = 5
	telegraph_inner_ring.width = 1.2
	telegraph_inner_ring.default_color = _presentation_color(
		VERDANT_TELEGRAPH_INNER,
		CRIMSON_TELEGRAPH_INNER,
		NINE_HEAVENS_TELEGRAPH_INNER
	)
	telegraph_inner_ring.antialiased = true
	telegraph_inner_ring.points = create_ring_points(
		explosion_radius * 0.52
	)
	add_child(telegraph_inner_ring)

## Telegraph selesai -> active burst + damage.
func impact() -> void:
	if has_impacted:
		return

	has_impacted = true

	hide_telegraph()
	create_impact_visual()
	apply_damage_to_player()

	await get_tree().create_timer(
		IMPACT_VISUAL_DURATION,
		false
	).timeout

	if is_inside_tree():
		queue_free()

## Menghilangkan seluruh danger telegraph tepat saat active window dimulai.
func hide_telegraph() -> void:
	if telegraph_visual != null:
		telegraph_visual.visible = false

	if telegraph_outline != null:
		telegraph_outline.visible = false

	if telegraph_inner_ring != null:
		telegraph_inner_ring.visible = false

## Active impact:
## flash di pusat + ring jade yang mengembang hingga gameplay radius.
func create_impact_visual() -> void:
	var flash := Polygon2D.new()
	flash.z_index = 6
	var flash_points := PackedVector2Array()

	var flash_radius: float = minf(
		explosion_radius * 0.42,
		20.0
	)

	for index in range(32):
		var angle: float = (
			TAU
			* float(index)
			/ 32.0
		)

		flash_points.append(
			Vector2.RIGHT.rotated(angle)
			* flash_radius
		)

	flash.polygon = flash_points
	flash.color = _presentation_color(
		VERDANT_IMPACT_FLASH,
		CRIMSON_IMPACT_FLASH,
		NINE_HEAVENS_IMPACT_FLASH
	)
	add_child(flash)

	var impact_ring := Line2D.new()
	impact_ring.z_index = 6
	impact_ring.width = 5.0
	impact_ring.default_color = _presentation_color(
		VERDANT_IMPACT_RING,
		CRIMSON_IMPACT_RING,
		NINE_HEAVENS_IMPACT_RING
	)
	impact_ring.antialiased = true

	var start_radius: float = maxf(
		explosion_radius * 0.32,
		8.0
	)

	impact_ring.points = create_ring_points(
		start_radius,
		36
	)

	add_child(impact_ring)

	## Empat jade streak kecil memberi rasa "formation burst"
	## tanpa menambahkan hitbox/mechanic baru.
	for direction in [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN
	]:
		var streak := Line2D.new()
		streak.z_index = 6
		streak.width = 2.0
		streak.default_color = _presentation_color(
			VERDANT_IMPACT_STREAK,
			CRIMSON_IMPACT_STREAK,
			NINE_HEAVENS_IMPACT_STREAK
		)
		streak.antialiased = true
		streak.points = PackedVector2Array([
			direction * 6.0,
			direction * minf(
				explosion_radius * 0.78,
				34.0
			)
		])
		add_child(streak)

		var streak_tween := create_tween()
		streak_tween.tween_property(
			streak,
			"modulate:a",
			0.0,
			IMPACT_VISUAL_DURATION
		)

	var target_scale: float = (
		explosion_radius
		/ start_radius
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		impact_ring,
		"scale",
		Vector2.ONE * target_scale,
		IMPACT_VISUAL_DURATION
	)

	tween.tween_property(
		impact_ring,
		"modulate:a",
		0.0,
		IMPACT_VISUAL_DURATION
	)

	tween.tween_property(
		flash,
		"modulate:a",
		0.0,
		IMPACT_VISUAL_DURATION
	)

## Memberikan damage jika Player masih berada di dalam radius explosion.
func apply_damage_to_player() -> void:
	var player := get_tree().get_first_node_in_group(
		"player"
	)

	if player == null:
		return

	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	if distance_to_player > explosion_radius:
		DebugLogger.combat(
			"Qi Explosion Dodged | Distance: %.1f"
			% distance_to_player
		)
		return

	var player_health: PlayerHealth = (
		player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)

	if player_health == null:
		push_error(
			"Qi Explosion tidak menemukan PlayerHealth."
		)
		return

	player_health.take_damage(
		base_damage
	)

	DebugLogger.combat(
		"Qi Explosion Hit | Damage: %.1f | Distance: %.1f"
		% [
			base_damage,
			distance_to_player
		]
	)
