extends Control

const Art = preload("res://scripts/weapon/jade_binding_art.gd")
const Icon = preload("res://assets/ui/equipment/final/jade_binding_chain.png")
const Imperial = preload("res://scripts/ui/pavilion_imperial_style.gd")
var age: float = 0.0
var sample_remaining: float = 0.0
var phase_label: Label
var demonstration: Control

func _ready() -> void:
	name = "JadeBindingPreview"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.015, 0.01, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(get_viewport_rect().size.x - 32.0, 460.0)
	panel.add_theme_stylebox_override("panel", Imperial.new())
	center.add_child(panel)
	var box := VBoxContainer.new()
	var compact: bool = get_viewport_rect().size.y < 700.0
	box.add_theme_constant_override("separation", 6 if compact else 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "JADE BINDING CHAIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Art.GOLD)
	box.add_child(title)
	var rarity := Label.new()
	rarity.text = "LEGENDARY  •  ★1 → ★5"
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_color_override("font_color", Art.GOLD)
	box.add_child(rarity)
	var icon := TextureRect.new()
	icon.texture = Icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.y = 48.0 if compact else 96.0
	box.add_child(icon)
	demonstration = Control.new()
	demonstration.custom_minimum_size.y = 120.0 if compact else 200.0
	demonstration.draw.connect(_draw_demonstration)
	box.add_child(demonstration)
	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_color_override("font_color", Art.JADE)
	box.add_child(phase_label)
	var description := Label.new()
	description.text = "Segel → ikat → ledakan simpul.\nSlow 40% / 0.72s • Boss 12%\nLv.1/3/5/7: 2/3/4/5 target\nCooldown 1.8s (min. 1.25s).\nAscension: stat lebih kuat."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13 if compact else 15)
	box.add_child(description)
	var close := Button.new()
	close.text = "TUTUP PREVIEW"
	close.custom_minimum_size.y = 44.0
	close.add_theme_stylebox_override("normal", Imperial.new())
	close.pressed.connect(queue_free)
	box.add_child(close)
	close.grab_focus()

func _process(delta: float) -> void:
	sample_remaining -= delta
	if sample_remaining > 0.0: return
	sample_remaining = 0.05
	age = fmod(age + 0.05, 2.2)
	phase_label.text = "01 • SEGEL" if age < 0.22 else ("02 • IKAT & TEGANGKAN" if age < 0.82 else "03 • KNOT JUDGMENT")
	if SettingsManager.reduced_effects: phase_label.text = "IKATAN • PRATINJAU STATIS"
	demonstration.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()

func _draw_demonstration() -> void:
	var c: Vector2 = demonstration.size * Vector2(0.5, 0.48)
	var points: Array[Vector2] = [c + Vector2(-45, 10), c + Vector2(46, -15)]
	var t: float = 0.60 if SettingsManager.reduced_effects else age
	var fade: float = clampf((1.55 - t) / 0.4, 0.0, 1.0)
	Art.seal(demonstration, c, 70.0 * (0.65 + minf(t / 0.22, 1.0) * 0.35), t, fade, SettingsManager.reduced_effects)
	for i: int in range(points.size()):
		demonstration.draw_circle(points[i], 9.0, Color(0.18, 0.26, 0.23))
		demonstration.draw_arc(points[i], 9, 0, TAU, 16, Color(0.66, 0.75, 0.66), 1.3, true)
		if t >= 0.22 and t < 0.82 + i * 0.10:
			Art.chain(demonstration, c, points[i], t + i, fade, SettingsManager.reduced_effects)
			Art.knot(demonstration, points[i], 10.0, fade)
		if t >= 0.82 + i * 0.10:
			Art.burst(demonstration, points[i], minf((t - 0.82 - i * 0.10) / 0.42, 1.0), SettingsManager.reduced_effects)
