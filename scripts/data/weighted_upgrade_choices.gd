extends RefCounted
## Weighted draws without replacement. Existing gameplay owns eligibility.

static func pick(candidates: Array[String], weights: Dictionary, count: int, rng: RandomNumberGenerator) -> Array[String]:
	var remaining: Array[String] = []
	for id: String in candidates:
		if not id.is_empty() and id not in remaining:
			remaining.append(id)
	var chosen: Array[String] = []
	for draw: int in range(mini(maxi(count, 0), remaining.size())):
		var total: float = 0.0
		var values: Array[float] = []
		for id: String in remaining:
			var value: float = float(weights.get(id, 1.0))
			if not is_finite(value) or value <= 0.0:
				value = 1.0
			values.append(value)
			total += value
		var roll: float = rng.randf() * total
		var selected_index: int = remaining.size() - 1
		for i: int in range(remaining.size()):
			roll -= values[i]
			if roll < 0.0:
				selected_index = i
				break
		chosen.append(remaining[selected_index])
		remaining.remove_at(selected_index)
	return chosen
