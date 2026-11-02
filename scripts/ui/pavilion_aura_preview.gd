extends Control
## Actual idle animation and the same aura geometry used by the live player.
const AuraVisual = preload("res://scripts/ui/pavilion_aura_visual.gd")
const FRAMES: SpriteFrames = preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
const ActorMaterial = preload("res://scripts/effects/premium_actor_material.gd")
var aura_id: String = "plain"
var clock: float = 0.0
var _tick: float = 0.0
var _fade: float = 1.0
var _visual = AuraVisual.new()
var _actor: AnimatedSprite2D
var _actor_material: ShaderMaterial
var _scale_value: float = 1.0
var _actor_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	_actor = AnimatedSprite2D.new()
	_actor.name = "AuraHeroIdle"
	_actor.sprite_frames = FRAMES
	_actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_actor)
	_actor_material = ActorMaterial.create(_actor, Color(0.42, 0.93, 0.90))
	_actor.frame_changed.connect(_sync_actor_frame)
	_actor.animation_changed.connect(_sync_actor_frame)
	resized.connect(_layout_actor)
	visibility_changed.connect(_sync_processing)
	SettingsManager.settings_changed.connect(_sync_processing)
	_layout_actor()
	_sync_processing()

func show_aura(next_id: String) -> void:
	var checked: String = next_id if next_id in AuraVisual.IDS else "plain"
	if aura_id == checked: return
	aura_id = checked
	clock = 0; _tick = 0
	_fade = 1.0 if SettingsManager.reduced_effects else 0.0
	queue_redraw()

func _layout_actor() -> void:
	if not is_instance_valid(_actor): return
	var side: float = minf(size.y * 0.80, size.x * 0.64)
	_scale_value = side / 96.0
	_actor_origin = Vector2(size.x * 0.5, size.y * 0.52)
	# Match the current production premium body: 1.12 scale, three pixels up.
	_actor.position = _actor_origin + Vector2(0, -3) * _scale_value
	_actor.scale = Vector2.ONE * _scale_value * 1.12
	queue_redraw()

func _sync_processing() -> void:
	set_process(is_visible_in_tree() and not SettingsManager.reduced_effects)
	if is_instance_valid(_actor):
		if is_visible_in_tree(): _actor.play("idle_down")
		else: _actor.pause()
	if SettingsManager.reduced_effects: _fade = 1.0
	if _actor_material != null: _actor_material.set_shader_parameter("rim_strength", 0.08 if SettingsManager.reduced_effects else 0.16)
	_sync_actor_frame()
	queue_redraw()

func _sync_actor_frame() -> void:
	if is_instance_valid(_actor) and _actor_material != null: ActorMaterial.sync_frame(_actor, _actor_material)

func _process(delta: float) -> void:
	var step: float = minf(delta, 0.1)
	clock = fposmod(clock + step, AuraVisual.PERIOD)
	_fade = minf(1.0, _fade + step / 0.24)
	_tick += step
	if _tick < 1.0 / 30.0: return
	_tick = 0.0
	queue_redraw()

func _draw() -> void:
	_visual.build(aura_id, clock, SettingsManager.reduced_effects)
	_visual.paint(self, _actor_origin, _scale_value, _fade)
