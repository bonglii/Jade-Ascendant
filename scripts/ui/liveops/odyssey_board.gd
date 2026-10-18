extends Control
signal travel_finished
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
const TILE=preload("res://assets/ui/liveops/odyssey/tile.png")
const TEMPLE=preload("res://assets/ui/liveops/odyssey/temple.png")
const DRAGON=preload("res://assets/ui/liveops/odyssey/dragon.png")
const FRAMES=preload("res://assets/character/player/player_lin_yue_idle_walk_spriteframes.tres")
const STONE=preload("res://assets/ui/shared/resources/spirit_stone_premium.png")
const JADE=preload("res://assets/ui/shared/resources/celestial_jade_premium.png")
const SEAL=preload("res://assets/ui/shared/resources/pavilion_seal_premium.png")
const TYPES: Array[String]=["LOTUS","STONE","SCROLL","CHEST","STONE","GATE","JADE","STONE","LOTUS","CHEST","SCROLL","STONE","GATE","JADE","STONE","CHEST","LOTUS","SCROLL","STONE","GATE"]
var token: AnimatedSprite2D
var selected: int=0
var coordinates: Array[Vector2i]=[]
var _from: int=0
var _steps: int=0
var _travel: float=0.0
var _age: float=0.0
var _idle_clock: float=0.0
var _last_step: int=-1
var _landing: float=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for x: int in range(6): coordinates.append(Vector2i(x,0))
	for y: int in range(1,6): coordinates.append(Vector2i(5,y))
	for x: int in range(4,-1,-1): coordinates.append(Vector2i(x,5))
	for y: int in range(4,0,-1): coordinates.append(Vector2i(0,y))
	token=AnimatedSprite2D.new(); token.sprite_frames=FRAMES; token.play("idle_down"); token.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; token.z_index=0; add_child(token)
	resized.connect(_layout); _layout()
func _width() -> float: return minf(size.x,size.y*1.65)
func point(index: int) -> Vector2:
	if coordinates.is_empty(): return size*0.5
	var c: Vector2i=coordinates[posmod(index,20)]; var width: float=_width()
	return Vector2(size.x*0.5+(c.x-c.y)*width/12.0,size.y*0.50-width*5.0/24.0+(c.x+c.y)*width/24.0)
func _layout() -> void:
	if token!=null:
		var display: float=clampf(_width()*0.14,70,106); token.scale=Vector2.ONE*display/96.0
		if not is_travelling(): token.position=point(selected)-Vector2(0,display*0.22)
	queue_redraw()
func is_travelling() -> bool: return _steps>0
func show_position(index: int, steps: int=0) -> void:
	if token==null: selected=index; return
	if steps<1: _steps=0; selected=index; _layout(); return
	_from=selected; selected=index; _steps=clampi(steps,1,6); _travel=0; _last_step=-1
func _process(delta: float) -> void:
	_age+=delta; _landing=maxf(0,_landing-delta)
	if is_travelling():
		var duration: float=0.19 if not Art.reduced(self) else 0.06
		_travel+=delta
		var step: int=mini(int(_travel/duration),_steps-1)
		var t: float=clampf((_travel-float(step)*duration)/duration,0,1)
		var start: Vector2=point(_from+step); var finish: Vector2=point(_from+step+1)
		if step!=_last_step:
			var grid: Vector2i=coordinates[posmod(_from+step+1,20)]-coordinates[posmod(_from+step,20)]
			var direction: String="right" if grid.x>0 else "left" if grid.x<0 else "down" if grid.y>0 else "up"
			token.play("walk_"+direction); _last_step=step
		var lift: float=sin(t*PI)*8.0 if not Art.reduced(self) else 0.0
		token.position=start.lerp(finish,t)-Vector2(0,token.scale.x*96*0.22+lift)
		if _travel>=float(_steps)*duration: _steps=0; _landing=0.65; token.play("idle_down"); _layout(); travel_finished.emit()
		queue_redraw()
	else:
		_idle_clock+=delta
		if _idle_clock>=1.0/20.0: _idle_clock=0; queue_redraw()
func _tile(index: int) -> void:
	var center: Vector2=point(index); var width: float=_width(); var span:=Vector2(width/6.0,width/9.0)
	draw_texture_rect(TILE,Rect2(center-span*0.5,span),false,Color("c5f4de") if index==selected else Color.WHITE)
	var icon: Texture2D=JADE if TYPES[index]=="JADE" else SEAL if TYPES[index]=="GATE" else STONE
	var side: float=clampf(width*0.045,20,34)
	draw_texture_rect(icon,Rect2(center-Vector2.ONE*side*0.5-Vector2(0,5),Vector2.ONE*side),false)
func _draw() -> void:
	if coordinates.is_empty(): return
	var width: float=_width()
	for i: int in range(20):
		if coordinates[i].x+coordinates[i].y<=5: _tile(i)
	var temple: float=width*0.52
	draw_texture_rect(TEMPLE,Rect2(Vector2(size.x*0.5-temple*0.5,size.y*0.5-temple*0.71),Vector2.ONE*temple),false)
	for i: int in range(20):
		if coordinates[i].x+coordinates[i].y>5: _tile(i)
	var at: Vector2=token.position+Vector2(0,token.scale.x*96*0.22) if is_travelling() else point(selected)
	draw_set_transform(at+Vector2(0,8),0,Vector2(1,0.35)); draw_circle(Vector2.ZERO,width*0.055,Color(0.01,0.06,0.05,0.65)); draw_set_transform(Vector2.ZERO)
	if not Art.reduced(self):
		var pulse: float=0.5+0.5*sin(_age*2)
		draw_texture_rect(SEAL,Rect2(at-Vector2(29,24),Vector2(58,58)),false,Color(0.6,1,0.85,0.12+pulse*0.08))
		if _landing>0:
			var reveal: float=1.0-_landing/0.65; var span:=Vector2(85,42)*(1+reveal*0.4)
			draw_texture_rect(DRAGON,Rect2(at-span*0.5-Vector2(0,45+reveal*20),span),false,Color(1,1,1,(1-reveal)*0.8))
