extends SceneTree
class Event extends Node:
	signal changed
	signal finished(action: String,success: bool)
	var snapshot: Dictionary = {}
	var status: String = "connected"
	var busy: bool = false
	func server_time() -> int: return 1800000000
	func refresh() -> bool: return true
	func submit(_action: Dictionary) -> bool: return false
	func purchase_bonus_active() -> bool: return true
var output: String
var failures: int = 0
var checks: int = 0
func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error("PREMIUM_MENU " + message)
func frames(count: int = 8) -> void:
	for index: int in count: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if not OS.get_user_data_dir().contains("jade_premium_qa"): quit(2); return
	output = OS.get_environment("JADE_RENDER_OUTPUT"); DirAccess.make_dir_recursive_absolute(output)
	await frames(10)
	var prewarm: Node = root.get_node_or_null("MenuResourcePrewarm")
	if prewarm != null: prewarm.queue_free()
	root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(648,1152)
	var guide: Node = root.get_node("RefineOnboarding"); guide.completed = true; guide.set_process(false)
	var original: Node = root.get_node("OdysseyClient"); original.name = "OriginalOdysseyClient"; original.set_process(false)
	var event := Event.new(); event.name = "OdysseyClient"
	event.snapshot = {"owner_binding":"a".repeat(64),"revision":1,"event":{"id":"dragon-test","enabled":true,"ads_enabled":true,"purchases_enabled":true,"starts_at":1799999900,"ends_at":1801000000},"state":{"tickets":3,"rolls":12,"position":4,"daily_rolls":3,"missions":[1],"milestones":[],"daily_gifts":3,"daily_guardians":0,"task_claims":[],"day":"2027-01-15"},"purchase_bonus":{"active":true,"offers":[{"product_id":"jade_satchel_550","jade":550,"dice":3,"claimed":false}]}}
	root.add_child(event)
	root.get_node("PavilionManager").billing_provider = null
	root.get_node("PavilionManager").billing_store_products = {"jade_satchel_550":{"formatted_price":"Rp75.000","price_amount_micros":75000000000}}
	change_scene_to_file("res://scenes/ui/odyssey_screen.tscn"); await frames(14)
	var screen: Node = current_scene
	for dimensions: Vector2i in [Vector2i(360,640),Vector2i(648,1152)]:
		root.size = dimensions; await frames()
		for kind: String in ["route","missions","shop","journey"]:
			match kind:
				"route": screen._routes()
				"missions": screen._missions()
				"shop": screen._shop()
				"journey": screen._journey_rewards()
			await frames(10)
			var panel: Control = screen._modal_panel
			check(Rect2(Vector2.ZERO,Vector2(dimensions)).grow(1).encloses(panel.get_global_rect()),kind+" within viewport "+str(dimensions))
			check(panel.size.y < dimensions.y - 20,kind+" has outside breathing room "+str(dimensions))
			await shot("odyssey-%s-%d" % [kind,dimensions.x])
			screen._close_modal(); await frames(2)
	change_scene_to_file("res://scenes/ui/mailbox_screen.tscn"); root.size = Vector2i(648,1152); await frames(10)
	check(current_scene.find_child("MailboxDeleteAllCompleted",true,false) != null,"mailbox delete completed action is visible")
	await shot("mailbox")
	change_scene_to_file("res://scenes/ui/new_player_event_screen.tscn"); await frames(10)
	await shot("login")
	var ops: Node = root.get_node("LiveOpsManager")
	check(int(ops.get_login_reward(7).celestial_jade) == 25,"login display uses real catalog")
	change_scene_to_file("res://scenes/ui/daily_quest_screen.tscn"); await frames(12)
	await shot("trials")
	var trial: Node = current_scene.get_node("TrialsProductionPresenter")
	check(trial.completion_reward.text.contains("Jade"),"trial footer discloses existing completion Jade")
	root.get_node("AchievementManager").set_progress_at_least("first_boss_defeat",1)
	trial._switch_section("achievement"); await frames(12)
	await shot("achievements")
	var presenter: Node = root.get_node("RewardClaimResultPresenter")
	presenter.show_claimed_reward("ACHIEVEMENT",{"spirit_stone":300,"celestial_jade":40,"pavilion_seal":1,"items":{}})
	await create_timer(1.4).timeout
	await shot("claim-summary")
	presenter._close_popup()
	await preload("res://tests/qa_runtime_teardown.gd").stop_audio(self)
	current_scene.queue_free(); current_scene = null; await frames(10)
	Node.print_orphan_nodes()
	print("PREMIUM_MENU_RENDER checks=",checks," failures=",failures)
	quit(1 if failures else 0)
