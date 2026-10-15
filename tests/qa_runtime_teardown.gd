extends RefCounted
## Stop scene-driven restart before draining Dummy/real audio playback on QA exit.
static func stop_audio(tree: SceneTree) -> void:
 var audio: Node=tree.root.get_node_or_null("AudioManager")
 if audio!=null:
  audio.set_process(false)
  audio.call("release_runtime_audio")
 await tree.create_timer(0.1,true).timeout
