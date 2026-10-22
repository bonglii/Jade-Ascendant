extends RefCounted
## Local display hints only. Never an ownership, login, grant or save authority.
const PATH: String = "user://jade_account_hints_v1.json"
const LIMIT: int = 16
static func mask_email(value: Variant) -> String:
 if not value is String or value.length()>254: return ""
 var parts: PackedStringArray=value.strip_edges().split("@")
 if parts.size()!=2 or parts[0].length()<2: return ""
 var pattern:=RegEx.new();pattern.compile("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,24}$")
 if pattern.search(value.strip_edges())==null: return ""
 return "••••"+parts[0].right(mini(4,parts[0].length()-1))+"@"+parts[1].to_lower()
static func _hex(value: String) -> bool:
 return value.length()==64 and value.is_valid_hex_number(false) and value==value.to_lower()
static func _read() -> Dictionary:
 if not FileAccess.file_exists(PATH): return {}
 var file:=FileAccess.open(PATH,FileAccess.READ)
 if file==null or file.get_length()>8192: return {}
 var parser:=JSON.new()
 if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary or parser.data.size()>LIMIT: return {}
 var result: Dictionary={}
 var pattern:=RegEx.new();pattern.compile("^••••[A-Za-z0-9._%+-]{1,4}@[A-Za-z0-9.-]+\\.[A-Za-z]{2,24}$")
 for raw: Variant in parser.data:
  if not raw is String or not _hex(raw): return {}
  var record: Variant=parser.data[raw]
  if not record is Dictionary or not record.get("hint") is String or record.hint.length()>254 or pattern.search(record.hint)==null or not typeof(record.get("seen")) in [TYPE_INT,TYPE_FLOAT]: return {}
  result[raw]=record
 return result
static func lookup(binding: String) -> String:
 return str(_read().get(binding,{}).get("hint","")) if _hex(binding) else ""
static func remember(binding: String,email: Variant) -> void:
 var hint: String=mask_email(email)
 if not _hex(binding) or hint.is_empty(): return
 var records: Dictionary=_read()
 if records.get(binding,{}).get("hint")==hint: return
 if records.size()>=LIMIT and not records.has(binding):
  var oldest: String="";var stamp: int=9223372036854775807
  for raw: String in records:
   if int(records[raw].seen)<stamp: oldest=raw;stamp=int(records[raw].seen)
  records.erase(oldest)
 records[binding]={"hint":hint,"seen":int(Time.get_unix_time_from_system())}
 var file:=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
 if file==null:return
 file.store_string(JSON.stringify(records));file.flush();var error: Error=file.get_error();file.close()
 if error==OK:DirAccess.rename_absolute(PATH+".tmp",PATH)
