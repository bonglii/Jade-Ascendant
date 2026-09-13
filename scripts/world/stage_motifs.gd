extends RefCounted

## Native 2D landmarks shared by arena scenery and stage-card illustrations.
## Colors stay quieter than combat warnings. Called only from CanvasItem._draw.
static func draw_motif(canvas: CanvasItem, stage_id: int, center: Vector2, scale_factor: float = 1.0) -> void:
	canvas.draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	match stage_id:
		2: _bamboo(canvas)
		3: _shrine(canvas)
		4: _storm_pillar(canvas)
		5: _gate(canvas)
		_: _valley_marker(canvas)
	canvas.draw_set_transform(Vector2.ZERO)


static func _bamboo(c: CanvasItem) -> void:
	# Dense vertical rhythm plus a low mist shelf gives Bamboo Mist Pass a
	# recognizable silhouette even at the tiny Stage Select preview scale.
	c.draw_line(Vector2(-54, 7), Vector2(54, 7), Color(0.025, 0.09, 0.065, 0.72), 8.0, true)
	for index: int in range(5):
		var x: float = (index - 2) * 13.0
		var height: float = 68.0 + float((index * 17) % 35)
		var top: Vector2 = Vector2(x + (index - 2) * 4, -height)
		c.draw_line(Vector2(x, 4), top, Color(0.055, 0.15, 0.10), 7.0, true)
		c.draw_line(Vector2(x - 1, 2), top + Vector2(-1, 0), Color(0.20, 0.37, 0.21), 3.0, true)
		for joint: int in range(1, 5):
			var point: Vector2 = Vector2(x, 3).lerp(top, float(joint) / 5.0)
			c.draw_line(point + Vector2(-4, 0), point + Vector2(4, 0), Color(0.39, 0.52, 0.30), 2.0, true)
			if joint >= 2:
				var side: float = -1.0 if (index + joint) % 2 == 0 else 1.0
				var leaf: PackedVector2Array = PackedVector2Array([
					point,
					point + Vector2(side * 24, -16),
					point + Vector2(side * 13, -3),
				])
				c.draw_colored_polygon(leaf, Color(0.12, 0.30, 0.17, 0.92))
				c.draw_line(point, point + Vector2(side * 23, -15), Color(0.31, 0.48, 0.27, 0.70), 1.0, true)
	for band_index: int in range(2):
		var mist_y: float = -18.0 + band_index * 19.0
		c.draw_line(Vector2(-70, mist_y), Vector2(66, mist_y - 7), Color(0.40, 0.58, 0.49, 0.16), 5.0, true)


static func _shrine(c: CanvasItem) -> void:
	var jade: Color = Color(0.28, 0.47, 0.37)
	var gold: Color = Color(0.60, 0.52, 0.29)
	c.draw_rect(Rect2(-65, -42, 130, 48), Color(0.075, 0.11, 0.105))
	c.draw_rect(Rect2(-58, -39, 116, 39), Color(0.22, 0.28, 0.245), false, 3.0)
	c.draw_line(Vector2(-47, -20), Vector2(47, -20), Color(0.12, 0.19, 0.16), 2.0)
	for side: int in [-1, 1]:
		var x: float = side * 44.0
		c.draw_rect(Rect2(x - 8, -85, 16, 48), Color(0.15, 0.22, 0.19))
		c.draw_line(Vector2(x - 4, -75), Vector2(x - 4, -44), jade, 2.0, true)
		c.draw_line(Vector2(x - 10, -83), Vector2(x + 8, -88), Color(0.31, 0.37, 0.28), 4.0, true)
		c.draw_rect(Rect2(x - 7, -26, 14, 18), Color(0.16, 0.24, 0.18))
		c.draw_rect(Rect2(x - 4, -24, 8, 8), Color(0.48, 0.67, 0.40, 0.8))
		# Torn jade talisman strip, deliberately rectangular rather than radial.
		c.draw_rect(Rect2(x - 3, -53, 6, 18), Color(0.56, 0.70, 0.42, 0.30))
	c.draw_arc(Vector2(0, -23), 21, 0, TAU, 24, gold, 2.0, true)
	c.draw_polyline(PackedVector2Array([
		Vector2(0, -40), Vector2(17, -23), Vector2(0, -6),
		Vector2(-17, -23), Vector2(0, -40),
	]), jade, 2.0, true)
	c.draw_line(Vector2(-5, -35), Vector2(5, -14), Color(0.10, 0.17, 0.14), 4.0, true)
	# Broken roof beam makes the silhouette asymmetrical and ruined.
	c.draw_line(Vector2(-72, -92), Vector2(10, -101), Color(0.17, 0.23, 0.20, 0.90), 7.0, true)
	c.draw_line(Vector2(18, -98), Vector2(68, -84), Color(0.17, 0.23, 0.20, 0.72), 5.0, true)


static func _storm_pillar(c: CanvasItem) -> void:
	var rock: PackedVector2Array = PackedVector2Array([
		Vector2(-24, 3), Vector2(-17, -84), Vector2(-4, -107),
		Vector2(14, -89), Vector2(25, -15), Vector2(17, 3),
	])
	c.draw_colored_polygon(rock, Color(0.10, 0.145, 0.20))
	c.draw_polyline(PackedVector2Array([
		Vector2(-17, -84), Vector2(-4, -107), Vector2(14, -89), Vector2(25, -15),
	]), Color(0.30, 0.39, 0.47), 3.0, true)
	c.draw_polyline(PackedVector2Array([
		Vector2(5, -82), Vector2(-9, -57), Vector2(6, -56), Vector2(-3, -33),
	]), Color(0.42, 0.53, 0.68, 0.72), 2.0, true)
	for index: int in range(4):
		var y: float = -14.0 - index * 21.0
		var alpha: float = 0.20 + float(index % 2) * 0.08
		c.draw_polyline(PackedVector2Array([
			Vector2(-62, y + 5), Vector2(-30, y), Vector2(18, y + 3), Vector2(64, y - 9),
		]), Color(0.30, 0.39, 0.58, alpha), 1.7, true)
	c.draw_line(Vector2(-39, 6), Vector2(39, 6), Color(0.16, 0.23, 0.29), 9.0, true)
	# A subdued banner shard differentiates the Herald's ritual approach from
	# generic mountain stone without borrowing the bright hostile lightning hue.
	c.draw_line(Vector2(20, -75), Vector2(43, -53), Color(0.22, 0.25, 0.39, 0.62), 4.0, true)
	c.draw_line(Vector2(43, -53), Vector2(34, -31), Color(0.22, 0.25, 0.39, 0.44), 4.0, true)


static func _gate(c: CanvasItem) -> void:
	var gold: Color = Color(0.68, 0.53, 0.24)
	var jade: Color = Color(0.13, 0.27, 0.24)
	for step: int in range(4):
		c.draw_rect(Rect2(-58 - step * 7, 7 + step * 8, 116 + step * 14, 7), Color(0.105 + step * 0.013, 0.17, 0.145))
	for side: int in [-1, 1]:
		var x: float = side * 58.0
		c.draw_rect(Rect2(x - 11, -91, 22, 97), jade)
		c.draw_line(Vector2(x - 5, -85), Vector2(x - 5, 0), gold, 2.5, true)
		c.draw_rect(Rect2(x - 15, -10, 30, 16), Color(0.22, 0.31, 0.25))
		c.draw_circle(Vector2(x, -50), 4, Color(0.40, 0.67, 0.48))
		# Ceremonial hanging seal plate reinforces the final-stage hierarchy.
		c.draw_rect(Rect2(x - 7, -69, 14, 19), Color(0.60, 0.46, 0.20, 0.50))
		c.draw_line(Vector2(x, -67), Vector2(x, -53), Color(0.88, 0.74, 0.39, 0.66), 1.5, true)
	var roof: PackedVector2Array = PackedVector2Array([
		Vector2(-90, -95), Vector2(-62, -102), Vector2(0, -124),
		Vector2(62, -102), Vector2(90, -95), Vector2(58, -86), Vector2(-58, -86),
	])
	c.draw_colored_polygon(roof, Color(0.085, 0.18, 0.17))
	c.draw_polyline(PackedVector2Array([
		Vector2(-90, -95), Vector2(-62, -102), Vector2(0, -124),
		Vector2(62, -102), Vector2(90, -95),
	]), gold, 3.0, true)
	c.draw_line(Vector2(-70, -84), Vector2(70, -84), gold, 3.0, true)
	c.draw_arc(Vector2(0, -48), 23, 0, TAU, 32, Color(0.31, 0.53, 0.40, 0.52), 2.0, true)
	c.draw_line(Vector2(-10, -48), Vector2(10, -48), gold, 2.0)
	c.draw_line(Vector2(0, -59), Vector2(0, -37), gold, 2.0)
	c.draw_line(Vector2(-34, -17), Vector2(34, -17), Color(0.86, 0.67, 0.29, 0.48), 2.0, true)


static func _valley_marker(c: CanvasItem) -> void:
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(-18, 3), Vector2(-15, -63), Vector2(3, -79),
		Vector2(19, -62), Vector2(21, 3),
	]), Color(0.12, 0.23, 0.18))
	c.draw_line(Vector2(-10, -58), Vector2(10, -58), Color(0.45, 0.65, 0.42), 2.0)
	c.draw_line(Vector2(0, -64), Vector2(0, -23), Color(0.37, 0.60, 0.40), 2.0)
	for index: int in range(7):
		var x: float = -36 + index * 12
		c.draw_line(Vector2(x, 6), Vector2(x - 5, -9 - (index % 3) * 5), Color(0.18, 0.37, 0.21), 2.0, true)
