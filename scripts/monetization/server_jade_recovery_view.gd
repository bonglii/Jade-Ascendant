extends RefCounted
## Volatile display only; no local grant, spend, merge or persistence.
const FRESH_MSEC: int=120000
var _owner: String=""
var _balance: int=-1
var _revision: int=-1
var _confirmed_at: int=-1
var _status: String="not_connected"
func bind_owner(owner: String) -> void:
 if owner==_owner:return
 _owner=owner;_balance=-1;_revision=-1;_confirmed_at=-1;_status="not_connected"
func accept(owner: String, view: Dictionary, now: int) -> bool:
 if owner.is_empty() or owner!=_owner or view.get("status") not in ["credited","ready"] or now<0:return false
 if not whole(view.get("balance"),0,9007199254740991) or not whole(view.get("revision"),0,9007199254740991):return false
 var revision: int=int(view.revision);var balance: int=int(view.balance)
 if revision<_revision or revision==_revision and _balance>=0 and balance!=_balance:return false
 _balance=balance;_revision=revision;_confirmed_at=now;_status="verified"
 return true
func unavailable() -> void:_status="unavailable"
func snapshot(now: int) -> Dictionary:
 var fresh: bool=_status=="verified" and now>=_confirmed_at and now-_confirmed_at<=FRESH_MSEC
 return {"status":("verified" if fresh else "stale") if _status=="verified" else _status,"balance":_balance,"revision":_revision,"confirmed":fresh,"can_spend":false,"can_grant":false}
static func whole(value: Variant, low: int, high: int) -> bool:
 if typeof(value)==TYPE_INT:return value>=low and value<=high
 if typeof(value)==TYPE_FLOAT:return is_finite(value) and floorf(value)==value and value>=float(low) and value<=float(high)
 return false
static func parse_repair(payload: String) -> Dictionary:
 if payload.is_empty() or payload.length()>2048:return {}
 var parser:=JSON.new()
 if parser.parse(payload)!=OK or not parser.data is Dictionary:return {}
 var data: Dictionary=parser.data
 if data.size()!=4 or data.get("state")!="server_reconciled" or not whole(data.get("repair_contract_version"),1,1):return {}
 if not whole(data.get("verified_purchases"),0,32) or not whole(data.get("new_wallet_credits"),0,32):return {}
 if data.new_wallet_credits>data.verified_purchases:return {}
 return {"status":"reconciled","verified_purchases":int(data.verified_purchases),"new_wallet_credits":int(data.new_wallet_credits)}
