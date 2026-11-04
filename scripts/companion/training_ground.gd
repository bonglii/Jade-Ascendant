extends Node2D
## Production actors and hit ledger; separate from Journey, XP, grants and paid ownership.
const Sheet=preload("res://scripts/companion/player_journal.gd")
const Skill=preload("res://scripts/data/skill_catalog.gd")
const Paths=preload("res://scripts/data/run_path_policy.gd")
const Oath=preload("res://scripts/data/jade_oath_state.gd")
const ATTACKS: Array[String]=["spirit_sword","fire_orb","thunder_talisman","yin_yang_blades","heavenly_sword_rain","eight_trigrams_formation"]
const MODES: Array[String]=["dummy","boss","seal","technique","standard","priority","gauntlet","pattern","rotation"]
const TITLES_EN: Array[String]=["ART MEASUREMENT","GUARDIAN PRACTICE","DEFEND THE SEALS","WEAPON TECHNIQUE","EQUAL-FOOTING TRIAL","BREAK THE WARD","THREE GUARDIANS","READ ONE PATTERN","WEEKLY COURT ITINERARY"]
const TITLES_ID: Array[String]=["PENGUKURAN ART","LATIHAN PENJAGA","PERTAHANKAN SEGEL","TEKNIK SENJATA","UJIAN SETARA","PECAHKAN PELINDUNG","TIGA PENJAGA","BACA SATU POLA","AGENDA PELATARAN MINGGUAN"]
var player: CharacterBody2D
var targets: Array[Node2D]=[]
var elapsed: float=0.0
var moving: bool=false
var mode: String="dummy"
var _owner: String
var _report: Label
var _status: Label
var _hint: Label
var _mode_picker: OptionButton
var _start_button: Button
var _skills: OptionButton
var _levels: OptionButton
var _path_picker: OptionButton
var _boon_picker: OptionButton
var _safe: Control
var _camera: Camera2D
var _panel: PanelContainer
var _joystick: Control
var _setup: Control
var _running: bool=false
var _resetting: bool=false
var _readout_timer: float=0.0
var _spawn_left: float=0.0
var _spawn_index: int=0
var _boss_round: int=0
var _boss: Node2D
var _hits: Dictionary={}
var _seals: int=0
var _seal=Oath.new()
var _known: Array[int]=[]
var _selected_boss: int=1
var _duration: float=30.0
var _outcome: String=""
var _outgoing: float=0.0
var _rotation: Dictionary={}
var _pattern_picker: OptionButton
var _pattern_ids: Array[int]=[]
var _record_context: Dictionary={}
func _active_mode() -> String:return str(_rotation.get("mode","standard")) if mode=="rotation" else mode
func _selected_pattern() -> int:
 if mode=="rotation":
  var requested: int=int(_rotation.get("pattern",0))
  return requested if requested in _pattern_ids else (_pattern_ids[0] if not _pattern_ids.is_empty() else 0)
 return _pattern_ids[_pattern_picker.selected] if _pattern_picker!=null and not _pattern_ids.is_empty() else 0
func _sync_patterns() -> void:
 _pattern_picker.clear();_pattern_ids.clear()
 var actor: Node=load("res://scripts/enemy/boss_1.gd").new()
 actor.configure_encounter(JourneyManager.get_stage_data(1,_selected_boss))
 _pattern_ids.assign(actor.available_ranged_patterns());actor.free()
 for id: int in _pattern_ids:_pattern_picker.add_item([Sheet.copy("Projectile lane","Jalur proyektil"),Sheet.copy("Radial gaps","Celah radial"),Sheet.copy("Lightning marks","Tanda petir"),Sheet.copy("Cross pattern","Pola silang")][id])

func _ready() -> void:
 set_meta("companion_practice",true);set_meta("standard_kit",false)
 EquipmentManager.capture_practice_loadout();_owner=PlayerCompanion.account_key
 for stage: int in range(1,6):
  if ("1-%d"%stage) in PlayerCompanion.state.seen_bosses or JourneyManager.is_stage_cleared(1,stage):_known.append(stage)
 if not _known.is_empty():_selected_boss=_known[0]
 var requested_boss: int=int(get_tree().root.get_meta("practice_boss",0))
 if get_tree().root.has_meta("practice_boss"):get_tree().root.remove_meta("practice_boss")
 var pattern_drill: bool = bool(get_tree().root.get_meta("practice_pattern_drill", false))
 if get_tree().root.has_meta("practice_pattern_drill"):
  get_tree().root.remove_meta("practice_pattern_drill")
 if requested_boss in _known:
  mode = "pattern" if pattern_drill else "boss"
  _selected_boss = requested_boss
 _camera=Camera2D.new();_camera.position=Vector2(324,576);add_child(_camera)
 var background:=CanvasLayer.new();background.layer=-10;add_child(background)
 var art:=TextureRect.new();art.texture=load("res://assets/ui/cultivation/cultivation_inner_sea_sanctum_v6.png");art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.modulate=Color(.32,.43,.41);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.mouse_filter=Control.MOUSE_FILTER_IGNORE;background.add_child(art)
 var hud:=CanvasLayer.new();hud.layer=10;add_child(hud)
 var screen_root:=Control.new();screen_root.name="TrainingScreenRoot";screen_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.add_child(screen_root)
 _safe=Control.new();_safe.name="TrainingSafeArea";_safe.set_script(preload("res://scripts/ui/mobile_safe_area.gd"));screen_root.add_child(_safe);_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_safe.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 for side: String in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,12)
 _safe.add_child(margin);_panel=PanelContainer.new();_panel.add_theme_stylebox_override("panel",Sheet.skin(12));margin.add_child(_panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",8);_panel.add_child(box)
 var heading:=HBoxContainer.new();heading.add_theme_constant_override("separation",8);box.add_child(heading)
 var back: Button=Sheet.button("‹",_back);back.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;back.custom_minimum_size.x=44;heading.add_child(back)
 var title: Label=Sheet.label(Sheet.copy("SECT TRAINING COURT","PELATARAN LATIHAN SEKTE"),20,Sheet.GOLD);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 _mode_picker=OptionButton.new();_mode_picker.name="PracticeMode";_mode_picker.custom_minimum_size.y=48;_mode_picker.fit_to_longest_item=false
 for i: int in range(MODES.size()):
  var goal := "Build"
  if MODES[i] in ["boss", "pattern", "gauntlet"]:
   goal = Sheet.copy("Guardian", "Penjaga")
  elif MODES[i] in ["seal", "priority", "rotation"]:
   goal = Sheet.copy("Challenge", "Tantangan")
  _mode_picker.add_item("%s · %s" % [goal, Sheet.copy(TITLES_EN[i], TITLES_ID[i])])
 _mode_picker.select(MODES.find(mode))
 _mode_picker.item_selected.connect(_select_mode);box.add_child(_mode_picker)
 var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",8);box.add_child(controls)
 _start_button=Sheet.button(Sheet.copy("START","MULAI"),_start);_start_button.name="PracticeStart";controls.add_child(_start_button)
 controls.add_child(Sheet.button(Sheet.copy("SETUP","ATUR"),_configure))
 controls.add_child(Sheet.button(Sheet.copy("RESET","RESET"),_reset))
 _hint=Sheet.label("",14);box.add_child(_hint)
 _status=Sheet.label("",16,Sheet.JADE);box.add_child(_status)
 var footer:=MarginContainer.new();footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);footer.offset_top=-118;footer.offset_bottom=-12;footer.offset_left=12;footer.offset_right=-12;_safe.add_child(footer)
 var report_panel:=PanelContainer.new();report_panel.add_theme_stylebox_override("panel",Sheet.skin(10));footer.add_child(report_panel)
 _report=Sheet.label("",16,Sheet.JADE);report_panel.add_child(_report)
 _joystick=load("res://scripts/ui/virtual_joystick.gd").new();_joystick.activation_top_ratio=0.0;_joystick.name="TrainingJoystick";_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.add_child(_joystick);_joystick.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _build_setup();_rebuild();SceneTransitionManager.set_back_handler(_back)
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(_safe)
func _build_setup() -> void:
 _setup=Control.new();_setup.name="PracticeSetup";_setup.z_index=50;_setup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_safe.add_child(_setup)
 var veil:=ColorRect.new();veil.color=Color(.005,.02,.02,.94);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_setup.add_child(veil)
 var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);_setup.add_child(center)
 var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",Sheet.skin(18));panel.custom_minimum_size=Vector2(minf(520,get_viewport_rect().size.x-32),minf(670,get_viewport_rect().size.y-60));center.add_child(panel)
 var outer:=VBoxContainer.new();outer.add_theme_constant_override("separation",12);panel.add_child(outer)
 outer.add_child(Sheet.label(Sheet.copy("PREPARE YOUR TEST","SIAPKAN UJIMU"),22,Sheet.GOLD))
 var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll);preload("res://scripts/ui/mobile_scroll_policy.gd").configure(scroll)
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",12);scroll.add_child(list)
 list.add_child(Sheet.label(Sheet.copy("No cost, rewards, XP or Journey progress. Equal-footing and technique modes use a fixed kit with no equipment, cultivation or mastery bonuses.","Tanpa biaya, reward, XP atau progres Journey. Mode setara dan teknik memakai kit tetap tanpa bonus equipment, cultivation atau mastery."),16))
 list.add_child(Sheet.label(Sheet.copy("ART TO TEST","ART YANG DIUJI"),14,Sheet.GOLD));_skills=_picker(list)
 for id: String in ATTACKS:_skills.add_item(Skill.get_upgrade_display_name(id))
 list.add_child(Sheet.label(Sheet.copy("ART LEVEL · fixed Lv.5 in technique, Lv.3 in equal-footing","LEVEL ART · tetap Lv.5 pada teknik, Lv.3 pada ujian setara"),14));_levels=_picker(list)
 for level: int in [1,3,5,7]:_levels.add_item("Lv."+str(level))
 list.add_child(Sheet.label(Sheet.copy("SPECIALIZATION · available at art Lv.5","SPESIALISASI · tersedia pada art Lv.5"),14));_path_picker=_picker(list)
 for text: String in [Sheet.copy("Balanced · original damage","Seimbang · damage asli"),Sheet.copy("Guardian Focus · boss +20%, others −10%","Fokus Penjaga · boss +20%, lainnya −10%"),Sheet.copy("Valley Sweep · others +15%, boss −10%","Sapuan Lembah · lainnya +15%, boss −10%")]:_path_picker.add_item(text)
 list.add_child(Sheet.label(Sheet.copy("ALTAR BOON · direct arts only","BERKAH ALTAR · hanya art langsung"),14));_boon_picker=_picker(list)
 for text: String in [Sheet.copy("None","Tanpa berkah"),Sheet.copy("Ember · damage +12%, movement −10%","Bara · damage +12%, gerak −10%"),Sheet.copy("Wind · movement +10%, damage −8%","Angin · gerak +10%, damage −8%")]:_boon_picker.add_item(text)
 var move:=CheckButton.new();move.text=Sheet.copy("Moving measurement targets","Target pengukuran bergerak");move.custom_minimum_size.y=48;move.toggled.connect(func(value: bool):moving=value);list.add_child(move)
 list.add_child(Sheet.label(Sheet.copy("GUARDIAN · encountered Chapter 1 only","PENJAGA · Bab 1 yang sudah ditemui"),14));var boss_picker: OptionButton=_picker(list)
 if _known.is_empty():boss_picker.add_item(Sheet.copy("Encounter a guardian first","Temui penjaga terlebih dahulu"));boss_picker.disabled=true
 else:
  for stage: int in _known:boss_picker.add_item("1-%d · %s"%[stage,str(JourneyManager.get_stage_data(1,stage).boss_name)])
  boss_picker.select(_known.find(_selected_boss))
  boss_picker.item_selected.connect(func(index: int):_selected_boss=_known[index];_sync_patterns())
 list.add_child(Sheet.label(Sheet.copy("PATTERN DRILL · guardian keeps its HP; read one real pattern for 45s","LATIHAN POLA · HP penjaga tetap; baca satu pola asli selama 45 dtk"),14));_pattern_picker=_picker(list);_pattern_picker.name="PracticePattern";_sync_patterns()
 list.add_child(Sheet.label(Sheet.copy("MEASUREMENT WINDOW","JENDELA PENGUKURAN"),14));var window: OptionButton=_picker(list)
 for seconds: int in [15,30,60]:window.add_item("%ds"%seconds)
 window.select(1);window.item_selected.connect(func(index: int):_duration=float([15,30,60][index]))
 var apply: Button=Sheet.button(Sheet.copy("APPLY & RESET","PAKAI & RESET"),func():_setup.hide();_reset());apply.name="PracticeApply";outer.add_child(apply)
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(_setup);_setup.hide()
func _picker(host: Node) -> OptionButton:
 var picker:=OptionButton.new();picker.custom_minimum_size=Vector2(0,48);picker.fit_to_longest_item=false;picker.clip_text=true;host.add_child(picker);return picker
func _configure() -> void:
 if _running:_finish(Sheet.copy("TEST STOPPED","UJI DIHENTIKAN"))
 _setup.show()
func _select_mode(index: int) -> void:
 mode=MODES[index];_reset()
func _reset() -> void:
 if _resetting:return
 _resetting=true;_rebuild.call_deferred()
func _rebuild() -> void:
 _start_button.text=Sheet.copy("START","MULAI")
 _rotation=preload("res://scripts/data/experience_policy.gd").itinerary(int(Time.get_unix_time_from_system())) if mode=="rotation" else {}
 _running=false;_outcome="";_hits.clear();_boss_round=0;_boss=null;_seals=0;elapsed=0;_readout_timer=0;_spawn_left=0;_spawn_index=0;_outgoing=0
 for child: Node in get_children():
  if child is Node2D and child!=_camera:remove_child(child);child.queue_free()
 targets.clear()
 var standard: bool=_active_mode() in ["technique","standard"]
 set_meta("standard_kit",standard)
 EquipmentManager.capture_practice_loadout()
 if standard:EquipmentManager.practice_items.clear();EquipmentManager.practice_levels.clear()
 player=load("res://scenes/player/player_1.tscn").instantiate();player.name="player_1"
 var health:=Node.new();health.set_script(preload("res://scripts/player/PlayerHealth.gd"));health.name="PlayerHealth";health.max_health=100.0;player.add_child(health)
 add_child(player);player.collision_layer=1;player.collision_mask=0;player.position=Vector2(324,640)
 if standard:
  player.get_node("PlayerStats").power_multiplier=1.0;player.get_node("PlayerStats").attack_cooldown=1.0;player.speed=220.0;health.max_health=100.0;health.current_health=100.0;health.qi_shield_charges=0
 health.died.connect(func():if _running:_finish.call_deferred(Sheet.copy("DEFEAT · TRY ANOTHER APPROACH","KALAH · COBA PENDEKATAN LAIN")))
 var manager: Node=player.get_node("WeaponManager");var id: String=ATTACKS[_skills.selected]
 if id!="spirit_sword":manager.call("add_"+id)
 var weapon: Node=manager.get_weapon_by_name(Paths.NAMES[_skills.selected])
 var requested: int=5 if _active_mode()=="technique" else 3 if _active_mode()=="standard" else int([1,3,5,7][_levels.selected])
 if weapon!=null:
  for step: int in range(6):
   if int(weapon.level)>=requested:break
   var before: int=int(weapon.level);weapon.upgrade()
   if int(weapon.level)<=before:break
 if requested>=5 and not standard:manager.run_paths.arts[id]=["balanced","focus","sweep"][_path_picker.selected]
 if not standard:manager.run_paths.boon=["none","ember","wind"][_boon_picker.selected]
 if _active_mode() in ["dummy","technique"]:_spawn_targets()
 _freeze_actors(true);_resetting=false;_refresh_instructions();_readout()
func _refresh_instructions() -> void:
 var descriptions: Dictionary={
  "dummy":Sheet.copy("Current gear · fixed timer · compare total and art damage.","Gear saat ini · timer tetap · bandingkan total dan damage art."),
  "boss":Sheet.copy("An encountered guardian's real patterns. No rewards or stage clear.","Pola asli penjaga yang sudah ditemui. Tanpa reward atau clear stage."),
  "seal":Sheet.copy("75s · charge three Jade Oath seals for 8s each while avoiding enemies.","75 dtk · isi tiga segel Jade Oath masing-masing 8 dtk sambil menghindari musuh."),
  "technique":Sheet.copy("60s · fixed kit Lv.5 · hit three targets using the selected art.","60 dtk · kit tetap Lv.5 · hantam tiga target memakai art pilihan."),
  "standard":Sheet.copy("60s · fixed 100 HP, base power/tempo, chosen art Lv.3. No gear or mastery.","60 dtk · tetap 100 HP, power/tempo dasar, art Lv.3. Tanpa gear atau mastery."),
  "priority":Sheet.copy("60s · destroy the jade ward bearer. Nearby enemies take 35% less damage while protected.","60 dtk · hancurkan pembawa pelindung giok. Musuh dekat menerima 35% lebih sedikit damage selama terlindungi."),
  "gauntlet":Sheet.copy("180s · three known guardians in sequence. HP carries between fights.","180 dtk · tiga penjaga dikenal secara berurutan. HP dibawa antar pertarungan.")}
 descriptions["pattern"]=Sheet.copy("45s · one real guardian pattern, no melee. Guardian takes no damage. Avoid HP hits.","45 dtk · satu pola asli penjaga, tanpa melee. HP penjaga tetap. Hindari hit ke HP.")
 descriptions["rotation"]=str(_rotation.get("title_id" if SettingsManager.language=="id" else "title_en",""))+" · "+str(_rotation.get("goal_id" if SettingsManager.language=="id" else "goal_en",""))+Sheet.copy(" Local schedule · Monday 00:00 WIB · no rewards."," Agenda lokal · Senin 00.00 WIB · tanpa reward.")
 _hint.text=descriptions[mode];_status.text=Sheet.copy("READY · START WHEN PREPARED","SIAP · MULAI SAAT SUDAH SIAP")
 _start_button.disabled=(_active_mode() in ["boss","pattern"] and _known.is_empty()) or (_active_mode()=="gauntlet" and not [1,2,3].all(func(stage: int):return stage in _known))
 if _start_button.disabled:_status.text=Sheet.copy("Encounter the required guardian(s) in Journey first.","Temui penjaga yang diperlukan di Journey terlebih dahulu.")
func _spawn_targets() -> void:
 for i: int in range(3):
  var target: Node2D=_enemy(Vector2(244+i*80,500),false)
  target.max_hp=1000000000.0;target.current_hp=target.max_hp;target.contact_damage=0;target.set_physics_process(false);targets.append(target)
func _enemy(point: Vector2,hostile: bool=true) -> Node2D:
 var target: Node2D=load("res://scenes/enemy/enemy_1.tscn").instantiate();target.add_to_group("companion_training_target");target.set_meta("practice_destructible",hostile)
 if hostile:target.max_hp=45.0;target.speed=55.0;target.contact_damage=6.0
 target.position=point;target.collision_layer=2;target.collision_mask=0;add_child(target);return target
func _start() -> void:
 if _resetting or _start_button.disabled or _running:return
 if not _outcome.is_empty():
  _resetting=true;_retry.call_deferred();return
 _running=true;_start_button.disabled=true;_freeze_actors(false)
 var tested_weapon: Node=player.get_node("WeaponManager").get_weapon_by_name(Paths.NAMES[_skills.selected])
 var tested_level: int=int(tested_weapon.level) if tested_weapon!=null else 1
 _record_context={"revision":1,"mode":mode,"resolved":_active_mode(),"week":int(_rotation.get("week",-1)),"art":ATTACKS[_skills.selected],"level":tested_level,"paths":player.get_node("WeaponManager").run_paths.duplicate(true),"moving":moving,"duration":_duration,"boss":_selected_boss,"pattern":_selected_pattern(),"slots":EquipmentManager.practice_items.duplicate(true),"levels":EquipmentManager.practice_levels.duplicate(true),"stats":[player.get_node("PlayerHealth").max_health,player.get_node("PlayerStats").power_multiplier,player.get_node("PlayerStats").attack_cooldown,player.speed],"mastery":get_node("/root/CultivationMasteryManager").state.duplicate(true)}
 if _active_mode() in ["boss","gauntlet","pattern"]:_spawn_boss(_selected_boss if _active_mode() in ["boss","pattern"] else 1)
 if _active_mode()=="seal":_next_seal()
 if _active_mode()=="priority":
  var bearer: Node2D=_enemy(Vector2(324,420));bearer.name="JadeWardBearer";bearer.max_hp=90.0;bearer.current_hp=90.0;bearer.speed=0.0;bearer.modulate=Color(.55,1,.78)
  var ward: Node2D=preload("res://scripts/gameplay/training_support_ward.gd").new();bearer.add_child(ward)
  for i: int in range(4):_enemy(Vector2(204+i*80,480))
func _retry() -> void:
 _rebuild();_start()
func _spawn_boss(stage: int) -> void:
 _boss_round+=1
 var actor: Node2D=load("res://scenes/enemy/boss_1.tscn").instantiate();actor.configure_encounter(JourneyManager.get_stage_data(1,stage));actor.position=Vector2(324,410);actor.motion_mode=CharacterBody2D.MOTION_MODE_FLOATING;actor.collision_layer=2;actor.collision_mask=0
 if _active_mode()=="pattern":actor.set_meta("practice_pattern",_selected_pattern())
 add_child(actor);_boss=actor
 actor.boss_defeated.connect(func():_boss_defeated.call_deferred())
func _boss_defeated() -> void:
 if not _running:return
 if _active_mode()=="gauntlet" and _boss_round<3:_spawn_boss(_boss_round+1)
 else:_finish(Sheet.copy("GUARDIAN TRIAL COMPLETE","UJIAN PENJAGA SELESAI"),true)

func _next_seal() -> void:
 _seal=Oath.new();_seal.begin(true);_seal.offer([Vector2(240,560),Vector2(410,690),Vector2(324,450)][mini(_seals,2)],5,30.0);queue_redraw()
func _freeze_actors(frozen: bool) -> void:
 for child: Node in get_children():
  if child is Node2D and child!=_camera:child.process_mode=Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT
 if not frozen and _active_mode() in ["dummy","technique"]:
  for target: Node2D in targets:if is_instance_valid(target):target.set_physics_process(false)
func _process(delta: float) -> void:
 if not is_instance_valid(player):return
 if PlayerCompanion.account_key!=_owner:_back();return
 _fit_arena()
 if not _running:return
 elapsed+=delta;player.position=player.position.clamp(Vector2(72,330),Vector2(576,920))
 if _active_mode() in ["dummy","technique"]:
  for i: int in range(targets.size()):
   if is_instance_valid(targets[i]):targets[i].position=Vector2(244+i*80+(sin(elapsed*1.4+float(i))*55 if moving else 0),500+(sin(elapsed+float(i))*35 if moving else 0))
 if _active_mode() in ["seal","standard"]:
  _spawn_left-=delta
  if _spawn_left<=0:
   _spawn_left=2.5
   if get_tree().get_nodes_in_group("enemy").size()<12:
    var angle: float=float(_spawn_index)*2.39996;_spawn_index+=1
    _enemy((player.position+Vector2.RIGHT.rotated(angle)*260).clamp(Vector2(85,350),Vector2(560,900)))
 if _active_mode()=="seal":
  _seal.advance(delta,player.position.distance_to(_seal.location)<=Oath.RADIUS,5);queue_redraw()
  if _seal.phase=="pending":
   _seals+=1
   if _seals>=3:_finish(Sheet.copy("THREE SEALS DEFENDED","TIGA SEGEL TERJAGA"),true);return
   _next_seal()
  elif _seal.phase=="failed":_finish(Sheet.copy("SEAL LOST · KEEP AN ESCAPE ROUTE","SEGEL GAGAL · JAGA JALUR KELUAR"));return
 var limit: float=45 if _active_mode()=="pattern" else 75 if _active_mode()=="seal" else 180 if _active_mode()=="gauntlet" else 120 if _active_mode()=="boss" else 60 if _active_mode() in ["technique","standard","priority"] else _duration
 if _active_mode()=="priority" and not is_instance_valid(get_node_or_null("JadeWardBearer")):_finish(Sheet.copy("WARD BROKEN","PELINDUNG PECAH"),true);return
 if _active_mode()=="technique":
  var hit: Dictionary=_hits.get(ATTACKS[_skills.selected],{})
  var needed: int=[6,4,8,20,6,18][_skills.selected]
  var count: int=0
  for row: Dictionary in hit.values():count+=int(row.hits)
  if hit.size()>=3 and count>=needed:_finish(Sheet.copy("TECHNIQUE DEMONSTRATED","TEKNIK TERBUKTI"),true);return
 if elapsed>=limit and _active_mode()=="pattern":_finish(Sheet.copy("PATTERN READ · REVIEW HP HITS","POLA TERBACA · TINJAU HIT KE HP"),true);return
 if elapsed>=limit and _active_mode()=="standard":_finish(Sheet.copy("EQUAL-FOOTING TRIAL COMPLETE","UJIAN SETARA SELESAI"),true);return
 if elapsed>=limit:_finish(Sheet.copy("MEASUREMENT COMPLETE","PENGUKURAN SELESAI") if _active_mode()=="dummy" else Sheet.copy("TIME LIMIT · REVIEW YOUR APPROACH","BATAS WAKTU · TINJAU PENDEKATANMU"),_active_mode()=="dummy");return
 _readout_timer-=delta
 if _readout_timer<=0:_readout_timer=.15;_readout()
func record_practice_hit(source: String,target_id: int,amount: float) -> void:
 if not _running or amount<=0:return
 if not _hits.has(source):_hits[source]={}
 var row: Dictionary=_hits[source].get(str(target_id),{"hits":0,"damage":0.0});row.hits+=1;row.damage+=amount;_hits[source][str(target_id)]=row
func _readout() -> void:
 if not is_instance_valid(player):return
 var ledger: Node=player.get_node("WeaponManager/RunCombatLedger");var total: float=0.0
 for value: Variant in ledger.totals.values():total+=float(value)
 _outgoing=total
 var lines: PackedStringArray=[Sheet.copy("TOTAL BUILD · %.1fs · %s DMG · %s DPS","TOTAL BUILD · %.1f dtk · %s DMG · %s DPS")%[elapsed,preload("res://scripts/ui/readable_numbers.gd").compact(roundi(total)),preload("res://scripts/ui/readable_numbers.gd").compact(roundi(total/maxf(elapsed,.1)))]]
 for row: Dictionary in ledger.damage_rows().slice(0,2):
  if float(row.damage)>0:lines.append(str(row.name)+" · "+str(roundi(float(row.damage))))
 if _active_mode()=="technique":
  var art_hits: Dictionary=_hits.get(ATTACKS[_skills.selected],{});var hit_count: int=0
  for row: Dictionary in art_hits.values():hit_count+=int(row.hits)
  lines.append(("TARGET %d/3 · HIT %d/%d" if SettingsManager.language=="id" else "TARGETS %d/3 · HITS %d/%d")%[mini(art_hits.size(),3),hit_count,[6,4,8,20,6,18][_skills.selected]])
 _report.text="\n".join(lines)
 var hp: Node=player.get_node("PlayerHealth")
 if _running:_status.text="HP %d/%d · %.1fs%s"%[roundi(hp.current_health),roundi(hp.max_health),elapsed," · %d/3 · %.1f/8s"%[_seals,_seal.charge] if _active_mode()=="seal" else ""]
 if _running and is_instance_valid(_boss):
  _status.text+=" · BOSS %d%%"%ceili(100.0*_boss.current_hp/maxf(1.0,_boss.max_hp))
  if _active_mode()=="gauntlet":_status.text+=" · %d/3"%_boss_round
func _finish(outcome: String,completed: bool=false) -> void:
 if not _running:return
 if PlayerCompanion.account_key!=_owner:_back();return
 _running=false;_outcome=outcome;_readout();_freeze_actors(true);player.get_node("WeaponManager/RunCombatLedger").frozen=true
 completed=completed and not player.get_node("PlayerHealth").is_dead and player.get_node("PlayerHealth").current_health>0
 if player.get_node("PlayerHealth").is_dead:outcome=Sheet.copy("DEFEAT · TRY ANOTHER APPROACH","KALAH · COBA PENDEKATAN LAIN")
 if completed and mode in ["dummy","boss","seal","technique","standard","priority","gauntlet"]:PlayerCompanion.record_drill(mode,ATTACKS[_skills.selected],clampi(roundi(elapsed*1000),1,180000),_outgoing,_owner)
 if completed:
  var row: Dictionary={"label":mode+" · "+Skill.get_upgrade_display_name(ATTACKS[_skills.selected])+" · Lv.%d · %ds"%[int(_record_context.level),roundi(elapsed)],"time_ms":clampi(roundi(elapsed*1000),1,180000),"damage":_outgoing,"hits":player.get_node("WeaponManager/RunCombatLedger").hp_hits,"score":"damage" if _active_mode()=="dummy" else "time"}
  var improved: bool=PlayerCompanion.record_training(_record_context,row,_owner)
  outcome+=Sheet.copy(" · PERSONAL BEST"," · REKOR PRIBADI") if improved else ""
 _status.text=outcome;_start_button.text=Sheet.copy("REPEAT SETUP","ULANG SETUP");_start_button.disabled=false
func _fit_arena() -> void:
 var accepts_input: bool=_running and (_setup==null or not _setup.visible) and not get_tree().paused
 if _joystick.is_processing_input()!=accepts_input:
  _joystick.set_process_input(accepts_input)
  if not accepts_input:_joystick._release_pointer();_joystick._release_actions()
 var view: Vector2=get_viewport_rect().size;var top: float=minf(_panel.get_global_rect().end.y+10,maxf(100,view.y-240))
 _joystick.offset_top=top;_joystick.offset_bottom=-128
 var zoom_value: float=clampf(minf((view.x-32)/504.0,(view.y-top-140)/590.0),.12,1.2)
 _camera.zoom=Vector2.ONE*zoom_value;_camera.position=Vector2(324,625-(top-128)/(2*zoom_value))
func _draw() -> void:
 if _active_mode()!="seal" or _seal.phase!="charging":return
 var point: Vector2=_seal.location
 draw_circle(point,Oath.RADIUS,Color(.12,.65,.47,.12));draw_arc(point,Oath.RADIUS,0,TAU,40,Sheet.GOLD,2,true)
 draw_arc(point,Oath.RADIUS-7,-PI/2,-PI/2+TAU*_seal.charge/Oath.CHARGE,40,Sheet.JADE,4,true)
func _unhandled_key_input(event: InputEvent) -> void:
 if _setup!=null and _setup.visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
  _back();get_viewport().set_input_as_handled()
func _back() -> void:
 if _setup!=null and _setup.visible:_setup.hide();return
 if SceneTransitionManager.is_transitioning:return
 _running=false;SceneTransitionManager.transition_menu_to("res://scenes/ui/skill_book_screen.tscn")
func _exit_tree() -> void:
 EquipmentManager.practice_items.clear();EquipmentManager.practice_levels.clear()
 for action: String in ["left","right","up","down","ui_left","ui_right","ui_up","ui_down"]:Input.action_release(action)
