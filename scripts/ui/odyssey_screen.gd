extends Control
const Flow=preload("res://scripts/ui/liveops/odyssey_flow_skin.gd")
const ARENA_PATH: String="res://scripts/ui/liveops/odyssey_arena.gd"
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
var _modal_panel: Panel
var _modal_header: Control
var _modal_body: VBoxContainer
var _modal_footer: VBoxContainer
var _mission_handles: Array[Dictionary]=[]
var _mission_all: Button
var _arena: Control
var _arena_submit_pending: Dictionary={}
var _retry_at: int=0
var _retry_count: int=0
var _queued_action: Dictionary={}
var _queued_ad: bool=false
var _active_action: Dictionary={}
var _modal_motion: Tween
var _card_sequence: int=0
var _battle_buttons: Array[Button] = []
var _battle_timer: Label
var _pending_milestone: int = 0
var _app_focused: bool=true
var _ad_feedback_clock: float=0.0
var _shop_handles: Array[Dictionary] = []
var _shop_busy: bool = false
var _shop_product: String = ""
var _shop_message: Label
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
	var icon:=TextureRect.new();
	if texture==Art.DIE: icon.set_script(preload("res://scripts/ui/liveops/odyssey_die_badge.gd"))
	icon.texture=texture; icon.custom_minimum_size=Vector2.ONE*side; icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; return icon
func _presenting() -> bool: return _reveal_pending or not _presentation_pending.is_empty() or (board!=null and board.is_travelling())
func _roll_pressed() -> void:
	if client==null or _mutating() or _presenting(): return
	var state: Dictionary=client.snapshot.get("state",{})
	if state.get("battle") is Dictionary: _battle()
	elif state.get("pending","")=="route": _routes()
	else: _submit({"kind":"roll"})
func _watch_ad() -> void:
	if client==null or _presenting() or _ad_pending(): return
	if client.busy:
		if client.status=="refreshing" and _queued_action.is_empty(): _queued_ad=true;_refresh()
		return
	client.watch_ad()
func _dice_revealed() -> void:
	var binding: String=_presentation_binding
	await get_tree().create_timer(0.52 if not Art.reduced(self) else 0.12).timeout
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
	PavilionManager.store_products_updated.connect(_refresh_shop_products)
	PavilionManager.billing_purchase_state_changed.connect(_shop_purchase_state)
	PavilionManager.purchase_delivery_finished.connect(_shop_delivery_finished)
	PavilionManager.pavilion_changed.connect(_refresh_shop_products)

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
		var claim: Button=button(str(n),_journey_rewards); claim.custom_minimum_size.y=60; claims.add_child(claim); milestones.append(claim)
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
func _mutating() -> bool:
	return client!=null and client.busy and client.status!="refreshing"
func _confirmed_view() -> bool:
	return client!=null and not client.snapshot.is_empty() and client.status in ["connected","refreshing","sending_action","waiting_for_ad_verification"]
func _ad_pending() -> bool: return client!=null and client.has_method("ad_waiting") and bool(client.call("ad_waiting"))
func _submit(action: Dictionary) -> void:
	if client==null or _presenting(): return
	if client.busy:
		if client.status=="refreshing" and _queued_action.is_empty() and not _queued_ad: _queued_action=action.duplicate(true);_refresh()
		return
	if action.get("kind")=="roll": dice_view.start()
	_active_action=action.duplicate(true)
	if client.submit(action):
		if action.get("kind") == "milestone": _pending_milestone = int(action.get("milestone",0))
		if not ((_modal_kind=="missions" and action.get("kind") in ["mission","task","missions_all"]) or (_modal_kind=="battle" and action.get("kind")=="arena_finish")): _close_modal()
	else:
		_active_action={}
		if action.get("kind")=="roll": dice_view.cancel()
func _process(delta: float) -> void:
	if client!=null and not client.busy and not _presenting():
		if not _queued_action.is_empty():
			var queued: Dictionary=_queued_action;_queued_action={};_submit(queued)
		elif _queued_ad: _queued_ad=false;_watch_ad()
	if not _arena_submit_pending.is_empty() and client!=null and not client.busy:
		var action: Dictionary=_arena_submit_pending;_arena_submit_pending={};_submit(action)
	if client!=null and not client.busy and client.status in ["NETWORK_UNAVAILABLE","REQUEST_TIMEOUT","connection_timeout","BACKEND_NOT_READY","BUSY"] and _retry_count<3 and Time.get_ticks_msec()>=_retry_at:
		_retry_count+=1; _retry_at=Time.get_ticks_msec()+4000*(1<<_retry_count); client.refresh()
	if _modal_kind == "battle" and is_instance_valid(_battle_timer) and not is_instance_valid(_arena):
		var battle: Dictionary = client.snapshot.get("state",{}).get("battle",{})
		var now: int = int(client.server_time())
		var counter_open: bool = now >= int(battle.get("opens_at",0))
		var left: int = int(battle.get("deadline",0)) - now
		_battle_timer.text = "GUARDIAN WINDUP…" if not counter_open else "COUNTER WINDOW · %ds" % maxi(0,left) if left >= 0 else "WINDOW MISSED · TAP A STANCE TO CONTINUE"
		for action: Button in _battle_buttons:
			if is_instance_valid(action): action.disabled = _mutating() or not counter_open
	_ad_feedback_clock+=delta
	if _ad_feedback_clock>=1.0:
		_ad_feedback_clock=0.0;_refresh_ad_control()
	_show_ad_reward_notice()
	_clock += delta
	if _clock >= 1.0:
		_clock=0;_update_time()
		if client!=null and not client.busy and client.status=="connected" and client.snapshot.get("event") is Dictionary:
			var event: Dictionary=client.snapshot.event
			if bool(event.get("enabled",false)) and client.server_time()>=int(event.starts_at) and client.server_time()<int(event.ends_at) and str(client.snapshot.get("state",{}).get("day",""))!=Time.get_datetime_string_from_unix_time(int(client.server_time())).substr(0,10): client.refresh()
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
	if client.status=="connected": _retry_count=0; _retry_at=Time.get_ticks_msec()+4000
	_update_mission_handles()
	_refresh_shop_products()
	var state: Dictionary = client.snapshot.get("state", {})
	if _modal_kind=="battle" and is_instance_valid(_arena) and not state.get("battle") is Dictionary: _close_modal()
	var event: Dictionary = client.snapshot.get("event", {}) if client.snapshot.get("event") is Dictionary else {}
	var active: bool = bool(event.get("enabled",false)) and int(client.server_time()) >= int(event.get("starts_at",0)) and int(client.server_time()) < int(event.get("ends_at",0))
	var binding: String=str(client.snapshot.get("owner_binding",""))+":"+str(event.get("id",""))
	if binding!=_presentation_binding:
		_presentation_binding=binding; _queued_action={};_queued_ad=false; _reveal_pending=false; _presentation_pending={}; observed_rolls=-1; _reward_identity=""; _pending_milestone=0
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
	var claim_open: bool=bool(event.get("enabled",false)) and client.server_time()>=int(event.get("starts_at",0)) and client.server_time()<int(event.get("ends_at",0))+3*86400
	roll.disabled=_mutating() or not _confirmed_view() or travelling or (not active and not (resolving and claim_open)) or (int(state.get("tickets",0))<1 and not resolving)
	ad.disabled = _mutating() or _ad_pending() or client.snapshot.get("state",{}).get("ad_delivery",client.snapshot.get("ad_delivery",{})).get("configured",true)==false or not _confirmed_view() or travelling or not active or not bool(event.get("ads_enabled",false)) or int(state.get("daily_ads",0)) >= 2
	ad.text = "VERIFIKASI HADIAH…" if _ad_pending() else "+1 DIE · AD %d/2" % int(state.get("daily_ads",0))
	_refresh_ad_control()
	buy.disabled = travelling
	for i: int in range(milestones.size()):
		var n: int = [24,48,72][i]; var claimed: bool = n in state.get("milestones",[])
		milestones[i].text = "%d · %s" % [n, "CLAIMED" if claimed else "CLAIM" if count>=n else "2 SEALS" if n==24 else "3 SEALS" if n==48 else "COMPASS"]
		milestones[i].disabled = travelling
	notice.text = str(state.get("notice","Connect Google to begin your journey.")) if client.status in ["connected","sending_action","refreshing"] else {"NETWORK_UNAVAILABLE":"Connection failed. Tap Reconnect; your progress is saved.","ENDPOINT_POLICY_REJECTED":"App update required. Install the latest Play build.","native_update_required":"App update required. Install the latest Play build.","ACCOUNT_HELD":"A refunded purchase requires review. Contact support.","BACKEND_NOT_READY":"Server is preparing the event. Please retry shortly."}.get(str(client.status),str(client.status).replace("_"," ").capitalize())
	if client.busy and client.status=="sending_action": notice.text="MENGIRIM AKSI…"
	elif client.has_method("ad_feedback") and not str(client.call("ad_feedback")).is_empty(): notice.text=str(client.call("ad_feedback"))
	if not _queued_action.is_empty() or _queued_ad: notice.text="Aksi diantrekan · menyelesaikan sinkronisasi"
	if travelling: notice.text="THE DIE IS REVEALING…" if _reveal_pending else "ROLLED %d · LIN YUE IS TRAVELLING" % dice
	roll.text="ROLLING…" if client.busy and dice_view.rolling else "TRAVELLING…" if travelling else "CONTINUE THE GATE" if state.get("battle") is Dictionary else "CHOOSE YOUR PATH" if state.get("pending","")=="route" else "ROLL DICE · 1 DIE"
	buy.text="TRAVEL SHOP"
	missions_button.disabled=travelling or not active
	var mission_ready: bool=false
	for n: int in [1,3,5]:
		if int(state.get("daily_rolls",0))>=n and n not in state.get("missions",[]): mission_ready=true
	mission_ready=mission_ready or (int(state.get("daily_gifts",0))>=3 and "gifts" not in state.get("task_claims",[])) or (int(state.get("daily_guardians",0))>=1 and "guardian" not in state.get("task_claims",[]))
	missions_button.text="MISSIONS · CLAIM" if mission_ready else "DAILY MISSIONS"
	if not client.busy and not travelling and dice_view.rolling: dice_view.cancel()
	_update_time()
	if modal == null and not client.busy and not travelling:
		if state.get("battle") is Dictionary: _battle()
		elif state.get("pending", "") == "route": _routes()

func _finished(action: String, success: bool) -> void:
	_active_action={}
	if not success and action=="roll": dice_view.cancel()
	if success and action in ["mission","task","missions_all","buy_dice","route","counter","arena_finish"]: _show_reward()
	if action == "milestone":
		if success and _pending_milestone == 72: _ceremony()
		elif success: _show_reward()
		_pending_milestone = 0
func _close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null; _modal_kind = ""; _card_sequence=0; _battle_buttons.clear(); _battle_timer = null; _mission_handles.clear(); _mission_all=null; _modal_panel=null; _modal_header=null; _modal_footer=null; _modal_body=null; _shop_handles.clear(); _shop_message=null; _arena=null
func _fit_popup() -> void:
	if not is_instance_valid(_modal_panel): return
	var span: Vector2 = safe.size
	var width: float = maxf(220,minf(span.x-28,580))
	var cap: float = minf(span.y-36,820 if _modal_kind in ["shop","missions"] else 680)
	_modal_panel.size.x = width
	var header_height: float = 96 if span.y > 600 else 68
	if is_instance_valid(_modal_header): _modal_header.custom_minimum_size.y = header_height
	var natural: float = header_height + 80
	if is_instance_valid(_modal_body): natural += _modal_body.get_combined_minimum_size().y
	if is_instance_valid(_modal_footer): natural += _modal_footer.get_combined_minimum_size().y
	_modal_panel.size = Vector2(width,minf(cap,maxf(header_height+180,natural)))
	_modal_panel.position = (span-_modal_panel.size)*0.5
func _popup(title: String, kind: String) -> VBoxContainer:
	_close_modal(); _modal_kind=kind
	modal=Control.new();modal.z_index=20;safe.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim:=ColorRect.new();dim.color=Color(0.002,0.01,0.02,0.68);modal.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_panel=Panel.new();_modal_panel.name="OdysseyFlowPanel";_modal_panel.clip_contents=true;_modal_panel.add_theme_stylebox_override("panel",Flow.style(4));modal.add_child(_modal_panel)
	var inset:=MarginContainer.new();_modal_panel.add_child(inset);inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right"]: inset.add_theme_constant_override("margin_"+side,24)
	for side: String in ["top","bottom"]: inset.add_theme_constant_override("margin_"+side,28)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);inset.add_child(column)
	_modal_header=Control.new();_modal_header.clip_contents=true;column.add_child(_modal_header)
	var banner:=TextureRect.new();banner.texture=Flow.texture(0 if kind=="missions" else 1 if kind in ["shop","confirm_pack"] else 2);banner.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;banner.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;_modal_header.add_child(banner);banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade:=ColorRect.new();shade.color=Color(0.006,0.05,0.045,0.78);_modal_header.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);shade.offset_top=-62
	var heading: Label=label(title,27);heading.add_theme_font_override("font",FONT);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;shade.add_child(heading);heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);heading.offset_left=12;heading.offset_right=-12
	var close: Button=_navigation("close",_close_modal,"Close");close.custom_minimum_size=Vector2(52,52);_modal_header.add_child(close);close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);close.offset_left=-56;close.offset_right=-4;close.offset_top=4;close.offset_bottom=56
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;scroll.scroll_deadzone=12;column.add_child(scroll)
	var body:=VBoxContainer.new();_modal_body=body;body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10);scroll.add_child(body)
	_modal_footer=VBoxContainer.new();column.add_child(_modal_footer)
	_fit_popup();_fit_popup.call_deferred()
	if not Art.reduced(self):
		_modal_panel.modulate.a=0.0
		_modal_motion=create_tween();_modal_motion.tween_property(_modal_panel,"modulate:a",1.0,0.18)
	if not safe.resized.is_connected(_fit_popup): safe.resized.connect(_fit_popup)
	return body
func _info() -> void:
	var body: VBoxContainer=_popup("THE CELESTIAL ATLAS","info")
	var limits: Dictionary=client.snapshot.get("limits",{}) if client!=null else {}
	body.add_child(label("FREE DAILY JOURNEYS",19)); body.add_child(label("3 dice arrive on daily login. Roll 1, 3 and 5 times to claim 3 more from Missions. Reset: 00:00 UTC (07:00 WIB).",16))
	body.add_child(label("OPTIONAL DICE",19)); body.add_child(label("2 verified ad dice per day. Purchased Jade: 1 die for %d or 5 dice for %d. Limit 10 bought per day and 40 per season. Every face has a 1 in 6 chance." % [int(limits.get("price_one",10)),int(limits.get("price_five",40))],16))
	body.add_child(label("CHOOSE YOUR PATH",19)); body.add_child(label("Quiet Grove grants peaceful supplies. Dragon Gate opens a free-movement arena. Move with the joystick, avoid marked attacks and stay in range for automatic sword strikes. The server verifies the movement replay before granting rewards.",16))
	body.add_child(label("GUARANTEED MILESTONES",19)); body.add_child(label("24 journeys: 2 Pavilion Seals.\n48: 3 Pavilion Seals + 500 Spirit Stones.\n72: one Heavenweaver Compass, secured in Mail.\nYou have 3 days after the season to claim reached milestones. Unused dice expire.",16))
func _mission_row(body: VBoxContainer, caption: String, target: int, kind: String, key: Variant, reward: String, icon: Texture2D) -> void:
	var card:=Flow.card();body.add_child(card);var content:=VBoxContainer.new();content.add_theme_constant_override("separation",6);card.add_child(content)
	var heading: Label=Flow.text(caption,19);content.add_child(heading)
	var meter:=ProgressBar.new();meter.max_value=target;meter.show_percentage=false;meter.custom_minimum_size.y=8;Flow.progress(meter);content.add_child(meter)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);content.add_child(row);row.add_child(_icon(icon,40))
	var count: Label=Flow.text(reward,20);row.add_child(count)
	var claim: Button=Flow.button("",func() -> void:
		if kind=="login": return
		_submit({"kind":"mission","mission":int(key)} if kind=="roll" else {"kind":"task","task":str(key)}))
	content.add_child(claim)
	_mission_handles.append({"kind":kind,"key":key,"target":target,"meter":meter,"button":claim,"heading":heading,"caption":caption})
func _update_mission_handles() -> void:
	if client==null: return
	var state: Dictionary=client.snapshot.get("state",{});var any_ready: bool=false
	for handle: Dictionary in _mission_handles:
		var progress_value: int=int(state.get("daily_rolls",0)) if handle.kind=="roll" else int(state.get("daily_gifts",0)) if handle.key=="gifts" else int(state.get("daily_guardians",0)) if handle.key=="guardian" else 1 if not str(state.get("day","")).is_empty() else 0
		var claimed: bool=int(handle.key) in state.get("missions",[]) if handle.kind=="roll" else str(handle.key) in state.get("task_claims",[]) if handle.kind=="task" else progress_value==1
		var claim_available: bool=progress_value>=int(handle.target) and not claimed
		handle.meter.value=mini(progress_value,int(handle.target));handle.heading.text="%s  ·  %d/%d" % [handle.caption,mini(progress_value,int(handle.target)),int(handle.target)]
		handle.button.text="DITERIMA" if claimed and handle.kind=="login" else "DIKLAIM" if claimed else "MENGIRIM…" if _mutating() and _active_action.get("kind")==("mission" if handle.kind=="roll" else "task") and _active_action.get("mission" if handle.kind=="roll" else "task")==handle.key else "KLAIM" if claim_available else "LANJUTKAN"
		handle.button.disabled=_mutating() or claimed or not claim_available or not _confirmed_view()
		handle.button.add_theme_stylebox_override("disabled",Flow.style(5 if claimed else 4,true))
		any_ready=any_ready or claim_available
	if is_instance_valid(_mission_all): _mission_all.disabled=not any_ready or _mutating() or not _confirmed_view();_mission_all.text="MENGIRIM…" if _mutating() and _active_action.get("kind")=="missions_all" else "KLAIM TERSEDIA"
func _missions() -> void:
	var body: VBoxContainer=_popup("DAILY MISSIONS","missions")
	var hint: Label=label("RESET 07.00 WIB · Hadiah tambahan masuk Mailbox",14);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(hint)
	_mission_row(body,"Masuk hari ini",1,"login","login","+3 Dadu",Art.DIE)
	for n: int in [1,3,5]: _mission_row(body,"Lakukan %d perjalanan" % n,n,"roll",n,"+1 Dadu",Art.DIE)
	var stone: Texture2D=preload("res://assets/ui/shared/resources/spirit_stone_premium.png")
	_mission_row(body,"Kunjungi petak hadiah",3,"task","gifts","+30 Stones",stone)
	_mission_row(body,"Selesaikan Gerbang Naga",1,"task","guardian","+60 Stones",stone)
	_mission_all=Flow.button("KLAIM TERSEDIA",func() -> void: _submit({"kind":"missions_all"}));_modal_footer.add_child(_mission_all);_update_mission_handles()
func _shop() -> void:
	if client==null or _presenting(): return
	var body: VBoxContainer=_popup("TRAVEL SHOP","shop")
	_shop_handles.clear()
	_shop_message = label("Harga langsung dari Google Play",15)
	body.add_child(_shop_message)
	PavilionManager.refresh_iap_store_products()
	var bonus: Dictionary=client.snapshot.get("purchase_bonus",{})
	var hint: Label=label("Jade + bonus dadu · Sekali per paket per season",15);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(hint)
	var offers: Array = bonus.get("offers",[]).duplicate(true)
	if offers.is_empty():
		var catalog: Dictionary = PavilionManager.get_iap_product_catalog()
		for product_id: String in catalog:
			var product: Dictionary = catalog[product_id]
			if str(product.get("type","")) == "consumable": offers.append({"product_id":product_id,"jade":int(product.get("celestial_jade",0)),"dice":0,"claimed":false,"bonus_unknown":true})
		offers.sort_custom(func(left: Dictionary,right: Dictionary) -> bool: return int(left.jade) < int(right.jade))
	if not offers.is_empty():
		for offer: Dictionary in offers:
			var card:=Flow.card();body.add_child(card);var content:=VBoxContainer.new();content.add_theme_constant_override("separation",6);card.add_child(content)
			var pack_title: Label = Flow.text("",19,true); content.add_child(pack_title)
			var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);content.add_child(row)
			row.add_child(_icon(preload("res://assets/ui/shared/resources/celestial_jade_premium.png"),40));row.add_child(Flow.text(str(int(offer.jade)),18));row.add_child(_icon(Art.DIE,40));row.add_child(Flow.text("+%d" % int(offer.dice),18))
			var buy_pack: Button=Flow.button("MEMUAT HARGA…",_purchase_shop_pack.bind(str(offer.product_id)));content.add_child(buy_pack)
			var eligibility: Label = Flow.text("",14)
			content.add_child(eligibility)
			_shop_handles.append({"product_id":str(offer.product_id),"button":buy_pack,"eligibility":eligibility,"offer":offer.duplicate(true),"title":pack_title,"dice_icon":row.get_child(2),"dice_amount":row.get_child(3)})
			if bool(offer.claimed): content.add_child(Flow.text("Bonus season ini sudah diterima. Pembelian berikutnya hanya Jade.",14))
	else:
		var card:=Flow.card();body.add_child(card);card.add_child(Flow.text("Katalog belum tersedia. Sambungkan akun lalu buka kembali toko.",17))
	var exchange:=Flow.card();body.add_child(exchange);var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);exchange.add_child(box);box.add_child(Flow.text("TUKAR PURCHASED JADE",19,true))
	var state: Dictionary=client.snapshot.get("state",{});var event: Dictionary=client.snapshot.get("event",{}) if client.snapshot.get("event") is Dictionary else {}
	var paid: Node=get_node_or_null("/root/PavilionManager/PaidGameplayV2");var balance: int=int(paid.call("paid_balance")) if paid!=null else 0
	box.add_child(Flow.text("Saldo: %d · Hari ini %d/10 · Season %d/40" % [balance,int(state.get("daily_bought",0)),int(state.get("season_bought",0))],15))
	var limits: Dictionary=client.snapshot.get("limits",{})
	var exchange_ready: bool=not _mutating() and _confirmed_view() and bool(event.get("enabled",false)) and bool(event.get("purchases_enabled",false)) and client.server_time()>=int(event.get("starts_at",0)) and client.server_time()<int(event.get("ends_at",0)) and int(state.get("rolls",0))<152
	for pack: int in [1,5]:
		var price: int=int(limits.get("price_one" if pack==1 else "price_five",10 if pack==1 else 40))
		var action: Button=Flow.button("%d Dadu · %d Jade" % [pack,price],_confirm_pack.bind(pack,price));action.disabled=not exchange_ready or balance<price or int(state.get("daily_bought",0))+pack>10 or int(state.get("season_bought",0))+pack>40;box.add_child(action)
	_refresh_shop_products()
	var footer: Label=label("Bonus setelah verifikasi server. Maksimal 152 perjalanan; dadu tidak terpakai kedaluwarsa. Satu Compass per season.",14);footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(footer)
func _refresh_shop_products(_products: Variant = null) -> void:
	if _modal_kind != "shop" or not is_instance_valid(_modal_panel): return
	var products: Dictionary = PavilionManager.get_iap_store_products()
	var readiness: Dictionary = PavilionManager.get_paid_delivery_readiness()
	var offers: Array = client.snapshot.get("purchase_bonus",{}).get("offers",[]) if client != null else []
	for entry: Dictionary in _shop_handles:
		if not is_instance_valid(entry.button): continue
		var info: Dictionary = products.get(entry.product_id,{})
		var price: String = str(info.get("formatted_price","")).strip_edges() if int(info.get("price_amount_micros",0)) > 0 else ""
		var offer: Dictionary = entry.offer
		for latest: Dictionary in offers:
			if str(latest.product_id) == str(entry.product_id): offer = latest; break
		var active_bonus: bool = client != null and client.purchase_bonus_active() and not bool(offer.get("bonus_unknown",false))
		var included: bool = active_bonus and not bool(offer.get("claimed",false)) and int(offer.get("dice",0)) > 0
		entry.title.text = "%d Jade + %d Dadu" % [int(offer.jade),int(offer.dice)] if included else "%d Celestial Jade" % int(offer.jade)
		entry.dice_icon.visible = included
		entry.dice_amount.visible = included
		entry.eligibility.text = tr("Bonus dadu sudah diklaim · pembelian ini hanya Jade") if bool(offer.get("claimed",false)) else tr("+%d bonus dadu · sekali per season") % int(offer.get("dice",0)) if active_bonus else tr("Bonus dadu belum terkonfirmasi · paket ini hanya Jade")
		entry.button.disabled = _shop_busy or price.is_empty() or not bool(readiness.ready) or not PavilionManager.is_iap_purchase_supported(str(entry.product_id))
		entry.button.text = tr("MEMPROSES…") if _shop_busy and _shop_product == str(entry.product_id) else tr("BELI · ") + price if not price.is_empty() else tr("HARGA BELUM TERSEDIA")
	if is_instance_valid(_shop_message) and not bool(readiness.ready):
		_shop_message.text = tr("Akun perlu peninjauan refund") if str(readiness.get("reason","")) == "account_held" else tr("Menunggu verifikasi wallet · harga Play tetap ditampilkan")

func _purchase_shop_pack(product_id: String) -> void:
	if _shop_busy: return
	var product: Dictionary = PavilionManager.get_iap_store_products().get(product_id,{})
	if int(product.get("price_amount_micros",0)) <= 0 or str(product.get("formatted_price","")).is_empty() or not PavilionManager.is_iap_purchase_supported(product_id): return
	_shop_busy = true; _shop_product = product_id
	if is_instance_valid(_shop_message): _shop_message.text = tr("Membuka Google Play…")
	_refresh_shop_products()
	if not PavilionManager.purchase_iap(product_id): _shop_busy = false; _shop_product = ""; _refresh_shop_products()

func _shop_purchase_state(product_id: String, state: String, message: String) -> void:
	if _shop_product.is_empty() or product_id != _shop_product: return
	if state in ["opening","verification_required","verification_in_progress","verification_deferred","recovery_deferred"]: _shop_busy = true
	else: _shop_busy = false
	if is_instance_valid(_shop_message): _shop_message.text = tr(message)
	if state in ["delivered","wallet_credited"] and client != null and not client.busy: client.refresh()
	_refresh_shop_products()

func _shop_delivery_finished(product_id: String, success: bool, message: String) -> void:
	if product_id != _shop_product: return
	_shop_busy = false
	if is_instance_valid(_shop_message): _shop_message.text = tr("PEMBELIAN TERVERIFIKASI · JADE TERSIMPAN") if success else tr(message)
	if success and client != null and not client.busy: client.refresh()
	_refresh_shop_products()

func _confirm_pack(pack: int, price: int) -> void:
	var body: VBoxContainer=_popup("CONFIRM YOUR JOURNEY","confirm_pack")
	body.add_child(_icon(Art.DIE,110)); body.add_child(label("%d travel %s for %d Purchased Jade." % [pack,"die" if pack==1 else "dice",price],22))
	body.add_child(label("The server charges once. Extra dice do not change die odds or grant extra Compass copies.",16))
	body.add_child(button("CONFIRM · %d JADE" % price,func() -> void: _submit({"kind":"buy_dice","pack":pack}),true)); body.add_child(button("BACK TO PACKS",_shop))
func _journey_rewards() -> void:
	var body: VBoxContainer=_popup("JOURNEY REWARDS","journey")
	var state: Dictionary=client.snapshot.get("state",{});var count: int=int(state.get("rolls",0))
	var title: Label=label("%d / 72 PERJALANAN" % count,22);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(title)
	var meter:=ProgressBar.new();meter.max_value=72;meter.value=mini(count,72);meter.custom_minimum_size.y=12;meter.show_percentage=false;body.add_child(meter)
	for n: int in [24,48,72]:
		var card:=Flow.card();body.add_child(card);var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);card.add_child(content)
		content.add_child(Flow.text("%d PERJALANAN" % n,21,true))
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);content.add_child(row);row.add_child(_icon(COMPASS if n==72 else preload("res://assets/ui/shared/resources/pavilion_seal_premium.png"),64));row.add_child(Flow.text("Heavenweaver Compass
★★★★★" if n==72 else "2 Pavilion Seals" if n==24 else "3 Seals + 500 Stones",19))
		var claimed: bool=n in state.get("milestones",[])
		var event: Dictionary=client.snapshot.get("event",{}) if client.snapshot.get("event") is Dictionary else {}
		var claim_open: bool=bool(event.get("enabled",false)) and client.server_time()>=int(event.get("starts_at",0)) and client.server_time()<int(event.get("ends_at",0))+3*86400
		var claim: Button=Flow.button("DIKLAIM" if claimed else "KLAIM" if count>=n else "BELUM TERCAPAI",func() -> void: _submit({"kind":"milestone","milestone":n}));claim.disabled=claimed or count<n or _mutating() or not _confirmed_view() or not claim_open;content.add_child(claim)
	var footer: Label=label("Hadiah dikirim ke Mailbox · Masa klaim 3 hari setelah season",14);footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.add_child(footer)
func _routes() -> void:
	if not ResourceLoader.has_cached(ARENA_PATH): ResourceLoader.load_threaded_request(ARENA_PATH)
	var body: VBoxContainer = _popup("CHOOSE YOUR PATH","route")
	for choice: String in ["safe","challenge"]:
		var card: PanelContainer = Flow.card()
		body.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",8)
		card.add_child(content)
		var scene := TextureRect.new()
		scene.texture = preload("res://assets/ui/liveops/event_identity/pilgrimage.png") if choice == "safe" else preload("res://assets/ui/liveops/event_identity/boss_hunt.png")
		scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		scene.custom_minimum_size.y = 82
		content.add_child(scene)
		content.add_child(Flow.text("Quiet Grove · 30 Spirit Stones" if choice == "safe" else "Dragon Gate · 60 Spirit Stones",20,true))
		content.add_child(Flow.text("Safe passage, guaranteed supplies." if choice == "safe" else "Move freely. Dodge the guardian and strike within sword range.",15))
		var action: Button = Flow.button("TAKE THE QUIET PATH" if choice == "safe" else "ENTER THE ARENA",_submit.bind({"kind":"route","choice":choice}))
		action.name = "RouteChoiceSafe" if choice == "safe" else "RouteChoiceChallenge"
		content.add_child(action)
	_fit_popup.call_deferred()
func _battle() -> void:
	var battle: Dictionary = client.snapshot.get("state",{}).get("battle",{})
	if battle.get("mode","")=="arena":
		_close_modal();_modal_kind="battle"
		modal=Control.new();modal.z_index=20;safe.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var arena_script: GDScript=load(ARENA_PATH);_arena=arena_script.new();_arena.client=client;_arena.battle=battle.duplicate(true);modal.add_child(_arena);_arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_arena.completed.connect(func(trace: String,abandon: bool) -> void:
			var action: Dictionary={"kind":"arena_finish","trace":trace,"abandon":abandon}
			if client.busy: _arena_submit_pending=action
			else: _submit(action))
		return
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

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: _app_focused=false
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN: _app_focused=true
func _refresh_ad_control() -> void:
	if client==null or not is_instance_valid(ad) or not client.has_method("ad_control"): return
	var control: Dictionary=client.call("ad_control")
	ad.text=str(control.get("text","IKLAN DISIAPKAN…"))
	var event: Dictionary=client.snapshot.get("event",{}) if client.snapshot.get("event") is Dictionary else {}
	var active: bool=bool(event.get("enabled",false)) and client.server_time()>=int(event.get("starts_at",0)) and client.server_time()<int(event.get("ends_at",0))
	ad.disabled=not bool(control.get("enabled",false)) or _mutating() or not _confirmed_view() or _presenting() or not active or not bool(event.get("ads_enabled",false))
func _show_ad_reward_notice() -> void:
	if not _app_focused or client==null or not client.has_method("get_ad_reward_notice"): return
	var manager: Node=get_node_or_null("/root/MonetizationManager")
	if manager!=null and manager.has_method("is_rewarded_request_active") and bool(manager.call("is_rewarded_request_active","odyssey_roll")): return
	var data: Dictionary=client.call("get_ad_reward_notice")
	if data.is_empty() or data.get("owner")!=client.snapshot.get("owner_binding") or data.get("event_id")!=client.snapshot.get("event",{}).get("id") or data.get("amount")!=1: return
	var toast: Control=preload("res://scripts/ui/liveops/odyssey_ad_reward_notice.gd").new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	var width: float=minf(480.0,maxf(240.0,safe.size.x-32.0));toast.offset_left=-width*0.5;toast.offset_right=width*0.5;toast.offset_top=110.0;toast.offset_bottom=260.0;toast.z_index=40
	safe.add_child(toast)
	client.call("acknowledge_ad_reward_notice",str(data.key))
