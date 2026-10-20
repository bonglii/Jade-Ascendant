extends SceneTree
var checks: int=0
var failures: int=0
func check(value: bool,caption: String) -> void:
 checks+=1
 if not value:failures+=1;push_error("BOARD_ASSET "+caption)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_celestial_board_qa"):quit(2);return
 var frames: SpriteFrames=load("res://assets/ui/liveops/odyssey/pawn_v2/lin_yue_board.tres")
 for animation: StringName in frames.get_animation_names():
  for index: int in range(frames.get_frame_count(animation)):
   var texture: AtlasTexture=frames.get_frame_texture(animation,index)
   check(texture.filter_clip,"atlas filter clip "+str(animation))
   var image: Image=texture.get_image();var used: Rect2i=image.get_used_rect()
   check(image.get_size()==Vector2i(192,192),"independent 192px cell")
   check(used.position.x>=16 and used.position.y>=16 and used.end.x<=176 and used.end.y<=176,"transparent gutter never contains neighbor pixels "+str(animation)+str(index))
   check(used.end.y<=165,"stable feet baseline "+str(animation)+str(index))
 var source: String=FileAccess.get_file_as_string("res://addons/JadeReleaseMetadata/export_plugin.gd")
 var verifier: String=FileAccess.get_file_as_string("res://backend/player_identity/verify_odyssey_aab.ps1")
 check(source.contains('contains("const PRESENTATION_REVISION: int=4")') and source.contains('metadata["odyssey_presentation"] = 4'),"export metadata recognizes current presentation")
 check(verifier.contains('$meta.odyssey_presentation -ne 4') and verifier.contains('$meta.board_polish_revision -ne 1'),"AAB verifier rejects an old presentation build")
 check(source.contains('metadata["celestial_hub_revision"] = 1') and verifier.contains('$meta.celestial_hub_revision -ne 1'),"AAB verifier rejects a build missing the approved event hub")
 print("BOARD_POLISH_ASSET checks=%d failures=%d"%[checks,failures]);await load("res://tests/qa_runtime_teardown.gd").stop_audio(self);quit(1 if failures else 0)
