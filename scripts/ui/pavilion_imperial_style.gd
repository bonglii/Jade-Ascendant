extends StyleBox
## Draw the original high-resolution material as scaled corner regions.
## Explicit destination corner size keeps mobile layout independent of PNG size.
const MATERIAL=preload("res://assets/ui/pavilion/sanctum_premium/imperial_jade_frame.png")
var tint: Color=Color.WHITE
var corner: Vector2=Vector2(20,18)
var pressed: bool=false
var selected: bool=false
func _init() -> void:
	content_margin_left=14;content_margin_right=14
	content_margin_top=10;content_margin_bottom=10
func _get_minimum_size() -> Vector2:
	return Vector2(28,20)
func _draw(canvas: RID,rect: Rect2) -> void:
	var source_size: Vector2=MATERIAL.get_size()
	var sx: Array[float]=[0.0,source_size.x*0.18,source_size.x*0.82,source_size.x]
	var sy: Array[float]=[0.0,source_size.y*0.26,source_size.y*0.74,source_size.y]
	var width: float=minf(corner.x,rect.size.x/2.0)
	var height: float=minf(corner.y,rect.size.y/2.0)
	var dx: Array[float]=[rect.position.x,rect.position.x+width,rect.end.x-width,rect.end.x]
	var dy: Array[float]=[rect.position.y,rect.position.y+height,rect.end.y-height,rect.end.y]
	for row in range(3):
		for col in range(3):
			var dest:=Rect2(dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row])
			var source:=Rect2(sx[col],sy[row],sx[col+1]-sx[col],sy[row+1]-sy[row])
			RenderingServer.canvas_item_add_texture_rect_region(canvas,dest,MATERIAL.get_rid(),source,tint)
	var center:=Rect2(rect.position+Vector2(width*.55,height*.7),rect.size-Vector2(width*1.1,height*1.4))
	RenderingServer.canvas_item_add_rect(canvas,center,Color(0.002,0.018,0.014,0.28 if not pressed else 0.52))
	if selected:
		RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position+Vector2(5,3),Vector2(rect.size.x-10,1)),Color(1.0,0.83,0.4,0.9))
	if pressed:
		RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position+Vector2(4,3),Vector2(rect.size.x-8,3)),Color(0,0.015,0.01,0.65))
