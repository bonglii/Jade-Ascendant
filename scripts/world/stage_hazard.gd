extends Node2D

## One bounded, pause-aware telegraph and one damage event.
## 1 = Ward Seal (Chapter 1)
## 2 = Marked Lightning (Chapter 1)
## 3 = Moonbrand (Chapter 2)
## 4 = Cinnabar Burst (Chapter 2)
## 5 = Starfall Seal (Chapter 3)
## 6 = Heavenly Rift (Chapter 3)
var hazard_kind: int = 1
var accent: Color = Color(0.85, 0.73, 0.34)
var radius: float = 64.0
var warning_duration: float = 1.25
var elapsed: float = 0.0
var impacted: bool = false

func _ready() -> void:
	add_to_group("enemy_attack")
	add_to_group("stage_hazard")
	z_index = 6
	match hazard_kind:
		2:
			radius = 58.0
			warning_duration = 1.1
		3:
			radius = 66.0
			warning_duration = 1.15
		4:
			radius = 52.0
			warning_duration = 0.90
		5:
			radius = 62.0
			warning_duration = 1.05
		6:
			radius = 50.0
			warning_duration = 0.85
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if not impacted and elapsed >= warning_duration:
		impacted = true
		_apply_impact()
	if elapsed >= warning_duration + 0.22:
		queue_free()
		return
	queue_redraw()

func _apply_impact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	if global_position.distance_squared_to(player.global_position) > radius * radius:
		return
	var health: PlayerHealth = player.get_node_or_null("PlayerHealth") as PlayerHealth
	if health != null:
		health.take_damage(_get_impact_damage())

func _get_impact_damage() -> float:
	match hazard_kind:
		2:
			return 6.0
		3:
			return 7.0
		4:
			return 8.0
		5:
			return 9.0
		6:
			return 10.0
		_:
			return 5.0

func _get_warning_color() -> Color:
	match hazard_kind:
		3:
			# Pale scarlet/peach linework stays readable over dark crimson terrain.
			return Color(1.0, 0.48, 0.50, 0.95)
		4:
			return Color(1.0, 0.62, 0.34, 0.95)
		5:
			# Chapter 3 hostile astral danger is amethyst, never player cyan/jade.
			return Color(0.94, 0.58, 1.0, 0.96)
		6:
			return Color(1.0, 0.50, 0.82, 0.97)
		_:
			# Preserve Chapter 1 danger language.
			return Color(1.0, 0.71, 0.33, 0.90)

func _draw() -> void:
	var warning: Color = _get_warning_color()

	if impacted:
		var fade: float = 1.0 - clampf(
			(elapsed - warning_duration) / 0.22,
			0.0,
			1.0
		)
		draw_arc(
			Vector2.ZERO,
			radius,
			0.0,
			TAU,
			40,
			Color(accent, fade),
			5.0,
			true
		)
		match hazard_kind:
			2:
				var bolt: PackedVector2Array = PackedVector2Array([
					Vector2(-8, -160),
					Vector2(11, -116),
					Vector2(-12, -72),
					Vector2(7, -36),
					Vector2.ZERO
				])
				draw_polyline(bolt, Color(0.9, 0.97, 1.0, fade), 5.0, true)
			3:
				draw_circle(Vector2.ZERO, radius * 0.78, Color(accent, fade * 0.18))
				draw_arc(
					Vector2(-8.0, 0.0), radius * 0.46, -1.15, 1.15, 24,
					Color(1.0, 0.70, 0.72, fade), 4.0, true
				)
				draw_line(
					Vector2(-32.0, 28.0), Vector2(30.0, -30.0),
					Color(1.0, 0.68, 0.58, fade), 4.0, true
				)
			4:
				draw_circle(Vector2.ZERO, radius * 0.72, Color(accent, fade * 0.20))
				for index: int in range(4):
					var direction: Vector2 = Vector2.RIGHT.rotated(PI * 0.5 * index)
					draw_line(
						direction * radius * 0.80,
						direction * radius * 0.18,
						Color(1.0, 0.77, 0.48, fade),
						4.0,
						true
					)
			5:
				draw_circle(Vector2.ZERO, radius * 0.72, Color(0.54, 0.28, 0.82, fade * 0.20))
				for index: int in range(8):
					var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
					var length: float = radius * (0.92 if index % 2 == 0 else 0.62)
					draw_line(
						direction * radius * 0.12,
						direction * length,
						Color(1.0, 0.86, 0.50, fade),
						3.5,
						true
					)
			6:
				draw_circle(Vector2.ZERO, radius * 0.70, Color(0.72, 0.18, 0.62, fade * 0.18))
				var fracture: PackedVector2Array = PackedVector2Array([
					Vector2(-radius * 0.22, -radius * 1.30),
					Vector2(radius * 0.08, -radius * 0.48),
					Vector2(-radius * 0.12, -radius * 0.08),
					Vector2(radius * 0.18, radius * 0.38),
					Vector2(-radius * 0.08, radius * 1.25),
				])
				draw_polyline(fracture, Color(1.0, 0.72, 0.48, fade), 5.0, true)
			_:
				draw_circle(Vector2.ZERO, radius * 0.8, Color(accent, fade * 0.22))
		return

	var progress: float = clampf(elapsed / warning_duration, 0.0, 1.0)

	var fill_color: Color = Color(0.8, 0.35, 0.15, 0.08)
	if hazard_kind == 3:
		fill_color = Color(0.66, 0.05, 0.12, 0.10)
	elif hazard_kind == 4:
		fill_color = Color(0.72, 0.18, 0.06, 0.09)
	elif hazard_kind == 5:
		fill_color = Color(0.38, 0.16, 0.62, 0.10)
	elif hazard_kind == 6:
		fill_color = Color(0.52, 0.08, 0.38, 0.10)

	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, warning, 2.0, true)
	draw_arc(
		Vector2.ZERO,
		radius + 24.0 * (1.0 - progress),
		0.0,
		TAU,
		40,
		warning,
		1.5,
		true
	)

	for index: int in range(4):
		var direction: Vector2 = Vector2.RIGHT.rotated(PI * 0.5 * index)
		var edge: Vector2 = direction * radius
		draw_line(edge - direction * 9.0, edge + direction * 5.0, warning, 3.0, true)

	match hazard_kind:
		2:
			draw_polyline(
				PackedVector2Array([
					Vector2(4, -17), Vector2(-7, 1), Vector2(5, 1), Vector2(-4, 17)
				]),
				warning,
				3.0,
				true
			)
		3:
			draw_arc(Vector2(-4.0, 0.0), 19.0, -1.20, 1.20, 18, warning, 2.5, true)
			draw_line(Vector2(-12.0, 12.0), Vector2(13.0, -13.0), warning, 2.0, true)
		4:
			var diamond: PackedVector2Array = PackedVector2Array([
				Vector2(0, -18), Vector2(18, 0), Vector2(0, 18),
				Vector2(-18, 0), Vector2(0, -18)
			])
			draw_polyline(diamond, warning, 2.0, true)
			for index: int in range(4):
				var direction: Vector2 = Vector2.RIGHT.rotated(PI * 0.5 * index)
				draw_line(direction * 18.0, direction * 6.0, warning, 2.0, true)
		5:
			var star: PackedVector2Array = PackedVector2Array()
			for index: int in range(10):
				var angle: float = -PI * 0.5 + TAU * float(index) / 10.0
				var star_radius: float = 19.0 if index % 2 == 0 else 8.0
				star.append(Vector2.RIGHT.rotated(angle) * star_radius)
			star.append(star[0])
			draw_polyline(star, warning, 2.2, true)
			draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.84, 0.46, 0.92))
		6:
			var rift: PackedVector2Array = PackedVector2Array([
				Vector2(-7, -22), Vector2(3, -9), Vector2(-5, 0),
				Vector2(6, 9), Vector2(-4, 22)
			])
			draw_polyline(rift, warning, 3.0, true)
			draw_line(Vector2(-18, -4), Vector2(-5, 0), warning, 1.8, true)
			draw_line(Vector2(6, 9), Vector2(19, 15), warning, 1.8, true)
		_:
			var seal: PackedVector2Array = PackedVector2Array([
				Vector2(0, -19), Vector2(19, 0), Vector2(0, 19),
				Vector2(-19, 0), Vector2(0, -19)
			])
			draw_polyline(seal, warning, 2.0, true)
			draw_line(Vector2(-10, 0), Vector2(10, 0), warning, 2.0, true)
