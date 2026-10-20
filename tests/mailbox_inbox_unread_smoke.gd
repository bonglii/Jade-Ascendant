extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void: run.call_deferred()
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("MAIL_INBOX "+label)
func frames() -> void:
 for index: int in 5:await process_frame
func inside(outer: Rect2,inner: Rect2) -> bool:
 return inner.position.x>=outer.position.x-1 and inner.position.y>=outer.position.y-1 and inner.end.x<=outer.end.x+1 and inner.end.y<=outer.end.y+1
func run() -> void:
 create_timer(25.0).timeout.connect(func(): quit(1))
 if not OS.get_user_data_dir().contains("jade_mail_session_qa"):quit(2);return
 await create_timer(.3).timeout
 var server: Node=root.get_node("ServerMailManager");server._owner="inbox_fixture".sha256_text();server._auth_node=null
 var id: String="%032x" % 50001
 var entry: Dictionary={"id":"server:"+id,"mail_id":id,"title":"Hadiah perjalanan kultivasi untuk para pendekar yang menjaga sanctuary sepanjang hari ini!!!","body":"Baca surat ini setelah mengetuk kartunya.","sender":"JADE SANCTUARY","reward":{"spirit_stone":10,"items":{}},"created_at":1700000000,"expires_at":1900000000,"read":false,"claimed":false,"pending":false,"can_claim":true,"blocked_on_other_device":false,"cancelled":false,"expired":false}
 var scene: PackedScene=load("res://scenes/ui/mailbox_screen.tscn")
 for locale: String in ["id","en"]:
  TranslationServer.set_locale(locale)
  for size: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(1280,1200)]:
   server._state.cache[server._owner]=[entry.duplicate(true)];server._state.read_pending={}
   var viewport:=SubViewport.new();viewport.size=size;root.add_child(viewport)
   var screen: Control=scene.instantiate();viewport.add_child(screen);await frames();screen._fit_popup();await frames()
   var tag: String=str(size)+" "+locale
   check(screen._selected_id.is_empty() and screen._compact_inbox_open,tag+" opens Inbox with no automatic selection")
   check(screen._inbox_panel.visible,tag+" inbox visible immediately")
   if screen._body.size.x<screen.WIDE_READER_THRESHOLD:check(not screen._letter_panel.visible,tag+" mobile reader stays closed until tap")
   check(not bool(server.get_mail(entry.id).read),tag+" opening screen does not consume unread marker")
   var refs: Dictionary=screen._mail_card_refs[entry.id]
   check(refs.unread_dot.visible and inside(refs.button.get_global_rect(),refs.unread_dot.get_global_rect()),tag+" unread dot fits inside card top corner")
   check(inside(refs.button.get_global_rect(),refs.title.get_global_rect()),tag+" long title stays inside card beside dot")
   screen._scroll_active=true;refs.button.button_down.emit();refs.button.pressed.emit();await frames()
   check(screen._selected_id.is_empty() and not bool(server.get_mail(entry.id).read),tag+" swipe never reads the letter")
   screen._scroll_active=false;screen._tap_guard_until=0
   refs.button.button_down.emit();refs.button.pressed.emit();await frames()
   check(screen._selected_id==entry.id and screen._letter_panel.visible,tag+" single tap opens selected letter")
   check(bool(server.get_mail(entry.id).read) and not screen._mail_card_refs[entry.id].unread_dot.visible,tag+" only selected letter loses red dot")
   check(screen._claim_button.text!="CONNECTING" and not screen._claim_button.disabled,tag+" cosmetic read does not disable claim")
   viewport.queue_free();await frames()
 server._owner=""
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 for index: int in 4:await process_frame
 print("MAILBOX_INBOX_UNREAD checks=",checks," failures=",failures,"; FOUR_VIEWPORTS_TWO_LANGUAGES")
 call_deferred("quit",1 if failures else 0)
