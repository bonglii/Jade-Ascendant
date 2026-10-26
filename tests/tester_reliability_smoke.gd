extends SceneTree
var checks: int=0
var failures: int=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize() -> void:run.call_deferred()
func settle() -> void:
 for i: int in range(8):await process_frame
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_tester_reliability_qa"):quit(2);return
 await create_timer(.5).timeout
 var pavilion: Node=root.get_node("PavilionManager")
 var journey: Node=root.get_node("JourneyManager")
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
 pavilion.state.starter_seals_claimed=true
 pavilion.state.pavilion_seals=5;pavilion.state.celestial_jade=1000
 var before: Dictionary=pavilion.state.duplicate(true)
 var payment: Dictionary=pavilion.preview_summon_payment(10)
 check(payment.get("pavilion_seal")==5 and payment.get("celestial_jade")==450,"ten pulls spend owned seals before discounted remaining Jade")
 check(pavilion.state==before,"payment preview is read-only")
 var result: Dictionary=pavilion.summon_equipment(10)
 check(bool(result.get("success",false)),"mixed summon commits")
 check(result.get("payment_method")=="mixed" and result.get("payment_seals")==5 and result.get("payment_jade")==450,"receipt discloses both currencies")
 check(pavilion.get_pavilion_seals()==0 and pavilion.get_local_celestial_jade()==550,"one atomic summon deducts exact mixed payment")
 pavilion.state.pavilion_seals=1
 result=pavilion.summon_equipment(1)
 check(bool(result.get("success",false)) and pavilion.get_pavilion_seals()==0 and pavilion.get_local_celestial_jade()==550,"single summon always prefers one owned seal")
 pavilion.state.pavilion_seals=2;pavilion.state.celestial_jade=100
 before=pavilion.state.duplicate(true)
 result=pavilion.summon_equipment(10)
 check(not bool(result.get("success",false)) and pavilion.state==before,"insufficient mixed funds cannot partially debit")
 var provider: Node=load("res://scripts/monetization/google_play_billing_provider.gd").new()
 check(provider._to_internal_product_id("jade_topup_50_v2")=="jade_pouch_100","versioned Play aliases preserve native journal IDs")
 check(provider._supported_ids().has("jade_pouch_100") and provider._supported_ids().has("jade_topup_50_v2"),"catalog can recover old purchases while querying new products")
 var offer: Dictionary={"formatted_price":"Rp18.000","price_currency_code":"IDR","price_amount_micros":18000000000}
 var old: Dictionary={"product_id":"jade_pouch_100","one_time_purchase_offer_details_list":[offer]}
 var updated: Dictionary={"product_id":"jade_topup_50_v2","one_time_purchase_offer_details_list":[offer]}
 for details: Array in [[old,updated],[updated,old]]:
  provider._on_product_details({"response_code":0,"product_details":details})
  check(provider.store_products.jade_pouch_100.play_product_id=="jade_topup_50_v2","Play response ordering cannot select an obsolete pack")
 provider._on_product_details({"response_code":0,"product_details":[old]})
 check(provider.store_products.jade_pouch_100.play_product_id=="jade_pouch_100","unconfigured new SKU retains a working legacy checkout")
 provider.free()
 pavilion.billing_store_products={"jade_pouch_100":{"play_product_id":"jade_topup_50_v2"}}
 check(pavilion.get_iap_product_data("jade_pouch_100").celestial_jade==50,"new Play SKU advertises base50")
 pavilion.billing_store_products={"jade_pouch_100":{"play_product_id":"jade_pouch_100"}}
 check(pavilion.get_iap_product_data("jade_pouch_100").celestial_jade==100,"legacy Play SKU retains promised100")
 pavilion.billing_store_products={}
 var polish: Script=load("res://scripts/effects/skill_instance_polish.gd")
 var projectile:=Node2D.new();root.add_child(projectile)
 polish.install(projectile,"yin_yang_blades");polish.install(projectile,"heavenly_sword_rain")
 check(projectile.get_child_count()==0,"authored skill cels do not allocate redundant per-projectile FX processors")
 projectile.queue_free()
 var conf:=ConfigFile.new();conf.set_value("tutorials","pavilion",true);conf.save("user://jade_onboarding.cfg")
 for dims: Vector2i in [Vector2i(320,568),Vector2i(390,844),Vector2i(648,1152)]:
  var vp:=SubViewport.new();vp.size=dims;root.add_child(vp)
  var library: Control=load("res://scenes/ui/skill_book_screen.tscn").instantiate();vp.add_child(library);await settle()
  library._open_skill_detail("eight_trigrams_formation");await settle()
  check(library._detail_panel.get_global_rect().end.x<=dims.x+1,"library detail fits narrow width "+str(dims))
  check(library._detail_panel.size.y<dims.y*.64,"short skill detail removes dead space "+str(dims))
  library._open_equipment_detail("heavenweaver_compass");await settle()
  check(library._detail_panel.size.y<=dims.y*.75+1,"long equipment detail bounded by viewport "+str(dims))
  check(library._detail_scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,"long content keeps native scrolling "+str(dims))
  library._close_popup();vp.queue_free();await settle()
 var paid_fx: Script=load("res://scripts/player/lin_yue_combat_presentation.gd")
 var fx: Node2D=paid_fx.new()
 fx._effects.append({"left":0.0})
 var effect_before: int=fx._effects.size()
 fx._on_weapon_attack_triggered("Heavenweaver Compass",Vector2(100,0))
 check(fx._effects.size()==effect_before and fx._effects[0].left==0.0 and fx._effect_cursor==0,"Compass cannot create generic player-origin blue cast pulses")
 fx.free()
 print("TESTER_RELIABILITY checks=%d failures=%d"%[checks,failures])
 await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 quit(1 if failures else 0)
