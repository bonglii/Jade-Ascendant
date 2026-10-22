extends Control
const Messages=preload("res://scripts/data/run_entry_messages.gd")
const FRAME=preload("res://assets/ui/trials/ascendant_v2/record_frame.svg")
var _panel: Panel
var _previous_back: Callable
var _retry: Callable
var _view: Dictionary={}
static func open(host: Node,reason: String,owner_hint: String="",retry: Callable=Callable()) -> Control:
 var existing: Control=host.get_node_or_null("PaidRunNotice") as Control
 if existing!=null:return existing
 var sheet=load("res://scripts/ui/run_verification_notice.gd").new()
 sheet.name="PaidRunNotice";sheet._view=Messages.view(reason,str(host.get_node("/root/SettingsManager").get("language")),owner_hint);sheet._retry=retry;host.add_child(sheet)
 return sheet
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var veil:=ColorRect.new();veil.color=Color(.003,.014,.020,.67);add_child(veil);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _panel=Panel.new();_panel.name="VerificationPaper";_panel.clip_contents=true
 var style:=StyleBoxTexture.new();style.texture=FRAME
 for edge: String in ["left","right","top","bottom"]:style.set("texture_margin_"+edge,18)
 _panel.add_theme_stylebox_override("panel",style);add_child(_panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",12);_panel.add_child(box);box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);box.offset_left=22;box.offset_right=-22;box.offset_top=20;box.offset_bottom=-20
 var top:=HBoxContainer.new();box.add_child(top)
 var eyebrow: Label=_label("VERIFIKASI RUN" if _language()=="id" else "RUN VERIFICATION",12,Color("7cddba"));eyebrow.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(eyebrow)
 var exit: Button=_button("×");exit.name="CloseVerification";exit.custom_minimum_size=Vector2(44,44);exit.pressed.connect(close);top.add_child(exit)
 box.add_child(_label(str(_view.title),24,Color("ead19a")))
 var scroll:=ScrollContainer.new();scroll.name="VerificationScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;box.add_child(scroll)
 var body: Label=_label(str(_view.body),16,Color("e4e9df"));body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
 box.add_child(_label(str(_view.footer),12,Color("a6bdb0")))
 var action: String=str(_view.action)
 if action!="close":
  var value: String=("PERIKSA AKUN" if _language()=="id" else "CHECK ACCOUNT") if action=="account" else ("BUKA HERO" if _language()=="id" else "OPEN HERO") if action=="hero" else ("COBA LAGI" if _language()=="id" else "RETRY")
  var primary:=_button(value);primary.name="VerificationAction";primary.custom_minimum_size.y=50;primary.pressed.connect(_act.bind(action));box.add_child(primary)
 _previous_back=_transition().back_handler;_transition().set_back_handler(close)
 resized.connect(_layout);_layout()
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(self)
 if not bool(get_node("/root/SettingsManager").get("reduced_effects")):modulate.a=0;create_tween().tween_property(self,"modulate:a",1.0,.12)
func _label(value: String,point_size: int,color: Color) -> Label:
 var label:=Label.new();label.text=value;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",point_size);label.add_theme_color_override("font_color",color);label.set_meta("jade_mobile_readability_v2",true);return label
func _button(value: String) -> Button:
 var button:=Button.new();button.text=value;button.focus_mode=Control.FOCUS_NONE;button.add_theme_font_size_override("font_size",16)
 var style:=StyleBoxFlat.new();style.bg_color=Color("123d35");style.border_color=Color("bca16a");style.set_border_width_all(1);style.set_corner_radius_all(10)
 for state: String in ["normal","hover","focus"]:button.add_theme_stylebox_override(state,style)
 var pressed: StyleBoxFlat=style.duplicate();pressed.bg_color=Color("285849");button.add_theme_stylebox_override("pressed",pressed);return button
func _layout() -> void:
 if not is_instance_valid(_panel):return
 _panel.size=Vector2(minf(460,maxf(220,size.x-32)),minf(420,maxf(240,size.y-72)));_panel.position=(size-_panel.size)*.5
func _act(action: String) -> void:
 var retry: Callable=_retry
 close()
 if action=="retry" and retry.is_valid():retry.call_deferred()
 elif action in ["account","hero"]:_transition().transition_menu_to("res://scenes/ui/settings_screen.tscn" if action=="account" else "res://scenes/ui/equipment_screen.tscn")
func close() -> void:
 if _transition().back_handler==Callable(self,"close"):_transition().set_back_handler(_previous_back)
 hide();mouse_filter=Control.MOUSE_FILTER_IGNORE;queue_free()

func _language() -> String:return str(get_node("/root/SettingsManager").get("language"))
func _transition() -> Node:return get_node("/root/SceneTransitionManager")
