extends RefCounted
## Optional local checkpoint state. No rewards, paid entitlement or kill emission.

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func clean(value: Variant, schedule: Dictionary, wave: int, final_wave: int) -> Dictionary:
	if not value is Dictionary or value.get("version") != 1:
		return {}
	if not number(value.get("spawn_timer"), 0.0, 60.0) or not number(value.get("kills"), 0.0, 1000000000.0):
		return {}
	if float(value.kills) != floorf(float(value.kills)) or not value.get("spawned") is Array or value.spawned.size() > 16:
		return {}
	var spawned: Array[int] = []
	for raw: Variant in value.spawned:
		if not number(raw, 1.0, float(final_wave - 1)) or float(raw) != floorf(float(raw)):
			return {}
		var slot: int = int(raw)
		if slot > wave or not schedule.has(slot) or slot in spawned:
			return {}
		spawned.append(slot)
	var active: Variant = value.get("active", {})
	if not active is Dictionary:
		return {}
	if not active.is_empty():
		if wave >= final_wave or not number(active.get("wave"), 1.0, float(final_wave - 1)):
			return {}
		var slot: int = int(active.wave)
		if not number(active.get("type"), 1.0, 2.0) or float(active.type) != floorf(float(active.type)):
			return {}
		if float(active.wave) != float(slot) or slot not in spawned or int(active.type) != int(schedule.get(slot, 0)):
			return {}
		if not number(active.get("health_ratio"), 0.000001, 1.0) or not number(active.get("x"), -20000.0, 20000.0) or not number(active.get("y"), -20000.0, 20000.0):
			return {}
		active = {"wave": slot, "type": int(active.type), "health_ratio": float(active.health_ratio), "x": float(active.x), "y": float(active.y)}
	return {"version": 1, "spawn_timer": float(value.spawn_timer), "kills": int(value.kills), "spawned": spawned, "active": active.duplicate(true)}
