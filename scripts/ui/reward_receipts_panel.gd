extends Control
var records: Array[Dictionary]=[]
var _panel: Panel
var _previous_back: Callable
func _ready() -> void:
 name="RewardReceiptsPanel";z_index=450;process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var dim:=ColorRect.new();dim.color=Color(0,.015,.02,.7);add_child(dim);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 dim.gui_input.connect(func(event: InputEvent):if event is InputEventMouseButton and event.pressed:close())
 _panel=Panel.new();_panel.name="ReceiptPaper";_panel.clip_contents=true;add_child(_panel)
 var style:=StyleBoxTexture.new();style.texture=load("res://assets/ui/trials/ascendant_v2/record_frame.svg")
 for edge: String in ["left","right","top","bottom"]:style.set("texture_margin_"+edge,18);style.set("content_margin_"+edge,20)
 _panel.add_theme_stylebox_override("panel",style)
 var body:=VBoxContainer.new();body.name="ReceiptBody";body.add_theme_constant_override("separation",12);_panel.add_child(body);body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=20;body.offset_top=20;body.offset_right=-20;body.offset_bottom=-20
 var heading:=HBoxContainer.new();body.add_child(heading);heading.add_child(_copy("RECENT REWARDS",20))
 var close_button:=Button.new();close_button.name="CloseReceipts";close_button.text="×";close_button.custom_minimum_size=Vector2(44,44);close_button.pressed.connect(close);heading.add_child(close_button)
 body.add_child(_copy("Received on this device · up to 30 records.",14))
 var scroll:=ScrollContainer.new();scroll.name="ReceiptScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",10);scroll.add_child(list)
 if records.is_empty():list.add_child(_copy("Newly received rewards will appear here. Earlier claims remain safe in your inventory.",17))
 for entry: Dictionary in records:
  var card:=PanelContainer.new();list.add_child(card)
  var skin:=StyleBoxTexture.new();skin.texture=load("res://assets/ui/trials/ascendant_v2/record_frame.svg")
  for edge: String in ["left","right","top","bottom"]:skin.set("texture_margin_"+edge,18);skin.set("content_margin_"+edge,12)
  card.add_theme_stylebox_override("panel",skin)
  var copy:=VBoxContainer.new();copy.add_theme_constant_override("separation",8);card.add_child(copy)
  var local_time: Dictionary=Time.get_datetime_dict_from_unix_time(int(entry.time)+int(Time.get_time_zone_from_system().get("bias",0))*60)
  copy.add_child(_copy("%02d/%02d %02d:%02d · %s"%[local_time.day,local_time.month,local_time.hour,local_time.minute,str(entry.source)],15))
  copy.add_child(_copy(RewardManager.get_reward_summary(entry.reward).replace("\n"," · "),17))
 resized.connect(_layout);_layout()
 preload("res://scripts/ui/mobile_scroll_policy.gd").prepare_tree(self)
 _previous_back=SceneTransitionManager.back_handler;SceneTransitionManager.set_back_handler(close)
func _copy(value: String, font_size: int) -> Label:
 var label:=Label.new();label.text=tr(value);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",Color(.95,.86,.63));return label
func _layout() -> void:
 if _panel==null:return
 var dims:=Vector2(minf(520,maxf(240,size.x-24)),minf(600,maxf(250,size.y-40)));_panel.position=(size-dims)*.5;_panel.size=dims
func close() -> void:queue_free()
func _exit_tree() -> void:
 if SceneTransitionManager.back_handler==Callable(self,"close"):SceneTransitionManager.set_back_handler(_previous_back if _previous_back.is_valid() else Callable())
