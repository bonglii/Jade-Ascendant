extends Node
## Pause-owned optional choices. No grants, extra projectiles or account writes.
const Policy=preload("res://scripts/data/run_path_policy.gd")
const Sheet=preload("res://scripts/companion/player_journal.gd")
const Scroll=preload("res://scripts/ui/mobile_scroll_policy.gd")
const SafeArea=preload("res://scripts/ui/mobile_safe_area.gd")
const SERIF: Font=preload("res://assets/ui/library/fonts/archive_serif.ttf")
const EMBER_ICON: Texture2D=preload("res://assets/ui/level_up/skill_art/fire_orb.png")
const WIND_ICON: Texture2D=preload("res://assets/ui/level_up/skill_art/movement_speed.png")
const BOON_HEIGHT: float=476.0
const ALTAR_FRAME: Texture2D=preload("res://assets/ui/system_v2/custom/frames/relic_altar_v2.svg")
const EMBER_FRAME: Texture2D=preload("res://assets/ui/settings/neo/command_card_gold.svg")
const WIND_FRAME: Texture2D=preload("res://assets/ui/settings/neo/command_card_aqua.svg")
var _modal: CanvasLayer
var _left: float=1.0
var _key: String=""
var _previous_back: Callable
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
func _process(delta: float) -> void:
	if is_instance_valid(_modal) or get_tree().paused or EquipmentManager.is_practice():return
	_left-=delta
	if _left>0:return
	_left=.35
	var manager: Node=get_parent()
	var world: Node=manager.get_parent().get_parent()
	var wave: Node=world.get_node_or_null("WaveManager")
	var health: Node=manager.get_parent().get_node_or_null("PlayerHealth")
	if wave==null or health==null or health.is_dead:return
	if int(wave.current_wave)>=3 and str(manager.run_paths.boon).is_empty():
		_offer("boon",Sheet.copy("ALTAR OF TWO WINDS","ALTAR DUA ANGIN"),[])
		return
	for index: int in range(Policy.ARTS.size()):
		var id: String=Policy.ARTS[index]
		var weapon: Node=manager.get_weapon_by_name(Policy.NAMES[index])
		if weapon!=null and int(weapon.level)>=5 and not manager.run_paths.arts.has(id):
			_offer(id,Policy.NAMES[index]+Sheet.copy(" · CHOOSE A PATH"," · PILIH JALUR"),[
				["focus",Sheet.copy("GUARDIAN FOCUS · +20% direct damage to bosses, −10% to other enemies.","FOKUS PENJAGA · +20% damage langsung ke boss, −10% ke musuh lain.")],
				["sweep",Sheet.copy("VALLEY SWEEP · +15% direct damage to other enemies, −10% to bosses.","SAPUAN LEMBAH · +15% damage langsung ke musuh lain, −10% ke boss.")],
				["balanced",Sheet.copy("BALANCED ART · retain the original damage.","ART SEIMBANG · pertahankan damage asli.")]])
			return
func _offer(key: String,title: String,choices: Array) -> void:
	if is_instance_valid(_modal):return
	_key=key
	var boon: bool=key=="boon"
	_modal=CanvasLayer.new();_modal.name="RunPathChoice";_modal.layer=80;add_child(_modal)
	var root:=Control.new();_modal.add_child(root);root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil:=ColorRect.new();veil.color=Color(.005,.016,.025,.72 if boon else .88);root.add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe:=SafeArea.new();safe.name="ChoiceSafeArea";root.add_child(safe);safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new();panel.name="PathPanel";panel.add_theme_stylebox_override("panel",Sheet.skin(14));safe.add_child(panel)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",8);panel.add_child(body)
	var heading: Label=Sheet.label(title,22,Sheet.GOLD)
	heading.add_theme_font_override("font",SERIF)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if boon:
		var banner := PanelContainer.new()
		banner.name = "AltarBanner"
		banner.add_theme_stylebox_override("panel", _altar_frame(ALTAR_FRAME, 9))
		body.add_child(banner)
		var titles := VBoxContainer.new()
		titles.add_theme_constant_override("separation", 2)
		banner.add_child(titles)
		var eyebrow: Label=Sheet.label(Sheet.copy("◆  WAVE 3 · CHOOSE ONE BOON  ◆","◆  WAVE 3 · PILIH SATU BERKAH  ◆"),12,Sheet.JADE)
		eyebrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		titles.add_child(eyebrow)
		titles.add_child(heading)
	else:
		body.add_child(heading)
	var caption: String=Sheet.copy("This run only · Continue keeps your choice.","Hanya run ini · pilihan tersimpan saat Continue.") if boon else Sheet.copy("This run only · chosen once · Continue keeps your choice. Set DoT ticks receive no additional path multiplier.","Hanya run ini · satu pilihan · Continue menyimpan pilihanmu. Tick DoT set tidak dikalikan ulang oleh cabang.")
	var hint: Label=Sheet.label(caption,14)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hint)
	var scroll:=ScrollContainer.new()
	scroll.name="PathChoicesScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",8);scroll.add_child(list)
	if boon:
		list.add_child(_boon_card("ember",Sheet.copy("EMBER OATH","SUMPAH BARA"),EMBER_ICON,Color("f4ba72")))
		list.add_child(_boon_card("wind",Sheet.copy("WIND OATH","SUMPAH ANGIN"),WIND_ICON,Sheet.JADE))
		var skip: Button=Sheet.button(Sheet.copy("CONTINUE WITHOUT BOON","LANJUT TANPA BERKAH"),_pick.bind("none"))
		skip.name="Path_none"
		body.add_child(skip)
	else:
		for choice: Array in choices:
			var action: Button=Sheet.button(str(choice[1]),_pick.bind(str(choice[0])))
			action.name="Path_"+str(choice[0]);action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action.custom_minimum_size.y=76;list.add_child(action)
	var fit: Callable=func():
		if safe.size.x<=24 or safe.size.y<=24:return
		panel.size=Vector2(minf(500,safe.size.x-24),minf(BOON_HEIGHT if boon else 426,safe.size.y-24))
		panel.position=(safe.size-panel.size)*.5
	Scroll.prepare_tree(root)
	safe.resized.connect(fit,CONNECT_DEFERRED)
	panel.minimum_size_changed.connect(fit,CONNECT_DEFERRED)
	fit.call_deferred()
	_previous_back=SceneTransitionManager.back_handler
	SceneTransitionManager.set_back_handler(_cancel)
	get_tree().paused=true
	if boon:
		AudioManager.play_sfx("achievement_unlock")
		if SettingsManager.haptics and OS.has_feature("android"):
			Input.vibrate_handheld(32)
		if not SettingsManager.reduced_effects:
			panel.modulate.a=0.0
			create_tween().tween_property(panel,"modulate:a",1.0,.22)

func _boon_card(id: String, title: String, art: Texture2D, accent: Color) -> Button:
	var action: Button=Sheet.button("",_pick.bind(id))
	action.name="Path_"+id
	action.custom_minimum_size.y=104
	var style: StyleBoxTexture = _altar_frame(EMBER_FRAME if id == "ember" else WIND_FRAME, 12)
	action.add_theme_stylebox_override("normal",style)
	var active: StyleBoxTexture=style.duplicate()
	active.modulate_color=Color(1.20, 1.16, 1.10)
	action.add_theme_stylebox_override("pressed",active)
	action.add_theme_stylebox_override("hover",active)
	var row:=HBoxContainer.new()
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",10)
	action.add_child(row);row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left=13;row.offset_right=-13;row.offset_top=9;row.offset_bottom=-9
	var icon:=TextureRect.new()
	icon.texture=art;icon.custom_minimum_size.x=48;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text:=VBoxContainer.new()
	text.mouse_filter=Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	text.alignment=BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation",2)
	row.add_child(text)
	text.add_child(Sheet.label(title,16,accent))
	var chosen: Dictionary={"boon":id}
	var damage: String="%+.0f%% %s"%[(Policy.multiplier(chosen,"spirit_sword",false)-1.0)*100.0,Sheet.copy("direct art damage","damage langsung art")]
	var movement: String="%+.0f%% %s"%[(Policy.movement(chosen)-1.0)*100.0,Sheet.copy("movement speed","kecepatan gerak")]
	var gain: String=damage if id=="ember" else movement
	var cost: String=movement if id=="ember" else damage
	text.add_child(Sheet.label(gain,14,Sheet.JADE))
	text.add_child(Sheet.label(cost,14,Color("f6a089")))
	var arrow: Label = Sheet.label("›", 23, accent)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(arrow)
	row.minimum_size_changed.connect(func():
		action.custom_minimum_size.y = maxf(104.0, row.get_combined_minimum_size().y + 18.0)
	)
	action.accessibility_name="%s. %s. %s"%[title,gain,cost]
	return action

func _altar_frame(texture: Texture2D, padding: int) -> StyleBoxTexture:
	var frame := StyleBoxTexture.new()
	frame.texture = texture
	for edge: String in ["left", "right", "top", "bottom"]:
		frame.set("texture_margin_" + edge, 18.0)
		frame.set("content_margin_" + edge, padding)
	return frame

func _pick(value: String) -> void:
	if not is_instance_valid(_modal):return
	var manager: Node=get_parent()
	if _key=="boon":manager.run_paths.boon=value
	else:manager.run_paths.arts[_key]=value
	manager.run_paths=Policy.clean(manager.run_paths)
	_restore_back()
	_modal.queue_free();_modal=null
	get_tree().paused=false
	var checkpoint: Node=manager.get_parent().get_parent().get_node_or_null("CheckPointManager")
	if checkpoint!=null:checkpoint.save_checkpoint()
func _cancel() -> void:
	if is_instance_valid(_modal):_pick("none" if _key=="boon" else "balanced")
func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(_modal) and event.is_action_pressed("ui_cancel") and not event.is_echo():
		_cancel();get_viewport().set_input_as_handled()
func _restore_back() -> void:
	if is_instance_valid(SceneTransitionManager) and SceneTransitionManager.back_handler==Callable(self,"_cancel"):
		SceneTransitionManager.set_back_handler(_previous_back)
func _exit_tree() -> void:
	_restore_back()
	if is_instance_valid(_modal):get_tree().paused=false
