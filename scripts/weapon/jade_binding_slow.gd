extends Node

## Pause-aware, strongest-only movement modifier. Never changes authored speed,
## AI state, attack timing, collision or boss telegraphs.
var remaining: float = 0.0
var multiplier: float = 1.0

static func apply(target: Node, duration: float = 0.72) -> void:
	var status: Node = target.get_node_or_null("JadeBindingSlow")
	if status == null:
		status = load("res://scripts/weapon/jade_binding_slow.gd").new()
		status.name = "JadeBindingSlow"
		target.add_child(status)
	status.set_physics_process(true)
	status.remaining = maxf(status.remaining, duration)
	status.multiplier = 0.88 if target.is_in_group("boss") else 0.60

static func movement_factor(target: Node) -> float:
	var status: Node = target.get_node_or_null("JadeBindingSlow")
	if status == null or status.remaining <= 0.0:
		return 1.0
	return status.multiplier

func _physics_process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	# Reuse one tiny component per affected actor; no deferred-delete race when
	# the next cast lands in the same frame that the previous modifier expires.
	if remaining <= 0.0:
		set_physics_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		set_physics_process(true)
