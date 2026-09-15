extends RefCounted

## Journey Visual Catalog
## Presentation-only metadata for Chapter/Realm UI.
## This file must not own progression, unlock, reward, or save state.

const DEFAULT_PROFILE := {
	"eyebrow": "CELESTIAL JOURNEY",
	"realm_epithet": "CULTIVATION REALM",
	"realm_hint": "A realm on the path toward ascension.",
	"trial_label": "CULTIVATION TRIAL",
	"realm_motif": "generic",
	"realm_mark": "ASCEND",
	"accent": Color(0.353, 0.784, 0.843, 1.0),
	"accent_soft": Color(0.204, 0.608, 0.494, 1.0),
	"gold": Color(0.941, 0.8, 0.439, 1.0),
	"sky_top": Color(0.006, 0.027, 0.047, 1.0),
	"sky_bottom": Color(0.016, 0.086, 0.094, 1.0),
	"mountain_far": Color(0.031, 0.122, 0.129, 0.82),
	"mountain_near": Color(0.012, 0.071, 0.075, 0.96),
	"mist": Color(0.286, 0.776, 0.82, 0.10),
	"moon": Color(0.941, 0.91, 0.827, 0.08)
}

const CHAPTER_PROFILES := {
	1: {
		"eyebrow": "CELESTIAL JOURNEY",
		"realm_epithet": "VALLEY OF AWAKENING",
		"realm_hint": "Verdant mountains gather living qi beneath ancient jade skies.",
		"trial_label": "VERDANT QI TRIAL",
		"realm_motif": "verdant",
		"realm_mark": "JADE VALLEY",
		"accent": Color(0.298, 0.82, 0.647, 1.0),
		"accent_soft": Color(0.184, 0.62, 0.471, 1.0),
		"gold": Color(0.957, 0.78, 0.357, 1.0),
		"sky_top": Color(0.004, 0.024, 0.043, 1.0),
		"sky_bottom": Color(0.012, 0.094, 0.09, 1.0),
		"mountain_far": Color(0.035, 0.169, 0.141, 0.78),
		"mountain_near": Color(0.012, 0.078, 0.067, 0.97),
		"mist": Color(0.282, 0.878, 0.675, 0.11),
		"moon": Color(0.886, 0.965, 0.827, 0.085)
	},
	2: {
		"eyebrow": "CELESTIAL JOURNEY",
		"realm_epithet": "CRIMSON MOON SECT",
		"realm_hint": "Moonlit ravines hide veiled blades, cinnabar rites, and scarlet seals.",
		"trial_label": "CRIMSON MOON TRIAL",
		"realm_motif": "crimson",
		"realm_mark": "BLOOD MOON",
		"accent": Color(0.88, 0.30, 0.38, 1.0),
		"accent_soft": Color(0.58, 0.16, 0.25, 1.0),
		"gold": Color(0.94, 0.67, 0.31, 1.0),
		"sky_top": Color(0.035, 0.010, 0.032, 1.0),
		"sky_bottom": Color(0.105, 0.020, 0.050, 1.0),
		"mountain_far": Color(0.19, 0.045, 0.075, 0.82),
		"mountain_near": Color(0.075, 0.018, 0.035, 0.97),
		"mist": Color(0.82, 0.20, 0.32, 0.10),
		"moon": Color(0.96, 0.67, 0.61, 0.13)
	},
	3: {
		"eyebrow": "CELESTIAL JOURNEY",
		"realm_epithet": "NINE HEAVENS STAR PALACE",
		"realm_hint": "Cloud seas and ancient star arrays guard the road toward true ascension.",
		"trial_label": "NINE HEAVENS TRIAL",
		"realm_motif": "nine_heavens",
		"realm_mark": "STAR PALACE",
		"accent": Color(0.68, 0.82, 0.98, 1.0),
		"accent_soft": Color(0.42, 0.49, 0.78, 1.0),
		"gold": Color(0.98, 0.84, 0.49, 1.0),
		"sky_top": Color(0.010, 0.018, 0.065, 1.0),
		"sky_bottom": Color(0.040, 0.075, 0.145, 1.0),
		"mountain_far": Color(0.13, 0.19, 0.32, 0.76),
		"mountain_near": Color(0.045, 0.080, 0.16, 0.95),
		"mist": Color(0.68, 0.82, 1.0, 0.11),
		"moon": Color(0.98, 0.94, 0.78, 0.11)
	}
}

static func get_chapter_profile(chapter_id: int) -> Dictionary:
	var profile: Dictionary = DEFAULT_PROFILE.duplicate(true)
	if CHAPTER_PROFILES.has(chapter_id):
		var chapter_profile: Dictionary = CHAPTER_PROFILES[chapter_id]
		for key in chapter_profile.keys():
			profile[key] = chapter_profile[key]
	return profile
