extends Control

## Pavilion-only luxury overlay for the shared hub navigation.
## It never handles input or navigation; it only decorates the active Pavilion tab.

const UiTokens = preload("res://scripts/ui/jade_ui_tokens.gd")

var elapsed: float = 0.0
var redraw_elapsed: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if SettingsManager.reduced_effects:
		return
	elapsed = fmod(elapsed + delta, 1000.0)
	redraw_elapsed += delta
	if redraw_elapsed >= UiTokens.MOTION_REDRAW_INTERVAL:
		redraw_elapsed = 0.0
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return

	var tab_width: float = size.x / 5.0
	var left_edge: float = tab_width * 4.0
	var right_edge: float = size.x
	var center_x: float = left_edge + tab_width * 0.5
	var icon_center := Vector2(center_x, UiTokens.NAV_ICON_CENTER_Y)

	var pulse: float = 0.5
	if not SettingsManager.reduced_effects:
		pulse = (sin(elapsed * 2.1) + 1.0) * 0.5

	_draw_celestial_corners(left_edge, right_edge, pulse)
	_draw_temple_crown(center_x, pulse)
	_draw_icon_halo(icon_center, pulse)
	_draw_bottom_fate_marker(center_x, pulse)


func _draw_celestial_corners(left_edge: float, right_edge: float, pulse: float) -> void:
	var top_y: float = 8.5
	var bottom_y: float = size.y - 9.0
	var inner_left: float = left_edge + 9.0
	var inner_right: float = right_edge - 9.0
	var gold := UiTokens.with_alpha(UiTokens.GOLD_BRIGHT, 0.60 + pulse * 0.18)
	var jade := UiTokens.with_alpha(UiTokens.JADE_BRIGHT, 0.28 + pulse * 0.10)

	# Notched ceremonial brackets echo the Home journey button without changing hit geometry.
	for x_value in [inner_left, inner_right]:
		var direction: float = 1.0 if x_value == inner_left else -1.0
		draw_line(Vector2(x_value, top_y + 8.0), Vector2(x_value, top_y + 2.0), gold, 1.25, true)
		draw_line(Vector2(x_value, top_y + 2.0), Vector2(x_value + direction * 7.0, top_y + 2.0), gold, 1.25, true)
		draw_line(Vector2(x_value, bottom_y - 8.0), Vector2(x_value, bottom_y - 2.0), jade, 1.0, true)
		draw_line(Vector2(x_value, bottom_y - 2.0), Vector2(x_value + direction * 7.0, bottom_y - 2.0), jade, 1.0, true)

	var top_span: float = maxf(tab_width_from_edges(inner_left, inner_right) * 0.22, 7.0)
	draw_line(Vector2(center_x_from_edges(inner_left, inner_right) - top_span, top_y), Vector2(center_x_from_edges(inner_left, inner_right) - 4.0, top_y), UiTokens.with_alpha(UiTokens.GOLD, 0.38), 1.0, true)
	draw_line(Vector2(center_x_from_edges(inner_left, inner_right) + 4.0, top_y), Vector2(center_x_from_edges(inner_left, inner_right) + top_span, top_y), UiTokens.with_alpha(UiTokens.GOLD, 0.38), 1.0, true)


func _draw_temple_crown(center_x: float, pulse: float) -> void:
	var crown_y: float = 8.0
	var glow := UiTokens.with_alpha(UiTokens.GOLD_BRIGHT, 0.66 + pulse * 0.16)
	var jade := UiTokens.with_alpha(UiTokens.JADE, 0.34 + pulse * 0.10)

	draw_line(Vector2(center_x - 14.0, crown_y + 5.0), Vector2(center_x, crown_y - 1.0), glow, 1.35, true)
	draw_line(Vector2(center_x, crown_y - 1.0), Vector2(center_x + 14.0, crown_y + 5.0), glow, 1.35, true)
	draw_line(Vector2(center_x - 10.0, crown_y + 7.0), Vector2(center_x + 10.0, crown_y + 7.0), jade, 1.0, true)

	var jewel := PackedVector2Array([
		Vector2(center_x, crown_y + 2.5),
		Vector2(center_x + 2.5, crown_y + 5.0),
		Vector2(center_x, crown_y + 7.5),
		Vector2(center_x - 2.5, crown_y + 5.0)
	])
	draw_colored_polygon(jewel, UiTokens.with_alpha(UiTokens.GOLD_BRIGHT, 0.78 + pulse * 0.14))


func _draw_icon_halo(icon_center: Vector2, pulse: float) -> void:
	var radius: float = UiTokens.NAV_ICON_RADIUS + 3.0 + pulse * 1.4
	draw_arc(icon_center, radius + 2.5, -PI * 0.92, -PI * 0.10, 18, UiTokens.with_alpha(UiTokens.GOLD_BRIGHT, 0.35 + pulse * 0.12), 1.0, true)
	draw_arc(icon_center, radius + 2.5, PI * 0.08, PI * 0.90, 18, UiTokens.with_alpha(UiTokens.JADE_BRIGHT, 0.28 + pulse * 0.10), 1.0, true)

	for index: int in range(4):
		var angle: float = PI * 0.25 + float(index) * PI * 0.5
		var point := icon_center + Vector2(cos(angle), sin(angle)) * (radius + 4.0)
		var diamond := PackedVector2Array([
			point + Vector2(0.0, -1.8),
			point + Vector2(1.8, 0.0),
			point + Vector2(0.0, 1.8),
			point + Vector2(-1.8, 0.0)
		])
		draw_colored_polygon(diamond, UiTokens.with_alpha(UiTokens.GOLD, 0.44 + pulse * 0.14))


func _draw_bottom_fate_marker(center_x: float, pulse: float) -> void:
	var y_value: float = size.y - 8.0
	var span: float = 16.0 + pulse * 2.0
	var gold := UiTokens.with_alpha(UiTokens.GOLD_BRIGHT, 0.48 + pulse * 0.16)
	draw_line(Vector2(center_x - span, y_value), Vector2(center_x - 4.0, y_value), gold, 1.1, true)
	draw_line(Vector2(center_x + 4.0, y_value), Vector2(center_x + span, y_value), gold, 1.1, true)
	var diamond := PackedVector2Array([
		Vector2(center_x, y_value - 2.8),
		Vector2(center_x + 2.8, y_value),
		Vector2(center_x, y_value + 2.8),
		Vector2(center_x - 2.8, y_value)
	])
	draw_colored_polygon(diamond, gold)


func tab_width_from_edges(left_edge: float, right_edge: float) -> float:
	return maxf(right_edge - left_edge, 1.0)


func center_x_from_edges(left_edge: float, right_edge: float) -> float:
	return (left_edge + right_edge) * 0.5
