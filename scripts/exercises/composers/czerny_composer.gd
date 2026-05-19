extends RefCounted
class_name CzernyComposer

# Generates exercises in the style of Carl Czerny's pedagogical works
# (Op. 599 — 100 Recreations; Op. 740 — School of Velocity; etc.).
# All Czerny works are public domain (1830s-1850s).
#
# Three exercise variants, each capturing a different Czerny formula:
#   - velocity_run:  long unbroken scale runs in 16ths (school-of-velocity feel)
#   - alberti_etude: RH scale fragments over LH Alberti-bass accompaniment
#   - scale_sequence: short scale-fragment motif sequenced up the diatonic scale
#
# Like the other composers, generate(...) returns a single-hand exercise dict so
# Practice Drills' Grand mode can call it twice and merge the streams automatically.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")
const SequenceTransformsScript = preload("res://scripts/exercises/patterns/sequence_transforms.gd")

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


# --- Velocity Run ---
# RH (or LH if requested): 2-octave scale up + back down in eighth notes (we'd
# render as 16ths if/when the renderer beams them properly, but eighths are
# visually clean for now).
# When requested as the LH partner in Grand mode, we generate a simple supporting
# pattern: root on beats 1 & 3, fifth on beats 2 & 4, an octave below.
static func generate_velocity_run(key_pc: int, key_is_minor: bool, octaves: int = 2, hand: String = "right", tempo_bpm: int = 120) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var notes: Array
	if hand == "left":
		notes = _build_root_fifth_accompaniment(key_pc, scale, octaves)
	else:
		notes = _build_full_scale_run(key_pc, scale, octaves, 60)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("czerny_velocity", "Czerny Velocity Run", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# --- Alberti Etude ---
# RH plays a stepwise melody (ascending then descending scale fragments).
# LH plays an Alberti bass — the iconic "broken triad" pattern bass-tenor-alto-tenor
# repeated. With major triad I-IV-V-I progression for harmonic interest.
static func generate_alberti_etude(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 100) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var notes: Array
	if hand == "left":
		notes = _build_alberti_bass(key_pc, key_is_minor)
	else:
		notes = _build_alberti_melody(key_pc, scale)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("czerny_alberti", "Czerny Alberti Etude", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# --- Scale Sequence ---
# 4-note motif (degrees 1-2-3-4) sequenced up the scale. Same structural family as Hanon
# but with a different motif emphasizing forward scalar motion.
static func generate_scale_sequence(key_pc: int, key_is_minor: bool, octaves: int = 1, hand: String = "right", tempo_bpm: int = 100) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var motif := [1, 2, 3, 4]
	var base_midi: int = 48 if hand == "left" else 60
	var num_positions: int = 8
	var pitches: Array = SequenceTransformsScript.sequence_up_scale(motif, key_pc, scale, base_midi, num_positions)
	var notes: Array = SequenceTransformsScript.pitches_to_eighth_notes(pitches)
	notes = SequenceTransformsScript.pad_to_bar_boundary(notes, 4.0, 0.5)
	return _wrap("czerny_sequence", "Czerny Scale Sequence", key_pc, key_is_minor, octaves, hand, tempo_bpm, notes)


# ============================================================================
# Builders for individual hand parts
# ============================================================================

static func _build_full_scale_run(key_pc: int, scale: Array, octaves: int, base_midi: int) -> Array:
	var num_steps: int = 7 * octaves + 1
	var degrees: Array = []
	for i in range(num_steps):
		degrees.append(i + 1)
	var pitches: Array = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, base_midi)
	# Append descending (skip duplicate top)
	var back: Array = pitches.duplicate()
	back.reverse()
	for i in range(1, back.size()):
		pitches.append(back[i])
	return SequenceTransformsScript.pitches_to_eighth_notes(pitches)


static func _build_root_fifth_accompaniment(key_pc: int, scale: Array, octaves: int) -> Array:
	# Simple LH "boom-chuck" pattern: root and fifth alternating on each beat.
	# Length must match the RH scale-run's padded bar length; otherwise Grand mode
	# leaves the treble staff empty while the bass keeps playing.
	var notes: Array = []
	var base_midi: int = 36  # C2
	var root_midi: int = base_midi + key_pc
	var fifth_midi: int = root_midi + 7
	var num_steps: int = 7 * octaves + 1
	var rh_raw_beats: float = float(num_steps * 2 - 1) * 0.5
	var target_beats: float = ceilf(rh_raw_beats / 4.0) * 4.0
	var beat: float = 0.0
	var i := 0
	while beat < target_beats - 0.001:
		var pitch: int = root_midi if (i % 2) == 0 else fifth_midi
		notes.append({"midi": pitch, "duration_beats": 1.0, "beat_offset": beat, "rest": false})
		beat += 1.0
		i += 1
	return notes


static func _build_alberti_melody(key_pc: int, scale: Array) -> Array:
	# Simple stepwise melody — 4 bars ascending then 4 bars descending in quarter notes.
	var degrees: Array = [1, 2, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 1]
	var pitches: Array = PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, 60)
	var notes: Array = SequenceTransformsScript.pitches_to_quarter_notes(pitches)
	return notes


static func _build_alberti_bass(key_pc: int, key_is_minor: bool) -> Array:
	# Alberti pattern in eighth notes: bass-top-mid-top, repeated.
	# Cycle through I-IV-V-I chords across 4 bars (1 chord per bar = 8 notes per bar).
	var third_int: int = 3 if key_is_minor else 4
	# Chord roots: I, IV, V, I (in scale degrees from key tonic).
	var chord_roots_offsets := [0, 5, 7, 0]  # semitones from tonic
	var notes: Array = []
	var base_midi: int = 48  # C3
	var beat: float = 0.0
	# One cycle is 16 beats total, matching the RH melody length.
	for cycle in range(1):
		for chord_idx in range(chord_roots_offsets.size()):
			var root: int = base_midi + key_pc + int(chord_roots_offsets[chord_idx])
			var third: int = root + third_int
			var fifth: int = root + 7
			# Alberti pattern: bass, top (fifth), middle (third), top (fifth) — repeated twice = 8 eighth notes
			var pattern_pitches := [root, fifth, third, fifth, root, fifth, third, fifth]
			for p in pattern_pitches:
				notes.append({"midi": int(p), "duration_beats": 0.5, "beat_offset": beat, "rest": false})
				beat += 0.5
	return notes


# ============================================================================
# Common wrapper
# ============================================================================

static func _wrap(type_str: String, label: String, key_pc: int, key_is_minor: bool, octaves: int, hand: String, tempo_bpm: int, notes: Array) -> Dictionary:
	var fifths: int = _key_to_fifths(key_pc, key_is_minor)
	var key_letter: String = _spell_key_letter(key_pc, fifths)
	var minor_label: String = "Minor" if key_is_minor else "Major"
	var title: String = "%s — %s %s" % [label, key_letter, minor_label]
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
