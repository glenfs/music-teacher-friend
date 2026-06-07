extends RefCounted
class_name ChordComposer

# Simple chord-progression exercises generated procedurally from the key.
# All patterns here are foundational diatonic-theory constructs (block
# triads, common cadences, pop progression) — no copyrighted source
# material. The composer builds them per-key + per-quality from scratch
# so any voicing decision is ours, not borrowed.
#
# Pedagogical references for the patterns chosen:
# - Diatonic triads through I-vii° — universal harmony exercise (any
#   theory textbook).
# - I-IV-V-I — the foundational classical cadence.
# - I-V-vi-IV — common pop progression (Pachelbel/Axis-of-Awesome shape).
# - Diatonic sevenths — jazz/contemporary theory standard.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")
const SequenceTransformsScript = preload("res://scripts/exercises/patterns/sequence_transforms.gd")


# --- Diatonic triads — I, ii, iii, IV, V, vi, vii° all block half-notes,
# 4 chords per bar (8 chords total over 2 bars) so the whole 7-chord run
# plus a return-to-I fits in 4 bars. Right hand gets the triad block,
# left hand doubles the root an octave down.
static func generate_diatonic_triads(key_pc: int, key_is_minor: bool, hand: String = "right", tempo_bpm: int = 60) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var notes: Array = []
	var beat: float = 0.0
	# Walk degrees 1..7 + return to 1.
	var degrees: Array = [1, 2, 3, 4, 5, 6, 7, 1]
	for deg in degrees:
		# Triad pitches: degree, degree+2, degree+4 from the scale.
		var triad_pitches: Array = PatternPrimitivesScript.degrees_to_midi([deg, deg + 2, deg + 4], key_pc, scale, base_midi)
		for p in triad_pitches:
			notes.append({
				"midi": int(p),
				"duration_beats": 2.0,
				"beat_offset": beat,
				"rest": false,
			})
		beat += 2.0
	var triad_label: String = "Diatonic Triads (i–VII → i)" if key_is_minor else "Diatonic Triads (I–vii° → I)"
	return _wrap("chord_diatonic_triads", triad_label, key_pc, key_is_minor, hand, tempo_bpm, notes, beat)


# I-IV-V-I — classical cadence in block triads. One chord per bar (whole
# notes) for slow practice; total 4 bars.
static func generate_progression_classical(key_pc: int, key_is_minor: bool, hand: String = "right", tempo_bpm: int = 60) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var degrees_seq: Array = [1, 4, 5, 1]
	var notes: Array = []
	var beat: float = 0.0
	for deg in degrees_seq:
		var triad: Array = PatternPrimitivesScript.degrees_to_midi([deg, deg + 2, deg + 4], key_pc, scale, base_midi)
		# In a minor key the dominant (V) must use the raised leading tone, otherwise
		# natural minor produces a MINOR v with no leading-tone pull — i.e. not a real
		# authentic cadence. Raise the chord's 3rd (the 7th scale degree) a semitone
		# to form the major V (harmonic-minor dominant).
		if key_is_minor and deg == 5 and triad.size() >= 2:
			triad[1] = int(triad[1]) + 1
		for p in triad:
			notes.append({
				"midi": int(p),
				"duration_beats": 4.0,
				"beat_offset": beat,
				"rest": false,
			})
		beat += 4.0
	var cad_label: String = "i-iv-V-i Cadence" if key_is_minor else "I-IV-V-I Cadence"
	return _wrap("chord_progression_classical", cad_label, key_pc, key_is_minor, hand, tempo_bpm, notes, beat)


# I-V-vi-IV — common pop progression. Half notes (2 chords per bar) so
# the four-chord loop fits in 2 bars + repeats once = 4 bars total.
static func generate_progression_pop(key_pc: int, key_is_minor: bool, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var degrees_seq: Array = [1, 5, 6, 4, 1, 5, 6, 4]
	var notes: Array = []
	var beat: float = 0.0
	for deg in degrees_seq:
		var triad: Array = PatternPrimitivesScript.degrees_to_midi([deg, deg + 2, deg + 4], key_pc, scale, base_midi)
		for p in triad:
			notes.append({
				"midi": int(p),
				"duration_beats": 2.0,
				"beat_offset": beat,
				"rest": false,
			})
		beat += 2.0
	return _wrap("chord_progression_pop", "I-V-vi-IV Pop Progression", key_pc, key_is_minor, hand, tempo_bpm, notes, beat)


# Diatonic 7th chords — Imaj7, iim7, iiim7, IVmaj7, V7, vim7, viim7♭5 all
# block half-notes. Each chord = root + 3rd + 5th + 7th (4 notes).
static func generate_diatonic_sevenths(key_pc: int, key_is_minor: bool, hand: String = "right", tempo_bpm: int = 60) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var notes: Array = []
	var beat: float = 0.0
	var degrees: Array = [1, 2, 3, 4, 5, 6, 7, 1]
	for deg in degrees:
		# 7th chord: degree + 2 + 4 + 6 (root, 3rd, 5th, 7th).
		var chord_pitches: Array = PatternPrimitivesScript.degrees_to_midi(
			[deg, deg + 2, deg + 4, deg + 6], key_pc, scale, base_midi)
		for p in chord_pitches:
			notes.append({
				"midi": int(p),
				"duration_beats": 2.0,
				"beat_offset": beat,
				"rest": false,
			})
		beat += 2.0
	var sevenths_label: String = "Diatonic 7ths (im7–VII7)" if key_is_minor else "Diatonic 7ths (Imaj7–viim7♭5)"
	return _wrap("chord_diatonic_sevenths", sevenths_label, key_pc, key_is_minor, hand, tempo_bpm, notes, beat)


# --- Internal helpers ---


static func _wrap(type_str: String, label: String, key_pc: int, key_is_minor: bool, hand: String, tempo_bpm: int, notes: Array, total_beats: float) -> Dictionary:
	var fifths: int = _key_to_fifths(key_pc, key_is_minor)
	var key_letter: String = _spell_key_letter(key_pc, fifths)
	var minor_label: String = "Minor" if key_is_minor else "Major"
	return {
		"title": "%s %s — %s" % [key_letter, minor_label, label],
		"exercise_type": type_str,
		"key_pc": key_pc,
		"key_is_minor": key_is_minor,
		"key_letter": key_letter,
		"level": 3,
		"tempo_bpm": tempo_bpm,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"octaves": 1,
		"hand": hand,
		"fifths": fifths,
		"notes": notes,
		"total_beats": total_beats,
	}


static func _key_to_fifths(pc: int, is_minor: bool) -> int:
	var maj_fifths := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6, 1: -5, 8: -4, 3: -3, 10: -2, 5: -1}
	var pc_norm := ((pc % 12) + 12) % 12
	if is_minor:
		var rel_pc: int = ((pc_norm + 3) % 12 + 12) % 12
		return int(maj_fifths.get(rel_pc, 0))
	return int(maj_fifths.get(pc_norm, 0))


static func _spell_key_letter(pc: int, fifths: int) -> String:
	const SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	const FLAT  := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
	var pc_norm := ((pc % 12) + 12) % 12
	return FLAT[pc_norm] if fifths < 0 else SHARP[pc_norm]
