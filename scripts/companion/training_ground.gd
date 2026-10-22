extends Node2D
## Production player, weapons and enemy damage code, isolated from Journey/rewards.
const Sheet=preload("res://scripts/companion/player_journal.gd")
const Skill=preload("res://scripts/data/skill_catalog.gd")
const ATTACKS: Array[String]=["spirit_sword","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation"]
var player: CharacterBody2D
var targets: Array[Node2D]=[]
var elapsed: float=0
var moving: bool=false
var _owner: String
var _report: Label
var _levels: OptionButton
var _skills: OptionButton
var _safe: Control
var _camera: Camera2D
var _resetting: bool=false
var _readout_timer: float=0
var _panel: PanelContainer
var _joystick: Control
func _ready() -> void:
 EquipmentManager.capture_practice_loadout()
 set_meta("companion_practice",true);_owner=PlayerCompanion.account_key
 _camera=Camera2D.new();_camera.position=Vector2(324,576);add_child(_camera)
 var background:=CanvasLayer.new();background.layer=-10;add_child(background)
 var art:=TextureRect.new();art.texture=load("res://assets/ui/cultivation/cultivation_inner_sea_sanctum_v6.png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.modulate=Color(.42,.50,.51);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);background.add_child(art)
 var hud:=CanvasLayer.new();add_child(hud)
 _safe=Control.new();_safe.set_script(preload("res://scripts/ui/mobile_safe_area.gd"));hud.add_child(_safe);_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
 _safe.add_child(margin)
 _panel=PanelContainer.new();_panel.add_theme_stylebox_override("panel",Sheet.skin(16));margin.add_child(_panel)
 var panel: PanelContainer=_panel
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
 var heading:=HBoxContainer.new();box.add_child(heading);var back: Button=Sheet.button("‹",_back);back.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;back.custom_minimum_size.x=44;back.add_theme_font_size_override("font_size",24);heading.add_child(back);var title: Label=Sheet.label(Sheet.copy("TRAINING GROUNDS","ARENA LATIHAN"),18,Sheet.GOLD);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 box.add_child(Sheet.label(Sheet.copy("Current gear · no cost, rewards, XP or Journey progress.","Gear saat ini · tanpa biaya, reward, XP atau progres Journey."),13))
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);box.add_child(row)
 _skills=OptionButton.new();_skills.custom_minimum_size=Vector2(0,48);_skills.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for id: String in ATTACKS:_skills.add_item(Skill.get_upgrade_display_name(id))
 _skills.fit_to_longest_item=false;_skills.clip_text=true;_skills.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
 box.add_child(_skills);box.move_child(_skills,row.get_index());_levels=OptionButton.new();_levels.custom_minimum_size=Vector2(74,48)
 for level: int in [1,3,5,7]:_levels.add_item("Lv."+str(level))
 _levels.fit_to_longest_item=false;_levels.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE
 row.add_child(_levels);row.add_child(Sheet.button(Sheet.copy("SET","PAKAI"),_set_skill))
 var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",8);box.add_child(controls)
 controls.add_child(Sheet.button(Sheet.copy("RESET TEST","RESET UJI"),_reset))
 var move:=CheckButton.new();move.text=Sheet.copy("Moving targets","Target bergerak");move.custom_minimum_size.y=48;move.toggled.connect(func(value: bool):moving=value);controls.add_child(move)
 _report=Sheet.label("",16,Sheet.JADE);box.add_child(_report)
 var joystick: Control=load("res://scripts/ui/virtual_joystick.gd").new();_joystick=joystick;joystick.activation_top_ratio=0.0;joystick.name="TrainingJoystick";joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.add_child(joystick)
 joystick.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _rebuild(false);SceneTransitionManager.set_back_handler(_back)
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(_safe)
func _spawn_targets() -> void:
 for target: Node2D in targets:
  if is_instance_valid(target):target.queue_free()
 targets.clear()
 for i: int in range(3):
  var target: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate()
  target.add_to_group("companion_training_target");target.max_hp=1000000000.0;target.contact_damage=0
  add_child(target);target.set_physics_process(false);target.collision_layer=2;target.collision_mask=0
  target.global_position=Vector2(240+i*80,450);targets.append(target)
func _set_skill() -> void:
 if _resetting:return
 _resetting=true;_rebuild.call_deferred(true)
func _reset() -> void:
 if _resetting:return
 _resetting=true;_rebuild.call_deferred(false)
func _rebuild(apply_skill: bool) -> void:
 # Every projectile/zone is owned by this scene. Reset discards them together,
 # so delayed hits cannot contaminate the next measurement.
 for child: Node in get_children():
  if child is Node2D and child!=_camera:
   remove_child(child);child.queue_free()
 targets.clear();elapsed=0;_readout_timer=0
 player=load("res://scenes/player/player_1.tscn").instantiate();player.name="player_1"
 # The level normally supplies health. Real blade/shield skills require it here too.
 var health:=Node.new();health.set_script(preload("res://scripts/player/PlayerHealth.gd"));health.name="PlayerHealth";health.max_health=100.0;player.add_child(health)
 add_child(player);player.collision_layer=0;player.collision_mask=0;player.position=Vector2(324,620)
 _spawn_targets()
 if apply_skill:
  var manager: Node=player.get_node("WeaponManager")
  var id: String=ATTACKS[_skills.selected]
  if id!="spirit_sword":manager.call("add_"+id)
  var names: Array[String]=["Spirit Sword","Fire Orb","Thunder Talisman","Yin-Yang Blades","Heavenly Sword Rain","Eight Trigrams Formation"]
  var weapon: Node=manager.get_weapon_by_name(names[_skills.selected])
  var requested: int=[1,3,5,7][_levels.selected]
  if weapon!=null:
   for step: int in range(6):
    var before: int=int(weapon.level)
    if before>=requested:break
    weapon.upgrade()
    if int(weapon.level)<=before:break
 _resetting=false
func _process(delta: float) -> void:
 if not is_instance_valid(player):return
 if PlayerCompanion.account_key!=_owner:_back();return
 _fit_arena()
 elapsed+=delta
 player.position=player.position.clamp(Vector2(72,330),Vector2(576,920))
 for i: int in range(targets.size()):
  if is_instance_valid(targets[i]):targets[i].position=Vector2(240+i*80+sin(elapsed*1.4+float(i))*55 if moving else 240+i*80,450+sin(elapsed+float(i))*35 if moving else 450)
 _readout_timer-=delta
 if _readout_timer>0:return
 _readout_timer=.15
 var total: float=0
 var ledger: Node=player.get_node("WeaponManager/RunCombatLedger")
 for value: Variant in ledger.totals.values():total+=float(value)
 var text: PackedStringArray=["%.1fs · %s DMG · %s DPS"%[elapsed,preload("res://scripts/ui/readable_numbers.gd").compact(roundi(total)),preload("res://scripts/ui/readable_numbers.gd").compact(roundi(total/maxf(elapsed,.1)))]]
 for row: Dictionary in ledger.damage_rows().slice(0,3):
  if float(row.damage)>0:text.append(str(row.name)+" · "+preload("res://scripts/ui/readable_numbers.gd").compact(roundi(float(row.damage))))
 _report.text="\n".join(text)
func _fit_arena() -> void:
 if not is_instance_valid(_panel) or not is_instance_valid(_joystick):return
 var view: Vector2=get_viewport_rect().size
 var top: float=minf(_panel.get_global_rect().end.y+12,maxf(100,view.y-100))
 _joystick.offset_top=top
 var zoom_value: float=clampf(minf((view.x-32)/504.0,(view.y-top-24)/590.0),.12,1.2)
 _camera.zoom=Vector2.ONE*zoom_value
 _camera.position=Vector2(324,625-top/(2*zoom_value))
func _back() -> void:
 if SceneTransitionManager.is_transitioning:return
 SceneTransitionManager.transition_menu_to("res://scenes/ui/skill_book_screen.tscn")
func _exit_tree() -> void:
 EquipmentManager.practice_items.clear();EquipmentManager.practice_levels.clear()
 for action: String in ["ui_left","ui_right","ui_up","ui_down"]:Input.action_release(action)
