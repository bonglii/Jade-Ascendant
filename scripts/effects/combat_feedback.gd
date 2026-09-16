extends Node2D

## Fixed storage, one canvas draw, no per-hit Label/Line2D/particle nodes.
const ActorPresentation = preload("res://scripts/effects/actor_presentation.gd")
const POOL_SIZE: int = 96
const ARC_POOL_SIZE: int = 16
const JADE: Color = Color(0.64, 0.94, 0.82)
const GOLD: Color = Color(0.95, 0.79, 0.44)
const THUNDER: Color = Color(0.62, 0.90, 1.0)
const DANGER: Color = Color(1.0, 0.60, 0.46)

# Damage text stays inside the existing pooled CanvasItem renderer.
# Values are tuned for the 648x1152 design viewport and remain cheap on mobile.
const DAMAGE_TEXT_FONT_SIZE: int = 20
const DAMAGE_TEXT_LIFETIME: float = 0.68
const DAMAGE_TEXT_RISE: float = 30.0
const DAMAGE_TEXT_WIDTH: float = 72.0
const DAMAGE_TEXT_FADE_START: float = 0.58
var effects: Array[Dictionary] = []
var arcs: Array[Dictionary] = []
var effect_cursor: int = 0
var arc_cursor: int = 0
var active_scene: Node
var impulse_left: float = 0.0
var impulse_power: float = 0.0
var impulse_clock: float = 0.0
var camera: Camera2D
var camera_rest: Vector2
var feedback_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 5
	for index in range(POOL_SIZE):
		effects.append({"left": 0.0})
	for index in range(ARC_POOL_SIZE):
		arcs.append({"left": 0.0})

func register_actor(actor: Node2D) -> void:
	if actor.has_node("QiPresentation"):
		return
	var presentation: Node = ActorPresentation.new()
	presentation.name = "QiPresentation"
	actor.add_child(presentation)

func actor_action(actor: Node2D, duration: float = 0.28) -> void:
	var presentation: Node = actor.get_node_or_null("QiPresentation")
	if presentation != null:
		presentation.call("action", duration)

func hit(actor: Node2D, amount: float) -> void:
	if amount <= 0.0 or not is_finite(amount):
		return
	var presentation: Node = actor.get_node_or_null("QiPresentation")
	if presentation != null:
		presentation.call("hurt")
	var entry: Dictionary = _next_effect()
	var text_color: Color = JADE
	if actor.is_in_group("player"):
		text_color = DANGER
	var text_lane: float = float((effect_cursor % 5) - 2) * 3.0
	entry.merge({
		"kind": "hit",
		"position": actor.global_position,
		"left": DAMAGE_TEXT_LIFETIME,
		"duration": DAMAGE_TEXT_LIFETIME,
		"text": str(maxi(1, int(round(amount)))) if SettingsManager.damage_numbers else "",
		"color": text_color,
		"text_lane": text_lane
	}, true)
	if actor.is_in_group("player"):
		AudioManager.play_sfx("hurt")
		impulse(2.5)
		if SettingsManager.haptics and OS.has_feature("android"):
			Input.vibrate_handheld(24)
	else:
		AudioManager.play_sfx("hit")

func pulse(at: Vector2, kind: String = "qi") -> void:
	var entry: Dictionary = _next_effect()
	var pulse_color: Color = JADE
	var pulse_duration: float = 0.48
	var pulse_alpha: float = 0.80
	var pulse_radius: float = 25.0
	var pulse_width: float = 1.5
	if kind in ["level", "pickup"]:
		pulse_color = GOLD
	elif kind == "talisman":
		pulse_color = THUNDER
	elif kind == "formation":
		# Eight Trigrams already owns a persistent ground sigil. Its pooled
		# confirmation only needs to acknowledge the damage tick, not draw a
		# second large effect over enemies/bosses.
		pulse_duration = 0.24
		pulse_alpha = 0.52
		pulse_radius = 16.0
		pulse_width = 1.25
	entry.merge({
		"kind": kind,
		"position": at,
		"left": pulse_duration,
		"duration": pulse_duration,
		"text": "",
		"color": pulse_color,
		"pulse_alpha": pulse_alpha,
		"pulse_radius": pulse_radius,
		"pulse_width": pulse_width
	}, true)

func death(actor: Node2D, is_boss: bool = false, play_audio: bool = true) -> void:
	var sprite: AnimatedSprite2D = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var entry: Dictionary = _next_effect()
	var lifetime: float = 1.15 if is_boss else 0.55
	entry.merge({"kind": "death", "position": actor.global_position, "left": lifetime, "duration": lifetime,
		"text": "", "color": GOLD if is_boss else JADE, "texture": null}, true)
	if sprite != null and sprite.sprite_frames != null:
		entry["texture"] = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		entry["sprite_position"] = sprite.global_position
		entry["sprite_scale"] = sprite.global_scale
	if is_boss:
		impulse(5.0)
		if play_audio:
			AudioManager.play_sfx("boss_defeat")
	elif play_audio:
		AudioManager.play_sfx("death")

func lightning(from: Vector2, to: Vector2, delay: float = 0.0, empowered: bool = false) -> void:
	if arcs.is_empty():
		return
	var entry: Dictionary = arcs[arc_cursor]
	arc_cursor = (arc_cursor + 1) % ARC_POOL_SIZE
	entry.clear()
	var points: PackedVector2Array = PackedVector2Array()
	var tangent: Vector2 = from.direction_to(to).orthogonal()
	for index in range(9):
		var ratio: float = float(index) / 8.0
		var bend: float = sin(float(index * 23 + arc_cursor * 7)) * 9.0 * sin(ratio * PI)
		points.append(from.lerp(to, ratio) + tangent * bend)
	entry.merge({"points": points, "left": 0.15 + delay, "delay": delay, "age": 0.0, "empowered": empowered})
	_activate_feedback()

func impulse(strength: float) -> void:
	if not SettingsManager.screen_shake or SettingsManager.reduced_effects:
		return
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_2d()
		if camera == null:
			return
		camera_rest = camera.offset
	impulse_left = 0.14
	impulse_power = maxf(impulse_power, strength)
	_activate_feedback()

func _activate_feedback() -> void:
	feedback_active = true

func _next_effect() -> Dictionary:
	var capacity: int = 32 if SettingsManager.reduced_effects else POOL_SIZE
	effect_cursor = (effect_cursor + 1) % capacity
	var entry: Dictionary = effects[effect_cursor]
	entry.clear()
	_activate_feedback()
	return entry

func _process(delta: float) -> void:
	if active_scene != get_tree().current_scene:
		_reset_feedback()
		active_scene = get_tree().current_scene

	# CombatFeedback is an autoload that also exists while menus are open.
	# When no pooled visual or camera impulse is alive, avoid scanning every
	# pool entry and avoid forcing a CanvasItem redraw every frame.
	if not feedback_active:
		return

	var has_active_feedback: bool = false

	for entry in effects:
		var effect_left: float = float(entry.get("left", 0.0))
		if effect_left <= 0.0:
			continue
		effect_left = maxf(effect_left - delta, 0.0)
		entry["left"] = effect_left
		if effect_left > 0.0:
			has_active_feedback = true

	for entry in arcs:
		var arc_left: float = float(entry.get("left", 0.0))
		if arc_left <= 0.0:
			continue
		arc_left = maxf(arc_left - delta, 0.0)
		entry["left"] = arc_left
		entry["age"] = float(entry.get("age", 0.0)) + delta
		if arc_left > 0.0:
			has_active_feedback = true

	if is_instance_valid(camera):
		impulse_left = maxf(impulse_left - delta, 0.0)
		impulse_clock += delta * 90.0
		if impulse_left > 0.0 and SettingsManager.screen_shake and not SettingsManager.reduced_effects:
			camera.offset = camera_rest + Vector2(sin(impulse_clock), cos(impulse_clock * 1.7)) * impulse_power * impulse_left / 0.14
		else:
			camera.offset = camera_rest
			impulse_power = 0.0
		if impulse_left > 0.0:
			has_active_feedback = true

	# Active effects still redraw exactly as before. The final active frame also
	# redraws once after all lifetimes reach zero so expired visuals are cleared.
	queue_redraw()
	feedback_active = has_active_feedback

func _reset_feedback() -> void:
	for entry in effects:
		entry.clear()
	for entry in arcs:
		entry.clear()
	if is_instance_valid(camera):
		camera.offset = camera_rest
	camera = null
	impulse_left = 0.0
	impulse_power = 0.0
	feedback_active = false
	queue_redraw()

func _draw() -> void:
	for entry in effects:
		var left: float = float(entry.get("left", 0.0))
		if left <= 0.0:
			continue
		var progress: float = 1.0 - left / float(entry["duration"])
		var point: Vector2 = entry["position"]
		var pulse_alpha: float = float(entry.get("pulse_alpha", 0.80))
		var tint: Color = Color(entry["color"], (1.0 - progress) * pulse_alpha)
		var kind: String = str(entry["kind"])
		if kind == "hit":
			var label_text: String = str(entry["text"])
			if not label_text.is_empty():
				var text_alpha: float = 1.0
				if progress > DAMAGE_TEXT_FADE_START:
					text_alpha = 1.0 - (
						(progress - DAMAGE_TEXT_FADE_START)
						/ (1.0 - DAMAGE_TEXT_FADE_START)
					)
				text_alpha = clampf(text_alpha, 0.0, 1.0)
				var lane_offset: float = float(entry.get("text_lane", 0.0))
				var label_position: Vector2 = point + Vector2(
					-DAMAGE_TEXT_WIDTH * 0.5 + lane_offset,
					-29.0 - progress * DAMAGE_TEXT_RISE
				)
				draw_string(
					ThemeDB.fallback_font,
					label_position + Vector2(0.0, 2.0),
					label_text,
					HORIZONTAL_ALIGNMENT_CENTER,
					DAMAGE_TEXT_WIDTH,
					DAMAGE_TEXT_FONT_SIZE,
					Color(0.015, 0.035, 0.03, text_alpha * 0.92)
				)
				draw_string(
					ThemeDB.fallback_font,
					label_position,
					label_text,
					HORIZONTAL_ALIGNMENT_CENTER,
					DAMAGE_TEXT_WIDTH,
					DAMAGE_TEXT_FONT_SIZE,
					Color(entry["color"], text_alpha)
				)
			if progress < 0.30:
				_draw_rays(point, 4, 5.0 + progress * 24.0, tint)
		elif kind == "death":
			var texture: Texture2D = entry.get("texture") as Texture2D
			if texture != null:
				var dimensions: Vector2 = texture.get_size() * Vector2(entry["sprite_scale"])
				var origin: Vector2 = entry["sprite_position"] + Vector2(0.0, -progress * 12.0) - dimensions * 0.5
				# The complete atlas frame is drawn; no source region is changed.
				draw_texture_rect(texture, Rect2(origin, dimensions), false, Color(0.72, 0.97, 0.87, pow(1.0 - progress, 2.0)))
			_draw_rays(point + Vector2(0.0, -progress * 18.0), 6, 8.0 + progress * 40.0, tint)
		else:
			var max_radius: float = float(entry.get("pulse_radius", 25.0))
			var line_width: float = float(entry.get("pulse_width", 1.5))
			var radius: float = (
				12.0 + progress * 56.0
				if kind == "level"
				else 6.0 + progress * max_radius
			)
			draw_arc(point, radius, 0.0, TAU, 32, tint, line_width, true)
			if kind in ["talisman", "level", "reversal"]:
				_draw_rays(point, 8, radius * 0.8, tint)
	for entry in arcs:
		var left: float = float(entry.get("left", 0.0))
		if left <= 0.0 or float(entry.get("age", 0.0)) < float(entry.get("delay", 0.0)):
			continue
		var alpha: float = minf(left / 0.15, 1.0) * (0.55 if SettingsManager.reduced_effects else 1.0)
		var points: PackedVector2Array = entry["points"]
		var width: float = 3.5 if bool(entry["empowered"]) else 2.0
		draw_polyline(points, Color(JADE, alpha * 0.3), width + 3.0, true)
		draw_polyline(points, Color(0.91, 1.0, 0.96, alpha), width, true)
		draw_arc(points[points.size() - 1], 8.0, 0.0, TAU, 16, Color(THUNDER, alpha), 1.0, true)

func _draw_rays(center: Vector2, count: int, radius: float, tint: Color) -> void:
	for index in range(count):
		var direction: Vector2 = Vector2.from_angle(float(index) * TAU / float(count))
		draw_line(center + direction * radius * 0.55, center + direction * radius, tint, 1.5, true)
