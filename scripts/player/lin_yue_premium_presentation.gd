extends Node2D

## Body styling and locomotion only; paid aura/cultivation effects keep their owners.
const ActorMaterial = preload("res://scripts/effects/premium_actor_material.gd")
const GHOST_COUNT: int = 4
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
var sample_left: float = 0.0
var tick_left: float = 0.0
var ghosts: Array[Sprite2D] = []
var ghost_positions: Array[Vector2] = []
var ghost_times: Array[float] = []
var steps: Array[Dictionary] = []
var cursor: int = 0
var step_cursor: int = 0
var last_position: Vector2
var walked: float = 0.0

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
	for i: int in range(GHOST_COUNT):
		var ghost := Sprite2D.new()
		ghost.visible = false
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(ghost)
		ghosts.append(ghost)
		ghost_positions.append(Vector2.ZERO)
		ghost_times.append(0.0)
	for i: int in range(STEP_COUNT): steps.append({"left":0.0,"position":Vector2.ZERO})
	var weapons: Node = actor.get_node_or_null("WeaponManager")
	if weapons != null: weapons.weapon_attack_triggered.connect(_on_cast)
	var health: Node = actor.get_node_or_null("PlayerHealth")
	if health != null:
		last_health = float(health.current_health)
		health.health_changed.connect(_on_health_changed)

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
	sample_left -= delta
	var moving: bool = actor.velocity.length_squared() > 16.0
	if moving and not SettingsManager.reduced_effects and sample_left <= 0.0:
		sample_left = 0.075
		var ghost: Sprite2D = ghosts[cursor]
		ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame)
		ghost.scale = sprite.scale
		ghost.rotation = sprite.rotation
		ghost.flip_h = sprite.flip_h
		ghost_positions[cursor] = sprite.global_position
		ghost_times[cursor] = 0.22
		cursor = (cursor+1)%GHOST_COUNT
	if moving and walked >= 28.0 and not SettingsManager.reduced_effects:
		walked = 0.0
		steps[step_cursor] = {"left":0.34,"position":actor.global_position+Vector2(5+(-7 if step_cursor%2 == 0 else 7),19)}
		step_cursor = (step_cursor+1)%STEP_COUNT
	for i: int in range(GHOST_COUNT):
		ghost_times[i] = maxf(0.0,ghost_times[i]-delta)
		ghosts[i].visible = ghost_times[i] > 0.0 and not SettingsManager.reduced_effects
		if ghosts[i].visible:
			ghosts[i].global_position = ghost_positions[i]
			ghosts[i].modulate = Color(0.30,0.90,0.91,ghost_times[i]/0.22*0.18)
	for step: Dictionary in steps: step.left = maxf(0.0,float(step.left)-delta)
	tick_left -= delta
	if tick_left > 0.0: return
	tick_left = 1.0/30.0
	var motion: float = 0.0 if SettingsManager.reduced_effects else 1.0
	var cast: float = sin((1.0-cast_left/0.25)*PI) if cast_left > 0.0 else 0.0
	var stride: float = sin(age*13.0) if moving else sin(age*2.4)*0.25
	var lean: float = clampf(actor.velocity.x/240.0,-1.0,1.0)
	sprite.scale = base_scale*Vector2(1.0+cast*0.055*motion,1.0-cast*0.035*motion)
	sprite.position = base_position+Vector2(-lean*1.8,-absf(stride)*1.7-cast*2.0)*motion
	sprite.rotation = (-lean*0.065+cast*0.025)*motion
	_actor_material.set_shader_parameter("accent",Color(1.0,0.69,0.28) if hurt_left > 0.0 else Color(0.42,0.93,0.90))
	_actor_material.set_shader_parameter("energy",maxf(cast*0.65,hurt_left/0.18*0.55)*motion)
	_actor_material.set_shader_parameter("rim_strength",0.3 if SettingsManager.reduced_effects else 0.65)
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
	if current < last_health: hurt_left = 0.18
	last_health = current
