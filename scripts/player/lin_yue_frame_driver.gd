extends RefCounted
## Distance drives authored poses; turning retains phase, blocked input settles.
const STRIDE_DISTANCE: float = 112.0
const HURT_SECONDS: float = 0.20
var sprite: AnimatedSprite2D
var phase: float = 0.0
var hurt_left: float = 0.0
func setup(target: AnimatedSprite2D) -> void: sprite=target
func react_to_hit() -> void: hurt_left=HURT_SECONDS
func advance(delta: float, facing: String, distance: float) -> void:
	if distance>0.01: phase=fposmod(phase+distance/STRIDE_DISTANCE,1.0)
	if hurt_left>0.0:
		hurt_left=maxf(0,hurt_left-delta)
		if hurt_left>0.0:
			_pose("hurt_"+facing,1.0-hurt_left/HURT_SECONDS)
			return
	if distance>0.01: _pose("walk_"+facing,phase)
	else:
		var idle:=StringName("idle_"+facing)
		if sprite.animation!=idle or not sprite.is_playing(): sprite.play(idle)
func _pose(animation: StringName, progress: float) -> void:
	if not sprite.sprite_frames.has_animation(animation): return
	sprite.animation=animation;sprite.pause()
	var count: int=sprite.sprite_frames.get_frame_count(animation)
	sprite.set_frame_and_progress(mini(count-1,int(progress*count)),fposmod(progress*count,1.0))
