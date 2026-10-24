extends CanvasLayer
## Presentation only. ProgressionManager commits EXP and remains its authority.
## Coalesce a multi-level grant; never replay loaded levels or create rewards.
const FRAME: Texture2D = preload("res://assets/ui/home/sanctuary/frame_compact.png")
const SERIF: Font = preload("res://assets/ui/library/fonts/archive_serif.ttf")
var from_level: int = 0
var to_level: int = 0
var settle_left: float = 0.0
var hold_left: float = 0.0
var panel: PanelContainer
var title: Label
var detail: Label
var frame: NinePatchRect
var shown_level: int = 0
var _account_owner: String = ""

func _ready() -> void:
	layer = 195
	process_mode = Node.PROCESS_MODE_ALWAYS
	_account_owner = GoogleAccountManager.get_monetization_account_binding()
	ProgressionManager.hero_level_up.connect(_earned_level)
	GoogleAccountManager.account_state_changed.connect(_account_changed)
	panel = PanelContainer.new()
	panel.name = "HeroLevelCelebration"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	add_child(panel)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(.008, .045, .042, .98)
	fill.set_corner_radius_all(12)
	fill.content_margin_left = 23; fill.content_margin_right = 23
	fill.content_margin_top = 18; fill.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", fill)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var eyebrow := Label.new()
	eyebrow.name = "LevelUpEyebrow"
	eyebrow.text = "LIN YUE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(.54, .92, .78))
	column.add_child(eyebrow)
	title = Label.new()
	title.name = "HeroLevelUpTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", SERIF)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, .87, .53))
	column.add_child(title)
	detail = Label.new()
	detail.name = "HeroLevelUpDetail"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_font_size_override("font_size", 14)
	column.add_child(detail)
	frame = NinePatchRect.new()
	frame.texture = FRAME
	frame.draw_center = false
	frame.patch_margin_left = 38; frame.patch_margin_right = 38
	frame.patch_margin_top = 20; frame.patch_margin_bottom = 20
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	get_viewport().size_changed.connect(_layout)

func _account_changed(_snapshot: Dictionary) -> void:
	var binding_value: String = GoogleAccountManager.get_monetization_account_binding()
	if binding_value == _account_owner: return
	_account_owner = binding_value
	from_level = 0; to_level = 0; hold_left = 0
	panel.hide()
	frame.hide()

func _earned_level(level: int) -> void:
	if from_level == 0: from_level = maxi(1, level - 1)
	to_level = maxi(to_level, level)
	settle_left = .25

func _process(delta: float) -> void:
	# A toast must not cover a run upgrade, Pause, loading or first-entry login.
	var scene: Node = get_tree().current_scene
	var victory: CanvasLayer = scene.get_node_or_null("VictoryUI") as CanvasLayer if scene != null else null
	var result_ready: bool = victory != null and victory.visible
	var safe: bool = ((scene is Control and not get_tree().paused) or result_ready) and not SceneTransitionManager.is_transitioning and not scene.scene_file_path.ends_with("google_account_entry.tscn") and not scene.scene_file_path.ends_with("boot.tscn")
	panel.visible = safe and hold_left > 0
	frame.visible = panel.visible
	if not safe: return
	if to_level > 0:
		settle_left -= delta
		if settle_left <= 0:
			var id: bool = SettingsManager.language == "id"
			title.text = "LEVEL NAIK!" if id else "LEVEL UP!"
			detail.text = ("Lv.%d → %d · %s" % [from_level, to_level, tr(ProgressionManager.get_hero_rank_title_for_level(to_level))])
			shown_level = to_level
			from_level = 0; to_level = 0
			hold_left = 4.0
			panel.show()
			frame.show()
			_layout()
	if hold_left > 0: hold_left = maxf(0, hold_left - delta)

func _layout() -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect()
	var safe := bounds
	var scene: Node = get_tree().current_scene
	if scene != null:
		var area: Control = scene.find_child("SafeArea", true, false) as Control
		if area != null: safe = area.get_global_rect()
	panel.size = Vector2(minf(400, maxf(220, safe.size.x - 28)), 126)
	panel.position = Vector2(safe.position.x + (safe.size.x - panel.size.x) * .5, safe.position.y + maxf(14, (safe.size.y - panel.size.y) * .26))
	if shown_level > 0: title.text = "LEVEL NAIK!" if SettingsManager.language == "id" else "LEVEL UP!"
	frame.position = panel.position
	frame.size = panel.size
