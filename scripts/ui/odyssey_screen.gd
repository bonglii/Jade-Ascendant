extends Control
const Board = preload("res://scripts/ui/liveops/odyssey_board.gd")
const BG = preload("res://assets/ui/liveops/odyssey/board.png")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
const FONT = preload("res://assets/ui/library/fonts/archive_serif.ttf")
const FRAME = preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
const BUTTON = preload("res://assets/ui/trials/ascendant_v2/claim_button.svg")
var client: Node
var board: Control
var tickets: Label
var progress: Label
var notice: Label
var countdown: Label
var roll: Button
var ad: Button
var buy: Button
var milestones: Array[Button] = []
var modal: Control
var safe: Control
var observed_rolls: int = -1
var _clock: float = 0.0
var _modal_kind: String = ""
var _battle_buttons: Array[Button] = []
var _battle_timer: Label
var _pending_milestone: int = 0
func label(text: String, font_size: int = 18) -> Label:
	var node := Label.new(); node.text = text; node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color", Color("eee6cb")); node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; return node
func style(texture: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new(); box.texture = texture
	box.texture_margin_left = 18; box.texture_margin_right = 18; box.texture_margin_top = 18; box.texture_margin_bottom = 18
	box.content_margin_left = 16; box.content_margin_right = 16; box.content_margin_top = 12; box.content_margin_bottom = 12; return box
func button(text: String, callback: Callable) -> Button:
	var node := Button.new(); node.text = text; node.custom_minimum_size.y = 48
	node.add_theme_font_size_override("font_size",17); node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for state: String in ["normal","hover","focus"]: node.add_theme_stylebox_override(state, style(BUTTON))
	node.pressed.connect(callback); node.size_flags_horizontal = Control.SIZE_EXPAND_FILL; return node
func _ready() -> void:
	SceneTransitionManager.set_back_handler(_back)
	client = get_node_or_null("/root/OdysseyClient")
	var background := TextureRect.new(); background.texture = BG; background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(background)
	var shade := ColorRect.new(); shade.color = Color(0.005,0.035,0.04,0.35); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(shade)
	safe = Control.new(); safe.set_script(preload("res://scripts/ui/mobile_safe_area.gd")); add_child(safe); safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new(); safe.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 18)
	var scroller := ScrollContainer.new(); scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; margin.add_child(scroller)
	var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 10); scroller.add_child(body)
	var top := HBoxContainer.new(); body.add_child(top)
	var back: Button = button("‹", _back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; back.custom_minimum_size.x = 48; top.add_child(back)
	var heading := VBoxContainer.new(); heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(heading)
	var eyebrow: Label = label("CELESTIAL EXPEDITION",12); eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_child(eyebrow)
	var title: Label = label("Jade Dragon Odyssey",28); title.add_theme_font_override("font",FONT); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_child(title)
	var retry: Button = button("↻", func() -> void: client.refresh()); retry.size_flags_horizontal = Control.SIZE_SHRINK_END; retry.custom_minimum_size.x = 48; top.add_child(retry)
	countdown = label("Connecting to the celestial atlas…",14); countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(countdown)
	var summary := HBoxContainer.new(); body.add_child(summary)
	tickets = label("DICE  —",22); tickets.autowrap_mode = TextServer.AUTOWRAP_OFF; tickets.size_flags_horizontal = Control.SIZE_EXPAND_FILL; summary.add_child(tickets)
	progress = label("0 / 72 JOURNEYS",18); progress.autowrap_mode = TextServer.AUTOWRAP_OFF; summary.add_child(progress)
	board = Board.new(); board.size_flags_horizontal = Control.SIZE_EXPAND_FILL; board.size_flags_vertical = Control.SIZE_EXPAND_FILL; board.custom_minimum_size.y = 320; body.add_child(board); board.travel_finished.connect(_refresh)
	notice = label("Explore the paths. Every journey advances the guaranteed reward.",16); notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; notice.custom_minimum_size.y = 42; body.add_child(notice)
	var reward_panel := PanelContainer.new(); reward_panel.add_theme_stylebox_override("panel",style(FRAME)); body.add_child(reward_panel)
	var reward_row := HBoxContainer.new(); reward_panel.add_child(reward_row)
	var icon := TextureRect.new(); icon.texture = COMPASS; icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.custom_minimum_size = Vector2(64,64); icon.mouse_filter = Control.MOUSE_FILTER_IGNORE; reward_row.add_child(icon)
	var reward_text: Label = label("HEAVENWEAVER COMPASS\n★★★★★  ·  GUARANTEED AT 72",17); reward_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; reward_row.add_child(reward_text)
	var claims := HBoxContainer.new(); body.add_child(claims)
	for n: int in [24,48,72]:
		var claim: Button = button(str(n) + "  ✧", func() -> void: _submit({"kind":"milestone","milestone":n})); claims.add_child(claim); milestones.append(claim)
	var controls := HBoxContainer.new(); body.add_child(controls)
	controls.add_child(button("MISSIONS",_missions)); roll = button("ROLL DICE",func() -> void: _submit({"kind":"roll"})); controls.add_child(roll); controls.add_child(button("INFO",_info))
	var monetization := HBoxContainer.new(); body.add_child(monetization)
	ad = button("▶  +1 DICE · AD",func() -> void: client.watch_ad()); monetization.add_child(ad)
	buy = button("+  JADE DICE",_shop); monetization.add_child(buy)
	if client != null:
		client.changed.connect(_refresh); client.finished.connect(_finished); client.refresh()
	_refresh()
func _submit(action: Dictionary) -> void:
	if client != null and client.submit(action):
		if action.get("kind") == "milestone": _pending_milestone = int(action.get("milestone",0))
		_close_modal()
func _process(delta: float) -> void:
	if _modal_kind == "battle" and is_instance_valid(_battle_timer):
		var battle: Dictionary = client.snapshot.get("state",{}).get("battle",{})
		var now: int = int(client.server_time())
		var counter_open: bool = now >= int(battle.get("opens_at",0))
		var left: int = int(battle.get("deadline",0)) - now
		_battle_timer.text = "GUARDIAN WINDUP…" if not counter_open else "COUNTER WINDOW · %ds" % maxi(0,left) if left >= 0 else "WINDOW MISSED · TAP A STANCE TO CONTINUE"
		for action: Button in _battle_buttons:
			if is_instance_valid(action): action.disabled = client.busy or not counter_open
	_clock += delta
	if _clock >= 1.0: _clock = 0; _update_time()
func _update_time() -> void:
	if client == null: return
	var event: Variant = client.snapshot.get("event")
	if not event is Dictionary: countdown.text = "Event not yet scheduled"; return
	var remaining: int = int(event.ends_at) - int(client.server_time())
	countdown.text = "%d DAYS REMAINING  ·  SERVER EVENT" % maxi(0, ceili(float(remaining) / 86400.0)) if remaining > 0 else "JOURNEY CLOSED · CLAIM MILESTONES"
func _refresh() -> void:
	if client == null: return
	var state: Dictionary = client.snapshot.get("state", {})
	var event: Dictionary = client.snapshot.get("event", {}) if client.snapshot.get("event") is Dictionary else {}
	var active: bool = bool(event.get("enabled",false)) and int(client.server_time()) >= int(event.get("starts_at",0)) and int(client.server_time()) < int(event.get("ends_at",0))
	var count: int = int(state.get("rolls",0)); tickets.text = "DICE  %d" % int(state.get("tickets",0)); progress.text = "%d / 72 JOURNEYS" % count
	var dice: int = int(state.get("last_die",0)); var steps: int = dice if observed_rolls >= 0 and count == observed_rolls + 1 else 0
	if count != observed_rolls: board.show_position(int(state.get("position",0)),steps)
	observed_rolls = count
	var travelling: bool = board.is_travelling()
	roll.disabled = client.busy or travelling or not active or int(state.get("tickets",0))<1 or not str(state.get("pending", "")).is_empty() or state.get("battle") != null
	ad.disabled = client.busy or travelling or not active or not bool(event.get("ads_enabled",false)) or int(state.get("daily_ads",0)) >= 2
	ad.text = "▶  +1 DICE · AD  %d/2" % int(state.get("daily_ads",0))
	buy.disabled = client.busy or travelling or not active or not bool(event.get("purchases_enabled",false)) or int(state.get("season_bought",0)) >= 40
	for i: int in range(milestones.size()):
		var n: int = [24,48,72][i]; var claimed: bool = n in state.get("milestones",[])
		milestones[i].text = "%d  %s" % [n, "✓" if claimed else "CLAIM" if count >= n else "✧"]
		milestones[i].disabled = client.busy or claimed or count < n
	notice.text = str(state.get("notice","Connect Google to begin your journey.")) if client.status == "connected" else str(client.status).replace("_"," ").capitalize()
	if travelling: notice.text = "ROLLED %d · TRAVELLING THE ATLAS" % dice
	_update_time()
	if modal == null and not client.busy and not travelling:
		if state.get("battle") is Dictionary: _battle()
		elif state.get("pending", "") == "route": _routes()
		elif active and state.get("day", "") != Time.get_datetime_string_from_unix_time(int(client.server_time())).substr(0,10): _submit({"kind":"sync"})
func _finished(action: String, success: bool) -> void:
	if action == "milestone":
		if success and _pending_milestone == 72: _ceremony()
		_pending_milestone = 0
func _close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null; _modal_kind = ""; _battle_buttons.clear(); _battle_timer = null
func _popup(title: String, kind: String) -> VBoxContainer:
	_close_modal(); _modal_kind = kind
	modal = Control.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); safe.add_child(modal)
	var dim := ColorRect.new(); dim.color = Color(0.002,0.01,0.02,0.83); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.add_child(center)
	var panel := PanelContainer.new(); panel.custom_minimum_size = Vector2(minf(size.x - 44, 510),0); panel.add_theme_stylebox_override("panel",style(FRAME)); center.add_child(panel)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y = minf(size.y * 0.72, 570); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; panel.add_child(scroll)
	var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",15); scroll.add_child(body)
	var heading: Label = label(title,27); heading.add_theme_font_override("font",FONT); heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; body.add_child(heading)
	return body
func _info() -> void:
	var body: VBoxContainer = _popup("THE CELESTIAL ATLAS","info")
	body.add_child(label("Roll to travel around the sanctuary. Gate tiles offer Quiet Grove supplies or a three-turn Dragon Gate counter trial. Read the guardian's announced stance, wait for its opening, then choose the matching counter.\n\nFREE: 3 dice on daily login + 1 die each for rolling 1, 3 and 5 times. Resets at 00:00 UTC.\n\nOPTIONAL: 2 verified ad dice/day. Jade dice: 1 for 25 or 5 for 100 Purchased Jade. Limit 10/day and 40/season.\n\n24 journeys: 2 Pavilion Seals.\n48: 3 Pavilion Seals + 500 Spirit Stones.\n72: guaranteed Heavenweaver Compass.\n\nRewards arrive in Mail. You have 3 days after the event to claim reached milestones. Dice expire with this season. Purchases do not change the die odds: each face is 1 in 6."))
	body.add_child(button("UNDERSTOOD",_close_modal))
func _missions() -> void:
	var body: VBoxContainer = _popup("DAILY DISCIPLINES","missions")
	var state: Dictionary = client.snapshot.get("state",{})
	body.add_child(label("Three daily login dice are collected automatically. Complete these journeys to earn three more."))
	for n: int in [1,3,5]:
		var claimed: bool = n in state.get("missions",[])
		var claim: Button = button("ROLL %d TIMES · %s" % [n,"CLAIMED" if claimed else "+1 DICE"],func() -> void: _submit({"kind":"mission","mission":n})); claim.disabled = client.busy or claimed or int(state.get("daily_rolls",0)) < n; body.add_child(claim)
	body.add_child(button("RETURN",_close_modal))
func _shop() -> void:
	var body: VBoxContainer = _popup("JADE TRAVEL SEALS","shop")
	var state: Dictionary = client.snapshot.get("state",{})
	var paid: Node = get_node_or_null("/root/PavilionManager/PaidGameplayV2")
	var balance: int = int(paid.call("paid_balance")) if paid != null else 0
	body.add_child(label("Uses your server-verified Purchased Jade balance. Dice do not increase the chance of any die face. Confirm a pack below.\n\nAvailable Purchased Jade: %d\nBought today: %d / 10\nBought this season: %d / 40\nOnly the 72-journey milestone grants the Compass; extra journeys do not grant another copy." % [balance,int(state.get("daily_bought",0)),int(state.get("season_bought",0))]))
	for pack: int in [1,5]:
		var purchase: Button = button("BUY %d DICE · %d JADE" % [pack,25 if pack == 1 else 100],func() -> void: _submit({"kind":"buy_dice","pack":pack})); purchase.disabled = client.busy or balance < (25 if pack == 1 else 100) or int(state.get("daily_bought",0)) + pack > 10 or int(state.get("season_bought",0)) + pack > 40; body.add_child(purchase)
	body.add_child(button("CANCEL",_close_modal))
func _routes() -> void:
	var body: VBoxContainer = _popup("CHOOSE YOUR PATH","route")
	body.add_child(label("QUIET GROVE · peaceful supplies\nSafe passage grants 30 Spirit Stones.\n\nDRAGON GATE · read and counter\nWin at least 2 of 3 counters for 60 Spirit Stones. A missed trial still grants base supplies."))
	var grove := TextureRect.new(); grove.texture = preload("res://assets/ui/liveops/event_identity/pilgrimage.png"); grove.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; grove.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; grove.custom_minimum_size.y = 90; body.add_child(grove)
	body.add_child(button("QUIET GROVE",func() -> void: _submit({"kind":"route","choice":"safe"})))
	var gate := TextureRect.new(); gate.texture = preload("res://assets/ui/liveops/event_identity/boss_hunt.png"); gate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; gate.custom_minimum_size.y = 90; body.add_child(gate)
	body.add_child(button("DRAGON GATE",func() -> void: _submit({"kind":"route","choice":"challenge"})))
func _battle() -> void:
	var battle: Dictionary = client.snapshot.get("state",{}).get("battle",{})
	var body: VBoxContainer = _popup("DRAGON GATE · %d / 3" % (int(battle.get("turn",0))+1),"battle")
	var stance: int = int(battle.get("attack",0)); var names: Array[String] = ["HEAVEN","EARTH","HUMAN"]
	body.add_child(label("The guardian reveals %s.\nCounter with the matching stance after the opening.\nLand 2 successful counters to win." % names[stance],21))
	_battle_timer = label("GUARDIAN WINDUP…",16); body.add_child(_battle_timer)
	for i: int in range(3):
		var counter: Button = button(names[i],func() -> void: _submit({"kind":"counter","choice":i})); counter.disabled = true; body.add_child(counter); _battle_buttons.append(counter)
func _ceremony() -> void:
	var body: VBoxContainer = _popup("HEAVENWEAVER AWAKENS","ceremony")
	var art: Control = preload("res://scripts/ui/liveops/odyssey_ceremony.gd").new(); body.add_child(art)
	body.add_child(label("★★★★★  HEAVENWEAVER COMPASS\nSecured in Mail. Claim its attachment to equip your new armament.",20))
	body.add_child(button("RETURN TO THE ATLAS",_close_modal))

func _back() -> void:
	if is_instance_valid(modal): _close_modal(); return
	if not SceneTransitionManager.is_transitioning:
		SceneTransitionManager.transition_menu_to("res://scenes/ui/event_center_screen.tscn", -1)
func _exit_tree() -> void:
	if SceneTransitionManager.back_handler == Callable(self, "_back"):
		SceneTransitionManager.set_back_handler(Callable())
