extends RefCounted

const CAPACITY: int = 12
const FIRST_CLEAR_COST: int = 2
const REFILL_SECONDS: int = 15 * 60

static func view(raw: Dictionary, now: int) -> Dictionary:
	var stored_units: Variant = raw.get("units", CAPACITY)
	var stored_anchor: Variant = raw.get("anchor", now)
	var units: int = clampi(int(stored_units), 0, CAPACITY) if _numeric(stored_units) else CAPACITY
	var anchor: int = maxi(0, int(stored_anchor)) if _numeric(stored_anchor) else now
	if units < CAPACITY and now >= anchor:
		var intervals: int = floori(float(now - anchor) / REFILL_SECONDS)
		units = mini(CAPACITY, units + intervals)
		anchor += intervals * REFILL_SECONDS
	if units == CAPACITY:
		anchor = now
	return {"units": units, "anchor": anchor}

static func debit(raw: Dictionary, cost: int, now: int) -> Dictionary:
	var balance: Dictionary = view(raw, now)
	balance.units = maxi(0, int(balance.units) - cost)
	return balance

static func seconds_until(raw: Dictionary, cost: int, now: int) -> int:
	var balance: Dictionary = view(raw, now)
	var needed: int = maxi(0, cost - int(balance.units))
	return 0 if needed == 0 else maxi(0, int(balance.anchor) + needed * REFILL_SECONDS - now)

static func accepted_cost(value: Variant) -> int:
	return FIRST_CLEAR_COST if _numeric(value) and float(value) == float(FIRST_CLEAR_COST) else 0

static func _numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
