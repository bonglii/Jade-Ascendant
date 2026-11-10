extends RefCounted

# Active seconds before the Wave 10 boss, excluding paused choices.
const BOSS_ENTRY: Dictionary = {
	1: [165.0, 220.0, 235.0, 248.0, 315.0, 325.0],
	2: [225.0, 234.0, 246.0, 258.0, 320.0],
	3: [235.0, 245.0, 255.0, 267.0, 329.0],
	4: [241.0, 251.0, 261.0, 274.0, 340.0],
	5: [249.0, 258.0, 269.0, 281.0, 350.0],
}

static func durations(realm: int, stage: int) -> PackedFloat32Array:
	var targets: Array = BOSS_ENTRY.get(realm, [])
	if stage < 1 or stage > targets.size():
		return PackedFloat32Array()
	var opening := PackedFloat32Array([18.0, 20.0]) if realm != 1 or stage != 1 else PackedFloat32Array([16.0, 18.0])
	# Spend most of the extra time on an established build and the last elite.
	var weights: Array[float] = [0.108, 0.126, 0.133, 0.142, 0.144, 0.183, 0.164]
	var result := opening.duplicate()
	var remaining: float = float(targets[stage - 1]) - opening[0] - opening[1]
	for weight: float in weights:
		result.append(remaining * weight)
	return result

static func total(schedule: PackedFloat32Array) -> float:
	var seconds: float = 0.0
	for duration: float in schedule:
		seconds += duration
	return seconds
