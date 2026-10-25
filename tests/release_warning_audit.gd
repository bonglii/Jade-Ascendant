extends SceneTree
const Book = preload("res://scripts/data/stage_record_book.gd")
const Progress = preload("res://scripts/data/odyssey_progress.gd")
var scanned: int = 0
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
 _scan("res://scripts")
 for row: Array in [[0,"00:00.0"],[999,"00:00.9"],[1000,"00:01.0"],[59999,"00:59.9"],[60000,"01:00.0"],[182345,"03:02.3"]]:
  checks += 1
  if Book.clock(int(row[0])) != str(row[1]): failures += 1
 for row: Array in [[1,0],[6,1],[24,4],[48,8],[72,12]]:
  checks += 2
  if Progress.threshold({},int(row[0])) != int(row[0]): failures += 1
  if Progress.threshold({"journey_laps_version":2},int(row[0])) != int(row[1]): failures += 1
 print("RELEASE_WARNING_AUDIT scripts=%d checks=%d failures=%d" % [scanned,checks,failures])
 quit(1 if failures else 0)
func _scan(folder: String) -> void:
 var dir := DirAccess.open(folder)
 for name: String in dir.get_directories(): _scan(folder + "/" + name)
 for name: String in dir.get_files():
  if name.ends_with(".gd"):
   scanned += 1
   var resource: Resource = ResourceLoader.load(folder + "/" + name,"GDScript",ResourceLoader.CACHE_MODE_IGNORE)
   if resource == null or not (resource as GDScript).can_instantiate(): failures += 1
