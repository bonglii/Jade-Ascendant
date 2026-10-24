extends Node2D

## One bounded, pause-aware telegraph and one damage event.
## 1 = Ward Seal (Chapter 1)
## 2 = Marked Lightning (Chapter 1)
## 3 = Moonbrand (Chapter 2)
## 4 = Cinnabar Burst (Chapter 2)
## 5 = Starfall Seal (Chapter 3)
## 6 = Heavenly Rift (Chapter 3)
const CelArt=preload("res://scripts/effects/combat_cel_art.gd")
var hazard_kind: int = 1
var accent: Color = Color(0.85, 0.73, 0.34)
var radius: float = 64.0
var warning_duration: float = 1.25
var elapsed: float = 0.0
var impacted: bool = false
# Presentation redraw only; damage timing is evaluated every process frame.
const VISUAL_REFRESH_INTERVAL: float = 1.0 / 30.0
var _visual_refresh_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("enemy_attack")
	add_to_group("stage_hazard")
	z_index = 6
	match hazard_kind:
		2:
			radius = 58.0
			warning_duration = 1.1
		3:
			radius = 66.0
			warning_duration = 1.15
		4:
			radius = 52.0
			warning_duration = 0.90
		5:
			radius = 62.0
			warning_duration = 1.05
		6:
			radius = 50.0
			warning_duration = 0.85
	material=CelArt.palette(_get_warning_color())
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var impact_started: bool = false
	if not impacted and elapsed >= warning_duration:
		impacted = true
		impact_started = true
		_apply_impact()
	if elapsed >= warning_duration + 0.22:
		queue_free()
		return

	# The precise hit event above is never throttled. Only the telegraph
	# animation is redrawn at most 30 times per second on a 60 FPS device;
	# the hit frame is always drawn immediately.
	_visual_refresh_elapsed += delta
	if _visual_refresh_elapsed >= VISUAL_REFRESH_INTERVAL or impact_started:
		_visual_refresh_elapsed = fmod(
			_visual_refresh_elapsed,
			VISUAL_REFRESH_INTERVAL
		)
		queue_redraw()

func _apply_impact() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return
	if global_position.distance_squared_to(player.global_position) > radius * radius:
		return
	var health: PlayerHealth = player.get_node_or_null("PlayerHealth") as PlayerHealth
	if health != null:
		health.take_damage(_get_impact_damage())

func _get_impact_damage() -> float:
	match hazard_kind:
		2:
			return 6.0
		3:
			return 7.0
		4:
			return 8.0
		5:
			return 9.0
		6:
			return 10.0
		_:
			return 5.0

func _get_warning_color() -> Color:
	match hazard_kind:
		3:
			# Pale scarlet/peach linework stays readable over dark crimson terrain.
			return Color(1.0, 0.48, 0.50, 0.95)
		4:
			return Color(1.0, 0.62, 0.34, 0.95)
		5:
			# Chapter 3 hostile astral danger is amethyst, never player cyan/jade.
			return Color(0.94, 0.58, 1.0, 0.96)
		6:
			return Color(1.0, 0.50, 0.82, 0.97)
		_:
			# Preserve Chapter 1 danger language.
			return Color(1.0, 0.71, 0.33, 0.90)

func _draw() -> void:
	var warning: Color=_get_warning_color()
	var reduced: bool=SettingsManager.reduced_effects
	if impacted:
		var t: float=clampf((elapsed-warning_duration)/.22,0,1)
		var fade: float=pow(1.0-t,1.4)
		CelArt.paint(self,"hostile",3,Vector2.ZERO,Vector2.ONE*radius*lerpf(1.3,2.0,t),t*.18,fade*(.55 if reduced else .88))
		if hazard_kind==2 and not reduced:
			CelArt.paint(self,"hostile",2,Vector2(0,-radius*.75),Vector2(radius*1.1,radius*2.1),0,fade)
		return
	var progress: float=clampf(elapsed/maxf(warning_duration,.01),0,1)
	# Painted danger seal; the thin boundary always remains the real hit radius.
	draw_circle(Vector2.ZERO,radius,Color(warning,.055+progress*.045))
	CelArt.paint(self,"hostile",0,Vector2.ZERO,Vector2.ONE*radius*2.0,sin(elapsed*.8)*.035,.48+progress*.32)
	draw_arc(Vector2.ZERO,radius,0,TAU,48,Color(warning,.72+progress*.23),1.8,true)
	if not reduced:
		var frames: Array[int]=[6,2,7,1,4,7]
		CelArt.paint(self,"impacts",frames[clampi(hazard_kind-1,0,5)],Vector2.ZERO,Vector2.ONE*radius*.90,0,.38+progress*.35)
