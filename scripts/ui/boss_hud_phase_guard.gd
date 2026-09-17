extends Node

## Keeps the boss encounter name as a one-time arrival presentation.
## The production HUD previously replayed the same name banner when the boss
## entered Phase 2. This bridge preserves the persistent phase indicator while
## preventing the arrival banner / boss-name pulse from replaying mid-fight.

var _guarded_boss_instance_id: int = 0

func _ready() -> void:
	var enemy_spawner: Node = get_parent()
	if enemy_spawner == null:
		return
	if not enemy_spawner.has_signal("boss_spawned_signal"):
		return
	var spawn_callable := Callable(self, "_on_boss_spawned")
	if not enemy_spawner.is_connected("boss_spawned_signal", spawn_callable):
		enemy_spawner.connect("boss_spawned_signal", spawn_callable)

func _on_boss_spawned(boss: Node) -> void:
	# HUD receives the same spawn signal and installs its normal boss bindings.
	# Defer our phase-route swap until that signal dispatch has fully completed.
	call_deferred("_install_phase_route", boss)

func _install_phase_route(boss: Node) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	if not boss.has_signal("phase_changed"):
		return

	var boss_instance_id: int = boss.get_instance_id()
	if _guarded_boss_instance_id == boss_instance_id:
		return

	var level_root: Node = get_parent().get_parent()
	if level_root == null:
		return
	var hud: Node = level_root.get_node_or_null("HUD")
	if hud == null:
		return

	var original_hud_callable := Callable(hud, "_on_boss_phase_changed")
	if boss.is_connected("phase_changed", original_hud_callable):
		boss.disconnect("phase_changed", original_hud_callable)

	var guarded_callable := Callable(
		self,
		"_on_guarded_boss_phase_changed"
	).bind(hud)
	if not boss.is_connected("phase_changed", guarded_callable):
		boss.connect("phase_changed", guarded_callable)

	_guarded_boss_instance_id = boss_instance_id
	DebugLogger.system(
		"HUD: Boss phase presentation guard active (name banner arrival-only)."
	)

func _on_guarded_boss_phase_changed(
	current_phase: int,
	hud: Node
) -> void:
	if hud == null or not is_instance_valid(hud):
		return

	# Keep the existing compact boss HUD current and retain the phase pulse.
	# Deliberately do not replay _show_encounter_banner() or pulse BossNameLabel.
	if hud.has_method("_set_boss_phase"):
		hud.call("_set_boss_phase", current_phase)

	var phase_label: Variant = hud.get("boss_phase_label")
	if phase_label is Control and hud.has_method("_pulse_control"):
		hud.call(
			"_pulse_control",
			phase_label,
			Color(0.98, 0.79, 0.30, 1.0),
			1.18
		)

	DebugLogger.system(str("HUD: Boss Phase -> ", current_phase))
