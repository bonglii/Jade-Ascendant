extends Control
## Shared xianxia journal, native mobile scroll and fixed close. No grant authority.
const Frame = preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
const Tokens = preload("res://scripts/ui/jade_ui_tokens.gd")
const Scroll = preload("res://scripts/ui/mobile_scroll_policy.gd")
const GearProjection = preload("res://scripts/companion/equipment_projection.gd")
const Sets = preload("res://scripts/data/equipment_set_catalog.gd")
const Chapters: Array = [preload("res://scripts/data/chapter_one_catalog.gd"),preload("res://scripts/data/chapter_two_catalog.gd"),preload("res://scripts/data/chapter_three_catalog.gd"),preload("res://scripts/data/chapter_four_catalog.gd"),preload("res://scripts/data/chapter_five_catalog.gd")]
const GOLD=Color("f1d18a")
const JADE=Color("77dfbb")
const TEXT=Color("d1e5dc")
var mode: String="tools"
var _panel: PanelContainer
var _body: VBoxContainer
var _scroll: ScrollContainer
var _heading: Label
var _previous_back: Callable
var _queued: bool=false
var _feedback: String=""
var _compare_a: int=1
var _compare_b: int=0
var _owner: String
static func open(host: Node, page: String="tools") -> Control:
 var existing: Node=host.get_node_or_null("PlayerJournal")
 if existing!=null: return existing as Control
 var sheet=load("res://scripts/companion/player_journal.gd").new()
 sheet.mode=page;sheet.name="PlayerJournal";host.add_child(sheet);return sheet
static func copy(en: String,id: String) -> String: return id if SettingsManager.language=="id" else en
func _ready() -> void:
 z_index=450;process_mode=Node.PROCESS_MODE_ALWAYS;set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 _owner=PlayerCompanion.account_key
 var dim:=ColorRect.new();dim.color=Color(.06,.16,.13,.14) if mode=="summons" else Color(.002,.018,.023,.87);dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(dim)
 _panel=PanelContainer.new();_panel.name="JournalFrame";_panel.add_theme_stylebox_override("panel",skin(22));add_child(_panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);_panel.add_child(box)
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);box.add_child(row)
 var back: Button=button("‹",func():
  if mode=="tools":close()
  else:mode="tools";_redraw())
 back.custom_minimum_size.x=44;back.size_flags_horizontal=SIZE_SHRINK_CENTER;back.add_theme_font_size_override("font_size",24);row.add_child(back)
 _heading=label("",18,GOLD);_heading.size_flags_horizontal=SIZE_EXPAND_FILL;row.add_child(_heading)
 var exit: Button=button("×",close);exit.name="JournalClose";exit.custom_minimum_size.x=44;exit.size_flags_horizontal=SIZE_SHRINK_CENTER;exit.add_theme_font_size_override("font_size",24);row.add_child(exit)
 _scroll=ScrollContainer.new();_scroll.name="JournalScroll";_scroll.size_flags_vertical=SIZE_EXPAND_FILL;Scroll.configure(_scroll);box.add_child(_scroll)
 _body=VBoxContainer.new();_body.size_flags_horizontal=SIZE_EXPAND_FILL;_body.add_theme_constant_override("separation",12);_scroll.add_child(_body)
 _previous_back=SceneTransitionManager.back_handler;SceneTransitionManager.set_back_handler(close)
 PlayerCompanion.changed.connect(_queue)
 CompanionNetwork.changed.connect(_queue)
 resized.connect(_fit);_fit();_redraw()
func _fit() -> void:
 if _panel==null:return
 var dims:=Vector2(minf(600,maxf(240,size.x-20)),maxf(220,minf(820,size.y-32)))
 _panel.size=dims;_panel.position=(size-dims)*.5
func _queue() -> void:
 if _queued:return
 _queued=true;_refresh.call_deferred()
func _refresh() -> void:
 _queued=false
 if PlayerCompanion.account_key!=_owner:close();return
 _redraw(true)
static func skin(padding: int=14) -> StyleBoxTexture:
 var style:=StyleBoxTexture.new();style.texture=Frame
 for edge: String in ["left","right","top","bottom"]:style.set("texture_margin_"+edge,18);style.set("content_margin_"+edge,padding)
 return style
static func label(text: String, size_px: int=15, color: Color=TEXT) -> Label:
 var value:=Label.new();value.text=text;value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;value.mouse_filter=MOUSE_FILTER_IGNORE
 value.add_theme_font_size_override("font_size",size_px);value.add_theme_color_override("font_color",color);return value
static func button(text: String, action: Callable) -> Button:
 var value:=Button.new();value.text=text;value.custom_minimum_size.y=48;value.size_flags_horizontal=SIZE_EXPAND_FILL
 value.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;value.mouse_filter=MOUSE_FILTER_PASS;value.focus_mode=FOCUS_NONE
 preload("res://scripts/ui/result_ceremony.gd").style_button(value,"navy")
 value.add_theme_font_size_override("font_size",14);value.clip_text=true;value.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 value.pressed.connect(action);return value
func card(title: String, text: String="", art: Texture2D=null) -> VBoxContainer:
 var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",skin(14));_body.add_child(panel)
 var content:=VBoxContainer.new();content.add_theme_constant_override("separation",9);panel.add_child(content)
 if art!=null:
  var image:=TextureRect.new();image.texture=art;image.custom_minimum_size.y=130;image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=MOUSE_FILTER_IGNORE;content.add_child(image)
 content.add_child(label(title,18,GOLD))
 if not text.is_empty():content.add_child(label(text))
 return content
func _go(page: String) -> void:mode=page;_scroll.scroll_vertical=0;_feedback="";_redraw()
func _redraw(preserve: bool=false) -> void:
 if not is_instance_valid(_body):return
 var offset: int=_scroll.scroll_vertical
 for child: Node in _body.get_children():_body.remove_child(child);child.queue_free()
 var titles: Dictionary={"tools":copy("CULTIVATOR JOURNAL","JURNAL KULTIVATOR"),"presets":copy("BUILD PRESETS","PRESET BUILD"),"goal":copy("COLLECTION GOAL","TARGET KOLEKSI"),"bosses":copy("BOSS ARCHIVE","ARSIP BOSS"),"runs":copy("RECENT RUNS","RUN TERAKHIR"),"agenda":copy("EVENT AGENDA","AGENDA EVENT"),"summons":copy("SUMMON HISTORY","RIWAYAT SUMMON"),"drills":copy("TECHNIQUE RECORDS","CATATAN TEKNIK")}
 _heading.text=str(titles.get(mode,titles.tools))
 if not _feedback.is_empty():_body.add_child(label(_feedback,14,JADE))
 match mode:
  "presets":_presets()
  "goal":_goals()
  "bosses":_bosses()
  "runs":_runs()
  "drills":_drills()
  "agenda":_agenda()
  "summons":_summons()
  _:_tools()
 Scroll.prepare_tree(_scroll)
 if preserve:_scroll.set_deferred("scroll_vertical",offset)
func _tools() -> void:
 card(copy("YOUR PATH, YOUR BUILD","JALUR DAN BUILD PILIHANMU"),copy("Review your equipment, revisit encounters and prepare your next run.","Atur equipment, pelajari pertarungan dan siapkan run berikutnya."),load("res://assets/ui/hero/imperial_v4/sanctuary_banner.png"))
 for entry: Array in [["presets","BUILD PRESETS","PRESET BUILD"],["goal","COLLECTION GOAL","TARGET KOLEKSI"],["bosses","BOSS ARCHIVE","ARSIP BOSS"],["runs","RECENT RUNS","RUN TERAKHIR"],["agenda","EVENT AGENDA","AGENDA EVENT"],["summons","SUMMON HISTORY","RIWAYAT SUMMON"],["drills","TECHNIQUE RECORDS","CATATAN TEKNIK"]]:
  var action: Button=button(copy(entry[1],entry[2])+"  ›",_go.bind(entry[0]));action.name="Journal_"+entry[0];_body.add_child(action)
 var practice: Button=button(copy("ENTER TRAINING GROUNDS","MASUK ARENA LATIHAN"),_practice);practice.name="JournalPractice";_body.add_child(practice)
func _presets() -> void:
 _body.add_child(label(copy("On this device · next run only. Continue keeps its saved build. Server gear must match Server Armory.","Di perangkat ini · run berikutnya. Continue memakai build tersimpan. Samakan gear server di Server Armory."),14))
 for index: int in range(3):
  var row: Dictionary=PlayerCompanion.state.presets.get(str(index),{})
  var title: String=str(row.get("name",[copy("Farming","Farming"),copy("Boss","Boss"),copy("Defense","Pertahanan")][index]))
  var content: VBoxContainer=card("%d · %s"%[index+1,title],_slot_names(row.get("slots",{})) if not row.is_empty() else copy("Empty build slot","Slot build kosong"))
  if not row.is_empty():content.add_child(button(copy("PREVIEW WHOLE PRESET","PRATINJAU SELURUH PRESET"),func():load("res://scripts/experience/menu_guide.gd").open(get_tree().current_scene,"preset",{"index":index})))
  var input:=LineEdit.new();input.text=title;input.max_length=24;input.custom_minimum_size.y=46;input.add_theme_font_size_override("font_size",15);content.add_child(input)
  var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",8);content.add_child(actions)
  actions.add_child(button(copy("SAVE","SIMPAN"),func(): _feedback=copy("Build saved.","Build disimpan.") if PlayerCompanion.save_preset(index,input.text) else copy("Cannot save now.","Belum dapat disimpan.");_redraw()))
  var apply: Button=button(copy("APPLY","PAKAI"),func():_feedback=copy("Build applied.","Build dipakai.") if PlayerCompanion.apply_preset(index) else copy("Check ownership, Server Armory and save status.","Periksa kepemilikan, Server Armory dan status save.");_redraw())
  apply.disabled=not PlayerCompanion.preset_problem(index).is_empty();actions.add_child(apply)
  if not row.is_empty() and not PlayerCompanion.preset_problem(index).is_empty():content.add_child(label(copy("Not ready: ","Belum siap: ")+_preset_reason(PlayerCompanion.preset_problem(index)),12,JADE))
func _preset_reason(reason: String) -> String:
 var messages: Dictionary={"empty":copy("Save a build first.","Simpan build dahulu."),"save_or_run_busy":copy("Finish combat or save recovery first.","Selesaikan combat atau pemulihan save."),"match_server_armory":copy("Match this preset's server gear in Server Armory.","Samakan gear server preset ini di Server Armory."),"item_not_owned":copy("A saved piece is no longer owned.","Salah satu item tersimpan belum dimiliki.")}
 return str(messages.get(reason,copy("Build unavailable.","Build belum tersedia.")))
func _slot_names(slots: Dictionary) -> String:
 var parts: PackedStringArray=[]
 for slot: String in EquipmentManager.get_slot_ids():
  var id: String=str(slots.get(slot,""))
  if not id.is_empty():parts.append(str(EquipmentManager.get_item_data(id).get("display_name",id)))
 return " · ".join(parts)
func _goals() -> void:
 var progress: Dictionary=PlayerCompanion.goal_progress()
 if not progress.is_empty():
  var content: VBoxContainer=card(copy("PINNED TARGET","TARGET PILIHAN"),"%s · %d/%d"%[_goal_name(progress.id),progress.owned,progress.total])
  for id: String in progress.missing:content.add_child(label("• "+str(EquipmentManager.get_item_data(id).display_name)+"\n"+_acquisition(id),14))
  if progress.missing.is_empty():content.add_child(label(copy("Collection complete. Upgrades require identical duplicates; no bonus is granted by this tracker.","Koleksi lengkap. Upgrade memakai duplikat identik; tracker ini tidak memberi bonus."),14,JADE))
  content.add_child(button(copy("CLEAR TARGET","HAPUS TARGET"),func():PlayerCompanion.set_goal("")))
 _body.add_child(label(copy("Choose one set or independent weapon to follow.","Pilih satu set atau weapon independen untuk diikuti."),15,JADE))
 for set_id: String in Sets.SET_ORDER:
  _body.add_child(button(Sets.get_display_name(set_id),func():PlayerCompanion.set_goal("set:"+set_id)))
 for id: String in EquipmentManager.get_item_ids_for_slot("armament"):
  _body.add_child(button(str(EquipmentManager.get_item_data(id).display_name),func():PlayerCompanion.set_goal(id)))
func _goal_name(id: String) -> String:return Sets.get_display_name(id.trim_prefix("set:")) if id.begins_with("set:") else str(EquipmentManager.get_item_data(id).get("display_name",id))
func _acquisition(id: String) -> String:
 var item: Dictionary=EquipmentManager.get_item_data(id)
 if item.get("event_only",false):return copy("Jade Dragon Odyssey: 12 full laps, milestone claim and Mail. Admin gifts can also establish ownership.","Jade Dragon Odyssey: 12 putaran, klaim milestone lalu Mail. Hadiah admin juga dapat memberi kepemilikan.")
 return copy("Pavilion Summon after clear 1-5. Stage requirement: ","Summon Paviliun setelah clear 1-5. Syarat stage: ")+str(item.get("requires_chapter",1))+"-"+str(item.get("requires_stage",1))
func _bosses() -> void:
 _body.add_child(label(copy("Encounter a guardian to reveal its archive. Earlier stage clears also unlock their entries.","Temui penjaga untuk membuka arsipnya. Stage yang pernah diselesaikan juga membuka entri."),14))
 for chapter: int in range(1,6):
  for stage: int in Chapters[chapter-1].STAGES:
   var data: Dictionary=Chapters[chapter-1].STAGES[stage]
   var known: bool=("%d-%d"%[chapter,stage]) in PlayerCompanion.state.seen_bosses or JourneyManager.is_stage_cleared(chapter,stage)
   var boss_title: String = "%d-%d · ???" % [chapter,stage]
   var boss_hint: String = copy("Not encountered","Belum ditemui")
   if known:
    boss_title = "%d-%d · %s" % [chapter,stage,str(data.get("boss_name","Guardian"))]
    boss_hint = str(data.get("encounter_hint",""))
   var content: VBoxContainer = card(boss_title,boss_hint)
   if known:content.add_child(button(copy("READ ENCOUNTER","PELAJARI POLA"),_boss_detail.bind(chapter,stage)))
func _boss_detail(chapter: int,stage: int) -> void:
 for child: Node in _body.get_children():_body.remove_child(child);child.queue_free()
 var data: Dictionary=Chapters[chapter-1].STAGES[stage]
 var image: Texture2D
 var path: String="res://assets/enemy/boss_2d/atlas_%d_%d.png"%[chapter,mini(stage,5)]
 if ResourceLoader.exists(path):
  var atlas: Texture2D=load(path);var tile:=AtlasTexture.new();tile.atlas=atlas;tile.region=Rect2(0,atlas.get_height()/6.0,atlas.get_width()/6.0,atlas.get_height()/6.0);tile.filter_clip=true;image=tile
 var details: VBoxContainer=card(str(data.boss_name),str(data.description),image)
 var boss_stats: Dictionary=data.get("boss_stats",{})
 if boss_stats.has("phase_two_hp_ratio"):details.add_child(label(copy("Phase shift at ","Pergantian fase pada ")+str(roundi(float(boss_stats.phase_two_hp_ratio)*100))+"% HP",16,JADE))
 details.add_child(label(copy("Leave melee windups. Move across projectile lanes, away from lightning marks, and through gaps in radial waves. Return within auto-attack range after dodging. A phase ward can temporarily prevent damage.","Keluar dari ancang-ancang melee. Lewati jalur proyektil, jauhi tanda petir, dan cari celah gelombang radial. Kembali ke jangkauan serang setelah menghindar. Pelindung fase dapat menahan damage sementara."),15))
 details.add_child(label(copy("Pattern pool follows the encounter: ","Kumpulan pola sesuai encounter: ")+_patterns(int(data.get("boss_style",0))),14,JADE))
 if chapter==1:
  details.add_child(button(copy("PRACTICE THIS GUARDIAN","LATIHAN PENJAGA INI"),_practice.bind(stage)))
  details.add_child(button(copy("DRILL ONE PATTERN","LATIH SATU POLA"),_practice.bind(stage, true)))
 _body.add_child(button(copy("ALL GUARDIANS","SEMUA PENJAGA"),_redraw));_scroll.scroll_vertical=0;Scroll.prepare_tree(_scroll)
func _patterns(style: int) -> String:
 if style in [1,2]: return copy("single projectile · radial burst","proyektil tunggal · radial")
 if style==3:return copy("phase1: lightning / projectile; phase2: lightning / radial","fase1: petir / proyektil; fase2: petir / radial")
 if style==4:return copy("phase2 also includes the ascended cross","fase2 juga memakai silang ascended")
 return copy("projectile · radial · lightning","proyektil · radial · petir")
func _runs() -> void:
 var compare: Button=button(copy("COMPARE TWO RUNS","BANDINGKAN DUA RUN"),_compare_runs);compare.name="CompareRuns";compare.disabled=PlayerCompanion.state.runs.size()<2;_body.add_child(compare)
 _body.add_child(label(copy("Latest10 runs on this device. Reviving the same run replaces its earlier defeat. Personal display only.","10 run terakhir di perangkat ini. Revive pada run yang sama mengganti laporan defeat sebelumnya. Catatan pribadi."),14))
 if PlayerCompanion.state.runs.is_empty():card(copy("YOUR NEXT ATTEMPT","PERCOBAAN BERIKUTMU"),copy("New results will appear here. Earlier stage records remain in Journey.","Hasil baru akan muncul di sini. Rekor stage sebelumnya tetap ada di Journey."))
 for row: Dictionary in PlayerCompanion.state.runs:
  var facts: Dictionary=row.facts
  var content: VBoxContainer=card("%d-%d · %s"%[int(row.chapter),int(row.stage),_outcome_copy(str(row.outcome))],_date(int(row.time))+" · %02d:%02d · Lv.%d"%[int(float(facts.seconds)/60),int(facts.seconds)%60,int(facts.level)])
  content.add_child(label(_slot_names(row.get("slots",{})),13,JADE))
  for damage: Dictionary in facts.get("damage",[]):content.add_child(label(str(damage.name)+" · "+preload("res://scripts/ui/readable_numbers.gd").compact(roundi(float(damage.damage))),14))
  if facts.has("run_paths"):content.add_child(label(_path_summary(facts.run_paths),13,JADE))
  var skills: PackedStringArray=[]
  for skill: Dictionary in facts.get("skills",[]):skills.append(str(skill.name)+" Lv."+str(skill.level))
  content.add_child(label(" · ".join(skills),13))
func _date(stamp: int) -> String:
 var date: Dictionary=Time.get_datetime_dict_from_unix_time(stamp+int(Time.get_time_zone_from_system().get("bias",0))*60)
 return "%02d/%02d %02d:%02d"%[date.day,date.month,date.hour,date.minute]
func _summons() -> void:
 _body.add_child(label(copy("Latest100 recorded results for this account on this device. Display history is not a restore or reward authority. Earlier unrecorded visits cannot be reconstructed.","100 hasil tercatat terakhir untuk akun ini di perangkat ini. Riwayat tampilan tidak dapat memulihkan/memberi reward. Kunjungan lama yang belum dicatat tidak dapat direkonstruksi."),14))
 if PlayerCompanion.state.summons.is_empty():card(copy("A NEW CHAPTER","CATATAN BARU"),copy("Your next completed summon appears here.","Summon berhasil berikutnya muncul di sini."))
 for row: Dictionary in PlayerCompanion.state.summons:
  var item: Dictionary=EquipmentManager.get_item_data(str(row.item_id))
  var content: VBoxContainer=card(str(item.display_name),_date(int(row.time))+" · "+str(row.source).to_upper()+" · "+copy("DUPLICATE" if row.duplicate else "NEW","DUPLIKAT" if row.duplicate else "BARU"))
  var icon:=TextureRect.new();icon.texture=load(preload("res://scripts/ui/equipment_visual_catalog.gd").get_icon_path(str(row.item_id)));icon.custom_minimum_size=Vector2(48,48);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;content.add_child(icon)
func _agenda() -> void:
 var client: Node=get_node_or_null("/root/CompanionNetwork")
 if client==null:return
 _body.add_child(label(copy("Published schedules only. Times below follow this device's timezone. A missing schedule never creates an event.","Hanya jadwal yang sudah dipublikasikan. Waktu mengikuti zona perangkat. Jadwal kosong tidak membuat event baru."),14))
 if client.agenda.is_empty():
  card(copy("CHECKING THE SEASONS","MEMERIKSA MUSIM"),copy("Schedule unavailable or not published. Existing events stay accessible in Celestial Events.","Jadwal belum tersedia atau belum diterbitkan. Event yang ada tetap dapat dibuka di Celestial Events."))
  client.refresh_agenda()
 for entry: Dictionary in client.agenda.get("events",[]):
  card(str(entry.title),_date(int(entry.starts_at))+" → "+_date(int(entry.ends_at))+"\n"+str(entry.get("status","scheduled")))
 _body.add_child(button(copy("REFRESH SCHEDULE","PERBARUI JADWAL"),func():client.refresh_agenda()))
func _practice(boss_stage: int=0, pattern_drill: bool=false) -> void:
 if SceneTransitionManager.is_transitioning:return
 var paid: Node=EquipmentManager._paid_v2()
 if paid!=null and (bool(paid.get("busy")) or not (paid.call("_read_pending") as Dictionary).is_empty()):_feedback=copy("Finish pending account recovery first.","Tuntaskan pemulihan akun terlebih dahulu.");_redraw();return
 if boss_stage>0:
  get_tree().root.set_meta("practice_boss",boss_stage)
  get_tree().root.set_meta("practice_pattern_drill",pattern_drill)
 close()
 SceneTransitionManager.transition_menu_to("res://scenes/ui/training_ground.tscn")
func close() -> void:queue_free()
func _exit_tree() -> void:
 if SceneTransitionManager.back_handler==Callable(self,"close"):SceneTransitionManager.set_back_handler(_previous_back if _previous_back.is_valid() else Callable())

func _compare_runs() -> void:
 var rows: Array=PlayerCompanion.state.runs
 if rows.size()<2:return
 _compare_a=clampi(_compare_a,0,rows.size()-1);_compare_b=clampi(_compare_b,0,rows.size()-1)
 for child: Node in _body.get_children():_body.remove_child(child);child.queue_free()
 _heading.text=copy("COMPARE TWO RUNS","BANDINGKAN DUA RUN")
 _body.add_child(label(copy("B minus A · personal records, no rewards. Compare the same stage, outcome and duration for useful build conclusions.","B dikurangi A · catatan pribadi, tanpa reward. Bandingkan stage, hasil dan durasi yang sama untuk menilai build."),15))
 for side: int in range(2):
  _body.add_child(label("RUN A" if side==0 else "RUN B",16,GOLD))
  var picker:=OptionButton.new();picker.name="CompareA" if side==0 else "CompareB";picker.fit_to_longest_item=false;picker.clip_text=true;picker.custom_minimum_size.y=48
  for row: Dictionary in rows:picker.add_item("%d-%d · %s · %s"%[int(row.chapter),int(row.stage),_outcome_copy(str(row.outcome)),_date(int(row.time))])
  picker.select(_compare_a if side==0 else _compare_b)
  picker.item_selected.connect(func(index: int):
   if side==0:_compare_a=index
   else:_compare_b=index
   _compare_runs.call_deferred())
  _body.add_child(picker)
 var a: Dictionary=rows[_compare_a];var b: Dictionary=rows[_compare_b]
 if _compare_a==_compare_b:_body.add_child(label(copy("Choose two different runs.","Pilih dua run yang berbeda."),16,GOLD))
 elif a.chapter!=b.chapter or a.stage!=b.stage or a.outcome!=b.outcome:_body.add_child(label(copy("Different stage or outcome · damage/DPS does not prove a stronger build.","Stage atau hasil berbeda · damage/DPS tidak membuktikan build lebih kuat."),16,GOLD))
 var changed: PackedStringArray=[]
 for slot: String in EquipmentManager.get_slot_ids():
  if a.slots.get(slot,"")!=b.slots.get(slot,""):changed.append(slot.capitalize())
 card(copy("WHAT CHANGED","APA YANG BERUBAH"),(copy("Equipment slots: ","Slot equipment: ")+", ".join(changed)) if not changed.is_empty() else copy("Same equipment IDs. Review stars, weapon levels and run choices separately.","ID equipment sama. Tinjau bintang, level weapon dan pilihan run secara terpisah."))
 var fa: Dictionary=a.facts;var fb: Dictionary=b.facts
 for stat: Array in [["seconds","Time (s)","Waktu (dtk)"],["level","Level","Level"],["hits","HP hits","Hit ke HP"],["hp_loss","HP lost","HP hilang"]]:
  var key: String=stat[0]
  var complete: bool=key not in ["hits","hp_loss"] or (bool(fa.get("incoming_complete",false)) and bool(fb.get("incoming_complete",false)))
  if not complete or not fa.has(key) or not fb.has(key):card(copy(stat[1],stat[2]),copy("Legacy / incomplete · comparison unavailable","Data lama / tidak lengkap · belum dapat dibandingkan"));continue
  card(copy(stat[1],stat[2]),"A %.1f · B %.1f · Δ %+.1f"%[float(fa[key]),float(fb[key]),float(fb[key])-float(fa[key])])
 var totals: Array[float]=[]
 for facts: Dictionary in [fa,fb]:
  var total: float=0
  for damage: Dictionary in facts.get("damage",[]):total+=float(damage.damage)
  totals.append(total)
 var complete_damage: bool=not bool(fa.get("damage_partial",true)) and not bool(fb.get("damage_partial",true))
 if complete_damage:card(copy("ACTUAL DAMAGE / DPS","DAMAGE AKTUAL / DPS"),"A %.0f / %.1f · B %.0f / %.1f\nΔ damage %+.0f"%[totals[0],totals[0]/maxf(.1,float(fa.seconds)),totals[1],totals[1]/maxf(.1,float(fb.seconds)),totals[1]-totals[0]])
 else:card(copy("PARTIAL DAMAGE","DAMAGE PARSIAL"),copy("One run lacks complete damage data. Use its recorded sources without ranking builds.","Salah satu run tidak punya data damage lengkap. Tinjau sumber tercatat tanpa memberi peringkat build."))
 for side: int in range(2):
  var row: Dictionary=[a,b][side];var facts: Dictionary=row.facts
  var detail: VBoxContainer=card("RUN "+("A" if side==0 else "B"),_slot_names(row.get("slots",{})))
  if facts.has("run_paths"):detail.add_child(label(_path_summary(facts.run_paths),14,JADE))
  detail.add_child(button(copy("LAST TEN SECONDS","SEPULUH DETIK TERAKHIR"),func():load("res://scripts/experience/menu_guide.gd").open(get_tree().current_scene,"timeline",facts.get("timeline",{}))))
  for damage: Dictionary in facts.get("damage",[]):detail.add_child(label(str(damage.name)+" · "+str(roundi(float(damage.damage))),14,JADE))
 _body.add_child(button(copy("BACK TO RUNS","KEMBALI KE RUN"),_redraw));_scroll.scroll_vertical=0;Scroll.prepare_tree(_scroll)
func _drills() -> void:
 for row: Dictionary in PlayerCompanion.state.get("training_records",{}).values().slice(-8):
  card(copy("PERSONAL BEST · ","REKOR PRIBADI · ")+load("res://scripts/data/experience_policy.gd").record_label(str(row.label),SettingsManager.language),copy("%.1fs · %.0f damage · %d HP hits. Matching rules and kit only.","%.1f dtk · %.0f damage · %d hit ke HP. Hanya aturan dan kit yang sama.")%[float(row.time_ms)/1000.0,float(row.damage),int(row.hits)])
 _body.add_child(label(copy("Personal training marks on this device. No currency, mastery XP or Journey clear is awarded.","Tanda latihan pribadi di perangkat ini. Tanpa currency, XP mastery atau clear Journey."),15))
 var catalog=preload("res://scripts/data/run_path_policy.gd")
 for index: int in range(catalog.ARTS.size()):
  var record: Dictionary=PlayerCompanion.state.get("drills",{}).get("technique:"+catalog.ARTS[index],{})
  card(catalog.NAMES[index],copy("Not demonstrated yet","Belum dibuktikan") if record.is_empty() else copy("DEMONSTRATED · %.1fs","TERBUKTI · %.1f dtk")%(float(record.time_ms)/1000.0))
 _body.add_child(button(copy("ENTER TRAINING COURT","MASUK PELATARAN LATIHAN"),_practice))

func _path_summary(raw: Dictionary) -> String:
 var paths: Dictionary=preload("res://scripts/data/run_path_policy.gd").clean(raw)
 var parts: PackedStringArray=[]
 for art: String in paths.arts:
  var choice: String=str(paths.arts[art])
  parts.append(preload("res://scripts/data/skill_catalog.gd").get_upgrade_display_name(art)+" · "+({"focus":copy("Guardian Focus","Fokus Penjaga"),"sweep":copy("Valley Sweep","Sapuan Lembah"),"balanced":copy("Balanced","Seimbang")}.get(choice,choice)))
 if paths.boon in ["ember","wind"]:parts.append(copy("Altar: ","Altar: ")+({"ember":copy("Ember","Bara"),"wind":copy("Wind","Angin")}[paths.boon]))
 return "\n".join(parts) if not parts.is_empty() else copy("Balanced path · no altar boon","Jalur seimbang · tanpa berkah altar")

func _outcome_copy(value: String) -> String:
 return copy("VICTORY","MENANG") if value=="victory" else copy("DEFEAT","KALAH") if value=="defeat" else value.to_upper()
