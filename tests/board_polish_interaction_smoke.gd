extends SceneTree
const Dot=preload("res://scripts/ui/action_ready_dot.gd")
const Board=preload("res://scripts/ui/liveops/odyssey_board.gd")
var checks: int=0
var failures: int=0
var travel_signals: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("BOARD_POLISH "+caption)
func settle(frames: int=8) -> void:
 for i in range(frames):await process_frame
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_celestial_board_qa"):quit(2);return
 create_timer(35).timeout.connect(func() -> void:quit(1))
 await create_timer(.3).timeout
 var settings: Node=root.get_node("SettingsManager");settings.reduced_effects=false
 var board: Control=Board.new();board.size=Vector2(600,500);root.add_child(board);board.set_process(false)
 board.travel_finished.connect(func() -> void:travel_signals+=1)
 check(board.token.sprite_frames.get_frame_texture("walk_down",0).get_width()==192,"board has high resolution source-derived frames")
 board.show_position(4);var first: Vector2=board.point(4);board.show_position(5,1);board._process(.1)
 var at: Vector2=board.token.position+Vector2(0,Board.FEET*board.token.scale.x)
 check(at.x>first.x and at.x<board.point(5).x,"first 100ms moves part way, never teleports")
 check(board.selected==4 and travel_signals==0,"destination is not selected before arriving")
 board._process(.24);check(board.is_travelling() and travel_signals==0,"arrival remains locked during readable landing")
 board._process(.23);check(not board.is_travelling() and board.selected==5 and travel_signals==1,"one completion after landing")
 check(board.token.position.is_equal_approx(board.point(5)-Vector2(0,Board.FEET*board.token.scale.x)),"feet land on the exact tile anchor")
 board.show_position(18);board.show_position(4,6);board._process(.7)
 check(board.is_travelling() and board.selected==18,"six steps stay readable after 700ms")
 board.show_position(2,4);check(board._destination==4,"duplicate movement request cannot restart active travel")
 for i in range(22):board._process(.06)
 check(not board.is_travelling() and board.selected==4 and travel_signals==2,"wraparound and turn finish once at authoritative tile")
 settings.reduced_effects=true;board.show_position(10,6);board._process(.1);check(board.is_travelling(),"reduced motion still shows movement")
 board._process(1.1);board._process(.23);check(not board.is_travelling() and board.selected==10,"reduced motion ends without ambient flash")
 board.set_reward_stops({"seal_tiles":[9,17]},[9]);check(board.seal_stops==[9,17] and board.claimed_seals==[9],"board visuals use the server's reward definition")
 board.set_reward_stops({},[]);check(board.seal_stops.is_empty(),"old server snapshot never invents available seal rewards")
 board.free();settings.reduced_effects=false
 var now: int=int(Time.get_unix_time_from_system());var today: String=Time.get_datetime_string_from_unix_time(now).substr(0,10)
 var snap: Dictionary={"event":{"id":"dragon-qa","enabled":true,"starts_at":now-100,"ends_at":now+86400},"state":{"day":today,"task_day":today,"daily_rolls":5,"missions":[],"task_claims":[],"daily_gifts":3,"daily_guardians":1,"rolls":48,"milestones":[]}}
 check(Dot.odyssey_count(snap,now)==7,"five daily claims plus two milestones aggregate")
 snap.state.missions=[1,3,5];snap.state.task_claims=["gifts","guardian"];snap.state.milestones=[24,48]
 check(Dot.odyssey_count(snap,now)==0,"all claimed removes attention")
 snap.state.missions=[];snap.state.task_claims=[];snap.state.milestones=[];snap.state.day="old";snap.state.task_day="old"
 check(Dot.odyssey_count(snap,now)==2,"stale daily counters cannot create false dots")
 snap.event.enabled=false;check(Dot.odyssey_count(snap,now)==0,"paused event has no false claim notification")
 snap.event.enabled=true;check(Dot.odyssey_count(snap,now+86401)==2,"unclaimed milestones remain visible in claim grace")
 check(Dot.odyssey_count(snap,now+4*86400)==0,"claim grace expiry clears the dot")
 var host:=Button.new();host.size=Vector2(120,60);root.add_child(host)
 var badge: Panel=Dot.show_on(host,4);var identity: int=badge.get_instance_id()
 for i in range(100):Dot.show_on(host,1)
 check(host.get_child_count()==1 and badge.get_instance_id()==identity,"refresh reuses one badge, no stacking")
 check(badge.mouse_filter==Control.MOUSE_FILTER_IGNORE and badge.z_index==0,"badge neither intercepts touch nor escapes modal stacking")
 check(host.get_rect().encloses(badge.get_rect()),"dot stays inside its touch target")
 Dot.show_on(host,0);check(not badge.visible,"zero claims hides dot immediately");host.free()
 var daily: Node=root.get_node("DailyQuestManager");daily.completed_quest_ids.assign([daily.get_daily_quest_ids()[0]]);daily.claimed_quest_ids.clear()
 var nav: Control=load("res://scripts/ui/wuxia_hub_nav.gd").new();nav.size=Vector2(648,90);root.add_child(nav);await settle()
 nav._refresh_notification_badge();check(nav.tab_buttons[3].get_node("ActionReadyDot").visible,"real Trials manager drives bottom navigation dot")
 daily.claimed_quest_ids.assign(daily.completed_quest_ids);nav._refresh_notification_badge()
 check(not nav.tab_buttons[3].get_node("ActionReadyDot").visible,"claiming daily rewards clears bottom tab")
 nav.free()
 var client: Node=root.get_node("OdysseyClient");client.set_process(false)
 snap.event.ends_at=now+86400;snap.state.day=today;snap.state.task_day=today;snap.state.tickets=6;snap.state.position=4;snap.state.last_die=0;snap.state.notice="Board QA";snap.server_time=now;snap.revision=1;snap.state.board_rewards={"seal_tiles":[9,17]}
 client.snapshot=snap;client._received_msec=Time.get_ticks_msec();client.status="connected";client.busy=false
 var viewport:=SubViewport.new();viewport.size=Vector2i(648,1152);root.add_child(viewport)
 var page: Control=load("res://scenes/ui/odyssey_screen.tscn").instantiate();viewport.add_child(page);page.set_process(false);await settle()
 check(page.milestones[0].get_node("ActionReadyDot").visible,"earned milestone has a red dot on the real board button")
 page._missions();var modal_id: int=page.modal.get_instance_id()
 for i in range(100):page._missions()
 check(page.modal.get_instance_id()==modal_id,"100 mission taps preserve one sheet instance")
 check(page._modal_panel.get_theme_stylebox("panel").get_script()!=null,"all board modals use the shared transparent rounded texture")
 check(page.modal.get_node("JadeModalScrim").color.a<=.5,"modal backdrop stays jade-tinted and bounded")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152),Vector2i(896,504)]:
  viewport.size=dims;await settle();page._fit_popup();await settle()
  check(Rect2(Vector2.ZERO,Vector2(dims)).encloses(page._modal_panel.get_rect()),"mission panel fits "+str(dims))
  check(page._modal_body.get_parent().horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"no horizontal scroll "+str(dims))
 page._close_modal();check(not page._presenting(),"closing modal restores no phantom animation lock")
 for entry: Array in [["_shop","shop"],["_info","info"],["_journey_rewards","journey"]]:
  page.call(entry[0]);var existing_id: int=page.modal.get_instance_id()
  for i in range(100):page.call(entry[0])
  check(page.modal.get_instance_id()==existing_id,"one sheet after 100 taps: "+str(entry[1]));page._close_modal()
 page._confirm_pack(1,10);var confirm_id: int=page.modal.get_instance_id()
 for i in range(100):page._confirm_pack(1,10)
 check(page.modal.get_instance_id()==confirm_id,"confirmation sheet cannot be rebuilt by repeated taps");page._close_modal()
 viewport.free();await settle()
 var journey: Node=root.get_node("JourneyManager");var stage: String=journey.get_stage_key(1,5)
 if stage not in journey.cleared_stage_keys:journey.cleared_stage_keys.append(stage)
 var pavilion_view:=SubViewport.new();pavilion_view.size=Vector2i(648,1152);root.add_child(pavilion_view)
 var pavilion: Control=load("res://scenes/ui/pavilion_screen.tscn").instantiate();pavilion_view.add_child(pavilion);await settle(15)
 pavilion._open_target_picker();var picker_id: int=pavilion._target_overlay.get_instance_id();var epoch: int=pavilion._target_epoch
 for i in range(100):pavilion._open_target_picker()
 check(pavilion._target_overlay.get_instance_id()==picker_id and pavilion._target_epoch==epoch,"100 Choose Equipment taps cannot rebuild or duplicate picker")
 for i in range(50):pavilion._open_target_picker("set" if i%2==0 else "weapon")
 await settle()
 check(is_instance_valid(pavilion._target_overlay) and pavilion.find_children("TargetChoices","GridContainer",true,false).size()==1,"alternating tabs retain exactly one live picker after deferred cleanup")
 pavilion._close_target_picker();pavilion._sheet_guard_until=0;pavilion._show_drop_rates_overlay()
 var rates_id: int=pavilion.locked_rates_overlay.get_instance_id()
 for i in range(100):pavilion._show_drop_rates_overlay()
 check(pavilion.locked_rates_overlay.get_instance_id()==rates_id,"rates sheet has the same anti-spam contract")
 pavilion._close_rates_overlay();pavilion._sheet_guard_until=0;pavilion._show_history_overlay()
 var history_id: int=pavilion.locked_history_overlay.get_instance_id()
 for i in range(100):pavilion._show_history_overlay()
 check(pavilion.locked_history_overlay.get_instance_id()==history_id,"history sheet has the same anti-spam contract")
 pavilion_view.free();await settle();await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("BOARD_POLISH_INTERACTION checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
