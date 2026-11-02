extends Node
## Pause-owned optional choices. No grants, extra projectiles or account writes.
const Policy=preload("res://scripts/data/run_path_policy.gd")
const Sheet=preload("res://scripts/companion/player_journal.gd")
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
		_offer("boon",Sheet.copy("ALTAR OF TWO WINDS","ALTAR DUA ANGIN"),[
			["ember",Sheet.copy("EMBER OATH · +12% direct art damage, −10% movement.","SUMPAH BARA · +12% damage langsung art, −10% gerak.")],
			["wind",Sheet.copy("WIND OATH · +10% movement, −8% direct art damage.","SUMPAH ANGIN · +10% gerak, −8% damage langsung art.")],
			["none",Sheet.copy("KEEP MY BALANCE · no boon or penalty.","JAGA KESEIMBANGAN · tanpa berkah atau penalti.")]])
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
	_key=key
	_modal=CanvasLayer.new();_modal.name="RunPathChoice";_modal.layer=80;add_child(_modal)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_modal.add_child(root)
	var veil:=ColorRect.new();veil.color=Color(.005,.025,.025,.92);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(veil)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(center)
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",Sheet.skin(18));panel.custom_minimum_size=Vector2(minf(520,get_viewport().get_visible_rect().size.x-32),0);center.add_child(panel)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",12);panel.add_child(body)
	body.add_child(Sheet.label(title,22,Sheet.GOLD))
	body.add_child(Sheet.label(Sheet.copy("This run only · chosen once · Continue keeps your choice. Set DoT ticks receive no additional path/boon multiplier.","Hanya run ini · satu pilihan · Continue menyimpan pilihanmu. Tick DoT set tidak dikalikan ulang oleh cabang/berkah."),15))
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size.y=minf(340,get_viewport().get_visible_rect().size.y*.46);body.add_child(scroll)
	var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
	for choice: Array in choices:
		var action: Button=Sheet.button(str(choice[1]),_pick.bind(str(choice[0])))
		action.name="Path_"+str(choice[0]);action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;action.custom_minimum_size.y=76;list.add_child(action)
	preload("res://scripts/ui/mobile_scroll_policy.gd").configure(scroll)
	preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(root)
	_previous_back=SceneTransitionManager.back_handler
	SceneTransitionManager.set_back_handler(_cancel)
	get_tree().paused=true
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
func _restore_back() -> void:
	if is_instance_valid(SceneTransitionManager) and SceneTransitionManager.back_handler==Callable(self,"_cancel"):
		SceneTransitionManager.set_back_handler(_previous_back)
func _exit_tree() -> void:
	_restore_back()
	if is_instance_valid(_modal):get_tree().paused=false
