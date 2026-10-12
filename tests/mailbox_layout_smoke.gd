extends SceneTree
var checks: int = 0
var failures: int = 0
const LONG_ID: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const SHORT_ID: String = "cccccccccccccccccccccccccccccccc"
func check(ok: bool,tag: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error(tag)
func entry(id: String,long_text: bool,reward: bool = true) -> Dictionary:
 return {"id":"server:"+id,"mail_id":id,"title":("Hadiah perjalanan kultivasi untuk seluruh pendekar Jade Ascendant yang membantu sanctuary hari ini!!!".substr(0,100) if long_text else "Hadiah sanctuary"),"sender":("JADE ASCENDANT SANCTUARY COMMUNITY OPERATIONS AND EVENT SUPPORT".substr(0,60) if long_text else "JADE SANCTUARY"),"body":(("Isi surat untuk semua cultivator.\n".repeat(150)).substr(0,3988)+"\nAKHIR SURAT" if long_text else "Terima kasih.\n\n[b]Ini teks literal.[/b]"),"reward":{"spirit_stone":100000,"items":{"refinement_shard":500}} if reward else {},"created_at":1,"expires_at":int(Time.get_unix_time_from_system())+86400,"read":true,"claimed":false,"pending":false,"can_claim":reward,"blocked_on_other_device":false,"cancelled":false,"expired":false,"receipt_id":""}
func _initialize() -> void: run.call_deferred()
func settled() -> void:
 for n: int in range(4): await process_frame
func inside(outer: Rect2,inner: Rect2) -> bool:
 return inner.position.x >= outer.position.x-1 and inner.position.y >= outer.position.y-1 and inner.end.x <= outer.end.x+1 and inner.end.y <= outer.end.y+1
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_mailbox_layout_qa"): push_error("Isolated mailbox layout QA user:// required");quit(2);return
 await create_timer(0.5).timeout
 var server: Node = root.get_node("ServerMailManager")
 server.set_process(false);server._owner="a".repeat(64);server._auth_node=null
 var fixture: Array = [entry(LONG_ID,true),entry(SHORT_ID,false,false)]
 for n: int in range(8): fixture.append(entry(("%032x" % (n+20)),false))
 if "--expanded-gifts" in OS.get_cmdline_user_args():
  var items: Dictionary = {"refinement_shard":500}
  for id: String in root.get_node("EquipmentManager").get_item_ids().slice(0,5): items[id]=1
  fixture[0].reward={"spirit_stone":100000,"celestial_jade":10000,"pavilion_seal":100,"items":items}
 server._state.cache[server._owner]=fixture
 check(server._valid_mail(fixture[0]),"long fixture obeys server protocol")
 var scene: PackedScene = load("res://scenes/ui/mailbox_screen.tscn")
 for locale: String in ["en","id"]:
  TranslationServer.set_locale(locale)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(896,504),Vector2i(360,640),Vector2i(390,844),Vector2i(540,960),Vector2i(648,960),Vector2i(648,1152),Vector2i(720,1280),Vector2i(800,1200)]:
   var viewport := SubViewport.new();viewport.size=dims;root.add_child(viewport)
   var mail: Control = scene.instantiate();viewport.add_child(mail);await settled();mail._fit_popup();await settled()
   var label: String = str(dims)+" "+locale
   check(mail._selected_id=="server:"+LONG_ID,label+" server mail selected")
   check(mail._letter_subject.text==fixture[0].title and mail._letter_subject.max_lines_visible==-1,label+" full title without line cap")
   check(mail._letter_sender.text.ends_with(fixture[0].sender),label+" full sender")
   check(mail._letter_body.get_parsed_text()==fixture[0].body,label+" all body text retained")
   check(mail._reader_scroll.size.y>=48,label+" nonzero usable reading viewport")
   check(mail._letter_body.size.x>=mail._reader_scroll.size.x*0.7,label+" no single-glyph reader collapse")
   check(inside(mail._letter_panel.get_global_rect(),mail._claim_button.get_global_rect()),label+" claim inside parchment")
   check(inside(mail._letter_panel.get_global_rect(),mail._delete_button.get_global_rect()),label+" delete inside parchment")
   check(mail._rewards_row.size.x<=mail._letter_panel.size.x-20,label+" attachments fit width")
   for tile: Control in mail._rewards_row.get_children():
    check(inside(mail._rewards_row.get_global_rect(),tile.get_global_rect()),label+" exact reward tile fits")
   var bar: VScrollBar = mail._reader_scroll.get_v_scroll_bar()
   check(bar.max_value>bar.page,label+" long document scrolls")
   mail._reader_scroll.scroll_vertical=int(bar.max_value-bar.page);await settled()
   check(mail._reader_content.get_global_rect().end.y<=mail._reader_scroll.get_global_rect().end.y+2,label+" document end reachable")
   var before: int = mail._reader_scroll.scroll_vertical
   mail._refresh_from_authority();await settled()
   check(absi(mail._reader_scroll.scroll_vertical-before)<=1,label+" server refresh retains reading position")
   mail._select_mail("server:"+SHORT_ID);await settled()
   check(mail._letter_body.get_parsed_text()==fixture[1].body,label+" BBCode remains literal for server text")
   check(not mail._claim_button.visible and mail._no_claim_hint.visible,label+" notice state retains actions")
   mail._select_mail("server:"+LONG_ID);await settled()
   check(absi(mail._reader_scroll.scroll_vertical-before)<=1,label+" returning to letter restores reading position")
   for refs: Dictionary in mail._mail_card_refs.values():
    check(inside(refs.button.get_global_rect(),refs.title.get_global_rect()),label+" inbox title inside card")
   mail._toggle_compact_inbox();await settled()
   if mail._body.size.x<450: check(mail._inbox_panel.visible and not mail._letter_panel.visible,label+" inbox toggle")
   viewport.queue_free();await settled()
 print("MAILBOX_LAYOUT_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
