extends RefCounted
class_name ScaleComposer

# Scale variants beyond the basic ascending-then-descending scale already in
# TechnicalExerciseGenerator. Each variant returns a single-hand exercise dict —
# Practice Drills' "Grand" staff mode calls each composer twice (once per hand)
# and merges the streams, so contrary motion and parallel thirds work
# automatically when both hands are requested.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")
const SequenceTransformsScript = preload("res://scripts/exercises/patterns/sequence_transforms.gd")
const ExerciseValidatorScript = preload("res://scripts/exercises/exercise_validator.gd")

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# =============================================================================
# Phase 6 — Scale-style stochastic sampler.
# Picks one of the four scale variants (thirds / sixths / chromatic / contrary)
# with light octave variation. Each variant is already fully procedural; the
# generator simply chooses among them per roll. Validator gates each attempt;
# falls back to generate_thirds if every retry is rejected.
# =============================================================================

const SCALE_VARIANTS := ["thirds", "sixths", "chromatic", "contrary"]
const SCALE_MAX_RESAMPLE_TRIES := 4


static func generate_random(
	style_profile: Dictionary,
	key_pc: int,
	key_is_minor: bool,
	level: int,
	tempo_bpm: int,
	hand: String,
	octaves: int,
	rng: RandomNumberGenerator,
	generator_id: String = "scale_random"
) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var fixed_variant: String = str(style_profile.get("variant", ""))
	for attempt in range(SCALE_MAX_RESAMPLE_TRIES):
		var variant: String
		if not fixed_variant.is_empty():
			variant = fixed_variant
		else:
			variant = SCALE_VARIANTS[rng.randi_range(0, SCALE_VARIANTS.size() - 1)]
		var oct: int = clampi(octaves + rng.randi_range(-1, 1), 1, 3)
		var ex: Dictionary
		match variant:
			"thirds":
				ex = generate_thirds(key_pc, key_is_minor, oct, hand, tempo_bpm)
			"sixths":
				ex = generate_sixths(key_pc, key_is_minor, oct, hand, tempo_bpm)
			"chromatic":
				ex = generate_chromatic(key_pc, key_is_minor, oct, hand, tempo_bpm)
			"contrary":
				ex = generate_contrary(key_pc, key_is_minor, oct, hand, tempo_bpm)
			_:
				ex = generate_thirds(key_pc, key_is_minor, oct, hand, tempo_bpm)
		if not ex.is_empty() and ExerciseValidatorScript.ok(ex):
			ex["generator_id"] = generator_id
			ex["exercise_type"] = generator_id
			ex["level"] = level
			ex["title"] = "Scale-style %s — %s" % [variant, str(ex.get("title", ""))]
			return ex
	# Exhausted retries → fall back to plain scale in thirds.
	var fallback := generate_thirds(key_pc, key_is_minor, clampi(octaves, 1, 3), hand, tempo_bpm)
	fallback["generator_id"] = generator_id
	fallback["exercise_type"] = generator_id
	fallback["level"] = level
	fallback["title"] = "Scale-style thirds (fallback) — %s" % str(fallback.get("title", ""))
	return fallback


# --- Scale in thirds ---
# Each "step" is a chord of two notes a diatonic third apart. Common etude pattern
# from Czerny and pedagogical scale books.
static func generate_thirds(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var num_steps: int = 7 * octaves + 1  # 8 steps per octave (degrees 1..8), then 1..15 for two octaves, etc.
	# Lower line: degrees 1..(7*octaves+1)
	var lower_degrees: Array = []
	var upper_degrees: Array = []
	for i in range(num_steps):
		lower_degrees.append(i + 1)
		upper_degrees.append(i + 1 + 2)  # diatonic 3rd above = +2 scale degrees
	var lower_pitches: Array = PatternPrimitivesScript.degrees_to_midi(lower_degrees, key_pc, scale, base_midi)
	var upper_pitches: Array = PatternPrimitivesScript.degrees_to_midi(upper_degrees, key_pc, scale, base_midi)
	# Build descending pitches (skip top duplicate when extending)
	var lower_full: Array = lower_pitches.duplicate()
	var upper_full: Array = upper_pitches.duplicate()
	var lower_back: Array = lower_pitches.duplicate()
	lower_back.reverse()
	var upper_back: Array = upper_pitches.duplicate()
	upper_back.reverse()
	for i in range(1, lower_back.size()):
		lower_full.append(lower_back[i])
		upper_full.append(upper_back[i])
	# Both notes share the same beat → render as a chord/event of 2 noteheads.
	var notes: Array = []
	var beat: float = 0.0
	for i in range(lower_full.size()):
		notes.append({"midi": int(lower_full[i]), "duration_beats": 0.5, "beat_offset": beat, "rest": false})
		notes.append({"midi": int(upper_full[i]), "duration_beats": 0.5, "beat_offset": beat, "rest": false})
		beat += 0.5
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("scale_thirds", "Scale in 3rds", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# --- Scale in sixths ---
static func generate_sixths(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var num_steps: int = 7 * octaves + 1
	var lower_degrees: Array = []
	var upper_degrees: Array = []
	for i in range(num_steps):
		lower_degrees.append(i + 1)
		upper_degrees.append(i + 1 + 5)  # diatonic 6th above = +5 scale degrees
	var lower_pitches: Array = PatternPrimitivesScript.degrees_to_midi(lower_degrees, key_pc, scale, base_midi)
	var upper_pitches: Array = PatternPrimitivesScript.degrees_to_midi(upper_degrees, key_pc, scale, base_midi)
	var lower_full: Array = lower_pitches.duplicate()
	var upper_full: Array = upper_pitches.duplicate()
	var lower_back: Array = lower_pitches.duplicate()
	lower_back.reverse()
	var upper_back: Array = upper_pitches.duplicate()
	upper_back.reverse()
	for i in range(1, lower_back.size()):
		lower_full.append(lower_back[i])
		upper_full.append(upper_back[i])
	var notes: Array = []
	var beat: float = 0.0
	for i in range(lower_full.size()):
		notes.append({"midi": int(lower_full[i]), "duration_beats": 0.5, "beat_offset": beat, "rest": false})
		notes.append({"midi": int(upper_full[i]), "duration_beats": 0.5, "beat_offset": beat, "rest": false})
		beat += 0.5
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("scale_sixths", "Scale in 6ths", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# --- Chromatic scale ---
# Always starts on the key root and goes up by half-steps. Key signature is treated as
# C-major (no accidentals in key sig) since chromatic by definition uses every pitch class.
static func generate_chromatic(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 90) -> Dictionary:
	var base_midi: int = 48 if hand == "left" else 60
	var start: int = base_midi + key_pc
	var steps_per_octave: int = 12
	var pitches: Array = []
	for i in range(octaves * steps_per_octave + 1):
		pitches.append(start + i)
	# Descending (skip duplicate top)
	var back: Array = pitches.duplicate()
	back.reverse()
	for i in range(1, back.size()):
		pitches.append(back[i])
	var notes: Array = SequenceTransformsScript.pitches_to_eighth_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("scale_chromatic", "Chromatic Scale", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# --- Contrary motion scale ---
# RH ascends from base; LH descends from the same base. When Grand mode requests both
# hands, the merge produces a visually striking contrary-motion exercise.
static func generate_contrary(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	# Both hands start at the SAME pitch (C4 by convention) but go opposite directions.
	var start_midi: int = 60
	var num_steps: int = 7 * octaves + 1
	var pitches: Array = []
	if hand == "left":
		# Descending from start_midi
		var degrees: Array = []
		for i in range(num_steps):
			degrees.append(1 - i)  # 1, 0, -1, -2, ...
		pitches = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, start_midi)
		# Then back up
		var back: Array = pitches.duplicate()
		back.reverse()
		for i in range(1, back.size()):
			pitches.append(back[i])
	else:
		# Ascending from start_midi
		var degrees: Array = []
		for i in range(num_steps):
			degrees.append(1 + i)
		pitches = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, start_midi)
		var back: Array = pitches.duplicate()
		back.reverse()
		for i in range(1, back.size()):
			pitches.append(back[i])
	var notes: Array = SequenceTransformsScript.pitches_to_eighth_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("scale_contrary", "Contrary Motion Scale", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# --- 16th-note + triplet variants (smart-drill-library expansion) ---


# 16th-note scale — same scale pitches, half the duration of an eighth-note
# scale. Doubles the rhythmic density without going above 16ths per spec.
static func generate_scale_16ths(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 76) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var num_steps: int = 7 * octaves + 1
	var degrees: Array = []
	for i in range(num_steps):
		degrees.append(i + 1)
	var pitches: Array = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, base_midi)
	var back: Array = pitches.duplicate()
	back.reverse()
	for i in range(1, back.size()):
		pitches.append(back[i])
	var notes: Array = SequenceTransformsScript.pitches_to_sixteenth_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.25)
	return _wrap("scale_16ths", "Scale — 16th notes", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# 16th-note arpeggio — broken triad (root-3rd-5th-octave) at 16th rate.
static func generate_arpeggio_16ths(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	# Arpeggio degrees: 1, 3, 5, 8, 10, 12, 15 for two-octave; pattern per octave
	# is [1, 3, 5, 8]; subsequent octaves chain on at +7 scale degrees.
	var degrees: Array = []
	for o in range(octaves):
		var oct_offset := o * 7
		degrees.append_array([1 + oct_offset, 3 + oct_offset, 5 + oct_offset])
	degrees.append(1 + octaves * 7)  # top tonic
	var pitches: Array = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, base_midi)
	var back: Array = pitches.duplicate()
	back.reverse()
	for i in range(1, back.size()):
		pitches.append(back[i])
	var notes: Array = SequenceTransformsScript.pitches_to_sixteenth_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.25)
	return _wrap("arpeggio_16ths", "Arpeggio — 16th notes", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# Triplet scale — three notes per beat (eighth-note triplets).
static func generate_scale_triplets(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var num_steps: int = 7 * octaves + 1
	var degrees: Array = []
	for i in range(num_steps):
		degrees.append(i + 1)
	var pitches: Array = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, base_midi)
	var back: Array = pitches.duplicate()
	back.reverse()
	for i in range(1, back.size()):
		pitches.append(back[i])
	var notes: Array = SequenceTransformsScript.pitches_to_triplet_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 1.0 / 3.0)
	return _wrap("scale_triplets", "Scale — Triplets", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# Triplet arpeggio — root-3rd-5th in triplets per beat. Classic technical
# pattern (e.g. broken triad arpeggios in 3-against-4 feel).
static func generate_arpeggio_triplets(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 84) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	# 1-3-5 triplet pattern, sequenced up each octave.
	var degrees: Array = []
	for o in range(octaves):
		var oct_offset := o * 7
		degrees.append_array([1 + oct_offset, 3 + oct_offset, 5 + oct_offset])
	degrees.append(1 + octaves * 7)
	var pitches: Array = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, base_midi)
	var back: Array = pitches.duplicate()
	back.reverse()
	for i in range(1, back.size()):
		pitches.append(back[i])
	var notes: Array = SequenceTransformsScript.pitches_to_triplet_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 1.0 / 3.0)
	return _wrap("arpeggio_triplets", "Arpeggio — Triplets", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# 16th-note bass-movement pattern — root-octave-fifth-octave repeating
# (Alberti-style at 16th resolution). Common bass-hand technical pattern
# from any beginner-intermediate piano method; not specific to any work.
static func generate_bass_movement_16ths(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "left", tempo_bpm: int = 72) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 36 if hand == "left" else 48
	# Pattern within one beat: root, octave-up, fifth, octave-up (4 sixteenths).
	# Repeat for each beat, moving the root through I → IV → V → I (4 bars).
	var pitches: Array = []
	var chord_roots: Array = [1, 4, 5, 1]  # diatonic roots
	for bar in range(maxi(1, octaves)):
		for root_deg in chord_roots:
			var root_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg], key_pc, scale, base_midi)[0])
			var fifth_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg + 4], key_pc, scale, base_midi)[0])
			# Four beats of root-octave-fifth-octave per bar.
			for _beat in range(4):
				pitches.append(root_midi)
				pitches.append(root_midi + 12)
				pitches.append(fifth_midi)
				pitches.append(root_midi + 12)
	var notes: Array = SequenceTransformsScript.pitches_to_sixteenth_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.25)
	var bass_dict: Dictionary = _wrap("bass_movement_16ths", "Bass Movement — 16th notes", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)
	# Octave-leap bass figure: the pattern jumps an octave within each beat and
	# resets register at bar boundaries — idiomatic and playable for this drill.
	bass_dict["max_jump"] = 20
	return bass_dict


# --- Internal helpers ---

static func _wrap(type_str: String, label: String, key_pc: int, key_is_minor: bool, octaves: int, hand: String, tempo_bpm: int, notes: Array) -> Dictionary:
	var fifths: int = _key_to_fifths(key_pc, key_is_minor)
	var key_letter: String = _spell_key_letter(key_pc, fifths)
	var minor_label: String = "Minor" if key_is_minor else "Major"
	var title: String = "%s %s — %s" % [key_letter, minor_label, label]
	var total_beats: float = 0.0
	if not notes.is_empty():
		var last: Dictionary = notes[notes.size() - 1]
		total_beats = float(last["beat_offset"]) + float(last["duration_beats"])
	return {
		"title": title,
		"exercise_type": type_str,
		"key_pc": key_pc,
		"key_is_minor": key_is_minor,
		"key_letter": key_letter,
		"level": octaves,
		"tempo_bpm": tempo_bpm,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"octaves": octaves,
		"hand": hand,
		"fifths": fifths,
		"notes": notes,
		"total_beats": total_beats,
	}


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
