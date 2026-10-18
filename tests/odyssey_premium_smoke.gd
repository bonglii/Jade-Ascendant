extends SceneTree
class FakeClient:
 extends Node
 signal changed
 signal finished(action: String, success: bool)
 var busy: bool=false
 var status: String="connected"
 var snapshot: Dictionary={"revision":1,"server_time":1792335000,"event":{"id":"dragon-odyssey-1","starts_at":1792334000,"ends_at":1793543600,"enabled":true,"ads_enabled":true,"purchases_enabled":true},"limits":{"price_one":10,"price_five":40},"state":{"tickets":6,"rolls":16,"last_die":4,"position":8,"daily_ads":0,"daily_bought":0,"season_bought":0,"daily_rolls":2,"missions":[1],"milestones":[],"pending":"","battle":null,"day":"2026-10-18","last_reward":{},"notice":"Welcome, cultivator."}}
 func server_time() -> int: return int(snapshot.server_time)
 func refresh() -> bool: changed.emit(); return true
 func watch_ad() -> bool: return true
 func submit(action: Dictionary) -> bool:
  if busy:return false
  busy=true; changed.emit(); get_tree().create_timer(0.08).timeout.connect(_response.bind(action)); return true
 func _response(action: Dictionary) -> void:
  snapshot.revision+=1
  if action.kind=="roll": snapshot.state.rolls+=1; snapshot.state.tickets-=1; snapshot.state.position=(snapshot.state.position+3)%20; snapshot.state.last_die=3; snapshot.state.last_reward={"spirit_stone":20}
  busy=false; finished.emit(action.kind,true); changed.emit()
class FakeWallet:
 extends Node
 func paid_balance() -> int:return 100
func _initialize() -> void: call_deferred("run")
func wait(seconds: float) -> void: await create_timer(seconds).timeout
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 var destination: String=OS.get_environment("JADE_ODYSSEY_QA_OUTPUT")
 if destination.is_empty(): destination=ProjectSettings.globalize_path("user://")
 await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(destination)
 get_root().get_texture().get_image().save_png(destination.path_join("odyssey-"+name+".png"))
func run() -> void:
 var client:=FakeClient.new(); client.name="OdysseyClient"; root.add_child(client)
 var pavilion:=Node.new(); pavilion.name="PavilionManager"; var wallet:=FakeWallet.new(); wallet.name="PaidGameplayV2"; pavilion.add_child(wallet); root.add_child(pavilion)
 var screen: Control=load("res://scripts/ui/odyssey_screen.gd").new(); root.add_child(screen)
 if DisplayServer.get_name()=="headless": screen.size=Vector2(648,1152)
 else: screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 await wait(0.7); await capture("main")
 assert(screen.roll.get_global_rect().end.y<=screen.size.y)
 assert(screen.ad.get_global_rect().end.y<=screen.size.y)
 assert(screen.buy.get_global_rect().end.x<=screen.size.x)
 print("LAYOUT root=",root.size," board=",screen.board.size," roll=",screen.roll.get_global_rect()," ad=",screen.ad.get_global_rect()," buy=",screen.buy.get_global_rect())
 screen._shop(); await wait(0.3); await capture("shop"); screen._close_modal(); screen._missions(); await wait(0.3); await capture("missions"); screen._close_modal()
 screen._submit({"kind":"roll"}); await wait(0.2)
 assert(screen._presenting()); assert(screen.roll.disabled); assert(not screen.board.is_travelling())
 await wait(0.55); await capture("rolling"); await wait(1.1)
 assert(not screen._presenting()); assert(screen.board.selected==11); assert(screen.dice_view.face==3)
 print("ODYSSEY_PRESENTATION_FLOW=PASS; NO_EARLY_MOVEMENT; NO_DOUBLE_ROLL; SERVER_DIE_PRESERVED")
 await capture("landed")
 screen._close_modal(); client.snapshot.state.pending="route"; client.changed.emit(); await wait(0.1); screen._close_modal()
 assert(not screen.roll.disabled); screen._roll_pressed(); assert(screen._modal_kind=="route"); screen._close_modal()
 client.snapshot.state.pending=""; client.changed.emit(); screen._submit({"kind":"roll"}); await wait(0.15)
 client.snapshot.owner_binding="new_account"; client.snapshot.state.rolls=0; client.snapshot.state.position=0; client.changed.emit(); await wait(1.2)
 assert(not screen._presenting()); assert(screen.board.selected==0); assert(not screen.dice_view.visible)
 root.get_node("SettingsManager").set("reduced_effects",true); screen._submit({"kind":"roll"}); await wait(1.2); assert(not screen._presenting()); assert(screen.board.selected==3)
 print("ODYSSEY_ACCOUNT_SWITCH_AND_REDUCED_EFFECTS=PASS")
 client.snapshot.event.enabled=false; client.changed.emit(); assert(screen.roll.disabled and screen.ad.disabled and screen.buy.disabled)
 client.snapshot.event.enabled=true; client.snapshot.event.starts_at=client.server_time()+3600; client.changed.emit(); assert(screen.roll.disabled); assert(screen.countdown.text.begins_with("STARTS IN"))
 client.snapshot.event.starts_at=client.server_time()-100; client.snapshot.event.ends_at=client.server_time()-1; client.snapshot.state.rolls=72; client.changed.emit()
 assert(not screen.milestones[2].disabled); assert(screen.roll.disabled and screen.ad.disabled and screen.buy.disabled and screen.missions_button.disabled)
 client.snapshot.event.ends_at=client.server_time()-4*86400; client.changed.emit(); assert(screen.milestones[2].disabled)
 print("ODYSSEY_SCHEDULE_AND_GRACE_GATES=PASS")
 root.get_node("SettingsManager").set("reduced_effects",false)
 screen._ceremony(); await wait(1.8); await capture("ceremony")
 quit()
