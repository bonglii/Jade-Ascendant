extends Node
class_name RewardFlyToNavbarLabController

## LAB-only reusable reward-flight controller.
## It targets the same SharedHubResourceBar/ResourceRow structure used by
## production HubResourceBarManager, but never writes manager/save state.

signal animation_started(resource_key: String, amount: int)
signal impact(resource_key: String, amount: int)
signal animation_finished(resource_key: String, amount: int)

const RESOURCE_INDEX: Dictionary = {
	"spirit_stone": 0,
	"refinement_shard": 1,
	"celestial_jade": 2,
	"pavilion_seal": 3,
}

const RESOURCE_TEXTURES: Dictionary = {
	"spirit_stone": preload(
		"res://assets/ui/shared/resources/spirit_stone_premium.png"
	),
	"refinement_shard": preload(
		"res://assets/ui/shared/resources/refinement_shard_premium.png"
	),
	"celestial_jade": preload(
		"res://assets/ui/shared/resources/celestial_jade_premium.png"
	),
	"pavilion_seal": preload(
		"res://assets/ui/shared/resources/pavilion_seal_premium.png"
	),
}

const GOLD := Color(1.0, 0.79, 0.30, 1.0)
const JADE := Color(0.34, 0.96, 0.78, 1.0)

var overlay: Control
var resource_bar: Control
var active: bool = false
var trail_points: PackedVector2Array = PackedVector2Array()
var active_trail: Line2D = null


func setup(host_overlay: Control, target_resource_bar: Control) -> void:
	overlay = host_overlay
	resource_bar = target_resource_bar


func play_single(
	resource_key: String,
	amount: int,
	source_global_position: Vector2
) -> void:
	if active:
		return
	var target := _target_cell(resource_key)
	var value_label := _target_value_label(target)
	if target == null or value_label == null:
		push_error("RewardFlyLab: target resource cell tidak ditemukan.")
		return

	active = true
	animation_started.emit(resource_key, amount)
	_play_audio("claim")

	var start_value := int(value_label.text) if value_label.text.is_valid_int() else 0
	var end_value := start_value + amount
	var target_global := target.get_global_rect().get_center()

	var fly_icon := _create_fly_icon(resource_key, 54.0)
	fly_icon.global_position = source_global_position - fly_icon.size * 0.5
	fly_icon.scale = Vector2(0.82, 0.82)
	overlay.add_child(fly_icon)

	_begin_trail()
	var control_point := Vector2(
		lerpf(source_global_position.x, target_global.x, 0.52),
		minf(source_global_position.y, target_global.y) - 150.0
	)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		Callable(self, "_update_bezier").bind(
			fly_icon,
			source_global_position,
			control_point,
			target_global
		),
		0.0,
		1.0,
		0.62
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		fly_icon,
		"scale",
		Vector2(1.08, 1.08),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(
		Callable(self, "_on_main_impact").bind(
			resource_key,
			amount,
			target,
			value_label,
			start_value,
			end_value,
			fly_icon
		)
	)


func play_claim_all(
	resource_key: String,
	amounts: Array[int],
	source_global_positions: Array[Vector2]
) -> void:
	if active:
		return
	if amounts.is_empty() or source_global_positions.is_empty():
		return

	var target := _target_cell(resource_key)
	var value_label := _target_value_label(target)
	if target == null or value_label == null:
		push_error("RewardFlyLab: target resource cell tidak ditemukan.")
		return

	active = true
	var total := 0
	for amount: int in amounts:
		total += amount
	animation_started.emit(resource_key, total)
	_play_audio("claim")

	# Claim All should feel like "collect -> consolidate -> deliver", not
	# several icons racing at once. We therefore use a short staggered gather.
	var merge_point := Vector2(
		overlay.size.x * 0.50,
		overlay.size.y * 0.44
	)

	var core := _create_merge_core(resource_key, merge_point)
	var total_label := _create_merge_total_label(total, merge_point)

	var mini_count := mini(amounts.size(), source_global_positions.size())
	var settle_time := 0.0

	for index: int in range(mini_count):
		var mini := _create_fly_icon(resource_key, 34.0)
		mini.global_position = source_global_positions[index] - mini.size * 0.5
		mini.scale = Vector2(0.74, 0.74)
		mini.modulate = Color(1, 1, 1, 0.96)
		overlay.add_child(mini)

		var delay := float(index) * 0.075
		var travel_time := 0.24
		settle_time = maxf(settle_time, delay + travel_time)

		var spread := Vector2(
			(float(index) - float(mini_count - 1) * 0.5) * 9.0,
			float(index % 2) * 4.0
		)
		var mini_target := merge_point + spread

		var mini_tween := create_tween()
		mini_tween.tween_interval(delay)
		mini_tween.set_parallel(true)
		mini_tween.tween_property(
			mini,
			"global_position",
			mini_target - mini.size * 0.5,
			travel_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mini_tween.tween_property(
			mini,
			"scale",
			Vector2(0.36, 0.36),
			travel_time
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mini_tween.tween_property(
			mini,
			"modulate:a",
			0.18,
			travel_time
		)
		mini_tween.chain().tween_callback(mini.queue_free)

		var core_pulse := create_tween()
		core_pulse.tween_interval(delay + travel_time - 0.03)
		core_pulse.tween_property(
			core,
			"scale",
			Vector2(1.10, 1.10),
			0.07
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		core_pulse.tween_property(
			core,
			"scale",
			Vector2.ONE,
			0.07
		)

	# Keep the consolidation visible for a beat so the player understands
	# that all rewards have become one delivery.
	await get_tree().create_timer(settle_time + 0.13).timeout

	if not is_instance_valid(core):
		active = false
		return

	var merge_burst := _create_merge_burst(merge_point)
	var burst_tween := create_tween()
	burst_tween.set_parallel(true)
	burst_tween.tween_property(
		merge_burst,
		"scale",
		Vector2(1.55, 1.55),
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst_tween.tween_property(
		merge_burst,
		"modulate:a",
		0.0,
		0.16
	)
	burst_tween.chain().tween_callback(merge_burst.queue_free)

	var core_tween := create_tween()
	core_tween.set_parallel(true)
	core_tween.tween_property(
		core,
		"scale",
		Vector2(1.18, 1.18),
		0.12
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(
		total_label,
		"modulate:a",
		1.0,
		0.10
	)
	await get_tree().create_timer(0.14).timeout

	var launch_position := core.get_global_rect().get_center()
	core.queue_free()

	var label_tween := create_tween()
	label_tween.set_parallel(true)
	label_tween.tween_property(
		total_label,
		"position:y",
		total_label.position.y - 10.0,
		0.18
	)
	label_tween.tween_property(
		total_label,
		"modulate:a",
		0.0,
		0.18
	)
	label_tween.chain().tween_callback(total_label.queue_free)

	_launch_claim_all_main(
		resource_key,
		total,
		launch_position,
		target,
		value_label
	)


func _create_merge_core(
	resource_key: String,
	center_position: Vector2
) -> TextureRect:
	var core := _create_fly_icon(resource_key, 58.0)
	core.name = "ClaimAllMergeCore"
	core.global_position = center_position - core.size * 0.5
	core.scale = Vector2(0.76, 0.76)
	core.modulate = Color(1, 1, 1, 0.96)
	overlay.add_child(core)
	return core


func _create_merge_total_label(
	total: int,
	center_position: Vector2
) -> Label:
	var label := Label.new()
	label.name = "ClaimAllTotal"
	label.text = "+%d" % total
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 0.82)
	)
	label.size = Vector2(120.0, 34.0)
	label.global_position = center_position + Vector2(-60.0, 40.0)
	label.modulate.a = 0.0
	label.z_index = 21
	overlay.add_child(label)
	return label


func _create_merge_burst(center_position: Vector2) -> Panel:
	var burst := Panel.new()
	burst.name = "ClaimAllMergeBurst"
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.size = Vector2(88.0, 88.0)
	burst.global_position = center_position - burst.size * 0.5
	burst.scale = Vector2(0.72, 0.72)
	burst.z_index = 17

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.95, 0.75, 0.08)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.80, 0.32, 0.82)
	style.corner_radius_top_left = 44
	style.corner_radius_top_right = 44
	style.corner_radius_bottom_left = 44
	style.corner_radius_bottom_right = 44
	style.shadow_color = Color(0.27, 0.94, 0.75, 0.24)
	style.shadow_size = 8
	burst.add_theme_stylebox_override("panel", style)

	overlay.add_child(burst)
	return burst


func _launch_claim_all_main(
	resource_key: String,
	total: int,
	start_position: Vector2,
	target: Control,
	value_label: Label
) -> void:
	var start_value := int(value_label.text) if value_label.text.is_valid_int() else 0
	var end_value := start_value + total
	var target_global := target.get_global_rect().get_center()

	var fly_icon := _create_fly_icon(resource_key, 62.0)
	fly_icon.global_position = start_position - fly_icon.size * 0.5
	fly_icon.scale = Vector2(0.55, 0.55)
	overlay.add_child(fly_icon)

	var burst := Panel.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.size = Vector2(74.0, 74.0)
	burst.global_position = start_position - burst.size * 0.5
	var burst_style := StyleBoxFlat.new()
	burst_style.bg_color = Color(0.26, 0.94, 0.74, 0.12)
	burst_style.border_width_left = 2
	burst_style.border_width_top = 2
	burst_style.border_width_right = 2
	burst_style.border_width_bottom = 2
	burst_style.border_color = Color(1.0, 0.79, 0.30, 0.68)
	burst_style.corner_radius_top_left = 37
	burst_style.corner_radius_top_right = 37
	burst_style.corner_radius_bottom_left = 37
	burst_style.corner_radius_bottom_right = 37
	burst.add_theme_stylebox_override("panel", burst_style)
	overlay.add_child(burst)

	var burst_tween := create_tween()
	burst_tween.set_parallel(true)
	burst_tween.tween_property(burst, "scale", Vector2(1.45, 1.45), 0.18)
	burst_tween.tween_property(burst, "modulate:a", 0.0, 0.18)
	burst_tween.chain().tween_callback(burst.queue_free)

	_begin_trail()
	var control_point := Vector2(
		lerpf(start_position.x, target_global.x, 0.48),
		minf(start_position.y, target_global.y) - 178.0
	)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		Callable(self, "_update_bezier").bind(
			fly_icon,
			start_position,
			control_point,
			target_global
		),
		0.0,
		1.0,
		0.62
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		fly_icon,
		"scale",
		Vector2(1.12, 1.12),
		0.25
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(
		Callable(self, "_on_main_impact").bind(
			resource_key,
			total,
			target,
			value_label,
			start_value,
			end_value,
			fly_icon
		)
	)


func _update_bezier(
	progress: float,
	fly_icon: TextureRect,
	start: Vector2,
	control: Vector2,
	end: Vector2
) -> void:
	if not is_instance_valid(fly_icon):
		return

	var inverse := 1.0 - progress
	var center := (
		inverse * inverse * start
		+ 2.0 * inverse * progress * control
		+ progress * progress * end
	)
	fly_icon.global_position = center - fly_icon.size * 0.5

	trail_points.append(center)
	while trail_points.size() > 10:
		trail_points.remove_at(0)
	if active_trail != null:
		active_trail.points = trail_points
		active_trail.modulate.a = 0.78 - progress * 0.32


func _on_main_impact(
	resource_key: String,
	amount: int,
	target: Control,
	value_label: Label,
	start_value: int,
	end_value: int,
	fly_icon: TextureRect
) -> void:
	_end_trail()
	if is_instance_valid(fly_icon):
		fly_icon.queue_free()

	impact.emit(resource_key, amount)
	_play_audio("pickup_jade")
	_pulse_target(target)
	_count_value(value_label, start_value, end_value)

	var flash := Panel.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = Vector2(66.0, 66.0)
	var target_center := target.get_global_rect().get_center()
	flash.global_position = target_center - flash.size * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.36, 1.0, 0.81, 0.10)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.82, 0.38, 0.82)
	style.corner_radius_top_left = 33
	style.corner_radius_top_right = 33
	style.corner_radius_bottom_left = 33
	style.corner_radius_bottom_right = 33
	flash.add_theme_stylebox_override("panel", style)
	overlay.add_child(flash)

	var flash_tween := create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.55, 1.55), 0.20)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.20)
	flash_tween.chain().tween_callback(flash.queue_free)
	flash_tween.chain().tween_callback(
		Callable(self, "_finish_animation").bind(resource_key, amount)
	)


func _pulse_target(target: Control) -> void:
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(
		target,
		"scale",
		Vector2(1.12, 1.12),
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		target,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _count_value(label: Label, from_value: int, to_value: int) -> void:
	var tween := create_tween()
	tween.tween_method(
		Callable(self, "_set_value_label").bind(label),
		float(from_value),
		float(to_value),
		0.24
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_value_label(value: float, label: Label) -> void:
	if is_instance_valid(label):
		label.text = str(int(round(value)))


func _create_fly_icon(resource_key: String, size_px: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(size_px, size_px)
	icon.size = Vector2(size_px, size_px)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = RESOURCE_TEXTURES.get(resource_key) as Texture2D
	icon.pivot_offset = icon.size * 0.5
	icon.z_index = 20
	return icon


func _begin_trail() -> void:
	_end_trail()
	trail_points = PackedVector2Array()
	active_trail = Line2D.new()
	active_trail.width = 4.0
	active_trail.default_color = JADE
	active_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	active_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	active_trail.z_index = 18
	overlay.add_child(active_trail)


func _end_trail() -> void:
	trail_points = PackedVector2Array()
	if active_trail != null and is_instance_valid(active_trail):
		var trail := active_trail
		active_trail = null
		var tween := create_tween()
		tween.tween_property(trail, "modulate:a", 0.0, 0.12)
		tween.tween_callback(trail.queue_free)


func _target_cell(resource_key: String) -> Control:
	if resource_bar == null:
		return null
	var row := resource_bar.get_node_or_null("ResourceRow") as HBoxContainer
	if row == null:
		return null
	var index := int(RESOURCE_INDEX.get(resource_key, -1))
	if index < 0 or index >= row.get_child_count():
		return null
	return row.get_child(index) as Control


func _target_value_label(target: Control) -> Label:
	if target == null:
		return null
	for child: Node in target.get_children():
		if child is Label:
			return child as Label
	return null


func _play_audio(cue: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", cue)


func _finish_animation(resource_key: String, amount: int) -> void:
	active = false
	animation_finished.emit(resource_key, amount)
