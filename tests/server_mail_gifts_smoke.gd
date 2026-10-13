extends SceneTree
const Catalog = preload("res://scripts/data/equipment_catalog.gd")
var checks: int = 0
var failures: int = 0
var mailer: Node
var ops: Node
var owner: String
class AuthStub extends Node:
 signal id_token_result(token: String)
 signal id_token_error(message: String)
 func is_signed_in() -> bool: return true
 func get_current_user_data() -> Dictionary: return {"uid":"mail-gifts-qa"}
 func get_id_token(_force: bool=false) -> void: pass
func check(ok: bool,tag: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(tag)
func claim(id: String,reward: Dictionary) -> void:
 mailer._queue.clear();mailer._pending={"kind":"claim","id":"server:"+id,"owner":owner,"refreshed_token":false};mailer._busy=true;mailer._waiting_token=false
 var body: Dictionary={"owner_binding":owner,"mail_id":id,"installation_id":mailer._state.installation_id,"receipt_id":id.sha256_text().substr(0,32),"delivery_state":"pending","reward":reward}
 mailer._on_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(body).to_utf8_buffer())
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_mail_gifts_qa"):push_error("Isolated gifts QA required");quit(2);return
 await create_timer(0.5).timeout
 mailer=root.get_node("ServerMailManager");ops=root.get_node("LiveOpsManager")
 var auth: Node=AuthStub.new();root.add_child(auth);root.get_node("PlayerIdentityServerClient")._auth=auth;mailer._auth_node=auth;mailer.set_process(false);owner="mail-gifts-qa".sha256_text();mailer._owner=owner
 var pavilion: Node=root.get_node("PavilionManager");var inventory: Node=root.get_node("InventoryManager");var progression: Node=root.get_node("ProgressionManager");var saver: Node=root.get_node("SaveManager")
 var expect_path: String="user://gifts_qa_expect.json"
 if "--restart" in OS.get_cmdline_user_args():
  var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expect_path))
  check(pavilion.get_celestial_jade()==int(expected.jade),"restart retains gift Jade")
  check(pavilion.get_pavilion_seals()==int(expected.seals),"restart retains summon seals")
  check(inventory.get_item_count("nine_heavens_star_sword")==1,"restart retains equipment")
  check(inventory.get_item_count("refinement_shard")==int(expected.shards),"restart retains duplicate conversion")
  claim("a".repeat(32),{"spirit_stone":0,"items":{},"celestial_jade":100})
  check(pavilion.get_celestial_jade()==int(expected.jade),"restart replay does not add Jade")
  check(not saver.has_pending_transaction(),"restart journal settled")
  print("MAIL_GIFTS_RESTART checks=",checks," failures=",failures);quit(1 if failures else 0);return
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://backend/player_identity/mail_reward_catalog.json"))
 check(manifest.equipment.size()==Catalog.ITEMS.size(),"backend/client catalog counts match")
 for item: Dictionary in manifest.equipment:
  check(Catalog.ITEMS.has(item.id) and Catalog.ITEMS[item.id].rarity==item.rarity and Catalog.ITEMS[item.id].display_name==item.name,"catalog identity "+str(item.id))
 var jade: int=pavilion.get_celestial_jade();var seals: int=pavilion.get_pavilion_seals();var stones: int=progression.spirit_stone
 claim("a".repeat(32),{"spirit_stone":0,"items":{},"celestial_jade":100})
 check(pavilion.get_celestial_jade()==jade+100,"Jade-only gift commits")
 check(mailer._has_local_receipt("a".repeat(32)),"Jade receipt commits with currency")
 check(mailer._queue.size()==1 and mailer._queue[0].kind=="ack","ACK follows durable Jade grant")
 claim("b".repeat(32),{"spirit_stone":250,"celestial_jade":50,"pavilion_seal":3,"items":{"nine_heavens_star_sword":1,"refinement_shard":2}})
 check(pavilion.get_celestial_jade()==jade+150,"mixed Jade exact amount")
 check(pavilion.get_pavilion_seals()==seals+3,"real summon seal counter incremented")
 check(progression.spirit_stone==stones+250,"mixed Stone exact amount")
 check(inventory.get_item_count("nine_heavens_star_sword")==1,"equipment reaches permanent ownership")
 var result: Dictionary=root.get_node("RewardManager").get_last_grant_result()
 check(result.applied_reward_data.get("celestial_jade")==50 and result.applied_reward_data.get("pavilion_seal")==3,"claim popup reports actual bonus currencies")
 var shards: int=inventory.get_item_count("refinement_shard")
 claim("c".repeat(32),{"spirit_stone":0,"items":{"nine_heavens_star_sword":1}})
 check(inventory.get_item_count("nine_heavens_star_sword")==2,"duplicate equipment retained as identical copy")
 check(inventory.get_item_count("refinement_shard")==shards,"duplicate does not convert to generic shards")
 claim("b".repeat(32),{"spirit_stone":250,"celestial_jade":50,"pavilion_seal":3,"items":{"nine_heavens_star_sword":1,"refinement_shard":2}})
 check(pavilion.get_celestial_jade()==jade+150 and pavilion.get_pavilion_seals()==seals+3,"replayed receipt adds no currency")
 check(inventory.get_item_count("refinement_shard")==shards and inventory.get_item_count("nine_heavens_star_sword")==2,"replayed receipt adds neither shards nor copies")
 for bad: Dictionary in [{"spirit_stone":0,"items":{},"celestial_jade":true},{"spirit_stone":0,"items":{},"pavilion_seal":101},{"spirit_stone":0,"items":{"unknown_equipment":1}},{"spirit_stone":0,"items":{"nine_heavens_star_sword":2}}]:check(not mailer._valid_reward(bad),"invalid extra gift denied")
 saver.begin_save_write_barrier("gifts_qa","atomic save failure")
 claim("d".repeat(32),{"spirit_stone":0,"items":{},"pavilion_seal":5})
 check(pavilion.get_pavilion_seals()==seals+3,"save failure grants no seals")
 check(not mailer._has_local_receipt("d".repeat(32)),"save failure leaves no claim marker")
 check(mailer._queue.is_empty(),"save failure sends no ACK")
 saver.end_save_write_barrier("gifts_qa")
 var expected: Dictionary={"jade":pavilion.get_celestial_jade(),"seals":pavilion.get_pavilion_seals(),"shards":inventory.get_item_count("refinement_shard")}
 var file:=FileAccess.open(expect_path,FileAccess.WRITE);file.store_string(JSON.stringify(expected));file.close()
 print("MAIL_GIFTS_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
