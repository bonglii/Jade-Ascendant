extends Area2D
class_name LightningStrike

## Lightning Strike
## Serangan area milik Storm Cultivator.
## Telegraph muncul pada posisi Player yang telah dikunci,
## lalu sambaran petir memberikan satu kali AoE damage.
##
## 14.4D.2 hierarchy rule:
## Hostile Storm Cultivator lightning uses violet/indigo language,
## separated from Lin Yue / Thunder Talisman cyan.
##
## Telegraph boundary follows the REAL strike radius.
## No decorative danger circle is added.

const TELEGRAPH_SEGMENTS: int = 48

const STORM_TELEGRAPH_FILL := Color(
	0.42,
	0.20,
	0.78,
	0.24
)

const STORM_TELEGRAPH_EDGE := Color(
	0.78,
	0.62,
	1.0,
	0.88
)

const STORM_BOLT_GLOW := Color(
	0.50,
	0.30,
	0.92,
	0.30
)

const STORM_BOLT_CORE := Color(
	0.90,
	0.82,
	1.0,
	1.0
)

const STORM_IMPACT := Color(
	0.68,
	0.44,
	1.0,
	0.72
)

const CRIMSON_TELEGRAPH_FILL := Color(0.82, 0.12, 0.18, 0.24)
const CRIMSON_TELEGRAPH_EDGE := Color(1.0, 0.35, 0.32, 0.90)
const CRIMSON_BOLT_GLOW := Color(0.95, 0.18, 0.22, 0.34)
const CRIMSON_BOLT_CORE := Color(1.0, 0.78, 0.54, 1.0)
const CRIMSON_IMPACT := Color(1.0, 0.30, 0.28, 0.76)
const NINE_HEAVENS_TELEGRAPH_FILL := Color(0.50, 0.30, 0.88, 0.20)
const NINE_HEAVENS_TELEGRAPH_EDGE := Color(0.92, 0.82, 0.46, 0.92)
const NINE_HEAVENS_BOLT_GLOW := Color(0.62, 0.38, 0.94, 0.34)
const NINE_HEAVENS_BOLT_CORE := Color(0.98, 0.92, 0.70, 1.0)
const NINE_HEAVENS_IMPACT := Color(0.76, 0.56, 1.0, 0.78)

@export var strike_radius: float = 55.0
@export var telegraph_duration: float = 0.75
@export var base_damage: float = 10.0

var has_impacted: bool = false
var telegraph_outline: Line2D = null
var presentation_theme: StringName = &"storm"

@onready var telegraph_visual: Polygon2D = (
	get_node_or_null("TelegraphVisual")
)

@onready var collision_shape: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
)

func _presentation_color(
	storm: Color,
	crimson: Color,
	nine_heavens: Color
) -> Color:
	if presentation_theme == &"crimson_moon":
		return crimson
	if presentation_theme == &"nine_heavens":
		return nine_heavens
	return storm

func _ready() -> void:
	add_to_group("enemy_attack")

	collision_layer = 0
	collision_mask = 0
	monitoring = false

	setup_collision_radius()
	create_telegraph_visual()

	await get_tree().create_timer(
		telegraph_duration,
		false
	).timeout

	if not is_inside_tree():
		return

	impact()

## Menyesuaikan CircleShape2D dengan radius Lightning Strike.
func setup_collision_radius() -> void:
	if collision_shape == null:
		push_error(
			"Lightning Strike tidak menemukan CollisionShape2D."
		)
		return

	var source_shape := (
		collision_shape.shape
		as CircleShape2D
	)

	if source_shape == null:
		push_error(
			"Lightning Strike membutuhkan CircleShape2D."
		)
		return

	var circle_shape := (
		source_shape.duplicate()
		as CircleShape2D
	)

	if circle_shape == null:
		push_error(
			"CircleShape2D Lightning Strike gagal diduplikasi."
		)
		return

	collision_shape.shape = circle_shape
	circle_shape.radius = strike_radius

## Telegraph = fill + exact-radius edge.
## Keduanya memiliki arti gameplay nyata.
func create_telegraph_visual() -> void:
	if telegraph_visual == null:
		push_error(
			"Lightning Strike tidak menemukan TelegraphVisual."
		)
		return

	var polygon_points := PackedVector2Array()
	var outline_points := PackedVector2Array()

	for index in range(TELEGRAPH_SEGMENTS):
		var angle: float = (
			TAU
			* float(index)
			/ float(TELEGRAPH_SEGMENTS)
		)

		var point := (
			Vector2.RIGHT.rotated(angle)
			* strike_radius
		)

		polygon_points.append(point)
		outline_points.append(point)

	## Close Line2D loop.
	if not outline_points.is_empty():
		outline_points.append(
			outline_points[0]
		)

	telegraph_visual.polygon = polygon_points
	telegraph_visual.z_index = 1
	telegraph_visual.color = _presentation_color(
		STORM_TELEGRAPH_FILL,
		CRIMSON_TELEGRAPH_FILL,
		NINE_HEAVENS_TELEGRAPH_FILL
	)

	telegraph_outline = Line2D.new()
	telegraph_outline.z_index = 6
	telegraph_outline.width = 2.5
	telegraph_outline.default_color = _presentation_color(
		STORM_TELEGRAPH_EDGE,
		CRIMSON_TELEGRAPH_EDGE,
		NINE_HEAVENS_TELEGRAPH_EDGE
	)
	telegraph_outline.antialiased = true
	telegraph_outline.points = outline_points
	add_child(telegraph_outline)

	## Restrained warning pulse during the real telegraph window.
	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(
		telegraph_outline,
		"modulate:a",
		0.50,
		telegraph_duration * 0.25
	)
	pulse.tween_property(
		telegraph_outline,
		"modulate:a",
		1.0,
		telegraph_duration * 0.25
	)

## Menyelesaikan telegraph dan menjalankan satu kali impact.
func impact() -> void:
	if has_impacted:
		return

	has_impacted = true

	if telegraph_visual != null:
		telegraph_visual.visible = false

	if (
		telegraph_outline != null
		and is_instance_valid(telegraph_outline)
	):
		telegraph_outline.visible = false

	create_impact_visual()
	apply_damage_to_player()

	await get_tree().create_timer(
		0.14,
		false
	).timeout

	if is_inside_tree():
		queue_free()

## Hostile violet storm bolt + active impact.
## Presentation-only; timing/radius/damage are unchanged.
func create_impact_visual() -> void:
	var bolt_points := PackedVector2Array([
		Vector2(-7.0, -120.0),
		Vector2(6.0, -95.0),
		Vector2(-5.0, -70.0),
		Vector2(7.0, -46.0),
		Vector2(-3.0, -22.0),
		Vector2.ZERO
	])

	var glow := Line2D.new()
	glow.z_index = 6
	glow.width = 10.0
	glow.default_color = _presentation_color(
		STORM_BOLT_GLOW,
		CRIMSON_BOLT_GLOW,
		NINE_HEAVENS_BOLT_GLOW
	)
	glow.antialiased = true
	glow.points = bolt_points
	add_child(glow)

	var bolt := Line2D.new()
	bolt.z_index = 6
	bolt.width = 4.5
	bolt.default_color = _presentation_color(
		STORM_BOLT_CORE,
		CRIMSON_BOLT_CORE,
		NINE_HEAVENS_BOLT_CORE
	)
	bolt.antialiased = true
	bolt.points = bolt_points
	add_child(bolt)

	var flash := Polygon2D.new()
	flash.z_index = 6
	var flash_points := PackedVector2Array()
	var segment_count: int = 32
	var flash_radius: float = minf(
		strike_radius,
		24.0
	)

	for index in range(segment_count):
		var angle: float = (
			TAU
			* float(index)
			/ float(segment_count)
		)

		flash_points.append(
			Vector2.RIGHT.rotated(angle)
			* flash_radius
		)

	flash.polygon = flash_points
	flash.color = _presentation_color(
		STORM_IMPACT,
		CRIMSON_IMPACT,
		NINE_HEAVENS_IMPACT
	)
	add_child(flash)

	var impact_ring := Line2D.new()
	impact_ring.z_index = 6
	impact_ring.width = 3.0
	impact_ring.default_color = _presentation_color(
		STORM_TELEGRAPH_EDGE,
		CRIMSON_TELEGRAPH_EDGE,
		NINE_HEAVENS_TELEGRAPH_EDGE
	)
	impact_ring.antialiased = true

	var ring_points := PackedVector2Array()

	for index in range(33):
		var angle: float = (
			TAU
			* float(index)
			/ 32.0
		)

		ring_points.append(
			Vector2.RIGHT.rotated(angle)
			* minf(
				strike_radius,
				28.0
			)
		)

	impact_ring.points = ring_points
	add_child(impact_ring)

	var tween := create_tween()
	tween.set_parallel(true)

	for node in [
		glow,
		bolt,
		flash,
		impact_ring
	]:
		tween.tween_property(
			node,
			"modulate:a",
			0.0,
			0.14
		)

	tween.tween_property(
		impact_ring,
		"scale",
		Vector2.ONE * 1.65,
		0.14
	)

## Memberikan damage jika Player masih berada dalam radius sambaran.
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

	if distance_to_player > strike_radius:
		DebugLogger.combat(
			"Lightning Strike Dodged | Distance: %.1f"
			% distance_to_player
		)
		return

	var player_health: PlayerHealth = (
		player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)

	if player_health == null:
		push_error(
			"Lightning Strike tidak menemukan PlayerHealth."
		)
		return

	player_health.take_damage(
		base_damage
	)

	DebugLogger.combat(
		"Lightning Strike Hit | Damage: %.1f | Distance: %.1f"
		% [
			base_damage,
			distance_to_player
		]
	)
