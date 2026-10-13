extends Control
## Artwork and bounded ambient accents only; no gameplay, timer or reward state.
var identity: String=""
var artwork: Texture2D
var accent: Color=Color(0.42,0.85,0.67)
var claim_ready: bool=false
var clock: float=0.0
var _redraw_budget: float=0.0
var render_ticks: int=0
var _reduced: bool=false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	custom_minimum_size=Vector2(0,150)
	resized.connect(queue_redraw)
func _visible_in_scroll() -> bool:
	if not is_visible_in_tree(): return false
	var bounds: Rect2=get_global_rect()
	var ancestor: Node=get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			return bounds.intersects((ancestor as ScrollContainer).get_global_rect())
		ancestor=ancestor.get_parent()
	return true
func _process(delta: float) -> void:
	if not _visible_in_scroll(): return
	if _reduced!=SettingsManager.reduced_effects:
		_reduced=SettingsManager.reduced_effects
		queue_redraw()
	if _reduced: return
	clock+=delta
	_redraw_budget+=delta
	if _redraw_budget>=0.05:
		_redraw_budget=fmod(_redraw_budget,0.05)
		render_ticks+=1
		queue_redraw()
func _draw() -> void:
	if artwork==null or size.x<=0 or size.y<=0: return
	var target: Vector2=size
	var source: Vector2=artwork.get_size()
	var factor: float=maxf(target.x/source.x,target.y/source.y)
	var region_size: Vector2=target/factor
	var region:=Rect2((source-region_size)*0.5,region_size)
	draw_texture_rect_region(artwork,Rect2(Vector2.ZERO,target),region)
	# Shade only the extreme lower edge; composition and central subjects stay visible.
	for band in range(8):
		var y: float=target.y*0.66+target.y*0.34*float(band)/8.0
		draw_rect(Rect2(0,y,target.x,target.y*0.34/8.0+1.0),Color(0.002,0.015,0.016,float(band)*0.032))
	if identity=="daily":
		var symbol: Texture2D=preload("res://assets/ui/icons/actions/daily.png")
		draw_texture_rect(symbol,Rect2(target*0.5-Vector2(30,30),Vector2(60,60)),false)
	if not SettingsManager.reduced_effects:
		for index in range(8):
			var speed: float=0.035 if identity=="boss_hunt" else 0.02
			var cycle: float=fposmod(float(index)*0.137+clock*speed,1.0)
			var x: float=target.x*(0.06+0.88*fposmod(float(index)*0.618,1.0))+sin(clock*0.45+float(index))*3.0
			var point:=Vector2(x,target.y*(1.0-cycle))
			var alpha: float=sin(cycle*PI)*0.55
			draw_circle(point,1.3 if identity=="boss_hunt" else 1.7,Color(accent,alpha))
	var edge: Color=Color(accent,0.8)
	if claim_ready:
		edge=Color(1.0,0.84,0.44,0.85 if SettingsManager.reduced_effects else 0.72+0.18*sin(clock*1.8))
	draw_rect(Rect2(Vector2.ONE,target-Vector2(2,2)),edge,false,1.5)
	# Small corner inlays support the illustration instead of covering its subjects.
	for x_side: float in [1.0,-1.0]:
		for y_side: float in [1.0,-1.0]:
			var corner:=Vector2(5.0 if x_side>0 else target.x-5.0,5.0 if y_side>0 else target.y-5.0)
			draw_line(corner,corner+Vector2(x_side*17,0),Color(1,0.85,0.5,0.9),2.0,true)
			draw_line(corner,corner+Vector2(0,y_side*12),Color(1,0.85,0.5,0.9),2.0,true)
