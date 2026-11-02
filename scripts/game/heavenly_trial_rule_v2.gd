extends Node2D
## Frozen pattern geometry. Reduced effects never remove the safe boundary.
var theme_id: String = "jade_wind"
var tier: int = 1
var clock: float = 0.0
var hit_mask: int = 0
var axis: float = 0.0
var _redraw: float = 0.0
var _ink := Color("8ad7af")
const WARNINGS := {"jade_wind":1.4,"scarlet_rite":1.55,"starfall":1.25,"froststep":1.8,"sunforge":1.65}
func _ready() -> void:
	add_to_group("enemy_attack")
	add_to_group("heavenly_pattern")
	z_index = 5
	_ink = {"scarlet_rite":Color("ff877b"),"starfall":Color("dfabff"),"froststep":Color("a5dcff"),"sunforge":Color("ffd17c")}.get(theme_id,Color("8ad7af"))
func marks() -> Array[Vector2]:
	if theme_id == "starfall": return [Vector2.ZERO,Vector2(125,-80).rotated(axis),Vector2(-125,-80).rotated(axis)]
	if theme_id == "froststep": return [Vector2(-104,0).rotated(axis),Vector2(104,0).rotated(axis)]
	return [Vector2.ZERO]
func inside(point: Vector2, mark: int = 0, ring_radius: float = 100.0) -> bool:
	var local := to_local(point)
	if theme_id == "jade_wind":
		local = local.rotated(-axis)
		return absf(local.x)<=210 and absf(local.y)<=28
	if theme_id == "sunforge":
		var angle: float = absf(wrapf(local.angle()-axis,-PI,PI))
		return angle > PI/6 and local.length()>=maxf(56,ring_radius-24) and local.length()<=ring_radius
	return local.distance_squared_to(marks()[mark])<=68*68
func ring_band(at: float) -> Vector2:
	var radius: float=lerpf(56,100,clampf((at-float(WARNINGS.sunforge))/.5,0,1))
	return Vector2(maxf(56,radius-24),radius)
func _process(delta: float) -> void:
	var previous: float = clock
	clock += delta
	var warning: float = WARNINGS.get(theme_id,1.4)
	var actor: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(actor):
		if theme_id == "starfall":
			for index: int in range(3):
				var impact: float = warning + index*.5
				if previous < impact and clock >= impact and hit_mask==0 and inside(actor.global_position,index): _damage(actor,1)
		elif theme_id == "scarlet_rite":
			for index: int in range(2):
				var impact: float = warning + index*.7
				if previous < impact and clock >= impact and inside(actor.global_position): _damage(actor,1<<index)
		elif theme_id == "froststep":
			if clock>=warning and clock<warning+2 and hit_mask==0:
				for index: int in range(2):
					if inside(actor.global_position,index): _damage(actor,1);break
		elif theme_id == "sunforge":
			if clock>=warning and previous<warning+.5 and hit_mask==0:
				var band: Vector2 = ring_band(clock)
				var previous_band: Vector2 = ring_band(previous)
				var local := to_local(actor.global_position)
				if absf(wrapf(local.angle()-axis,-PI,PI))>PI/6 and local.length()>=previous_band.x and local.length()<=band.y: _damage(actor,1)
		elif previous < warning and clock >= warning and inside(actor.global_position): _damage(actor,1)
	_redraw += delta
	if _redraw >= 1.0/30: _redraw=0;queue_redraw()
	var tail: float = 2.0 if theme_id=="froststep" else 1.3 if theme_id=="starfall" else 1.0 if theme_id=="scarlet_rite" else .7
	if clock >= warning+tail: queue_free()
func _damage(actor: Node, bit: int) -> void:
	if (hit_mask&bit)!=0:return
	hit_mask |= bit
	var health: Node = actor.get_node_or_null("PlayerHealth")
	if health != null: health.take_damage(3.0+float(tier)*2)
func snapshot() -> Dictionary:
	return {"version":2,"theme":theme_id,"tier":tier,"clock":clock,"hit":hit_mask,"axis":axis,"x":global_position.x,"y":global_position.y}
static func valid_snapshot(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version")!=2 or raw.get("theme") not in WARNINGS or raw.get("tier") not in [1,2,3] or raw.get("hit") not in [0,1,2,3]: return false
	for key: String in ["clock","axis","x","y"]:
		if not (raw.get(key) is int or raw.get(key) is float) or not is_finite(float(raw[key])):return false
	return raw.clock>=0 and raw.clock<=4 and absf(raw.axis)<=TAU and absf(raw.x)<=100000 and absf(raw.y)<=100000
func _draw() -> void:
	var warning: float = WARNINGS.get(theme_id,1.4)
	if theme_id=="jade_wind":
		draw_set_transform(Vector2.ZERO,axis)
		draw_rect(Rect2(-210,-28,420,56),Color(_ink,.16 if clock<warning else .65),true)
		draw_rect(Rect2(-210,-28,420,56),Color(_ink,.95),false,2)
		for x: int in [-150,0,150]:
			for side: int in [-1,1]:
				draw_line(Vector2(x,side*34),Vector2(x,side*58),_ink,2,true)
				draw_line(Vector2(x,side*58),Vector2(x-7,side*49),_ink,2,true)
				draw_line(Vector2(x,side*58),Vector2(x+7,side*49),_ink,2,true)
		return
	if theme_id=="sunforge":
		var band: Vector2 = Vector2(56,100) if clock<warning else ring_band(clock)
		draw_arc(Vector2.ZERO,100,axis+PI/6,axis+TAU-PI/6,64,Color(_ink,.65),2,true)
		draw_arc(Vector2.ZERO,(band.x+band.y)*.5,axis+PI/6,axis+TAU-PI/6,64,Color(_ink,.20 if clock<warning else .85),maxf(1,band.y-band.x),true)
		for side: float in [-PI/6,PI/6]: draw_line(Vector2.from_angle(axis+side)*55,Vector2.from_angle(axis+side)*108,Color("a8ecd3"),3,true)
		return
	var points: Array[Vector2] = marks()
	for index: int in range(points.size()):
		var impact: float = warning + (index*.5 if theme_id=="starfall" else 0.0)
		var active: bool = clock>=impact
		var progress: float = clampf(clock/impact,0,1)
		if theme_id=="scarlet_rite" and clock>=warning:
			progress=clampf((clock-warning)/.7,0,1)
			active=(clock>=warning and clock<warning+.18) or clock>=warning+.7
		draw_circle(points[index],68,Color(_ink,.32 if active else .12))
		draw_arc(points[index],68,0,TAU,48,Color(_ink,.9),2,true)
		draw_arc(points[index],62,-PI/2,-PI/2+TAU*progress,48,Color(_ink,.95),3,true)
		if theme_id=="starfall": draw_string(ThemeDB.fallback_font,points[index]+Vector2(-5,5),str(index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,_ink)
