extends Node2D
const Reach=preload("res://scripts/data/weapon_reach.gd")
## One persistent courier, maximum two dragon meshes. Damage is cadence-gated,
## never driven by frame count or by the decorative trail. No ownership bypass.
const DRAGON = preload("res://assets/vfx/compass_pursuit/jade_dragon.png")
const COMPASS = preload("res://assets/ui/liveops/odyssey/compass.png")
const Ledger = preload("res://scripts/weapon/run_combat_ledger.gd")
const DRAGON_BODY_LENGTH: float=104.0
const DRAGON_NECK: float=27.0
const DRAGON_HALF_WIDTH: float=27.15
const DRAGON_HEAD_SCALE: float=.075
const HIT_SCALE: float = 0.375
const CONTACT_RADIUS: float = 34.0
const REFRESH: float = 0.15
var player_ref: WeakRef
var weapon_ref: WeakRef
var combat_level: int = 1
var age: float = 0.0
var refresh_left: float = 0.0
var mesh_left: float = 0.0
var pending: float = 0.0
var amount: float = 0.0
var resonance_used: bool = false
var heads: Array[Dictionary] = []
var echoes: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var applied_total: float = 0.0
static func living(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node2D and not value.is_queued_for_deletion() and value.is_in_group("enemy") and not bool(value.get("is_dead")) and value.has_method("take_damage")
static func in_range(player: Node2D, enemy: Node2D) -> bool:
	return Reach.contains(player,enemy)
func configure(player: Node2D, weapon: Node) -> void:
	player_ref = weakref(player)
	weapon_ref = weakref(weapon)
	z_index = 8
	add_to_group("heavenweaver_cast")
	_resize_heads(1, player.global_position)
func _resize_heads(count: int, origin: Vector2) -> void:
	while heads.size() < count:
		var mesh := MeshInstance2D.new()
		mesh.texture = DRAGON
		mesh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mesh.modulate = Color(0.68, 1.0, 1.0) if heads.size() == 1 else Color.WHITE
		add_child(mesh)
		var face := Sprite2D.new()
		var face_texture := AtlasTexture.new()
		face_texture.atlas = DRAGON
		face_texture.region = Rect2(1650, 0, 522, 724)
		face_texture.filter_clip = true
		face.texture = face_texture
		face.scale = Vector2.ONE * DRAGON_HEAD_SCALE
		face.offset = Vector2(-165, 0)
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		face.modulate = mesh.modulate
		add_child(face)
		heads.append({"point": origin + Vector2(22, -28), "angle": 0.0, "target": null, "spine": PackedVector2Array(), "mesh": mesh, "face": face, "spent": true})
	while heads.size() > count:
		var removed: Dictionary = heads.pop_back()
		removed.mesh.queue_free()
		removed.face.queue_free()
func strike_tick(damage: float, weapon_level: int) -> void:
	if not _authorized(): return
	combat_level = weapon_level
	amount = damage
	_resize_heads(2 if combat_level >= 7 else 1, player_ref.get_ref().global_position)
	# At most one outstanding strike: distance never banks missed attacks.
	pending = 0.6
	resonance_used = false
	for head: Dictionary in heads: head.spent = false
func _authorized() -> bool:
	if player_ref == null or weapon_ref == null: return false
	var player: Node = player_ref.get_ref()
	var weapon: Node = weapon_ref.get_ref()
	var client: Node = get_node_or_null("/root/OdysseyClient")
	var manager: Node = player.get_node_or_null("WeaponManager") if is_instance_valid(player) else null
	if not is_instance_valid(player) or player.is_queued_for_deletion() or not is_instance_valid(weapon) or weapon.is_queued_for_deletion() or client == null or not bool(client.get("run_authorized")): return false
	# A revoked paid selection must not keep attacking through a persistent actor.
	if manager != null and not str(manager.get("_paid_starter_id")).is_empty():
		return EquipmentManager._paid_selected_v2(EquipmentManager.SLOT_ARMAMENT, true) == str(weapon.get("armament_id"))
	return true
func _physics_process(delta: float) -> void:
	if not _authorized(): queue_free(); return
	var player: Node2D = player_ref.get_ref() as Node2D
	age += delta
	pending = maxf(0.0, pending - delta)
	refresh_left -= delta
	mesh_left -= delta
	if refresh_left <= 0.0 or heads.any(func(h: Dictionary) -> bool: return _target(h) != null and not living(_target(h))):
		_refresh_targets(player)
		refresh_left = REFRESH
	for index: int in heads.size():
		var head: Dictionary = heads[index]
		var target: Node2D = _target(head)
		var active: bool = living(target) and in_range(player, target)
		var destination: Vector2 = target.global_position + Vector2.from_angle(age * 3.0 + index * PI) * 21.0 if active else player.global_position + Vector2.from_angle(age * 1.3 + index * PI) * 40.0 + Vector2(0, -18)
		var previous: Vector2 = head.point
		var speed: float = (760.0 if combat_level >= 3 else 620.0) if active else 220.0
		head.point = previous.move_toward(destination, speed * delta)
		if previous.distance_squared_to(head.point) > 0.01:
			head.angle = lerp_angle(float(head.angle), (head.point - previous).angle(), minf(1.0, delta * 18.0))
		if active and pending > 0.0 and not bool(head.spent) and head.point.distance_to(target.global_position) <= CONTACT_RADIUS:
			head.spent = true
			var shared: bool = heads.size() == 2 and _target(heads[0]) == _target(heads[1])
			var share: float = 0.5 if shared else (0.65 if index == 1 else 1.0)
			var hit_amount: float = amount * HIT_SCALE * share
			var applied: float = _hit(player, target, hit_amount, true)
			if applied > 0.0 and combat_level >= 5:
				if echoes.size() < 2: echoes.append({"target": weakref(target), "left": 0.12, "amount": hit_amount * 0.25})
		if mesh_left <= 0.0: _update_dragon(head, 1.0 / 30.0 if SettingsManager.reduced_effects else 1.0 / 60.0, index)
	if mesh_left <= 0.0: mesh_left = 1.0 / 30.0 if SettingsManager.reduced_effects else 1.0 / 60.0
	for i: int in range(echoes.size() - 1, -1, -1):
		var echo: Dictionary = echoes[i]
		echo.left -= delta
		if float(echo.left) > 0.0: continue
		var target: Node2D = echo.target.get_ref() as Node2D
		if living(target) and in_range(player, target): _hit(player, target, float(echo.amount), false)
		echoes.remove_at(i)
	for i: int in range(impacts.size() - 1, -1, -1):
		impacts[i].left -= delta
		if float(impacts[i].left) <= 0.0: impacts.remove_at(i)
	queue_redraw()
func _target(head: Dictionary) -> Node2D:
	return head.target.get_ref() as Node2D if head.target != null else null
func _refresh_targets(player: Node2D) -> void:
	# One shared O(n) selection pass; two nearest threats, no per-frame sort.
	var nearest: Node2D
	var second: Node2D
	var distance: float = INF
	var next_distance: float = INF
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if not living(enemy) or not in_range(player, enemy): continue
		var candidate: float = player.global_position.distance_squared_to(enemy.global_position)
		if candidate < distance:
			second = nearest; next_distance = distance; nearest = enemy; distance = candidate
		elif candidate < next_distance:
			second = enemy; next_distance = candidate
	for index: int in heads.size():
		var head: Dictionary = heads[index]
		var desired: Node2D = nearest if index == 0 or second == null else second
		var current: Node2D = _target(head)
		if index == 0 and living(current) and in_range(player, current) and living(desired):
			# Switch only for a threat at least25% closer; avoid target flicker.
			if distance >= player.global_position.distance_squared_to(current.global_position) * 0.5625: desired = current
		if index == 1 and heads.size() == 2 and desired == _target(heads[0]) and second != null:
			desired = nearest if nearest != desired else second
		head.target = weakref(desired) if living(desired) else null
func _hit(player: Node2D, enemy: Node2D, damage: float, can_resonate: bool) -> float:
	var stats: Node = player.get_node_or_null("PlayerStats")
	if stats == null or not living(enemy): return 0.0
	var result: Dictionary = stats.call("calculate_damage_result", damage)
	CombatFeedback.mark_next_hit_critical(enemy, bool(result.is_critical))
	var applied: float = Ledger.apply_hit(enemy, float(result.damage), "heavenweaver_compass")
	applied_total += applied
	if applied > 0.0:
		if impacts.size() >= 8: impacts.pop_front()
		impacts.append({"point": enemy.global_position, "left": 0.26, "echo": not can_resonate})
	if applied > 0.0 and can_resonate and not resonance_used and bool(result.is_critical) and bool(stats.call("has_sword_dao_resonance")) and living(enemy):
		resonance_used = true
		var bonus: Dictionary = stats.call("calculate_damage_result", damage * 0.4)
		CombatFeedback.mark_next_hit_critical(enemy, bool(bonus.is_critical))
		applied_total += Ledger.apply_hit(enemy, float(bonus.damage), "heavenweaver_compass")
	return applied
func _update_dragon(head: Dictionary, _delta: float, index: int) -> void:
	# Twelve textured joints form one unbroken painted body, without atlas seams.
	var spine := PackedVector2Array()
	var joints: int = 8 if SettingsManager.reduced_effects else 12
	var angle: float = float(head.get("visual_angle", head.angle))
	angle += clampf(angle_difference(angle, float(head.angle)), -6.0 * _delta, 6.0 * _delta)
	head.visual_angle = angle
	var at: Vector2 = head.point - Vector2.from_angle(angle) * DRAGON_NECK
	spine.append(at)
	var previous: PackedVector2Array = head.spine
	var spacing: float = DRAGON_BODY_LENGTH / (joints - 1)
	var segment_angle: float = angle
	var attacking: bool=living(_target(head))
	for j: int in range(1, joints):
		# Follow the preceding joint's trail rather than rebuilding the whole
		# body from the newest heading. Bounded bends prevent folded UV strips.
		var desired: float = segment_angle
		if previous.size() == joints:
			desired = (at - previous[j]).angle()
		var bend: float = clampf(angle_difference(segment_angle, desired), -.26, .26)
		var breath: float=sin(age*(6.8 if attacking else 3.8)-j*.72+index)*(.080 if attacking else .04)*float(j)/joints
		segment_angle += bend * (1.0 - exp(-14.0 * _delta)) + breath
		at -= Vector2.from_angle(segment_angle) * spacing
		spine.append(at)
	head.face.global_position = head.point
	head.face.rotation = angle
	head.spine = spine
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for j: int in joints:
		var tangent: Vector2 = (spine[maxi(0, j - 1)] - spine[mini(joints - 1, j + 1)]).normalized()
		var normal: Vector2 = tangent.orthogonal()
		for side: int in 2:
			vertices.append(to_local(spine[j] + normal * (float(side) * 2.0 - 1.0) * DRAGON_HALF_WIDTH))
			uvs.append(Vector2(0.78 * (1.0 - float(j) / (joints - 1)), float(side)))
		if j > 0:
			var k: int = j * 2
			indices.append_array(PackedInt32Array([k - 2, k - 1, k, k - 1, k + 1, k]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	head.mesh.mesh = mesh
func _draw() -> void:
	for head: Dictionary in heads:
		var target: Node2D = _target(head)
		if living(target):
			var at: Vector2 = to_local(target.global_position)
			draw_texture_rect(COMPASS, Rect2(at - Vector2.ONE * 12, Vector2.ONE * 24), false, Color(1, 1, 1, 0.52))
	for hit: Dictionary in impacts:
		var t: float = 1.0 - float(hit.left) / 0.26
		var at: Vector2 = to_local(hit.point)
		var color := Color(0.65, 1, 0.82, (1.0 - t) * 0.8)
		for petal: int in (3 if SettingsManager.reduced_effects else 6):
			var direction: Vector2 = Vector2.from_angle(petal * TAU / 6.0 + age)
			var center: Vector2 = at + direction * (8.0 + 19.0 * t)
			var shape: PackedVector2Array = [center - direction * 5, center + direction.orthogonal() * 2.8, center + direction * 5, center - direction.orthogonal() * 2.8]
			draw_colored_polygon(shape, color)
