extends Control
const Art=preload("res://scripts/ui/liveops/odyssey_art.gd")
const PremiumButton=preload("res://scripts/ui/liveops/odyssey_button.gd")
const PremiumPanel=preload("res://scripts/ui/liveops/odyssey_panel.gd")
const Dice=preload("res://scripts/ui/liveops/odyssey_dice.gd")
const Board = preload("res://scripts/ui/liveops/odyssey_board.gd")
const BG = preload("res://assets/ui/liveops/odyssey/board.png")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
const FONT = preload("res://assets/ui/library/fonts/archive_serif.ttf")
var dice_view: Control
var progress_bar: ProgressBar
var missions_button: Button
var _reveal_pending: bool=false
var _presentation_pending: Dictionary={}
var _reward_identity: String=""
var _reward_banner: PanelContainer
var _toast_motion: Tween
var _presentation_binding: String=""
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
func button(text: String, callback: Callable, primary: bool=false) -> Button:
	var node:=PremiumButton.new(); node.text=text; node.primary=primary; node.custom_minimum_size.y=80 if primary else 68
	node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; node.size_flags_horizontal=Control.SIZE_EXPAND_FILL; node.pressed.connect(callback); return node
func _navigation(glyph: String, callback: Callable, hint: String) -> Button:
	var node: Button=button("",callback); node.glyph=glyph; node.tooltip_text=hint; node.custom_minimum_size=Vector2(64,64); node.size_flags_horizontal=Control.SIZE_SHRINK_CENTER; return node
func _card() -> PanelContainer:
	return PremiumPanel.new()
func _icon(texture: Texture2D, side: float) -> TextureRect:
	var icon:=TextureRect.new(); icon.texture=texture; icon.custom_minimum_size=Vector2.ONE*side; icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; return icon
func _presenting() -> bool: return _reveal_pending or not _presentation_pending.is_empty() or (board!=null and board.is_travelling())
func _roll_pressed() -> void:
	if client==null or client.busy or _presenting(): return
	var state: Dictionary=client.snapshot.get("state",{})
	if state.get("battle") is Dictionary: _battle()
	elif state.get("pending","")=="route": _routes()
	else: _submit({"kind":"roll"})
func _watch_ad() -> void:
	if client!=null and not client.busy and not _presenting(): client.watch_ad()
func _dice_revealed() -> void:
	var binding: String=_presentation_binding
	await get_tree().create_timer(0.24 if not Art.reduced(self) else 0.05).timeout
	if not is_inside_tree() or binding!=_presentation_binding: return
	dice_view.visible=false; _reveal_pending=false
	if _presentation_pending.is_empty(): return
	var pending: Dictionary=_presentation_pending; _presentation_pending={}; board.show_position(int(pending.position),int(pending.steps)); _refresh()
func _travel_finished() -> void:
	_show_reward(); _refresh()
func _show_reward() -> void:
	if client==null: return
	var identity: String=str(client.snapshot.get("revision",0))
	if identity==_reward_identity: return
	_reward_identity=identity
	var reward: Dictionary=client.snapshot.get("state",{}).get("last_reward",{}); var pieces: Array[String]=[]
	if int(reward.get("spirit_stone",0))>0: pieces.append("+%d Spirit Stones" % int(reward.spirit_stone))
	if int(reward.get("celestial_jade",0))>0: pieces.append("+%d Celestial Jade" % int(reward.celestial_jade))
	if int(reward.get("pavilion_seal",0))>0: pieces.append("+%d Pavilion Seals" % int(reward.pavilion_seal))
	if pieces.is_empty(): return
	if is_instance_valid(_reward_banner): _reward_banner.queue_free()
	if _toast_motion!=null: _toast_motion.kill()
	_reward_banner=_card(); _reward_banner.z_index=10; _reward_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE; safe.add_child(_reward_banner); _reward_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_reward_banner.offset_top=170; _reward_banner.offset_left=-230; _reward_banner.offset_right=230
	var text: Label=label("REWARD SECURED IN MAIL\n"+" · ".join(pieces),17); text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _reward_banner.add_child(text)
	_reward_banner.modulate.a=0.0; _toast_motion=create_tween(); _toast_motion.tween_property(_reward_banner,"modulate:a",1.0,0.18); _toast_motion.tween_interval(1.9); _toast_motion.tween_property(_reward_banner,"modulate:a",0.0,0.35)
func _ready() -> void:
	SceneTransitionManager.set_back_handler(_back)
	client=get_node_or_null("/root/OdysseyClient")
	var background:=TextureRect.new(); background.texture=BG; background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(background)
	var shade:=ColorRect.new(); shade.color=Color(0.005,0.025,0.032,0.48); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(shade)
	safe=Control.new(); safe.set_script(preload("res://scripts/ui/mobile_safe_area.gd")); add_child(safe); safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin:=MarginContainer.new(); safe.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: margin.add_theme_constant_override("margin_"+side,18)
	margin.add_theme_constant_override("margin_top",12); margin.add_theme_constant_override("margin_bottom",16)
	var scroll:=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; margin.add_child(scroll)
	var body:=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",6); scroll.add_child(body)
	var top:=HBoxContainer.new(); top.add_theme_constant_override("separation",8); body.add_child(top); top.add_child(_navigation("back",_back,"Return to events"))
	var heading:=VBoxContainer.new(); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_theme_constant_override("separation",1); top.add_child(heading)
	var eyebrow: Label=label("CELESTIAL EXPEDITION",11); eyebrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; eyebrow.add_theme_color_override("font_color",Art.GOLD); heading.add_child(eyebrow)
	var title: Label=label("Jade Dragon Odyssey",30); title.add_theme_font_override("font",FONT); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; heading.add_child(title)
	countdown=label("CONNECTING TO THE ATLAS",12); countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; heading.add_child(countdown); top.add_child(_navigation("info",_info,"Event rules"))
	var summary:=_card(); summary.custom_minimum_size.y=112; body.add_child(summary); var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",8); summary.add_child(row)
	var dice_badge:=_icon(Art.DIE,52); dice_badge.name="TravelDiceBadge"; dice_badge.size_flags_vertical=Control.SIZE_SHRINK_CENTER; row.add_child(dice_badge)
	var purse:=VBoxContainer.new(); purse.size_flags_horizontal=Control.SIZE_EXPAND_FILL; purse.alignment=BoxContainer.ALIGNMENT_CENTER; row.add_child(purse); purse.add_child(label("TRAVEL DICE",14))
	tickets=label("—",34); tickets.add_theme_font_override("font",FONT); tickets.add_theme_color_override("font_color",Art.GOLD); purse.add_child(tickets)
	var journey:=VBoxContainer.new(); journey.custom_minimum_size.x=140; journey.size_flags_horizontal=Control.SIZE_EXPAND_FILL; journey.alignment=BoxContainer.ALIGNMENT_CENTER; row.add_child(journey)
	journey.add_child(label("GUARANTEED LEGENDARY",13)); progress=label("0 / 72 JOURNEYS",22); journey.add_child(progress)
	progress_bar=ProgressBar.new(); progress_bar.max_value=72; progress_bar.show_percentage=false; progress_bar.custom_minimum_size.y=8
	var fill:=StyleBoxFlat.new(); fill.bg_color=Art.GOLD; fill.set_corner_radius_all(4); progress_bar.add_theme_stylebox_override("fill",fill)
	var track:=StyleBoxFlat.new(); track.bg_color=Color("092c2a"); track.set_corner_radius_all(4); progress_bar.add_theme_stylebox_override("background",track); journey.add_child(progress_bar)
	board=Board.new(); board.size_flags_horizontal=Control.SIZE_EXPAND_FILL; board.size_flags_vertical=Control.SIZE_EXPAND_FILL; board.custom_minimum_size.y=480; body.add_child(board); board.travel_finished.connect(_travel_finished)
	dice_view=Dice.new(); dice_view.set_anchors_and_offsets_preset(Control.PRESET_CENTER); dice_view.offset_left=-104; dice_view.offset_right=104; dice_view.offset_top=-104; dice_view.offset_bottom=104; dice_view.z_index=2; dice_view.visible=false; board.add_child(dice_view); dice_view.reveal_finished.connect(_dice_revealed)
	notice=label("Every journey brings your legendary relic closer.",15); notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; notice.custom_minimum_size.y=24; body.add_child(notice)
	var reward:=_card(); body.add_child(reward); var reward_row:=HBoxContainer.new(); reward_row.add_theme_constant_override("separation",10); reward.add_child(reward_row); reward_row.add_child(_icon(COMPASS,56))
	var description:=VBoxContainer.new(); description.size_flags_horizontal=Control.SIZE_EXPAND_FILL; description.alignment=BoxContainer.ALIGNMENT_CENTER; description.add_theme_constant_override("separation",1); reward_row.add_child(description)
	var stars: Label=label("★★★★★  EXCLUSIVE ARMAMENT",12); stars.add_theme_color_override("font_color",Art.GOLD); description.add_child(stars)
	var relic: Label=label("Heavenweaver Compass",23); relic.add_theme_font_override("font",FONT); description.add_child(relic); description.add_child(label("Guaranteed at 72 journeys • Secured in Mail",12))
	var claims:=HBoxContainer.new(); claims.add_theme_constant_override("separation",6); body.add_child(claims)
	for n: int in [24,48,72]:
		var claim: Button=button(str(n),func() -> void: _submit({"kind":"milestone","milestone":n})); claim.custom_minimum_size.y=60; claims.add_child(claim); milestones.append(claim)
	roll=button("ROLL DICE · 1 DIE",_roll_pressed,true); body.add_child(roll)
	var optional:=HBoxContainer.new(); optional.add_theme_constant_override("separation",6); body.add_child(optional)
	ad=button("+1 DIE · AD 0/2",_watch_ad); optional.add_child(ad); buy=button("TRAVEL SHOP",_shop); optional.add_child(buy)
	var footer:=HBoxContainer.new(); footer.add_theme_constant_override("separation",8); body.add_child(footer)
	missions_button=button("DAILY MISSIONS",_missions); missions_button.custom_minimum_size.y=58; footer.add_child(missions_button)
	var retry: Button=button("RECONNECT",func() -> void:
		if client!=null and not client.busy and not _presenting(): client.refresh())
	retry.custom_minimum_size.y=58; footer.add_child(retry)
	if client!=null: client.changed.connect(_refresh); client.finished.connect(_finished); client.refresh()
	_refresh()
	if not Art.reduced(self): body.modulate.a=0.0; create_tween().tween_property(body,"modulate:a",1.0,0.24)
func _submit(action: Dictionary) -> void:
	if client==null or client.busy or _presenting(): return
	if action.get("kind")=="roll": dice_view.start()
	if client.submit(action):
		if action.get("kind") == "milestone": _pending_milestone = int(action.get("milestone",0))
		_close_modal()
	elif action.get("kind")=="roll": dice_view.cancel()
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
	if client==null: return
	var event: Variant=client.snapshot.get("event")
	if not event is Dictionary:
		countdown.text="CONNECTING TO THE ATLAS" if client.busy else "EVENT NOT YET SCHEDULED" if client.status=="connected" else "CONNECTION REQUIRED · TAP RECONNECT"
		return
	var now: int=int(client.server_time()); var remaining: int=int(event.ends_at)-now
	if not bool(event.enabled): countdown.text="EVENT PAUSED"; return
	if now<int(event.starts_at): countdown.text="STARTS IN %dH %dM" % [int(float(int(event.starts_at)-now)/3600.0),int(float((int(event.starts_at)-now)%3600)/60.0)]; return
	countdown.text="%d DAYS %dH REMAINING" % [maxi(0,int(float(remaining)/86400.0)),maxi(0,int(float(remaining%86400)/3600.0))] if remaining>0 else "JOURNEY CLOSED · CLAIM MILESTONES"
func _refresh() -> void:
	if client == null: return
	var state: Dictionary = client.snapshot.get("state", {})
	var event: Dictionary = client.snapshot.get("event", {}) if client.snapshot.get("event") is Dictionary else {}
	var active: bool = bool(event.get("enabled",false)) and int(client.server_time()) >= int(event.get("starts_at",0)) and int(client.server_time()) < int(event.get("ends_at",0))
	var binding: String=str(client.snapshot.get("owner_binding",""))+":"+str(event.get("id",""))
	if binding!=_presentation_binding:
		_presentation_binding=binding; _reveal_pending=false; _presentation_pending={}; observed_rolls=-1; _reward_identity=""; _pending_milestone=0
		dice_view.cancel(); board.show_position(int(state.get("position",0))); _close_modal()
	var count: int = int(state.get("rolls",0)); tickets.text = str(int(state.get("tickets",0))); progress.text = "%d / 72 JOURNEYS" % count; progress_bar.value=mini(count,72)
	var dice: int = int(state.get("last_die",0)); var steps: int = dice if observed_rolls >= 0 and count == observed_rolls + 1 else 0
	if count!=observed_rolls:
		if steps>0:
			_presentation_pending={"position":int(state.get("position",0)),"steps":steps}; _reveal_pending=true
			if not dice_view.rolling: dice_view.start()
			dice_view.resolve(dice)
		else: board.show_position(int(state.get("position",0))); dice_view.face=maxi(1,dice); dice_view.queue_redraw()
	observed_rolls = count
	var travelling: bool = _presenting()
	var resolving: bool=state.get("battle") is Dictionary or state.get("pending","")=="route"
	var claim_open: bool=bool(event.get("enabled",false)) and int(client.server_time())>=int(event.get("starts_at",0)) and int(client.server_time())<int(event.get("ends_at",0))+3*86400
	roll.disabled=client.busy or travelling or (not active and not (resolving and claim_open)) or (int(state.get("tickets",0))<1 and not resolving)
	ad.disabled = client.busy or travelling or not active or not bool(event.get("ads_enabled",false)) or int(state.get("daily_ads",0)) >= 2
	ad.text = "+1 DIE · AD %d/2" % int(state.get("daily_ads",0))
	buy.disabled = travelling
	for i: int in range(milestones.size()):
		var n: int = [24,48,72][i]; var claimed: bool = n in state.get("milestones",[])
		milestones[i].text = "%d · %s" % [n, "CLAIMED" if claimed else "CLAIM" if count>=n else "2 SEALS" if n==24 else "3 SEALS" if n==48 else "COMPASS"]
		milestones[i].disabled = client.busy or travelling or not claim_open or claimed or count < n
	notice.text = str(state.get("notice","Connect Google to begin your journey.")) if client.status == "connected" else {"NETWORK_UNAVAILABLE":"Connection failed. Tap Reconnect; your progress is saved.","ENDPOINT_POLICY_REJECTED":"App update required. Install the latest Play build.","native_update_required":"App update required. Install the latest Play build.","ACCOUNT_HELD":"A refunded purchase requires review. Contact support.","BACKEND_NOT_READY":"Server is preparing the event. Please retry shortly."}.get(str(client.status),str(client.status).replace("_"," ").capitalize())
	if travelling: notice.text="THE DIE IS REVEALING…" if _reveal_pending else "ROLLED %d · LIN YUE IS TRAVELLING" % dice
	roll.text="ROLLING…" if client.busy and dice_view.rolling else "TRAVELLING…" if travelling else "CONTINUE THE GATE" if state.get("battle") is Dictionary else "CHOOSE YOUR PATH" if state.get("pending","")=="route" else "ROLL DICE · 1 DIE"
	buy.text="TRAVEL SHOP"
	missions_button.disabled=client.busy or travelling or not active
	var mission_ready: bool=false
	for n: int in [1,3,5]:
		if int(state.get("daily_rolls",0))>=n and n not in state.get("missions",[]): mission_ready=true
	missions_button.text="MISSIONS · CLAIM" if mission_ready else "DAILY MISSIONS"
	if not client.busy and not travelling and dice_view.rolling: dice_view.cancel()
	_update_time()
	if modal == null and not client.busy and not travelling:
		if state.get("battle") is Dictionary: _battle()
		elif state.get("pending", "") == "route": _routes()
		elif active and state.get("day", "") != Time.get_datetime_string_from_unix_time(int(client.server_time())).substr(0,10): _submit({"kind":"sync"})
func _finished(action: String, success: bool) -> void:
	if not success and action=="roll": dice_view.cancel()
	if success and action in ["mission","buy_dice","route","counter"]: _show_reward()
	if action == "milestone":
		if success and _pending_milestone == 72: _ceremony()
		elif success: _show_reward()
		_pending_milestone = 0
func _close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null; _modal_kind = ""; _battle_buttons.clear(); _battle_timer = null
func _popup(title: String, kind: String) -> VBoxContainer:
	_close_modal(); _modal_kind=kind
	modal=Control.new(); modal.z_index=20; modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); safe.add_child(modal)
	var dim:=ColorRect.new(); dim.color=Color(0.002,0.01,0.02,0.86); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var center:=Control.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.add_child(center)
	var panel:=_card(); panel.clip_contents=true; panel.size=Vector2(minf(safe.size.x-32,540),minf(safe.size.y-32,760)); panel.position=(safe.size-panel.size)*0.5
	var inset: StyleBox=panel.get_theme_stylebox("panel").duplicate(); inset.content_margin_left=64; inset.content_margin_right=64; inset.content_margin_top=56; inset.content_margin_bottom=56; panel.add_theme_stylebox_override("panel",inset); center.add_child(panel)
	var shell:=VBoxContainer.new(); shell.add_theme_constant_override("separation",8); panel.add_child(shell)
	var top:=HBoxContainer.new(); shell.add_child(top)
	var heading: Label=label(title,22); heading.add_theme_font_override("font",FONT); heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; top.add_child(heading); top.add_child(_navigation("close",_close_modal,"Close"))
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; shell.add_child(scroll)
	var body:=VBoxContainer.new(); body.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation",12); scroll.add_child(body)
	if not Art.reduced(self): panel.modulate.a=0.0; create_tween().tween_property(panel,"modulate:a",1.0,0.18)
	return body
func _info() -> void:
	var body: VBoxContainer=_popup("THE CELESTIAL ATLAS","info")
	var limits: Dictionary=client.snapshot.get("limits",{}) if client!=null else {}
	body.add_child(label("FREE DAILY JOURNEYS",19)); body.add_child(label("3 dice arrive on daily login. Roll 1, 3 and 5 times to claim 3 more from Missions. Reset: 00:00 UTC (07:00 WIB).",16))
	body.add_child(label("OPTIONAL DICE",19)); body.add_child(label("2 verified ad dice per day. Purchased Jade: 1 die for %d or 5 dice for %d. Limit 10 bought per day and 40 per season. Every face has a 1 in 6 chance." % [int(limits.get("price_one",10)),int(limits.get("price_five",40))],16))
	body.add_child(label("CHOOSE YOUR PATH",19)); body.add_child(label("Quiet Grove grants peaceful supplies. Dragon Gate opens 3 counter rounds: read the guardian's stance, wait for the opening, then match it. Land 2 counters to win.",16))
	body.add_child(label("GUARANTEED MILESTONES",19)); body.add_child(label("24 journeys: 2 Pavilion Seals.\n48: 3 Pavilion Seals + 500 Spirit Stones.\n72: one Heavenweaver Compass, secured in Mail.\nYou have 3 days after the season to claim reached milestones. Unused dice expire.",16))
func _missions() -> void:
	var body: VBoxContainer=_popup("DAILY DISCIPLINES","missions")
	body.add_child(label("3 login dice arrive automatically. Complete these journeys to claim the remaining daily dice.",16))
	var state: Dictionary=client.snapshot.get("state",{})
	for n: int in [1,3,5]:
		var claimed: bool=n in state.get("missions",[])
		var card:=_card(); body.add_child(card); var row:=HBoxContainer.new(); card.add_child(row); row.add_child(_icon(Art.DIE,48))
		var description: Label=label("ROLL %d TIMES\n%d / %d complete" % [n,mini(int(state.get("daily_rolls",0)),n),n],16); description.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(description)
		var claim: Button=button("CLAIMED" if claimed else "+1 DIE",func() -> void: _submit({"kind":"mission","mission":n})); claim.custom_minimum_size.x=130; claim.size_flags_horizontal=Control.SIZE_SHRINK_END; claim.disabled=client.busy or claimed or int(state.get("daily_rolls",0))<n; row.add_child(claim)
func _shop() -> void:
	if client==null or _presenting(): return
	var body: VBoxContainer=_popup("TRAVEL SHOP","shop")
	var bonus: Dictionary=client.snapshot.get("purchase_bonus",{})
	body.add_child(label("JADE + BONUS TRAVEL DICE",22))
	body.add_child(label("Top up Celestial Jade in Google Play. During the active promotion, each Jade pack includes bonus dice once per season. Prices appear live in the Treasury.",16))
	var offers: Array=bonus.get("offers",[])
	if client.purchase_bonus_active():
		for offer: Dictionary in offers:
			var text: String="%d JADE + %d BONUS DICE" % [int(offer.jade),int(offer.dice)]
			if bool(offer.claimed): text="%d JADE · BONUS CLAIMED" % int(offer.jade)
			body.add_child(button(text,_open_treasury.bind(str(offer.product_id))))
	else:
		body.add_child(label("Dice bonuses require a connected, active season and a new verified purchase after this promotion begins. No bonus is promised while the event is unavailable.",15))
	body.add_child(button("OPEN CELESTIAL TREASURY",_open_treasury.bind(""),true))
	body.add_child(label("Maximum 152 journeys per season. Unused dice expire; extra dice do not grant extra Compass copies. Bonus dice arrive after server purchase verification, never from the payment animation.",15))
	body.add_child(label("EXCHANGE PURCHASED JADE",20))
	var state: Dictionary=client.snapshot.get("state",{})
	var event: Dictionary=client.snapshot.get("event",{}) if client.snapshot.get("event") is Dictionary else {}
	var exchange_ready: bool=client.status=="connected" and not client.busy and bool(event.get("enabled",false)) and bool(event.get("purchases_enabled",false)) and client.server_time()>=int(event.get("starts_at",0)) and client.server_time()<int(event.get("ends_at",0)) and int(state.get("rolls",0))<152
	var paid: Node=get_node_or_null("/root/PavilionManager/PaidGameplayV2")
	var balance: int=int(paid.call("paid_balance")) if paid!=null else 0
	var limits: Dictionary=client.snapshot.get("limits",{})
	body.add_child(label("Verified Purchased Jade: %d\nBought today: %d / 10 · Season: %d / 40" % [balance,int(state.get("daily_bought",0)),int(state.get("season_bought",0))],17))
	body.add_child(label("Optional catch-up packs. Free daily dice can reach the guaranteed reward. Choose a pack, then confirm the cost.",16))
	for pack: int in [1,5]:
		var price: int=int(limits.get("price_one" if pack==1 else "price_five",10 if pack==1 else 40))
		var card:=_card(); body.add_child(card); var content:=VBoxContainer.new(); card.add_child(content)
		var row:=HBoxContainer.new(); row.add_child(_icon(Art.DIE,72)); var description: Label=label("%d TRAVEL %s\n%s" % [pack,"DIE" if pack==1 else "DICE","Single journey" if pack==1 else "20% bundle saving"],20); description.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(description); content.add_child(row)
		var purchase: Button=button("%d JADE · REVIEW PACK" % price,_confirm_pack.bind(pack,price)); purchase.disabled=not exchange_ready or balance<price or int(state.get("daily_bought",0))+pack>10 or int(state.get("season_bought",0))+pack>40; content.add_child(purchase)
func _open_treasury(product_id: String) -> void:
	if SceneTransitionManager.is_transitioning: return
	get_tree().set_meta("odyssey_treasury_return",true)
	get_tree().set_meta("odyssey_treasury_product",product_id)
	SceneTransitionManager.transition_menu_to("res://scenes/ui/celestial_treasury_screen.tscn",1)
func _confirm_pack(pack: int, price: int) -> void:
	var body: VBoxContainer=_popup("CONFIRM YOUR JOURNEY","confirm_pack")
	body.add_child(_icon(Art.DIE,110)); body.add_child(label("%d travel %s for %d Purchased Jade." % [pack,"die" if pack==1 else "dice",price],22))
	body.add_child(label("The server charges once. Extra dice do not change die odds or grant extra Compass copies.",16))
	body.add_child(button("CONFIRM · %d JADE" % price,func() -> void: _submit({"kind":"buy_dice","pack":pack}),true)); body.add_child(button("BACK TO PACKS",_shop))
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
