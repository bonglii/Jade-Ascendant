extends Node2D

## Body styling and locomotion only; paid aura/cultivation effects keep their owners.
const ActorMaterial = preload("res://scripts/effects/premium_actor_material.gd")
const STEP_COUNT: int = 6
var sprite: AnimatedSprite2D
var actor: CharacterBody2D
var _actor_material: ShaderMaterial
var base_scale: Vector2
var base_position: Vector2
var cast_left: float = 0.0
var hurt_left: float = 0.0
var last_health: float = 0.0
var age: float = 0.0
var tick_left: float = 0.0
var steps: Array[Dictionary] = []
var step_cursor: int = 0
var last_position: Vector2
var walked: float = 0.0
var stride_phase: float = 0.0
var stride_strength: float = 0.0

func _ready() -> void:
	actor = get_parent() as CharacterBody2D
	sprite = actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null: set_process(false); return
	z_index = 2
	base_scale = sprite.scale * 1.12
	base_position = sprite.position + Vector2(0,-3)
	sprite.scale = base_scale
	sprite.position = base_position
	_actor_material = ActorMaterial.create(sprite, Color(0.42,0.93,0.90))
	sprite.frame_changed.connect(_sync_frame)
	sprite.animation_changed.connect(_sync_frame)
	_sync_frame()
	last_position = actor.global_position
	for i: int in range(STEP_COUNT): steps.append({"left":0.0,"position":Vector2.ZERO})
	var weapons: Node = actor.get_node_or_null("WeaponManager")
	if weapons != null: weapons.weapon_attack_triggered.connect(_on_cast)
	var health: Node = actor.get_node_or_null("PlayerHealth")
	if health != null:
		last_health = float(health.current_health)
		health.health_changed.connect(_on_health_changed)
		health.died.connect(_on_death)

func _sync_frame() -> void:
	if _actor_material != null: ActorMaterial.sync_frame(sprite,_actor_material)

func _on_cast(_weapon: String, _target: Vector2) -> void:
	cast_left = 0.25

func _process(delta: float) -> void:
	age += delta
	cast_left = maxf(0.0,cast_left-delta)
	hurt_left = maxf(0.0,hurt_left-delta)
	var distance: float = actor.global_position.distance_to(last_position)
	last_position = actor.global_position
	walked += distance
	stride_phase = fmod(stride_phase + minf(distance, 32.0) * TAU / 88.0, TAU)
	stride_strength = move_toward(stride_strength, 1.0 if distance > 0.05 else 0.0, delta * 12.0)
	var moving: bool = distance > 0.05 and actor.velocity.length_squared() > 16.0
	if moving and walked >= 56.0 and not SettingsManager.reduced_effects:
		walked = 0.0
		steps[step_cursor] = {"left":0.34,"position":actor.global_position+Vector2(5+(-7 if step_cursor%2 == 0 else 7),19)}
		step_cursor = (step_cursor+1)%STEP_COUNT
	for step: Dictionary in steps: step.left = maxf(0.0,float(step.left)-delta)
	tick_left -= delta
	if tick_left > 0.0: return
	tick_left = 1.0/30.0
	var motion: float = 0.0 if SettingsManager.reduced_effects else 1.0
	var cast: float = sin((1.0-cast_left/0.25)*PI) if cast_left > 0.0 else 0.0
	# Authored frames own the body; planted boots must not be displaced twice.
	sprite.scale = base_scale
	sprite.position = base_position
	sprite.rotation = 0.0
	_actor_material.set_shader_parameter("accent",Color(1.0,0.69,0.28) if hurt_left > 0.0 else Color(0.42,0.93,0.90))
	_actor_material.set_shader_parameter("energy",maxf(cast*0.65,hurt_left/0.18*0.55)*motion)
	_actor_material.set_shader_parameter("rim_strength",0.08 if SettingsManager.reduced_effects else 0.16)
	_actor_material.set_shader_parameter("stride_phase", stride_phase)
	_actor_material.set_shader_parameter("stride_strength", 0.0)
	_actor_material.set_shader_parameter("side_facing", 1.0 if actor.facing_direction in ["left", "right"] else 0.0)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(5,18),0,Vector2(1,0.36))
	draw_circle(Vector2.ZERO,21,Color(0,0.012,0.018,0.32))
	draw_set_transform(Vector2.ZERO)
	if SettingsManager.reduced_effects: return
	for step: Dictionary in steps:
		var left: float = float(step.left)
		if left <= 0.0: continue
		var at: Vector2 = to_local(step.position)
		var color := Color(0.44,0.94,0.87,left/0.34*0.42)
		draw_line(at-Vector2(4,0),at+Vector2(4,0),color,1.4,true)
		draw_line(at-Vector2(0,4),at+Vector2(0,4),color,1.4,true)


func _on_health_changed(current: float, _maximum: float) -> void:
	if current < last_health:
		hurt_left = 0.18
		if actor.has_method("request_hurt_pose"): actor.request_hurt_pose()
	last_health = current

func _on_death() -> void:
	var farewell := AnimatedSprite2D.new()
	farewell.name="LinYueDefeatPose"
	farewell.process_mode=Node.PROCESS_MODE_ALWAYS
	farewell.sprite_frames=sprite.sprite_frames
	farewell.texture_filter=sprite.texture_filter
	farewell.z_index=sprite.z_index
	actor.get_parent().add_child(farewell)
	farewell.global_position=sprite.global_position
	farewell.scale=base_scale
	farewell.animation_finished.connect(farewell.queue_free)
	farewell.play("death_down")
