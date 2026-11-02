extends RefCounted
## Choose only the session's week. Never borrow a newer week's pattern configuration.
const THEMES := ["jade_wind","scarlet_rite","starfall","froststep","sunforge"]
static func version(config: Variant) -> int:
	if not config is Dictionary:return 0
	var raw: Variant=config.get("ruleset_version",1)
	if not (raw is int or raw is float) or not is_finite(float(raw)) or raw != floorf(float(raw)) or raw < 1 or raw > 2:return 0
	return int(raw)
static func session_config(session: Dictionary, snapshot: Dictionary) -> Dictionary:
	var raw: Variant=session.get("week_config")
	if not raw is Dictionary:
		for key: String in ["week","previous"]:
			var candidate: Variant=snapshot.get(key)
			if candidate is Dictionary and candidate.get("id")==session.get("week"):raw=candidate;break
	if not raw is Dictionary or raw.get("id")!=session.get("week") or version(raw)==0 or raw.get("theme") not in THEMES or not valid_stage(raw.get("stage")):return {}
	return raw.duplicate(true)

static func valid_stage(raw: Variant) -> bool:
	return (raw is int or raw is float) and is_finite(float(raw)) and raw==floorf(float(raw)) and raw>=1 and raw<=5
