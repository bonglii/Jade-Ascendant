extends RefCounted
## Optional cosmetic objective. No economy or main-save authority.
const BADGE := "keeper_of_the_oath"
const WINDOW := 22.0
const CHARGE := 8.0
const RADIUS := 64.0
var phase: String = "off"
var remaining: float = WINDOW
var charge: float = 0.0
var location := Vector2.ZERO

func begin(enabled: bool) -> void:
	phase = "waiting" if enabled else "off"
	remaining = WINDOW
	charge = 0.0
	location = Vector2.ZERO

func offer(point: Vector2, wave: int, available: float) -> bool:
	if phase != "waiting" or wave != 5 or available < WINDOW or not point.is_finite():
		return false
	location = point
	phase = "charging"
	return true

func advance(delta: float, inside: bool, wave: int) -> void:
	if phase == "waiting" and wave > 5:
		phase = "omitted"
	if phase != "charging" or not is_finite(delta) or delta <= 0.0:
		return
	if wave >= 7:
		phase = "failed"
		return
	var used := minf(delta, remaining)
	if inside:
		charge = minf(CHARGE, charge + used)
	remaining = maxf(0.0, remaining - used)
	if charge >= CHARGE:
		phase = "pending"
	elif remaining <= 0.0:
		phase = "failed"

func snapshot() -> Dictionary:
	return {"version":1, "phase":phase, "remaining":remaining, "charge":charge, "x":location.x, "y":location.y}

func restore(raw: Variant) -> void:
	begin(false)
	if not raw is Dictionary or raw.get("version") != 1 or raw.get("phase") not in ["off","waiting","charging","pending","failed","omitted"]:
		return
	for key: String in ["remaining","charge","x","y"]:
		if not (raw.get(key) is int or raw.get(key) is float) or not is_finite(float(raw[key])):
			return
	if raw.remaining < 0 or raw.remaining > WINDOW or raw.charge < 0 or raw.charge > CHARGE or absf(raw.x)>100000 or absf(raw.y)>100000:
		return
	if raw.phase == "pending" and raw.charge != CHARGE:
		return
	if raw.phase == "charging" and (raw.remaining <= 0 or raw.charge >= CHARGE):
		return
	phase = raw.phase
	remaining = float(raw.remaining)
	charge = float(raw.charge)
	location = Vector2(raw.x, raw.y)
