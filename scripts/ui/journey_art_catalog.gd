extends RefCounted

## Journey Art Catalog
## Presentation-only asset metadata for Realm/Stage selection.
## Progression, unlock, reward, save state, and gameplay identity remain manager-owned.

const REALM_VISTAS: Dictionary = {
	1: "res://assets/ui/journey/realm_vistas/realm_01.png",
	2: "res://assets/ui/journey/realm_vistas/realm_02.png",
	3: "res://assets/ui/journey/realm_vistas/realm_03.png",
}

const STAGE_ART: Dictionary = {
	1: {
		1: "res://assets/ui/journey/stage_art/stage_1_1.png",
		2: "res://assets/ui/journey/stage_art/stage_1_2.png",
		3: "res://assets/ui/journey/stage_art/stage_1_3.png",
		4: "res://assets/ui/journey/stage_art/stage_1_4.png",
		5: "res://assets/ui/journey/stage_art/stage_1_5.png",
	},
	2: {
		1: "res://assets/ui/journey/stage_art/stage_2_1.png",
		2: "res://assets/ui/journey/stage_art/stage_2_2.png",
		3: "res://assets/ui/journey/stage_art/stage_2_3.png",
		4: "res://assets/ui/journey/stage_art/stage_2_4.png",
		5: "res://assets/ui/journey/stage_art/stage_2_5.png",
	},
	3: {
		1: "res://assets/ui/journey/stage_art/stage_3_1.png",
		2: "res://assets/ui/journey/stage_art/stage_3_2.png",
		3: "res://assets/ui/journey/stage_art/stage_3_3.png",
		4: "res://assets/ui/journey/stage_art/stage_3_4.png",
		5: "res://assets/ui/journey/stage_art/stage_3_5.png",
	},
}

const NODE_SEALS: Dictionary = {
	1: {
		"CLEARED": "res://assets/ui/journey/nodes/chapter_1/stage_seal_cleared.png",
		"CURRENT": "res://assets/ui/journey/nodes/chapter_1/stage_seal_current.png",
		"LOCKED": "res://assets/ui/journey/nodes/chapter_1/stage_seal_locked.png",
		"BOSS": "res://assets/ui/journey/nodes/chapter_1/stage_seal_boss.png",
	},
	2: {
		"CLEARED": "res://assets/ui/journey/nodes/chapter_2/stage_seal_cleared.png",
		"CURRENT": "res://assets/ui/journey/nodes/chapter_2/stage_seal_current.png",
		"LOCKED": "res://assets/ui/journey/nodes/chapter_2/stage_seal_locked.png",
		"BOSS": "res://assets/ui/journey/nodes/chapter_2/stage_seal_boss.png",
	},
	3: {
		"CLEARED": "res://assets/ui/journey/nodes/chapter_3/stage_seal_cleared.png",
		"CURRENT": "res://assets/ui/journey/nodes/chapter_3/stage_seal_current.png",
		"LOCKED": "res://assets/ui/journey/nodes/chapter_3/stage_seal_locked.png",
		"BOSS": "res://assets/ui/journey/nodes/chapter_3/stage_seal_boss.png",
	},
}

## Temporary compatibility boundary while the historical Stage 1-6 save identity
## is retired. Production presentation is locked to five trials per Realm.
## Remove this override only after the legacy save migration/cleanup pass lands.
const PRESENTATION_STAGE_IDS: Dictionary = {
	1: [1, 2, 3, 4, 5],
}

const STAGE_PRESENTATION_OVERRIDES: Dictionary = {
	1: {
		5: {
			"display_name": "Heart of Verdant Heaven",
			"description": "Beyond the Celestial Gate, the valley's heart opens into an ascension crucible.",
			"encounter_hint": "Ascendant disciples • Twin seals • Ascended Sovereign",
			"is_chapter_boss": true,
		},
	},
}


static func get_realm_vista_path(chapter_id: int) -> String:
	return str(REALM_VISTAS.get(chapter_id, ""))


static func get_stage_art_path(chapter_id: int, stage_id: int) -> String:
	var chapter_art: Dictionary = STAGE_ART.get(chapter_id, {})
	return str(chapter_art.get(stage_id, ""))


static func get_node_seal_path(chapter_id: int, state: String) -> String:
	var chapter_seals: Dictionary = NODE_SEALS.get(chapter_id, {})
	if chapter_seals.is_empty():
		chapter_seals = NODE_SEALS.get(1, {})
	return str(chapter_seals.get(state, chapter_seals.get("LOCKED", "")))


static func get_presentation_stage_ids(chapter_id: int, canonical_ids: Array) -> Array:
	if not PRESENTATION_STAGE_IDS.has(chapter_id):
		return canonical_ids.duplicate()
	var allowed: Array = PRESENTATION_STAGE_IDS.get(chapter_id, [])
	var result: Array = []
	for raw_stage_id: Variant in canonical_ids:
		var stage_id: int = int(raw_stage_id)
		if stage_id in allowed:
			result.append(stage_id)
	return result


static func apply_stage_presentation(
	chapter_id: int,
	stage_id: int,
	canonical_data: Dictionary
) -> Dictionary:
	var result: Dictionary = canonical_data.duplicate(true)
	var chapter_overrides: Dictionary = STAGE_PRESENTATION_OVERRIDES.get(chapter_id, {})
	var overrides: Dictionary = chapter_overrides.get(stage_id, {})
	for raw_key: Variant in overrides.keys():
		result[raw_key] = overrides[raw_key]
	return result
