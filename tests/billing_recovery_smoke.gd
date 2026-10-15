extends SceneTree

# Real provider, fake Play boundary. No checkout, network, token persistence or grants.
class FakePlay extends Node:
 var available: bool = true
 var catalogs: int = 0
 var restores: int = 0
 var checkouts: int = 0
 var starts: int = 0
 var finalized: int = 0
 func is_ready() -> bool: return available
 func start_connection() -> void: starts += 1
 func end_connection() -> void: pass
 func query_product_details(_ids: PackedStringArray, _kind: int) -> void: catalogs += 1
 func query_purchases(_kind: int) -> void: restores += 1
 func set_obfuscated_account_id(_value: String) -> void: pass
 func purchase(_id: String, _option: String, _offer: String, _personalized: bool) -> Dictionary:
  checkouts += 1
  return {"response_code":0}
 func consume_purchase(_token: String) -> void: finalized += 1
 func acknowledge_purchase(_token: String) -> void: finalized += 1

var checks: int = 0
var failures: int = 0
var ready_events: int = 0
var ownership_events: int = 0
var states: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures += 1; push_error("BILLING_RECOVERY_FAIL " + message)
func detail() -> Dictionary:
 return {"product_id":"jade_pouch_100","one_time_purchase_offer_details_list":[{"formatted_price":"Rp 1.000","price_amount_micros":1000000000,"price_currency_code":"IDR"}]}
func receipt(state: int = 1) -> Dictionary:
 return {"purchase_state":state,"product_ids":["jade_pouch_100"],"purchase_token":"fixture-only-safe-token-123456","order_id":"fixture"}
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_billing_recovery_qa"): quit(2); return
 await create_timer(.4).timeout
 var pavilion: Node = root.get_node("PavilionManager")
 var before: Dictionary = pavilion.state.duplicate(true)
 var provider: Node = load("res://scripts/monetization/google_play_billing_provider.gd").new()
 root.add_child(provider)
 var play := FakePlay.new(); provider.add_child(play); provider.billing_client = play
 provider.purchase_ready.connect(func(_p: String, _t: String, _o: String): ready_events += 1)
 provider.entitlements_received.connect(func(_ids: Array[String]): ownership_events += 1)
 provider.purchase_state_changed.connect(func(_p: String, status: String, _msg: String): states.append(status))
 await process_frame
 check(not provider.purchase("jade_pouch_100") and play.checkouts==0, "locked context cannot check out")
 provider.refresh_products(); provider.refresh_products()
 check(play.catalogs==1 and provider._catalog_pending, "overlapping catalog requests coalesce")
 provider._on_catalog_timeout(provider._catalog_nonce-1)
 check(provider._catalog_pending, "old catalog timeout ignored")
 provider._on_product_details({"response_code":0,"product_details":[detail()]})
 check(provider.store_products.size()==1 and provider.store_products.jade_pouch_100.formatted_price=="Rp 1.000", "real price parser retained")
 check(not provider._retry_scheduled, "successful query cancels stale retry")
 play.available=false; provider._on_disconnected(); var retry: int=provider._retry_nonce
 provider._on_disconnected()
 check(provider._retry_nonce==retry and provider._retry_attempt==1, "disconnect burst schedules one retry")
 provider._retry_catalog(retry-1)
 check(play.catalogs==1, "old retry ignored")
 provider._retry_catalog(retry)
 check(play.catalogs==2 and play.starts==0, "read query invokes native auto-reconnect without second connection")
 for i: int in range(8):
  provider._on_product_details({"response_code":12})
  provider._retry_catalog(provider._retry_nonce)
 check(provider._retry_attempt==5 and not provider._retry_scheduled, "automatic retry is finite")
 provider.refresh_products()
 check(provider._retry_attempt==0 and provider._catalog_pending, "explicit retry opens fresh cycle")
 provider._on_product_details({"response_code":5})
 check(not provider._retry_scheduled, "developer configuration errors do not retry forever")
 play.available=true
 var a: String="account-a".sha256_text(); var b: String="account-b".sha256_text()
 provider.configure_secure_purchase_context(a,true)
 await process_frame
 check(play.restores==1 and provider.restore_in_progress, "ready owner restores once")
 for i: int in range(20): provider.configure_secure_purchase_context(a,true); provider.restore_purchases()
 check(play.restores==1, "status polls and restore spam do not multiply native queries")
 provider.configure_secure_purchase_context(b,true)
 await process_frame
 check(play.restores==1, "new owner waits for old query to drain")
 var owned_count: int=ownership_events
 provider._on_query_purchases({"response_code":0,"purchases":[receipt()]})
 check(ready_events==0 and ownership_events==owned_count, "old owner's results never forwarded")
 await process_frame
 check(play.restores==2 and provider._restore_binding==b, "new owner queried after old completion")
 provider._on_restore_timeout(provider._restore_nonce)
 check(provider._restore_draining and not provider.restore_in_progress, "timeout visible while uncorrelated native callback drains")
 provider.configure_secure_purchase_context(a,true); provider.restore_purchases()
 await process_frame
 check(play.restores==2, "timeout does not rebind outstanding old-owner callback")
 provider._on_query_purchases({"response_code":0,"purchases":[receipt()]})
 check(ready_events==0, "timed-out native result discarded")
 await process_frame
 check(play.restores==3 and provider._restore_binding==a, "current owner restored after drain")
 provider._on_query_purchases({"response_code":2})
 check(ownership_events==owned_count+1 and "recovery_unavailable" in states, "query failure is not an empty ownership success")
 provider.restore_purchases()
 provider._on_query_purchases({"response_code":0,"purchases":[receipt(2)]})
 check(ready_events==0 and "pending" in states, "pending purchase never reaches verification/grant")
 provider.restore_purchases()
 provider._on_query_purchases({"response_code":0,"purchases":[receipt()]})
 check(ready_events==1, "purchased receipt only forwarded for server verification")
 check(provider.purchase("jade_pouch_100"), "configured purchase opens fake Play once")
 check(not provider.purchase("jade_pouch_100") and play.checkouts==1, "checkout double tap blocked")
 provider.configure_secure_purchase_context(b,true)
 provider._on_purchase_updated({"response_code":0,"purchases":[receipt()]})
 check(ready_events==1 and "account_changed" in states, "checkout owner change cannot forward late result")
 provider._on_purchase_updated({"response_code":1})
 check(ready_events==1, "cancel never verifies/grants")
 provider.configure_secure_purchase_context(a,true)
 await process_frame
 var switched: Array[bool]=[false]
 provider.purchase_ready.connect(func(_p: String,_t: String,_o: String):
  if not switched[0]:
   switched[0]=true
   provider.configure_secure_purchase_context(b,true))
 var events_before: int=ready_events
 provider._on_query_purchases({"response_code":0,"purchases":[receipt(),receipt()]})
 check(ready_events==events_before+1,"reentrant owner change stops forwarding remaining receipts")
 provider.configure_secure_purchase_context(a,true)
 var on_state: Callable=func(_p: String,status: String,_msg: String):
  if status=="verification_required":provider.configure_secure_purchase_context(b,true)
 provider.purchase_state_changed.connect(on_state)
 events_before=ready_events
 provider._process_purchase(receipt())
 check(ready_events==events_before,"status listener owner change cannot forward receipt under a new account")
 provider.purchase_state_changed.disconnect(on_state)
 var locked_before: int=ready_events
 provider.configure_secure_purchase_context("",false)
 provider._process_purchase(receipt())
 check(ready_events==locked_before, "locked callback never forwards receipt")
 check(not provider.get_runtime_status().ready, "runtime reports locked identity")
 var snap: String=JSON.stringify(provider.get_runtime_status())
 check(not snap.contains(a) and not snap.contains(b) and not snap.contains("fixture-only"), "runtime diagnostics exclude bindings and tokens")
 check(play.finalized==0, "client never consumes/acknowledges purchases")
 var settings: Node=load("res://scripts/ui/settings_screen.gd").new()
 var account: Node=root.get_node("GoogleAccountManager")
 var original_name: String=account._display_name
 account._display_name="private-email@example.invalid"
 var summary: String=settings.get_support_summary()
 account._display_name=original_name
 check(summary.contains("Billing state=") and summary.contains("Google elapsed ms=") and summary.contains("Profile retry seconds="), "Settings exposes actual sanitized integration stages")
 check(not summary.contains("private-email") and not summary.contains("fixture-only"), "support summary never exports account name or tokens")
 settings.free()
 check(pavilion.state==before, "all recovery tests preserve real balances/save state")
 provider._retry_nonce+=1; provider.queue_free()
 await process_frame
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("BILLING_RECOVERY checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
