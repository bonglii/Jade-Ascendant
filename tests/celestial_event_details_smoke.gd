extends SceneTree
const Dot=preload("res://scripts/ui/action_ready_dot.gd")
var checks: int=0
var failures: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("CELESTIAL_DETAILS "+caption)
func _initialize() -> void:run.call_deferred()
func settle(frames: int=8) -> void:
 for frame: int in range(frames):await process_frame
func buttons_with_method(node: Node,method: String) -> Array[Button]:
 var result: Array[Button]=[]
 if node is Button:
  for connection: Dictionary in node.pressed.get_connections():
   if connection.callable.get_method()==method:result.append(node)
 for child: Node in node.get_children():result.append_array(buttons_with_method(child,method))
 return result
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_celestial_board_qa"):quit(2);return
 create_timer(45).timeout.connect(func() -> void:quit(1))
 await create_timer(.3).timeout
 var script_paths: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/celestial_changed_scripts.json"))
 check(script_paths is Array and not script_paths.is_empty(),"delivery provides an explicit list of every changed GDScript")
 if script_paths is Array:
  for source: String in script_paths:
   var script: Script=load(source)
   check(script!=null and script.can_instantiate(),"explicit compile "+source)
 if failures>0:
  print("CELESTIAL_DETAILS_COMPILE_FAILED checks=%d failures=%d"%[checks,failures]);quit(1);return
 var live: Node=root.get_node("LiveOpsManager");var pavilion: Node=root.get_node("PavilionManager")
 var viewport:=SubViewport.new();viewport.size=Vector2i(390,844);root.add_child(viewport)
 var login: Control=load("res://scenes/ui/new_player_event_screen.tscn").instantiate();login.set_meta("liveops_popup",true);viewport.add_child(login);await settle(12)
 check(login._day_card_refs.size()==7,"actual seven-day screen builds all seven cards")
 for locale: String in ["en","id"]:
  TranslationServer.set_locale(locale)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
   viewport.size=dims;await settle();login._refresh();await settle()
   for day: int in range(1,8):
    var card: Button=login._day_card_refs[day].card
    var dot: Panel=card.get_node_or_null("ActionReadyDot")
    check(dot!=null,"day card has declared shared dot "+str(day)+locale)
    if dot!=null:check(dot.visible==(live.is_login_day_unlocked(day) and not live.is_login_day_claimed(day)),"day readiness follows actual ledger "+str(day)+locale)
   check(login._action.get_node("ActionReadyDot").visible==not login._action.disabled,"selected claim button readiness "+locale)
 var first_card: Button=login._day_card_refs[1].card;var identity: int=first_card.get_node("ActionReadyDot").get_instance_id()
 for refresh: int in range(30):login._refresh_day_card(1)
 check(first_card.get_node("ActionReadyDot").get_instance_id()==identity,"repeated refresh reuses day badge")
 var ledger: Array[String]=live._get_ledger();ledger.append(live._login_claim_marker(1));pavilion.state["claimed_milestone_ids"]=ledger;login._refresh();await settle()
 check(not login._day_card_refs[1].card.get_node("ActionReadyDot").visible,"claimed day clears its own badge")
 check(not login._action.get_node("ActionReadyDot").visible,"claimed day clears selected action badge")
 login.free();await settle()
 # All five trial claims unlock a separate final Convergence reward.
 ledger=live._get_ledger()
 for trial: String in live.get_five_elements_trial_ids():ledger.append(live.FIVE_ELEMENTS_CLAIM_PREFIX+trial)
 pavilion.state["claimed_milestone_ids"]=ledger
 var elements: Control=load("res://scenes/ui/path_of_five_elements_screen.tscn").instantiate();viewport.add_child(elements);await settle()
 var convergence_buttons: Array[Button]=buttons_with_method(elements,"_claim_convergence")
 check(not convergence_buttons.is_empty(),"actual Five Elements screen creates final claim action")
 for button: Button in convergence_buttons:
  check(not button.disabled and button.get_node_or_null("ActionReadyDot")!=null and button.get_node("ActionReadyDot").visible,"Convergence dot available after all trial rewards")
 for locale: String in ["en","id"]:
  TranslationServer.set_locale(locale)
  for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
   viewport.size=dims;await settle();elements._refresh();await settle()
   check(Dot.count(elements,"five_elements")==1,"final reward remains claimable during resize and translation "+locale+str(dims))
 ledger.append(live.FIVE_ELEMENTS_CLAIM_PREFIX+live.FIVE_ELEMENTS_CONVERGENCE_ID);pavilion.state["claimed_milestone_ids"]=ledger;elements._refresh();await settle()
 check(Dot.count(elements,"five_elements")==0,"final reward marker clears event badge")
 check(buttons_with_method(elements,"_claim_convergence").is_empty(),"claimed Convergence cannot expose a second claim")
 elements.free();await settle()
 # Remaining local detail screens are opened too, not only their hub cards.
 for scene: String in ["jade_valley_pilgrimage_screen","celestial_boss_hunt_screen","heavenly_ladder_screen","celestial_treasure_hunt_screen"]:
  var detail: Control=load("res://scenes/ui/"+scene+".tscn").instantiate();viewport.add_child(detail);await settle()
  check(detail.is_inside_tree() and detail.get_child_count()>0,"real detail scene opens "+scene)
  detail.free();await settle()
 viewport.free();await settle();await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("CELESTIAL_DETAILS checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
