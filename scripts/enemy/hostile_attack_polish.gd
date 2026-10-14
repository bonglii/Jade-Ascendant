class_name HostileAttackPolish
extends Node2D
## Painted ornament only. Hostile radius, damage, target lock and impact timer
## remain owned by the parent. Actual boundary stays visible even at VFX cap.
const Catalog = preload("res://scripts/data/boss_premium_catalog.gd")
const Art = preload("res://scripts/effects/combat_cel_art.gd")
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
	if owner_attack.has_node("HostileAttackPolish") or active_instances >= MAX_INSTANCES: return
	if str(owner_attack.presentation_theme) not in ["jade_valley","crimson_moon","nine_heavens","storm","verdant_qi","frostveil","solar_nirvana"]: return
	var fx: Node2D = (load("res://scripts/enemy/hostile_attack_polish.gd") as GDScript).new()
	fx.name = "HostileAttackPolish"
	fx.kind = effect_kind
	owner_attack.add_child(fx)
func _ready() -> void:
	active_instances += 1
	registered = true
	attack = get_parent() as Node2D
	tint = Catalog.theme_color(str(attack.presentation_theme))
	material = Art.palette(tint)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	var reduced: bool = SettingsManager.reduced_effects
	if kind == "projectile":
		Art.paint(self,"hostile",1,Vector2(-7,0),Vector2(48,30) if not reduced else Vector2(34,22),0,.94)
		return
	var radius: float = float(attack.strike_radius if kind == "lightning" else attack.explosion_radius if kind == "explosion" else attack.shockwave_radius)
	if not bool(attack.has_impacted):
		if reduced: return # Mandatory real-radius warning is drawn by parent.
		var progress: float = clampf(age/maxf(float(attack.telegraph_duration),.01),0,1)
		Art.paint(self,"hostile",0,Vector2.ZERO,Vector2.ONE*radius*1.68,age*.18,.25+progress*.35)
		return
	var fade: float = pow(clampf(1.0-impact_age/.22,0,1),1.4)
	Art.paint(self,"hostile",3,Vector2.ZERO,Vector2.ONE*radius*lerpf(.9,1.95,clampf(impact_age/.18,0,1)),impact_age*.22,fade*(.40 if reduced else .90))
	if kind == "lightning" and not reduced:
		Art.paint(self,"hostile",2,Vector2(0,-85),Vector2(115,205),0,fade)
