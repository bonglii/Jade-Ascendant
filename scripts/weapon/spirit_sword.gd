extends Area2D

signal critical_hit_confirmed(
	source_projectile: Area2D,
	hit_enemy: Node2D,
	hit_position: Vector2
)

## Spirit Sword Projectile
## Original player projectiles are aligned to Player/CombatOrigin.
## Resonance projectiles intentionally retain their actual hit position.

const SPIRIT_SWORD_IMPACT_SCENE: PackedScene = preload(
	"res://scenes/weapons/spirit_sword_impact.tscn"
)

@export var speed: float = 500.0
@export var damage: float = 10.0
@export var attack_cooldown: float = 1.0

var attack_timer: float = 0.0
var direction: Vector2 = Vector2.ZERO

var is_critical: bool = false
var is_resonance_projectile: bool = false
var resonance_triggered: bool = false

var pierce: int = 0
var lifetime: float = 4.0
var hit_ids: Array[int] = []
var consumed: bool = false
var combat_profile: Dictionary = {}
var combat_style_id: StringName = &"spirit_sword"


func configure_combat_profile(profile: Dictionary) -> void:
	combat_profile = profile.duplicate(true)
	combat_style_id = StringName(str(combat_profile.get("style_id", "spirit_sword")))
	if is_node_ready():
		_apply_combat_profile()


func _ready() -> void:
	_apply_combat_profile()


func _apply_combat_profile() -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var glow := get_node_or_null("QiTrailGlow") as Line2D
	var trail := get_node_or_null("QiTrail") as Line2D
	var core := get_node_or_null("QiTrailCore") as Line2D

	if sprite != null:
		sprite.visible = bool(combat_profile.get("sprite_visible", true))
		var sprite_tint: Color = combat_profile.get("sprite_tint", Color.WHITE)
		sprite.modulate = sprite_tint
	if glow != null:
		glow.default_color = combat_profile.get("trail_glow", glow.default_color)
		glow.width = float(combat_profile.get("trail_glow_width", 12.0))
	if trail != null:
		trail.default_color = combat_profile.get("trail_main", trail.default_color)
		trail.width = float(combat_profile.get("trail_main_width", 5.5))
	if core != null:
		core.default_color = combat_profile.get("trail_core", core.default_color)
		core.width = float(combat_profile.get("trail_core_width", 2.0))

	queue_redraw()


func _draw() -> void:
	var motif: String = str(combat_profile.get("motif", "none"))
	if motif == "none":
		return

	var main_color: Color = combat_profile.get(
		"trail_main",
		Color(0.27, 0.90, 0.85, 0.38)
	)
	var core_color: Color = combat_profile.get(
		"trail_core",
		Color(0.78, 1.0, 0.94, 0.72)
	)

	match motif:
		"jade_mark":
			draw_polyline(
				PackedVector2Array([
					Vector2(-9.0, 0.0),
					Vector2(-3.0, -6.0),
					Vector2(3.0, 0.0),
					Vector2(-3.0, 6.0),
					Vector2(-9.0, 0.0)
				]),
				core_color,
				1.4,
				true
			)
		"mist_ribbons":
			draw_arc(
				Vector2(-8.0, -3.0), 21.0, -0.62, 0.42, 18,
				Color(main_color.r, main_color.g, main_color.b, 0.34),
				2.2, true
			)
			draw_arc(
				Vector2(-12.0, 5.0), 27.0, -0.42, 0.52, 20,
				Color(core_color.r, core_color.g, core_color.b, 0.18),
				4.6, true
			)
		"seal_fan":
			var fan_origin := Vector2(-8.0, 0.0)
			draw_arc(
				fan_origin, 19.0, -0.72, 0.72, 24,
				core_color, 3.0, true
			)
			for fan_angle in [-0.66, -0.33, 0.0, 0.33, 0.66]:
				draw_line(
					fan_origin,
					fan_origin + Vector2.from_angle(float(fan_angle)) * 18.0,
					main_color,
					1.4,
					true
				)
			draw_circle(fan_origin, 2.4, core_color)
		"moon_saber":
			draw_arc(
				Vector2(-5.0, 0.0), 25.0, -0.58, 0.58, 24,
				main_color, 3.0, true
			)
			draw_arc(
				Vector2(-8.0, 0.0), 31.0, -0.46, 0.46, 22,
				Color(core_color.r, core_color.g, core_color.b, 0.42),
				1.3, true
			)
		"star_sword":
			var star_center := Vector2(-4.0, 0.0)
			draw_line(star_center + Vector2(-9.0, 0.0), star_center + Vector2(9.0, 0.0), core_color, 1.7, true)
			draw_line(star_center + Vector2(0.0, -9.0), star_center + Vector2(0.0, 9.0), core_color, 1.7, true)
			draw_line(star_center + Vector2(-6.0, -6.0), star_center + Vector2(6.0, 6.0), main_color, 1.0, true)
			draw_line(star_center + Vector2(-6.0, 6.0), star_center + Vector2(6.0, -6.0), main_color, 1.0, true)
		"ward_jian":
			var ward_center := Vector2(-6.0, 0.0)
			var ward_points := PackedVector2Array()
			for index in range(7):
				var angle: float = float(index) * TAU / 6.0
				ward_points.append(ward_center + Vector2.from_angle(angle) * 11.0)
			draw_polyline(ward_points, main_color, 1.8, true)
			draw_line(ward_center + Vector2(-7.0, 0.0), ward_center + Vector2(7.0, 0.0), core_color, 1.4, true)
		"mirror_blade":
			draw_arc(Vector2(-7.0, -5.0), 22.0, -0.52, 0.40, 20, main_color, 1.7, true)
			draw_arc(Vector2(-7.0, 5.0), 22.0, -0.40, 0.52, 20, core_color, 1.7, true)
			draw_line(Vector2(-22.0, -7.0), Vector2(8.0, 7.0), Color(core_color.r, core_color.g, core_color.b, 0.34), 1.2, true)
		"sunfire_dragon":
			draw_arc(Vector2(-7.0, 0.0), 24.0, -0.70, 0.42, 24, main_color, 3.0, true)
			draw_arc(Vector2(-11.0, 1.0), 31.0, -0.48, 0.30, 22, Color(core_color.r, core_color.g, core_color.b, 0.52), 1.6, true)
			for ray_y in [-8.0, 0.0, 8.0]:
				draw_line(Vector2(-10.0, ray_y), Vector2(8.0, ray_y * 0.45), core_color, 1.2, true)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	position += direction * speed * delta


func setup(target_position: Vector2) -> void:
	if not is_resonance_projectile:
		_align_original_spawn_to_combat_origin()

	direction = global_position.direction_to(
		target_position
	)

	rotation = direction.angle()


func _align_original_spawn_to_combat_origin() -> void:
	var player := (
		get_tree().get_first_node_in_group("player")
		as Node2D
	)
	if player == null:
		return

	var combat_origin := (
		player.get_node_or_null("CombatOrigin")
		as Node2D
	)
	if combat_origin == null:
		return

	# Preserve the existing secondary-projectile perpendicular spawn offset.
	var existing_spawn_offset: Vector2 = (
		global_position - player.global_position
	)
	global_position = (
		combat_origin.global_position
		+ existing_spawn_offset
	)


func mark_resonance_triggered() -> void:
	resonance_triggered = true


func run_resonance_guard_test() -> bool:
	if is_resonance_projectile:
		return false

	var original_is_critical: bool = is_critical
	var original_resonance_triggered: bool = resonance_triggered

	is_critical = true
	resonance_triggered = true

	var guard_active: bool = resonance_triggered

	if guard_active:
		DebugLogger.combat(
			"SPIRIT SWORD | Resonance already triggered."
		)

	is_critical = original_is_critical
	resonance_triggered = original_resonance_triggered

	return guard_active


func _on_body_entered(body: Node2D) -> void:
	if (
		consumed
		or not body.is_in_group("enemy")
		or body.get_instance_id() in hit_ids
	):
		return

	hit_ids.append(body.get_instance_id())

	CombatFeedback.mark_next_hit_critical(body, is_critical)
	body.take_damage(damage)
	spawn_hit_visual()

	if is_critical:
		DebugLogger.combat(
			"SPIRIT SWORD ACTUAL CRITICAL HIT CONFIRMED"
		)

	try_emit_critical_hit(body)

	if pierce > 0:
		pierce -= 1
		return

	consumed = true
	queue_free()


func spawn_hit_visual() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return

	var effect := (
		SPIRIT_SWORD_IMPACT_SCENE.instantiate()
		as SpiritSwordImpact
	)
	if effect == null:
		return

	current_scene.add_child(effect)
	effect.global_position = global_position
	effect.setup(
		is_critical,
		is_resonance_projectile,
		combat_profile
	)


func try_emit_critical_hit(hit_enemy: Node2D) -> void:
	if not is_critical:
		return

	if is_resonance_projectile:
		DebugLogger.combat(
			"RESONANCE PROJECTILE | Chain blocked."
		)
		return

	if resonance_triggered:
		DebugLogger.combat(
			"SPIRIT SWORD | Resonance already triggered."
		)
		return

	DebugLogger.combat(
		"SPIRIT SWORD | Emitting critical_hit_confirmed."
	)

	critical_hit_confirmed.emit(
		self,
		hit_enemy,
		global_position
	)
