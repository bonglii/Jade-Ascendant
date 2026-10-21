extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error("ECONOMY_PROGRESS_FAIL " + label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
 if not OS.get_user_data_dir().contains("jade_economy_qa"): quit(2); return
 await process_frame
 # Bulk economy assertions do not exercise audio playback. Keep Dummy SFX queues empty.
 root.get_node("AudioManager").backgrounded=true;root.get_node("AudioManager").set_process(false)
 var eq: Node = root.get_node("EquipmentManager")
 var idle: Node = root.get_node("IdleCultivationManager")
 var journey: Node = root.get_node("JourneyManager")
 var inv: Node = root.get_node("InventoryManager")
 var progress: Node = root.get_node("ProgressionManager")
 var saver: Node = root.get_node("SaveManager")
 if "--resume" in OS.get_cmdline_user_args():
  check(eq.get_item_weapon_level("nine_heavens_star_sword") == 11, "restart new level")
  check(progress.spirit_stone == 0, "restart committed wallet")
  check(idle.state.lifetime_claim_seconds == 15900 and idle.state.shard_progress_units == 5, "restart idle lifetime and shard carry")
  check(idle.state.processed_rewarded_grant_ids == ["old_grant"], "restart consumed ad IDs preserved")
  await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
  print("ECONOMY_PROGRESS_RESTART checks=",checks," failures=",failures)
  quit(1 if failures else 0)
  return
 eq.active_run_loadout_snapshot.clear()
 for id: String in eq.get_item_ids_for_slot("armament"):
  eq.ascension_stars[id] = 5
  var total: int = 0
  for level: int in range(1,50):
   eq.weapon_levels[id] = level
   var cost: int = eq.get_weapon_level_cost(id)
   check(cost == 10*(level+3), "cost curve " + id + " " + str(level))
   total += cost
  check(total == 13720, "full cost " + id)
  eq.weapon_levels[id] = 50
  check(eq.get_weapon_level_cost(id) == 0 and not eq.can_level_weapon(id), "cap " + id)
 check(eq.get_weapon_level_cost("invalid_item") == 0, "invalid weapon no cost")
 journey.cleared_stage_keys = ["invalid", "1-99", "99-1"]
 check(idle.get_progress_tier() == 0 and not idle.is_unlocked(), "invalid keys cannot unlock")
 journey.cleared_stage_keys = ["1-1", "1-1", "invalid"]
 check(idle.get_progress_tier() == 1, "duplicates counted once")
 journey.cleared_stage_keys.clear()
 var count: int = 0
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):
   if not journey.is_stage_implemented(chapter,stage): continue
   journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
   count += 1
   check(idle.get_progress_tier() == count, "authored tier " + str(count))
   var rates: Dictionary = idle.get_rates_for_tier(count)
   check(rates.spirit_stone_per_hour == 48+(count-1)*6, "stone growth " + str(count))
   var hour: Dictionary = idle.preview_reward_for_seconds(3600,count)
   check(hour.reward_data.spirit_stone == rates.spirit_stone_per_hour + (floori(6.0/int(rates.shard_interval_units))*inv.LEGACY_FRAGMENT_STONES if int(rates.shard_interval_units)>0 else 0), "hour payout " + str(count))
 check(count == 26 and idle.MAX_PROGRESS_TIER == count, "content cap covers all stages")
 check(idle.get_rates_for_tier(16).spirit_stone_per_hour == 138, "tier16 preserved")
 check(idle.get_rates_for_tier(999).spirit_stone_per_hour == 198, "upper clamp")
 check(idle.get_tier_title(21) == "FROSTVEIL RESONANCE", "realm4 title")
 check(idle.get_tier_title(26) == "SOLAR NIRVANA MEDITATION", "realm5 title")
 var twelve: Dictionary = idle.preview_reward_for_seconds(86400,26,5)
 check(twelve.claim_seconds == 43200 and twelve.reward_data.spirit_stone == 2616, "12h cap")
 check(twelve.reward_data.hero_exp == 720 and twelve.reward_data.items.is_empty(), "EXP growth and retired fragments paid as stones")
 check(twelve.next_shard_progress_units == 5, "shard remainder preserved")
 var partial: Dictionary = idle.preview_reward_for_seconds(599,26,5)
 check(partial.claim_units == 0 and partial.reward_data.spirit_stone == 0 and partial.next_shard_progress_units == 5, "partial unit retained")
 var doubled: Dictionary = idle.preview_rewarded_double_for_seconds(43200,26,5)
 check(doubled.reward_data.spirit_stone == 5232 and doubled.reward_data.items.is_empty() and doubled.next_shard_progress_units == 5, "ad double without changing progress")
 var now: int = idle._system_now()
 var old: Dictionary = {"version":1,"last_claim_unix":now-3600,"last_observed_unix":now,"lifetime_claim_seconds":12300,"shard_progress_units":5,"processed_rewarded_grant_ids":["old_grant"]}
 idle.state = idle._normalize_state(old,now)
 check(idle.state == old, "v1 timestamp counters and consumed IDs preserved")
 # A rewarded claim must retain its prepared tier despite later progression.
 journey.cleared_stage_keys = ["1-1"]
 check(idle.prepare_rewarded_double_claim(), "prepare tier1 ad snapshot")
 var frozen_reward: Dictionary = idle._pending_rewarded_claim.reward_data.duplicate(true)
 for chapter: int in journey.get_chapter_ids():
  for stage: int in journey.get_stage_ids(chapter):
   journey.cleared_stage_keys.append(journey.get_stage_key(chapter,stage))
 check(idle.get_progress_tier() == 26 and idle._pending_rewarded_claim.reward_data == frozen_reward and frozen_reward.spirit_stone == 96, "pending ad retains prepared tier and reward")
 idle.cancel_pending_rewarded_double_claim()
 var before: Dictionary = idle.state.duplicate(true)
 var stones: int = progress.spirit_stone
 saver.begin_save_write_barrier("economy_qa", "claim fixture")
 check(not idle.claim_idle_reward().get("success",false), "claim blocked by recovery")
 check(idle.state == before and progress.spirit_stone == stones, "failed claim no mutations")
 saver.end_save_write_barrier("economy_qa")
 check(idle.claim_idle_reward().get("success",false), "tier26 actual atomic claim")
 check(progress.spirit_stone == stones+218, "actual claim uses tier26 rate")
 check(not idle.claim_idle_reward().get("success",false) and progress.spirit_stone == stones+218, "repeat claim cannot pay twice")
 var persisted: Dictionary = saver.read_save_data(idle.SAVE_DOMAIN)
 check(persisted.get("success",false) and persisted.data == idle.state, "idle claim persisted")
 var sword: String = "nine_heavens_star_sword"
 inv.item_counts[sword] = 1
 eq.ascension_stars[sword] = 2
 eq.weapon_levels[sword] = 10
 progress.spirit_stone = 129
 check(not eq.level_weapon(sword) and eq.get_item_weapon_level(sword) == 10 and progress.spirit_stone == 129, "insufficient funds no change")
 progress.spirit_stone = 130
 check(eq.level_weapon(sword) and eq.get_item_weapon_level(sword) == 11 and progress.spirit_stone == 0, "exact funds debit new price")
 check(inv.item_counts[sword] == 1 and eq.get_item_star(sword) == 2, "levels preserve duplicates and stars")
 var saved_eq: Dictionary = saver.read_save_data("equipment")
 var saved_progress: Dictionary = saver.read_save_data("progression")
 check(saved_eq.data.weapon_levels[sword] == 11 and saved_progress.data.spirit_stone == 0, "cost and level durable together")
 await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
 print("ECONOMY_PROGRESS_QA checks=",checks," failures=",failures)
 quit(1 if failures else 0)
