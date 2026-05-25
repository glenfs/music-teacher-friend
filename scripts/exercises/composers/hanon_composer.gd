extends RefCounted
class_name HanonComposer

# Generates Hanon "Virtuoso Pianist" exercises (public domain, 1873).
#
# Each Hanon exercise follows the same structural formula:
#   - An 8-note motif expressed as diatonic degrees from the current "root"
#   - The motif repeats at successive scale-step positions (typically 8 ascending positions)
#   - Both hands play the same motif, LH one octave below RH
#   - Optionally followed by a descending half (returning to start)
#
# Encoding the motif as scale degrees lets us transpose it to any key automatically.
#
# Skill tags help the curriculum/skill-focused selectors (later session) pick exercises
# that target a specific weakness.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")
const SequenceTransformsScript = preload("res://scripts/exercises/patterns/sequence_transforms.gd")
const ScoreModelScript = preload("res://scripts/score_engine/score_model.gd")
const ExerciseValidatorScript = preload("res://scripts/exercises/exercise_validator.gd")

# =============================================================================
# Phase 6 — Hanon-style stochastic sampler.
# Pairs with the canonical templates above: each template encodes ONE specific
# Op.60 motif; generate_random samples fresh motifs that respect the same
# pedagogical constraints, then sequences them across scale positions like
# Hanon does, producing a full exercise dict with the same shape as generate().
# =============================================================================

# Hanon No. 1 lives in the 5-finger position: degrees 1..5, stepwise + skip.
const STYLE_5_FINGER := {
	"length": 8,
	"start_degree": 1,
	"degree_range": [1, 5],
	"allowed_steps": [-2, -1, 1, 2],
	"contour_rule": "free",
	"ascending_positions": 8,
}

# Hanon No. 2 zigzag style: alternating step ↔ skip across 6 degrees.
const STYLE_ALTERNATING_FINGERS := {
	"length": 8,
	"start_degree": 1,
	"degree_range": [1, 6],
	"allowed_steps": [-3, -2, -1, 1, 2, 3],
	"contour_rule": "alternating_step_skip",
	"ascending_positions": 8,
}

# Stochastic variation recipes applied to the base motif. Plain is weighted
# higher (listed twice) because the canonical templates themselves are plain.
# Recipes that double motif length (broken_thirds/fifths) are intentionally
# omitted — Hanon's sequence-up-the-scale structure assumes a fixed-length motif.
const HANON_RECIPES := [
	[],
	[],
	["retrograde"],
	["invert(4)"],
]

const HANON_MAX_RESAMPLE_TRIES := 6


# Sampler entry point. Returns the same dict shape as generate() (template path).
# Resamples up to HANON_MAX_RESAMPLE_TRIES times if the validator rejects the
# output; on full exhaustion falls back to canonical Hanon No. 1 (always valid)
# and tags the result with the requesting `generator_id` so the caller can tell.
static func generate_random(
	style_profile: Dictionary,
	key_pc: int,
	key_is_minor: bool,
	level: int,
	tempo_bpm: int,
	hand: String,
	rng: RandomNumberGenerator,
	generator_id: String = "hanon_random"
) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var num_positions: int = int(style_profile.get("ascending_positions", 8))
	var include_descending: bool = bool(style_profile.get("include_descending", false))
	for attempt in range(HANON_MAX_RESAMPLE_TRIES):
		var motif_dict: Dictionary = PatternPrimitivesScript.random_motif(rng, style_profile)
		var degrees: Array = motif_dict.get("degrees", [])
		if degrees.is_empty():
			continue
		# Stochastic variation recipe on top of the sampled motif.
		var recipe: Array = HANON_RECIPES[rng.randi_range(0, HANON_RECIPES.size() - 1)]
		var varied: Array = SequenceTransformsScript.apply_stack(degrees, recipe, rng)
		# Sequence the motif up the scale, just like the canonical Hanon path.
		var pitches: Array = SequenceTransformsScript.sequence_up_scale(varied, key_pc, scale, base_midi, num_positions)
		if include_descending:
			pitches = SequenceTransformsScript.append_reversed(pitches)
		var notes: Array = SequenceTransformsScript.pitches_to_eighth_notes(pitches)
		# Per-position fingering: replay the heuristic fingering once per motif length.
		var fingering: Array = motif_dict.get("fingering", [])
		if not fingering.is_empty():
			var fl: int = fingering.size()
			for i in range(notes.size()):
				(notes[i] as Dictionary)["fingering"] = int(fingering[i % fl])
		notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
		var ex := _wrap_random(notes, key_pc, key_is_minor, level, tempo_bpm, hand, motif_dict.get("constraints_used", {}), generator_id)
		if ExerciseValidatorScript.ok(ex):
			return ex
	# Exhausted retries: degrade gracefully to canonical Hanon No. 1.
	var fallback: Dictionary = generate(1, key_pc, key_is_minor, tempo_bpm, hand, false)
	fallback["generator_id"] = generator_id
	fallback["exercise_type"] = generator_id
	fallback["title"] = "%s (fallback → Hanon No. 1)" % str(fallback.get("title", ""))
	return fallback


# Wraps the generated note list in the standard exercise dict shape, parallel
# to the canonical generate()'s tail end.
static func _wrap_random(
	notes: Array,
	key_pc: int,
	key_is_minor: bool,
	level: int,
	tempo_bpm: int,
	hand: String,
	constraints_used: Dictionary,
	generator_id: String
) -> Dictionary:
	var fifths: int = _key_to_fifths(key_pc, key_is_minor)
	var key_letter: String = _spell_key_letter(key_pc, fifths)
	var minor_label: String = "Minor" if key_is_minor else "Major"
	var total_beats: float = 0.0
	if not notes.is_empty():
		var last: Dictionary = notes[notes.size() - 1]
		total_beats = float(last["beat_offset"]) + float(last["duration_beats"])
	return {
		"title": "Hanon-style — %s %s (Level %d)" % [key_letter, minor_label, level],
		"exercise_type": generator_id,
		"key_pc": key_pc,
		"key_is_minor": key_is_minor,
		"key_letter": key_letter,
		"level": level,
		"tempo_bpm": tempo_bpm,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"octaves": 1,
		"hand": hand,
		"fifths": fifths,
		"notes": notes,
		"total_beats": total_beats,
		"generator_id": generator_id,
		"constraints_used": constraints_used,
	}

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# First 5 Hanon exercises. Pattern is in DIATONIC degrees:
#   1 = current bar's root, 2 = scale-step above, ..., 8 = octave.
# The motif iterates across `ascending_positions` bars, each starting one scale-step higher.
const HANON_TEMPLATES := {
	1: {
		"name": "Hanon No. 1",
		"subtitle": "Five-finger independence",
		"pattern":   [1, 3, 4, 5, 6, 5, 4, 3],
		"fingering": [1, 2, 3, 4, 5, 4, 3, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "5_finger_position", "evenness"],
	},
	2: {
		"name": "Hanon No. 2",
		"subtitle": "Alternating fingers",
		"pattern":   [1, 3, 2, 4, 3, 5, 4, 6],
		"fingering": [1, 3, 2, 4, 3, 5, 4, 5],
		"ascending_positions": 8,
		"skill_tags": ["independence", "alternating_fingers"],
	},
	3: {
		"name": "Hanon No. 3",
		"subtitle": "Thumb-pinky reach",
		"pattern":   [1, 5, 4, 3, 5, 4, 3, 2],
		"fingering": [1, 5, 4, 3, 5, 4, 3, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "thumb_pinky"],
	},
	4: {
		"name": "Hanon No. 4",
		"subtitle": "Broken thirds in fingers",
		"pattern":   [1, 2, 4, 3, 5, 4, 6, 5],
		"fingering": [1, 2, 3, 2, 4, 3, 5, 4],
		"ascending_positions": 8,
		"skill_tags": ["independence", "broken_thirds"],
	},
	5: {
		"name": "Hanon No. 5",
		"subtitle": "Wider intervals",
		"pattern":   [3, 1, 4, 2, 5, 3, 6, 4],
		"fingering": [3, 1, 4, 2, 5, 3, 4, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "wider_intervals", "thumb_dexterity"],
	},
	6: {
		"name": "Hanon No. 6",
		"subtitle": "Stepwise wrist agility",
		"pattern":   [1, 3, 5, 4, 3, 2, 4, 3],
		"fingering": [1, 2, 4, 3, 2, 1, 3, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "evenness"],
	},
	7: {
		"name": "Hanon No. 7",
		"subtitle": "Triplet groupings",
		"pattern":   [1, 3, 5, 6, 5, 4, 3, 2],
		"fingering": [1, 2, 3, 5, 4, 3, 2, 1],
		"ascending_positions": 8,
		"skill_tags": ["independence", "evenness"],
	},
	8: {
		"name": "Hanon No. 8",
		"subtitle": "Outer-finger drill",
		"pattern":   [5, 4, 3, 2, 1, 2, 3, 4],
		"fingering": [5, 4, 3, 2, 1, 2, 3, 4],
		"ascending_positions": 8,
		"skill_tags": ["independence", "finger_strength"],
	},
	9: {
		"name": "Hanon No. 9",
		"subtitle": "Three-and-five pattern",
		"pattern":   [1, 2, 3, 1, 2, 3, 4, 5],
		"fingering": [1, 2, 3, 1, 2, 3, 4, 5],
		"ascending_positions": 8,
		"skill_tags": ["independence", "thumb"],
	},
	10: {
		"name": "Hanon No. 10",
		"subtitle": "Reverse stepwise",
		"pattern":   [5, 3, 4, 2, 3, 1, 2, 3],
		"fingering": [5, 3, 4, 2, 3, 1, 2, 3],
		"ascending_positions": 8,
		"skill_tags": ["independence", "thumb_pinky"],
	},
	# Templates 11-20: Hanon-style finger-independence drills inspired by Book 1.
	# Patterns chosen for distinct technical focus (each emphasizes a different
	# finger combination). Verify against your edition of Op. 60 for exact matches.
	11: {
		"name": "Hanon No. 11",
		"subtitle": "Full 5-finger run",
		"pattern":   [1, 2, 3, 4, 5, 4, 3, 2],
		"fingering": [1, 2, 3, 4, 5, 4, 3, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "evenness"],
	},
	12: {
		"name": "Hanon No. 12",
		"subtitle": "Fourth-finger focus",
		"pattern":   [3, 4, 5, 4, 3, 2, 1, 2],
		"fingering": [3, 4, 5, 4, 3, 2, 1, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "finger_strength"],
	},
	13: {
		"name": "Hanon No. 13",
		"subtitle": "Cross-pattern",
		"pattern":   [1, 3, 2, 4, 3, 5, 4, 3],
		"fingering": [1, 3, 2, 4, 3, 5, 4, 3],
		"ascending_positions": 8,
		"skill_tags": ["independence", "evenness"],
	},
	14: {
		"name": "Hanon No. 14",
		"subtitle": "Mid-finger drill",
		"pattern":   [3, 2, 1, 2, 3, 4, 5, 4],
		"fingering": [3, 2, 1, 2, 3, 4, 5, 4],
		"ascending_positions": 8,
		"skill_tags": ["independence"],
	},
	15: {
		"name": "Hanon No. 15",
		"subtitle": "Leaping figures",
		"pattern":   [1, 2, 4, 3, 5, 4, 2, 3],
		"fingering": [1, 2, 4, 3, 5, 4, 2, 3],
		"ascending_positions": 8,
		"skill_tags": ["independence", "stretching"],
	},
	16: {
		"name": "Hanon No. 16",
		"subtitle": "Doubled steps",
		"pattern":   [1, 3, 5, 3, 2, 4, 2, 1],
		"fingering": [1, 3, 5, 3, 2, 4, 2, 1],
		"ascending_positions": 8,
		"skill_tags": ["independence", "thumb"],
	},
	17: {
		"name": "Hanon No. 17",
		"subtitle": "Pivoting fingers",
		"pattern":   [2, 1, 3, 2, 4, 3, 5, 4],
		"fingering": [2, 1, 3, 2, 4, 3, 5, 4],
		"ascending_positions": 8,
		"skill_tags": ["independence", "evenness"],
	},
	18: {
		"name": "Hanon No. 18",
		"subtitle": "Reversed cross-pattern",
		"pattern":   [5, 3, 4, 2, 3, 1, 2, 4],
		"fingering": [5, 3, 4, 2, 3, 1, 2, 4],
		"ascending_positions": 8,
		"skill_tags": ["independence", "finger_strength"],
	},
	19: {
		"name": "Hanon No. 19",
		"subtitle": "Outer-finger circuit",
		"pattern":   [1, 5, 2, 4, 3, 4, 2, 5],
		"fingering": [1, 5, 2, 4, 3, 4, 2, 5],
		"ascending_positions": 8,
		"skill_tags": ["independence", "thumb_pinky", "stretching"],
	},
	20: {
		"name": "Hanon No. 20",
		"subtitle": "Synthesis drill",
		"pattern":   [1, 4, 3, 5, 2, 4, 3, 2],
		"fingering": [1, 4, 3, 5, 2, 4, 3, 2],
		"ascending_positions": 8,
		"skill_tags": ["independence", "evenness"],
	},
}


# Generate a Hanon exercise as a single-hand exercise dict (compatible with Practice
# Drills UI). The Practice Drills "Grand" staff mode calls this once per hand and
# merges the streams via its own logic, so we don't need a two_hands param here.
#   hand = "right" → notes start at C4 (MIDI 60) ascending diatonically
#   hand = "left"  → notes start at C3 (MIDI 48), same pattern an octave lower
static func generate(
	exercise_num: int,
	key_pc: int,
	key_is_minor: bool = false,
	tempo_bpm: int = 100,
	hand: String = "right",
	include_descending: bool = false
) -> Dictionary:
	var template_v = HANON_TEMPLATES.get(exercise_num, null)
	if template_v == null:
		return {}
	var template: Dictionary = template_v
	var pattern_degrees: Array = template["pattern"]
	var num_positions: int = int(template.get("ascending_positions", 8))
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60

	var pitches: Array = SequenceTransformsScript.sequence_up_scale(pattern_degrees, key_pc, scale, base_midi, num_positions)
	if include_descending:
		pitches = SequenceTransformsScript.append_reversed(pitches)

	var notes: Array = SequenceTransformsScript.pitches_to_eighth_notes(pitches)
	# Attach Hanon's standard fingering: the 8-note pattern fingering repeats per position.
	var fingering: Array = template.get("fingering", [])
	if not fingering.is_empty():
		var pat_len: int = fingering.size()
		for i in range(notes.size()):
			(notes[i] as Dictionary)["fingering"] = int(fingering[i % pat_len])
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)

	var fifths: int = _key_to_fifths(key_pc, key_is_minor)
	var key_letter: String = _spell_key_letter(key_pc, fifths)
	var minor_label: String = "Minor" if key_is_minor else "Major"
	var subtitle: String = str(template.get("subtitle", ""))
	var title: String = "%s — %s %s" % [template["name"], key_letter, minor_label]
	if not subtitle.is_empty():
		title += " (%s)" % subtitle

	var total_beats: float = 0.0
	if not notes.is_empty():
		var last: Dictionary = notes[notes.size() - 1]
		total_beats = float(last["beat_offset"]) + float(last["duration_beats"])

	return {
		"title": title,
		"exercise_type": "hanon_%d" % exercise_num,
		"key_pc": key_pc,
		"key_is_minor": key_is_minor,
		"key_letter": key_letter,
		"level": exercise_num,
		"tempo_bpm": tempo_bpm,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"octaves": 1,
		"hand": hand,
		"fifths": fifths,
		"notes": notes,
		"total_beats": total_beats,
		"skill_tags": template.get("skill_tags", []),
	}


# --- Key-spelling helpers (mirror the same logic used by other composers) ---

static func _key_to_fifths(pc: int, is_minor: bool) -> int:
	if is_minor:
		var minor_map := {9: 0, 4: 1, 11: 2, 6: 3, 1: 4, 8: 5, 3: 6, 2: -1, 7: -2, 0: -3, 5: -4, 10: -5}
		if minor_map.has(pc):
			return int(minor_map[pc])
		return 0
	var sharp_map := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6}
	var flat_map := {5: -1, 10: -2, 3: -3, 8: -4, 1: -5}
	if sharp_map.has(pc):
		return int(sharp_map[pc])
	if flat_map.has(pc):
		return int(flat_map[pc])
	return 0


static func _spell_key_letter(pc: int, fifths: int) -> String:
	var pc_clamped := ((int(pc) % 12) + 12) % 12
	if fifths < 0:
		return NOTE_NAMES_FLAT[pc_clamped]
	return NOTE_NAMES_SHARP[pc_clamped]
