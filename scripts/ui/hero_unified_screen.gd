extends Control

## One HERO page. Gameplay/save authority stays in the existing managers.
const Visual=preload("res://scripts/ui/equipment_visual_catalog.gd")
const Sets=preload("res://scripts/data/equipment_set_catalog.gd")
const Nav=preload("res://scripts/ui/wuxia_hub_nav.gd")
const HERO_SERIF: Font=preload("res://assets/ui/library/fonts/archive_serif.ttf")
const GOLD: Color=Color(0.95,0.79,0.43)
const JADE: Color=Color(0.40,0.92,0.80)
const TEXT: Color=Color(0.90,0.95,0.94)
const SLOTS: Array[String]=["armament","robe","bracer","pendant","boots"]
const SLOT_NAMES: Array[String]=["SENJATA","JUBAH","LENGAN","LIONTIN","SEPATU"]
const FILTERS: Array[String]=["all","armament","robe","bracer","pendant","boots","material"]
@onready var content: Control=$Content
var scroll: ScrollContainer
var fixed_deck: VBoxContainer
var page: VBoxContainer
var grid: GridContainer
var nav: Control
var filter_id: String="all"
var sort_id: int=0
var query: String=""
var selected_item_id: String=""
var detail: Control
var detail_open: bool=false
var pending_refresh: bool=false
var unit: float=1.0
var drag_start: Vector2
var card_buttons: Dictionary={}
var filter_menu: OptionButton
var search_box: LineEdit
var sheet_mode: String="item"
var sheet_panel: PanelContainer
var sheet_scroll: ScrollContainer
var sheet_body: VBoxContainer
var sheet_actions: VBoxContainer
var sheet_root: VBoxContainer
var popup_unit: float=1.0
var building_popup: bool=false
var sheet_generation: int=0
var loadout_refresh_pending: bool=false
var equip_action_pending: bool=false
var detail_progress_key: String=""
var inventory_sync_pending: bool=false
var detail_values: Dictionary={}
var detail_set_header: Label
var detail_set_lines: Array[Label]=[]
var header_count: Label
var last_layout_size: Vector2=Vector2(-1,-1)
var _build_count: int=0
var _last_build_usec: int=0
var _relic_styles: Dictionary={}
var _relic_pressed: StyleBoxFlat

func _ready() -> void:
 var bg:=ColorRect.new();bg.color=Color(.006,.028,.033);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(bg);move_child(bg,0);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fixed_deck=VBoxContainer.new();fixed_deck.name="FixedHeroLoadout";content.add_child(fixed_deck)
 scroll=ScrollContainer.new();scroll.name="HeroScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER;scroll.follow_focus=false;scroll.scroll_deadzone=10
 content.add_child(scroll)
 page=VBoxContainer.new();page.name="UnifiedPage";page.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page.add_theme_constant_override("separation",12);scroll.add_child(page)
 nav=Nav.new();nav.name="HubNav";nav.active_tab=2;content.add_child(nav)
 content.resized.connect(_layout)
 EquipmentManager.equipment_changed.connect(_on_equipment_changed)
 InventoryManager.inventory_changed.connect(_on_inventory_changed)
 SaveManager.save_write_completed.connect(_on_save_write_completed)
 SceneTransitionManager.set_back_handler(handle_system_back)
 _layout()

func _layout() -> void:
 if not is_instance_valid(scroll) or content.size.is_equal_approx(last_layout_size):return
 last_layout_size=content.size
 unit=clampf(content.size.x/648.0,.49,1.65)
 if content.size.y<620 and content.size.x>content.size.y: unit=minf(unit,1.0)
 var side: float=12.0*unit
 var nav_h: float=82.0
 nav.position=Vector2(side,content.size.y-nav_h-8.0*unit);nav.size=Vector2(content.size.x-side*2,nav_h)
 fixed_deck.position=Vector2(side,78.0)
 fixed_deck.size.x=content.size.x-side*2
 page.custom_minimum_size.x=content.size.x-side*2
 fixed_deck.custom_minimum_size.x=page.custom_minimum_size.x
 _queue_refresh()

func _queue_refresh() -> void:
 if pending_refresh:return
 pending_refresh=true;_refresh_all.call_deferred()

func _on_equipment_changed(_slot: String,_id: String) -> void:
 if loadout_refresh_pending:return
 loadout_refresh_pending=true;_refresh_loadout.call_deferred()

func _on_save_write_completed(domain: String,_result: Dictionary) -> void:
 if domain=="progression":_on_equipment_changed("","")

func _on_inventory_changed(_id: String,_count: int) -> void:
 if inventory_sync_pending:return
 inventory_sync_pending=true;_sync_inventory.call_deferred()

func _sync_inventory() -> void:
 inventory_sync_pending=false
 if not is_instance_valid(grid) or pending_refresh:return
 var ids: Array[String]=_visible_item_ids()
 var old_ids: Array=card_buttons.keys()
 if ids.size()!=old_ids.size() or ids.any(func(id: String):return not card_buttons.has(id)):_rebuild_grid()
 else:
  for i: int in range(ids.size()):grid.move_child(card_buttons[ids[i]],i)
 var owned: int=0
 for id: String in InventoryManager.get_owned_item_ids():
  if EquipmentManager.has_item_definition(id):owned+=1
 header_count.text="KOLEKSI %d/%d"%[owned,EquipmentManager.get_item_ids().size()]
 _refresh_loadout()

func _detail_progress_key() -> String:
 return "%s:%d:%d:%d"%[selected_item_id,EquipmentManager.get_loadout_item_star(selected_item_id),EquipmentManager.get_item_weapon_level(selected_item_id),InventoryManager.get_item_count(selected_item_id)]

func _refresh_loadout() -> void:
 loadout_refresh_pending=false
 if not is_instance_valid(page) or pending_refresh:return
 var ids: Array[String]=_equipped_ids()
 for slot: String in SLOTS:
  var button: Button=content.find_child("Slot_"+slot,true,false) as Button
  if button!=null:_sync_slot(button,EquipmentManager.get_loadout_equipped_item_id(slot))
 for id: String in card_buttons:
  _sync_refine_dot(card_buttons[id], id)
  var mark: CanvasItem=card_buttons[id].get_node_or_null("EquippedMark")
  if mark!=null:mark.visible=id in ids
  var card: Button=card_buttons[id]
  var rank: Label=card.get_node_or_null("ItemRank")
  if rank!=null:rank.text=_stars(EquipmentManager.get_loadout_item_star(id)) if EquipmentManager.has_item_definition(id) else "×%d"%InventoryManager.get_item_count(id)
 var state: Dictionary=Sets.get_dominant_set_state(ids)
 var summary: Label=content.find_child("SetName",true,false) as Label
 if summary!=null:summary.text=(str(state.display_name) if int(state.piece_count)>0 else "BELUM ADA SET")+"  •  %d/4"%int(state.piece_count)
 if detail_open:
  if sheet_mode=="stats":_show_stats(true)
  else:_sync_detail_loadout()

func _sync_slot(button: Button,id: String) -> void:
 if str(button.get_meta("item_id","unset"))==id:
  _sync_refine_dot(button,id);return
 button.set_meta("item_id",id)
 for child: Node in button.get_children():button.remove_child(child);child.queue_free()
 button.text="+" if id.is_empty() else ""
 button.add_theme_stylebox_override("normal",_style(JADE))
 button.add_theme_stylebox_override("hover",_style(JADE))
 if not id.is_empty():
  _skin_card(button,str(EquipmentManager.get_item_data(id).get("rarity","common")))
  var icon:=_texture(Visual.get_icon_path(id));button.add_child(icon);icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  icon.offset_left=9;icon.offset_right=-9;icon.offset_top=9;icon.offset_bottom=-9
 _sync_refine_dot(button,id)

func _sync_detail_loadout() -> void:
 if not is_instance_valid(sheet_actions):return
 if not InventoryManager.owns_item(selected_item_id):_close_detail();return
 if not EquipmentManager.has_item_definition(selected_item_id):
  if detail_values.has("material"):detail_values.material.text="MATERIAL • Jumlah %d"%InventoryManager.get_item_count(selected_item_id)
  return
 var equip: Button=sheet_actions.find_child("EquipAction",true,false) as Button
 if equip!=null:
  var equipped: bool=selected_item_id in _equipped_ids()
  equip.text="LEPAS" if equipped else "PASANG"
  equip.disabled=not EquipmentManager.can_modify_equipment()
  _bind_action(equip,_equip_selected.bind(selected_item_id,equipped,sheet_generation))
 var id: String=selected_item_id
 var star: int=EquipmentManager.get_loadout_item_star(id)
 if detail_values.has("stars"):detail_values.stars.text=_stars(star)
 if detail_values.has("stats"):detail_values.stats.text=Visual.get_stat_summary(EquipmentManager.get_effective_item_data(id))
 if detail_values.has("copies"):detail_values.copies.text="DUPLIKAT IDENTIK %d • Naik bintang memakai 1 duplikat; item utama tetap dimiliki."%maxi(InventoryManager.get_item_count(id)-1,0)
 if detail_values.has("level"):detail_values.level.text="LEVEL WEAPON %d / %d • +%d%% damage weapon"%[EquipmentManager.get_item_weapon_level(id),EquipmentManager.get_weapon_level_cap(id),roundi((EquipmentManager.get_weapon_level_multiplier(id)-1)*100)]
 var key: String=_detail_progress_key()
 var ascend: Button=sheet_actions.find_child("AscendAction",true,false) as Button
 if ascend!=null:
  ascend.text="NAIK BINTANG" if star<5 else "BINTANG MAX"
  ascend.disabled=not EquipmentManager.can_ascend_item(id)
  _bind_upgrade_action(ascend,id,"star",key)
 var level: Button=sheet_actions.find_child("LevelAction",true,false) as Button
 if level!=null:
  level.text="NAIK LEVEL • %d Spirit Stone"%EquipmentManager.get_weapon_level_cost(id)
  if EquipmentManager.get_item_weapon_level(id)>=EquipmentManager.get_weapon_level_cap(id):level.text="LEVEL MAX • PERLU BINTANG" if star<5 else "LEVEL MAX 50"
  level.disabled=not EquipmentManager.can_level_weapon(id)
  _bind_upgrade_action(level,id,"level",key)
 detail_progress_key=key
 var set_id: String=Sets.get_set_id_for_item(selected_item_id)
 var pieces: int=Sets.get_piece_count(set_id,_equipped_ids())
 if is_instance_valid(detail_set_header):detail_set_header.text="%s • SET %s • %d/4"%[Sets.get_display_name(set_id),Sets.get_set_rarity(set_id).to_upper(),pieces]
 for i: int in range(detail_set_lines.size()):
  var label: Label=detail_set_lines[i]
  if not is_instance_valid(label):continue
  var tier: int=i+2
  label.text="%d bagian: %s%s"%[tier,Sets.get_tier_description(set_id,tier),"  ✓ AKTIF" if pieces>=tier else ""]
  label.add_theme_color_override("font_color",JADE if pieces>=tier else TEXT)

func _refresh_all() -> void:
 var started_usec: int=Time.get_ticks_usec()
 pending_refresh=false
 if not is_instance_valid(page):return
 var old_scroll: int=scroll.scroll_vertical
 for container: VBoxContainer in [fixed_deck,page]:
  for child: Node in container.get_children():container.remove_child(child);child.queue_free()
 card_buttons.clear()
 _relic_styles.clear();_relic_pressed=null
 page.add_theme_constant_override("separation",maxi(5,int(10*unit)))
 var backpack: VBoxContainer=page
 page=fixed_deck
 page.add_theme_constant_override("separation",maxi(4,int(8*unit)))
 var heading:=HBoxContainer.new();page.add_child(heading)
 var title:=_label("HERO",26,GOLD);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 var armory:=_button("SERVER ARMORY");armory.custom_minimum_size=Vector2(0,38);heading.add_child(armory)
 armory.pressed.connect(func() -> void: load("res://scripts/ui/paid_armory_panel.gd").open_for(content))
 if content.size.y>=620 or content.size.y>content.size.x:_build_banner()
 _build_slots();_build_resonance()
 page=backpack
 _build_collection()
 _layout_sections.call_deferred()
 scroll.set_deferred("scroll_vertical",old_scroll)
 _build_count+=1;_last_build_usec=Time.get_ticks_usec()-started_usec
 DebugLogger.system("Hero UI ready | builds %d | build %d ms"%[_build_count,roundi(_last_build_usec/1000.0)])
 if detail_open:
  if sheet_mode=="stats":_show_stats(true)
  else:_show_detail(selected_item_id,true)

func _label(value: String,font_size: int=16,tint: Color=TEXT) -> Label:
 var ui_scale: float=popup_unit if building_popup else unit
 var label:=Label.new();label.text=value;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",maxi(12 if building_popup else 9,int(font_size*ui_scale)));label.add_theme_color_override("font_color",tint)
 if font_size>=22:
  label.add_theme_font_override("font",HERO_SERIF)
 label.set_meta("hero_mobile_font_polished",true);label.set_meta(&"jade_mobile_readability_v2",true)
 return label

func _style(accent: Color=JADE) -> StyleBoxFlat:
 var ui_scale: float=popup_unit if building_popup else unit
 var st:=StyleBoxFlat.new();st.bg_color=Color(.008,.045,.049,.98);st.border_color=Color(accent,.6)
 st.set_border_width_all(1);st.border_width_bottom=3;st.set_corner_radius_all(8)
 st.shadow_color=Color(0,0,0,.35);st.shadow_size=5;st.shadow_offset=Vector2(0,2)
 st.content_margin_left=12*ui_scale;st.content_margin_right=12*ui_scale;st.content_margin_top=8*ui_scale;st.content_margin_bottom=8*ui_scale
 return st

func _button(value: String,primary: bool=false) -> Button:
 var ui_scale: float=popup_unit if building_popup else unit
 var button:=Button.new();button.text=value;button.custom_minimum_size.y=maxf(44,48*ui_scale)
 button.add_theme_font_size_override("font_size",maxi(13,int(16*ui_scale)))
 button.add_theme_color_override("font_color",GOLD if primary else TEXT)
 button.add_theme_stylebox_override("normal",_style(GOLD if primary else JADE))
 if primary:
  var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/system_v2/custom/buttons/primary_selected.svg");skin.texture_margin_left=12;skin.texture_margin_right=12;skin.texture_margin_top=10;skin.texture_margin_bottom=10
  button.add_theme_stylebox_override("normal",skin)
 var pressed: StyleBoxFlat=_style(GOLD);pressed.bg_color=Color(.03,.18,.17);pressed.shadow_size=0
 button.add_theme_stylebox_override("pressed",pressed);button.add_theme_stylebox_override("hover",pressed)
 button.set_meta("hero_mobile_font_polished",true);button.set_meta(&"jade_mobile_readability_v2",true)
 button.mouse_filter=Control.MOUSE_FILTER_PASS
 return button

func _texture(path: String) -> TextureRect:
 var view:=TextureRect.new()
 var cache: Node=get_node_or_null("/root/MenuResourcePrewarm")
 view.texture=cache.get_hub_texture(path) if cache!=null and cache.has_method("get_hub_texture") else load(path) as Texture2D;view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.mouse_filter=Control.MOUSE_FILTER_IGNORE
 view.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 return view

func _build_banner() -> void:
 var banner:=Control.new();banner.name="HeroBanner";banner.clip_contents=true;banner.custom_minimum_size.y=maxf(80,142*unit);page.add_child(banner)
 var bg:=_texture("res://assets/ui/hero/imperial_v4/sanctuary_banner.png");bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 banner.add_child(bg);bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var actor:=_texture("res://assets/ui/hero/lin_yue_menu_showcase_v2.png");actor.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 banner.add_child(actor);actor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);actor.anchor_left=.48;actor.anchor_bottom=0;actor.offset_top=0;actor.offset_bottom=450*unit
 var nameplate:=_label("LIN YUE",30,GOLD);banner.add_child(nameplate);nameplate.position=Vector2(18,28)*unit
 var subtitle:=_label("PENGEMBARA GIOK",12);banner.add_child(subtitle);subtitle.position=Vector2(18,66)*unit
 var status:=_label("✓ LOADOUT SIAP",12,JADE);banner.add_child(status);status.position=Vector2(18,109)*unit
 if EquipmentManager.has_preserved_active_run_loadout():status.text="PERUBAHAN UNTUK RUN BARU"

func _rarity_color(id: String) -> Color:
 return {"legendary":GOLD,"epic":Color(.74,.44,.98),"rare":Color(.37,.75,.97),"common":Color(.29,.69,.53)}.get(id,JADE)

func _skin_card(button: Button,rarity: String) -> void:
 if not _relic_styles.has(rarity):
  var st:=StyleBoxTexture.new();st.texture=load("res://assets/ui/system_v2/custom/cards/relic_card_"+rarity+".svg") as Texture2D
  st.texture_margin_left=8;st.texture_margin_right=8;st.texture_margin_top=8;st.texture_margin_bottom=8
  _relic_styles[rarity]=st
 if _relic_pressed==null:_relic_pressed=_style(GOLD)
 var normal: StyleBox=_relic_styles[rarity]
 button.add_theme_stylebox_override("normal",normal);button.add_theme_stylebox_override("hover",normal)
 button.add_theme_stylebox_override("pressed",_relic_pressed)

func _relic_button() -> Button:
 # Collection cards install rarity skins directly, without creating discarded CTA skins.
 var card:=Button.new()
 card.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;card.focus_mode=Control.FOCUS_NONE
 card.mouse_filter=Control.MOUSE_FILTER_PASS
 card.add_theme_color_override("font_color",TEXT)
 card.set_meta("hero_mobile_font_polished",true);card.set_meta(&"jade_mobile_readability_v2",true)
 return card

func _build_slots() -> void:
 var row:=HBoxContainer.new();row.name="EquippedSlots";row.add_theme_constant_override("separation",6);page.add_child(row)
 var side: float=(page.custom_minimum_size.x-24)/5
 for i: int in range(SLOTS.size()):
  var box:=VBoxContainer.new();box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(box)
  var id: String=EquipmentManager.get_loadout_equipped_item_id(SLOTS[i])
  var button:=_button("");button.custom_minimum_size=Vector2(0,minf(side,48) if content.size.y<620 and content.size.x>content.size.y else side);button.name="Slot_"+SLOTS[i];box.add_child(button)
  button.tooltip_text=SLOT_NAMES[i]
  _sync_slot(button,id)
  button.pressed.connect(_slot_pressed.bind(SLOTS[i]))
  var label:=_label(SLOT_NAMES[i],12);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;box.add_child(label)

func _equipped_ids() -> Array[String]:
 var ids: Array[String]=[]
 for slot: String in SLOTS:
  var id: String=EquipmentManager.get_loadout_equipped_item_id(slot)
  if not id.is_empty():ids.append(id)
 return ids

func _build_resonance() -> void:
 var panel:=PanelContainer.new();panel.name="SetSummary";panel.add_theme_stylebox_override("panel",_style(GOLD));page.add_child(panel)
 var row:=HBoxContainer.new();panel.add_child(row)
 var state: Dictionary=Sets.get_dominant_set_state(_equipped_ids())
 var set_display_name: String=str(state.display_name) if int(state.piece_count)>0 else "BELUM ADA SET"
 var text:=_label(set_display_name+"  •  %d/4"%int(state.piece_count),14,GOLD);text.name="SetName";text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;row.add_child(text)
 var button:=_button("STATISTIK ›");row.add_child(button);button.pressed.connect(_show_stats)

func _build_collection() -> void:
 var heading:=HBoxContainer.new();page.add_child(heading)
 var title:=_label("BACKPACK",22,GOLD);title.name="BackpackTitle";title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 var equipment_count: int=0
 for id: String in InventoryManager.get_owned_item_ids():
  if EquipmentManager.has_item_definition(id):equipment_count+=1
 header_count=_label("KOLEKSI %d/%d"%[equipment_count,EquipmentManager.get_item_ids().size()],12,JADE);heading.add_child(header_count)
 var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",8);page.add_child(controls)
 filter_menu=OptionButton.new();filter_menu.name="Filter";filter_menu.custom_minimum_size.y=44;filter_menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for title_value: String in ["SEMUA","SENJATA","JUBAH","LENGAN","LIONTIN","SEPATU","MATERIAL"]:filter_menu.add_item(title_value)
 filter_menu.select(maxi(FILTERS.find(filter_id),0));controls.add_child(filter_menu)
 filter_menu.item_selected.connect(func(index: int):filter_id=FILTERS[index];_rebuild_grid())
 var sort:=OptionButton.new();sort.custom_minimum_size.y=44;sort.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for value: String in ["RARITAS","NAMA","BINTANG"]:sort.add_item(value)
 sort.select(sort_id);controls.add_child(sort);sort.item_selected.connect(func(index: int):sort_id=index;_rebuild_grid())
 var search_button:=_button("⌕");search_button.custom_minimum_size.x=44;controls.add_child(search_button)
 search_button.pressed.connect(func():
  search_box.visible=not search_box.visible
  if search_box.visible:search_box.grab_focus())
 for control: OptionButton in [filter_menu,sort]:
  _polish_dropdown(control)
  control.set_meta("hero_mobile_font_polished",true);control.set_meta(&"jade_mobile_readability_v2",true)
 search_box=LineEdit.new();search_box.name="Search";search_box.placeholder_text="Cari equipment / material…";search_box.text=query;search_box.custom_minimum_size.y=44;search_box.visible=not query.is_empty()
 search_box.add_theme_font_size_override("font_size",maxi(13,int(15*unit)));page.add_child(search_box)
 search_box.text_changed.connect(func(value: String):query=value;_rebuild_grid())
 grid=GridContainer.new();grid.name="BackpackGrid";grid.columns=5;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",8);page.add_child(grid)
 _rebuild_grid()
 page.add_child(_label("Ketuk item untuk detail • Geser untuk melihat koleksi",12,Color(.6,.74,.72)))

func _visible_item_ids() -> Array[String]:
 var ids: Array[String]=[]
 for id: String in InventoryManager.get_owned_item_ids():
  var data: Dictionary=InventoryManager.get_item_data(id)
  if filter_id=="material" and InventoryManager.get_item_type(id)!="material":continue
  if filter_id not in ["all","material"] and str(data.get("slot",""))!=filter_id:continue
  if not query.is_empty() and not str(data.get("display_name",id)).to_lower().contains(query.to_lower()):continue
  ids.append(id)
 ids.sort_custom(func(a: String,b: String):
  if sort_id==1:return str(InventoryManager.get_item_data(a).get("display_name",a))<str(InventoryManager.get_item_data(b).get("display_name",b))
  if sort_id==2 and EquipmentManager.get_item_star(a)!=EquipmentManager.get_item_star(b):return EquipmentManager.get_item_star(a)>EquipmentManager.get_item_star(b)
  var ranks: Dictionary={"legendary":3,"epic":2,"rare":1,"common":0}
  var ra: int=int(ranks.get(InventoryManager.get_item_data(a).get("rarity",""),-1))
  var rb: int=int(ranks.get(InventoryManager.get_item_data(b).get("rarity",""),-1))
  return ra>rb if ra!=rb else a<b)
 return ids

func _rebuild_grid() -> void:
 if not is_instance_valid(grid):return
 for child: Node in grid.get_children():grid.remove_child(child);child.queue_free()
 card_buttons.clear()
 var ids: Array[String]=_visible_item_ids()
 var side: float=(page.custom_minimum_size.x-24)/5.0
 for id: String in ids:
  var data: Dictionary=InventoryManager.get_item_data(id)
  var is_equipment: bool=EquipmentManager.has_item_definition(id)
  var card:=_relic_button();card.name="Relic_"+id;card.custom_minimum_size=Vector2(side,side+maxf(22,28*unit));grid.add_child(card);card_buttons[id]=card
  _skin_card(card,str(data.get("rarity","rare")))
  var icon:=_texture(Visual.get_icon_path(id));card.add_child(icon);icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  icon.offset_left=8*unit;icon.offset_top=7*unit;icon.offset_right=-8*unit;icon.offset_bottom=-maxf(24,30*unit)
  card.tooltip_text=str(data.get("display_name",id))
  var label:=_label(_stars(EquipmentManager.get_loadout_item_star(id)) if is_equipment else "×%d"%InventoryManager.get_item_count(id),12,GOLD)
  label.name="ItemRank"
  label.add_theme_font_size_override("font_size",maxi(11,int(16*unit)));label.add_theme_constant_override("outline_size",1)
  card.add_child(label);label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);label.offset_top=-maxf(22,28*unit);label.offset_bottom=-2;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  if is_equipment:
   _build_equipped_mark(card,side)
  _sync_refine_dot(card,id)
  card.button_down.connect(func():drag_start=get_global_mouse_position())
  card.pressed.connect(_card_pressed.bind(id))
 if ids.is_empty() and page.get_node_or_null("EmptyResult")==null:
  var empty_label:=_label("Belum ada item yang cocok.",16);page.add_child(empty_label);empty_label.name="EmptyResult"
 var empty: Node=page.get_node_or_null("EmptyResult")
 if not ids.is_empty() and empty!=null:empty.queue_free()

func _build_equipped_mark(card: Button,side: float) -> void:
 var mark:=Control.new();mark.name="EquippedMark";mark.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(mark);mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var frame:=_texture("res://assets/ui/hero/equipped/equipped_frame.svg");frame.stretch_mode=TextureRect.STRETCH_SCALE;mark.add_child(frame);frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var badge:=PanelContainer.new();badge.name="EquippedBadge";badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;mark.add_child(badge)
 badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);badge.offset_left=4;badge.offset_right=-4;badge.offset_top=4;badge.offset_bottom=maxf(17,20*unit)
 var skin:=StyleBoxFlat.new();skin.bg_color=Color(.035,.24,.21,.97);skin.border_color=GOLD;skin.set_border_width_all(1);skin.set_corner_radius_all(3)
 badge.add_theme_stylebox_override("panel",skin)
 var caption:=_label("✓ AKTIF" if side<80 else "TERPAKAI",11,GOLD);caption.name="EquippedCaption";caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.add_child(caption)
 mark.visible=str(card.name).trim_prefix("Relic_") in _equipped_ids()

func _stars(rank: int) -> String:
 return "★".repeat(clampi(rank,0,5))+"☆".repeat(5-clampi(rank,0,5))

func _card_pressed(id: String) -> void:
 if card_buttons.has(id) and bool(card_buttons[id].get_meta("jade_scroll_cancelled",false)):return
 if get_global_mouse_position().distance_to(drag_start)>12:return
 _show_detail(id)

func _slot_pressed(slot: String) -> void:
 var paid: Node=PavilionManager.paid_gameplay
 if is_instance_valid(paid) and not str(paid.call("selected_slot",slot)).is_empty():
  load("res://scripts/ui/paid_armory_panel.gd").open_for(content,str(paid.call("selected_slot",slot)));return
 var id: String=EquipmentManager.get_loadout_equipped_item_id(slot)
 if id.is_empty():filter_id=slot;filter_menu.select(maxi(FILTERS.find(slot),0));_rebuild_grid();scroll.set_deferred("scroll_vertical",0)
 else:_show_detail(id)

func _close_detail() -> void:
 detail_open=false;sheet_generation+=1
 if is_instance_valid(detail):detail.queue_free()
 detail=null

func _make_sheet(mode: String="item") -> VBoxContainer:
 if is_instance_valid(detail):content.remove_child(detail);detail.queue_free()
 sheet_mode=mode;sheet_generation+=1
 detail_set_header=null;detail_set_lines.clear();detail_values.clear()
 detail=Control.new();detail.name="ItemDetail";content.add_child(detail);detail.z_index=80
 detail.position=Vector2(0,76);detail.size=Vector2(content.size.x,maxf(80,nav.position.y-82))
 popup_unit=minf(unit,maxf(.7,detail.size.y/700.0))
 building_popup=true
 var dim:=ColorRect.new();dim.color=Color(0,0,0,.62);detail.add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 dim.gui_input.connect(func(event: InputEvent):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:_close_detail())
 sheet_panel=PanelContainer.new();sheet_panel.name="DetailPanel";sheet_panel.self_modulate.a=0.0;detail.add_child(sheet_panel)
 var skin: StyleBoxFlat=_style(GOLD);skin.border_width_top=2;skin.border_width_bottom=3;skin.shadow_size=12
 sheet_panel.add_theme_stylebox_override("panel",skin)
 sheet_root=VBoxContainer.new();sheet_root.add_theme_constant_override("separation",8);sheet_panel.add_child(sheet_root)
 var top:=HBoxContainer.new();top.name="PopupHeader";sheet_root.add_child(top)
 var title:=_label("STATISTIK LOADOUT" if mode=="stats" else "DETAIL RELIK",20,GOLD);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;top.add_child(title)
 var close:=_button("×");close.custom_minimum_size.x=44;close.pressed.connect(_close_detail);top.add_child(close)
 sheet_scroll=ScrollContainer.new();sheet_scroll.name="DescriptionScroll";sheet_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;sheet_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO;sheet_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;sheet_scroll.scroll_deadzone=8;sheet_root.add_child(sheet_scroll)
 _polish_scrollbar(sheet_scroll.get_v_scroll_bar())
 sheet_body=VBoxContainer.new();sheet_body.name="DetailBody";sheet_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sheet_body.size_flags_vertical=Control.SIZE_SHRINK_BEGIN;sheet_body.add_theme_constant_override("separation",8);sheet_scroll.add_child(sheet_body)
 sheet_actions=VBoxContainer.new();sheet_actions.name="PopupActions";sheet_actions.add_theme_constant_override("separation",6);sheet_root.add_child(sheet_actions)
 _fit_sheet.call_deferred(sheet_generation)
 return sheet_body

func _fit_sheet(expected_generation: int=-1) -> void:
 if expected_generation<0:expected_generation=sheet_generation
 await get_tree().process_frame
 if expected_generation!=sheet_generation or not is_instance_valid(detail) or not is_instance_valid(sheet_panel):return
 var width: float=minf(560.0*unit,detail.size.x-24.0*unit)
 var max_height: float=minf((470.0 if sheet_mode=="stats" else 580.0)*popup_unit,detail.size.y*.72)
 sheet_panel.position=Vector2((detail.size.x-width)*.5,0)
 sheet_panel.size=Vector2(width,max_height)
 var skin: StyleBox=sheet_panel.get_theme_stylebox("panel")
 sheet_body.custom_minimum_size.x=maxf(0,width-skin.get_minimum_size().x-12)
 await get_tree().process_frame
 if expected_generation!=sheet_generation or not is_instance_valid(detail) or not is_instance_valid(sheet_panel):return
 var fixed: float=sheet_root.get_child(0).get_combined_minimum_size().y+sheet_actions.get_combined_minimum_size().y+skin.get_minimum_size().y+16
 var natural: float=sheet_body.get_combined_minimum_size().y+fixed
 var height: float=minf(max_height,maxf(fixed+44,natural))
 sheet_scroll.custom_minimum_size.y=maxf(44,height-fixed)
 sheet_panel.size=Vector2(width,height)
 sheet_panel.position.y=maxf(8,(detail.size.y-height)*.5)
 sheet_panel.self_modulate.a=1.0

func _polish_dropdown(control: OptionButton) -> void:
 control.fit_to_longest_item=false;control.clip_text=true;control.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 control.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;control.focus_mode=Control.FOCUS_NONE
 control.add_theme_constant_override("arrow_margin",8)
 var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/system_v2/custom/buttons/secondary_normal.svg")
 skin.texture_margin_left=12;skin.texture_margin_right=12;skin.texture_margin_top=10;skin.texture_margin_bottom=10
 skin.content_margin_left=14;skin.content_margin_right=28;skin.content_margin_top=8;skin.content_margin_bottom=8
 for state: String in ["normal","normal_mirrored","hover","pressed"]:control.add_theme_stylebox_override(state,skin)
 control.add_theme_font_size_override("font_size",maxi(14,int(16*unit)));control.add_theme_color_override("font_color",GOLD)
 control.add_theme_icon_override("arrow",load("res://assets/ui/hero/compact_popup/dropdown_arrow.svg"))
 var menu: PopupMenu=control.get_popup()
 var panel: StyleBoxFlat=_style(GOLD);panel.bg_color=Color(.007,.043,.048,.99);panel.border_width_top=2;panel.shadow_size=10
 menu.add_theme_stylebox_override("panel",panel)
 var hover: StyleBoxFlat=_style(JADE);hover.bg_color=Color(.025,.17,.16);hover.shadow_size=0
 menu.add_theme_stylebox_override("hover",hover)
 menu.add_theme_font_size_override("font_size",maxi(14,int(16*unit)))
 menu.add_theme_color_override("font_color",TEXT);menu.add_theme_color_override("font_hover_color",GOLD)
 menu.add_theme_color_override("font_disabled_color",Color(.43,.55,.53))
 menu.add_theme_constant_override("v_separation",maxi(16,int(20*unit)))
 menu.add_theme_icon_override("radio_checked",load("res://assets/ui/hero/compact_popup/radio_selected.svg"))
 menu.add_theme_icon_override("radio_unchecked",load("res://assets/ui/hero/compact_popup/radio_unselected.svg"))
 menu.add_theme_constant_override("item_start_padding",10);menu.add_theme_constant_override("item_end_padding",12)

func _paragraph(body: VBoxContainer,value: String,font_size: int=16,color: Color=TEXT) -> void:
 if value.is_empty():return
 var label:=_label(value,font_size,color);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(label)

func _show_detail(id: String,force: bool=false) -> void:
 if not force and detail_open and sheet_mode=="item" and selected_item_id==id and detail_progress_key==_detail_progress_key():return
 if not InventoryManager.owns_item(id):_close_detail();return
 selected_item_id=id;detail_open=true
 detail_progress_key=_detail_progress_key()
 var body: VBoxContainer=_make_sheet("item")
 var data: Dictionary=InventoryManager.get_item_data(id)
 var stage:=Control.new();stage.name="RelicArtStage";stage.clip_contents=true;stage.custom_minimum_size.y=120*popup_unit;body.add_child(stage)
 var landscape:=_texture("res://assets/ui/hero/imperial_v4/sanctuary_banner.png");landscape.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;landscape.modulate=Color(.45,.58,.55);stage.add_child(landscape);landscape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var icon:=_texture(Visual.get_icon_path(id));icon.name="DetailIcon";stage.add_child(icon);icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);icon.offset_top=8;icon.offset_bottom=-8
 _paragraph(body,str(data.get("display_name",id)),24,GOLD)
 if not EquipmentManager.has_item_definition(id):
  _paragraph(body,"MATERIAL • Jumlah %d"%InventoryManager.get_item_count(id),16,JADE)
  detail_values.material=body.get_child(body.get_child_count()-1)
  _paragraph(body,str(data.get("description","")));building_popup=false;return
 var star: int=EquipmentManager.get_loadout_item_star(id)
 var effective: Dictionary=EquipmentManager.get_effective_item_data(id)
 _paragraph(body,str(data.get("rarity","common")).to_upper()+"  •  "+SLOT_NAMES[maxi(SLOTS.find(str(data.get("slot",""))),0)],15,JADE)
 _paragraph(body,_stars(star),24,GOLD)
 detail_values.stars=body.get_child(body.get_child_count()-1)
 _paragraph(body,Visual.get_stat_summary(effective),18)
 detail_values.stats=body.get_child(body.get_child_count()-1)
 var weapon: bool=str(data.get("slot",""))=="armament"
 if weapon:
  _paragraph(body,"LEVEL WEAPON %d / %d • +%d%% damage weapon"%[EquipmentManager.get_item_weapon_level(id),EquipmentManager.get_weapon_level_cap(id),roundi((EquipmentManager.get_weapon_level_multiplier(id)-1)*100)],17,JADE)
  detail_values.level=body.get_child(body.get_child_count()-1)
  _paragraph(body,"Weapon berdiri sendiri, tidak dihitung sebagai bagian set. Level permanen ini berbeda dari refinement Lv.1–7 selama run.",14)
 else:
  var set_id: String=Sets.get_set_id_for_item(id)
  var pieces: int=Sets.get_piece_count(set_id,_equipped_ids())
  _paragraph(body,"%s • SET %s • %d/4"%[Sets.get_display_name(set_id),Sets.get_set_rarity(set_id).to_upper(),pieces],16,GOLD)
  detail_set_header=body.get_child(body.get_child_count()-1) as Label
  for tier: int in [2,3,4]:
   _paragraph(body,"%d bagian: %s%s"%[tier,Sets.get_tier_description(set_id,tier),"  ✓ AKTIF" if pieces>=tier else ""],14,JADE if pieces>=tier else TEXT)
   detail_set_lines.append(body.get_child(body.get_child_count()-1) as Label)
 _paragraph(body,Visual.get_signature_effect_name(data),16,GOLD)
 _paragraph(body,Visual.get_signature_effect_description(data),14)
 _paragraph(body,"DUPLIKAT IDENTIK %d • Naik bintang memakai 1 duplikat; item utama tetap dimiliki."%maxi(InventoryManager.get_item_count(id)-1,0),14)
 detail_values.copies=body.get_child(body.get_child_count()-1)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);sheet_actions.add_child(row)
 var equip:=_button("LEPAS" if id in _equipped_ids() else "PASANG",true);equip.name="EquipAction";equip.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(equip)
 equip.disabled=not EquipmentManager.can_modify_equipment();_bind_action(equip,_equip_selected.bind(id,id in _equipped_ids(),sheet_generation))
 var ascend:=_button("NAIK BINTANG" if star<5 else "BINTANG MAX");ascend.name="AscendAction";ascend.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(ascend)
 ascend.disabled=not EquipmentManager.can_ascend_item(id);_bind_upgrade_action(ascend,id,"star",detail_progress_key)
 if id in ["jade_binding_chain","celestial_returning_glaive"]:
  var demo:=_button("DEMO SENJATA");demo.name="DemoAction";body.add_child(demo);_bind_action(demo,_open_binding_preview.bind(id,sheet_generation))
 if weapon:
  var level:=_button("NAIK LEVEL • %d Spirit Stone"%EquipmentManager.get_weapon_level_cost(id),true);level.name="LevelAction";sheet_actions.add_child(level)
  level.disabled=not EquipmentManager.can_level_weapon(id)
  if EquipmentManager.get_item_weapon_level(id)>=EquipmentManager.get_weapon_level_cap(id):level.text="LEVEL MAX • PERLU BINTANG" if star<5 else "LEVEL MAX 50"
  _bind_upgrade_action(level,id,"level",detail_progress_key)
 building_popup=false

func _equip_selected(expected_id: String="",expected_equipped: Variant=null,generation: int=-1) -> void:
 if generation>=0 and generation!=sheet_generation:return
 if equip_action_pending or not detail_open or sheet_mode!="item":return
 if not expected_id.is_empty() and expected_id!=selected_item_id:return
 var equipped: bool=selected_item_id in _equipped_ids()
 if expected_equipped!=null and bool(expected_equipped)!=equipped:return
 if not EquipmentManager.can_modify_equipment():return
 equip_action_pending=true
 var slot: String=str(EquipmentManager.get_item_data(selected_item_id).get("slot",""))
 if equipped:EquipmentManager.unequip_slot(slot)
 else:EquipmentManager.equip_item(selected_item_id)
 _sync_detail_loadout()
 _release_equip_action.call_deferred()

func _bind_action(button: Button,callback: Callable) -> void:
 var previous: Callable=button.get_meta("hero_action",Callable())
 if previous.is_valid() and button.pressed.is_connected(previous):button.pressed.disconnect(previous)
 button.pressed.connect(callback);button.set_meta("hero_action",callback)

func _bind_upgrade_action(button: Button,id: String,kind: String,key: String) -> void:
 _bind_action(button,_upgrade_selected.bind(id,kind,key,sheet_generation))

func _upgrade_selected(id: String,kind: String,key: String,generation: int) -> void:
 if equip_action_pending or not detail_open or sheet_mode!="item" or generation!=sheet_generation:return
 if id!=selected_item_id or key!=_detail_progress_key() or not EquipmentManager.can_modify_equipment():return
 if kind=="star" and not EquipmentManager.can_ascend_item(id):return
 if kind=="level" and not EquipmentManager.can_level_weapon(id):return
 if kind not in ["star","level"]:return
 equip_action_pending=true
 if kind=="star":EquipmentManager.ascend_item(id)
 else:EquipmentManager.level_weapon(id)
 _sync_detail_loadout()
 _release_equip_action.call_deferred()

func _release_equip_action() -> void:
 equip_action_pending=false

func _show_stats(force: bool=false) -> void:
 if not force and detail_open and sheet_mode=="stats":return
 selected_item_id="";detail_open=true
 var body: VBoxContainer=_make_sheet("stats")
 _paragraph(body,"Bonus loadout untuk run berikutnya.",14)
 var ids: Array[String]=_equipped_ids()
 var metrics: Array[Array]=[
  ["HP","+%.1f"%(EquipmentManager.get_loadout_total_max_health_bonus()+Sets.get_gameplay_bonus("max_health_flat",ids))],
  ["DAMAGE","+%.1f%%"%((EquipmentManager.get_loadout_damage_multiplier()-1+Sets.get_gameplay_bonus("damage_bonus",ids))*100)],
  ["MOVEMENT","+%.1f%%"%((EquipmentManager.get_loadout_movement_speed_multiplier()-1+Sets.get_gameplay_bonus("movement_speed_bonus",ids))*100)],
  ["EXP","+%.1f%%"%((EquipmentManager.get_loadout_experience_multiplier()-1+Sets.get_gameplay_bonus("experience_bonus",ids))*100)],
  ["CRITICAL CHANCE","+%.1f%%"%((EquipmentManager.get_loadout_critical_chance_bonus()+Sets.get_gameplay_bonus("critical_chance_bonus",ids))*100)],
  ["SET ARMOR","%.0f%%"%(float(Sets.get_active_passive(ids).get("reduction",0.0))*100)]
 ]
 var stats_grid:=GridContainer.new();stats_grid.name="StatsGrid";stats_grid.columns=2;stats_grid.add_theme_constant_override("h_separation",8);stats_grid.add_theme_constant_override("v_separation",8);body.add_child(stats_grid)
 for metric: Array in metrics:
  var tile:=PanelContainer.new();tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tile.add_theme_stylebox_override("panel",_style(JADE));stats_grid.add_child(tile)
  var column:=VBoxContainer.new();column.add_theme_constant_override("separation",2);tile.add_child(column)
  var caption:=_label(str(metric[0]),12,JADE);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(caption)
  column.add_child(_label(str(metric[1]),20,GOLD))
 var state: Dictionary=Sets.get_dominant_set_state(ids)
 if int(state.piece_count)>0:
  _paragraph(body,"%s • %d/4"%[str(state.display_name),int(state.piece_count)],16,GOLD)
  for tier: int in [2,3,4]:_paragraph(body,"%d bagian: %s"%[tier,Sets.get_tier_description(str(state.set_id),tier)],14,JADE if int(state.piece_count)>=tier else TEXT)
 else:_paragraph(body,"Pasang equipment yang sekeluarga untuk mengaktifkan bonus set.",14)
 building_popup=false

func handle_system_back() -> void:
 for preview: String in ["ReturningGlaivePreview","JadeBindingPreview"]:
  if get_node_or_null(preview)!=null:get_node(preview).queue_free();return
 if is_instance_valid(detail):_close_detail();return
 SceneTransitionManager.transition_menu_to("res://scenes/ui/main_menu.tscn",-1)

func _open_binding_preview(expected_id: String="",generation: int=-1) -> void:
 if not detail_open or sheet_mode!="item":return
 if generation>=0 and generation!=sheet_generation:return
 if not expected_id.is_empty() and expected_id!=selected_item_id:return
 var glaive: bool=selected_item_id=="celestial_returning_glaive"
 var name_value: String="ReturningGlaivePreview" if glaive else "JadeBindingPreview"
 if get_node_or_null(name_value)!=null:return
 var script: Script=load("res://scripts/ui/returning_glaive_preview.gd" if glaive else "res://scripts/ui/jade_binding_preview.gd")
 add_child(script.new())

func _polish_scrollbar(bar: VScrollBar) -> void:
 var track:=StyleBoxFlat.new();track.bg_color=Color(.09,.25,.23,.45);track.set_corner_radius_all(3)
 track.content_margin_left=3;track.content_margin_right=3;track.content_margin_top=0;track.content_margin_bottom=0
 bar.add_theme_stylebox_override("scroll",track)
 var thumb:=StyleBoxFlat.new();thumb.bg_color=Color(.33,.77,.64,.8);thumb.set_corner_radius_all(3)
 thumb.content_margin_left=3;thumb.content_margin_right=3;thumb.content_margin_top=0;thumb.content_margin_bottom=0
 for state: String in ["grabber","grabber_highlight","grabber_pressed"]:bar.add_theme_stylebox_override(state,thumb)
 var blank: ImageTexture=ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8))
 for name_value: String in ["increment","increment_highlight","increment_pressed","decrement","decrement_highlight","decrement_pressed"]:bar.add_theme_icon_override(name_value,blank)

func _sync_refine_dot(card: Button, id: String) -> void:
 var dot: Panel = card.get_node_or_null("RefineReadyDot") as Panel
 var upgrade_available: bool = not id.is_empty() and (EquipmentManager.can_ascend_item(id) or EquipmentManager.can_level_weapon(id))
 if dot == null and not upgrade_available: return
 if dot == null:
  dot = Panel.new();dot.name="RefineReadyDot";dot.mouse_filter=Control.MOUSE_FILTER_IGNORE;dot.z_index=3
  card.add_child(dot);dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
  var side: float=clampf(13*unit,10,17)
  dot.offset_left=-side-5;dot.offset_right=-5;dot.offset_top=5;dot.offset_bottom=side+5
  var skin:=StyleBoxFlat.new();skin.bg_color=Color(.94,.13,.17);skin.border_color=Color(1,.81,.48);skin.set_border_width_all(1);skin.set_corner_radius_all(9)
  skin.shadow_color=Color(.55,.02,.07,.32);skin.shadow_size=3;dot.add_theme_stylebox_override("panel",skin)
 dot.visible=upgrade_available

func _layout_sections() -> void:
 if not is_instance_valid(fixed_deck):return
 var height: float=fixed_deck.get_combined_minimum_size().y
 fixed_deck.size=Vector2(page.custom_minimum_size.x,height)
 scroll.position=Vector2(fixed_deck.position.x,fixed_deck.position.y+height+8)
 scroll.size=Vector2(page.custom_minimum_size.x,maxf(40,nav.position.y-scroll.position.y-8))
