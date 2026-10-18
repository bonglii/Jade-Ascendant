extends SceneTree
const Flow=preload("res://tests/odyssey_premium_smoke.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
 create_timer(5.0).timeout.connect(func() -> void: quit(1))
 var client=Flow.FakeClient.new(); client.name="OdysseyClient"; root.add_child(client)
 for viewport: Vector2 in [Vector2(648,1152),Vector2(648,1296),Vector2(720,1600)]:
  var screen: Control=load("res://scripts/ui/odyssey_screen.gd").new(); screen.size=viewport; root.add_child(screen)
  await create_timer(0.2).timeout
  var badge: TextureRect=screen.find_child("TravelDiceBadge",true,false)
  assert(badge!=null and badge.size.x<=56 and badge.size.y<=56)
  var board: Control=screen.board
  assert(board.tile_size().x>=96 and board.tile_size().y>=65)
  var centers: Array[Vector2]=[]
  for index: int in range(20):
   var point: Vector2=board.point(index); assert(point not in centers); centers.append(point)
   var tile: Rect2=Rect2(point-board.tile_size()*0.5,board.tile_size())
   assert(tile.position.x>=0 and tile.end.x<=board.size.x+0.1)
   assert(tile.position.y>=0 and tile.end.y<=board.size.y+0.1)
  for index: int in [0,5,10,15]:
   board.show_position(index)
   var token_rect: Rect2=Rect2(board.token.position-Vector2.ONE*board.token.scale.x*48,Vector2.ONE*board.token.scale.x*96)
   assert(token_rect.position.y>=-1 and token_rect.end.y<=board.size.y+1)
  assert(screen.roll.get_global_rect().end.y<=viewport.y)
  assert(screen.missions_button.get_global_rect().end.y<=viewport.y)
  print("ODYSSEY_MOBILE_LAYOUT=PASS; VIEWPORT=",viewport,"; BADGE=",badge.size,"; TILE=",board.tile_size(),"; TOKEN=",board.token.scale.x*96)
  screen.queue_free(); await process_frame
 client.queue_free(); quit()
