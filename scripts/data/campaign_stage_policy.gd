extends RefCounted

## Published campaign membership. Legacy stages remain in Journey's save catalog
## and can still be restored, but never make new-player goals unreachable.
const LEGACY_ONLY: Dictionary = {1: [6]}

static func active_ids(chapter_id: int, canonical_ids: Array) -> Array:
	var result: Array = []
	var legacy: Array = LEGACY_ONLY.get(chapter_id, [])
	for value: Variant in canonical_ids:
		var stage_id: int = int(value)
		if stage_id not in legacy and stage_id not in result:
			result.append(stage_id)
	return result
