class_name HostileAttackPolish
extends Node2D

## Decorative emission/impact only. The parent owns all timing/radius/damage.
const Catalog = preload("res://scripts/data/boss_premium_catalog.gd")
const MAX_INSTANCES: int = 64
static var active_instances: int = 0
var kind: String = "projectile"
var age: float = 0.0
var tick: float = 0.0
var attack: Node2D
var tint: Color
var registered: bool = false
var impact_age: float = 0.0
static func install(owner_attack: Node2D, effect_kind: String) -> void:
	if str(owner_attack.presentation_theme) not in ["jade_valley","crimson_moon","nine_heavens","storm","verdant_qi","frostveil","solar_nirvana"]:
		return
	if active_instances >= MAX_INSTANCES: return
	var fx: Node2D = (load("res://scripts/enemy/hostile_attack_polish.gd") as GDScript).new()
	fx.kind = effect_kind
	owner_attack.add_child(fx)
func _ready() -> void:
	active_instances += 1
	registered = true
	attack = get_parent() as Node2D
	tint = Catalog.theme_color(str(attack.presentation_theme))
	z_index = 6
func _exit_tree() -> void:
	if registered: active_instances = maxi(0,active_instances-1)
func _process(delta: float) -> void:
	age += delta
	if kind != "projectile" and bool(attack.has_impacted): impact_age += delta
	tick -= delta
	if tick > 0.0: return
	tick = 1.0/(18.0 if SettingsManager.reduced_effects else 30.0)
	queue_redraw()
func _draw() -> void:
	if attack == null: return
	if kind == "projectile":
		var direction: Vector2 = attack.direction.rotated(-attack.global_rotation)
		var tail: float = 12.0 if SettingsManager.reduced_effects else 36.0
		var to: Vector2 = -direction*tail
		if not SettingsManager.reduced_effects:
			draw_line(Vector2.ZERO,to,Color(tint,0.13),11,true)
			draw_line(Vector2.ZERO,to*0.75,Color(tint,0.35),4.5,true)
		draw_line(Vector2.ZERO,to*0.50,Color(tint,0.88),1.6,true)
		return
	var impacted: bool = bool(attack.has_impacted)
	var radius: float = float(attack.strike_radius if kind == "lightning" else attack.explosion_radius if kind == "explosion" else attack.shockwave_radius)
	if not impacted:
		# Tiny inward ticks sit ON the actual danger boundary; no second radius.
		var progress: float = clampf(age/maxf(float(attack.telegraph_duration),0.01),0,1)
		var count: int = 4 if SettingsManager.reduced_effects else 8
		for i: int in range(count):
			var direction: Vector2 = Vector2.RIGHT.rotated(TAU*i/count)
			draw_line(direction*(radius-7),direction*radius,Color(tint,0.35+progress*0.5),2,true)
		if not SettingsManager.reduced_effects:
			draw_arc(Vector2.ZERO,radius-3,-PI/2,-PI/2+TAU*progress,32,Color(tint,0.55),1.4,true)
		return
	if SettingsManager.reduced_effects: return
	var fade: float = clampf(1.0-impact_age/0.22,0.0,1.0)
	if kind == "lightning":
		# A fixed branching bolt with layered core. No extra particles/nodes.
		var trunk:=PackedVector2Array([Vector2(3,-220),Vector2(-11,-175),Vector2(8,-137),Vector2(-9,-92),Vector2(5,-48),Vector2.ZERO])
		draw_polyline(trunk,Color(tint,.10*fade),19,true)
		draw_polyline(trunk,Color(tint,.38*fade),7,true)
		draw_polyline(trunk,Color(tint.lightened(.65),.96*fade),2.4,true)
		for side: int in [-1,1]:
			var branch:=PackedVector2Array([Vector2(-9,-92),Vector2(side*29,-112),Vector2(side*45,-151)])
			draw_polyline(branch,Color(tint,.56*fade),1.7,true)
		draw_arc(Vector2.ZERO,radius*.65,0,TAU,28,Color(tint,.48*fade),2.4,true)

	else:
		for i: int in range(10):
			var direction: Vector2 = Vector2.RIGHT.rotated(TAU*i/10.0)
			draw_line(direction*radius*0.65,direction*radius*0.95,Color(tint,0.38*fade),2,true)
