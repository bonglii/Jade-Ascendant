extends SceneTree
## Source-only candidate QA; run in a disposable Godot 4.7.2 user-data sandbox.
## No production identity, payments, ads, reward grants, or live Worker access.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
 run.call_deferred()

func check(ok: bool, context: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("PLAYER_FEATURES_FAIL " + context)

func frames(count: int=6) -> void:
 for i: int in range(count):
  await process_frame

func run() -> void:
 if not OS.get_user_data_dir().contains("jade_event_touch_qa"):
  push_error("PLAYER_FEATURES_QA_REQUIRES_ISOLATED_USER_DIR")
  quit(2)
  return
 create_timer(80.0).timeout.connect(func():push_error("PLAYER_FEATURES_TIMEOUT");quit(1))
 await frames(15)
 var companion: Node=root.get_node("PlayerCompanion")
 var equipment: Node=root.get_node("EquipmentManager")
 var journey: Node=root.get_node("JourneyManager")
 var progress: Node=root.get_node("ProgressionManager")
 var pavilion: Node=root.get_node("PavilionManager")
 var inventory: Node=root.get_node("InventoryManager")
 var starting_equipment: Dictionary=equipment.build_equipment_save_data().duplicate(true)
 var starting_journey: Dictionary=journey.build_save_data().duplicate(true)
 var starting_inventory: Dictionary=inventory.item_counts.duplicate(true)
 var starting_jade: int=pavilion.get_local_celestial_jade()
 var starting_stones: int=progress.spirit_stone
 var empty: Dictionary=companion._empty()
 check(not empty.metrics_opt_in and empty.metrics.is_empty(),"telemetry starts disabled")
 check(companion.valid_slots(preload("res://scripts/companion/equipment_projection.gd").slots()),"current equip slots validate")
 var normal: Dictionary={"id":"a".repeat(32),"kind":"stage_enter","chapter":1,"stage":1,"seconds":42}
 check(companion.valid_metric(normal),"normal metric validates")
 var wrong: Dictionary=normal.duplicate(true)
 wrong.stage=7
 check(not companion.valid_metric(wrong),"invalid stage cannot enter analytics queue")
 wrong=normal.duplicate(true)
 wrong.seconds=-1
 check(not companion.valid_metric(wrong),"negative duration rejected")
 var full: Dictionary=empty.duplicate(true)
 full.metrics_opt_in=true
 for i: int in range(105):
  var item: Dictionary=normal.duplicate(true)
  item.id=("%032x" % i)
  full.metrics.append(item)
 check(companion._clean(full).metrics.size()==100,"reload admits 100 bounded events")
 check(companion._clean(full).metrics[99].id==("%032x" % 99),"bounded queue preserves declared ordering")
 check(companion.state.metrics_opt_in==false,"opt-in not enabled by pure validators")
 # Training uses real weapon and enemy code, but cannot produce Journey currency, items or XP.
 var error: Error=change_scene_to_file("res://scenes/ui/training_ground.tscn")
 check(error==OK,"practice scene can instantiate")
 if error!=OK:
  await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  quit(1)
  return
 await frames(15)
 var practice: Node=current_scene
 check(practice!=null and bool(practice.get_meta("companion_practice",false)),"practice mode explicitly isolated")
 var actor: Node=practice.get_node_or_null("player_1")
 check(actor!=null,"production player instantiated")
 check(equipment.is_practice(),"equipment uses read-only practice loadout")
 var enemy_count: int=0
 for target: Node2D in practice.targets:
  if not is_instance_valid(target): continue
  enemy_count+=1
  check(target.is_in_group("companion_training_target") and target.contact_damage==0.0,"dummy cannot injure player or grant regular kills")
 check(enemy_count==3,"three training targets available")
 if enemy_count>0:
  var target: Node2D=practice.targets[0]
  target.take_damage(1.0e15)
  await frames(3)
  check(target.is_dead and not target.get_parent()==null,"training kill remains local without enemy destruction")
  check(not target.is_in_group("enemy"),"defeated training dummy is no longer auto-targetable")
  check(actor.experience==0,"training kill does not spawn XP")
 check(equipment.build_equipment_save_data()==starting_equipment,"practice leaves permanent equipment untouched")
 check(journey.build_save_data()==starting_journey,"practice leaves Journey progress untouched")
 check(inventory.item_counts==starting_inventory,"practice leaves inventory untouched")
 check(pavilion.get_local_celestial_jade()==starting_jade,"practice grants zero Jade")
 check(progress.spirit_stone==starting_stones,"practice grants zero Spirit Stones")
 paused=false
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if is_instance_valid(practice):
  current_scene=null
  practice.free()
 await frames(3)
 print("PLAYER_FEATURES_QA checks=%d failures=%d; ANDROID_TOUCH=NOT_TESTED; PROFILE_DEPLOY=NONE"%[checks,failures])
 quit(1 if failures else 0)
