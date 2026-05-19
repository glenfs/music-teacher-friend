extends RefCounted
class_name ExerciseLibrary

# Central registry of all generatable exercises with metadata for skill-focused
# selection, difficulty filtering, and (later) curriculum building.
#
# Each entry maps an exercise type string (the same string passed to
# TechnicalExerciseGenerator.generate(...)) to a Dictionary describing it.
#
# Schema:
#   {
#     "id": String,                 # exercise type — e.g., "hanon_1", "scale_thirds"
#     "name": String,               # display label for dropdown
#     "category": String,           # "scale" | "arpeggio" | "drill" | "hanon" | "czerny"
#     "skill_tags": Array[String],  # standardized skill names (see SKILLS below)
#     "min_level": int,             # earliest level appropriate (1-10)
#     "max_level": int,             # latest level (10 = always relevant)
#     "two_hand_friendly": bool,    # rendering looks right in Grand staff mode
#   }

# Standardized skill vocabulary. Used for both tagging exercises and the user
# focus selector. Keep this small — too many tags fragment the catalog.
const SKILLS := {
	"all":              "All exercises",
	"finger_strength":  "Finger Strength (esp. 4-5)",
	"velocity":         "Velocity / Speed",
	"evenness":         "Evenness of Touch",
	"independence":     "Finger Independence",
	"hand_independence":"Hand Independence",
	"thumb":            "Thumb / Crossings",
	"stretching":       "Hand Stretching",
	"chord_voicing":    "Chord Voicings & Intervals",
	"reading":          "Sight-Reading Patterns",
}


const ENTRIES := {
	# --- Foundational ---
	"scale": {
		"id": "scale",
		"name": "Scale",
		"category": "scale",
		"skill_tags": ["evenness", "thumb", "reading"],
		"min_level": 1, "max_level": 10,
		"two_hand_friendly": true,
	},
	"arpeggio": {
		"id": "arpeggio",
		"name": "Arpeggio",
		"category": "arpeggio",
		"skill_tags": ["chord_voicing", "stretching", "thumb"],
		"min_level": 2, "max_level": 10,
		"two_hand_friendly": true,
	},
	"five_finger": {
		"id": "five_finger",
		"name": "5-Finger Drill",
		"category": "drill",
		"skill_tags": ["finger_strength", "evenness", "independence"],
		"min_level": 1, "max_level": 4,
		"two_hand_friendly": true,
	},
	# --- Hanon (Book 1, Nos. 1-5) ---
	"hanon_1": {
		"id": "hanon_1",
		"name": "Hanon No. 1 — Independence",
		"category": "hanon",
		"skill_tags": ["independence", "evenness", "finger_strength"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_2": {
		"id": "hanon_2",
		"name": "Hanon No. 2 — Alternating",
		"category": "hanon",
		"skill_tags": ["independence", "evenness"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_3": {
		"id": "hanon_3",
		"name": "Hanon No. 3 — Thumb-Pinky",
		"category": "hanon",
		"skill_tags": ["independence", "stretching", "thumb"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_4": {
		"id": "hanon_4",
		"name": "Hanon No. 4 — Broken 3rds",
		"category": "hanon",
		"skill_tags": ["independence", "chord_voicing"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_5": {
		"id": "hanon_5",
		"name": "Hanon No. 5 — Wide Intervals",
		"category": "hanon",
		"skill_tags": ["independence", "thumb", "stretching"],
		"min_level": 6, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_6": {
		"id": "hanon_6",
		"name": "Hanon No. 6 — Wrist Agility",
		"category": "hanon",
		"skill_tags": ["independence", "evenness"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_7": {
		"id": "hanon_7",
		"name": "Hanon No. 7 — Triplet Groups",
		"category": "hanon",
		"skill_tags": ["independence", "evenness"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_8": {
		"id": "hanon_8",
		"name": "Hanon No. 8 — Outer Fingers",
		"category": "hanon",
		"skill_tags": ["independence", "finger_strength"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_9": {
		"id": "hanon_9",
		"name": "Hanon No. 9 — Three-and-Five",
		"category": "hanon",
		"skill_tags": ["independence", "thumb"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_10": {
		"id": "hanon_10",
		"name": "Hanon No. 10 — Reverse Stepwise",
		"category": "hanon",
		"skill_tags": ["independence", "thumb"],
		"min_level": 6, "max_level": 10,
		"two_hand_friendly": true,
	},
	"hanon_11": {"id": "hanon_11", "name": "Hanon No. 11 — Full 5-Finger", "category": "hanon", "skill_tags": ["independence", "evenness"], "min_level": 5, "max_level": 10, "two_hand_friendly": true},
	"hanon_12": {"id": "hanon_12", "name": "Hanon No. 12 — 4th-Finger Focus", "category": "hanon", "skill_tags": ["independence", "finger_strength"], "min_level": 5, "max_level": 10, "two_hand_friendly": true},
	"hanon_13": {"id": "hanon_13", "name": "Hanon No. 13 — Cross Pattern", "category": "hanon", "skill_tags": ["independence", "evenness"], "min_level": 6, "max_level": 10, "two_hand_friendly": true},
	"hanon_14": {"id": "hanon_14", "name": "Hanon No. 14 — Mid-Finger Drill", "category": "hanon", "skill_tags": ["independence"], "min_level": 5, "max_level": 10, "two_hand_friendly": true},
	"hanon_15": {"id": "hanon_15", "name": "Hanon No. 15 — Leaping Figures", "category": "hanon", "skill_tags": ["independence", "stretching"], "min_level": 6, "max_level": 10, "two_hand_friendly": true},
	"hanon_16": {"id": "hanon_16", "name": "Hanon No. 16 — Doubled Steps", "category": "hanon", "skill_tags": ["independence", "thumb"], "min_level": 6, "max_level": 10, "two_hand_friendly": true},
	"hanon_17": {"id": "hanon_17", "name": "Hanon No. 17 — Pivoting Fingers", "category": "hanon", "skill_tags": ["independence", "evenness"], "min_level": 6, "max_level": 10, "two_hand_friendly": true},
	"hanon_18": {"id": "hanon_18", "name": "Hanon No. 18 — Reversed Cross", "category": "hanon", "skill_tags": ["independence", "finger_strength"], "min_level": 7, "max_level": 10, "two_hand_friendly": true},
	"hanon_19": {"id": "hanon_19", "name": "Hanon No. 19 — Outer Circuit", "category": "hanon", "skill_tags": ["independence", "thumb_pinky", "stretching"], "min_level": 7, "max_level": 10, "two_hand_friendly": true},
	"hanon_20": {"id": "hanon_20", "name": "Hanon No. 20 — Synthesis", "category": "hanon", "skill_tags": ["independence", "evenness"], "min_level": 7, "max_level": 10, "two_hand_friendly": true},
	# --- Scale variants ---
	"scale_thirds": {
		"id": "scale_thirds",
		"name": "Scale in 3rds",
		"category": "scale",
		"skill_tags": ["chord_voicing", "evenness", "reading"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"scale_sixths": {
		"id": "scale_sixths",
		"name": "Scale in 6ths",
		"category": "scale",
		"skill_tags": ["chord_voicing", "stretching", "reading"],
		"min_level": 6, "max_level": 10,
		"two_hand_friendly": true,
	},
	"scale_chromatic": {
		"id": "scale_chromatic",
		"name": "Chromatic Scale",
		"category": "scale",
		"skill_tags": ["velocity", "evenness", "thumb"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
	},
	"scale_contrary": {
		"id": "scale_contrary",
		"name": "Contrary Motion Scale",
		"category": "scale",
		"skill_tags": ["hand_independence", "evenness"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	# --- Czerny ---
	"czerny_velocity": {
		"id": "czerny_velocity",
		"name": "Czerny — Velocity Run",
		"category": "czerny",
		"skill_tags": ["velocity", "evenness", "hand_independence"],
		"min_level": 6, "max_level": 10,
		"two_hand_friendly": true,
	},
	"czerny_alberti": {
		"id": "czerny_alberti",
		"name": "Czerny — Alberti Etude",
		"category": "czerny",
		"skill_tags": ["hand_independence", "chord_voicing"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"czerny_sequence": {
		"id": "czerny_sequence",
		"name": "Czerny — Scale Sequence",
		"category": "czerny",
		"skill_tags": ["evenness", "velocity"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
	},
}

# Display order for the dropdown when no filter is active.
const DEFAULT_ORDER := [
	"scale", "arpeggio", "five_finger",
	"hanon_1", "hanon_2", "hanon_3", "hanon_4", "hanon_5",
	"hanon_6", "hanon_7", "hanon_8", "hanon_9", "hanon_10",
	"hanon_11", "hanon_12", "hanon_13", "hanon_14", "hanon_15",
	"hanon_16", "hanon_17", "hanon_18", "hanon_19", "hanon_20",
	"scale_thirds", "scale_sixths", "scale_chromatic", "scale_contrary",
	"czerny_velocity", "czerny_alberti", "czerny_sequence",
]


# Returns exercise IDs filtered by skill tag. "all" returns the full default order.
static func ids_for_skill(skill: String) -> Array:
	if skill == "all" or skill.is_empty():
		return DEFAULT_ORDER.duplicate()
	var out: Array = []
	for id in DEFAULT_ORDER:
		var entry: Dictionary = ENTRIES.get(id, {})
		var tags: Array = entry.get("skill_tags", [])
		if tags.has(skill):
			out.append(id)
	return out


# Returns exercise IDs appropriate for a level (level falls within [min_level, max_level]).
static func ids_for_level(level: int) -> Array:
	var out: Array = []
	for id in DEFAULT_ORDER:
		var entry: Dictionary = ENTRIES.get(id, {})
		var min_lvl: int = int(entry.get("min_level", 1))
		var max_lvl: int = int(entry.get("max_level", 10))
		if level >= min_lvl and level <= max_lvl:
			out.append(id)
	return out


# Combined filter: by skill AND by level.
static func ids_for_skill_and_level(skill: String, level: int) -> Array:
	var by_skill: Array = ids_for_skill(skill)
	var out: Array = []
	for id in by_skill:
		var entry: Dictionary = ENTRIES.get(id, {})
		var min_lvl: int = int(entry.get("min_level", 1))
		var max_lvl: int = int(entry.get("max_level", 10))
		if level >= min_lvl and level <= max_lvl:
			out.append(id)
	return out


static func entry(id: String) -> Dictionary:
	return ENTRIES.get(id, {})


static func display_name(id: String) -> String:
	return str(ENTRIES.get(id, {}).get("name", id))


# Returns an array of [skill_id, label] pairs in a presentation-ready order.
static func skill_options() -> Array:
	var out: Array = []
	var order := ["all", "finger_strength", "velocity", "evenness", "independence", "hand_independence", "thumb", "stretching", "chord_voicing", "reading"]
	for s in order:
		if SKILLS.has(s):
			out.append([s, str(SKILLS[s])])
	return out
