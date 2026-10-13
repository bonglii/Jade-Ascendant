extends Area2D
## One-use map vacuum: existing shards keep ownership of XP and collection.
const ART: Texture2D = preload("res://assets/pickups/jade_qi_magnet.svg")
var collected: bool = false
var clock: float = 0.0
var burst_left: float = 0.0
var shard_count: int = 0
var icon: Sprite2D

func _ready() -> void:
	add_to_group("qi_magnet")
	collision_layer = 32
	collision_mask = 1
	z_index = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 25.0
	shape.shape = circle
	add_child(shape)
	icon = Sprite2D.new()
	icon.texture = ART
	icon.scale = Vector2.ONE * 0.48
	add_child(icon)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	clock += delta
	if collected:
		burst_left -= delta
		if burst_left <= 0.0:
			queue_free()
	else:
		icon.position.y = -4.0 + sin(clock * 2.3) * 2.5
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if collected or is_queued_for_deletion() or not body.is_in_group("player"):
		return
	collected = true
	remove_from_group("qi_magnet")
	# A single bounded group snapshot; no permanent map scans or extra XP.
	for shard: Node in get_tree().get_nodes_in_group("qi_pickup"):
		if is_instance_valid(shard) and not shard.is_queued_for_deletion() and shard.has_method("attract_to_player"):
			if shard.attract_to_player(body):
				shard_count += 1
	icon.hide()
	global_position = body.global_position
	burst_left = 0.9
	AudioManager.play_sfx("pickup")
	CombatFeedback.pulse(global_position, "level")

func _draw() -> void:
	var reduced: bool = SettingsManager.reduced_effects
	if collected:
		var progress: float = clampf(1.0 - burst_left / 0.9, 0.0, 1.0)
		if not reduced:
			draw_arc(Vector2.ZERO, 25.0 + progress * 115.0, 0.0, TAU, 48, Color(0.23, 0.94, 0.72, 1.0 - progress), 2.0, true)
		var text: String = ("QI TERKUMPUL" if SettingsManager.language == "id" else "QI GATHERED") + " · %d" % shard_count
		draw_string_outline(ThemeDB.fallback_font, Vector2(-90, -38), text, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, 4, Color(0.02, 0.10, 0.08, 1.0 - progress))
		draw_string(ThemeDB.fallback_font, Vector2(-90, -38), text, HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(0.98, 0.83, 0.43, 1.0 - progress))
		return
	draw_circle(Vector2(0, 15), 23.0, Color(0.05, 0.24, 0.19, 0.38))
	var rotation_value: float = 0.0 if reduced else clock * 0.6
	for i: int in range(3):
		var start: float = rotation_value + TAU * float(i) / 3.0
		draw_arc(Vector2.ZERO, 32.0, start, start + 1.3, 12, Color(0.30, 0.94, 0.73, 0.65), 1.5, true)
	draw_arc(Vector2.ZERO, 35.0, 0, TAU, 32, Color(0.96, 0.76, 0.35, 0.25), 1.0, true)
	var caption: String = "MAGNET QI" if SettingsManager.language == "id" else "QI MAGNET"
	draw_string_outline(ThemeDB.fallback_font, Vector2(-55, 46), caption, HORIZONTAL_ALIGNMENT_CENTER, 110, 11, 3, Color(0.02, 0.10, 0.08))
	draw_string(ThemeDB.fallback_font, Vector2(-55, 46), caption, HORIZONTAL_ALIGNMENT_CENTER, 110, 11, Color(0.96, 0.80, 0.44))
