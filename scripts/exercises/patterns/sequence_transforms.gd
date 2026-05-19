extends RefCounted
class_name SequenceTransforms

# Higher-order transforms that combine pattern primitives across positions/keys/hands.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")


# Repeat a degree-pattern, shifting the starting position up by one scale-step each iteration.
# Returns a flat list of MIDI pitches.
#
# Example: pattern_degrees = [1, 3, 4, 5, 6, 5, 4, 3] (Hanon No. 1)
#          With key_pc=0 (C), MAJOR_SCALE, base_midi=60, num_positions=8:
#          → 64 MIDI pitches across 8 ascending positions in C major.
static func sequence_up_scale(
	pattern_degrees: Array,
	key_pc: int,
	scale: Array,
	base_midi: int,
	num_positions: int
) -> Array:
	var all_pitches: Array = []
	for pos in range(num_positions):
		var shifted: Array = []
		for d in pattern_degrees:
			shifted.append(int(d) + pos)
		var midi_seq: Array = PatternPrimitivesScript.degrees_to_midi(shifted, key_pc, scale, base_midi)
		for m in midi_seq:
			all_pitches.append(m)
	return all_pitches


# Append a descending counterpart of the ascending sequence — for "play up then play back down" drills.
# This is a simplification: real Hanon descending uses an inverted pattern, but reversing the ascending
# pitches works as a practice version and avoids encoding two patterns per exercise.
static func append_reversed(pitches: Array) -> Array:
	var out: Array = pitches.duplicate()
	var rev: Array = pitches.duplicate()
	rev.reverse()
	# Skip the first element of the reversed half so the top pitch isn't repeated back-to-back.
	for i in range(1, rev.size()):
		out.append(rev[i])
	return out


# Shift every pitch by an octave (or any number of semitones).
static func shift_all(pitches: Array, semitones: int) -> Array:
	var out: Array = []
	for p in pitches:
		out.append(int(p) + semitones)
	return out


# Convert a list of MIDI pitches into eighth-note "note" dicts (the canonical exercise format).
# All notes get duration_beats = 0.5 and beat_offset incrementing by 0.5.
static func pitches_to_eighth_notes(pitches: Array, start_beat: float = 0.0) -> Array:
	var notes: Array = []
	var beat: float = start_beat
	for p in pitches:
		notes.append({
			"midi": int(p),
			"duration_beats": 0.5,
			"beat_offset": beat,
			"rest": false,
		})
		beat += 0.5
	return notes


# Same but with quarter notes (1.0 beat each).
static func pitches_to_quarter_notes(pitches: Array, start_beat: float = 0.0) -> Array:
	var notes: Array = []
	var beat: float = start_beat
	for p in pitches:
		notes.append({
			"midi": int(p),
			"duration_beats": 1.0,
			"beat_offset": beat,
			"rest": false,
		})
		beat += 1.0
	return notes


# Pad note list with rests until total_beats reached (so MusicXML/render aligns to bar boundaries).
static func pad_to_bar_boundary(notes: Array, beats_per_bar: float, note_duration: float = 0.5) -> Array:
	if notes.is_empty():
		return notes
	var last_note: Dictionary = notes[notes.size() - 1]
	var current_end: float = float(last_note["beat_offset"]) + float(last_note["duration_beats"])
	var remainder: float = fmod(current_end, beats_per_bar)
	if remainder < 0.001:
		return notes
	var pad_beats: float = beats_per_bar - remainder
	var beat: float = current_end
	while beat < current_end + pad_beats - 0.001:
		notes.append({
			"midi": -1,
			"duration_beats": note_duration,
			"beat_offset": beat,
			"rest": true,
		})
		beat += note_duration
	return notes
