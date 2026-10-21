extends Control
## Read-only personal records. Existing Journey remains the only stage launcher.
const Book=preload("res://scripts/data/stage_record_book.gd")
const Skills=preload("res://scripts/data/skill_catalog.gd")
const FRAME=preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
const GOLD=Color("ead19a")
const JADE=Color("7cddba")
var chapter: int=1
var _panel: Panel
var _list: VBoxContainer
var _scroll: ScrollContainer
var _back: Callable
var _filters: Array[Button]=[]
static func open(host: Node, initial_chapter: int=1) -> Control:
 var existing: Node=host.get_node_or_null("StageRecordsPanel")
 if existing!=null:return existing as Control
 var sheet=load("res://scripts/ui/stage_records_panel.gd").new()
 sheet.name="StageRecordsPanel";sheet.chapter=initial_chapter;host.add_child(sheet)
 return sheet
func _ready() -> void:
 z_index=450;process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var veil:=ColorRect.new();veil.color=Color(.005,.018,.025,.78);add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 veil.gui_input.connect(func(event: InputEvent):if event is InputEventMouseButton and event.pressed:close())
 _panel=Panel.new();_panel.name="RecordsPaper";_panel.clip_contents=true;_panel.add_theme_stylebox_override("panel",_skin(20));add_child(_panel)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",10);_panel.add_child(body);body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=20;body.offset_right=-20;body.offset_top=20;body.offset_bottom=-20
 var heading:=HBoxContainer.new();body.add_child(heading)
 heading.add_child(_label(_copy("COMBAT RECORDS","REKOR COMBAT"),22,GOLD))
 var exit:=_button("×");exit.name="CloseRecords";exit.custom_minimum_size=Vector2(44,44);exit.pressed.connect(close);heading.add_child(exit)
 body.add_child(_label(_copy("Your journey. Your next personal best.","Perjalananmu. Lampaui rekor sebelumnya."),14,JADE))
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",4);body.add_child(row)
 for realm: int in JourneyManager.get_chapter_ids():
  var filter:=_button(str(realm));filter.name="RecordRealm"+str(realm);filter.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filter.toggle_mode=true;row.add_child(filter);_filters.append(filter);filter.pressed.connect(_select.bind(realm))
 _scroll=ScrollContainer.new();_scroll.name="StageRecordScroll";_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(_scroll)
 _list=VBoxContainer.new();_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_list.add_theme_constant_override("separation",12);_scroll.add_child(_list)
 body.add_child(_label(_copy("Personal records, not extra rewards. New clears are recorded from this update. Replay from Journey.","Rekor pribadi, tanpa hadiah tambahan. Clear baru dicatat mulai update ini. Replay dari Journey."),12,Color("a5b9b0")))
 resized.connect(_layout);_layout();_refresh()
 _back=SceneTransitionManager.back_handler;SceneTransitionManager.set_back_handler(close)
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(self)
func _copy(en: String,id: String) -> String:return id if SettingsManager.language=="id" else en
func _skin(padding: int) -> StyleBoxTexture:
 var style:=StyleBoxTexture.new();style.texture=FRAME
 for edge: String in ["left","right","top","bottom"]:style.set("texture_margin_"+edge,18);style.set("content_margin_"+edge,padding)
 return style
func _label(value: String,font_size: int,color: Color=GOLD) -> Label:
 var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.set_meta("jade_mobile_readability_v2",true);return label
func _button(value: String) -> Button:
 var button:=Button.new();button.text=value;button.custom_minimum_size.y=44;button.add_theme_font_size_override("font_size",16)
 var normal:=StyleBoxFlat.new();normal.bg_color=Color("13352f");normal.border_color=Color("749a80");normal.set_border_width_all(1);normal.set_corner_radius_all(9)
 var active: StyleBoxFlat=normal.duplicate();active.bg_color=Color("315442");active.border_color=GOLD
 for state: String in ["normal","hover","focus"]:button.add_theme_stylebox_override(state,normal)
 button.add_theme_stylebox_override("pressed",active);return button
func _select(realm: int) -> void:
 if chapter==realm:return
 chapter=realm;_refresh();_scroll.scroll_vertical=0
func _refresh() -> void:
 for button: Button in _filters:button.set_pressed_no_signal(button.text==str(chapter))
 for child: Node in _list.get_children():_list.remove_child(child);child.queue_free()
 _list.add_child(_label(str(JourneyManager.get_chapter_data(chapter).get("display_name","")),19,JADE))
 for stage: int in preload("res://scripts/ui/journey_art_catalog.gd").get_presentation_stage_ids(chapter,JourneyManager.get_stage_ids(chapter)):
  if not JourneyManager.is_stage_implemented(chapter,stage):continue
  var card:=PanelContainer.new();card.name="StageRecord_%d_%d"%[chapter,stage];card.add_theme_stylebox_override("panel",_skin(14));_list.add_child(card)
  var content:=VBoxContainer.new();content.add_theme_constant_override("separation",8);card.add_child(content)
  var title:=HBoxContainer.new();title.add_theme_constant_override("separation",10);content.add_child(title)
  var art_path: String=preload("res://scripts/ui/journey_art_catalog.gd").get_stage_art_path(chapter,stage)
  if art_path.is_empty():art_path=preload("res://scripts/ui/journey_art_catalog.gd").get_realm_vista_path(chapter)
  var art:=TextureRect.new();art.texture=load(art_path);art.custom_minimum_size=Vector2(48,48);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.add_child(art)
  title.add_child(_label("%d–%d · %s"%[chapter,stage,str(JourneyManager.get_stage_data(chapter,stage).get("display_name",""))],17))
  var record: Dictionary=JourneyManager.stage_records.get(JourneyManager.get_stage_key(chapter,stage),{})
  if record.is_empty():
   content.add_child(_label(_copy("Clear again to set a record.","Clear lagi untuk mencatat rekor.") if JourneyManager.is_stage_cleared(chapter,stage) else _copy("No record yet. Clear this stage in Journey.","Belum ada rekor. Selesaikan stage di Journey."),14,Color("b3c4ba")))
   continue
  content.add_child(_label(_copy("BEST %s · %d recorded clears","TERBAIK %s · %d clear tercatat")%[Book.clock(int(record.best_ms)),int(record.clears)],17,JADE))
  var badges:=GridContainer.new();badges.columns=1;badges.add_theme_constant_override("v_separation",4);content.add_child(badges)
  for medal: Array in [[true,_copy("CLEAR","CLEAR")],[record.survivor,_copy("SURVIVOR · no death / revive","SURVIVOR · tanpa mati / revive")],[record.untouched,_copy("UNTOUCHED · no HP lost","UNTOUCHED · tanpa HP berkurang")]]:
   badges.add_child(_label(("✓ " if medal[0] else "○ ")+str(medal[1]),14,JADE if medal[0] else Color("8c9d96")))
  var last: Dictionary=record.last
  var metrics: String=_copy("%d HP hits · %d deaths","%d hit HP · %d kematian")%[int(last.hits),int(last.deaths)] if last.complete else _copy("HP record incomplete · legacy Continue","Catatan HP belum lengkap · Continue lama")
  content.add_child(_label(_copy("LAST %s · ","TERAKHIR %s · ")%Book.clock(int(last.time_ms))+metrics,14,Color("b3c4ba")))
  var total: int=0
  for amount: Variant in last.damage.values():total+=int(amount)
  content.add_child(_label(_copy("Recorded damage %s","Damage tercatat %s")%preload("res://scripts/ui/readable_numbers.gd").compact(total)+( _copy(" · partial"," · parsial") if not last.damage_complete else ""),14,JADE))
  for skill: Dictionary in last.skills:
   var skill_row:=HBoxContainer.new();skill_row.add_theme_constant_override("separation",8);content.add_child(skill_row)
   var icon:=TextureRect.new();icon.texture=load(Skills.get_icon_path(skill.id,skill.get("armament_id","")));icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(28,28);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;skill_row.add_child(icon)
   var title_text: String=Skills.get_upgrade_display_name(skill.id)
   if skill.id=="spirit_sword" and not str(skill.get("armament_id","")).is_empty():title_text=str(preload("res://scripts/data/equipment_catalog.gd").ITEMS.get(skill.armament_id,{}).get("display_name",title_text))
   skill_row.add_child(_label(title_text+" · Lv.%d"%int(skill.level),14,Color("d0d9c8")))
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(_list)
func _layout() -> void:
 if _panel==null:return
 var dims:=Vector2(minf(540,maxf(220,size.x-24)),minf(700,maxf(220,size.y-32)));_panel.size=dims;_panel.position=(size-dims)*.5
func close() -> void:queue_free()
func _exit_tree() -> void:
 if SceneTransitionManager.back_handler==Callable(self,"close"):SceneTransitionManager.set_back_handler(_back if _back.is_valid() else Callable())
