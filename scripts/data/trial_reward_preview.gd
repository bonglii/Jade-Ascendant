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

static func for_hub(snapshot: Dictionary) -> Dictionary:
	var previous: Variant=snapshot.get("previous")
	var progress: Variant=snapshot.get("previous_progress",[])
	if previous is Dictionary and progress is Array:
		for row: Variant in progress:
			if row is Dictionary and int(row.get("clears",0))>0 and int(row.get("claimed",0))==0:
				return for_week(snapshot,str(previous.id)) if previous.get("id") is String and not str(previous.id).is_empty() else {}
	return for_week(snapshot)
