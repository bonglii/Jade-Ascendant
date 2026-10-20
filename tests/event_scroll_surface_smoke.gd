extends SceneTree
## Native GUI gestures, not direct scroll-value assignment, exercise the first swipe.
const Policy=preload("res://scripts/ui/mobile_scroll_policy.gd")
const JadeMaterial=preload("res://scripts/ui/liveops/event_jade_material.gd")
var checks: int=0
var failures: int=0
var accidental_clicks: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("EVENT_SCROLL "+caption)
func settle(frames: int=6) -> void:
 for i: int in range(frames):await process_frame
func mouse(at: Vector2,down: bool) -> void:
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0;event.pressed=down;event.position=at;root.push_input(event,true)
func swipe(at: Vector2,delta: Vector2) -> void:
 mouse(at,true);await settle(1)
 for i: int in range(1,9):
  var event:=InputEventMouseMotion.new();event.position=at+delta*float(i)/8.0;event.relative=delta/8.0;event.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(event,true);await settle(1)
 mouse(at+delta,false);await settle(2)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):quit(2);return
 create_timer(70).timeout.connect(func() -> void:quit(1))
 var onboarding:=ConfigFile.new();onboarding.set_value("meta","version",2)
 for key: String in ["home","equipment","pavilion"]:onboarding.set_value("tutorials",key,true)
 onboarding.save("user://jade_onboarding.cfg")
 await settle()
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(390,844)
 var client: Node=root.get_node("OdysseyClient");client.set_process(false)
 var now: int=int(Time.get_unix_time_from_system());var day: String=Time.get_datetime_string_from_unix_time(now).substr(0,10)
 var catalog: Dictionary=root.get_node("PavilionManager").get_iap_product_catalog();var offers: Array=[]
 for id: String in catalog:
  var product: Dictionary=catalog[id]
  if str(product.get("type",""))=="consumable":offers.append({"product_id":id,"jade":int(product.get("celestial_jade",0)),"dice":[1,3,5,8,12,16][offers.size()],"claimed":false})
 client.snapshot={"event":{"id":"qa-scroll","enabled":true,"ads_enabled":true,"purchases_enabled":true,"starts_at":now-100,"ends_at":now+86400},"state":{"tickets":6,"rolls":36,"daily_rolls":3,"position":4,"day":day,"task_day":day,"missions":[],"task_claims":[],"milestones":[],"last_die":0,"daily_ads":0},"revision":1,"server_time":now,"purchase_bonus":{"active":true,"offers":offers}}
 client._received_msec=Time.get_ticks_msec();client.status="connected";client.busy=false
 var before: Dictionary=client.snapshot.duplicate(true)
 # The same autoload policy must handle nested cards and runtime-added controls.
 var scroll:=ScrollContainer.new();scroll.size=Vector2(370,700);scroll.position=Vector2(10,10);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;root.add_child(scroll)
 var stack:=VBoxContainer.new();stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(stack)
 for i: int in range(12):
  var card:=PanelContainer.new();card.custom_minimum_size.y=140;stack.add_child(card)
  var target:=Button.new();target.text="ACTION";target.pressed.connect(func() -> void:accidental_clicks+=1);card.add_child(target)
 await settle()
 await swipe(Vector2(160,140),Vector2(0,-95))
 check(scroll.scroll_vertical>40,"new scroll zone responds to the first swipe starting on a button")
 check(accidental_clicks==0,"swipe cancels native button press without toggling eligibility")
 scroll.free();await settle()
 var hub: Control=load("res://scenes/ui/event_center_screen.tscn").instantiate();hub.set_meta("liveops_popup",true);root.add_child(hub);await settle()
 var initial: int=hub._scroll.scroll_vertical
 await swipe(hub._hero_stage.get_global_rect().get_center(),Vector2(0,-115))
 check(hub._scroll.scroll_vertical>initial+40,"Celestial hero artwork scrolls on first gesture")
 check(not hub._navigating,"swiping featured artwork does not navigate")
 hub._scroll.scroll_vertical=330;await settle()
 var target: Button=hub._activity_handles.seven_day.hit
 var start: Vector2=target.get_global_rect().get_center()
 if not hub._scroll.get_global_rect().has_point(start):start=hub._scroll.get_global_rect().get_center()
 initial=hub._scroll.scroll_vertical;await swipe(start,Vector2(0,-95))
 check(hub._scroll.scroll_vertical>initial+35 and not hub._navigating,"event hit targets route swipes and never open accidentally")
 var capture_dir: String=OS.get_environment("JADE_EVENT_TOUCH_CAPTURE_DIR")
 if not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
  hub._scroll.scroll_vertical=0;await settle();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture_dir.path_join("celestial-390.png"))
 hub.free();await settle()
 var page: Control=load("res://scenes/ui/odyssey_screen.tscn").instantiate();root.add_child(page);page.set_process(false);await settle()
 check(page.find_children("*","Button",true,false).all(func(b: Button) -> bool:return not b.text.contains("RECONNECT")),"manual reconnect button removed")
 var board_scroll: ScrollContainer=page.find_child("BoardScroll",true,false)
 initial=board_scroll.scroll_vertical;await swipe(page.board.get_global_rect().get_center(),Vector2(0,-95))
 check(board_scroll.scroll_vertical>initial+35,"board scenery is a live scroll zone")
 for kind: String in ["_missions","_journey_rewards","_shop","_info"]:
  page.call(kind)
  if kind=="_shop":
   var products: Dictionary={}
   for i: int in range(offers.size()):products[str(offers[i].product_id)]={"formatted_price":"Rp18.000" if i==0 else "Rp1.499.000,00","price_amount_micros":18000000000}
   root.get_node("PavilionManager").billing_store_products=products;page._refresh_shop_products()
   check(offers.size()==6 and page._shop_handles.size()==offers.size(),"six real catalog products populate the shop fixture")
   for entry: Dictionary in page._shop_handles:
    for state: String in ["normal","hover","pressed","disabled"]:
     check(entry.button.get_theme_stylebox(state).get("texture")==JadeMaterial.BUTTON,"price material retains its texture in "+state)
   check(page._shop_handles[0].button.text=="Rp18.000","Play-formatted fixture price remains visible with checkout unavailable")
   check(page._shop_handles[0].dice_icon.visible,"confirmed active bonus shows dice beside its Jade")
   check(page._shop_handles[1].button.text.replace("\n","")=="Rp1.499.000,00","long price keeps the entire amount and currency")
  await settle()
  var modal_scroll: ScrollContainer=page._modal_body.get_parent()
  initial=modal_scroll.scroll_vertical
  var at: Vector2=modal_scroll.get_global_rect().position+Vector2(modal_scroll.size.x*.5,minf(150,modal_scroll.size.y*.6))
  await swipe(at,Vector2(0,-85))
  check(modal_scroll.scroll_vertical>initial+25,"first swipe works in "+kind)
  check(page._modal_kind!="" and client.snapshot==before,"swiping sheet cannot mutate rewards or close "+kind)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
   root.size=dims;await settle();page._fit_popup();await settle()
   check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(page._modal_panel.get_rect()),"sheet fits "+kind+str(dims))
   check(page._modal_header.get_global_rect().encloses(page._modal_header.find_child("ModalTitle",true,false).get_global_rect()),"title inside full header "+kind+str(dims))
   check(modal_scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED and modal_scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"one scroll axis and no pipe "+kind+str(dims))
   if kind=="_shop":
    for entry: Dictionary in page._shop_handles:
     var row: Control=entry.button.get_parent();var items: Control=row.get_node("PackItems")
     check(items.get_global_rect().end.x<=entry.button.global_position.x+1,"items left of price "+str(dims))
     check(row.get_global_rect().encloses(entry.button.get_global_rect()),"price stays inside row "+str(dims))
     var widest: float=0
     for line: String in entry.button.text.split("\n"):widest=maxf(widest,entry.button.get_theme_font("font").get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,entry.button.get_theme_font_size("font_size")).x)
     check(widest<=entry.button.custom_minimum_size.x-16+1,"price amount fits without splitting digits "+str(dims))
  root.size=Vector2i(390,844);page._close_modal();await settle()
 page._missions();await settle();var identity: int=page.modal.get_instance_id()
 for i: int in range(50):page._missions()
 check(page.modal.get_instance_id()==identity,"repeated taps still create one sheet")
 if not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
  await settle();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture_dir.path_join("missions-390.png"))
  page._close_modal();page._shop();
  var capture_products: Dictionary={}
  for entry: Dictionary in page._shop_handles:capture_products[str(entry.product_id)]={"formatted_price":"Rp18.000","price_amount_micros":18000000000}
  root.get_node("PavilionManager").billing_store_products=capture_products;page._refresh_shop_products();await create_timer(.25).timeout;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture_dir.path_join("shop-390.png"))
 for texture: Texture2D in [JadeMaterial.BUTTON,JadeMaterial.MEDALLION,JadeMaterial.PANEL,JadeMaterial.PAPER]:
  var pixels: Image=texture.get_image()
  check(pixels.get_pixel(0,0).a==0,"rounded material corner is genuinely transparent")
 page.free();await settle()
 if not capture_dir.is_empty():
  await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  print("EVENT_SCROLL_RENDER checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0);return
 # Representative existing pages use exactly the same native routing policy.
 var inventory: Node=root.get_node("InventoryManager")
 for id: String in root.get_node("EquipmentManager").get_item_ids():inventory.item_counts[id]=1
 var server: Node=root.get_node("ServerMailManager");server._owner="scroll_fixture".sha256_text();server._auth_node=null
 var mails: Array=[]
 for i: int in range(20):
  var id: String="%032x"%(70000+i)
  mails.append({"id":"server:"+id,"mail_id":id,"title":"Surat pengujian scroll %d"%i,"body":"Surat tetap belum dibaca setelah swipe.","sender":"QA","reward":{},"created_at":1700000000+i,"expires_at":1900000000,"read":false,"claimed":false,"pending":false,"can_claim":false,"blocked_on_other_device":false,"cancelled":false,"expired":false})
 server._state.cache[server._owner]=mails
 for scene_name: String in ["equipment_screen","daily_quest_screen","achievement_screen","mailbox_screen","jade_valley_pilgrimage_screen","path_of_five_elements_screen"]:
  var screen: Control=load("res://scenes/ui/"+scene_name+".tscn").instantiate();root.add_child(screen);current_scene=screen;await settle(28)
  var candidates: Array[Node]=screen.find_children("*","ScrollContainer",true,false).filter(func(node: Node) -> bool:return node.is_visible_in_tree() and node.size.y>50 and node.get_v_scroll_bar().max_value>node.size.y+30)
  check(not candidates.is_empty(),"real populated page has scrollable content "+scene_name)
  if not candidates.is_empty():
   var list: ScrollContainer=candidates[0];var pos: Vector2=list.get_global_rect().get_center()
   var old_y: int=list.scroll_vertical
   print("REAL_SCROLL ",scene_name," ",list.get_path()," rect=",list.get_global_rect()," initial=",old_y," max=",list.get_v_scroll_bar().max_value)
   if scene_name=="equipment_screen" and not capture_dir.is_empty() and DisplayServer.get_name()!="headless":
    await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture_dir.path_join("hero-before.png"))
   await swipe(pos,Vector2(0,-85))
   check(list.scroll_vertical>old_y+25,"native first swipe in existing page "+scene_name)
   check(list.scroll_deadzone==Policy.DEADZONE,"same gesture threshold in "+scene_name)
  if scene_name=="equipment_screen":check(screen.selected_item_id.is_empty(),"equipment swipe cannot open detail sheet")
  if scene_name=="mailbox_screen":check(screen._selected_id.is_empty(),"mailbox swipe cannot read a letter")
  current_scene=null;screen.free();await settle()
 server._owner=""
 check(client.snapshot==before,"entire presentation pass preserves authoritative snapshot")
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("EVENT_SCROLL_SURFACE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
