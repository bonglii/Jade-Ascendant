extends Control
## Approved weekly hub. Visual state reads the verified client; buttons never grant.
const Style=preload("res://scripts/ui/liveops/event_hub_style.gd")
const Scroll=preload("res://scripts/ui/mobile_scroll_policy.gd")
const ART=preload("res://assets/ui/heavenly_trials/jade_gate.png")
const ICONS: Dictionary={"celestial_jade":preload("res://assets/ui/shared/resources/celestial_jade_premium.png"),"pavilion_seal":preload("res://assets/ui/shared/resources/pavilion_seal_premium.png"),"spirit_stone":preload("res://assets/ui/shared/resources/spirit_stone_premium.png")}
const RULES: Dictionary={"jade_wind":["JADE WIND","Wind seals mark your last position. Keep moving."],"scarlet_rite":["SCARLET RITE","Scarlet marks erupt twice. Leave the marked ground."],"starfall":["STARFALL","A star seal marks your position before it bursts."],"froststep":["FROSTSTEP","Frost seals linger before they burst. Choose a clear path."],"sunforge":["SUNFORGE","Solar marks cover a wider area. Move before they ignite."]}
var client: Node
var _title: Label
var _time: Label
var _rule: Label
var _note: Label
var _entry: Button
var _rewards: Button
var _tiers: Array[Dictionary]=[]
var _selected: int=1
var _modal: Control
var _modal_kind: String=""
var _navigating: bool=false
var _elapsed: float=0
var _continue_waiting: bool=false
var _portrait_key: String=""
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS;client=get_node_or_null("/root/HeavenlyTrialsClient")
 _build();_refresh()
 if client!=null:
  client.connect("changed",_refresh);client.connect("finished",_finished);client.call("refresh")
 SceneTransitionManager.set_back_handler(_back)
 if client!=null and not client.last_result.is_empty():call_deferred("_open_rewards")
func _label(text: String,size_px: int,color: Color=Style.TEXT,display: bool=false) -> Label:
 var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",size_px);label.add_theme_color_override("font_color",color)
 if display:label.add_theme_font_override("font",Style.DISPLAY)
 return label
func _margin(parent: Node,amount: int=18) -> MarginContainer:
 var margin:=MarginContainer.new()
 for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,amount)
 parent.add_child(margin);return margin
func _panel(parent: Node,edge: Color=Style.GOLD) -> PanelContainer:
 var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",Style.panel(Color(.018,.10,.08,.96),edge,14));parent.add_child(panel);return panel
func _button(parent: Node,text: String,callback: Callable,primary: bool=false) -> Button:
 var button:=Button.new();button.text=text;button.custom_minimum_size=Vector2(0,56);button.add_theme_font_size_override("font_size",18);Style.button(button,primary);parent.add_child(button);button.pressed.connect(callback);return button
func _rewards_row(parent: Node,reward: Dictionary) -> void:
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);parent.add_child(row)
 for key: String in ICONS:
  if int(reward.get(key,0))<=0:continue
  var group:=HBoxContainer.new();group.add_theme_constant_override("separation",4);row.add_child(group)
  var icon:=TextureRect.new();icon.texture=ICONS[key];icon.custom_minimum_size=Vector2(30,30);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=MOUSE_FILTER_IGNORE;group.add_child(icon)
  var amount: Label=_label(str(int(reward[key])),20,Style.CREAM);amount.autowrap_mode=TextServer.AUTOWRAP_OFF;group.add_child(amount)
func _build() -> void:
 var background:=TextureRect.new();background.texture=ART;background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;background.set_anchors_and_offsets_preset(PRESET_FULL_RECT);background.mouse_filter=MOUSE_FILTER_IGNORE;background.modulate=Color(.32,.45,.39);add_child(background)
 var margin: MarginContainer=_margin(self,20);margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",14);margin.add_child(body)
 var header:=HBoxContainer.new();header.add_theme_constant_override("separation",12);body.add_child(header)
 var back: Button=_button(header,"‹",_back);back.custom_minimum_size=Vector2(48,48);back.size_flags_vertical=SIZE_SHRINK_CENTER;back.add_theme_font_size_override("font_size",30)
 var headings:=VBoxContainer.new();headings.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(headings);headings.add_child(_label("CELESTIAL CHALLENGE",12,Style.JADE));headings.add_child(_label("HEAVENLY TRIALS",24,Style.CREAM,true))
 _time=_label("",14,Style.CREAM);body.add_child(_time)
 var scroll:=ScrollContainer.new();scroll.name="TrialsScroll";scroll.size_flags_vertical=SIZE_EXPAND_FILL;body.add_child(scroll);Scroll.configure(scroll)
 var list:=VBoxContainer.new();list.size_flags_horizontal=SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",14);scroll.add_child(list)
 var hero: PanelContainer=_panel(list);hero.name="WeeklyHero";hero.custom_minimum_size.y=210;hero.clip_contents=true
 var image:=TextureRect.new();image.texture=ART;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.set_anchors_and_offsets_preset(PRESET_FULL_RECT);image.mouse_filter=MOUSE_FILTER_IGNORE;hero.add_child(image)
 var portrait:=TextureRect.new();portrait.name="WeeklyBossPortrait";portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.mouse_filter=MOUSE_FILTER_IGNORE;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED

 portrait.anchor_left=.61;portrait.anchor_right=.96;portrait.anchor_top=.02;portrait.anchor_bottom=.78;hero.add_child(portrait)
 var gradient:=Gradient.new();gradient.set_color(0,Color(.01,.05,.035,0));gradient.set_color(1,Color(.01,.07,.045,.99));gradient.add_point(.45,Color(.01,.05,.035,.08));var tex:=GradientTexture2D.new();tex.gradient=gradient;tex.fill_from=Vector2(.5,0);tex.fill_to=Vector2(.5,1)
 var veil:=TextureRect.new();veil.texture=tex;veil.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;veil.set_anchors_and_offsets_preset(PRESET_FULL_RECT);veil.mouse_filter=MOUSE_FILTER_IGNORE;hero.add_child(veil)
 var hero_content:=VBoxContainer.new();hero_content.add_theme_constant_override("separation",4);_margin(hero,18).add_child(hero_content)
 var spacer:=Control.new();spacer.size_flags_vertical=SIZE_EXPAND_FILL;hero_content.add_child(spacer)
 var week_label: Label=_label("WEEKLY ASCENSION",12,Style.JADE);week_label.name="WeekEyebrow";hero_content.add_child(week_label);_title=_label("THE GATE AWAITS",30,Style.CREAM,true);hero_content.add_child(_title)
 hero_content.add_child(_label("Three trials. One path to mastery.",16,Style.TEXT))
 _rule=_label("Preparing the weekly challenge…",17,Style.CREAM);_margin(_panel(list,Color("60734b")),14).add_child(_rule)
 for tier: int in range(1,4):
  var panel: PanelContainer=_panel(list,Color("526c50"));panel.name="Tier%d"%tier
  var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);_margin(panel,14).add_child(row)
  var number: Label=_label(["I","II","III"][tier-1],32,Style.GOLD,true);number.custom_minimum_size.x=42;number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;row.add_child(number)
  var info:=VBoxContainer.new();info.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(info)
  info.add_child(_label(["Foundation","Tempering","Ascension"][tier-1],23,Style.CREAM,true));var state: Label=_label("Clear %d-5 to unlock"%tier,14,Style.MUTED);info.add_child(state)
  var choose: Button=_button(row,"SELECT",_select.bind(tier));choose.custom_minimum_size=Vector2(84,50);choose.size_flags_vertical=SIZE_SHRINK_CENTER;choose.autowrap_mode=TextServer.AUTOWRAP_OFF;choose.add_theme_font_size_override("font_size",14)
  _tiers.append({"state":state,"button":choose,"panel":panel})
 var rewards_panel:=VBoxContainer.new();rewards_panel.add_theme_constant_override("separation",8);_margin(_panel(list),16).add_child(rewards_panel)
 rewards_panel.add_child(_label("EACH TIER · FIRST WEEKLY CLEAR",12,Style.JADE));_rewards_row(rewards_panel,{"celestial_jade":40,"pavilion_seal":1,"spirit_stone":600})
 _note=_label("",15,Style.MUTED);list.add_child(_note)
 _entry=_button(body,"ENTER TRIAL",_enter,true)
 var footer:=HBoxContainer.new();footer.add_theme_constant_override("separation",10);body.add_child(footer)
 _rewards=_button(footer,"REWARDS",_open_rewards);_rewards.size_flags_horizontal=SIZE_EXPAND_FILL
 var shop: Button=_button(footer,"EVENT SHOP",_open_shop);shop.size_flags_horizontal=SIZE_EXPAND_FILL
 Scroll.prepare_tree(scroll)
func _process(delta: float) -> void:
 _elapsed+=delta
 if _elapsed>=1:_elapsed=0;_refresh()
var _disabled_exit: bool=false
func _refresh() -> void:
 if client!=null and client.status=="connected" and client.snapshot.has("campaign") and not client.event_enabled():
  if not _disabled_exit:_disabled_exit=true;call_deferred("_leave_disabled_event")
  return
 if not is_instance_valid(_entry):return
 var data: Dictionary=client.snapshot if client!=null else {};var week: Variant=data.get("week")
 var available: bool=client!=null and bool(client.call("is_available"));var busy: bool=client==null or bool(client.call("mutation_busy"))
 var unlocked: int=int(data.get("unlock_tier",0))
 if week is Dictionary:
  _refresh_portrait(_selected,int(week.stage))
  var rule: Array=RULES.get(str(week.theme),RULES.jade_wind);_title.text=str(rule[0]);find_child("WeekEyebrow",true,false).text="WEEK %02d · ASCENSION"%[int(week.index)+1];_rule.text=rule[1]
  var left: int=maxi(0,int(week.ends_at)-int(client.call("server_time")));_time.text="RESETS MON 04:00 WIB  ·  %dd %02dh LEFT"%[int(float(left)/86400.0),int(float(left%86400)/3600.0)]
 else:_time.text="WEEKLY RESET · MONDAY 04:00 WIB"
 for tier: int in range(1,4):
  var progress: Dictionary={}
  for row: Dictionary in data.get("progress",[]):
   if int(row.tier)==tier:progress=row
  var ui: Dictionary=_tiers[tier-1];var locked: bool=tier>unlocked
  ui.state.text="Clear %d-5 to unlock"%tier if locked else ("REWARD CLAIMED · Replay for mastery" if int(progress.get("claimed",0))==1 else "CLEARED · Reward ready" if int(progress.get("clears",0))>0 else "READY · Unlimited free attempts")
  ui.button.disabled=locked or not available or busy;ui.button.text="LOCK" if locked else "✓" if tier==_selected else "SELECT"
  ui.panel.modulate=Color.WHITE if tier==_selected else Color(.82,.88,.82)
 _entry.disabled=not available or busy or _selected>unlocked
 var session: Variant=data.get("session");_entry.text="CONTINUE TRIAL" if session is Dictionary else "ENTER TRIAL · FREE"
 _note.text="All rewards earned this week remain claimable for 48h after reset."
 if client!=null and str(client.status) not in ["connected","preparing"]:_note.text="Connection: "+str(client.status).replace("_"," ")+". Recovery runs automatically."
 if session is Dictionary:_note.text="A trial is in progress. Continue it or abandon it from Rewards."
 _rewards.text="REWARDS";preload("res://scripts/ui/action_ready_dot.gd").show_on(_rewards,int(client.call("ready_count")) if client!=null else 0)
func _refresh_portrait(tier: int,stage: int) -> void:
 var key: String="%d_%d"%[clampi(tier,1,3),clampi(stage,1,5)]
 if key==_portrait_key:return
 var portrait: TextureRect=find_child("WeeklyBossPortrait",true,false)
 var atlas: Texture2D=load("res://assets/enemy/boss_2d/atlas_"+key+".png")
 if atlas==null:return
 var cell:=Vector2i(int(float(atlas.get_width())/6.0),int(float(atlas.get_height())/6.0))
 var idle:=Rect2i(0,cell.y,cell.x,cell.y)
 var used: Rect2i=atlas.get_image().get_region(idle).get_used_rect()
 var tile:=AtlasTexture.new();tile.atlas=atlas;tile.region=Rect2(used.position+idle.position,used.size);tile.filter_clip=true
 portrait.texture=tile;_portrait_key=key
func _select(tier: int) -> void:_selected=tier;_refresh()
func _enter() -> void:
 if client==null or client.mutation_busy():return
 if SaveManager.has_save_file("checkpoint"):_note.text="Continue your Journey run first. Your saved stage will stay intact.";return
 if client.snapshot.get("session") is Dictionary:
  if client.busy:_continue_waiting=true;_note.text="Verifying your saved attempt…"
  else:client.call("launch",true)
 else:client.call("action","start",{"tier":_selected})
func _finished(kind: String,success: bool) -> void:
 if kind=="read" and success and _continue_waiting:
  _continue_waiting=false;client.call("launch",true)
 if kind=="start" and success:client.call("launch",false)
 if success and kind=="finish":_open_rewards();return
 if success and not _modal_kind.is_empty():
  var old: String=_modal_kind;_close_modal()
  if old=="rewards":_open_rewards()
  elif old=="shop":_open_shop()
func _modal_body(title: String,kind: String) -> VBoxContainer:
 _close_modal();_modal_kind=kind
 _modal=Control.new();_modal.set_anchors_and_offsets_preset(PRESET_FULL_RECT);_modal.z_index=40;add_child(_modal)
 var scrim:=ColorRect.new();scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT);scrim.color=Color(0,.015,.01,.82);_modal.add_child(scrim)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(PRESET_FULL_RECT);_modal.add_child(center)
 var panel: PanelContainer=_panel(center);panel.custom_minimum_size=Vector2(minf(size.x-32,560),minf(size.y-32,520 if kind=="shop" else 650))
 var outer:=VBoxContainer.new();outer.add_theme_constant_override("separation",14);_margin(panel,18).add_child(outer)
 var header:=HBoxContainer.new();outer.add_child(header);var label: Label=_label(title,27,Style.CREAM,true);label.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(label);_button(header,"×",_close_modal).custom_minimum_size.x=48
 var scroll:=ScrollContainer.new();scroll.name="TrialsModalScroll";scroll.size_flags_vertical=SIZE_EXPAND_FILL;outer.add_child(scroll);Scroll.configure(scroll)
 var body:=VBoxContainer.new();body.size_flags_horizontal=SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",16);scroll.add_child(body)
 return body
func _close_modal() -> void:
 if is_instance_valid(_modal):remove_child(_modal);_modal.queue_free()
 _modal=null
 _modal_kind=""
func _open_rewards() -> void:
 var outcome: Dictionary=client.last_result if client!=null else {}
 var heading: String="TRIAL CLEARED" if bool(outcome.get("won",false)) else "TRIAL COMPLETE" if not outcome.is_empty() else "WEEKLY REWARDS"
 var body: VBoxContainer=_modal_body(heading,"rewards")
 if not outcome.is_empty():
  if client!=null and client.mutation_busy():body.add_child(_label("Securing result with the server…",16,Style.JADE))
  var seconds: int=int(float(outcome.get("time_ms",0))/1000.0)
  body.add_child(_label("TIER %d · %02d:%02d"%[int(outcome.tier),int(float(seconds)/60.0),seconds%60],18,Style.GOLD))
  if not bool(outcome.get("won",false)):body.add_child(_label("Your Journey is safe. Return for another free attempt.",17,Style.TEXT))
 body.add_child(_label("CLEAR · SURVIVOR · UNTOUCHED",16,Style.GOLD))
 body.add_child(_label("Medals celebrate your best run. Every clear earns the same tier reward, once per week.",16))
 _rewards_row(body,{"celestial_jade":40,"pavilion_seal":1,"spirit_stone":600})
 if client==null:return
 for row: Dictionary in client.snapshot.get("progress",[]):
  var medals: String="CLEAR"+(" · SURVIVOR" if int(row.survivor)==1 else "")+(" · UNTOUCHED" if int(row.untouched)==1 else "")
  body.add_child(_label("TIER %d  ·  %02d:%02d\n%s"%[int(row.tier),int(float(row.best_ms)/60000.0),(int(float(row.best_ms)/1000.0))%60,medals],17,Style.CREAM))
 var claim: Button=_button(body,"CLAIM EARNED REWARDS",_claim,true);claim.disabled=client.mutation_busy() or int(client.call("ready_count"))==0
 body.add_child(_label("Delivered securely to your mailbox. Optional ads add Stones only.",14,Style.MUTED))
 if bool(client.snapshot.get("ads_ready",false)):
  for row: Dictionary in client.snapshot.get("progress",[]):
   if int(row.get("claimed",0))==1 and int(row.get("bonus",0))==0:
    var ad: Button=_button(body,"WATCH AD · +600 STONES",_watch.bind(int(row.tier)))
    ad.disabled=client.mutation_busy() or str(client.ad_status) in ["watching","verifying_reward","delivery_pending"]
    break
  body.add_child(_label(str(client.ad_status).replace("_"," ").to_upper(),14,Style.JADE))
 if client.snapshot.get("session") is Dictionary:_button(body,"ABANDON CURRENT ATTEMPT",_abandon)
func _watch(tier: int) -> void:
 if client!=null:client.call("watch_bonus",tier)

func _claim() -> void:
 if client==null:return
 for row: Dictionary in client.snapshot.get("previous_progress",[]):
  if int(row.get("claimed",0))==0:client.call("action","claim_all",{},str(row.week));return
 client.call("action","claim_all")
func _abandon() -> void:
 if client!=null and client.snapshot.get("session") is Dictionary:client.call("action","abandon",{"session_id":str(client.snapshot.session.id)},str(client.snapshot.session.week))
func _open_shop() -> void:
 var body: VBoxContainer=_modal_body("TRIAL SUPPORT","shop")
 body.add_child(_label("OPTIONAL · FREE ENTRY ALWAYS",13,Style.JADE))
 var offer:=HBoxContainer.new();offer.add_theme_constant_override("separation",12);body.add_child(offer)
 var contents:=VBoxContainer.new();contents.size_flags_horizontal=SIZE_EXPAND_FILL;contents.add_theme_constant_override("separation",8);offer.add_child(contents)
 for key: String in ["celestial_jade","pavilion_seal"]:
  var line:=HBoxContainer.new();line.add_theme_constant_override("separation",6);contents.add_child(line)
  var icon:=TextureRect.new();icon.texture=ICONS[key];icon.custom_minimum_size=Vector2(24,24);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=MOUSE_FILTER_IGNORE;line.add_child(icon)
  var count_label: Label=_label("550 Jade" if key=="celestial_jade" else "+2 Seals",18,Style.CREAM);count_label.autowrap_mode=TextServer.AUTOWRAP_OFF;line.add_child(count_label)
 var pavilion: Node=get_node_or_null("/root/PavilionManager");var product: Dictionary=pavilion.call("get_iap_store_products").get("heavenly_trials_support_550",{}) if pavilion!=null else {}
 var price: String=str(product.get("formatted_price","")) if int(product.get("price_amount_micros",0))>0 else ""
 var purchase_column:=VBoxContainer.new();purchase_column.add_theme_constant_override("separation",8);purchase_column.size_flags_vertical=SIZE_SHRINK_CENTER;offer.add_child(purchase_column)
 var price_label: Label=_label(price if not price.is_empty() else "GOOGLE PLAY",14,Style.GOLD);price_label.name="TrialsPrice";price_label.autowrap_mode=TextServer.AUTOWRAP_OFF;price_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;purchase_column.add_child(price_label)
 var price_font: Font=price_label.get_theme_font("font")
 var font_px: int=14
 while font_px>10 and price_font.get_string_size(price_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_px).x>116:font_px-=1
 price_label.add_theme_font_size_override("font_size",font_px)
 var buy: Button=_button(purchase_column,"BUY" if not price.is_empty() else "OFFLINE",_buy,true)
 buy.custom_minimum_size=Vector2(116,56);buy.add_theme_font_size_override("font_size",15)
 buy.name="TrialsCheckout"
 buy.disabled=client==null or not client.is_available() or client.mutation_busy() or not bool(client.snapshot.get("shop_ready",false)) or bool(client.snapshot.get("pack_claimed",false)) or price.is_empty()
 body.add_child(_label("550 purchased Jade + 2 bonus Seals. Bonus summons use the server's paid inventory and refund protection.",17))
 body.add_child(_label("One weekly offer. Prices are supplied by Google Play; no estimated cash price.",14,Style.MUTED))
 if client!=null and int(client.snapshot.get("bonus_seals",0))>0:
  _button(body,"PAVILION · %d SEALS"%int(client.snapshot.bonus_seals),_bonus_summon)
func _buy() -> void:
 if client==null or not client.is_available() or not bool(client.snapshot.get("shop_ready",false)) or client.mutation_busy():return
 var pavilion: Node=get_node_or_null("/root/PavilionManager")
 if pavilion!=null and pavilion.call("purchase_iap","heavenly_trials_support_550"):
  var buy: Button=find_child("TrialsCheckout",true,false)
  if buy!=null:buy.disabled=true
func _bonus_summon() -> void:
 if _navigating:return
 _navigating=true
 SceneTransitionManager.transition_to("res://scenes/ui/pavilion_screen.tscn",{"title":"CELESTIAL PAVILION","subtitle":"Use your bonus Seal"})
func _leave_disabled_event() -> void:
 _close_modal()
 _back()
func _back() -> void:
 if is_instance_valid(_modal):_close_modal();return
 if _navigating:return
 _navigating=true;preload("res://scripts/ui/liveops/live_ops_ui.gd").return_home(self)
