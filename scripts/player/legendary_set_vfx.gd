extends Node2D
const OPACITY_BOOST: float = 1.4

## One bounded presentation per player, driven by confirmed gameplay events.
## Component frames have transparent gutters. Continuous transforms/alpha own
## the animation, so no frame swaps, neighbor sampling or character deformation.
const Art = preload("res://scripts/player/legendary_set_art.gd")
const FORM_SECONDS: float = 0.82
const PROC_SECONDS: float = 0.70
const BLOCK_SECONDS: float = 0.48
const RATE_LIMIT: float = 0.32
var set_id: String = ""
var pending_id: String = ""
var frames: Array[Texture2D] = []
var reduced: bool = false
var clock: float = 0.0
var visibility_mix: float = 0.0
var desired_visible: bool = false
var formation_left: float = 0.0
var proc_left: float = 0.0
var block_left: float = 0.0
var proc_gate: float = 0.0
var shield_mix: float = 0.0
var shield_charges: int = 0
var aim: Vector2 = Vector2.RIGHT
var health: Node
var foreground: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_to_group("legendary_set_vfx")
	foreground = Node2D.new()
	foreground.name = "GuardianForeground"
	foreground.z_index = 2 # Parent is at 2; player is at 3.
	add_child(foreground)
	foreground.draw.connect(_draw_foreground)
	var player: Node = get_parent().get_parent()
	health = player.get_node_or_null("PlayerHealth")
	if health != null:
		shield_charges = int(health.qi_shield_charges)
		health.health_changed.connect(_health_changed)
		health.qi_shield_blocked.connect(_shield_blocked)
	set_process(false)

func configure(id: String, pieces: int, use_reduced: bool) -> void:
	reduced = use_reduced
	pending_id = id if Art.qualifies(id, pieces) else ""
	desired_visible = not pending_id.is_empty()
	# Keep the departing set until fully faded. A -> B never flashes A's assets
	# with B's palette or restarts the player's body animation.
	if set_id.is_empty() and desired_visible: _adopt_pending()
	set_process(desired_visible or visibility_mix > 0.0)
	queue_redraw()
	if foreground != null: foreground.queue_redraw()

func _adopt_pending() -> void:
	set_id = pending_id
	frames = Art.textures(set_id)
	formation_left = FORM_SECONDS
	proc_left = 0.0
	block_left = 0.0
	proc_gate = 0.0
	shield_mix = 0.0
	if health != null: shield_charges = int(health.qi_shield_charges)
	if set_id == "celestial_aegis" and shield_charges == 0:
		formation_left = 0.0 # Set identity is not proof of a charged shield.

func _health_changed(current: float, _maximum: float) -> void:
	var next_charges: int = int(health.qi_shield_charges)
	if set_id == "celestial_aegis" and next_charges > shield_charges:
		formation_left = FORM_SECONDS
	shield_charges = next_charges
	if current > 0.0 and desired_visible: set_process(true)

func _shield_blocked(remaining: int) -> void:
	shield_charges = remaining
	if set_id == "celestial_aegis" and desired_visible:
		block_left = BLOCK_SECONDS
		formation_left = 0.0
		set_process(true)

func confirmed_proc(kind: String, target_position: Vector2) -> void:
	if not desired_visible or set_id != pending_id or not Art.SETS.has(set_id): return
	if str(Art.SETS[set_id].kind) != kind or proc_gate > 0.0: return
	if health != null and bool(health.is_dead): return
	aim = (target_position - global_position).normalized()
	if aim.is_zero_approx(): aim = Vector2.RIGHT
	proc_left = PROC_SECONDS
	proc_gate = RATE_LIMIT
	set_process(true)

func _process(delta: float) -> void:
	if health != null and bool(health.is_dead):
		visibility_mix = 0.0
		formation_left = 0.0
		proc_left = 0.0
		block_left = 0.0
		queue_redraw()
		foreground.queue_redraw()
		set_process(false)
		return
	clock = fmod(clock + delta, TAU * 100.0)
	var target_mix: float = 1.0 if desired_visible and pending_id == set_id else 0.0
	visibility_mix = move_toward(visibility_mix, target_mix, delta / 0.24)
	if visibility_mix <= 0.0 and pending_id != set_id:
		set_id = ""
		frames.clear()
		if desired_visible: _adopt_pending()
	formation_left = maxf(0.0, formation_left - delta)
	proc_left = maxf(0.0, proc_left - delta)
	block_left = maxf(0.0, block_left - delta)
	proc_gate = maxf(0.0, proc_gate - delta)
	var shield_target: float = 1.0 if set_id == "celestial_aegis" and shield_charges > 0 else 0.0
	shield_mix = move_toward(shield_mix, shield_target, delta / 0.25)
	queue_redraw()
	foreground.queue_redraw()
	if not desired_visible and visibility_mix <= 0.0: set_process(false)
	elif reduced and visibility_mix >= 1.0 and formation_left <= 0.0 and proc_left <= 0.0 and block_left <= 0.0 and is_equal_approx(shield_mix, shield_target):
		set_process(false)

func _smooth(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _burst(left: float, duration: float) -> float:
	if reduced or left <= 0.0: return 0.0
	var progress: float = 1.0 - left / duration
	return _smooth(progress / 0.15) * (1.0 - _smooth((progress - 0.20) / 0.80))

func _strength() -> float:
	return _smooth(visibility_mix)

func _clock(speed: float) -> float:
	return 0.0 if reduced else clock * speed

func _paint(node: Node2D, index: int, at: Vector2, size: Vector2, angle: float, alpha: float) -> void:
	if frames.size() != 4 or alpha <= 0.001: return
	node.draw_set_transform(at, angle, Vector2.ONE)
	node.draw_texture_rect(frames[index], Rect2(-size * 0.5, size), false, Color(1,1,1,clampf(minf(.96, alpha * OPACITY_BOOST) * _strength(),0,1)))
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	if set_id.is_empty() or frames.is_empty() or _strength() <= 0.001: return
	var form: float = _burst(formation_left, FORM_SECONDS)
	var proc: float = _burst(proc_left, PROC_SECONDS)
	var impact: float = _burst(block_left, BLOCK_SECONDS)
	var burst: float = maxf(form, maxf(proc, impact))
	var breath: float = 1.0 if reduced else 1.0 + 0.025 * sin(clock * 1.6)
	var radius: float = (104.0 + 36.0 * burst) * breath
	_paint(self, 0, Vector2(0,30), Vector2(radius, radius * 0.34), 0.0, 0.48 + burst * 0.38)
	# Wide ceremonial formation is brief. The idle halo leaves the body aperture
	# and incoming attack telegraphs readable; no broad opaque body wash.
	_paint(self, 1, Vector2(0,-6), Vector2.ONE * radius, _clock(-0.07), 0.22 + burst * 0.56 + shield_mix * 0.12)
	_draw_guardians(self, false, burst)
	if not reduced and burst > 0.01: _draw_filaments(burst)

func _draw_foreground() -> void:
	if set_id.is_empty() or frames.is_empty() or _strength() <= 0.001: return
	var burst: float = maxf(_burst(formation_left, FORM_SECONDS), _burst(proc_left, PROC_SECONDS))
	_paint(foreground, 2, Vector2(0,-56), Vector2(24,29) * (1.0 + burst * 0.20), 0.0, 0.84)
	_draw_guardians(foreground, true, burst)
	if block_left > 0.0 and not reduced: _draw_block_fragments()

func _draw_guardians(node: Node2D, front: bool, burst: float) -> void:
	var count: int = int(Art.SETS[set_id].orbit)
	var alpha: float = 0.42 + burst * 0.53
	if set_id == "celestial_aegis": alpha = 0.14 + maxf(shield_mix,burst) * 0.81
	var rx: float = 41.0 + burst * 16.0
	var ry: float = 24.0 + burst * 11.0
	for i: int in range(count):
		var angle: float = i * TAU / count + _clock(0.34)
		var depth: float = sin(angle)
		if (depth >= 0.0) != front: continue
		var at := Vector2(cos(angle) * rx, -8.0 + depth * ry)
		var turn: float = 0.0
		var size := Vector2(23,27) * (0.86 + 0.14 * (depth + 1.0) * 0.5)
		if set_id == "nine_heavens":
			turn = angle + PI * 0.5
			at.y += sin(_clock(1.8) + i) * 3.0
		elif set_id == "solar_meridian":
			turn = angle + PI * 0.5
			size *= 0.80 + burst * 0.5
		elif set_id == "vermilion_verdict":
			var converge: float = _burst(proc_left, PROC_SECONDS)
			at = at.lerp(aim * 47.0 + Vector2(0,-7), converge * 0.60)
			turn = lerp_angle(0.0, aim.angle() + PI * 0.5, converge)
		_paint(node, 3, at, size, turn, alpha)

func _draw_filaments(strength: float) -> void:
	var color: Color = Art.SETS[set_id].color
	# Fixed six strokes; no per-hit allocations, trails or unbounded particles.
	for i: int in range(6):
		var angle: float = i * TAU / 6.0 + clock * 0.18
		var points := PackedVector2Array()
		for step: int in range(9):
			var t: float = step / 8.0
			points.append(Vector2(cos(angle + t * 0.9) * (46 + t * 8), 27 - t * 68 + sin(angle) * 6))
		draw_polyline(points, Color(color, strength * _strength() * 0.36), 1.2, true)

func _draw_block_fragments() -> void:
	var t: float = clampf(1.0 - block_left / BLOCK_SECONDS, 0.0, 1.0)
	var opacity: float = (1.0 - _smooth(t)) * _strength()
	for i: int in range(8):
		var direction := Vector2.RIGHT.rotated(i * TAU / 8.0 + 0.2)
		var at: Vector2 = Vector2(0,-5) + direction * (35 + 26 * _smooth(t))
		_paint(foreground, 3, at, Vector2(8,10) * (1.0 - t * 0.5), i + t * 2, opacity)
	foreground.draw_arc(Vector2(0,-5), 36 + t * 29, 0, TAU, 40, Color(0.56,0.84,1,opacity * 0.65), 1.3, true)
