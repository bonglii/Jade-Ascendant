extends Control
## Cinematic renderer for results already committed by PavilionManager.
signal ritual_finished
signal phase_changed(message: String)
signal relic_appeared
const PALACE = preload("res://assets/ui/pavilion/sanctum_premium/celestial_gate.png")
const SEAL = preload("res://assets/ui/pavilion/sanctum_premium/celestial_seal.png")
const DRAGON = preload("res://assets/ui/pavilion/sanctum_premium/celestial_dragon.png")
const HALO = preload("res://assets/ui/pavilion/vfx/shared/soft_halo_premium.png")
const TONES = {"common":Color(0.73,0.80,0.74),"rare":Color(0.35,0.78,0.96),"epic":Color(0.74,0.48,0.96),"legendary":Color(0.98,0.78,0.35)}
var relic: Texture2D
var _pending_relic: Texture2D
var preview_mode: bool = false
var background_visible: bool = true
var presentation_star: int = 1
var _land_clock: float = 0.0
var rarity: String = "legendary"
var playing: bool = false
var landed: bool = false
var elapsed: float = 0.0
var duration: float = 4.1
var clock: float = 0.0
var _step: int = -1
var _tick: float = 0.0
var _cue_sent: bool = false
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
func set_relic(texture: Texture2D, next_rarity: String = "legendary") -> void:
	relic = texture
	rarity = next_rarity if TONES.has(next_rarity) else "common"
	queue_redraw()
func play(texture: Texture2D, next_rarity: String, star: int = 1) -> void:
	# Identity stays out of the visible renderer until completion, even on reuse.
	preview_mode = false
	relic = null
	_pending_relic = texture
	rarity = next_rarity if TONES.has(next_rarity) else "common"
	presentation_star = clampi(star,1,5)
	elapsed = 0.0
	_step = -1
	landed = false
	_cue_sent = false
	playing = true
	duration = {"common":1.05,"rare":1.8,"epic":2.8,"legendary":4.1}[rarity]
	queue_redraw()
	if SettingsManager.reduced_effects: skip()
func skip() -> void:
	if not playing: return
	elapsed = duration
	playing = false
	landed = true
	relic = _pending_relic
	_pending_relic = null
	_land_clock = clock
	_send_impact()
	queue_redraw()
	ritual_finished.emit()
func clear() -> void:
	playing = false
	landed = false
	elapsed = 0.0
	relic = null
	_pending_relic = null
	queue_redraw()

func _process(delta: float) -> void:
	if playing:
		elapsed += delta
		var progress: float = elapsed/duration
		var step: int = 0 if progress < 0.18 else (1 if progress < 0.45 else (2 if progress < 0.74 else 3))
		if step != _step:
			_step = step
			var phases: Array[String] = ["THE SEAL FALLS SILENT","QI GATHERS",{"common":"SEAL OPENS","rare":"MERIDIANS IGNITE","epic":"CONSTELLATION FORMS","legendary":"HEAVENLY GATE OPENS"}[rarity],"THE GATE RESONATES"]
			phase_changed.emit(phases[step])
			if step == 2 and rarity == "legendary": AudioManager.play_sfx("summon_legendary_omen")
		if elapsed >= duration: skip()
	if not is_visible_in_tree() or not get_global_rect().intersects(get_viewport_rect()): return
	if SettingsManager.reduced_effects: return
	clock += delta
	_tick += delta
	if _tick >= 1.0/30.0:
		_tick = 0.0
		queue_redraw()
func _draw_backdrop(rect: Rect2, zoom: float = 1.0, alpha: float = 1.0) -> void:
	var texture_size: Vector2 = PALACE.get_size()
	var ratio: float = maxf(rect.size.x/texture_size.x,rect.size.y/texture_size.y)*zoom
	var source_size: Vector2 = rect.size/ratio
	# Focus crop on the actual gate aperture, not the staircase.
	var crop_center := Vector2(texture_size.x*0.5,texture_size.y*0.43)
	var origin: Vector2 = crop_center-source_size*0.5
	origin.x = clampf(origin.x,0,texture_size.x-source_size.x)
	origin.y = clampf(origin.y,0,texture_size.y-source_size.y)
	draw_texture_rect_region(PALACE,rect,Rect2(origin,source_size),Color(1,1,1,alpha))
func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0: return
	var tone: Color = TONES[rarity]
	if playing and elapsed/duration < 0.18: tone = Color(0.35,0.64,0.57)
	var t: float = 0.0 if SettingsManager.reduced_effects else clock
	var p: float = clampf(elapsed/duration,0,1)
	var cinematic: bool = playing or landed
	var center := Vector2(size.x*0.5,size.y*0.43)
	var radius: float = minf(size.x*0.38,size.y*0.39)
	var surge: float = smoothstep(0.18,0.65,p) if cinematic else 0.18
	var camera_zoom: float = 1.0+0.08*smoothstep(0.18,0.74,p) if cinematic else 1.0
	if background_visible:
		_draw_backdrop(Rect2(Vector2.ZERO,size),camera_zoom)
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.0,0.045,0.04,0.15 if not cinematic else 0.24*(1.0-surge)))
	if cinematic:
		for aura in range(6): draw_circle(center,radius*(0.83+float(aura)*0.09),Color(tone,0.018*surge))
		draw_arc(center,radius*0.96,-t*0.10,TAU-t*0.10,80,Color(tone,0.30+surge*0.40),2.0,true)
	# Eased meridian sweeps and precise rune pulses flank the equipment.
	for ring in range(3):
		var rotation_angle: float = t*(0.09 if ring%2==0 else -0.07)
		var rr: float = radius*(0.72+float(ring)*0.11)
		draw_arc(center,rr,rotation_angle,rotation_angle+TAU*0.64,72,Color(tone,0.12+surge*0.20),1.2,true)
		for index in range(6):
			var angle: float = rotation_angle+TAU*float(index)/6.0
			var point: Vector2 = center+Vector2(cos(angle),sin(angle))*rr
			draw_circle(point,1.5,Color(tone,0.22+surge*0.4))
	if cinematic and p > 0.40:
		if rarity == "epic": _constellation(center,radius,tone,t)
		elif rarity == "rare": _beam(center,radius,tone,surge*0.45)
		elif rarity == "legendary":
			var open_amount: float = smoothstep(0.45,0.79,p)
			_beam(center,size.y*0.55,tone,open_amount)
			_draw_dragon(Rect2(Vector2(size.x*0.01,size.y*0.015),Vector2(size.x*0.98,size.y*0.82)),open_amount*0.88)
			# Gold gate seams part around the relic; no opaque dragon covers it.
			for side in [-1.0,1.0]:
				for segment in range(5):
					var angle: float = -PI/2.0+float(segment)*PI/5.0+(PI if side < 0 else 0.0)
					draw_arc(center+Vector2(side*open_amount*size.x*0.065,0),radius,angle,angle+PI/8,18,Color(tone,0.65*open_amount),2.0,true)
	if playing:
		var seal_size: float = radius*1.02*(1.0-0.18*smoothstep(0.45,0.74,p))
		var seal_alpha: float = 1.0-smoothstep(0.90,1.0,p)
		var angle: float = sin(p*TAU)*0.10
		draw_set_transform(center,angle)
		draw_texture_rect(SEAL,Rect2(-Vector2.ONE*seal_size*0.5,Vector2.ONE*seal_size),false,Color(1,1,1,seal_alpha))
		draw_set_transform(Vector2.ZERO)
	if relic != null and (preview_mode or landed):
		var reveal: float = 1.0 if preview_mode or SettingsManager.reduced_effects else smoothstep(0.0,0.32,clock-_land_clock)
		var side: float = minf(size.x*0.76,size.y*0.71)*lerpf(0.72,1.0,reveal)
		var lift: float = lerpf(26.0,0.0,reveal)+sin(t*1.35)*3.0
		var halo_side: float = side*1.30
		draw_texture_rect(HALO,Rect2(center-Vector2.ONE*halo_side*0.5,Vector2.ONE*halo_side),false,Color(tone,0.16 if not cinematic else 0.35*reveal))
		draw_set_transform(center+Vector2(0,lift),lerpf(-0.12,0,reveal))
		draw_texture_rect(relic,Rect2(-Vector2.ONE*side*0.5,Vector2.ONE*side),false,Color(1,1,1,reveal))
		draw_set_transform(Vector2.ZERO)
		if (rarity == "legendary" or presentation_star == 5) and cinematic:
			for ray in range(12):
				var a: float = float(ray)*TAU/12.0+t*0.03
				draw_line(center+Vector2(cos(a),sin(a))*radius*0.7,center+Vector2(cos(a),sin(a))*radius*1.22,Color(tone,0.13*reveal),1.0,true)
	# Bounded qi ribbons and dust, 30 redraws/sec; reduced effects stay static.
	for lane in range(2):
		var points := PackedVector2Array()
		for index in range(40):
			var fraction: float = float(index)/39.0
			var a: float = fraction*TAU+t*0.45+float(lane)*PI
			points.append(center+Vector2(sin(a)*radius*0.75,(fraction-0.5)*radius*1.8))
		draw_polyline(points,Color(tone,0.14+surge*0.15),1.2,true)
	for star in range(24):
		var x: float = fmod(float(star)*79.0+t*(5.0+surge*8.0),size.x)
		var y: float = size.y-fmod(float(star)*57.0+t*(10.0+surge*9.0),size.y)
		draw_circle(Vector2(x,y),1.0+float(star%3)*0.3,Color(tone,(0.23+surge*0.28)*(smoothstep(0.0,0.12,y/size.y)*smoothstep(0.0,0.12,1.0-y/size.y))))
	# Just one soft impact veil; never a repeated strobe.
	if playing and rarity == "legendary" and not SettingsManager.reduced_effects:
		var flash: float = maxf(0.0,1.0-absf(p-0.745)/0.045)*0.14
		draw_rect(Rect2(Vector2.ZERO,size),Color(1,0.9,0.66,flash))
func _beam(center: Vector2, height: float, tone: Color, alpha: float) -> void:
	for line in range(9):
		var x: float = center.x+float(line-4)*3.0
		var strength: float = (1.0-absf(float(line-4))/5.0)*0.09*alpha
		draw_line(Vector2(x,center.y-height),Vector2(x,center.y+height),Color(tone,strength),4.0,true)
func _constellation(center: Vector2, radius: float, tone: Color, t: float) -> void:
	var stars := PackedVector2Array()
	for index in range(7):
		var angle: float = -PI/2.0+TAU*float(index)/7.0+t*0.05
		var point: Vector2 = center+Vector2(cos(angle),sin(angle))*radius*0.89
		stars.append(point)
		draw_circle(point,3.0,Color(tone,0.85))
	stars.append(stars[0])
	draw_polyline(stars,Color(tone,0.52),1.5,true)
func _draw_dragon(rect: Rect2, strength: float) -> void:
	var source: Vector2 = DRAGON.get_size()
	var fit: float = minf(rect.size.x/source.x,rect.size.y/source.y)
	var final_size: Vector2 = source*fit
	var top_left: Vector2 = rect.position+(rect.size-final_size)*0.5
	draw_texture_rect(DRAGON,Rect2(top_left,final_size),false,Color(1,1,1,strength))
func _send_impact() -> void:
	if _cue_sent: return
	_cue_sent = true
	relic_appeared.emit()
