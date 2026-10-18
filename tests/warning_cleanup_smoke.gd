extends SceneTree
func _initialize() -> void:
 _run.call_deferred()
func walk(dir: String) -> Array[String]:
 var out: Array[String]=[]
 for file: String in DirAccess.get_files_at(dir):
  if file.ends_with('.gd'):out.append(dir+'/'+file)
 for sub: String in DirAccess.get_directories_at(dir):out.append_array(walk(dir+'/'+sub))
 return out
func _run() -> void:
 if not OS.get_user_data_dir().contains('jade_warning_cleanup_qa'):
  quit(2)
  return
 var checked: int=0
 var failed: int=0
 for source: String in walk('res://scripts'):
  var script: GDScript=load(source)
  checked+=1
  if script==null or not script.can_instantiate():failed+=1;push_error('WARNING_SCAN '+source)
 print('WARNING_SCAN scripts=',checked,' failed=',failed)
 await process_frame
 quit(0 if failed==0 else 1)
