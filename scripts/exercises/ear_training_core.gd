class_name EarTrainingCore
extends RefCounted

# Pure question-picking + pool-building helpers for Interval / Chord ear
# training modes. All inputs are passed in — no instance state. Caller
# (interval_birds.gd) owns the RNG, review queue, focus-misses array, and
# the live difficulty toggles, and just calls these to compute the next
# question.


# Hand-tuned difficulty rank used during the early-question ramp. Lower =
# more recognizable interval (e.g. P8 / P5 are very easy, TT / m2 are hard).
const INTERVAL_DIFFICULTY_RANK := {
	"P1": 0, "P8": 1, "P5": 2, "P4": 3,
	"M3": 4, "m3": 5, "M6": 6, "m6": 7,
	"M2": 8, "M7": 9, "m2": 10, "m7": 11, "TT": 12,
}

# Easy-first picks for question 1 — first match in this order wins.
const EASY_INTERVAL_ORDER := ["P8", "P5", "P4", "M3", "P1"]
const EASY_CHORD_ORDER := ["Major", "Minor", "Dom7", "Maj7", "Min7", "Dim"]

# Chord difficulty rank used by mid-session adaptive escalation. Lower = easier
# to recognize by ear. Triads first, dominant/major7th next, extensions later.
const CHORD_DIFFICULTY_RANK := {
	"Major": 0, "Minor": 1, "Power": 2, "Sus2": 3, "Sus4": 3,
	"Dom7": 4, "Maj7": 5, "Min7": 6, "Dim": 7, "Aug": 8,
	"Half-dim": 9, "Dim7": 10, "mMaj7": 11, "Aug7": 12, "AugMaj7": 13,
	"7sus4": 9, "Maj6": 6, "Min6": 7, "6-9": 12, "6/9": 12,
	"Dom9": 10, "Maj9": 11, "Min9": 11, "Add9": 8, "Madd9": 9,
	# 11ths/13ths - top of extension stack
	"Dom11": 14, "Maj11": 15, "Min11": 15, "Dom13": 16, "Maj7#11": 16,
	# Altered dominants - hard by ear, very distinct color
	"7#9": 13, "7b9": 13, "7b5": 12,
	# Augmented sixths - classical theory specialty
	"It+6": 17, "Fr+6": 17, "Ger+6": 17,
}


# Returns the rolling accuracy of the last N results in [0.0, 1.0]. Empty
# arrays return -1.0 (sentinel: "not enough data, don't adapt").
static func rolling_accuracy(results: Array, min_samples: int = 4) -> float:
	if results.size() < min_samples:
		return -1.0
	var hits := 0
	for r in results:
		if bool(r):
			hits += 1
	return float(hits) / float(results.size())


# Picks the easiest item from full_pool that's NOT already in active.
# Used when rolling accuracy is high and we want to introduce a harder
# item to keep the round growing in difficulty. Returns "" if none.
static func next_item_to_add(active: Array, full_pool: Array, rank_table: Dictionary) -> String:
	var candidates: Array[String] = []
	for item in full_pool:
		var sid := str(item)
		if not active.has(sid):
			candidates.append(sid)
	if candidates.is_empty():
		return ""
	candidates.sort_custom(func(a, b): return int(rank_table.get(a, 99)) < int(rank_table.get(b, 99)))
	return candidates[0]


# Picks the hardest item in active that's safe to drop (not in protected_set
# and would leave >= min_remaining items). Used when rolling accuracy is low.
# Returns "" when no item is safe to drop.
static func hardest_item_to_drop(active: Array, rank_table: Dictionary, protected_set: Dictionary = {}, min_remaining: int = 2) -> String:
	if active.size() <= min_remaining:
		return ""
	var droppable: Array[String] = []
	for item in active:
		var sid := str(item)
		if not protected_set.has(sid):
			droppable.append(sid)
	if droppable.is_empty():
		return ""
	droppable.sort_custom(func(a, b): return int(rank_table.get(a, 99)) > int(rank_table.get(b, 99)))
	return droppable[0]


# Build the interval pool from the user's selected degrees + minor toggle.
# Falls back to the unfiltered selection when minor-stripping leaves the
# pool empty (so the round is never blocked).
static func build_interval_pool(selected_degrees: Array, include_minor: bool, degree_intervals: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for d in selected_degrees:
		var options: Array = degree_intervals.get(d, [])
		for id in options:
			var iid := str(id)
			if iid.begins_with("m") and not include_minor:
				continue
			if not pool.has(iid):
				pool.append(iid)
	if pool.is_empty():
		for d in selected_degrees:
			var fallback_options: Array = degree_intervals.get(d, [])
			for id in fallback_options:
				var fallback_id := str(id)
				if not pool.has(fallback_id):
					pool.append(fallback_id)
	return pool


# Returns the user's selected chord types, filtered through CHORD_INTERVALS
# membership. Falls back to the default selection (Major/Minor) when empty.
static func available_chord_types(selected_chord_types: Array, chord_intervals: Dictionary, defaults: Array) -> Array[String]:
	var out: Array[String] = []
	for chord_name in selected_chord_types:
		var s := str(chord_name)
		if chord_intervals.has(s) and not out.has(s):
			out.append(s)
	if out.is_empty():
		for chord_name in defaults:
			out.append(str(chord_name))
	return out


# Resolve a chord quality + root + inversion into the actual MIDI notes.
# Inversions are applied by rotating notes upward an octave.
static func chord_notes(root_midi: int, chord_quality: String, inversion: int, chord_intervals: Dictionary) -> Array[int]:
	var raw_intervals: Array = chord_intervals[chord_quality]
	var intervals: Array[int] = []
	for v in raw_intervals:
		intervals.append(int(v))
	var inv_count := mini(inversion, intervals.size() - 1)
	for _i in inv_count:
		var moved: int = int(intervals.pop_front()) + 12
		intervals.append(moved)
	var notes: Array[int] = []
	for iv in intervals:
		notes.append(root_midi + iv)
	return notes


# Dynamic interval root MIDI range based on how far into the round we are.
# Early questions stay near middle C; later questions widen the range.
static func interval_root_range(q_ratio: float) -> Vector2i:
	if q_ratio < 0.30:
		return Vector2i(58, 62)
	if q_ratio < 0.65:
		return Vector2i(53, 67)
	return Vector2i(48, 72)


# Trim the ask pool by interval difficulty rank during the early-question
# ramp so the round opens with recognizable intervals. Returns the original
# pool unchanged when the ramp would leave it empty.
static func ramp_interval_pool(ask_pool: Array[String], q_ratio: float) -> Array[String]:
	if ask_pool.size() <= 2:
		return ask_pool
	var max_rank := 3 if q_ratio < 0.25 else (7 if q_ratio < 0.55 else 99)
	var ramped: Array[String] = []
	for rid in ask_pool:
		if INTERVAL_DIFFICULTY_RANK.get(rid, 99) <= max_rank:
			ramped.append(rid)
	return ramped if not ramped.is_empty() else ask_pool


# First-question easy pick for Interval mode. Returns the first easy id that
# appears in the active pool, or "" if none match.
static func easy_interval_first_pick(active_intervals: Array) -> String:
	for easy in EASY_INTERVAL_ORDER:
		if easy in active_intervals:
			return easy
	return ""


# First-question easy pick for Chord mode. Returns the first easy chord that
# appears in the active ask pool, or "" if none match.
static func easy_chord_first_pick(chord_ask_pool: Array) -> String:
	for easy in EASY_CHORD_ORDER:
		if easy in chord_ask_pool:
			return easy
	return ""


# Pick the next interval question. Tries up to 16 attempts to avoid repeating
# the previous question's signature.
#
# Returns { interval_id, root_midi, second_midi, signature } — caller stores
# the signature and applies the rest to its current-question state.
#
# `weighted_pick` is the review queue's preferred id (empty when no queue
# weight). `interval_id_for_semitones_fn` is injected so this module doesn't
# depend on MusicHelpers directly.
static func pick_interval_question(
	ask_pool: Array[String],
	weighted_pick: String,
	last_signature: String,
	q_ratio: float,
	interval_data: Dictionary,
	interval_id_for_semitones_fn: Callable,
	rng: RandomNumberGenerator
) -> Dictionary:
	var range_v := interval_root_range(q_ratio)
	var root_min: int = range_v.x
	var root_max: int = range_v.y
	var picked_id := ""
	var root_midi := 60
	var second_midi := 60
	var sig := ""
	for attempt in range(16):
		if weighted_pick != "" and attempt == 0:
			picked_id = weighted_pick
		else:
			picked_id = ask_pool[rng.randi_range(0, ask_pool.size() - 1)]
		var semitone_options: Array = interval_data[picked_id]["semitones"]
		var semitones: int = int(semitone_options[rng.randi_range(0, semitone_options.size() - 1)])
		root_midi = rng.randi_range(root_min, root_max)
		second_midi = root_midi + semitones
		# Re-derive id from actual semitones (interval ids can repeat octaves)
		picked_id = str(interval_id_for_semitones_fn.call(second_midi - root_midi))
		sig = "%s:%d:%d" % [picked_id, root_midi, second_midi]
		if sig != last_signature or attempt == 15:
			break
	return {
		"interval_id": picked_id,
		"root_midi": root_midi,
		"second_midi": second_midi,
		"signature": sig,
	}


# Pick the next chord question. Tries up to 16 attempts to avoid repeating
# the previous question's signature. Returns { quality, root_midi, inversion,
# notes, signature }. Inversion is only applied when allowed AND the
# inversion toggle is on; allow_inversions itself is the caller's
# precomputed flag (true when the user has any non-triads selected).
static func pick_chord_question(
	chord_ask_pool: Array[String],
	weighted_pick: String,
	last_signature: String,
	allow_inversions: bool,
	inversion_toggle_on: bool,
	chord_intervals: Dictionary,
	rng: RandomNumberGenerator
) -> Dictionary:
	var quality := ""
	var root_midi := 60
	var inversion := 0
	var notes: Array[int] = []
	var sig := ""
	for attempt in range(16):
		if attempt == 0 and not weighted_pick.is_empty():
			quality = weighted_pick
		else:
			quality = chord_ask_pool[rng.randi_range(0, chord_ask_pool.size() - 1)]
		root_midi = rng.randi_range(50, 60)
		inversion = 0
		if allow_inversions and inversion_toggle_on:
			var max_inversion := mini(2, chord_intervals[quality].size() - 1)
			if max_inversion > 0:
				inversion = rng.randi_range(0, max_inversion)
		notes = chord_notes(root_midi, quality, inversion, chord_intervals)
		sig = "%s:%d:%d" % [quality, root_midi, inversion]
		if sig != last_signature or attempt == 15:
			break
	return {
		"quality": quality,
		"root_midi": root_midi,
		"inversion": inversion,
		"notes": notes,
		"signature": sig,
	}
