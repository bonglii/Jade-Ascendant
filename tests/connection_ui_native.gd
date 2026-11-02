extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("CONNECTION_UI "+label)
func frames(count: int=12) -> void:
 for i: int in count:await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("connection_combat"):quit(2);return
 if DisplayServer.get_name()=="headless":push_error("Native GUI required");quit(2);return
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self);await create_timer(.4).timeout
 var client: Node=root.get_node("OdysseyClient");client.set_process(false)
 client._binding=root.get_node("GoogleAccountManager").get_monetization_account_binding()
 check(client._binding.length()==64,"isolated account fixture is selected")
 var now: int=int(Time.get_unix_time_from_system())
 var event: Dictionary={"id":"dragon-readiness","enabled":true,"starts_at":now-60,"ends_at":now+3600}
 var money: Dictionary={"pavilion":root.get_node("PavilionManager").state.duplicate(true),"stones":root.get_node("ProgressionManager").spirit_stone,"inventory":root.get_node("InventoryManager").item_counts.duplicate(true)}
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
 var output: String="res://.local/connection_combat_qa/ui_review";DirAccess.make_dir_recursive_absolute(output)
 for locale: String in ["id","en"]:
  root.get_node("SettingsManager").set_presentation("language",locale)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(720,1600)]:
   client.snapshot={};client.status="connecting";client._event_preview={"version":1,"binding":client._binding,"observed_unix":now,"event":event.duplicate(true)}
   root.size=dims;change_scene_to_file("res://scenes/ui/event_center_screen.tscn");await frames(24)
   var page: Control=current_scene
   check(page._hero_stage.visible,"known active event appears while syncing "+locale+str(dims))
   check(page._event_status.text in ["CONNECTING","MENGHUBUNGKAN"],"preview never claims connected")
   check(not page._hero_meter.visible and not client.event_enabled(),"preview has no fabricated progress/action authority")
   check(page._hero_stage.get_global_rect().grow(1).encloses(page._hero_action.get_global_rect()),"event action stays inside its card")
   check(page._hero_stage.get_global_rect().end.x<=root.size.x+1,"event card fits narrow width")
   check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(page._popup.get_rect()),"popup fits the viewport "+locale+str(dims)+str(page._popup.get_rect()))
   for tab: Button in page._filters.values():
    var available: float=tab.size.x-tab.get_theme_stylebox("normal").get_minimum_size().x
    check(tab.get_theme_font("font").get_string_size(tab.text,HORIZONTAL_ALIGNMENT_LEFT,-1,tab.get_theme_font_size("font_size")).x<=available+1,"filter text stays on one readable line")
   await RenderingServer.frame_post_draw
   var pixels: Image=root.get_texture().get_image()
   check(pixels!=null and not pixels.is_empty(),"real native UI image")
   if pixels!=null and not pixels.is_empty():check(pixels.save_png(output+"/%s-%d-preview.png"%[locale,dims.x])==OK,"UI capture saved")
   client._event_preview.event.ends_at=now-1;page._refresh_odyssey();await frames(2)
   check(not page._hero_stage.visible,"expired preview stays hidden")
   client._event_preview={};client.snapshot={"event":event.duplicate(true),"state":{"day":Time.get_date_string_from_system(true),"task_day":Time.get_date_string_from_system(true),"daily_rolls":0,"missions":[],"rolls":6,"milestones":[],"daily_gifts":0,"daily_guardians":0},"server_time":now};client._received_msec=Time.get_ticks_msec();client.status="connected"
   page._refresh_odyssey();await frames(2)
   check(page._hero_stage.visible and page._hero_meter.visible,"authoritative snapshot replaces discovery preview")
   check(page._event_progress.text.begins_with("6 / 72"),"only live snapshot shows player progress")
   check(root.get_node("PavilionManager").state==money.pavilion and root.get_node("ProgressionManager").spirit_stone==money.stones and root.get_node("InventoryManager").item_counts==money.inventory,"discovery/rendering never grants or spends")
 current_scene.queue_free();current_scene=null;await process_frame;await process_frame
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("CONNECTION_UI_NATIVE checks=%d failures=%d; NATIVE_GUI=true; PHONE=NOT_TESTED"%[checks,failures])
 quit(1 if failures else 0)
