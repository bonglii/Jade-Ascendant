extends RefCounted
## Display only. Never invent a reward or borrow a different week's grant.
const CAPS := {"celestial_jade":40,"pavilion_seal":1,"spirit_stone":600}
static func for_week(snapshot: Dictionary, week_id: String = "") -> Dictionary:
	for key: String in ["week", "previous"]:
		var week: Variant = snapshot.get(key)
		if not week is Dictionary or (not week_id.is_empty() and str(week.get("id", "")) != week_id):
			continue
		var reward: Variant = week.get("reward")
		if not reward is Dictionary: return {}
		var result: Dictionary = {}
		for currency: String in CAPS:
			var amount: Variant = reward.get(currency)
			if not (amount is int or amount is float) or not is_finite(float(amount)) or amount != floorf(float(amount)) or amount < 0 or amount > CAPS[currency]: return {}
			result[currency] = int(amount)
		return result
	return {}
