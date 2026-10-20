extends Control
## Approved Celestial Event hub. Resident layout; read-only manager snapshots.
const ActionDot=preload("res://scripts/ui/action_ready_dot.gd")
const Catalog=preload("res://scripts/ui/liveops/event_hub_catalog.gd")
const HubStyle=preload("res://scripts/ui/liveops/event_hub_style.gd")
const EventArt=preload("res://scripts/ui/liveops/event_identity_catalog.gd")
const LiveOpsUi=preload("res://scripts/ui/liveops/live_ops_ui.gd")
const HUB_REVISION: int=1
const HERO: Texture2D=preload("res://assets/ui/liveops/event_center_v2/odyssey_hero.png")
const ICONS: Dictionary={"spirit_stone":preload("res://assets/ui/shared/resources/spirit_stone_premium.png"),"celestial_jade":preload("res://assets/ui/shared/resources/celestial_jade_premium.png"),"pavilion_seal":preload("res://assets/ui/shared/resources/pavilion_seal_premium.png"),"compass":preload("res://assets/ui/liveops/odyssey/compass.png")}
const FEATURED_EVENT_ID: String="seven_days_of_ascension"
const PILGRIMAGE_EVENT_ID: String="jade_valley_pilgrimage"
const BOSS_HUNT_EVENT_ID: String="celestial_boss_hunt"
const HEAVENLY_LADDER_EVENT_ID: String="heavenly_ladder"
const TREASURE_HUNT_EVENT_ID: String="celestial_treasure_hunt"
const FIVE_ELEMENTS_EVENT_ID: String="path_of_five_elements"
const DAILY_SCENE: String="res://scenes/ui/daily_quest_screen.tscn"
const PAVILION_SCENE: String="res://scenes/ui/pavilion_screen.tscn"
const SCROLL_DEADZONE: int=7
var _live_ops: Node
var _popup: PanelContainer
var _scroll: ScrollContainer
var _header_title: Label
var _subtitle: Label
var _close_button: Button
var _hero_stage: PanelContainer
var _hero_title: Label
var _hero_description: Label
var _hero_tag: Label
var _event_status: Label
var _event_progress: Label
var _hero_action: Button
var _hero_meter: ProgressBar
var _section_title: Label
var _ready_count: Label
var _hero_rewards: HBoxContainer
var _hero_actions: GridContainer
var _activity_handles: Dictionary={}
var _filters: Dictionary={}
var _filter: String="all"
var _dragging: bool=false
var _tap_guard_until: int=0
var _press_scroll_y: Dictionary={}
var _press_positions: Dictionary={}
var _navigating: bool=false
var _refresh_elapsed: float=0.0

func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_STOP;process_mode=Node.PROCESS_MODE_ALWAYS
 _live_ops=get_node_or_null("/root/LiveOpsManager")
 if not bool(get_meta("liveops_popup",false)):SceneTransitionManager.set_back_handler(_back)
 _build();_fit_layout();_refresh_event_status()
 resized.connect(_fit_layout)
 for manager_name: String in ["LiveOpsManager","OdysseyClient","DailyQuestManager","PavilionManager","SaveManager"]:
  var manager: Node=get_node_or_null("/root/"+manager_name)
  if manager==null:continue
  for event_name: String in ["live_ops_changed","changed","daily_quest_progressed","daily_quest_claimed","daily_quests_reset","pavilion_changed","save_write_barrier_changed"]:
   if manager.has_signal(event_name) and not manager.is_connected(event_name,_refresh_from_signal):manager.connect(event_name,_refresh_from_signal)
func _notification(what: int) -> void:
 if what==NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree() and is_instance_valid(_popup):_refresh_event_status();_fit_layout()
func _process(delta: float) -> void:
 _refresh_elapsed+=delta
 if _refresh_elapsed>=1.0:_refresh_elapsed=0.0;_refresh_event_status()
func _label(text: String,font_size: int,color: Color=HubStyle.TEXT,display: bool=false) -> Label:
 var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
 if display:label.add_theme_font_override("font",HubStyle.DISPLAY)
 return label
func _margin(parent: Node,amount: int) -> MarginContainer:
 var margin:=MarginContainer.new()
 for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,amount)
 parent.add_child(margin);return margin
func _pill(parent: Node) -> PanelContainer:
 var pill:=PanelContainer.new();pill.add_theme_stylebox_override("panel",HubStyle.panel(Color(.015,.10,.07,.92),Color(.44,.51,.28,.6),5));parent.add_child(pill);return pill
func _texture(image: Texture2D) -> TextureRect:
 var texture:=TextureRect.new();texture.texture=image;texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;texture.mouse_filter=Control.MOUSE_FILTER_IGNORE
 return texture
func _build() -> void:
 var scrim:=ColorRect.new();scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scrim.color=Color(.005,.018,.014,.77);scrim.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(scrim)
 _popup=PanelContainer.new();_popup.name="CelestialEventsProductionPopup";_popup.add_theme_stylebox_override("panel",HubStyle.panel(Color("061d18"),HubStyle.GOLD,16));add_child(_popup)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",12);_margin(_popup,16).add_child(body)
 var heading:=HBoxContainer.new();heading.add_theme_constant_override("separation",10);body.add_child(heading)
 var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(titles)
 var eyebrow: Label=_label("JADE ASCENDANT",12,HubStyle.JADE);titles.add_child(eyebrow)
 _header_title=_label("",32,HubStyle.CREAM,true);titles.add_child(_header_title)
 _subtitle=_label("",15,HubStyle.MUTED);titles.add_child(_subtitle)
 _close_button=Button.new();_close_button.text="×";_close_button.custom_minimum_size=Vector2(48,48);_close_button.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
 _close_button.add_theme_font_size_override("font_size",27);HubStyle.button(_close_button);heading.add_child(_close_button);_close_button.pressed.connect(_back)
 var filter_row:=HBoxContainer.new();filter_row.add_theme_constant_override("separation",8);body.add_child(filter_row)
 for key: String in ["all","limited","progress"]:
  var tab:=Button.new();tab.name="Filter_"+key;tab.custom_minimum_size.y=44;tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tab.add_theme_font_size_override("font_size",15);HubStyle.button(tab)
  filter_row.add_child(tab);_filters[key]=tab;tab.pressed.connect(_set_filter.bind(key))
 _scroll=ScrollContainer.new();_scroll.name="EventList";_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 _scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;_scroll.follow_focus=false
 body.add_child(_scroll);_scroll.scroll_started.connect(_on_scroll_started);_scroll.scroll_ended.connect(_on_scroll_ended)
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);_scroll.add_child(list)
 _build_hero(list)
 var section:=HBoxContainer.new();section.name="EventSection";list.add_child(section)
 _section_title=_label("",17,HubStyle.CREAM,true);_section_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;section.add_child(_section_title)
 _ready_count=_label("",13,HubStyle.JADE);_ready_count.autowrap_mode=TextServer.AUTOWRAP_OFF;_ready_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;section.add_child(_ready_count)
 for key: String in Catalog.IDS:_build_row(list,key)
func _build_hero(parent: Node) -> void:
 _hero_stage=PanelContainer.new();_hero_stage.name="FeaturedOdyssey";_hero_stage.clip_contents=true;_hero_stage.add_theme_stylebox_override("panel",HubStyle.panel(Color("0b2d22"),HubStyle.GOLD,12));parent.add_child(_hero_stage)
 var art: TextureRect=_texture(HERO);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_hero_stage.add_child(art)
 # A bottom fade leaves the dragon visible and reserves a quiet reading surface.
 var gradient:=Gradient.new();gradient.set_color(0,Color(0,.035,.02,.04));gradient.set_color(1,Color(.006,.06,.035,.99));gradient.add_point(.44,Color(.004,.04,.02,.1));gradient.add_point(.72,Color(.005,.05,.03,.86))
 var fade:=GradientTexture2D.new();fade.gradient=gradient;fade.fill_from=Vector2(.5,0);fade.fill_to=Vector2(.5,1)
 var veil: TextureRect=_texture(fade);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_hero_stage.add_child(veil)
 var stack:=VBoxContainer.new();stack.add_theme_constant_override("separation",8);_margin(_hero_stage,18).add_child(stack)
 var ribbon:=HBoxContainer.new();ribbon.add_theme_constant_override("separation",8);stack.add_child(ribbon)
 _hero_tag=_label("",12,HubStyle.CREAM);_hero_tag.autowrap_mode=TextServer.AUTOWRAP_OFF;_hero_tag.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_margin(_pill(ribbon),6).add_child(_hero_tag)
 var ribbon_space:=Control.new();ribbon_space.mouse_filter=Control.MOUSE_FILTER_IGNORE;ribbon_space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ribbon.add_child(ribbon_space)
 _event_status=_label("",13,HubStyle.JADE);_event_status.autowrap_mode=TextServer.AUTOWRAP_OFF;_event_status.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;_margin(_pill(ribbon),6).add_child(_event_status)
 _hero_title=_label("Jade Dragon\nOdyssey",38,HubStyle.CREAM,true);stack.add_child(_hero_title)
 _hero_description=_label("",15,HubStyle.TEXT);_hero_description.custom_minimum_size.x=0;stack.add_child(_hero_description)
 var space:=Control.new();space.mouse_filter=Control.MOUSE_FILTER_IGNORE;space.custom_minimum_size.y=65;space.size_flags_vertical=Control.SIZE_EXPAND_FILL;stack.add_child(space)
 _hero_actions=GridContainer.new();_hero_actions.columns=2;_hero_actions.add_theme_constant_override("h_separation",14);_hero_actions.add_theme_constant_override("v_separation",8);stack.add_child(_hero_actions)
 var reward_stack:=VBoxContainer.new();reward_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_hero_actions.add_child(reward_stack)
 var reward_caption: Label=_label("",11,HubStyle.MUTED);reward_caption.name="JourneyRewardsCaption";reward_stack.add_child(reward_caption)
 _hero_rewards=HBoxContainer.new();_hero_rewards.add_theme_constant_override("separation",10);reward_stack.add_child(_hero_rewards)
 for key: String in ["compass","celestial_jade","pavilion_seal"]:
  var icon: TextureRect=_texture(ICONS[key]);icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(38,38);_hero_rewards.add_child(icon)
 var journey_stack:=VBoxContainer.new();journey_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_hero_actions.add_child(journey_stack)
 _event_progress=_label("",13,HubStyle.CREAM);journey_stack.add_child(_event_progress)
 _hero_meter=HubStyle.meter();journey_stack.add_child(_hero_meter)
 _hero_action=Button.new();_hero_action.name="ContinueJourney";_hero_action.custom_minimum_size=Vector2(0,54);_hero_action.add_theme_font_size_override("font_size",16);HubStyle.button(_hero_action,true);journey_stack.add_child(_hero_action);_wire_navigation_button(_hero_action,"odyssey")
func _build_row(parent: Node,key: String) -> void:
 var card:=PanelContainer.new();card.name="Event_"+key;card.custom_minimum_size.y=148;card.clip_contents=true
 card.add_theme_stylebox_override("panel",HubStyle.panel(Color("0a2b23"),Color("4a644b"),10));parent.add_child(card)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);_margin(card,10).add_child(row)
 var picture: Texture2D=load("res://assets/ui/liveops/seven_day/seven_day_ascension_hero_portrait_bg.png") if key=="seven_day" else EventArt.texture_for(key)
 var art: TextureRect=_texture(picture);art.custom_minimum_size=Vector2(128,0);art.clip_contents=true;row.add_child(art)
 var text_stack:=VBoxContainer.new();text_stack.size_flags_horizontal=Control.SIZE_EXPAND_FILL;text_stack.add_theme_constant_override("separation",4);row.add_child(text_stack)
 var title_label: Label=_label("",23,HubStyle.CREAM,true);text_stack.add_child(title_label)
 var description_label: Label=_label("",14,HubStyle.MUTED);text_stack.add_child(description_label)
 var status_label: Label=_label("",13,HubStyle.JADE);text_stack.add_child(status_label)
 var meter: ProgressBar=HubStyle.meter();text_stack.add_child(meter)
 var reward_label: Label=_label("",13,HubStyle.CREAM);text_stack.add_child(reward_label)
 var arrow:=Button.new();arrow.name="OpenEvent";arrow.text="›";arrow.custom_minimum_size=Vector2(48,48);arrow.size_flags_vertical=Control.SIZE_SHRINK_CENTER;arrow.add_theme_font_size_override("font_size",30);HubStyle.button(arrow);row.add_child(arrow)
 # One hit target across the whole row; decorations and arrow never own a second callback.
 arrow.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var hit:=Button.new();hit.name="EventHitTarget";hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hit.flat=true;hit.focus_mode=Control.FOCUS_NONE
 for state_name: String in ["normal","hover","pressed","focus"]:hit.add_theme_stylebox_override(state_name,StyleBoxEmpty.new())
 card.add_child(hit);_wire_navigation_button(hit,key)
 _activity_handles[key]={"card":card,"title":title_label,"description":description_label,"status":status_label,"meter":meter,"reward":reward_label,"cta":arrow,"hit":hit,"art":art}
func _refresh_from_signal(_first: Variant=null,_second: Variant=null,_third: Variant=null) -> void:_refresh_event_status()
func _refresh_event_status() -> void:
 if not is_instance_valid(_header_title):return
 _header_title.text=Catalog.copy("CELESTIAL EVENTS","EVENT SURGAWI");_subtitle.text=Catalog.copy("Your next adventure starts here.","Petualangan berikutmu dimulai di sini.")
 _close_button.tooltip_text=Catalog.copy("Close events","Tutup event")
 for entry: Array in [["all","ALL","SEMUA"],["limited","LIMITED","TERBATAS"],["progress","PROGRESS","PROGRES"]]:
  var tab: Button=_filters[entry[0]];tab.text=Catalog.copy(entry[1],entry[2]);tab.modulate=Color.WHITE if _filter==entry[0] else Color(.72,.82,.76)
 _section_title.text=Catalog.copy("YOUR EVENTS","EVENT KAMU")
 var total_ready: int=ActionDot.count(self,"all_events")
 _ready_count.text=Catalog.copy("%d READY","%d TERSEDIA")%total_ready if total_ready>0 else Catalog.copy("KEEP EXPLORING","TERUS JELAJAHI")
 for key: String in _activity_handles:
  var item: Dictionary=_activity_handles[key];var data: Dictionary=Catalog.preview(self,key);var ready_count: int=ActionDot.count(self,key)
  item.title.text=Catalog.title(key);item.description.text=Catalog.description(key)
  item.status.text=Catalog.copy("%d READY TO CLAIM","%d SIAP DIKLAIM")%ready_count if ready_count>0 else (Catalog.copy("COMPLETED","SELESAI") if data.complete else Catalog.copy("PROGRESS %d / %d","PROGRES %d / %d")%[data.current,data.total])
  item.status.add_theme_color_override("font_color",HubStyle.CREAM if ready_count>0 else HubStyle.JADE)
  item.meter.max_value=maxi(1,int(data.total));item.meter.value=data.current
  item.reward.text=_reward_text(data.reward);item.reward.visible=not item.reward.text.is_empty()
  item.cta.tooltip_text=Catalog.copy("Open ","Buka ")+Catalog.title(key);item.hit.tooltip_text=item.cta.tooltip_text
  ActionDot.show_on(item.cta,ready_count)
 _refresh_odyssey()
func _refresh_activity_handles() -> void:_refresh_event_status()
func _reward_text(reward: Dictionary) -> String:
 var parts: PackedStringArray=[]
 for entry: Array in [["spirit_stone","Spirit Stones"],["celestial_jade","Celestial Jade"],["pavilion_seal","Pavilion Seal"]]:
  var amount: int=int(reward.get(entry[0],0))
  if amount>0:parts.append("%d %s"%[amount,entry[1]])
 return Catalog.copy("Next: ","Berikut: ")+"  ·  ".join(parts) if not parts.is_empty() else ""
func _refresh_odyssey() -> void:
 var client: Node=get_node_or_null("/root/OdysseyClient");var snapshot: Dictionary=client.snapshot if client!=null else {}
 var event: Dictionary=snapshot.get("event",{}) if snapshot.get("event") is Dictionary else {};var state: Dictionary=snapshot.get("state",{})
 var now: float=client.server_time() if client!=null else 0.0
 _hero_tag.text=Catalog.copy("LIMITED EVENT","EVENT TERBATAS");_hero_description.text=Catalog.copy("Roll the dice. Explore the celestial isles.","Lempar dadu. Jelajahi kepulauan surgawi.")
 _hero_rewards.get_parent().get_node("JourneyRewardsCaption").text=Catalog.copy("EVENT REWARDS","HADIAH EVENT")
 _event_progress.text=Catalog.copy("%d / 72 journeys","%d / 72 perjalanan")%int(state.get("rolls",0));_hero_meter.max_value=72;_hero_meter.value=int(state.get("rolls",0))
 _hero_action.text=Catalog.copy("CONTINUE JOURNEY","LANJUTKAN PERJALANAN") if not event.is_empty() and bool(event.get("enabled",false)) and now>=float(event.get("starts_at",0)) and now<float(event.get("ends_at",0)) else Catalog.copy("VIEW EVENT","LIHAT EVENT")
 _event_status.text=_odyssey_status(event,now)
 ActionDot.show_on(_hero_action,ActionDot.count(self,"odyssey"))
func _odyssey_status(event: Dictionary,now: float) -> String:
 if event.is_empty():return Catalog.copy("AWAITING SEASON","MENUNGGU MUSIM")
 if not bool(event.get("enabled",false)):return Catalog.copy("PAUSED","DIJEDA")
 var starts: float=float(event.get("starts_at",0));var ends: float=float(event.get("ends_at",0))
 if now<starts:return Catalog.copy("STARTS IN ","MULAI ")+_duration(starts-now)
 if now<ends:return _duration(ends-now)+Catalog.copy(" LEFT"," LAGI")
 if now<ends+259200:return Catalog.copy("CLAIM REWARDS","KLAIM HADIAH")
 return Catalog.copy("SEASON ENDED","MUSIM BERAKHIR")
func _duration(seconds: float) -> String:
 if seconds>=86400:return Catalog.copy("%d DAYS","%d HARI")%int(ceil(seconds/86400))
 if seconds>=3600:return Catalog.copy("%d HOURS","%d JAM")%int(ceil(seconds/3600))
 return Catalog.copy("%d MIN","%d MNT")%maxi(1,int(ceil(seconds/60)))
func _set_filter(key: String) -> void:
 if _dragging or Time.get_ticks_msec()<_tap_guard_until or _filter==key:return
 _filter=key;_scroll.scroll_vertical=0;_hero_stage.visible=key!="progress"
 _section_title.get_parent().visible=key!="limited"
 for id: String in _activity_handles:_activity_handles[id].card.visible=key!="limited" and (key!="progress" or id!="pavilion")
 _refresh_event_status()
func _fit_layout() -> void:
 if not is_instance_valid(_popup):return
 var popup_size:=Vector2(minf(maxf(size.x-16,280),760),maxf(size.y-20,240))
 _popup.size=popup_size;_popup.position=(size-popup_size)*.5
 var compact: bool=popup_size.x<430
 _header_title.add_theme_font_size_override("font_size",23 if compact else 32)
 _subtitle.add_theme_font_size_override("font_size",13 if compact else 15)
 _hero_title.add_theme_font_size_override("font_size",29 if compact else 38)
 _hero_stage.custom_minimum_size.y=360 if compact else 400
 _hero_actions.columns=1 if compact else 2
 for key: String in _activity_handles:
  var item: Dictionary=_activity_handles[key];item.art.custom_minimum_size.x=68 if compact else 128
  item.title.add_theme_font_size_override("font_size",19 if compact else 23)
  item.description.visible=not compact
  item.reward.add_theme_font_size_override("font_size",12 if compact else 13)
  item.card.custom_minimum_size.y=132 if compact else 148
func _wire_navigation_button(button: Button,id: String) -> void:
 button.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;button.keep_pressed_outside=false;button.mouse_filter=Control.MOUSE_FILTER_PASS
 button.button_down.connect(_record_button_down.bind(id));button.pressed.connect(_open_destination.bind(id))
func _record_button_down(id: String) -> void:
 _press_scroll_y[id]=_scroll.scroll_vertical;_press_positions[id]=get_global_mouse_position()
func _on_scroll_started() -> void:_dragging=true;_tap_guard_until=Time.get_ticks_msec()+190
func _on_scroll_ended() -> void:_dragging=false;_tap_guard_until=Time.get_ticks_msec()+190
func _back() -> void:
 if _navigating:return
 _navigating=true;LiveOpsUi.return_home(self)
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled();_back()

func _open_destination(id: String) -> void:
 if _navigating or SceneTransitionManager.is_transitioning:return
 var moved: bool=_press_positions.has(id) and get_global_mouse_position().distance_to(_press_positions[id])>=SCROLL_DEADZONE
 _press_positions.erase(id)
 if moved:return
 var before: int = int(_press_scroll_y.get(id, -1))
 _press_scroll_y.erase(id)
 if _dragging or Time.get_ticks_msec() < _tap_guard_until:
  return
 if before >= 0 and absi(_scroll.scroll_vertical - before) >= SCROLL_DEADZONE:
  return

 var scene_path: String = ""
 var event_id: String = ""
 match id:
  "seven_day":
   event_id = FEATURED_EVENT_ID
  "pilgrimage":
   event_id = PILGRIMAGE_EVENT_ID
  "boss_hunt":
   event_id = BOSS_HUNT_EVENT_ID
  "heavenly_ladder":
   event_id = HEAVENLY_LADDER_EVENT_ID
  "treasure_hunt":
   event_id = TREASURE_HUNT_EVENT_ID
  "five_elements":
   event_id = FIVE_ELEMENTS_EVENT_ID
  "odyssey":
   scene_path = "res://scenes/ui/odyssey_screen.tscn"
  "daily":
   scene_path = DAILY_SCENE
  "pavilion":
   scene_path = PAVILION_SCENE
  _:
   return

 if not event_id.is_empty():
  if _live_ops == null:
   return
  var event: Dictionary = _live_ops.call(
   "get_event",
   event_id
  )
  scene_path = str(
   event.get("scene_path", "")
  ).strip_edges()

 if (
  scene_path.is_empty()
  or not ResourceLoader.exists(scene_path, "PackedScene")
 ):
  push_error(
   "EventCenterScreen: destination scene is unavailable for " + id
  )
  return

 _navigating=true
 # Seven Days remains a popup when Event Center was opened from Home.
 # For other destinations retain the existing lightweight menu transition.
 if (
  bool(get_meta("liveops_popup", false))
  and id in ["seven_day", "pilgrimage", "boss_hunt"]
 ):
  if _live_ops != null and _live_ops.has_method("open_live_popup"):
   _live_ops.call("open_live_popup", scene_path)
   return

 if SceneTransitionManager.is_transitioning:
  return
 var change_error: Error = SceneTransitionManager.transition_menu_to(
  scene_path, 1
 )
 if change_error != OK:
  _navigating=false
  push_error(
   "EventCenterScreen: gagal membuka scene. Error code: "
   + str(change_error)
  )
