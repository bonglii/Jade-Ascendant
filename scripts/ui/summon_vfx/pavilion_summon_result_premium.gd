extends Control

## Production premium landing/result composition for Pavilion summons.
## v8e exact user-requested fix:
## - remove the upper item rarity frame for every rarity
## - enlarge only the lower equipment-name nameplate
## - keep every other size/position/animation unchanged

const BACKDROP_PATH: String = "res://assets/ui/pavilion/result_premium/celestial_result_backdrop.png"
const PEDESTAL_PATH: String = "res://assets/ui/pavilion/result_premium/celestial_result_pedestal.png"
const HALO_PATH: String = "res://assets/ui/pavilion/vfx/shared/soft_halo_premium.png"

const FRAME_PATHS: Dictionary = {
	"common": "res://assets/ui/pavilion/result_premium/frame_common.png",
	"rare": "res://assets/ui/pavilion/result_premium/frame_rare.png",
	"epic": "res://assets/ui/pavilion/result_premium/frame_epic.png",
	"legendary": "res://assets/ui/pavilion/result_premium/frame_legendary.png",
}

const NAMEPLATE_PATHS: Dictionary = {
	"common": "res://assets/ui/pavilion/result_premium/nameplate_common.png",
	"rare": "res://assets/ui/pavilion/result_premium/nameplate_rare.png",
	"epic": "res://assets/ui/pavilion/result_premium/nameplate_epic.png",
	"legendary": "res://assets/ui/pavilion/result_premium/nameplate_legendary.png",
}

var _backdrop: TextureRect
var _veil: ColorRect
var _pedestal: TextureRect
var _halo: TextureRect
var _frame: TextureRect
var _item_icon: TextureRect
var _nameplate: TextureRect
var _copy_clip: Control
var _item_name: Label
var _meta_line: Label
var _description_title: Label
var _description_body: Label
var _state_panel: PanelContainer
var _state_label: Label
var _active_tween: Tween
var _current_rarity: String = "common"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_visuals()
	resized.connect(_layout_visuals)
	call_deferred("_layout_visuals")
	hide_result()


func show_result(
	rarity_id: String,
	item_icon_path: String,
	item_name: String,
	meta_text: String,
	description_title: String,
	description_text: String,
	state_text: String,
	animated: bool = true
) -> void:
	var rarity: String = rarity_id.to_lower()
	if not FRAME_PATHS.has(rarity):
		rarity = "common"
	_current_rarity = rarity

	_kill_active_tween()

	_frame.texture = load(str(FRAME_PATHS[rarity])) as Texture2D
	_frame.visible = false
	_nameplate.texture = load(str(NAMEPLATE_PATHS[rarity])) as Texture2D
	_item_icon.texture = load(item_icon_path) as Texture2D
	_item_name.text = item_name
	_meta_line.text = meta_text
	_description_title.text = description_title
	_description_title.visible = not description_title.is_empty()
	_description_body.text = description_text
	_description_body.visible = not description_text.is_empty()
	_state_label.text = state_text

	_apply_rarity_copy_palette(rarity)
	visible = true
	_layout_visuals()

	_backdrop.modulate = Color(1, 1, 1, 0)
	_pedestal.modulate = Color(1, 1, 1, 0)
	_halo.modulate = Color(1, 1, 1, 0)
	_halo.scale = Vector2(0.86, 0.86)
	_frame.modulate = Color(1, 1, 1, 0)
	_frame.visible = false
	_frame.scale = Vector2(0.96, 0.96)
	_item_icon.modulate = Color(1, 1, 1, 0)
	_item_icon.scale = Vector2(0.78, 0.78)
	_nameplate.modulate = Color(1, 1, 1, 0)
	_nameplate.scale = Vector2(0.98, 0.98)
	_copy_clip.modulate = Color(1, 1, 1, 0)
	_state_panel.modulate = Color(1, 1, 1, 0)
	_veil.color = Color(0.02, 0.03, 0.028, 0.0)

	var pedestal_alpha: float = 0.10
	var halo_alpha: float = 0.22
	match rarity:
		"rare":
			pedestal_alpha = 0.12
			halo_alpha = 0.26
		"epic":
			pedestal_alpha = 0.14
			halo_alpha = 0.32
		"legendary":
			pedestal_alpha = 0.16
			halo_alpha = 0.40

	if not animated:
		_backdrop.modulate.a = 0.94
		_pedestal.modulate.a = pedestal_alpha
		_halo.modulate.a = halo_alpha
		_halo.scale = Vector2.ONE
		_frame.modulate.a = 0.0
		_frame.scale = Vector2.ONE
		_item_icon.modulate.a = 1.0
		_item_icon.scale = Vector2.ONE
		_nameplate.modulate.a = 1.0
		_nameplate.scale = Vector2.ONE
		_copy_clip.modulate.a = 1.0
		_state_panel.modulate.a = 1.0
		_veil.color = Color(0.02, 0.03, 0.028, 0.04)
		return

	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(_backdrop, "modulate:a", 0.94, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_pedestal, "modulate:a", pedestal_alpha, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_halo, "modulate:a", halo_alpha, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_halo, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_item_icon, "modulate:a", 1.0, 0.18).set_delay(0.03).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_item_icon, "scale", Vector2.ONE, 0.36).set_delay(0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_nameplate, "modulate:a", 1.0, 0.18).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_nameplate, "scale", Vector2.ONE, 0.24).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_copy_clip, "modulate:a", 1.0, 0.18).set_delay(0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_state_panel, "modulate:a", 1.0, 0.18).set_delay(0.11).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_veil, "color", Color(0.02, 0.03, 0.028, 0.04), 0.20)


func hide_result() -> void:
	_kill_active_tween()
	visible = false


func _build_visuals() -> void:
	_backdrop = TextureRect.new()
	_backdrop.texture = load(BACKDROP_PATH) as Texture2D
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.z_index = 0
	add_child(_backdrop)

	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.z_index = 1
	add_child(_veil)

	_pedestal = TextureRect.new()
	_pedestal.texture = load(PEDESTAL_PATH) as Texture2D
	_pedestal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pedestal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pedestal.z_index = 2
	add_child(_pedestal)

	_halo = TextureRect.new()
	_halo.texture = load(HALO_PATH) as Texture2D
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.z_index = 3
	var halo_material := CanvasItemMaterial.new()
	halo_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = halo_material
	add_child(_halo)

	_frame = TextureRect.new()
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.z_index = 4
	_frame.visible = false
	add_child(_frame)

	_item_icon = TextureRect.new()
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_icon.z_index = 5
	add_child(_item_icon)

	_state_panel = PanelContainer.new()
	_state_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_state_panel.z_index = 6
	add_child(_state_panel)

	_state_label = Label.new()
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_state_label.add_theme_font_size_override("font_size", 11)
	_state_panel.add_child(_state_label)

	_nameplate = TextureRect.new()
	_nameplate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nameplate.stretch_mode = TextureRect.STRETCH_SCALE
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.z_index = 7
	add_child(_nameplate)

	_copy_clip = Control.new()
	_copy_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_copy_clip.clip_contents = true
	_copy_clip.z_index = 8
	add_child(_copy_clip)

	_item_name = _make_copy_label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_copy_clip.add_child(_item_name)

	_meta_line = _make_copy_label(13, HORIZONTAL_ALIGNMENT_CENTER)
	_copy_clip.add_child(_meta_line)

	_description_title = _make_copy_label(11, HORIZONTAL_ALIGNMENT_CENTER)
	_copy_clip.add_child(_description_title)

	_description_body = _make_copy_label(11, HORIZONTAL_ALIGNMENT_CENTER)
	_description_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_clip.add_child(_description_body)


func _make_copy_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _layout_visuals() -> void:
	if _backdrop == null:
		return
	var viewport_size: Vector2 = size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return

	_backdrop.position = Vector2.ZERO
	_backdrop.size = viewport_size

	_veil.position = Vector2.ZERO
	_veil.size = viewport_size

	# EXACT ZONE CONTRACT FROM USER MARKUP:
	# Upper large zone = equipment + rarity border only.
	# Lower compact zone = equipment name + info only.
	var hero_center := Vector2(viewport_size.x * 0.50, viewport_size.y * 0.46)

	var pedestal_width: float = minf(viewport_size.x * 1.05, 430.0)
	_pedestal.size = Vector2(pedestal_width, pedestal_width)
	_pedestal.position = Vector2(
		(viewport_size.x - pedestal_width) * 0.5,
		viewport_size.y * 0.16
	)
	_pedestal.pivot_offset = _pedestal.size * 0.5

	# Border is intentionally large and tall, but shares the SAME hero center
	# with the equipment. Optical offsets compensate for asymmetric artwork.
	var frame_height: float = minf(viewport_size.y * 0.96, 620.0)
	var frame_width: float = frame_height * (418.0 / 937.0)
	_frame.size = Vector2(frame_width, frame_height)
	var optical_offset: Vector2 = _frame_optical_offset(_current_rarity, _frame.size)
	_frame.position = hero_center - (_frame.size * 0.5) + optical_offset
	_frame.pivot_offset = _frame.size * 0.5

	# Reward art is now truly the hero: width-driven instead of height-limited.
	var item_size: float = minf(viewport_size.x * 0.94, 380.0)
	_item_icon.size = Vector2(item_size, item_size)
	_item_icon.position = hero_center - (_item_icon.size * 0.5)
	_item_icon.pivot_offset = _item_icon.size * 0.5

	var halo_size: float = item_size * 1.78
	_halo.size = Vector2(halo_size, halo_size)
	_halo.position = hero_center - (_halo.size * 0.5)
	_halo.pivot_offset = _halo.size * 0.5

	# Compact copy block lives ONLY in the lower zone marked by the user.
	var plate_width: float = minf(viewport_size.x * 1.16, 468.0)
	var base_plate_height: float = plate_width * (458.0 / 836.0)
	var plate_height: float = base_plate_height * 1.22
	var previous_plate_y: float = minf(
		viewport_size.y * 0.755,
		viewport_size.y - base_plate_height - 8.0
	)
	# Extend ONLY the upper edge of the nameplate upward.
	# The bottom edge, text block and badge keep their v8e positions.
	var plate_y: float = previous_plate_y - (plate_height - base_plate_height)
	_nameplate.size = Vector2(plate_width, plate_height)
	_nameplate.position = Vector2(
		(viewport_size.x - plate_width) * 0.5,
		plate_y
	)
	_nameplate.pivot_offset = _nameplate.size * 0.5

	var copy_width: float = plate_width * 0.86
	var copy_height: float = base_plate_height * 0.61
	_copy_clip.size = Vector2(copy_width, copy_height)
	_copy_clip.position = Vector2(
		viewport_size.x * 0.5 - copy_width * 0.5,
		previous_plate_y + base_plate_height * 0.13
	)

	_item_name.position = Vector2.ZERO
	_item_name.size = Vector2(copy_width, copy_height * 0.31)
	_item_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_meta_line.position = Vector2(0.0, copy_height * 0.29)
	_meta_line.size = Vector2(copy_width, copy_height * 0.16)
	_meta_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_description_title.position = Vector2(0.0, copy_height * 0.45)
	_description_title.size = Vector2(copy_width, copy_height * 0.13)
	_description_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_description_body.position = Vector2(3.0, copy_height * 0.58)
	_description_body.size = Vector2(copy_width - 6.0, copy_height * 0.38)
	_description_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# State badge sits immediately above the lower info block, never inside hero art.
	var state_width: float = minf(viewport_size.x * 0.58, 230.0)
	var state_height: float = 22.0
	_state_panel.size = Vector2(state_width, state_height)
	_state_panel.position = Vector2(
		(viewport_size.x - state_width) * 0.5,
		previous_plate_y - state_height - 6.0
	)


func _frame_optical_offset(rarity: String, frame_size: Vector2) -> Vector2:
	# Measured from the approved PNG alpha mass, not guessed by eye.
	# Positive X/Y moves the artwork right/down so its VISUAL center aligns
	# with the equipment hero center.
	match rarity:
		"rare":
			return Vector2(frame_size.x * 0.032, frame_size.y * 0.056)
		"epic":
			return Vector2(frame_size.x * 0.029, frame_size.y * 0.023)
		"legendary":
			return Vector2(frame_size.x * 0.044, frame_size.y * 0.027)
		"common":
			return Vector2(frame_size.x * -0.007, frame_size.y * 0.044)
		_:
			return Vector2.ZERO


func _apply_rarity_copy_palette(rarity: String) -> void:
	var name_color := Color(0.10, 0.20, 0.18, 1.0)
	var meta_color := Color(0.24, 0.39, 0.34, 0.98)
	var detail_color := Color(0.20, 0.32, 0.29, 0.98)
	var state_accent := Color(0.30, 0.78, 0.62, 1.0)
	match rarity:
		"rare":
			name_color = Color(0.055, 0.15, 0.30, 1.0)
			meta_color = Color(0.10, 0.28, 0.50, 0.98)
			detail_color = Color(0.10, 0.24, 0.42, 0.98)
			state_accent = Color(0.26, 0.72, 1.0, 1.0)
		"epic":
			name_color = Color(0.23, 0.075, 0.34, 1.0)
			meta_color = Color(0.38, 0.13, 0.52, 0.98)
			detail_color = Color(0.32, 0.11, 0.45, 0.98)
			state_accent = Color(0.74, 0.42, 1.0, 1.0)
		"legendary":
			name_color = Color(0.40, 0.13, 0.025, 1.0)
			meta_color = Color(0.55, 0.24, 0.04, 0.98)
			detail_color = Color(0.47, 0.19, 0.03, 0.98)
			state_accent = Color(1.0, 0.70, 0.18, 1.0)
	_item_name.add_theme_color_override("font_color", name_color)
	_meta_line.add_theme_color_override("font_color", meta_color)
	_description_title.add_theme_color_override("font_color", meta_color)
	_description_body.add_theme_color_override("font_color", detail_color)
	_state_label.add_theme_color_override("font_color", state_accent)

	var state_style := StyleBoxFlat.new()
	state_style.bg_color = Color(state_accent.r * 0.08, state_accent.g * 0.08, state_accent.b * 0.08, 0.88)
	state_style.border_color = Color(state_accent.r, state_accent.g, state_accent.b, 0.76)
	state_style.set_border_width_all(1)
	state_style.corner_radius_top_left = 14
	state_style.corner_radius_top_right = 14
	state_style.corner_radius_bottom_left = 14
	state_style.corner_radius_bottom_right = 14
	_state_panel.add_theme_stylebox_override("panel", state_style)


func _kill_active_tween() -> void:
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null
