extends TextureRect
## Uses the same engraved die artwork and face coordinates as the animated die.
func _draw() -> void:
 var side: float=minf(size.x,size.y)
 var origin: Vector2=(size-Vector2.ONE*side)*0.5
 for pip: Vector2 in [Vector2(0.335,0.425),Vector2(0.475,0.565),Vector2(0.615,0.705)]:
  var center: Vector2=origin+pip*side
  draw_circle(center+Vector2(0,side*0.008),side*0.046,Color("ba9551"))
  draw_circle(center,side*0.037,Color("125441"))
  draw_circle(center-Vector2.ONE*side*0.009,side*0.012,Color("b2ead4"))
