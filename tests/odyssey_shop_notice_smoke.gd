extends SceneTree
var Screen: GDScript
var Announcement: GDScript
var Notifications: GDScript
var Treasury: GDScript
class FakeNative:
 extends RefCounted
 func deferUpdateNotifications()->void: pass
class EventClient extends Node:
 signal changed
 signal finished(action: String,success: bool)
 var snapshot: Dictionary={}
 var status: String="NETWORK_UNAVAILABLE"
 var busy: bool=false
 var now: int=1800000000
 func server_time()->int: return now
 func purchase_bonus_active()->bool: return status=="connected" and bool(snapshot.get("purchase_bonus",{}).get("active",false))
 func refresh()->bool: return true
 func submit(_action: Dictionary)->bool: return false
func _initialize()->void: call_deferred("run")
func bounded(inner: Control,outer: Control,margin: float=0.0)->void:
 var a: Rect2=inner.get_global_rect();var b: Rect2=outer.get_global_rect().grow(1.0-margin)
 assert(b.encloses(a),"UI bounds escaped: "+str(inner.name)+" "+str(a)+" vs "+str(b))
func run()->void:
 Screen=load("res://scripts/ui/odyssey_screen.gd");Announcement=load("res://scripts/managers/announcement_center.gd");Notifications=load("res://scripts/managers/update_notifications.gd");Treasury=load("res://scripts/ui/liveops/celestial_treasury_screen.gd")
 var actual_client: Node=load("res://scripts/monetization/odyssey_client.gd").new()
 actual_client.status="connected";actual_client._received_msec=Time.get_ticks_msec();actual_client.snapshot={"server_time":1800000000,"event":{"enabled":true,"purchases_enabled":true,"starts_at":1799999900,"ends_at":1800000100},"purchase_bonus":{"active":true}}
 assert(actual_client.purchase_bonus_active())
 actual_client.status="NETWORK_UNAVAILABLE";assert(not actual_client.purchase_bonus_active())
 actual_client.status="connected";actual_client.snapshot.event.ends_at=1799999999;assert(not actual_client.purchase_bonus_active());actual_client.free()
 create_timer(25).timeout.connect(func()->void: quit(1))
 for dimensions: Vector2i in [Vector2i(360,640),Vector2i(412,915),Vector2i(648,1152),Vector2i(840,400)]:
  var view:=SubViewport.new();view.size=dimensions;root.add_child(view)
  var screen: Control=Screen.new();screen.size=Vector2(dimensions);view.add_child(screen)
  var client:=EventClient.new();client.name="OdysseyClient";root.add_child(client);screen.client=client
  screen._refresh();await process_frame;await process_frame
  assert(not screen.buy.disabled);assert(not screen.countdown.text.contains("NOT YET SCHEDULED"))
  screen._shop();await process_frame;await process_frame
  var modal: Control=screen.modal;var panels: Array[Node]=modal.find_children("*","PanelContainer",true,false);assert(not panels.is_empty())
  var panel: Control=panels[0];bounded(panel,modal)
  for child: Node in modal.find_children("*","Label",true,false):
   var text: Label=child as Label
   # Scroll content may extend vertically; all text must stay within frame horizontally.
   assert(text.get_global_rect().position.x>=panel.get_global_rect().position.x+40)
   assert(text.get_global_rect().end.x<=panel.get_global_rect().end.x-40)
  screen._close_modal()
  client.status="connected";client.snapshot={"event":{"id":"dragon-test","enabled":true,"purchases_enabled":true,"starts_at":client.now-100,"ends_at":client.now+10000},"purchase_bonus":{"active":true,"offers":[{"product_id":"jade_satchel_550","jade":550,"dice":3,"claimed":false}]}}
  screen._shop();await process_frame;await process_frame
  var found: bool=false
  for node: Node in screen.modal.find_children("*","Button",true,false):
   if (node as Button).text=="550 JADE + 3 BONUS DICE": found=true
  assert(found)
  screen._open_treasury("jade_satchel_550")
  assert(root.get_node("SceneTransitionManager").destination=="res://scenes/ui/celestial_treasury_screen.tscn")
  assert(get_meta("odyssey_treasury_product","")=="jade_satchel_550")
  remove_meta("odyssey_treasury_product");remove_meta("odyssey_treasury_return")
  var treasury: Control=Treasury.new();view.add_child(treasury)
  treasury._catalog={"jade_satchel_550":{"celestial_jade":550}};treasury._selected_id="jade_satchel_550";treasury._update_details()
  assert(treasury._details_body.text.contains("550 Celestial Jade + 3 bonus travel dice"))
  client.snapshot.purchase_bonus.offers[0].claimed=true;treasury._update_details()
  assert(treasury._details_body.text.contains("already been claimed"))
  treasury._cards_by_id["jade_satchel_550"]=treasury._create_card("jade_satchel_550")
  client.snapshot.purchase_bonus.offers[0].claimed=false;treasury._refresh_storefront()
  assert(treasury._cards_by_id.jade_satchel_550.badge.text=="+3 BONUS DICE")
  client.snapshot={};client.status="NETWORK_UNAVAILABLE";treasury._refresh_storefront()
  assert(treasury._cards_by_id.jade_satchel_550.badge.text=="CELESTIAL JADE")
  treasury.queue_free();screen._close_modal();screen.queue_free();client.queue_free();await process_frame
  var announcement: CanvasLayer=Announcement.new();view.add_child(announcement);announcement.set_process(false);announcement._build()
  announcement._title.text="UPDATE "+"long title ".repeat(10);announcement._body.text=("Long update description and https://example.invalid/"+"x".repeat(300)+"\n").repeat(10);announcement._kind.text="PENGUMUMAN SANCTUARY";announcement._button.text="MENGERTI";announcement._fit();announcement.show()
  await process_frame;await process_frame;bounded(announcement._panel,announcement._shade)
  bounded(announcement._scroll,announcement._panel,24);bounded(announcement._button,announcement._panel,24)
  assert(announcement._scroll.get_v_scroll_bar().max_value>announcement._scroll.size.y)
  announcement.queue_free();await process_frame
  var notifications: CanvasLayer=Notifications.new();view.add_child(notifications);notifications.native=FakeNative.new();notifications._show_prompt();await process_frame;await process_frame
  var notification_panel: Control=notifications._shade.find_child("UpdateNoticeBoundedPanel",true,false);bounded(notification_panel,notifications._shade)
  for text: Node in notification_panel.find_children("*","Label",true,false):
   assert((text as Control).get_global_rect().end.x<=notification_panel.get_global_rect().end.x-30)
  notifications._dismiss();notifications.queue_free();view.queue_free();await process_frame
 print("ODYSSEY_SHOP_NOTICE_UI=PASS; FOUR_VIEWPORTS; LONG_LETTER_SCROLL; BOUNDED_CONSENT; OFFLINE_SHOP; NO_FALSE_SCHEDULE; TREASURY_COMPILED")
 quit()
