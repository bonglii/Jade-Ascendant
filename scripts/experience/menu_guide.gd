extends Control
## Shared read-only jade reader. Spending, grants and run changes stay in managers.
const Frame=preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
const Scroll=preload("res://scripts/ui/mobile_scroll_policy.gd")
const Gear=preload("res://scripts/companion/equipment_projection.gd")
const Gold=Color("f1d18a")
const Jade=Color("77dfbb")
const GUIDES: Dictionary={
 "cultivate":["PREPARE THE NEXT JOURNEY","SIAPKAN PERJALANAN BERIKUTNYA","Vitality adds starting HP. Sword Power strengthens supported direct attacks. Swift Qi lowers the base cooldown; weapon floors and TEMPO still apply. Lv.10 opens free specialization on each path for new runs. Continue keeps its saved choices.","Vitality menambah HP awal. Sword Power memperkuat serangan langsung yang mendukungnya. Swift Qi menurunkan cooldown dasar; batas weapon dan TEMPO tetap berlaku. Lv.10 membuka spesialisasi gratis tiap jalur untuk run baru. Continue mempertahankan pilihan tersimpannya."],
 "events":["PLAY, PROGRESS, CLAIM","MAIN, MAJU, KLAIM","Weekly: Heavenly Trials has its own attempts and reset. Journey milestones: Boss Hunt, Pilgrimage, Ladder, Treasure Hunt and Five Elements follow their displayed conditions. Limited: Odyssey follows its confirmed schedule and earned-claim window.","Mingguan: Trial Surgawi memiliki percobaan dan reset sendiri. Milestone Journey: Perburuan Boss, Ziarah, Tangga Surgawi, Perburuan Harta dan Lima Elemen mengikuti syaratnya. Terbatas: Odyssey mengikuti jadwal terkonfirmasi dan masa klaim hadiah yang telah diperoleh."],
 "pavilion":["A TARGET FOR YOUR BUILD","TARGET UNTUK BUILDMU","Jade & Seals and Paid Jade have separate targets and guarantee progress. The selected mode shows its actual cost. Rarity guarantee and Wish Fate are different promises; changing a target can reset Fate as explained in Info.","Jade & Segel dan Jade Berbayar memiliki target dan progres jaminan terpisah. Mode yang dipilih menampilkan biaya aktual. Jaminan rarity dan Wish Fate berbeda; mengganti target dapat mereset Fate sesuai penjelasan Info."],
 "purchase":["PURCHASE & DELIVERY","PEMBELIAN & PENGIRIMAN","Use the current price shown by Google Play. Pending or verification is not a second purchase request. Wait for the confirmed balance; use Restore and the existing recovery tools for eligible deliveries. Do not purchase again to repair a pending receipt.","Gunakan harga aktual Google Play. Status tertunda atau verifikasi bukan permintaan membeli ulang. Tunggu saldo terkonfirmasi; gunakan Pulihkan dan alat pemulihan untuk pengiriman yang memenuhi syarat. Pembelian ulang tidak diperlukan untuk memperbaiki receipt tertunda."],
 "settings":["READABILITY FIRST","UTAMAKAN KETERBACAAN","High Contrast Warnings adds bright outlines and symbols with the same danger radius and timing. Reduced Effects and Quiet Player Ornament stay separate. Realm Approaches varies ordinary-enemy approach sectors in NEW Journey runs; counts, stats and elite slots stay authored. Continue keeps its captured rule.","Peringatan Kontras Tinggi menambah garis terang dan simbol dengan radius dan waktu bahaya yang sama. Kurangi Efek dan Ornamen Player Ringan tetap terpisah. Variasi Arah Realm mengubah sektor kedatangan musuh biasa pada run Journey BARU; jumlah, stat dan slot elite tetap. Continue memakai aturan tersimpannya."],
 "library":["YOUR NEXT STEP","LANGKAH BERIKUTMU","Review gear, techniques, boss patterns and realm stories. Journals are local records for this account on this device, not a reward or recovery service.","Tinjau gear, teknik, pola boss dan cerita realm. Jurnal adalah catatan lokal akun di perangkat ini, bukan layanan hadiah atau pemulihan."]}
var previous: Callable
var panel: PanelContainer
var safe: Control
var body: VBoxContainer
static func copy(en: String,id: String) -> String:return id if SettingsManager.language=="id" else en
static func label(text: String,px: int=24,color: Color=Color("d1e5dc")) -> Label:
 var value:=Label.new();value.text=text;value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;value.mouse_filter=MOUSE_FILTER_IGNORE;value.add_theme_font_size_override("font_size",px);value.add_theme_color_override("font_color",color);return value
static func skin() -> StyleBoxTexture:
 var value:=StyleBoxTexture.new();value.texture=Frame
 for edge: String in ["left","right","top","bottom"]:value.set("texture_margin_"+edge,18);value.set("content_margin_"+edge,16)
 return value
static func button(text: String,action: Callable) -> Button:
 var value:=Button.new();value.text=text;value.custom_minimum_size.y=72;value.size_flags_horizontal=SIZE_EXPAND_FILL;value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;value.mouse_filter=MOUSE_FILTER_PASS;value.action_mode=BaseButton.ACTION_MODE_BUTTON_RELEASE;value.add_theme_font_size_override("font_size",22)
 load("res://scripts/ui/result_ceremony.gd").style_button(value,"navy");value.custom_minimum_size.y=80;value.add_theme_font_size_override("font_size",24);value.pressed.connect(action);return value
static func section(parent: Node,title: String,text: String="") -> VBoxContainer:
 var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",skin());parent.add_child(card)
 var content:=VBoxContainer.new();content.size_flags_horizontal=SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);card.add_child(content);content.add_child(label(title,25,Gold))
 if not text.is_empty():content.add_child(label(text))
 return content
static func open(host: Node,key: String,data: Dictionary={}) -> Control:
 var existing: Node=host.get_node_or_null("ExperienceGuide")
 if existing!=null:return existing
 var value: Control=load("res://scripts/experience/menu_guide.gd").new();value.name="ExperienceGuide";value.set_meta("guide_key",key);value.set_meta("guide_data",data);host.add_child(value);return value
func _ready() -> void:
 z_index=800;process_mode=PROCESS_MODE_ALWAYS;set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 var dim:=ColorRect.new();dim.color=Color(.002,.018,.023,.88);dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(dim)
 safe=Control.new();safe.set_script(load("res://scripts/ui/mobile_safe_area.gd"));safe.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(safe)
 panel=PanelContainer.new();panel.name="ExperienceReader";panel.add_theme_stylebox_override("panel",skin());safe.add_child(panel)
 var outer:=VBoxContainer.new();outer.add_theme_constant_override("separation",12);panel.add_child(outer)
 var heading:=HBoxContainer.new();outer.add_child(heading)
 var title:=label(copy("CULTIVATOR'S COMPASS","KOMPAS KULTIVATOR"),26,Gold);title.size_flags_horizontal=SIZE_EXPAND_FILL;heading.add_child(title)
 var exit:=button("×",close);exit.name="ExperienceClose";exit.custom_minimum_size=Vector2(72,72);exit.size_flags_horizontal=SIZE_SHRINK_END;heading.add_child(exit)
 var scroll:=ScrollContainer.new();scroll.name="ExperienceScroll";scroll.size_flags_vertical=SIZE_EXPAND_FILL;Scroll.configure(scroll);outer.add_child(scroll)
 body=VBoxContainer.new();body.size_flags_horizontal=SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",14);scroll.add_child(body)
 previous=SceneTransitionManager.back_handler;SceneTransitionManager.set_back_handler(close);_content(str(get_meta("guide_key")),get_meta("guide_data",{}));Scroll.prepare_tree(scroll)
 safe.resized.connect(_fit);_fit.call_deferred()
func _fit() -> void:
 if not is_instance_valid(panel):return
 var dims: Vector2=safe.size
 if dims.x<=0 or dims.y<=0:dims=get_viewport_rect().size
 panel.size=Vector2(minf(600,dims.x-24),minf(920,dims.y-36));panel.position=(dims-panel.size)*.5
func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel") and not event.is_echo():close();get_viewport().set_input_as_handled()
func close() -> void:
 if SceneTransitionManager.back_handler==Callable(self,"close"):SceneTransitionManager.set_back_handler(previous if previous.is_valid() else Callable())
 queue_free()
func _exit_tree() -> void:
 if SceneTransitionManager.back_handler==Callable(self,"close"):SceneTransitionManager.set_back_handler(previous if previous.is_valid() else Callable())
func _journal(page: String) -> void:
 var host: Node=get_tree().current_scene;close();load("res://scripts/companion/player_journal.gd").open(host,page)
func _training() -> void:close();SceneTransitionManager.transition_menu_to("res://scenes/ui/training_ground.tscn")
func _page(key: String) -> void:
 for child: Node in body.get_children():body.remove_child(child);child.queue_free()
 _content(key,{});var scroll: ScrollContainer=body.get_parent() as ScrollContainer
 if scroll!=null:scroll.scroll_vertical=0;Scroll.prepare_tree(scroll)
func _content(key: String,data: Dictionary) -> void:
 if key=="preset":_preset(data);return
 if key=="timeline":_timeline(data);return
 if key=="weekly":_weekly();return
 if key=="odyssey":_odyssey();return
 var texts: Array=GUIDES.get(key,GUIDES.library)
 section(body,copy(texts[0],texts[1]),copy(texts[2],texts[3]))
 match key:
  "events":body.add_child(button(copy("OPEN EVENT AGENDA","BUKA AGENDA EVENT"),_journal.bind("agenda")))
  "pavilion":
   body.add_child(button(copy("TRACK A COLLECTION TARGET","IKUTI TARGET KOLEKSI"),_journal.bind("goal")))
   body.add_child(button(copy("REVIEW GEAR PRESETS","TINJAU PRESET GEAR"),_journal.bind("presets")))
  "settings":
   var preview: Control=load("res://scripts/experience/comfort_preview.gd").new();preview.custom_minimum_size.y=210;body.add_child(preview)
   section(body,copy("CURRENT COMFORT","KENYAMANAN AKTIF"),copy("Contrast %s · Quiet ornament %s · FPS %d","Kontras %s · Ornamen ringan %s · FPS %d")%[str(SettingsManager.high_contrast_warnings),str(SettingsManager.quiet_player_vfx),SettingsManager.frame_limit])
   body.add_child(button(copy("PURCHASE DELIVERY HELP","BANTUAN PENGIRIMAN PEMBELIAN"),func():_page("purchase")))
  "purchase":body.add_child(button(copy("SETTINGS & RECOVERY","PENGATURAN & PEMULIHAN"),func():close();SceneTransitionManager.transition_menu_to("res://scenes/ui/settings_screen.tscn")))
  _:body.add_child(button(copy("ENTER TRAINING COURT","MASUK PELATARAN LATIHAN"),_training))
func _preset(data: Dictionary) -> void:
 var index: int=int(data.get("index",-1));var preset: Dictionary=PlayerCompanion.state.presets.get(str(index),{})
 if preset.is_empty():section(body,copy("EMPTY PRESET","PRESET KOSONG"),copy("Save a loadout in the existing Journal first.","Simpan loadout melalui Jurnal terlebih dahulu."));return
 var before: Dictionary=Gear.project(Gear.slots());var after: Dictionary=Gear.project(preset.slots)
 section(body,str(preset.name),copy("Whole equipment loadout · next NEW run only. Continue keeps saved gear. Gear contribution, not predicted DPS.","Seluruh equipment · khusus run BARU berikutnya. Continue mempertahankan gear tersimpan. Kontribusi gear, bukan prediksi DPS."))
 for row: Array in [["max_health_flat","HP",1.0],["damage_bonus","Damage %",100.0],["critical_chance_bonus","Crit %",100.0],["movement_speed_bonus","Move %",100.0],["experience_bonus","EXP %",100.0]]:
  var a: float=float(before[row[0]])*row[2];var b: float=float(after[row[0]])*row[2];body.add_child(label("%s %.1f → %.1f (%+.1f)"%[row[1],a,b,b-a],24,Jade if b>=a else Color("f39787")))
 for pair: Array in [[before,copy("CURRENT","SEKARANG")],[after,"PRESET"]]:
  var model: Dictionary=pair[0];section(body,pair[1],"%s %d/4 · %s"%[model.set.display_name,model.set.piece_count,str(model.passive.get("name",copy("No active four-piece passive","Tanpa pasif empat set")))])
 if PlayerCompanion.preset_problem(index).is_empty():body.add_child(button(copy("APPLY THIS PRESET","PAKAI PRESET INI"),func():
  if PlayerCompanion.apply_preset(index):close()
  else:section(body,copy("NOT APPLIED","BELUM DIPAKAI"),copy("Ownership, gear or run status changed. Review the Journal.","Kepemilikan, gear atau status run berubah. Periksa Jurnal."))))
 else:section(body,copy("PREVIEW ONLY","PRATINJAU SAJA"),copy("Match verified gear and ownership; finish combat or save recovery before applying.","Samakan gear terverifikasi dan kepemilikan; selesaikan combat atau pemulihan save sebelum memakai."))
func _timeline(data: Dictionary) -> void:
 var snapshot: Dictionary=load("res://scripts/data/hit_timeline.gd").clean(data)
 section(body,copy("LAST TEN SECONDS · HP EVENTS","SEPULUH DETIK TERAKHIR · HIT KE HP"),copy("Actual HP lost after defenses. Shield blocks are not HP hits. This does not prove attacker position or dodge inputs.","HP aktual yang hilang setelah pertahanan. Blok shield bukan hit ke HP. Catatan ini tidak membuktikan posisi penyerang atau input menghindar."))
 if snapshot.is_empty() or not bool(snapshot.complete):body.add_child(label(copy("Legacy / incomplete timeline. Earlier hits cannot be reconstructed.","Timeline lama / belum lengkap. Hit terdahulu tidak dapat direkonstruksi."),24,Gold))
 var events: Array[Dictionary]=load("res://scripts/data/hit_timeline.gd").recent(snapshot)
 var names: Dictionary={"unknown":copy("Unknown source","Sumber tidak diketahui"),"melee":"Melee","projectile":copy("Projectile","Proyektil"),"lightning":copy("Lightning","Petir"),"shockwave":copy("Shockwave","Gelombang Qi"),"area":copy("Area attack","Serangan area")}
 for event: Dictionary in events:section(body,"−%.1fs · %s"%[maxf(0,float(snapshot.clock)-event.time),names[event.source]],copy("HP lost %.1f · HP left %.1f","HP hilang %.1f · HP tersisa %.1f")%[event.loss,event.hp])
 if events.is_empty():body.add_child(label(copy("No recorded HP hits in this window.","Tidak ada hit ke HP tercatat pada rentang ini.")))
func _weekly() -> void:
 var client: Node=get_node_or_null("/root/HeavenlyTrialsClient");var week: Dictionary=client.snapshot.get("week",{}) if client!=null and client.snapshot.get("week") is Dictionary else {}
 if week.is_empty():section(body,copy("WAITING FOR WEEK RULES","MENUNGGU ATURAN MINGGU"),copy("Connect to read confirmed rules; patterns and rewards are not invented offline.","Sambungkan untuk membaca aturan terkonfirmasi; pola dan hadiah tidak ditebak saat offline."));return
 section(body,copy("READ THE WEEKLY PATTERN","BACA POLA MINGGUAN"),load("res://scripts/data/trial_counterplay.gd").hint(str(week.get("theme","")),int(week.get("ruleset_version",1)),SettingsManager.language))
 var diagram: Control=load("res://scripts/experience/rule_diagram.gd").new();diagram.custom_minimum_size.y=230;body.add_child(diagram)
 section(body,copy("POSITION, WATCH, RETURN","POSISI, AMATI, KEMBALI"),copy("Leave the marked danger, use open space, return to attack range. Illustrative counterplay, not a live hitbox or timer. Personal risks keep the same weekly reward.","Tinggalkan bahaya bertanda, gunakan ruang terbuka, kembali ke jangkauan serang. Ilustrasi counterplay, bukan hitbox atau timer live. Risiko pribadi mempertahankan hadiah mingguan yang sama."))
func _odyssey() -> void:
 section(body,copy("MAKE EACH JOURNEY COUNT","PAHAMI SETIAP PERJALANAN"),copy("Dice use a ticket only on an accepted action. Read actual route and guardian options before continuing. On lap rules, only full laps past START count.","Dadu memakai tiket hanya pada aksi yang diterima. Baca opsi jalur dan penjaga sebelum melanjutkan. Pada aturan putaran, hanya putaran penuh melewati START yang dihitung."))
 var client: Node=get_node_or_null("/root/OdysseyClient");var state: Dictionary=client.snapshot.get("state",{}) if client!=null and client.snapshot.get("state") is Dictionary else {}
 if state.is_empty():
  section(body,copy("WAITING FOR YOUR PROGRESS","MENUNGGU PROGRESMU"),copy("Connect to read your confirmed route, lap rules and earned milestones. No progress total is assumed offline.","Sambungkan untuk membaca rute, aturan putaran dan milestone terkonfirmasi. Total progres tidak ditebak saat offline."));return
 section(body,copy("YOUR CURRENT TARGET","TARGET SAAT INI"),copy("Confirmed progress %d/%d. Claim ready milestones, then collect equipment in Mail. Confirmed time determines play and earned-claim periods.","Progres terkonfirmasi %d/%d. Klaim milestone yang siap, lalu ambil equipment di Mail. Waktu terkonfirmasi menentukan masa bermain dan klaim.")%[load("res://scripts/data/odyssey_progress.gd").current(state),load("res://scripts/data/odyssey_progress.gd").goal(state)])
