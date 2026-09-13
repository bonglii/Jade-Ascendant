extends Node2D
class_name LinYueCultivationPresentation

## Lin Yue Cultivation State Feedback
##
## Semantic presentation only:
## - Qi Shield block -> defensive ward burst.
## - Blood Qi actual HP recovery -> controlled crimson Qi returns to meridians.
## - Level Up -> jade/gold breakthrough pulse.
##
## No collision, damage, heal, cooldown, stat, or upgrade logic lives here.

const QI_SHIELD_DURATION: float = 0.24
const BLOOD_QI_DURATION: float = 0.36
const BREAKTHROUGH_DURATION: float = 0.64

const CIRCLE_SEGMENTS: int = 32
const ARC_SEGMENTS: int = 10
const MAX_ACTIVE_EFFECTS: int = 5

var active_effects: int = 0

@onready var player: Node = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("connect_actual_gameplay_signals")

func connect_actual_gameplay_signals() -> void:
	if player == null:
		return

	if player.has_signal("level_changed"):
		if not player.level_changed.is_connected(_on_level_changed):
			player.level_changed.connect(_on_level_changed)

	var player_health := (
		player.get_node_or_null("PlayerHealth")
		as PlayerHealth
	)

	if player_health == null:
		push_warning(
			"Lin Yue Cultivation Presentation: PlayerHealth tidak ditemukan."
		)
		return

	if not player_health.qi_shield_blocked.is_connected(
		_on_qi_shield_blocked
	):
		player_health.qi_shield_blocked.connect(
			_on_qi_shield_blocked
		)

	if player_health.has_signal("blood_qi_recovered"):
		if not player_health.blood_qi_recovered.is_connected(
			_on_blood_qi_recovered
		):
			player_health.blood_qi_recovered.connect(
				_on_blood_qi_recovered
			)

func _on_qi_shield_blocked(_remaining_charges: int) -> void:
	create_qi_shield_block()

func _on_blood_qi_recovered(
	recovered_amount: float,
	_current_health: float,
	_max_health: float
) -> void:
	if recovered_amount <= 0.0:
		return

	create_blood_qi_recovery()

func _on_level_changed(_new_level: int) -> void:
	create_breakthrough()

func can_spawn_effect() -> bool:
	return active_effects < MAX_ACTIVE_EFFECTS

func create_circle_points(
	radius: float,
	segments: int = CIRCLE_SEGMENTS
) -> PackedVector2Array:
	var points := PackedVector2Array()
	var safe_segments: int = max(segments, 3)

	for index in range(safe_segments + 1):
		var angle: float = (
			TAU
			* float(index)
			/ float(safe_segments)
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	return points

func create_arc_points(
	radius: float,
	start_angle: float,
	end_angle: float
) -> PackedVector2Array:
	var points := PackedVector2Array()

	for index in range(ARC_SEGMENTS + 1):
		var ratio: float = (
			float(index)
			/ float(ARC_SEGMENTS)
		)

		var angle: float = lerpf(
			start_angle,
			end_angle,
			ratio
		)

		points.append(
			Vector2.RIGHT.rotated(angle)
			* radius
		)

	return points

func register_effect(effect_root: Node) -> void:
	active_effects += 1

	effect_root.tree_exited.connect(
		func() -> void:
			active_effects = maxi(active_effects - 1, 0)
	)

func make_line(
	points: PackedVector2Array,
	width: float,
	color: Color
) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.antialiased = true
	line.points = points
	return line

## Bigger and more readable in runtime.
func create_qi_shield_block() -> void:
	if not can_spawn_effect():
		return

	var root := Node2D.new()
	add_child(root)
	register_effect(root)

	var jade_color := Color(
		0.46,
		0.96,
		0.80,
		0.96
	)

	var pale_color := Color(
		0.88,
		1.0,
		0.94,
		0.90
	)

	var outer_shell := Node2D.new()
	root.add_child(outer_shell)

	for quadrant in range(4):
		var start_angle: float = (
			float(quadrant)
			* PI * 0.5
			+ 0.08
		)

		var end_angle: float = (
			start_angle
			+ PI * 0.5
			- 0.16
		)

		var large_arc := make_line(
			create_arc_points(
				42.0,
				start_angle,
				end_angle
			),
			4.0,
			jade_color
		)
		outer_shell.add_child(large_arc)

		var inner_arc := make_line(
			create_arc_points(
				31.0,
				start_angle + 0.06,
				end_angle - 0.06
			),
			2.2,
			pale_color
		)
		outer_shell.add_child(inner_arc)

	var impact_core := make_line(
		create_circle_points(18.0),
		2.0,
		pale_color
	)
	root.add_child(impact_core)

	var ward_ring := make_line(
		create_circle_points(27.0),
		2.8,
		Color(
			0.70,
			1.0,
			0.88,
			0.86
		)
	)
	root.add_child(ward_ring)

	for index in range(10):
		var angle: float = (
			TAU
			* float(index)
			/ 10.0
		)

		var direction := Vector2.RIGHT.rotated(angle)

		var shard_root := Node2D.new()
		shard_root.position = direction * 26.0
		root.add_child(shard_root)

		var shard := make_line(
			PackedVector2Array([
				Vector2.ZERO,
				direction * 13.0
			]),
			2.0,
			Color(
				0.78,
				1.0,
				0.90,
				0.90
			)
		)
		shard_root.add_child(shard)

		var shard_tween := create_tween()
		shard_tween.set_parallel(true)

		shard_tween.tween_property(
			shard_root,
			"position",
			direction * 48.0,
			QI_SHIELD_DURATION
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_OUT
		)

		shard_tween.tween_property(
			shard_root,
			"modulate:a",
			0.0,
			QI_SHIELD_DURATION
		)

	root.scale = Vector2.ONE * 0.90

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		outer_shell,
		"scale",
		Vector2.ONE * 1.18,
		QI_SHIELD_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		root,
		"scale",
		Vector2.ONE * 1.10,
		QI_SHIELD_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		root,
		"modulate:a",
		0.0,
		QI_SHIELD_DURATION
	)

	tween.finished.connect(
		func() -> void:
			if is_instance_valid(root):
				root.queue_free()
	)

## Bigger recovery presentation for clearer runtime readability.
func create_blood_qi_recovery() -> void:
	if not can_spawn_effect():
		return

	var root := Node2D.new()
	add_child(root)
	register_effect(root)

	var crimson := Color(
		0.82,
		0.18,
		0.26,
		0.88
	)

	var crimson_pale := Color(
		0.98,
		0.52,
		0.58,
		0.76
	)

	var jade := Color(
		0.62,
		0.96,
		0.82,
		0.84
	)

	var center_ring := make_line(
		create_circle_points(12.0),
		2.3,
		jade
	)
	root.add_child(center_ring)

	var secondary_ring := make_line(
		create_circle_points(19.0),
		1.5,
		Color(
			0.86,
			1.0,
			0.92,
			0.50
		)
	)
	root.add_child(secondary_ring)

	var inner_cross := Node2D.new()
	root.add_child(inner_cross)

	inner_cross.add_child(
		make_line(
			PackedVector2Array([
				Vector2(-8.0, 0.0),
				Vector2(8.0, 0.0)
			]),
			1.5,
			Color(
				0.90,
				1.0,
				0.92,
				0.76
			)
		)
	)
	inner_cross.add_child(
		make_line(
			PackedVector2Array([
				Vector2(0.0, -8.0),
				Vector2(0.0, 8.0)
			]),
			1.5,
			Color(
				0.90,
				1.0,
				0.92,
				0.76
			)
		)
	)

	for index in range(8):
		var angle: float = (
			TAU
			* float(index)
			/ 8.0
			- PI * 0.5
		)

		var direction := Vector2.RIGHT.rotated(angle)
		var tangent := direction.rotated(PI * 0.5)
		var start_position: Vector2 = direction * 42.0

		var wisp_root := Node2D.new()
		wisp_root.position = start_position
		wisp_root.rotation = angle
		root.add_child(wisp_root)

		var main_wisp := make_line(
			PackedVector2Array([
				Vector2.ZERO,
				Vector2(-10.0, 3.5),
				Vector2(-17.0, -1.5)
			]),
			2.3,
			crimson
		)
		wisp_root.add_child(main_wisp)

		var echo_wisp := make_line(
			PackedVector2Array([
				Vector2(3.0, 1.5),
				Vector2(-8.0, 7.0)
			]),
			1.4,
			crimson_pale
		)
		wisp_root.add_child(echo_wisp)

		var wisp_tween := create_tween()
		wisp_tween.set_parallel(true)

		wisp_tween.tween_property(
			wisp_root,
			"position",
			tangent * 4.0,
			BLOOD_QI_DURATION
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_IN
		)

		wisp_tween.tween_property(
			wisp_root,
			"rotation",
			angle + 0.34,
			BLOOD_QI_DURATION
		)

		wisp_tween.tween_property(
			wisp_root,
			"modulate:a",
			0.0,
			BLOOD_QI_DURATION
		)

	for index in range(6):
		var mote := Node2D.new()
		mote.position = Vector2(
			-10.0 + float(index) * 4.0,
			10.0
		)
		root.add_child(mote)

		var mote_line := make_line(
			PackedVector2Array([
				Vector2.ZERO,
				Vector2(0.0, -8.0)
			]),
			1.6,
			Color(
				0.76,
				0.98,
				0.86,
				0.74
			)
		)
		mote.add_child(mote_line)

		var mote_tween := create_tween()
		mote_tween.set_parallel(true)

		mote_tween.tween_property(
			mote,
			"position:y",
			-16.0,
			BLOOD_QI_DURATION
		).set_trans(
			Tween.TRANS_SINE
		).set_ease(
			Tween.EASE_OUT
		)

		mote_tween.tween_property(
			mote,
			"modulate:a",
			0.0,
			BLOOD_QI_DURATION
		)

	var center_tween := create_tween()
	center_tween.set_parallel(true)

	center_tween.tween_property(
		center_ring,
		"scale",
		Vector2.ONE * 2.15,
		BLOOD_QI_DURATION
	)

	center_tween.tween_property(
		secondary_ring,
		"scale",
		Vector2.ONE * 1.65,
		BLOOD_QI_DURATION
	)

	center_tween.tween_property(
		inner_cross,
		"scale",
		Vector2.ONE * 1.85,
		BLOOD_QI_DURATION
	)

	center_tween.tween_property(
		center_ring,
		"modulate:a",
		0.0,
		BLOOD_QI_DURATION
	)

	center_tween.tween_property(
		secondary_ring,
		"modulate:a",
		0.0,
		BLOOD_QI_DURATION
	)

	center_tween.tween_property(
		inner_cross,
		"modulate:a",
		0.0,
		BLOOD_QI_DURATION
	)

	center_tween.finished.connect(
		func() -> void:
			if is_instance_valid(root):
				root.queue_free()
	)

func create_breakthrough() -> void:
	if not can_spawn_effect():
		return

	var root := Node2D.new()
	add_child(root)
	register_effect(root)

	var jade := Color(
		0.42,
		0.94,
		0.76,
		0.94
	)

	var pale_jade := Color(
		0.86,
		1.0,
		0.93,
		0.88
	)

	var antique_gold := Color(
		0.88,
		0.72,
		0.32,
		0.88
	)

	var warm_gold := Color(
		0.98,
		0.88,
		0.48,
		0.82
	)

	## Central white-jade flash.
	var flash_core := make_line(
		create_circle_points(10.0),
		3.2,
		pale_jade
	)
	root.add_child(flash_core)

	## Main cultivation seal.
	var seal_inner := make_line(
		create_circle_points(20.0),
		3.0,
		jade
	)
	root.add_child(seal_inner)

	var seal_mid := make_line(
		create_circle_points(34.0),
		2.4,
		antique_gold
	)
	root.add_child(seal_mid)

	var seal_outer := make_line(
		create_circle_points(48.0),
		1.8,
		warm_gold
	)
	root.add_child(seal_outer)

	## Segmented jade seal marks.
	for index in range(8):
		var angle: float = (
			TAU
			* float(index)
			/ 8.0
		)

		var direction := (
			Vector2.RIGHT.rotated(angle)
		)

		var tangent := direction.rotated(
			PI * 0.5
		)

		var mark := make_line(
			PackedVector2Array([
				direction * 27.0
				- tangent * 5.0,
				direction * 27.0
				+ tangent * 5.0
			]),
			2.2,
			pale_jade
		)
		root.add_child(mark)

	## Large diamond cultivation glyph.
	var central_glyph := make_line(
		PackedVector2Array([
			Vector2(0.0, -17.0),
			Vector2(17.0, 0.0),
			Vector2(0.0, 17.0),
			Vector2(-17.0, 0.0),
			Vector2(0.0, -17.0)
		]),
		2.2,
		Color(
			0.94,
			0.99,
			0.84,
			0.90
		)
	)
	root.add_child(central_glyph)

	## Eight radial ascension rays.
	for index in range(8):
		var angle: float = (
			TAU
			* float(index)
			/ 8.0
			- PI * 0.5
		)

		var direction := (
			Vector2.RIGHT.rotated(angle)
		)

		var ray := make_line(
			PackedVector2Array([
				direction * 18.0,
				direction * 60.0
			]),
			2.4
			if index % 2 == 0
			else 1.8,
			jade
			if index % 2 == 0
			else antique_gold
		)
		root.add_child(ray)

	## Vertical Qi pillar. Broad enough to read at gameplay scale,
	## but it is only a level-up ceremony, never an attack area.
	var pillar_root := Node2D.new()
	root.add_child(pillar_root)

	for index in range(5):
		var x_offset: float = (
			-16.0
			+ float(index) * 8.0
		)

		var pillar_line := make_line(
			PackedVector2Array([
				Vector2(
					x_offset,
					38.0
				),
				Vector2(
					x_offset * 0.55,
					-78.0
				)
			]),
			3.0
			if index == 2
			else 2.0,
			pale_jade
			if index % 2 == 0
			else jade
		)
		pillar_root.add_child(
			pillar_line
		)

	## Outer spiritual sparks.
	for index in range(12):
		var angle: float = (
			TAU
			* float(index)
			/ 12.0
			+ PI / 12.0
		)

		var direction := (
			Vector2.RIGHT.rotated(angle)
		)

		var spark_root := Node2D.new()
		spark_root.position = (
			direction * 32.0
		)
		root.add_child(spark_root)

		var spark := make_line(
			PackedVector2Array([
				Vector2.ZERO,
				direction * 14.0
			]),
			1.7,
			pale_jade
			if index % 2 == 0
			else warm_gold
		)
		spark_root.add_child(spark)

		var spark_tween := create_tween()
		spark_tween.set_parallel(true)

		spark_tween.tween_property(
			spark_root,
			"position",
			direction * 68.0,
			BREAKTHROUGH_DURATION
		).set_trans(
			Tween.TRANS_QUAD
		).set_ease(
			Tween.EASE_OUT
		)

		spark_tween.tween_property(
			spark_root,
			"modulate:a",
			0.0,
			BREAKTHROUGH_DURATION
		)

	root.scale = (
		Vector2.ONE * 0.82
	)

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		flash_core,
		"scale",
		Vector2.ONE * 4.0,
		BREAKTHROUGH_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		seal_inner,
		"scale",
		Vector2.ONE * 2.3,
		BREAKTHROUGH_DURATION
	)

	tween.tween_property(
		seal_mid,
		"scale",
		Vector2.ONE * 1.75,
		BREAKTHROUGH_DURATION
	)

	tween.tween_property(
		seal_outer,
		"scale",
		Vector2.ONE * 1.45,
		BREAKTHROUGH_DURATION
	)

	tween.tween_property(
		central_glyph,
		"rotation",
		PI * 0.50,
		BREAKTHROUGH_DURATION
	)

	tween.tween_property(
		pillar_root,
		"position:y",
		-16.0,
		BREAKTHROUGH_DURATION
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		root,
		"scale",
		Vector2.ONE * 1.12,
		BREAKTHROUGH_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	for child in root.get_children():
		tween.tween_property(
			child,
			"modulate:a",
			0.0,
			BREAKTHROUGH_DURATION
		)

	tween.finished.connect(
		func() -> void:
			if is_instance_valid(root):
				root.queue_free()
	)
