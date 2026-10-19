extends Control
signal reveal_finished
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
var face: int=1
var rolling: bool=false
var age: float=0.0
var _shine: float=0.0
var _resolved: int=0
var _reveal_at: float=0.0
var _resolve_started: float=0.0
var _frame_clock: float=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE; custom_minimum_size=Vector2(90,90); set_process(false)
func start() -> void:
	visible=true; rolling=true; _resolved=0; age=0; _shine=0; _frame_clock=0; set_process(true)
func resolve(value: int) -> void:
	_resolved=clampi(value,1,6); _resolve_started=age; _reveal_at=maxf(age+0.55,1.3) if not Art.reduced(self) else age+0.08; set_process(true)
func cancel() -> void:
	visible=false; rolling=false; _resolved=0; _shine=0; set_process(false); queue_redraw()
func _process(delta: float) -> void:
	age+=delta
	if rolling:
		var settle: float=clampf((age-_resolve_started)/maxf(0.01,_reveal_at-_resolve_started),0,1) if _resolved>0 else 0.0
		_frame_clock+=delta
		if _frame_clock>=lerpf(0.055,0.20,settle*settle): face=1+posmod(face,6); _frame_clock=0
		if _resolved>0 and age>=_reveal_at:
			face=_resolved; rolling=false; _shine=1.0; reveal_finished.emit()
	else:
		_shine=maxf(0,_shine-delta*1.4)
		if _shine<=0: set_process(false)
	queue_redraw()
func _draw() -> void:
	var side: float=minf(size.x,size.y); var center: Vector2=size*0.5
	var damping: float=1.0-clampf((age-_resolve_started)/maxf(0.01,_reveal_at-_resolve_started),0,1) if _resolved>0 else 1.0
	var bounce: float=sin(age*22)*side*0.035*damping if rolling and not Art.reduced(self) else 0.0
	var angle: float=sin(age*18)*0.14*damping if rolling and not Art.reduced(self) else 0.0
	draw_set_transform(center+Vector2(0,-bounce),angle,Vector2.ONE*(1.0+_shine*0.045))
	var origin:=Vector2.ONE*(-side*0.5)
	draw_texture_rect(Art.DIE,Rect2(origin,Vector2.ONE*side),false)
	var pips: Array[Vector2]=[]
	if face%2==1: pips.append(Vector2(0.475,0.565))
	if face>=2: pips.append_array([Vector2(0.335,0.425),Vector2(0.615,0.705)])
	if face>=4: pips.append_array([Vector2(0.615,0.425),Vector2(0.335,0.705)])
	if face==6: pips.append_array([Vector2(0.335,0.565),Vector2(0.615,0.565)])
	for pip: Vector2 in pips:
		var point: Vector2=origin+pip*side
		draw_circle(point+Vector2(0,side*0.009),side*0.035,Color("a5824b")); draw_circle(point,side*0.030,Color("16745c")); draw_circle(point-Vector2.ONE*side*0.008,side*0.011,Color("b2ead4"))
	draw_set_transform(Vector2.ZERO)
