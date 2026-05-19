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
