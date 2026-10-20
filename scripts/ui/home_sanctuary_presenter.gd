extends "res://scripts/ui/home_production_presenter.gd"

## Approved Sanctuary layout. All balances, rewards, run/checkpoint decisions,
## account state and popup ownership remain in the existing authorities.
const ActionDot=preload("res://scripts/ui/action_ready_dot.gd")
const RealmArt = preload("res://scripts/ui/journey_art_catalog.gd")
const Art = preload("res://scripts/ui/home_sanctuary_art.gd")
const BOSS_SCENE: String = "res://scenes/ui/celestial_boss_hunt_screen.tscn"
const LIBRARY_SCENE: String = "res://scenes/ui/skill_book_screen.tscn"
const BOSS_ART: Texture2D = preload("res://assets/ui/liveops/event_identity/boss_hunt.png")
const STONE: Texture2D = preload("res://assets/ui/shared/resources/spirit_stone_premium.png")
var lower_scroll: ScrollContainer
var lower_stack: VBoxContainer
var journey_card: Control
var event_card: Control
var shortcuts: HBoxContainer
var title_name: Label
var title_role: Label
var boss_progress: Label
var boss_reward: Label
var event_action: Label
var login_state: Label
var meditation_state: Label
var meditation_badge: Panel
var feature_dot: Panel
var library_button: Button
var settings_shortcut: Button
var profile_seal_view: TextureRect
var profile_chevron: Label
var portrait_unit: float = 1.0
var refresh_elapsed: float = 0.0
var all_events_button: Button
var hero_title: Control
var checkpoint_available: bool = false
var layout_queued: bool = false
var realm_window: Panel
var event_window: Panel
var realm_vista: TextureRect
var presented_chapter: int = -1

func _ready() -> void:
 var root: Node = get_parent().get_parent()
 root.set_meta("sanctuary_home_ready",true)
 LiveOpsLocalization.install()
 _install_premium_meditation_presenter()
 _hide_legacy_home_chrome()
 _build_header()
 _build_body()
 _connect_runtime_signals()
 if not SaveManager.save_write_completed.is_connected(_on_save_completed):
  SaveManager.save_write_completed.connect(_on_save_completed)
 if not JourneyManager.stage_completed.is_connected(_on_stage_completed):
  JourneyManager.stage_completed.connect(_on_stage_completed)
 resized.connect(_queue_layout)
 get_tree().node_added.connect(_on_tree_node_added)
 _refresh_all()
 _layout_sanctuary()
 call_deferred("_layout_sanctuary")

func _process(delta: float) -> void:
 refresh_elapsed+=delta
 if refresh_elapsed<.5:return
 refresh_elapsed=0
 _refresh_journey()
 _refresh_liveops_badges()

func _on_save_completed(domain: String,_result: Dictionary) -> void:
 if domain in ["progression","journey","pavilion","checkpoint","idle_cultivation"]:_refresh_all.call_deferred()

func _on_stage_completed(_chapter: int,_stage: int,_first: bool) -> void:
 _refresh_all()

func _queue_layout() -> void:
 if layout_queued:return
 layout_queued=true
 _layout_sanctuary.call_deferred()

func _main_menu() -> Node:
 return get_parent().get_parent() if is_inside_tree() else null

func _build_header() -> void:
 profile_shortcut=_button("ProfileShortcut",Callable(self,"_open_profile"))
 profile_shortcut.tooltip_text=tr("Profile")
 profile_shortcut.clip_contents=true
 _plate(profile_shortcut)
 profile_seal_view=_icon(profile_shortcut,PROFILE_MEDALLION)
 profile_name=_copy(profile_shortcut,"",19,GOLD_BRIGHT,true)
 profile_name.name="PlayerName"
 profile_rank=_copy(profile_shortcut,"",12,TEXT)
 profile_rank.name="CultivationRank"
 profile_status=_copy(profile_shortcut,"",11,JADE_SOFT)
 profile_status.name="ProfileStatus"
 profile_exp=ProgressBar.new();profile_exp.name="HeroExperienceProgress";profile_exp.show_percentage=false;profile_exp.max_value=1.0
 profile_exp.mouse_filter=Control.MOUSE_FILTER_IGNORE
 profile_exp.add_theme_stylebox_override("background",_meter_style(Color(.01,.04,.04),Color(.6,.5,.28,.55)))
 profile_exp.add_theme_stylebox_override("fill",_meter_style(JADE,Color(.8,.9,.75)))
 profile_shortcut.add_child(profile_exp)
 profile_connection=Panel.new();profile_connection.name="ConnectionIndicator";profile_connection.mouse_filter=Control.MOUSE_FILTER_IGNORE
 profile_shortcut.add_child(profile_connection)
 profile_chevron=_copy(profile_shortcut,"›",20,GOLD_BRIGHT)
 settings_shortcut=_button("HomeSettingsButton",_open_menu_scene.bind(SETTINGS_SCENE))
 _plate(settings_shortcut)
 _icon(settings_shortcut,SETTINGS_ICON)
 mailbox_button=_button("SanctuaryMailbox",_open_live_popup.bind(MAILBOX_SCENE))
 _plate(mailbox_button)
 _icon(mailbox_button,MAILBOX_ICON)
 mailbox_badge=_add_notification_badge(mailbox_button)
 hero_title=Control.new();hero_title.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(hero_title)
 title_name=_copy(hero_title,"LIN YUE",35,GOLD_BRIGHT,true)
 title_role=_copy(hero_title,"THE JADE WANDERER",12,Color(.93,.89,.74))

func _build_body() -> void:
 lower_scroll=ScrollContainer.new();lower_scroll.name="SanctuaryPanelsScroll"
 lower_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 lower_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER
 lower_scroll.scroll_deadzone=MOBILE_SCROLL_DEADZONE;lower_scroll.follow_focus=false
 add_child(lower_scroll)
 event_scroll=lower_scroll
 lower_stack=VBoxContainer.new();lower_stack.name="SanctuaryPanels";lower_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 lower_stack.add_theme_constant_override("separation",10);lower_scroll.add_child(lower_stack)
 _build_journey_card()
 var heading:=Control.new();heading.name="EventsHeading";heading.custom_minimum_size.y=28;lower_stack.add_child(heading)
 var caption:=_copy(heading,tr("CELESTIAL EVENTS"),19,GOLD_BRIGHT,true);caption.name="EventsCaption"
 all_events_button=_button("AllEvents",_open_live_popup.bind(EVENT_CENTER_SCENE),heading)
 all_events_button.text=tr("ALL EVENTS")+" ›"
 _plate(all_events_button,true,Color(.018,.15,.14,.99))
 _font_button(all_events_button,20)
 _build_featured_event()
 shortcuts=HBoxContainer.new();shortcuts.name="SanctuaryShortcuts";shortcuts.add_theme_constant_override("separation",7)
 lower_stack.add_child(shortcuts)
 seven_day_button=_shortcut("SevenDay",SEVEN_DAY_ICON,tr("7-DAY"),_open_live_popup.bind(SEVEN_DAY_SCENE))
 login_state=seven_day_button.get_node("State") as Label
 seven_day_badge=_add_notification_badge(seven_day_button)
 meditation_button=_shortcut("MeditationFeature",MEDITATION_ICON,tr("MEDITATION"),Callable(self,"_open_spirit_meditation"))
 meditation_state=meditation_button.get_node("State") as Label
 meditation_badge=_red_dot(meditation_button)
 library_button=_shortcut("HomeSkillBookButton",preload("res://assets/ui/home/sanctuary/library_seal.svg"),tr("LIBRARY"),_open_menu_scene.bind(LIBRARY_SCENE))
 (library_button.get_node("State") as Label).text=tr("RELICS & SKILLS")

func _build_journey_card() -> void:
 journey_card=Control.new();journey_card.name="PremiumJourneyDeck";lower_stack.add_child(journey_card)
 journey_deck_shell=journey_card
 _plate(journey_card,false)
 realm_window=Art.art_window(journey_card,"RealmArtWindow")
 realm_vista=_icon(realm_window,null);realm_vista.name="RealmVignette"
 realm_vista.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 realm_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 Art.fade(realm_window,PackedColorArray([Color(.008,.045,.048,.08),Color(.008,.045,.048,.48),Color(.008,.045,.048,.99),Color(.008,.045,.048,1)]),PackedFloat32Array([0,.18,.42,1]))
 # Border is above both art and fade; the realm reads as one inset scene.
 journey_card.move_child(journey_card.get_node("SanctuaryFrame"),-1)
 chapter_label=_copy(journey_card,"",12,GOLD_BRIGHT,true)
 realm_title=_copy(journey_card,"",21,TEXT,true);realm_title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;realm_title.max_lines_visible=2
 next_path_label=_copy(journey_card,"",12,Color(.77,.9,.86))
 realm_progress=ProgressBar.new();realm_progress.name="SanctuaryRealmProgress";realm_progress.show_percentage=false
 realm_progress.mouse_filter=Control.MOUSE_FILTER_IGNORE
 realm_progress.add_theme_stylebox_override("background",_meter_style(Color(.01,.06,.07),Color(.22,.57,.5)))
 realm_progress.add_theme_stylebox_override("fill",_meter_style(JADE,Color(.88,.81,.44)))
 journey_card.add_child(realm_progress)
 progress_label=_copy(journey_card,"",12,JADE_SOFT)
 journey_button=_button("SanctuaryJourney",_call_main_menu.bind("_on_journey_pressed"),journey_card)
 _plate(journey_button,true,Color(.025,.18,.16,.99))
 journey_button.text=tr("ENTER JOURNEY")+" ›";_font_button(journey_button,19)
 continue_button=_button("SanctuaryContinue",_call_main_menu.bind("_on_continue_pressed"),journey_card)
 _plate(continue_button,true,Color(.01,.12,.14,.99));_font_button(continue_button,16)

func _build_featured_event() -> void:
 event_card=Control.new();event_card.name="SanctuaryFeaturedEvent";lower_stack.add_child(event_card)
 Art.fill(event_card,Color(.008,.045,.048,.92),false)
 event_window=Art.art_window(event_card,"EventArtWindow")
 var art:=_icon(event_window,BOSS_ART);art.name="EventArt";art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 Art.fade(event_window,PackedColorArray([Color(.012,.022,.024,.98),Color(.018,.022,.025,.88),Color(.018,.02,.025,.20)]),PackedFloat32Array([0,.45,1]))
 Art.frame(event_card,false)
 var tag:=_copy(event_card,tr("REALM CHALLENGE"),11,GOLD_BRIGHT);tag.name="EventKind"
 var title:=_copy(event_card,tr("CELESTIAL BOSS HUNT"),25,Color(1,.9,.65),true);title.name="FeaturedTitle"
 title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.max_lines_visible=2
 boss_progress=_copy(event_card,"",13,TEXT)
 var reward_icon:=_icon(event_card,STONE);reward_icon.name="UpcomingRewardIcon"
 boss_reward=_copy(event_card,"",13,GOLD_BRIGHT);boss_reward.name="UpcomingReward"
 event_action=_copy(event_card,tr("VIEW EVENT")+" ›",14,GOLD_BRIGHT,true)
 event_button=_button("FeaturedEventAction",_open_live_popup.bind(BOSS_SCENE),event_card)
 feature_dot=_red_dot(event_card)
 event_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 event_button.tooltip_text=tr("CELESTIAL BOSS HUNT")

func _shortcut(name_value: String,texture: Texture2D,title: String,action: Callable) -> Button:
 var button:=_button(name_value,action,shortcuts);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _plate(button)
 var icon:=_icon(button,texture);icon.name="ShortcutIcon"
 var caption:=_copy(button,title,14,TEXT,true);caption.name="Title"
 var state:=_copy(button,"",11,JADE_SOFT);state.name="State"
 return button

func _refresh_journey() -> void:
 if journey_card==null:return
 var chapter_id: int=JourneyManager.selected_chapter_id
 if presented_chapter!=chapter_id:
  presented_chapter=chapter_id
  var path: String=RealmArt.get_realm_vista_path(chapter_id)
  realm_vista.texture=load(path) as Texture2D if not path.is_empty() else Art.BACKGROUND
 var chapter: Dictionary=JourneyManager.get_chapter_data(chapter_id)
 var progress: Dictionary=JourneyManager.get_chapter_progress(chapter_id)
 var total: int=maxi(int(progress.get("total_stages",1)),1)
 var cleared: int=clampi(int(progress.get("cleared_stages",0)),0,total)
 chapter_label.text=tr("CHAPTER %02d") % chapter_id
 realm_title.text=tr(str(chapter.get("display_name","Jade Sanctuary"))).to_upper()
 progress_label.text="%d / %d"%[cleared,total]
 realm_progress.max_value=total;realm_progress.value=cleared
 var next_stage: int=total
 for stage_id: int in JourneyManager.get_stage_ids(chapter_id):
  if not JourneyManager.is_stage_cleared(chapter_id,stage_id):next_stage=stage_id;break
 next_path_label.text=tr("NEXT")+" · "+tr("STAGE")+" %d-%d"%[chapter_id,next_stage]
 var menu: Node=_main_menu()
 var has_checkpoint: bool=checkpoint_available
 if continue_button.visible!=has_checkpoint:
  continue_button.visible=has_checkpoint;_queue_layout()
 continue_button.text=tr("CONTINUE")+" ›" if size.x<560 else tr("CONTINUE RUN")
 if has_checkpoint and menu.has_method("_get_continue_button_text"):
  continue_button.tooltip_text=str(menu.call("_get_continue_button_text"))
 var locked: bool=SaveManager.is_progress_read_only()
 journey_button.disabled=locked or SceneTransitionManager.is_transitioning
 continue_button.disabled=locked or not has_checkpoint or SceneTransitionManager.is_transitioning

func _refresh_liveops_badges() -> void:
 if event_card==null:return
 super._refresh_liveops_badges()
 ActionDot.show_on(all_events_button,ActionDot.count(self,"all_events"))
 ActionDot.show_on(profile_shortcut,ActionDot.count(self,"profile"))
 var live_ops: Node=get_node_or_null("/root/LiveOpsManager")
 if live_ops==null:return
 var ids: Array=live_ops.get_boss_hunt_milestone_ids()
 boss_progress.text="%d / %d "%[live_ops.get_boss_hunt_unlocked_count(),ids.size()]+tr("GUARDIANS")
 feature_dot.visible=live_ops.get_boss_hunt_claimable_count()>0
 var reward: Dictionary={}
 for id: String in ids:
  if not live_ops.is_boss_hunt_milestone_claimed(id):reward=live_ops.get_boss_hunt_milestone(id).get("reward",{});break
 var stones: int=int(RewardManager.retire_fragments(reward).get("spirit_stone",0))
 boss_reward.text=tr("UPCOMING")+" +%d"%stones if stones>0 else tr("ALL CLAIMED")
 event_action.text=(tr("CLAIM REWARD") if feature_dot.visible else tr("VIEW EVENT"))+" ›"
 login_state.text=tr("DAY")+" %d / %d"%[live_ops.get_active_login_day_count(),live_ops.LOGIN_DAY_COUNT]
 var unlocked: bool=IdleCultivationManager.is_unlocked()
 var claim_available: bool=unlocked and IdleCultivationManager.get_claimable_units()>0
 meditation_state.text=tr("READY") if claim_available else (tr("ACCUMULATING") if unlocked else tr("CLEAR 1-1"))
 meditation_badge.visible=claim_available
 meditation_button.disabled=not unlocked

func _refresh_all() -> void:
 if profile_shortcut==null:return
 var menu: Node=_main_menu()
 checkpoint_available=menu!=null and menu.has_method("_has_checkpoint") and bool(menu.call("_has_checkpoint"))
 _refresh_profile_shortcut();_refresh_journey();_refresh_liveops_badges()

func _layout_profile_shortcut() -> void:
 pass # Owned by the single responsive layout below.

func _position_meditation() -> void:
 pass # Meditation lives in the three-shortcut row.

func _configure_mobile_scroll() -> void:
 pass # Release-on-tap guard already owns the one shared scroller.

func _layout_sanctuary() -> void:
 layout_queued=false
 if lower_scroll==null or size.x<=1 or size.y<=1:return
 portrait_unit=clampf(size.x/648.0,.49,1.8)
 var u: float=portrait_unit
 var side: float=maxf(9,14*u)
 var nav: Control=get_parent().get_node_or_null("HubNav") as Control
 var nav_height: float=88.0
 if nav!=null:
  nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
  nav.offset_left=side;nav.offset_right=-side;nav.offset_top=-nav_height-8;nav.offset_bottom=-8
 var header_y: float=78.0
 var header_h: float=maxf(94,108*u)
 var icon_side: float=clampf(84*u,56,112)
 var icon_gap: float=maxf(8,10*u)
 _rect(settings_shortcut,Vector2(size.x-side-icon_side,header_y+4),Vector2(icon_side,icon_side))
 _rect(mailbox_button,Vector2(settings_shortcut.position.x-icon_side-icon_gap,header_y+4),Vector2(icon_side,icon_side))
 var profile_w: float=mailbox_button.position.x-side-icon_gap
 _rect(profile_shortcut,Vector2(side,header_y),Vector2(profile_w,header_h))
 var avatar_side: float=maxf(40,54*u)
 var inset: float=maxf(10,16*u)
 var avatar_y: float=(header_h-avatar_side)*.5
 _rect(profile_seal_view,Vector2(inset,avatar_y),Vector2(avatar_side,avatar_side))
 var text_x: float=inset+avatar_side+maxf(8,10*u)
 var text_w: float=maxf(40,profile_w-text_x-maxf(18,24*u))
 var name_y: float=maxf(10,14*u)
 var name_h: float=maxf(20,26*u)
 var rank_y: float=name_y+name_h+2*u
 var rank_h: float=maxf(16,18*u)
 var exp_y: float=rank_y+rank_h+5*u
 _rect(profile_name,Vector2(text_x,name_y),Vector2(text_w,name_h));_font(profile_name,24,true)
 _rect(profile_rank,Vector2(text_x,rank_y),Vector2(text_w,rank_h));_font(profile_rank,14)
 _rect(profile_exp,Vector2(text_x,exp_y),Vector2(text_w,maxf(3,4*u)))
 _rect(profile_status,Vector2(text_x,exp_y+maxf(7,9*u)),Vector2(text_w,maxf(14,15*u)));_font(profile_status,12)
 var dot_side: float=maxf(7,9*u)
 _rect(profile_connection,Vector2(inset+avatar_side-dot_side,avatar_y+avatar_side-dot_side),Vector2.ONE*dot_side)
 _rect(profile_chevron,Vector2(profile_w-maxf(16,20*u),(header_h-24*u)*.5),Vector2(12,24)*u)
 _fit_icon(settings_shortcut,maxf(10,16*u));_fit_icon(mailbox_button,maxf(8,12*u))
 _rect(hero_title,Vector2(side+8*u,maxf(header_y+header_h+14, size.y*.19)),Vector2(size.x*.42,65*u))
 _rect(title_name,Vector2.ZERO,Vector2(hero_title.size.x,42*u));_font(title_name,35,true)
 _rect(title_role,Vector2(0,43*u),Vector2(hero_title.size.x,17*u));_font(title_role,12)
 var compact: bool=size.x<560
 var card_h: float=206.0 if compact else maxf(152,158*u)
 var event_h: float=maxf(166,190*u)
 var shortcut_h: float=90.0 if size.x<420 else maxf(65,80*u)
 var heading_h: float=maxf(60,66*u)
 var gap: float=maxf(6,9*u)
 var panel_h: float=card_h+event_h+shortcut_h+heading_h+gap*3
 var bottom: float=size.y-nav_height-20
 var upper: float=maxf(header_y+header_h+10,bottom-panel_h)
 var available: float=maxf(70,bottom-upper)
 lower_stack.custom_minimum_size.x=size.x-2*side
 _rect(lower_scroll,Vector2(side,upper),Vector2(size.x-2*side,available))
 hero_title.visible=hero_title.position.y+hero_title.size.y+8<upper
 lower_stack.custom_minimum_size.x=lower_scroll.size.x
 lower_stack.add_theme_constant_override("separation",int(gap))
 journey_card.custom_minimum_size.y=card_h;event_card.custom_minimum_size.y=event_h;shortcuts.custom_minimum_size.y=shortcut_h
 var width: float=lower_scroll.size.x
 var map_w: float=width*(.20 if compact else .22)
 Art.inset_art(realm_window,maxf(10,20*u))
 Art.inset_art(event_window,maxf(10,20*u))
 var text_start: float=map_w+8*u
 var action_w: float=width-24 if compact else width*.39
 var text_width: float=width-text_start-18*u if compact else width-text_start-action_w-22*u
 _rect(chapter_label,Vector2(text_start,16.0 if compact else 23*u),Vector2(text_width,20));_font(chapter_label,13,true)
 _rect(realm_title,Vector2(text_start,38.0 if compact else 46*u),Vector2(text_width,48));_font(realm_title,22,true)
 _rect(next_path_label,Vector2(text_start,83.0 if compact else 100*u),Vector2(text_width,20));_font(next_path_label,13)
 var meter_y: float=112.0 if compact else card_h-38*u
 _rect(realm_progress,Vector2(text_start,meter_y),Vector2(maxf(30,text_width-43*u),7))
 _rect(progress_label,Vector2(text_start+maxf(30,text_width-40*u),meter_y-5),Vector2(42*u,20));_font(progress_label,12)
 journey_button.text=tr("ENTER JOURNEY")+" ›"
 continue_button.text=tr("CONTINUE")+" ›" if compact else tr("CONTINUE RUN")
 var button_h: float=50.0 if compact else maxf(52,64*u)
 var action_x: float=12.0 if compact else width-action_w-12*u
 if compact:
  var button_y: float=card_h-button_h-16
  if continue_button.visible:
   _rect(journey_button,Vector2(action_x,button_y),Vector2((action_w-8)*.59,button_h))
   _rect(continue_button,Vector2(action_x+(action_w-8)*.59+8,button_y),Vector2((action_w-8)*.41,button_h))
  else:_rect(journey_button,Vector2(action_x,button_y),Vector2(action_w,button_h))
 elif continue_button.visible:
  _rect(journey_button,Vector2(action_x,15*u),Vector2(action_w,button_h))
  _rect(continue_button,Vector2(action_x,card_h-button_h-12*u),Vector2(action_w,button_h))
 else:_rect(journey_button,Vector2(action_x,(card_h-button_h)*.5),Vector2(action_w,button_h))
 _font_button(journey_button,20);_font_button(continue_button,17)
 var heading: Control=lower_stack.get_node("EventsHeading");heading.custom_minimum_size.y=heading_h
 var all_width: float=minf(width*.48,maxf(130,176*u))
 var caption: Label=heading.get_node("EventsCaption");_rect(caption,Vector2(3*u,0),Vector2(width-all_width-10*u,heading_h));_font(caption,20,true)
 all_events_button.text=tr("ALL EVENTS")+" ›"
 _rect(all_events_button,Vector2(width-all_width,0),Vector2(all_width,heading_h));_font_button(all_events_button,20)
 _rect(event_card.get_node("EventKind"),Vector2(34,29)*u,Vector2(width*.57,16*u));_font(event_card.get_node("EventKind"),11)
 _rect(event_card.get_node("FeaturedTitle"),Vector2(34,53)*u,Vector2(width*.56,maxf(42,56*u)));_font(event_card.get_node("FeaturedTitle"),25,true)
 _rect(boss_progress,Vector2(25*u,event_h-maxf(51,62*u)),Vector2(width*.6,18*u));_font(boss_progress,13)
 _rect(event_card.get_node("UpcomingRewardIcon"),Vector2(25*u,event_h-maxf(32,42*u)),Vector2(24,24)*u)
 _rect(boss_reward,Vector2(55*u,event_h-maxf(31,41*u)),Vector2(width*.5,22*u));_font(boss_reward,12)
 _rect(event_action,Vector2(width*.55,event_h-maxf(35,46*u)),Vector2(width*.42,maxf(22,27*u)));_font(event_action,13,true)
 var shortcut_w: float=(width-14)/3.0
 for button: Button in [seven_day_button,meditation_button,library_button]:
  var icon: Control=button.get_node("ShortcutIcon")
  var iw: float=minf(shortcut_h-15*u,shortcut_w*.33)
  _rect(icon,Vector2(8*u,(shortcut_h-iw)*.5),Vector2(iw,iw))
  if size.x<420:
   _rect(icon,Vector2((shortcut_w-32)*.5,8),Vector2(32,32))
   var title: Label=button.get_node("Title");var state: Label=button.get_node("State")
   title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;state.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   _rect(title,Vector2(6,42),Vector2(shortcut_w-12,18));_font(title,16,true)
   _rect(state,Vector2(6,61),Vector2(shortcut_w-12,16));_font(state,12)
   continue
  (button.get_node("Title") as Label).horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
  (button.get_node("State") as Label).horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
  var tx: float=iw+11*u;var tw: float=shortcut_w-tx-10*u
  _rect(button.get_node("Title"),Vector2(tx,17*u),Vector2(tw,23*u));_font(button.get_node("Title"),16,true)
  _rect(button.get_node("State"),Vector2(tx,44*u),Vector2(tw,17*u));_font(button.get_node("State"),12)

func _button(name_value: String,action: Callable,parent: Node=null) -> Button:
 var button:=Button.new();button.name=name_value;button.focus_mode=Control.FOCUS_NONE
 button.clip_text=true;button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 button.mouse_filter=Control.MOUSE_FILTER_PASS;button.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;button.keep_pressed_outside=false
 var empty:=StyleBoxEmpty.new()
 for state: String in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(state,empty)
 button.set_meta(&"jade_mobile_readability_v2",true)
 (self if parent==null else parent).add_child(button)
 button.gui_input.connect(_track_gesture.bind(button))
 button.button_down.connect(_capture_press.bind(button))
 button.pressed.connect(_activate.bind(action,button))
 return button

func _capture_press(button: Button) -> void:
 button.set_meta("sanctuary_dragged",false)
 button.set_meta("sanctuary_distance",0.0)
 button.set_meta("sanctuary_scroll",lower_scroll.scroll_vertical if is_instance_valid(lower_scroll) else 0)
 button.set_meta("sanctuary_pointer",get_global_mouse_position())

func _track_gesture(event: InputEvent, button: Button) -> void:
 if event is InputEventScreenDrag or (event is InputEventMouseMotion and button.button_pressed):
  var distance: float=float(button.get_meta("sanctuary_distance",0.0))+event.relative.length()
  button.set_meta("sanctuary_distance",distance)
  if distance>=14:button.set_meta("sanctuary_dragged",true)

func _activate(action: Callable,button: Button) -> void:
 if SceneTransitionManager.is_transitioning or bool(button.get_meta("sanctuary_dragged",false)):return
 var start_y: int=int(button.get_meta("sanctuary_scroll",0))
 if is_instance_valid(lower_scroll) and absi(start_y-lower_scroll.scroll_vertical)>=MOBILE_SCROLL_DEADZONE:return
 if button.has_meta("sanctuary_pointer") and (button.get_meta("sanctuary_pointer") as Vector2).distance_to(get_global_mouse_position())>14:return
 if action.is_valid():action.call()

func _plate(parent: Control,compact: bool=true,color: Color=Color(.008,.045,.048,.92)) -> void:
 Art.fill(parent,color,compact);Art.frame(parent,compact)

func _icon(parent: Node,texture: Texture2D) -> TextureRect:
 var icon:=TextureRect.new();icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture=texture;parent.add_child(icon);return icon

func _copy(parent: Node,value: String,font_size: int,color: Color=TEXT,serif: bool=false) -> Label:
 var label:=Label.new();label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.text=value;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 label.set_meta(&"jade_mobile_readability_v2",true);parent.add_child(label);_font(label,font_size,serif);label.add_theme_color_override("font_color",color)
 return label

func _font(label: Label,source_size: int,serif: bool=false) -> void:
 label.add_theme_font_size_override("font_size",maxi(11,roundi(source_size*portrait_unit)))
 if serif:label.add_theme_font_override("font",Art.SERIF)
 if label.has_meta("sanctuary_layout_size"):label.size=label.get_meta("sanctuary_layout_size")

func _font_button(button: Button,source_size: int) -> void:
 var primary: bool=button in [journey_button,continue_button]
 var margin: float=clampf(20*portrait_unit,12,26) if primary else 6.0
 if primary and size.x<560 and is_instance_valid(continue_button) and continue_button.visible:margin=8.0
 var style: StyleBox=button.get_theme_stylebox("normal")
 style.content_margin_left=margin;style.content_margin_right=margin
 button.add_theme_font_override("font",Art.SERIF);button.add_theme_color_override("font_color",GOLD_BRIGHT)
 var font_size: int=maxi(16 if primary else 14,roundi(source_size*portrait_unit))
 var available: float=maxf(0,button.size.x-margin*2)
 while font_size>14 and Art.SERIF.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>available:font_size-=1
 button.add_theme_font_size_override("font_size",font_size)

func _red_dot(parent: Control) -> Panel:
 var dot:=Panel.new();dot.name="ReadyDot";dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
 dot.add_theme_stylebox_override("panel",_panel_style(Color(.9,.12,.12),GOLD,7,3))
 parent.add_child(dot);dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 dot.offset_left=-18;dot.offset_right=-7;dot.offset_top=8;dot.offset_bottom=19
 return dot

func _fit_icon(button: Button,margin: float) -> void:
 for child: Node in button.get_children():
  if child is TextureRect and child!=mailbox_badge:
   (child as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   (child as Control).offset_left=margin;(child as Control).offset_top=margin;(child as Control).offset_right=-margin;(child as Control).offset_bottom=-margin

func _rect(node: Control,position_value: Vector2,size_value: Vector2) -> void:
 node.set_meta("sanctuary_layout_size",size_value)
 node.position=position_value;node.size=size_value

func open_currency_sources(index: int) -> void:
 if index==1:
  _open_live_popup("res://scenes/ui/celestial_treasury_screen.tscn")
 else:_open_menu_scene("res://scenes/ui/daily_quest_screen.tscn" if index==0 else "res://scenes/ui/pavilion_screen.tscn")
