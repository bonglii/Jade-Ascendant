extends "res://tests/player_six_fixes_ui.gd"
func _initialize() -> void:
 if DisplayServer.get_name()=="headless":push_error("Native GUI is required");quit(2);return
 run.call_deferred()
func review_sizes() -> Array[Vector2i]:return [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]
func review_locales() -> Array[String]:return ["en"]
func capture_native(label: String) -> void:
 await RenderingServer.frame_post_draw
 var pixels: Image=root.get_texture().get_image()
 check(pixels!=null and not pixels.is_empty(),"native GPU readback "+label)
 if pixels!=null and not pixels.is_empty():
  DirAccess.make_dir_recursive_absolute("res://.local/six_native_images")
  check(pixels.save_png("res://.local/six_native_images/"+label+".png")==OK,"native screenshot saved")
func swipe(at: Vector2) -> void:
 var event:=InputEventMouseButton.new();event.position=at;event.pressed=true;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT
 root.push_input(event,true);await frames(1)
 for i: int in range(1,10):
  var motion:=InputEventMouseMotion.new();motion.position=at+Vector2(0,-i*12);motion.relative=Vector2(0,-12);motion.button_mask=MOUSE_BUTTON_MASK_LEFT
  root.push_input(motion,true);await frames(1)
 event.position=at+Vector2(0,-108);event.pressed=false;event.button_mask=0;root.push_input(event,true);await frames(8)
func native_pavilion(screen: Control) -> void:
 await capture_native("pavilion-paid-"+str(root.size.x))
 if root.size.x!=390:return
 screen._open_target_picker("weapon");await frames(18)
 var scroller: ScrollContainer=screen._target_overlay.get_meta("scroll")
 var card: Control=screen._target_overlay.find_child("TargetChoices",true,false).get_child(0)
 var visible: Rect2=card.get_global_rect().intersection(scroller.get_global_rect())
 var before: Dictionary=wallet();var wish: String=paid.snapshot.wish
 check(visible.size.x>20 and visible.size.y>20,"native target swipe starts on visible real card")
 var initial: int=scroller.scroll_vertical
 if visible.size.y>20:await swipe(visible.get_center())
 check(scroller.scroll_vertical>initial+20,"native target first swipe scrolls")
 check(wallet()==before and paid.snapshot.wish==wish and not paid.busy and not is_instance_valid(screen._focus_sheet),"swipe cannot choose/confirm target or spend")
 await capture_native("paid-target-native");screen._close_target_picker();await frames()
func native_hero(screen: Control) -> void:
 await capture_native("hero-"+str(root.size.x))
 if root.size.x!=390:return
 var inv: Node=root.get_node("InventoryManager");var saved: Dictionary=inv.item_counts.duplicate(true)
 for id: String in root.get_node("EquipmentManager").get_item_ids():inv.item_counts[id]=1
 screen._sync_inventory();await frames(20)
 var visible: Rect2
 for card: Control in screen.card_buttons.values():
  visible=card.get_global_rect().intersection(screen.scroll.get_global_rect())
  if visible.size.x>20 and visible.size.y>20:break
 var initial: int=screen.scroll.scroll_vertical
 var before: Dictionary=wallet()
 check(visible.size.x>20 and visible.size.y>20,"native backpack first swipe starts on real card")
 if visible.size.y>20:await swipe(visible.get_center())
 check(screen.scroll.scroll_vertical>initial+20,"native backpack first swipe scrolls")
 check(wallet()==before and not screen.detail_open and not paid.busy,"backpack swipe cannot open/equip/refine/spend")
 await capture_native("backpack-swipe-native")
 inv.item_counts=saved;screen._sync_inventory();await frames()
