extends SceneTree
## Targeted dependency smoke only; unchanged gameplay QA is reused.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("CLEANUP_RESOURCE_FAIL "+label)
func frames(n: int=12) -> void:
 for i: int in range(n):await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_paid_v2_qa"):quit(2);return
 await frames()
 check(load("res://assets/ui/liveops/mail/spirit_messages_jade_frame.png") is Texture2D,"canonical frame loads")
 for pair: Array in [["res://assets/ui/liveops/mail/spirit_messages_jade_frame.png","23e508606567c1db87bd117cca69c98a3d3da68602753e987ae6dc9f048f2728"],["res://assets/ui/cultivation/cultivation_celestial_realm_bg.png","96aa00303dbb56d93ca9ad931d2d095ad90c5e564e9be8eb0312e8bb95aee730"]]:
  var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(FileAccess.get_file_as_bytes(pair[0]));check(context.finish().hex_encode()==pair[1],"canonical pixels retained")
 for path: String in ["res://scenes/ui/main_menu.tscn","res://scenes/ui/cultivation_menu.tscn","res://scenes/ui/mailbox_screen.tscn","res://scenes/ui/celestial_treasury_screen.tscn"]:
  paused=false;change_scene_to_file(path);await frames(20);check(current_scene!=null and current_scene.scene_file_path==path,"production scene "+path)
 check(root.get_node("MonetizationManager").ads_suspended(),"ad hold remains on")
 paused=false;await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 if current_scene!=null:current_scene.queue_free();current_scene=null
 await frames(8);print("REPOSITORY_CLEANUP_RESOURCE_QA checks=",checks," failures=",failures);quit(1 if failures else 0)
