extends StyleBox
## Source corner slices and on-screen corner size are independent.
## Native nine-patch source margins can overdraw a short/compact touch target.
var texture: Texture2D
var modulate_color: Color=Color.WHITE
var corner: Vector2=Vector2(18,16)
func _get_minimum_size() -> Vector2:
 return Vector2(28,20)
func _draw(canvas: RID,rect: Rect2) -> void:
 if texture==null:return
 var extent: Vector2=texture.get_size()
 var sx: Array[float]=[0,32,extent.x-32,extent.x]
 var sy: Array[float]=[0,32,extent.y-32,extent.y]
 var width: float=minf(corner.x,rect.size.x*.5)
 var height: float=minf(corner.y,rect.size.y*.5)
 var dx: Array[float]=[rect.position.x,rect.position.x+width,rect.end.x-width,rect.end.x]
 var dy: Array[float]=[rect.position.y,rect.position.y+height,rect.end.y-height,rect.end.y]
 for row: int in range(3):
  for col: int in range(3):
   var target:=Rect2(dx[col],dy[row],dx[col+1]-dx[col],dy[row+1]-dy[row])
   var source:=Rect2(sx[col],sy[row],sx[col+1]-sx[col],sy[row+1]-sy[row])
   RenderingServer.canvas_item_add_texture_rect_region(canvas,target,texture.get_rid(),source,modulate_color)
