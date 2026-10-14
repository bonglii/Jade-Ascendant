extends Node2D
## Actor cast/assassin/guardian cues read production state, never damage logic.
const Art = preload("res://scripts/effects/combat_cel_art.gd")
const MAX_INSTANCES: int = 64
static var active: int = 0
var kind: String = ""
var actor: Node2D
var tick: float = 0.0
var age: float = 0.0
var pulse_left: float = 0.0
var pulse_radius: float = 0.0
static func install(owner_actor: Node2D, role: String) -> void:
	if active >= MAX_INSTANCES or owner_actor.has_node("AttackPresence"): return
	var fx: Node2D = load("res://scripts/enemy/regular_attack_presence.gd").new()
	fx.kind = role
	fx.name = "AttackPresence"
	owner_actor.add_child(fx)
func _ready() -> void:
	active += 1
	actor = get_parent() as Node2D
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if kind == "guardian":
		material = Art.palette(preload("res://scripts/data/boss_premium_catalog.gd").theme_color(str(actor.presentation_theme)))
func _exit_tree() -> void: active = maxi(0,active-1)
func pulse(radius: float) -> void:
	pulse_radius = radius
	pulse_left = .30
	queue_redraw()
func _process(delta: float) -> void:
	age += delta
	pulse_left = maxf(0,pulse_left-delta)
	tick -= delta
	if tick <= 0:
		tick = 1.0 / 30.0
		queue_redraw()
func _draw() -> void:
	if actor == null or bool(actor.is_dead): return
	var reduced: bool = SettingsManager.reduced_effects
	if kind == "guardian":
		if bool(actor.is_pulse_winding_up):
			if not reduced: Art.paint(self,"hostile",0,Vector2.ZERO,Vector2.ONE*float(actor.qi_pulse_radius)*1.65,age*.12,.46)
		if pulse_left > 0:
			var t: float = 1.0-pulse_left/.30
			Art.paint(self,"hostile",3,Vector2.ZERO,Vector2.ONE*pulse_radius*lerpf(.6,1.9,t),t*.1,(1.0-t)*(.45 if reduced else .90))
		return
	if kind == "assassin" and bool(actor.is_winding_up):
		var dir: Vector2 = actor.dash_direction
		var length: float = float(actor.dash_speed) * float(actor.dash_duration)
		# A narrow directional cue, not a claimed rectangular hitbox. Sweep
		# follows the real locked dash direction, with no retarget on release.
		var points := PackedVector2Array([dir*18,dir*minf(length,110)])
		draw_polyline(points,Color(1,.49,.39,.60),2,true)
		if not reduced: Art.paint(self,"impacts",7,dir*25,Vector2(40,20),dir.angle()-PI*.25,.48)
	elif kind == "assassin" and bool(actor.is_dashing) and not reduced:
		Art.paint(self,"impacts",0,-actor.dash_direction*22,Vector2(55,23),actor.dash_direction.angle(),.32)
	elif kind == "ranged" and float(actor.cast_visual_timer)>0.0:
		var at: Vector2 = Vector2(-20 if bool(actor.facing_left) else 20,-18)
		Art.paint(self,"hostile",0,at,Vector2.ONE*30,age*.60,.66 if not reduced else .35)
