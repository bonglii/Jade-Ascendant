extends RefCounted

## Player ornament only. Attack scenes still own the damage edges and clocks.
const CROWD_COUNT: int = 80
const CACHED_DRAW_GROUP: StringName = &"cached_weapon_draw"

static func quiet() -> bool:
	return SettingsManager.reduced_effects or SettingsManager.quiet_player_vfx

static func low_detail(canvas: CanvasItem) -> bool:
	return quiet() or canvas.get_tree().get_node_count_in_group(&"enemy") >= CROWD_COUNT

static func ribbon(canvas: CanvasItem, tip: Vector2, forward: Vector2, size: Vector2,
		tint: Color, core: Color, lean: float = 1.0) -> void:
	var along: Vector2 = forward * size.x
	var across: Vector2 = forward.orthogonal() * size.y * lean
	# A translucent tail forks away from the bright tapered leading edge.
	var points := PackedVector2Array([
		tip - along + across * 0.38,
		tip - along * 0.70 - across * 0.40,
		tip - along * 0.37 - across * 0.46,
		tip,
		tip - along * 0.29 + across * 0.22,
		tip - along * 0.64 + across * 0.04
	])
	var colors := PackedColorArray([
		Color(tint, 0), Color(tint, tint.a * 0.32), tint,
		core, tint, Color(tint, tint.a * 0.48)
	])
	canvas.draw_polygon(points, colors)
	canvas.draw_polyline(PackedVector2Array([
		tip - along * 0.58 - across * 0.17,
		tip - along * 0.32 - across * 0.13,
		tip - along * 0.10 - across * 0.04, tip
	]), Color(core, core.a * 0.78), 1.35, true)

static func curls(canvas: CanvasItem, center: Vector2, radius: float, phase: float,
		tint: Color, count: int = 4) -> void:
	if radius <= 1.0 or tint.a <= 0.0:
		return
	for index in range(count):
		var angle: float = phase + TAU * index / count
		var hub: Vector2 = center + Vector2.from_angle(angle) * radius * 0.62
		canvas.draw_arc(hub, radius * 0.27, angle - 0.72, angle + 1.12, 12, tint, 1.4, true)
