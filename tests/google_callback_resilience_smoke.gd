extends SceneTree
class FakeAuth extends Node:
 var signed: bool=true
 var data: Dictionary={"uid":"current-account","isAnonymous":false,"name":"QA"}
 func is_signed_in() -> bool:return signed
 func get_current_user_data() -> Dictionary:return data
var checks: int=0
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("GOOGLE_CALLBACK_FAIL "+message)
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_google_callback_qa"):quit(2);return
 await create_timer(.5).timeout
 var manager: Node=load("res://scripts/managers/google_account_manager.gd").new();root.add_child(manager)
 await process_frame;await process_frame
 var auth:=FakeAuth.new();root.add_child(auth)
 manager._auth=auth;manager._native_ready=true;manager._busy=true;manager._operation="sign_in"
 var inv: Dictionary=root.get_node("InventoryManager").item_counts.duplicate(true)
 check(not manager._callback_matches_native_user({"uid":"old-account"}),"old account mismatch")
 check(manager._callback_matches_native_user(auth.data),"current account correlation")
 manager._on_auth_success({"uid":"old-account","isAnonymous":false})
 check(manager._busy and manager._account_uid.is_empty(),"old sign-in callback cannot finish current operation")
 manager._on_auth_success(auth.data)
 check(not manager._busy and manager._account_uid=="current-account","current callback finishes sign-in")
 manager._busy=true;manager._operation="link_google";manager._link_source_uid="current-account"
 manager._on_link_with_google_success({"uid":"old-account"})
 check(manager._busy,"late link callback ignored")
 manager._on_link_with_google_success(auth.data)
 check(not manager._busy and manager._account_uid=="current-account","same-account link accepted")
 manager._busy=true;manager._operation="sign_in";manager._operation_nonce=10
 manager._on_operation_timeout(9,"sign_in")
 check(manager._busy,"old timeout ignored")
 manager._on_operation_timeout(10,"sign_in")
 check(not manager._busy and manager._signed_in,"timeout reconciles completed native sign-in")
 auth.signed=false;manager._busy=true;manager._operation="sign_in";manager._operation_nonce=20
 manager._on_operation_timeout(20,"sign_in")
 check(not manager._busy and manager._status.contains("did not respond"),"true native timeout remains visible")
 auth.signed=true;manager._busy=true;manager._operation="sign_out";manager._operation_nonce=30
 manager._signed_in=true
 manager._on_operation_timeout(30,"sign_out")
 check(not manager._busy and manager._signed_in and manager._status.contains("did not complete"),"logout timeout does not report sign-in as logout success")
 manager._busy=true;manager._operation="sign_out";manager._operation_nonce=31
 manager._on_auth_failure("late sign-in error")
 check(manager._busy and manager._operation=="sign_out","unrelated auth failure cannot cancel logout")
 manager._on_sign_out_success(true)
 check(manager._busy and manager._operation=="sign_out","stale logout callback cannot erase active native session")
 manager._on_auth_state_changed(false,{})
 check(manager._busy,"stale signed-out event ignored while native still signed in")
 auth.signed=false
 manager._on_operation_timeout(31,"sign_out")
 check(not manager._busy and not manager._signed_in,"logout timeout reconciles actual signed-out state")
 auth.signed=true;auth.data={"uid":"other-account","isAnonymous":false}
 manager._busy=true;manager._operation="link_google";manager._link_source_uid="original-anonymous";manager._operation_nonce=40
 manager._on_operation_timeout(40,"link_google")
 check(not manager._signed_in and manager._account_uid.is_empty(),"link timeout cannot accept a different owner's Google session")
 check(not manager._timeout_user_matches_operation("link_google",{"uid":"original-anonymous","isAnonymous":true}),"unfinished anonymous link rejected")
 manager._link_source_uid="original-anonymous"
 check(manager._timeout_user_matches_operation("link_google",{"uid":"original-anonymous","isAnonymous":false}),"completed same-owner link can reconcile")
 manager._busy=true;manager._operation="sign_in";manager._operation_nonce=50
 manager._reconcile_after_resume(49)
 check(manager._busy,"stale application-resume callback ignored")
 manager._reconcile_after_resume(50)
 check(not manager._busy and manager._account_uid=="other-account","completed native login reconciles on resume without waiting 35 seconds")
 manager._busy=true;manager._operation="sign_out";manager._operation_nonce=60
 manager._reconcile_after_resume(60)
 check(manager._busy,"resume does not prematurely complete pending logout")
 manager._busy=false;manager._operation=""
 check(root.get_node("InventoryManager").item_counts==inv,"account UI never merges/mutates inventory")
 manager.queue_free();auth.queue_free();root.get_node("AudioManager").release_runtime_audio()
 print("GOOGLE_CALLBACK_RESILIENCE checks=",checks," failures=",failures)
 quit(0 if failures==0 else 1)
