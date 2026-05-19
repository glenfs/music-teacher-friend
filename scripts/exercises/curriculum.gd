extends RefCounted
class_name Curriculum

# Graded curriculum + Daily Warmup generator. Tells the app:
#   - What exercises are appropriate for each player level (1-10)
#   - How to pick a balanced "daily warmup" mix for a given level + focus

const ExerciseLibraryScript = preload("res://scripts/exercises/exercise_library.gd")

# Curated per-level recommendation lists. Each level inherits exercises from earlier
# levels (so level 5 includes everything at levels 1-4 too) via the library's
# min_level/max_level filter — these arrays just suggest "what to focus on now".
const LEVEL_FOCUS := {
	1:  ["scale", "five_finger"],
	2:  ["scale", "five_finger", "arpeggio"],
	3:  ["scale", "arpeggio", "five_finger"],
	4:  ["scale", "arpeggio", "hanon_1", "hanon_2"],
	5:  ["scale", "arpeggio", "hanon_1", "hanon_2", "hanon_3", "hanon_6", "scale_chromatic"],
	6:  ["scale_thirds", "scale_contrary", "hanon_3", "hanon_4", "hanon_5", "czerny_sequence"],
	7:  ["scale_thirds", "scale_sixths", "hanon_5", "hanon_8", "czerny_velocity"],
	8:  ["scale_sixths", "scale_chromatic", "hanon_8", "hanon_9", "czerny_velocity", "czerny_alberti"],
	9:  ["hanon_8", "hanon_9", "hanon_10", "czerny_velocity", "scale_contrary"],
	10: ["hanon_9", "hanon_10", "czerny_velocity", "czerny_alberti", "scale_thirds"],
}

# Recommended keys to rotate through for variety. By level, easier keys first.
const LEVEL_KEYS := {
	1:  [0],                    # C
	2:  [0, 7],                 # C, G
	3:  [0, 7, 5],              # C, G, F
	4:  [0, 7, 5, 2],           # + D
	5:  [0, 7, 5, 2, 9, 10],    # + A, Bb
	6:  [0, 7, 5, 2, 9, 10, 4, 3],   # + E, Eb
	7:  [0, 7, 5, 2, 9, 10, 4, 3, 11, 8],
	8:  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],  # all keys
	9:  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	10: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
}


# Returns a list of exercise IDs appropriate for the user's current level.
# Combines the curated focus list AND the library-derived level filter.
static func exercises_for_level(level: int) -> Array:
	var lvl: int = clampi(level, 1, 10)
	var focus_list: Array = LEVEL_FOCUS.get(lvl, ["scale"])
	var library_list: Array = ExerciseLibraryScript.ids_for_level(lvl)
	# Build an ordered, deduped result: curated focus first, then library extras.
	var seen: Dictionary = {}
	var out: Array = []
	for id in focus_list:
		if not seen.has(id) and ExerciseLibraryScript.ENTRIES.has(id):
			seen[id] = true
			out.append(id)
	for id in library_list:
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	return out


# Recommended keys for a given level (rotating selection of pitch classes).
static func keys_for_level(level: int) -> Array:
	var lvl: int = clampi(level, 1, 10)
	return LEVEL_KEYS.get(lvl, [0])


# Daily warmup: pick ONE exercise + key combination appropriate for the level + focus.
# Returns a dict { exercise_id, key_pc, key_is_minor }.
# `seed` lets callers reproduce a specific warmup; pass -1 (default) for random.
static func daily_warmup_pick(level: int, focus: String = "all", seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	# Filter exercises: appropriate for level AND matching focus.
	var candidates: Array = []
	var by_level: Array = exercises_for_level(level)
	if focus == "all" or focus.is_empty():
		candidates = by_level
	else:
		var by_focus: Array = ExerciseLibraryScript.ids_for_skill(focus)
		for id in by_level:
			if by_focus.has(id):
				candidates.append(id)
	if candidates.is_empty():
		candidates = by_level
	if candidates.is_empty():
		return {"exercise_id": "scale", "key_pc": 0, "key_is_minor": false}
	var chosen_id: String = str(candidates[rng.randi() % candidates.size()])
	var keys: Array = keys_for_level(level)
	var key_pc: int = int(keys[rng.randi() % keys.size()])
	# Occasionally pick minor (more interesting once user passes level 4).
	var key_is_minor: bool = (level >= 4) and (rng.randf() < 0.25)
	return {"exercise_id": chosen_id, "key_pc": key_pc, "key_is_minor": key_is_minor}


# Map the learning-module skill family (used by module_progress.gd) to our exercise
# focus vocabulary. Lets Daily Warmup auto-target the user's weak area pulled from
# their learning history.
const MODULE_FAMILY_TO_FOCUS := {
	"note": "reading",
	"listening": "chord_voicing",
	"keyboard": "evenness",
	"rhythm": "evenness",
	"theory": "all",
}


static func focus_for_module_family(family: String) -> String:
	return str(MODULE_FAMILY_TO_FOCUS.get(family, "all"))


# Multi-exercise daily set (4 exercises rotating through different skills).
# Returns Array of {exercise_id, key_pc, key_is_minor}.
static func daily_warmup_set(level: int, count: int = 4, seed: int = -1) -> Array:
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var skills_rotation := ["evenness", "independence", "velocity", "hand_independence"]
	var out: Array = []
	for i in range(count):
		var focus: String = skills_rotation[i % skills_rotation.size()]
		out.append(daily_warmup_pick(level, focus, int(rng.randi())))
	return out
