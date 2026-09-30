extends Node2D

## Gate B: bounded world-space telegraphs for Frostveil Abyss / Solar Nirvana.
## Drawn only during an attack, no GPU particles, one damage event, pause-aware.
## Geometry and damage use the same snapshot; movement is the counterplay.

var pattern: String = "frost_mark"
var aim: Vector2 = Vector2.RIGHT
var damage: float = 8.0
var warning_duration: float = 1.22
var is_stage_hazard: bool = false

var _elapsed: float = 0.0
var _impacted: bool = false
var _redraw_elapsed: float = 0.0

const FROST: Color = Color(0.55, 0.90, 1.0, 1.0)
const SOLAR: Color = Color(1.0, 0.75, 0.38, 1.0)
const MAX_LIFETIME_AFTER_IMPACT: float = 0.20

# Production FX stamps augment, but NEVER replace, the geometric hit tests.
const FROST_SEAL: Texture2D = preload("res://assets/vfx/realm/frost_sigil.png")
const SOLAR_SEAL: Texture2D = preload("res://assets/vfx/realm/solar_sigil.png")
const FROST_IMPACT: Texture2D = preload("res://assets/vfx/realm/frost_impact.png")
const SOLAR_IMPACT: Texture2D = preload("res://assets/vfx/realm/solar_impact.png")

func _ready() -> void:
	add_to_group("enemy_attack")
	if is_stage_hazard:
		add_to_group("stage_hazard")
	z_index = 7
	# Cast direction is determined once, not re-aimed onto the player.
	if aim.length_squared() < 0.001:
		aim = Vector2.RIGHT
	else:
		aim = aim.normalized()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if not _impacted and _elapsed >= warning_duration:
		_impacted = true
		_apply_impact()
		queue_redraw()
	if _elapsed >= warning_duration + MAX_LIFETIME_AFTER_IMPACT:
		queue_free()
		return
	# All ten stage boss spells share this class. Throttle redraws instead of
	# asking the renderer to rebuild up to ten ornate shapes at 60 Hz.
	_redraw_elapsed += delta
	var interval: float = 0.12 if SettingsManager.reduced_effects else 0.050
	if _redraw_elapsed >= interval:
		_redraw_elapsed = 0.0
		queue_redraw()

func _apply_impact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	if not contains_world_point(player.global_position):
		return
	var health: PlayerHealth = player.get_node_or_null("PlayerHealth") as PlayerHealth
	if health != null:
		health.take_damage(damage)

## Pure hit test also serves deterministic QA for telegraph shape/radius.
func contains_world_point(world_point: Vector2) -> bool:
	var local_point: Vector2 = to_local(world_point)
	var longitudinal: float = local_point.dot(aim)
	var transverse: float = absf(local_point.cross(aim))
	var distance: float = local_point.length()
	match pattern:
		"frost_lance":
			return longitudinal >= 0.0 and longitudinal <= 410.0 and transverse <= 32.0
		"mirror_gate":
			return longitudinal >= 0.0 and longitudinal <= 385.0 and absf(transverse - 78.0) <= 26.0
		"frost_ring":
			return distance >= 95.0 and distance <= 180.0
		"frost_mark":
			return distance <= 76.0
		"solar_lance":
			return longitudinal >= 0.0 and longitudinal <= 445.0 and transverse <= 40.0
		"solar_fan":
			return longitudinal >= 0.0 and distance <= 260.0 and transverse <= longitudinal * 0.42
		"solar_ring":
			return distance >= 105.0 and distance <= 192.0
		"ember_mark":
			return distance <= 85.0
		"frost_fork":
			return _in_fork(local_point, 0.35, 375.0, 27.0)
		"mirror_cross":
			return _in_fork(local_point, PI / 4.0, 395.0, 25.0)
		"lotus_bloom":
			return _in_spokes(local_point, 6, 40.0, 186.0, 0.23)
		"bell_toll":
			return _in_rings(distance, [64.0, 130.0, 198.0], 16.0)
		"frost_crown":
			return _in_spokes(local_point, 8, 46.0, 260.0, 0.12)
		"sun_pillar":
			return _in_chain(local_point, [85.0, 185.0, 285.0], 46.0)
		"forge_cross":
			return (absf(longitudinal) <= 265.0 and transverse <= 31.0) or (absf(longitudinal) <= 31.0 and transverse <= 265.0)
		"phoenix_wings":
			var angle_value: float = absf(wrapf(local_point.angle() - aim.angle(), -PI, PI))
			return distance <= 265.0 and angle_value >= 0.20 and angle_value <= 0.56
		"eclipse_wheel":
			var angle_value: float = absf(wrapf(local_point.angle() - aim.angle(), -PI * 0.25, PI * 0.25))
			return distance >= 100.0 and distance <= 205.0 and angle_value > 0.17
		"nine_suns":
			return _in_solar_orbs(local_point)
	return false


func _in_fork(point: Vector2, angle_value: float, reach: float, width_v: float) -> bool:
	for sign_value: float in [-1.0, 1.0]:
		var direction: Vector2 = aim.rotated(sign_value * angle_value)
		var forward: float = point.dot(direction)
		if forward >= 0.0 and forward <= reach and absf(point.cross(direction)) <= width_v:
			return true
	return false


func _in_rings(distance_value: float, radii: Array, half_width: float) -> bool:
	for radius_value: Variant in radii:
		if absf(distance_value - float(radius_value)) <= half_width:
			return true
	return false


func _in_spokes(point: Vector2, spoke_count: int, min_radius: float, max_radius: float, half_angle: float) -> bool:
	var r: float = point.length()
	if r < min_radius or r > max_radius:
		return false
	var sector: float = TAU / float(spoke_count)
	var deviation: float = absf(wrapf(point.angle() - aim.angle(), -sector * 0.5, sector * 0.5))
	return deviation <= half_angle


func _in_chain(point: Vector2, distances: Array, mark_radius: float) -> bool:
	for d: Variant in distances:
		if point.distance_squared_to(aim * float(d)) <= mark_radius * mark_radius:
			return true
	return false


func _in_solar_orbs(point: Vector2) -> bool:
	for idx: int in range(9):
		var center: Vector2 = aim.rotated(float(idx) * TAU / 9.0) * 154.0
		if point.distance_squared_to(center) <= 42.0 * 42.0:
			return true
	return false

func _draw() -> void:
	var gold_family: bool = pattern.begins_with("solar") or pattern in ["ember_mark", "sun_pillar", "forge_cross", "phoenix_wings", "eclipse_wheel", "nine_suns"]
	var accent: Color = SOLAR if gold_family else FROST
	var progress: float = clampf(_elapsed / maxf(warning_duration, 0.01), 0.0, 1.0)
	var alpha: float = 0.24 + progress * 0.21
	if _impacted:
		alpha = 0.65 * (1.0 - clampf((_elapsed - warning_duration) / MAX_LIFETIME_AFTER_IMPACT, 0.0, 1.0))
	var fill: Color = Color(accent.r, accent.g, accent.b, alpha * 0.45)
	var edge: Color = Color(accent.r, accent.g, accent.b, minf(alpha * 2.0, 0.99))
	match pattern:
		"frost_lance", "solar_lance":
			var half_width: float = 40.0 if pattern == "solar_lance" else 32.0
			var reach: float = 445.0 if pattern == "solar_lance" else 410.0
			_draw_lane(Vector2.ZERO, reach, half_width, fill, edge)
		"mirror_gate":
			var lateral: Vector2 = aim.orthogonal() * 78.0
			_draw_lane(lateral, 385.0, 26.0, fill, edge)
			_draw_lane(-lateral, 385.0, 26.0, fill, edge)
		"frost_ring", "solar_ring":
			var inner_radius: float = 105.0 if gold_family else 95.0
			var outer_radius: float = 192.0 if gold_family else 180.0
			_draw_annulus(inner_radius, outer_radius, fill, edge)
		"frost_mark", "ember_mark":
			var mark_radius: float = 85.0 if gold_family else 76.0
			draw_circle(Vector2.ZERO, mark_radius, fill)
			draw_arc(Vector2.ZERO, mark_radius, 0.0, TAU, 48, edge, 3.0, true)
			draw_arc(Vector2.ZERO, mark_radius * 0.65, 0.0, TAU, 48, edge * Color(1.0, 1.0, 1.0, 0.45), 1.5, true)
		"frost_fork":
			_draw_fork(0.35, 375.0, 27.0, fill, edge)
		"mirror_cross":
			_draw_fork(PI / 4.0, 395.0, 25.0, fill, edge)
		"lotus_bloom":
			_draw_spokes(6, 40.0, 186.0, 0.23, fill, edge)
		"bell_toll":
			for ring_radius: float in [64.0, 130.0, 198.0]:
				_draw_annulus(ring_radius - 16.0, ring_radius + 16.0, fill, edge)
		"frost_crown":
			_draw_spokes(8, 46.0, 260.0, 0.12, fill, edge)
		"sun_pillar":
			for length_v: float in [85.0, 185.0, 285.0]:
				_draw_round_mark(aim * length_v, 46.0, fill, edge)
		"forge_cross":
			_draw_lane(-aim * 265.0, 530.0, 31.0, fill, edge)
			_draw_lane(-aim.orthogonal() * 265.0, 530.0, 31.0, fill, edge, aim.orthogonal())
		"phoenix_wings":
			_draw_wing_fan(265.0, 0.20, 0.56, fill, edge)
		"eclipse_wheel":
			_draw_eclipse_ring(100.0, 205.0, 0.17, fill, edge)
		"nine_suns":
			for idx: int in range(9):
				_draw_round_mark(aim.rotated(float(idx) * TAU / 9.0) * 154.0, 42.0, fill, edge)
		"solar_fan":
			var fan_points := PackedVector2Array([Vector2.ZERO])
			var angle: float = aim.angle()
			for index: int in range(25):
				var theta: float = angle - 0.397 + float(index) / 24.0 * 0.794
				fan_points.append(Vector2.RIGHT.rotated(theta) * 260.0)
			draw_colored_polygon(fan_points, fill)
			for side: float in [-0.397, 0.397]:
				draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(angle + side) * 260.0, edge, 3.0, true)
			draw_arc(Vector2.ZERO, 260.0, angle - 0.397, angle + 0.397, 28, edge, 3.0, true)
	# Boss signature ornament follows the existing hit geometry; it does NOT
	# introduce new danger shapes, collision radii or invisible damage areas.
	# The existing border remains the exact gameplay boundary.
	if not gold_family and not is_stage_hazard and not SettingsManager.reduced_effects:
		_draw_frost_boss_accents(progress, accent)
	# Late presentation pass: authored glows sit WITHIN actual hit shapes.
	# These are draw calls only. Damage is still contains_world_point().
	_draw_realm_fx_stamps(gold_family, progress)


func _draw_frost_boss_accents(progress: float, accent: Color) -> void:
	var fade: float = clampf(0.32 + progress * 0.35, 0.0, 0.76)
	if _impacted:
		fade = 0.82 * (1.0 - clampf((_elapsed - warning_duration) / MAX_LIFETIME_AFTER_IMPACT, 0.0, 1.0))
	var detail: Color = Color(0.87, 0.98, 1.0, fade)
	var subdued: Color = Color(accent.r, accent.g, accent.b, fade * 0.72)
	var orth: Vector2 = aim.orthogonal()
	match pattern:
		"frost_lance":
			# Interior measured runes within the original 64px-wide lane.
			for n: int in range(1, 5):
				var c: Vector2 = aim * float(n * 79)
				draw_line(c - orth * 17.0, c + orth * 17.0, subdued, 1.0, true)
				draw_circle(c, 2.0, detail)
		"mirror_gate":
			for sign_v: float in [-1.0, 1.0]:
				var side: Vector2 = orth * sign_v * 78.0
				for n: int in range(1, 4):
					var p: Vector2 = side + aim * float(n * 91)
					draw_line(p - orth * 11.0, p + orth * 11.0, subdued, 1.1, true)
		"frost_fork", "mirror_cross":
			var split_angle: float = 0.35 if pattern == "frost_fork" else PI / 4.0
			for sign_v: float in [-1.0, 1.0]:
				var direction: Vector2 = aim.rotated(sign_v * split_angle)
				for i: int in range(1, 4):
					var p: Vector2 = direction * float(i * 88)
					draw_line(p - direction.orthogonal() * 10.0, p + direction.orthogonal() * 10.0, subdued, 1.0, true)
		"frost_ring":
			for i: int in range(8):
				var direction: Vector2 = Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
				draw_line(direction * 121.0, direction * 146.0, subdued, 1.3, true)
		"frost_mark":
			for i: int in range(4):
				var direction: Vector2 = Vector2.RIGHT.rotated(float(i) * PI / 2.0)
				draw_line(direction * 32.0, direction * 62.0, subdued, 1.0, true)
				draw_circle(direction * 44.0, 2.1, detail)
		"lotus_bloom":
			for i: int in range(6):
				var direction: Vector2 = aim.rotated(float(i) * TAU / 6.0)
				var p: Vector2 = direction * 135.0
				draw_line(p - direction.orthogonal() * 12.0, p + direction.orthogonal() * 12.0, detail, 1.1, true)
				draw_circle(direction * 148.0, 3.1, subdued)
		"bell_toll":
			for radius_value: float in [64.0, 130.0, 198.0]:
				for i: int in range(8):
					var direction: Vector2 = Vector2.RIGHT.rotated(float(i) * TAU / 8.0)
					draw_line(direction * (radius_value - 9.0), direction * (radius_value + 9.0), subdued, 1.1, true)
		"frost_crown":
			for i: int in range(8):
				var direction: Vector2 = aim.rotated(float(i) * TAU / 8.0)
				var p: Vector2 = direction * 203.0
				draw_line(p - direction.orthogonal() * 8.0, p + direction.orthogonal() * 8.0, detail, 1.5, true)


func _draw_lane(offset: Vector2, length: float, half_width: float, fill: Color, edge: Color, direction: Vector2 = Vector2.ZERO) -> void:
	if direction == Vector2.ZERO:
		direction = aim
	var normal: Vector2 = direction.orthogonal() * half_width
	var start: Vector2 = offset
	var end: Vector2 = offset + direction * length
	var points := PackedVector2Array([start - normal, start + normal, end + normal, end - normal])
	draw_colored_polygon(points, fill)
	for side: float in [-1.0, 1.0]:
		draw_line(start + normal * side, end + normal * side, edge, 2.5, true)
	draw_line(end - normal, end + normal, edge, 2.5, true)

func _draw_annulus(inner_radius: float, outer_radius: float, fill: Color, edge: Color) -> void:
	var previous_angle: float = 0.0
	for index: int in range(1, 49):
		var next_angle: float = TAU * float(index) / 48.0
		var points := PackedVector2Array([
			Vector2.RIGHT.rotated(previous_angle) * inner_radius,
			Vector2.RIGHT.rotated(previous_angle) * outer_radius,
			Vector2.RIGHT.rotated(next_angle) * outer_radius,
			Vector2.RIGHT.rotated(next_angle) * inner_radius,
		])
		draw_colored_polygon(points, fill)
		previous_angle = next_angle
	draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 64, edge, 2.7, true)
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 64, edge, 3.0, true)


func _draw_fork(angle_value: float, reach: float, half_width: float, fill: Color, edge: Color) -> void:
	for sign_value: float in [-1.0, 1.0]:
		_draw_lane(Vector2.ZERO, reach, half_width, fill, edge, aim.rotated(sign_value * angle_value))


func _draw_round_mark(center: Vector2, radius_value: float, fill: Color, edge: Color) -> void:
	draw_circle(center, radius_value, fill)
	draw_arc(center, radius_value, 0.0, TAU, 40, edge, 2.7, true)


func _draw_spokes(count: int, inner_r: float, outer_r: float, half_angle: float, fill: Color, edge: Color) -> void:
	for spoke_idx: int in range(count):
		var angle_center: float = aim.angle() + float(spoke_idx) * TAU / float(count)
		var poly: PackedVector2Array = PackedVector2Array([
			Vector2.RIGHT.rotated(angle_center - half_angle) * inner_r,
			Vector2.RIGHT.rotated(angle_center - half_angle) * outer_r,
			Vector2.RIGHT.rotated(angle_center + half_angle) * outer_r,
			Vector2.RIGHT.rotated(angle_center + half_angle) * inner_r,
		])
		draw_colored_polygon(poly, fill)
		for direction: float in [-1.0, 1.0]:
			draw_line(Vector2.RIGHT.rotated(angle_center + half_angle * direction) * inner_r,
				Vector2.RIGHT.rotated(angle_center + half_angle * direction) * outer_r, edge, 2.2, true)


func _draw_wing_fan(reach: float, inner_angle: float, outer_angle: float, fill: Color, edge: Color) -> void:
	for sign_value: float in [-1.0, 1.0]:
		var inner_dir: Vector2 = aim.rotated(inner_angle * sign_value)
		var outer_dir: Vector2 = aim.rotated(outer_angle * sign_value)
		var points := PackedVector2Array([Vector2.ZERO])
		for step: int in range(21):
			var t: float = float(step) / 20.0
			points.append(aim.rotated(lerpf(inner_angle, outer_angle, t) * sign_value) * reach)
		draw_colored_polygon(points, fill)
		draw_line(Vector2.ZERO, inner_dir * reach, edge, 2.2, true)
		draw_line(Vector2.ZERO, outer_dir * reach, edge, 2.2, true)


func _draw_eclipse_ring(inner_r: float, outer_r: float, safe_angle: float, fill: Color, edge: Color) -> void:
	# Four cardinal gaps are intentionally SAFE; render precisely the hit zones.
	for sector_idx: int in range(4):
		var start_angle: float = aim.angle() + float(sector_idx) * PI * 0.5 + safe_angle
		var end_angle: float = aim.angle() + float(sector_idx + 1) * PI * 0.5 - safe_angle
		for step: int in range(12):
			var a: float = lerpf(start_angle, end_angle, float(step) / 12.0)
			var b: float = lerpf(start_angle, end_angle, float(step + 1) / 12.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2.RIGHT.rotated(a) * inner_r,
				Vector2.RIGHT.rotated(a) * outer_r,
				Vector2.RIGHT.rotated(b) * outer_r,
				Vector2.RIGHT.rotated(b) * inner_r,
			]), fill)
		draw_arc(Vector2.ZERO, inner_r, start_angle, end_angle, 16, edge, 2.5, true)
		draw_arc(Vector2.ZERO, outer_r, start_angle, end_angle, 16, edge, 2.5, true)


## Effect stamps are not new gameplay shapes. Their maximum diameter is
## intentionally smaller than the relevant geometric lane/disc, while safe
## centers in annulus attacks stay free of ornamental danger circles.
## Approved concept-art stamps are subordinate to the EXACT hit geometry.
## They never act as additional targeting markers or damage radius.
func _draw_realm_fx_stamps(solar: bool, progress: float) -> void:
	var seal: Texture2D = SOLAR_SEAL if solar else FROST_SEAL
	var impact: Texture2D = SOLAR_IMPACT if solar else FROST_IMPACT
	var reduced: bool = SettingsManager.reduced_effects
	var scale_factor: float = 0.45 if is_stage_hazard else 1.0
	var warning_alpha: float = (0.22 + progress * 0.23) * scale_factor
	if _impacted:
		var remaining: float = clampf(1.0 - (_elapsed - warning_duration) / MAX_LIFETIME_AFTER_IMPACT, 0.0, 1.0)
		if remaining <= 0.0:
			return
		var burst_alpha: float = remaining * (0.38 if reduced else 0.78) * scale_factor
		match pattern:
			"frost_mark", "ember_mark":
				_stamp(impact, Vector2.ZERO, 145.0 if solar else 128.0, burst_alpha)
			"sun_pillar":
				for distance_value: float in [85.0, 185.0, 285.0]:
					_stamp(impact, aim * distance_value, 88.0, burst_alpha)
			"nine_suns":
				for index: int in range(9):
					_stamp(impact, aim.rotated(float(index) * TAU / 9.0) * 154.0, 72.0, burst_alpha * 0.62)
			"frost_lance", "solar_lance":
				_stamp(impact, aim * 180.0, 59.0 if not solar else 74.0, burst_alpha * 0.68)
			"mirror_gate":
				for side: float in [-1.0, 1.0]:
					_stamp(impact, aim.orthogonal() * side * 78.0 + aim * 165.0, 47.0, burst_alpha * 0.72)
			"frost_fork", "mirror_cross":
				var divergence: float = 0.35 if pattern == "frost_fork" else PI / 4.0
				for side: float in [-1.0, 1.0]:
					_stamp(impact, aim.rotated(side * divergence) * 235.0, 46.0, burst_alpha * 0.73)
			"lotus_bloom", "frost_crown":
				var rays: int = 6 if pattern == "lotus_bloom" else 8
				for index: int in range(rays):
					_stamp(impact, aim.rotated(float(index) * TAU / float(rays)) * 152.0, 31.0 if rays == 6 else 22.0, burst_alpha * 0.68)
			"bell_toll":
				for radius_value: float in [64.0, 130.0, 198.0]:
					for index: int in range(6):
						_stamp(impact, Vector2.RIGHT.rotated(float(index) * TAU / 6.0) * radius_value, 29.0, burst_alpha * 0.38)
			"frost_ring", "solar_ring":
				var middle_radius: float = 148.0 if solar else 137.0
				for index: int in range(8):
					_stamp(impact, Vector2.RIGHT.rotated(float(index) * TAU / 8.0) * middle_radius, 43.0, burst_alpha * 0.40)
			"forge_cross":
				for direction: Vector2 in [aim, -aim, aim.orthogonal(), -aim.orthogonal()]:
					_stamp(impact, direction * 120.0, 54.0, burst_alpha * 0.62)
			"solar_fan":
				_stamp(impact, aim * 120.0, 86.0, burst_alpha * 0.74)
			"phoenix_wings":
				for side: float in [-1.0, 1.0]:
					_stamp(impact, aim.rotated(side * 0.38) * 160.0, 37.0, burst_alpha * 0.70)
			"eclipse_wheel":
				for index: int in range(4):
					_stamp(impact, aim.rotated(PI * 0.25 + float(index) * PI * 0.5) * 150.0, 46.0, burst_alpha * 0.60)
		return
	if reduced:
		return
	match pattern:
		"frost_mark", "ember_mark":
			_stamp(seal, Vector2.ZERO, 118.0 if solar else 105.0, warning_alpha)
		"sun_pillar":
			for distance_value: float in [85.0, 185.0, 285.0]:
				_stamp(seal, aim * distance_value, 76.0, warning_alpha * 0.76)
		"nine_suns":
			for index: int in range(9):
				_stamp(seal, aim.rotated(float(index) * TAU / 9.0) * 154.0, 72.0, warning_alpha * 0.65)
		"frost_lance", "solar_lance":
			_stamp(seal, aim * 65.0, 48.0 if not solar else 58.0, warning_alpha * 0.84)
		"mirror_gate":
			for side: float in [-1.0, 1.0]:
				_stamp(seal, aim.orthogonal() * side * 78.0 + aim * 52.0, 40.0, warning_alpha * 0.84)
		"frost_fork", "mirror_cross":
			var divergence: float = 0.35 if pattern == "frost_fork" else PI * 0.25
			for side: float in [-1.0, 1.0]:
				_stamp(seal, aim.rotated(side * divergence) * 68.0, 36.0, warning_alpha * 0.80)
		"lotus_bloom", "frost_crown":
			var rays: int = 6 if pattern == "lotus_bloom" else 8
			for index: int in range(rays):
				_stamp(seal, aim.rotated(float(index) * TAU / float(rays)) * 141.0, 33.0 if rays == 6 else 22.0, warning_alpha * 0.70)
		"bell_toll":
			for radius_value: float in [64.0, 130.0, 198.0]:
				for index: int in range(4):
					_stamp(seal, Vector2.RIGHT.rotated(float(index) * TAU / 4.0) * radius_value, 26.0, warning_alpha * 0.58)
		"solar_ring", "frost_ring":
			for index: int in range(8):
				_stamp(seal, Vector2.RIGHT.rotated(float(index) * TAU / 8.0) * (148.0 if solar else 137.0), 43.0, warning_alpha * 0.52)
		"solar_fan":
			for side: float in [-1.0, 1.0]:
				_stamp(seal, aim.rotated(side * 0.16) * 160.0, 38.0, warning_alpha * 0.70)
		"phoenix_wings":
			for side: float in [-1.0, 1.0]:
				_stamp(seal, aim.rotated(side * 0.38) * 160.0, 32.0, warning_alpha * 0.62)
		"forge_cross":
			for direction: Vector2 in [aim, -aim, aim.orthogonal(), -aim.orthogonal()]:
				_stamp(seal, direction * 118.0, 38.0, warning_alpha * 0.65)
		"eclipse_wheel":
			for index: int in range(4):
				_stamp(seal, aim.rotated(PI * 0.25 + float(index) * PI * 0.5) * 150.0, 43.0, warning_alpha * 0.55)


func _stamp(texture_value: Texture2D, center: Vector2, diameter: float, alpha_value: float) -> void:
	if texture_value == null or alpha_value <= 0.0:
		return
	var sz: Vector2 = Vector2.ONE * diameter
	draw_texture_rect(texture_value, Rect2(center - sz * 0.5, sz), false,
		Color(1.0, 1.0, 1.0, clampf(alpha_value, 0.0, 1.0)))
