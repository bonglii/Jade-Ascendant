extends Node

## Pause-aware, strongest-only movement modifier. Never changes authored speed,
## AI state, attack timing, collision or boss telegraphs.
var remaining: float = 0.0
var multiplier: float = 1.0
var sources: Dictionary = {}

static func apply(target: Node, duration: float = 0.72, normal_factor: float = .60, boss_factor: float = .88) -> void:
	var status: Node = target.get_node_or_null("JadeBindingSlow")
	if status == null:
		status = load("res://scripts/weapon/jade_binding_slow.gd").new()
		status.name = "JadeBindingSlow"
		target.add_child(status)
	status.set_physics_process(true)
	var factor: float=boss_factor if target.is_in_group("boss") else normal_factor
	if status.remaining<=0.0:status.sources.clear()
	status.sources[factor]=maxf(float(status.sources.get(factor,0)),duration)
	status._refresh_sources()

static func movement_factor(target: Node) -> float:
	var status: Node = target.get_node_or_null("JadeBindingSlow")
	if status == null or status.remaining <= 0.0:
		return 1.0
	return status.multiplier

func _refresh_sources() -> void:
	remaining=0.0;multiplier=1.0
	for factor: float in sources:
		remaining=maxf(remaining,float(sources[factor]))
		multiplier=minf(multiplier,factor)

func _physics_process(delta: float) -> void:
	if remaining<=0.0:sources.clear()
	for factor: float in sources.keys():
		sources[factor]=maxf(float(sources[factor])-delta,0.0)
		if sources[factor]<=0.0:sources.erase(factor)
	_refresh_sources()
	if remaining<=0.0:set_physics_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		set_physics_process(true)
