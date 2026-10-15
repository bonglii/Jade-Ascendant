extends RefCounted
## Fixed HTTPS resolvers; token inspection is callback correlation, never verification.
const PROVIDERS: Array[Dictionary]=[
 {"ip":"1.1.1.1","host":"cloudflare-dns.com","path":"/dns-query"},
 {"ip":"8.8.8.8","host":"dns.google","path":"/resolve"}]
static func public_ipv4(value: String) -> bool:
 var parts: PackedStringArray=value.split(".")
 if parts.size()!=4:return false
 var n: Array[int]=[]
 for part: String in parts:
  if not part.is_valid_int() or str(int(part))!=part or int(part)<0 or int(part)>255:return false
  n.append(int(part))
 if n[0] in [0,10,127] or n[0]>=224:return false
 if n[0]==100 and n[1]>=64 and n[1]<=127:return false
 if n[0]==169 and n[1]==254 or n[0]==172 and n[1]>=16 and n[1]<=31:return false
 if n[0]==192 and (n[1]==168 or n[1]==0 and n[2] in [0,2]):return false
 if n[0]==198 and (n[1] in [18,19] or n[1]==51 and n[2]==100):return false
 if n[0]==203 and n[1]==0 and n[2]==113:return false
 return true
static func _json(bytes: PackedByteArray, limit: int) -> Variant:
 if bytes.is_empty() or bytes.size()>limit or not valid_utf8(bytes):return null
 var parser:=JSON.new()
 return parser.data if parser.parse(bytes.get_string_from_utf8())==OK else null
static func valid_utf8(bytes: PackedByteArray) -> bool:
 var i: int=0
 while i<bytes.size():
  var first: int=bytes[i];var count: int=0;var value: int=0;var floor_value: int=0
  if first<128:i+=1;continue
  if first>=194 and first<=223:count=1;value=first&31;floor_value=128
  elif first>=224 and first<=239:count=2;value=first&15;floor_value=2048
  elif first>=240 and first<=244:count=3;value=first&7;floor_value=65536
  else:return false
  if i+count>=bytes.size():return false
  for j: int in range(1,count+1):
   var next: int=bytes[i+j]
   if next<128 or next>191:return false
   value=(value<<6)|(next&63)
  if value<floor_value or value>1114111 or value>=55296 and value<=57343:return false
  i+=count+1
 return true
static func decode(bytes: PackedByteArray, hostname: String) -> Dictionary:
 var data: Variant=_json(bytes,8192)
 if not data is Dictionary:return {}
 if typeof(data.get("Status")) not in [TYPE_INT,TYPE_FLOAT] or data.get("Status")!=0:return {}
 if not data.get("TC",false) is bool or data.get("TC",false):return {}
 var questions: Variant=data.get("Question")
 if not questions is Array or questions.size()!=1 or not questions[0] is Dictionary:return {}
 if str(questions[0].get("name","")).trim_suffix(".").to_lower()!=hostname.to_lower() or questions[0].get("type")!=1:return {}
 var answers: Variant=data.get("Answer",[])
 if not answers is Array or answers.size()>32:return {}
 var names: Array[String]=[hostname.to_lower()];var ttl: int=300
 for step: int in range(8):
  for answer: Variant in answers:
   if not answer is Dictionary:continue
   if answer.get("type")==5 and str(answer.get("name","")).trim_suffix(".").to_lower() in names:
    var alias: String=str(answer.get("data","")).trim_suffix(".").to_lower()
    if not alias.is_empty() and not names.has(alias):names.append(alias)
    ttl=mini(ttl,_ttl(answer.get("TTL",0)))
 var addresses:=PackedStringArray()
 for answer: Variant in answers:
  if not answer is Dictionary:continue
  var address: String=str(answer.get("data",""))
  if answer.get("type")==1 and str(answer.get("name","")).trim_suffix(".").to_lower() in names and public_ipv4(address):
   if addresses.size()<4 and not addresses.has(address):addresses.append(address)
   ttl=mini(ttl,_ttl(answer.get("TTL",0)))
 return {"addresses":addresses,"ttl":ttl} if not addresses.is_empty() else {}
static func _ttl(value: Variant) -> int:
 if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)!=floorf(float(value)):return 0
 return clampi(int(value),0,300)
static func token_owner_matches(token: String, owner: String) -> bool:
 if token.length()>8192 or owner.is_empty():return false
 var parts: PackedStringArray=token.split(".")
 if parts.size()!=3:return false
 var pattern:=RegEx.new();pattern.compile("^[A-Za-z0-9_-]+$")
 for part: String in parts:
  if pattern.search(part)==null or part.length()%4==1:return false
 var values: Array=[]
 for part: String in [parts[0],parts[1]]:
  var standard: String=part.replace("-","+").replace("_","/")
  values.append(_json(Marshalls.base64_to_raw(standard+"=".repeat((4-standard.length()%4)%4)),8192))
 if not values[0] is Dictionary or not values[1] is Dictionary:return false
 var claims: Dictionary=values[1]
 if not claims.get("sub") is String:return false
 var uid: String=claims.sub
 return values[0].get("alg")=="RS256" and claims.get("iss")=="https://securetoken.google.com/jade-ascendant" and claims.get("aud")=="jade-ascendant" and not uid.is_empty() and uid.length()<=128 and uid.sha256_text()==owner
