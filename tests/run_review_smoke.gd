extends SceneTree
const Ledger = preload("res://scripts/weapon/run_combat_ledger.gd")
const Review = preload("res://scripts/data/run_review.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("RUN_REVIEW " + label)
func frames(count: int = 6) -> void:
	for i: int in range(count): await process_frame
func _initialize() -> void: run.call_deferred()
func finish(marker: String) -> void:
	paused = false
	var world: Node = current_scene
	current_scene = null
	world.queue_free()
	await frames(8)
	await load("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	print(marker, " checks=", checks, " failures=", failures)
	quit.call_deferred(1 if failures else 0)
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_event_touch_qa"): quit(2); return
	create_timer(60).timeout.connect(func(): quit(1))
	await frames()
	var restarting: bool = "--resume" in OS.get_cmdline_user_args()
	if restarting: root.get_node("GameSession").continue_saved_game()
	else:
		root.get_node("GameSession").start_new_game()
		root.get_node("JourneyManager").begin_selected_stage()
	check(change_scene_to_file("res://scenes/levels/level_1.tscn") == OK, "real scene")
	await create_timer(0.2).timeout
	current_scene.get_node("HUD/ScreenRoot/HUDSafeArea/TutorialOverlay")._on_skip_pressed(); paused = false
	var owner: Node = current_scene.get_node("EnemySpawner")
	owner.set_process(false); owner.clear_normal_enemies()
	current_scene.get_node("WaveManager").set_process(false)
	var player: Node = current_scene.get_node("player_1")
	player.set_physics_process(false); player.get_node("WeaponManager").set_process(false)
	var health: Node = player.get_node("PlayerHealth")
	var ledger: Node = player.get_node("WeaponManager/RunCombatLedger")
	var checkpoint: Node = current_scene.get_node("CheckPointManager")
	if not restarting:
		health.take_damage(10)
		check(ledger.hp_hits == 1 and health.current_health == 90 and ledger.hp_loss == 10, "actual HP loss recorded")
		check(checkpoint.save_checkpoint(), "wounded checkpoint saved")
		health.current_health = 100; health.health_changed.emit(100, 100)
		check(checkpoint.load_checkpoint(), "wounded checkpoint loaded")
		check(ledger.hp_hits == 1 and ledger.hp_loss == 10, "Continue does not invent HP loss or hit")
		health.heal(5)
		check(ledger.hp_hits == 1 and ledger.hp_loss == 10, "healing is not damage")
		check(checkpoint.save_checkpoint(), "healed wounded state persisted for separate process")
		await finish("RUN_REVIEW"); return
	check(health.current_health == 95 and ledger.hp_hits == 1 and ledger.hp_loss == 10, "separate-process Continue retains wounded HP and original metrics")
	check(ledger.incoming_complete and ledger.metrics_complete, "new completeness survives restart")
	health.hit_guard_remaining = 0; health.qi_shield_charges = 1
	health.take_damage(500)
	check(health.current_health == 95 and ledger.hp_loss == 10 and ledger.hp_hits == 1, "shield absorbs damage without false HP loss")
	health.hit_guard_remaining = 0; health.take_damage(7)
	check(health.current_health == 88 and ledger.hp_loss == 17 and ledger.hp_hits == 2, "post-Continue baseline counts only actual next damage")
	var snapshot: Dictionary = ledger.snapshot()
	check(Ledger.valid_snapshot(snapshot), "new snapshot valid")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.metrics.erase("hp_loss"); legacy.metrics.erase("incoming_complete")
	check(Ledger.valid_snapshot(legacy), "old optional metrics accepted")
	ledger.restore(legacy)
	check(ledger.hp_hits == 2 and ledger.metrics_complete and not ledger.incoming_complete, "legacy known hits retained; incoming history explicitly unknown")
	for loss: Variant in [NAN, -1, 1.0e13, "10"]:
		var bad: Dictionary = snapshot.duplicate(true); bad.metrics.hp_loss = loss
		check(not Ledger.valid_snapshot(bad), "malformed incoming loss rejected")
	var broken: Dictionary = snapshot.duplicate(true); broken.metrics.erase("incoming_complete")
	check(not Ledger.valid_snapshot(broken), "incomplete incoming metadata rejected")
	ledger.restore(snapshot)
	var end: Node = current_scene.get_node("GameOverManager")
	var ui: Node = current_scene.get_node("GameOverUI")
	var ceremony: Node = ui.get_node("ResultCeremony")
	current_scene.get_node("WaveManager").current_wave = 6
	var expected_reward: int = root.get_node("RewardManager").get_game_over_reward(6).get("spirit_stone", 0)
	var before_stones: int = root.get_node("ProgressionManager").spirit_stone
	var boss: Node = owner.boss_scene.instantiate()
	current_scene.add_child(boss); boss.set_physics_process(false); boss.current_hp = 125; boss.max_hp = 500
	ledger.record("fire_orb", 12345)
	health.hit_guard_remaining = 0; health.take_damage(10000)
	await frames(12)
	check(end.game_over_triggered and paused and ui.visible, "actual death opens review and revive window")
	check(ledger.hp_loss == 105 and ledger.hp_hits == 3 and ledger.deaths == 1, "overkill capped to actual lost HP including lethal hit")
	check(not ledger.frozen and ceremony.review.hits == 3, "deferred defeat review includes final hit and does not freeze ledger")
	check(ceremony.review.boss_fraction == 0.25 and ceremony._review_title.text.contains("25%"), "actual boss HP shown in review")
	check(ceremony._report_damage.size() > 0 and ceremony._report_skills.size() > 0, "real damage and acquired skills available")
	check(root.get_node("ProgressionManager").spirit_stone == before_stones and not end.defeat_finalized, "read-only review never finalizes or grants")
	end.rewarded_revive_pending = true
	ui._on_review_hero_pressed(); ui._on_main_menu_pressed(); ui._on_retry_pressed()
	check(not end.defeat_finalized and not ui._leaving_run and not root.get_node("SceneTransitionManager").is_transitioning, "all exits wait for pending revive")
	check(not end.finalize_defeat(), "manager also rejects pending-revive finalization")
	end.cancel_pending_rewarded_revive()
	check(end.prepare_rewarded_revive(), "real revive preparation still works")
	var result: Dictionary = end.apply_verified_rewarded_revive("qa_run_review_verified_fixture")
	check(bool(result.success) and not paused and not ui.visible and not ledger.frozen, "verified fixture revive resumes without report freeze")
	health.rewarded_revive_invulnerable_until_msec = 0; health.hit_guard_remaining = 0
	health.take_damage(5)
	check(ledger.hp_hits == 4 and ledger.hp_loss == 110, "damage metrics continue after revive")
	check(checkpoint.save_checkpoint(), "revived metrics still save")
	boss.queue_free(); await frames()
	health.hit_guard_remaining = 0; health.take_damage(10000); await frames(10)
	check(ceremony.review.hits == 5 and not end.defeat_finalized, "second defeat refreshes review")
	check(Review.advice({"metrics_complete": true, "hits": 9}, "en").body.contains("Qi Shield"), "advice uses actual pressure")
	check(Review.advice({"wave": 2, "level": 2}, "id").body.contains("Qi"), "early progression advice localized")
	check(Review.advice({}, "en").body.contains("Hero"), "empty-data fallback safe")
	var hero: Button = ceremony._body.find_child("ReviewHeroButton", true, false)
	hero.pressed.emit(); hero.pressed.emit()
	await create_timer(2, true).timeout
	check(current_scene.scene_file_path == "res://scenes/ui/equipment_screen.tscn", "Hero action navigates to actual preparation page")
	check(root.get_node("ProgressionManager").spirit_stone == before_stones + expected_reward and expected_reward > 0, "spam Hero grants the existing recovery exactly once")
	check(not root.get_node("JourneyManager").has_active_run(), "Hero exit cleans active run")
	check(not root.get_node("SaveManager").read_save_data("checkpoint").get("success", false), "finalized defeat cannot be continued")
	await finish("RUN_REVIEW_RESTART")
