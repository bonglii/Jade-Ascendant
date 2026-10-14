extends SceneTree
## Validate the shipped PNGs, including every edge of every independently cut cel.
var checks: int=0
var failures: int=0
func _initialize() -> void:
 for realm: int in range(1,6):
  for stage: int in range(1,6):
   var image:=Image.load_from_file("res://assets/enemy/boss_2d/atlas_%d_%d.png"%[realm,stage])
   if image==null or image.get_size()!=Vector2i(960,960):
    failures+=1;push_error("Invalid boss atlas %d/%d"%[realm,stage]);continue
   for row: int in range(6):
    for col: int in range(6):
     var occupied: bool=false
     var clean: bool=true
     for y: int in range(160):
      for x: int in range(160):
       var alpha: float=image.get_pixel(col*160+x,row*160+y).a
       if alpha>0.0:
        occupied=true
        if x<12 or x>=148 or y<12 or y>=148:clean=false
     checks+=1
     if not occupied or not clean:
      failures+=1;push_error("Empty or clipped cel %d/%d row%d col%d"%[realm,stage,row,col])
 print("BOSS_ATLAS_GUTTERS_QA checks=%d failures=%d"%[checks,failures])
 quit(0 if failures==0 else 1)
