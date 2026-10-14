extends Node2D
const DefeatPresentation = preload("res://scripts/enemy/boss_defeat_presentation.gd")
const Catalog = preload("res://scripts/data/boss_premium_catalog.gd")
const ActorMaterial = preload("res://scripts/effects/premium_actor_material.gd")
var profile: Dictionary = {}
var sprite: AnimatedSprite2D
var _actor_material: ShaderMaterial
var age: float = 0.0
var phase_left: float = 0.0
var arrival_left: float = 0.85
var action_left: float = 0.0
var action_length: float = 0.3
var action_kind: String = ""
var phase: int = 1
var tick: float = 0.0

func _ready() -> void:
	var boss: Node = get_parent()
	profile = Catalog.get_profile(str(boss.encounter_display_name))
	if profile.is_empty(): set_process(false); return
	sprite = boss.get_node("AnimatedSprite2D") as AnimatedSprite2D
	z_index = 0
	_actor_material = ActorMaterial.create(sprite,profile.accent)
	sprite.frame_changed.connect(_sync_frame)
	sprite.animation_changed.connect(_sync_frame)
	_sync_frame()
	boss.phase_changed.connect(_on_phase)
	boss.boss_defeated.connect(_on_defeat)

func _sync_frame() -> void:
	ActorMaterial.sync_frame(sprite,_actor_material)
func _on_phase(value: int) -> void:
	phase = value
	phase_left = 0.9
func on_action(kind: String,duration: float) -> void:
	action_kind = kind
	action_length = maxf(duration,0.01)
	action_left = action_length
func _process(delta: float) -> void:
	if profile.is_empty(): return
	age += delta
	phase_left = maxf(0.0,phase_left-delta)
	arrival_left = maxf(0.0,arrival_left-delta)
	action_left = maxf(0.0,action_left-delta)
	tick -= delta
	if tick > 0.0: return
	tick = 1.0/(18.0 if SettingsManager.reduced_effects else 30.0)
	_actor_material.set_shader_parameter("rim_strength",0.08 if bool(get_parent().get_meta("frame_driven_boss",false)) else (0.35 if SettingsManager.reduced_effects else 0.8))
	_actor_material.set_shader_parameter("energy",0.0 if SettingsManager.reduced_effects else maxf(phase_left,action_left/action_length*0.6) * (0.2 if bool(get_parent().get_meta("frame_driven_boss",false)) else 1.0))
	queue_redraw()

func _draw() -> void:
	if profile.is_empty(): return
	var tint: Color = profile.accent
	var center: Vector2 = sprite.position+Vector2(0,-10)
	var reduced: bool = SettingsManager.reduced_effects
	var lift: float = 0.0 if reduced else sin(age*1.8)*3.0
	var strength: float = 0.12 if reduced else 0.22+(0.08 if phase == 2 else 0.0)
	# Vertical body crest is ornamental, never a floor hazard/attack radius.
	var theme: String = profile.theme
	var count: int = mini(3+int(profile.stage),8)
	_draw_identity_crest(center,tint,strength,reduced)
	if theme == "crimson_moon":
		for side: int in [-1,1]:
			draw_arc(center+Vector2(side*15,lift-5),48,PI*0.35,PI*1.65,24,Color(tint,strength),2.2,true)
	elif theme in ["nine_heavens","frostveil"]:
		for i: int in range(count):
			var angle: float = TAU*i/count+(0.0 if reduced else age*0.16)
			var at: Vector2 = center+Vector2(cos(angle)*43,sin(angle)*57+lift)
			draw_line(at-Vector2(5,0),at+Vector2(5,0),Color(tint,strength+0.2),1.4,true)
			draw_line(at-Vector2(0,7),at+Vector2(0,7),Color(tint,strength+0.2),1.4,true)
	else:
		for side: int in [-1,1]:
			var stem: Vector2 = center+Vector2(side*38,30)
			draw_line(stem,stem+Vector2(side*7,-58),Color(tint,strength),2,true)
			for leaf: int in range(mini(count,5)):
				var at: Vector2 = stem+Vector2(side*leaf*1.5,-leaf*11)
				draw_line(at,at+Vector2(side*12,-9),Color(tint,strength+0.05),2,true)
	if reduced: return
	var pulse: float = maxf(phase_left,arrival_left)
	if pulse > 0.0:
		for i: int in range(8):
			var angle: float = TAU*i/8.0
			var from: Vector2 = center+Vector2(cos(angle)*36,sin(angle)*42)
			var to: Vector2 = center+Vector2(cos(angle)*(36+24*(1-pulse)),sin(angle)*(42+24*(1-pulse)))
			draw_line(from,to,Color(tint,pulse*0.65),2,true)
	if action_left > 0.0 and not bool(get_parent().get_meta("frame_driven_boss",false)):
		var charge: float = 1.0-action_left/action_length
		_draw_action_crest(center, charge, tint)
		var radius: float = 28.0+charge*20.0
		for side: int in [-1,1]:
			draw_arc(center+Vector2(side*12,8),radius,PI*(0.4 if side == 1 else 1.4),PI*(1.0 if side == 1 else 2.0),16,Color(tint,0.45*sin(charge*PI)),2.4,true)


func _on_defeat() -> void:
	var world: Node = get_parent().get_parent()
	if not is_instance_valid(world) or world.is_queued_for_deletion(): return
	var remnant := DefeatPresentation.new()
	remnant.name = "PremiumBossDefeatRemnant"
	remnant.position = get_parent().position
	world.add_child(remnant)
	remnant.setup(sprite,profile.accent)

func _draw_action_crest(center: Vector2, progress: float, tint: Color) -> void:
	var alpha: float = sin(progress * PI) * 0.85
	var facing: float = -1.0 if bool(get_parent().facing_left) else 1.0
	var hand: Vector2 = center + Vector2(facing * 30, -12)
	if action_kind in ["melee", "shockwave"]:
		var tip: Vector2 = hand + Vector2(facing * (12 + progress * 25), -32)
		draw_line(hand, tip, Color(tint, alpha * 0.25), 9, true)
		draw_line(hand, tip, Color(tint.lightened(0.3), alpha), 2.8, true)
		draw_line(hand - Vector2(6,0), hand + Vector2(6,0), Color(tint,alpha), 2, true)
	elif action_kind == "lightning":
		var points := PackedVector2Array([hand,hand+Vector2(10,-13),hand+Vector2(-6,-29),hand+Vector2(5,-43)])
		draw_polyline(points,Color(tint,alpha * 0.22),8,true)
		draw_polyline(points,Color(tint.lightened(0.4),alpha),2,true)
	else:
		for index: int in range(3):
			var at: Vector2 = hand + Vector2((index-1)*11, -progress*18-8)
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(4,0),at+Vector2(0,6),at-Vector2(4,0)]),Color(tint,alpha * 0.7))


func _draw_identity_crest(center: Vector2, tint: Color, strength: float, reduced: bool) -> void:
	# Body-tight crest: distinct silhouettes, never a second danger radius.
	var stage: int=int(profile.stage)
	var top: Vector2=center+Vector2(0,-48)
	var ink:=Color(tint,strength+.12)
	match (stage-1)%5:
		0:
			draw_polyline(PackedVector2Array([top+Vector2(-12,8),top,top+Vector2(12,8)]),ink,2.0,true)
		1:
			draw_line(top+Vector2(-11,-5),top+Vector2(11,12),ink,1.8,true)
			draw_line(top+Vector2(11,-5),top+Vector2(-11,12),ink,1.8,true)
		2:
			draw_arc(top+Vector2(0,5),12,0,TAU,20,ink,1.8,true)
			for side: int in [-1,1]:draw_line(top+Vector2(side*15,5),top+Vector2(side*7,5),ink,1.5,true)
		3:
			draw_polyline(PackedVector2Array([top+Vector2(0,-10),top+Vector2(9,2),top+Vector2(-4,2),top+Vector2(2,15)]),ink,2.0,true)
		4:
			draw_polyline(PackedVector2Array([top+Vector2(-18,8),top+Vector2(-15,-7),top+Vector2(-7,2),top+Vector2(0,-13),top+Vector2(7,2),top+Vector2(15,-7),top+Vector2(18,8)]),ink,2.1,true)
	if not reduced and action_left>0.0:
		var value: float=sin((1.0-action_left/action_length)*PI)
		draw_circle(top,3.0,Color(tint,value*.6))
