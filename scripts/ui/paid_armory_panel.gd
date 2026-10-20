extends Control
## Compact, scroll-safe authenticated armory. No local paid inventory writes.
const Visual = preload("res://scripts/ui/equipment_visual_catalog.gd")
const ArmoryFrame = preload("res://scripts/ui/pavilion_imperial_style.gd")
const GOLD = Color(0.95,0.79,0.43)
const JADE = Color(0.40,0.92,0.80)
var _paid: Node
var _body: VBoxContainer
var _scroll: ScrollContainer
var _panel: PanelContainer
var _selected: String = ""
var _pending: bool = false
var _target_picker: bool = false
var _old_back: Callable
var _blocked_until: int = 0
var _touch: Vector2
static func open_for(parent: Node, item_id: String = "") -> void:
	if parent.get_node_or_null("ServerArmory") != null: return
	var sheet := load("res://scripts/ui/paid_armory_panel.gd").new() as Control
	sheet.name = "ServerArmory"; sheet.set("_selected", item_id)
	parent.add_child(sheet)
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); z_index = 200
	_paid = PavilionManager.paid_gameplay
	_old_back = SceneTransitionManager.back_handler; SceneTransitionManager.set_back_handler(_close)
	var veil := ColorRect.new(); veil.color=Color(0.002,0.015,0.02,0.96); veil.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(veil); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel=PanelContainer.new(); add_child(_panel)
	var skin:=ArmoryFrame.new(); skin.selected=true; _panel.add_theme_stylebox_override("panel",skin)
	_scroll=ScrollContainer.new(); _scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_SHOW_NEVER; _scroll.scroll_deadzone=10; _scroll.follow_focus=false
	_panel.add_child(_scroll)
	_scroll.scroll_started.connect(_block_touch); _scroll.scroll_ended.connect(_block_touch)
	_body=VBoxContainer.new(); _body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation",10); _scroll.add_child(_body)
	resized.connect(_fit); _fit()
	if is_instance_valid(_paid): _paid.connect("changed",_queue_draw)
	_redraw()
func _fit() -> void:
	if not is_instance_valid(_panel): return
	var safe: Vector2 = Vector2(maxf(220,size.x-24), maxf(120,size.y-24))
	_panel.size=Vector2(minf(590,safe.x),minf(780,safe.y))
	_panel.position=(size-_panel.size)*0.5
func _close() -> void:
	if SceneTransitionManager.back_handler == Callable(self,"_close"):
		SceneTransitionManager.set_back_handler(_old_back if _old_back.is_valid() else Callable())
	queue_free()
func _exit_tree() -> void:
	if SceneTransitionManager.back_handler == Callable(self,"_close"):
		SceneTransitionManager.set_back_handler(_old_back if _old_back.is_valid() else Callable())
func _block_touch() -> void:
	_blocked_until=Time.get_ticks_msec()+180
func _queue_draw() -> void:
	if _pending: return
	_pending=true; call_deferred("_redraw")
func _text(parent: Node, text: String, color: Color = Color(0.88,0.94,0.92), font_size: int = 14) -> Label:
	var label:=Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color",color); label.add_theme_font_size_override("font_size",font_size)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(label); return label
func _button(parent: Node, text: String, action: Callable, color: Color = GOLD) -> Button:
	var button:=Button.new(); button.text=text; button.custom_minimum_size=Vector2(0,48)
	button.clip_text=true; button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode=Control.FOCUS_NONE; button.mouse_filter=Control.MOUSE_FILTER_PASS
	var skin:=ArmoryFrame.new(); skin.tint=color
	button.add_theme_stylebox_override("normal",skin); button.add_theme_stylebox_override("hover",skin)
	var pressed:=ArmoryFrame.new(); pressed.pressed=true; pressed.tint=color; button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_font_size_override("font_size",13); parent.add_child(button)
	button.button_down.connect(func() -> void: _touch=get_global_mouse_position())
	button.pressed.connect(func() -> void:
		if Time.get_ticks_msec() < _blocked_until or get_global_mouse_position().distance_to(_touch)>10: return
		_blocked_until=Time.get_ticks_msec()+140
		action.call())
	return button
func _redraw() -> void:
	_pending=false
	if not is_instance_valid(_body): return
	var old_scroll: int=_scroll.scroll_vertical
	for child: Node in _body.get_children(): _body.remove_child(child); child.queue_free()
	_text(_body,"SERVER ARMORY",GOLD,23)
	_button(_body,"CLOSE",_close,JADE)
	if not is_instance_valid(_paid): _text(_body,"Connect your account to view purchased equipment."); return
	_text(_body,"PAID JADE  ·  %d"%int(_paid.call("paid_balance")),JADE,17)
	var verification_ready: bool=bool(_paid.call("is_verified_ready"))
	var busy: bool=bool(_paid.get("busy"))
	_text(_body,"SERVER VERIFIED" if verification_ready else "CONNECT TO VERIFY · "+str(_paid.get("status")),JADE if verification_ready else GOLD)
	_button(_body,"RECOVER / REFRESH",func() -> void: _paid.call("refresh"),JADE).disabled=busy
	_text(_body,"Paid gear stays on your account. Keep a server connection during combat. Unequip its server slot here before replacing it with local gear.")
	var state: Dictionary=_paid.get("snapshot")
	var wish: String=str(state.get("wish",""))
	_button(_body,"TARGET  ·  "+(_name(wish) if not wish.is_empty() else "CHOOSE LEGENDARY"),func() -> void: _target_picker=not _target_picker;_queue_draw()).disabled=busy or not verification_ready
	if _target_picker:
		_button(_body,"CLEAR TARGET",func() -> void: _submit("wish",{"item_id":""})).disabled=busy
		for id: String in EquipmentManager.get_item_ids():
			var data: Dictionary=EquipmentManager.get_item_data(id)
			if data.get("rarity")=="legendary" and not bool(data.get("retired",false)):
				_button(_body,_name(id),_submit.bind("wish",{"item_id":id})).disabled=busy
	if not _selected.is_empty() and int(_paid.call("item_count",_selected))>0:
		_detail(busy)
	var grid:=GridContainer.new(); grid.columns=5; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; _body.add_child(grid)
	for id: String in state.get("inventory",{}):
		var data: Dictionary=EquipmentManager.get_item_data(id)
		var color: Color={"common":Color(0.7,0.78,0.75),"rare":Color(0.35,0.7,1),"epic":Color(0.75,0.45,1),"legendary":GOLD}.get(str(data.get("rarity","common")),GOLD)
		var card:=_button(grid,"",_select.bind(id),color); card.custom_minimum_size=Vector2(0,76)
		var icon:=TextureRect.new(); icon.texture=load(Visual.get_icon_path(id)); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		card.add_child(icon); icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);icon.offset_bottom=-24
		var caption:=_text(card,"★%d · ×%d"%[int(_paid.call("item_star",id)),int(_paid.call("item_count",id))],color,12)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-24;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_scroll.set_deferred("scroll_vertical",old_scroll)
func _name(id: String) -> String:
	return str(EquipmentManager.get_item_data(id).get("display_name",id))
func _select(id: String) -> void:
	_selected=id; _queue_draw()
func _submit(kind: String, args: Dictionary) -> void:
	if is_instance_valid(_paid): _paid.call("submit",kind,args)
func _detail(busy: bool) -> void:
	var data: Dictionary=EquipmentManager.get_item_data(_selected)
	var slot: String=str(data.get("slot",""))
	var equipped: bool=str(_paid.call("selected_slot",slot))==_selected
	_text(_body,_name(_selected),GOLD,19)
	_text(_body,"★".repeat(int(_paid.call("item_star",_selected)))+" · "+slot.to_upper()+" · "+str(data.get("rarity","")))
	var effective: Dictionary=EquipmentManager.call("_build_effective_item_data",_selected,int(_paid.call("item_star",_selected)))
	var stats: Array[String]=[]
	for key: String in ["max_health_flat","damage_bonus","movement_speed_bonus","experience_bonus","critical_chance_bonus"]:
		var amount: float=float(effective.get(key,0.0))
		if amount>0.0: stats.append(key.replace("_"," ").capitalize()+" +"+(str(int(amount)) if key=="max_health_flat" else "%.1f%%"%(amount*100.0)))
	_text(_body," · ".join(PackedStringArray(stats)),JADE)
	_text(_body,str(data.get("signature_effect_description",data.get("signature_effect_name",""))))
	var target: String="" if equipped else _selected
	_button(_body,"UNEQUIP SERVER SLOT" if equipped else "EQUIP",_submit.bind("equip",{"slot":slot,"item_id":target}),JADE).disabled=busy
	_button(_body,"REFINE · 1 IDENTICAL DUPLICATE",_submit.bind("refine",{"item_id":_selected})).disabled=busy or int(_paid.call("item_count",_selected))<2 or int(_paid.call("item_star",_selected))>=5
	if slot=="armament" and equipped:
		var cost: int=EquipmentManager.get_weapon_level_cost(_selected)
		_button(_body,"LEVEL %d/%d · %d SPIRIT STONES"%[EquipmentManager.get_item_weapon_level(_selected),EquipmentManager.get_weapon_level_cap(_selected),cost],_level,JADE).disabled=busy or not EquipmentManager.can_level_weapon(_selected)
func _level() -> void:
	EquipmentManager.level_weapon(_selected); _queue_draw()
