extends PanelContainer
const Catalog=preload("res://scripts/data/cultivation_mastery_catalog.gd")
const FONT=preload("res://addons/admob/assets/fonts/NotoSansSC-Regular.otf")
const GOLD: Color=Color(.98,.79,.32)
const JADE: Color=Color(.28,.93,.73)
const ICONS: Dictionary={"vitality":"res://assets/ui/cultivation/meridian_vitality.png","sword_power":"res://assets/ui/cultivation/meridian_sword_power.png","swift_qi":"res://assets/ui/cultivation/meridian_swift_qi.png"}
var owner_manager: Node
var scroll_owner: ScrollContainer
var path_cards: Dictionary={}
var _seen_realm: int=-1
var pending: bool=false
var action_pending: bool=false
var status: String=""
var _press_position: Vector2
var _press_scroll: int = 0
var body: VBoxContainer
func _ready() -> void:
 name="DaoMasteryPanel";size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/system_v2/custom/cards/relic_card_legendary.svg")
 skin.texture_margin_left=16;skin.texture_margin_right=16;skin.texture_margin_top=16;skin.texture_margin_bottom=16
 skin.content_margin_left=14;skin.content_margin_right=14;skin.content_margin_top=16;skin.content_margin_bottom=16
 add_theme_stylebox_override("panel",skin)
 body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);add_child(body)
 owner_manager=get_node_or_null("/root/CultivationMasteryManager")
 if owner_manager!=null:owner_manager.changed.connect(queue_refresh)
 ProgressionManager.cultivation_upgraded.connect(func(_path: String,_level: int):queue_refresh())
 resized.connect(queue_refresh);queue_refresh()
func queue_refresh() -> void:
 if pending:return
 pending=true;_refresh.call_deferred()
func _copy(english: String,indonesian: String) -> String:return indonesian if SettingsManager.language=="id" else english
func _label(value: String,font_size: int=14,color: Color=Color(.93,.96,.94)) -> Label:
 var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
 label.set_meta(&"jade_mobile_readability_v2",true);return label
func _button(value: String) -> Button:
 var button:=Button.new();button.text=value;button.custom_minimum_size.y=48;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 button.mouse_filter=Control.MOUSE_FILTER_PASS;button.add_theme_font_override("font",FONT);button.add_theme_font_size_override("font_size",14);button.add_theme_color_override("font_color",GOLD)
 var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/system_v2/custom/buttons/secondary_normal.svg");skin.texture_margin_left=12;skin.texture_margin_right=12;skin.texture_margin_top=10;skin.texture_margin_bottom=10
 skin.content_margin_left=10;skin.content_margin_right=10;skin.content_margin_top=8;skin.content_margin_bottom=8
 for key: String in ["normal","hover","pressed"]:button.add_theme_stylebox_override(key,skin)
 button.button_down.connect(func():
  _press_position=get_global_mouse_position()
  _press_scroll=scroll_owner.scroll_vertical if scroll_owner!=null else 0)
 return button
func _dragged() -> bool:
 return get_global_mouse_position().distance_to(_press_position)>8 or (scroll_owner!=null and absi(scroll_owner.scroll_vertical-_press_scroll)>6)
func _refresh() -> void:
 pending=false
 if body==null:return
 for child: Node in body.get_children():body.remove_child(child);child.queue_free()
 path_cards.clear()
 if owner_manager==null:owner_manager=get_node_or_null("/root/CultivationMasteryManager")
 if owner_manager==null or not owner_manager.ready_state:
  body.add_child(_label("DAO MASTERY",24,GOLD));body.add_child(_label("Mastery save belum siap. Progres kultivasi lama tetap tersimpan."));return
 var model: Dictionary=owner_manager.state
 var row:=HBoxContainer.new();body.add_child(row)
 var icon_box:=Control.new();icon_box.custom_minimum_size=Vector2(64,64);row.add_child(icon_box)
 if model.realm==1:
  var fx: Control=preload("res://scripts/ui/cultivation_breakthrough_fx.gd").new();icon_box.add_child(fx);fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fx.configure(GOLD)
  if _seen_realm!=1:fx.celebrate()
 _seen_realm=int(model.realm)
 var icon:=TextureRect.new();icon.texture=load("res://assets/ui/cultivation/meridian_dao_core.png");icon.custom_minimum_size=Vector2(64,64);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon_box.add_child(icon);icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var title_box:=VBoxContainer.new();title_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(title_box)
 title_box.add_child(_label("GOLDEN CORE" if model.realm==1 else "FOUNDATION ESTABLISHMENT",20,GOLD))
 title_box.add_child(_label(_copy("DAO MASTERY • one active choice per path","DAO MASTERY • 1 pilihan aktif per jalur"),14,JADE))
 body.add_child(_label(_copy("Lv.10 unlocks specialization. Choose freely for the next run; existing upgrades stay intact.","Lv.10 membuka spesialisasi. Pilihan gratis, berlaku mulai run baru; tidak mereset upgrade lama."),14))
 for path: String in Catalog.PATHS:
  var group:=VBoxContainer.new();group.name="Path_"+path;group.add_theme_constant_override("separation",8);body.add_child(group);path_cards[path]=group
  var current: String=str(model.choices[path]);var unlocked: bool=owner_manager.path_maxed(path)
  group.add_child(_label(path.replace("_"," ").to_upper()+" • "+(_copy("MASTERY OPEN","MASTERY TERBUKA") if unlocked else _copy("REQUIRES LV.10","PERLU LV.10")),16,GOLD if unlocked else Color(.6,.7,.72)))
  var choices:=GridContainer.new();choices.columns=1 if size.x<440 else 2;choices.add_theme_constant_override("h_separation",10);choices.add_theme_constant_override("v_separation",8);group.add_child(choices)
  for id: String in Catalog.OPTIONS[path]:
   var choice:=VBoxContainer.new();choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;choices.add_child(choice)
   var button:=_button(("✓ " if current==id else "")+str(Catalog.NODES[id].name));button.name="Mastery_"+id;choice.add_child(button)
   button.icon=load(ICONS[path]);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",28)
   button.disabled=not owner_manager.can_choose(path);button.pressed.connect(_choose.bind(path,id,current))
   var description:=_label(str(Catalog.NODES[id].description if SettingsManager.language=="id" else Catalog.NODES[id].description_en),13,JADE if current==id else Color(.77,.85,.86));choice.add_child(description)
 var separator:=HSeparator.new();body.add_child(separator)
 body.add_child(_label("HEAVENLY TRIBULATION",20,GOLD))
 body.add_child(_label(_copy("Requires all 3 paths MAX, 3 active masteries, Stage 1–5 unlocked. Defeat its boss with ≤3 HP-damage hits and no death/revive. Complete the trial in one session.","Syarat: 3 jalur MAX, 3 mastery aktif, Stage 1–5 terbuka. Menangkan boss Stage 1–5 dengan ≤3 hit yang mengurangi HP, tanpa mati/revive. Ujian harus selesai dalam satu sesi."),14))
 var progress: int=0
 for path: String in Catalog.PATHS:
  if owner_manager.path_maxed(path) and model.choices[path]!="":progress+=1
 body.add_child(_label(_copy("MASTERY READINESS %d/3","KESIAPAN MASTERY %d/3")%progress,16,JADE))
 if model.realm==1:body.add_child(_label(_copy("GOLDEN CORE AWAKENED • Clears %d • Best: %d HP hits","GOLDEN CORE TERBUKA • Clear %d • Best: %d HP hits")%[int(model.clears),int(model.best_hits)],14,GOLD))
 var trial_status: String=str(model.trial.get("status",""))
 if trial_status in ["failed","interrupted"]:body.add_child(_label(_copy("Previous trial "+("interrupted" if trial_status=="interrupted" else "failed")+". Upgrades stay intact. Resolve any active checkpoint before retrying.","Ujian sebelumnya "+("terputus" if trial_status=="interrupted" else "gagal")+". Upgrade lama tetap aman. Selesaikan checkpoint aktif sebelum mencoba lagi."),14))
 var trial:=_button(_copy("REPLAY TRIAL • IMPROVE RECORD","ULANGI UJIAN • PERBAIKI REKOR") if model.realm==1 else _copy("BEGIN TRIAL • GOLDEN CORE","MULAI UJIAN • GOLDEN CORE"));trial.name="RealmTrialAction";body.add_child(trial);trial.disabled=not owner_manager.trial_ready();trial.pressed.connect(_start_trial)
 if not status.is_empty():body.add_child(_label(status,14,GOLD))
func _choose(path: String,id: String,expected: String) -> void:
 if action_pending or _dragged():return
 action_pending=true
 if not owner_manager.choose(path,id,expected):status=owner_manager.last_error
 else:status=_copy("Mastery selected for the next run.","Mastery dipilih untuk run berikutnya.")
 queue_refresh();_release.call_deferred()
func _release() -> void:action_pending=false
func focus_path(path: String) -> void:
 if scroll_owner!=null and path_cards.has(path):scroll_owner.ensure_control_visible(path_cards[path])
func _start_trial() -> void:
 if action_pending or _dragged() or SceneTransitionManager.is_transitioning:return
 action_pending=true
 var scene: String=owner_manager.prepare_trial()
 if scene.is_empty():status=owner_manager.last_error;queue_refresh();_release.call_deferred();return
 GameSession.start_new_game()
 var error: Error=SceneTransitionManager.transition_to(scene,{"title":"HEAVENLY TRIBULATION","subtitle":"Golden Core • Stage 1–5 • ≤3 HP hits","minimum_display_time":.65})
 if error!=OK:owner_manager.cancel_prepared_trial();status="Transisi ujian gagal. Coba lagi.";queue_refresh()
 _release.call_deferred()
