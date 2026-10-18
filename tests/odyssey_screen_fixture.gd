extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_warning_cleanup_qa"): quit(2); return
 var client: Node = root.get_node("OdysseyClient")
 client.set_process(false)
 client.snapshot={"event":{"id":"dragon-1","enabled":true,"ads_enabled":true,"purchases_enabled":true,"starts_at":int(Time.get_unix_time_from_system())-86400,"ends_at":int(Time.get_unix_time_from_system())+10*86400},"state":{"tickets":6,"rolls":36,"position":4,"last_die":4,"day":Time.get_date_string_from_system(true),"daily_ads":0,"notice":"Celestial supplies secured. Choose your next journey."},"revision":1,"server_time":int(Time.get_unix_time_from_system())}
 client.status="connected"
 var screen: Control = load("res://scenes/ui/odyssey_screen.tscn").instantiate()
 root.add_child(screen); current_scene=screen
 screen.set_process(false); client.busy=false; client.status="connected"; screen._refresh()
 await process_frame; await process_frame
 var mode: String=OS.get_environment("ODYSSEY_MODAL")
 if mode in ["_routes","_shop","_ceremony","_info"]:screen.call(mode)
 await process_frame; await process_frame
 if mode == "_ceremony": await create_timer(2.2).timeout
 print("ODYSSEY_LAYOUT size=",screen.size," board=",screen.board.size)
 for node: Node in [screen.tickets,screen.progress,screen.board,screen.roll,screen.ad,screen.buy]:
  print("ODYSSEY_RECT ",node.name," pos=",node.global_position," size=",node.size," min=",node.get_combined_minimum_size()," parent=",node.get_parent().size)
 var image: Image=get_root().get_texture().get_image()
 if image!=null:image.save_png(OS.get_environment("ODYSSEY_CAPTURE") if not OS.get_environment("ODYSSEY_CAPTURE").is_empty() else "/tmp/odyssey-screen.png")
 current_scene = null
 screen.free(); screen = null; await process_frame
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit()
