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
#     "mode": String,               # OPTIONAL: MODE_TEMPLATE (deterministic, default)
#                                   #           or MODE_GENERATOR (stochastic sampler)
#     "style_profile": Dictionary,  # OPTIONAL (generators only): constraint dict the
#                                   #           sampler walks within. Phase-7 territory.
#   }

# Two kinds of catalog entries can coexist downstream:
#   "template"  → canonical, deterministic (current behavior). Same key/level always
#                 yields the same exercise. All existing entries are templates.
#   "generator" → stochastic sampler. Takes a seed; produces a fresh exercise that
#                 satisfies the entry's style_profile each time. Added in Phase 7+.
const MODE_TEMPLATE := "template"
const MODE_GENERATOR := "generator"

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
	# --- Generator entries (Phase 7) ---
	# Each carries `mode: MODE_GENERATOR`, a `kind` that routes to the right
	# composer in TechnicalExerciseGenerator.generate(), and a `style_profile`
	# the composer's sampler walks within. Catalog mechanics (display order,
	# skill/level filters) work identically to templates — the dropdown picks
	# them up automatically.
	"hanon_5_finger_random": {
		"id": "hanon_5_finger_random",
		"name": "Hanon — 5-Finger Variation",
		"category": "hanon",
		"skill_tags": ["independence", "evenness", "finger_strength"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
		"mode": "generator",
		"kind": "hanon",
		"style_profile": {
			"length": 8,
			"start_degree": 1,
			"degree_range": [1, 5],
			"allowed_steps": [-2, -1, 1, 2],
			"contour_rule": "free",
			"ascending_positions": 8,
		},
	},
	"hanon_alternating_random": {
		"id": "hanon_alternating_random",
		"name": "Hanon — Alternating Variation",
		"category": "hanon",
		"skill_tags": ["independence", "evenness"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
		"mode": "generator",
		"kind": "hanon",
		"style_profile": {
			"length": 8,
			"start_degree": 1,
			"degree_range": [1, 6],
			"allowed_steps": [-3, -2, -1, 1, 2, 3],
			"contour_rule": "alternating_step_skip",
			"ascending_positions": 8,
		},
	},
	"hanon_any_random": {
		"id": "hanon_any_random",
		"name": "Hanon (any) — Random Variation",
		"category": "hanon",
		"skill_tags": ["independence", "evenness"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
		"mode": "generator",
		"kind": "hanon_any",  # dispatcher picks 5-finger or alternating per roll
		"style_profile": {},
	},
	"czerny_random": {
		"id": "czerny_random",
		"name": "Czerny — Random Variation",
		"category": "czerny",
		"skill_tags": ["velocity", "evenness", "hand_independence"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
		"mode": "generator",
		"kind": "czerny",
		"style_profile": {},
	},
	"scale_random": {
		"id": "scale_random",
		"name": "Scale — Random Variation",
		"category": "scale",
		"skill_tags": ["chord_voicing", "stretching", "evenness", "reading"],
		"min_level": 4, "max_level": 10,
		"two_hand_friendly": true,
		"mode": "generator",
		"kind": "scale",
		"style_profile": {},
	},
	# --- Smart Drill Library expansion: rhythmic variants ---
	"scale_16ths": {
		"id": "scale_16ths",
		"name": "Scale — 16th notes",
		"category": "scale",
		"skill_tags": ["velocity", "evenness", "finger_strength"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"arpeggio_16ths": {
		"id": "arpeggio_16ths",
		"name": "Arpeggio — 16th notes",
		"category": "arpeggio",
		"skill_tags": ["velocity", "chord_voicing", "stretching"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"scale_triplets": {
		"id": "scale_triplets",
		"name": "Scale — Triplets",
		"category": "scale",
		"skill_tags": ["evenness", "velocity", "independence"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"arpeggio_triplets": {
		"id": "arpeggio_triplets",
		"name": "Arpeggio — Triplets",
		"category": "arpeggio",
		"skill_tags": ["chord_voicing", "evenness", "velocity"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"bass_movement_16ths": {
		"id": "bass_movement_16ths",
		"name": "Bass Movement — 16ths (I-IV-V-I)",
		"category": "scale",
		"skill_tags": ["hand_independence", "velocity", "evenness"],
		"min_level": 6, "max_level": 10,
		"two_hand_friendly": false,
	},
	# --- Simple chord exercises ---
	"chord_diatonic_triads": {
		"id": "chord_diatonic_triads",
		"name": "Diatonic Triads (I–vii° → I)",
		"category": "chord",
		"skill_tags": ["chord_voicing", "reading"],
		"min_level": 3, "max_level": 10,
		"two_hand_friendly": true,
	},
	"chord_progression_classical": {
		"id": "chord_progression_classical",
		"name": "I-IV-V-I Cadence",
		"category": "chord",
		"skill_tags": ["chord_voicing", "reading"],
		"min_level": 2, "max_level": 10,
		"two_hand_friendly": true,
	},
	"chord_progression_pop": {
		"id": "chord_progression_pop",
		"name": "I-V-vi-IV Pop Progression",
		"category": "chord",
		"skill_tags": ["chord_voicing", "reading"],
		"min_level": 2, "max_level": 10,
		"two_hand_friendly": true,
	},
	"chord_diatonic_sevenths": {
		"id": "chord_diatonic_sevenths",
		"name": "Diatonic 7ths (Imaj7–viim7♭5)",
		"category": "chord",
		"skill_tags": ["chord_voicing", "stretching", "reading"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	# --- Jazz exercises ---
	"jazz_ii_v_i_major": {
		"id": "jazz_ii_v_i_major",
		"name": "Jazz ii-V-I (Major)",
		"category": "jazz",
		"skill_tags": ["chord_voicing", "reading"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": true,
	},
	"jazz_ii_v_i_minor": {
		"id": "jazz_ii_v_i_minor",
		"name": "Jazz ii-V-i (Minor, with ♭9)",
		"category": "jazz",
		"skill_tags": ["chord_voicing", "reading", "stretching"],
		"min_level": 6, "max_level": 10,
		"two_hand_friendly": true,
	},
	"jazz_stride_bass": {
		"id": "jazz_stride_bass",
		"name": "Stride Bass (I-V-vi-IV)",
		"category": "jazz",
		"skill_tags": ["hand_independence", "chord_voicing"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": false,
	},
	"jazz_walking_bass": {
		"id": "jazz_walking_bass",
		"name": "Walking Bass — Turnaround",
		"category": "jazz",
		"skill_tags": ["hand_independence", "reading"],
		"min_level": 5, "max_level": 10,
		"two_hand_friendly": false,
	},
}

# Display order for the dropdown when no filter is active. Generator entries
# are appended to the END so the canonical templates remain the default UX —
# users discover the "Random Variation" entries by scrolling, and Phase-8 polish
# surfaces them via a "🎲 New Variation" button affordance.
const DEFAULT_ORDER := [
	"scale", "arpeggio", "five_finger",
	"hanon_1", "hanon_2", "hanon_3", "hanon_4", "hanon_5",
	"hanon_6", "hanon_7", "hanon_8", "hanon_9", "hanon_10",
	"hanon_11", "hanon_12", "hanon_13", "hanon_14", "hanon_15",
	"hanon_16", "hanon_17", "hanon_18", "hanon_19", "hanon_20",
	"scale_thirds", "scale_sixths", "scale_chromatic", "scale_contrary",
	"czerny_velocity", "czerny_alberti", "czerny_sequence",
	# --- Generators (Phase 7) ---
	"hanon_5_finger_random", "hanon_alternating_random", "hanon_any_random",
	"czerny_random",
	"scale_random",
	# --- Smart Drill Library expansion ---
	"scale_16ths", "arpeggio_16ths",
	"scale_triplets", "arpeggio_triplets",
	"bass_movement_16ths",
	"chord_diatonic_triads", "chord_progression_classical",
	"chord_progression_pop", "chord_diatonic_sevenths",
	"jazz_ii_v_i_major", "jazz_ii_v_i_minor",
	"jazz_stride_bass", "jazz_walking_bass",
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
	return str(ENTRIES.get(id, {}).get("name", id)).replace("—", "-").replace("–", "-").replace("−", "-")


# Returns the catalog entry's mode (template vs generator). Entries without an
# explicit "mode" are templates — every existing entry falls under this default,
# so adding generators later is purely additive.
static func mode_for_id(id: String) -> String:
	return str(ENTRIES.get(id, {}).get("mode", MODE_TEMPLATE))


static func is_generator(id: String) -> bool:
	return mode_for_id(id) == MODE_GENERATOR


# Returns the style_profile dict for a generator entry (empty if template/missing).
# Phase-7 generator entries will populate this; templates always return {}.
static func style_profile_for_id(id: String) -> Dictionary:
	var sp: Variant = ENTRIES.get(id, {}).get("style_profile", {})
	if typeof(sp) == TYPE_DICTIONARY:
		return sp
	return {}


# Returns an array of [skill_id, label] pairs in a presentation-ready order.
static func skill_options() -> Array:
	var out: Array = []
	var order := ["all", "finger_strength", "velocity", "evenness", "independence", "hand_independence", "thumb", "stretching", "chord_voicing", "reading"]
	for s in order:
		if SKILLS.has(s):
			out.append([s, str(SKILLS[s])])
	return out
