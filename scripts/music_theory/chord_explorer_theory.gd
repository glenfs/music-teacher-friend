class_name ChordExplorerTheory
extends RefCounted

# Pure pitch / notation helpers used by the Chord Explorer panel.
# Caller owns the visual coordinates and instance state — this module
# only knows about MIDI pitches and where they sit on the staff.


const _LETTER_PER_PC := {0: 0, 1: 0, 2: 1, 3: 1, 4: 2, 5: 3, 6: 3, 7: 4, 8: 4, 9: 5, 10: 5, 11: 6}

const _MAJOR_SHARP_FIFTHS := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6}
const _MAJOR_FLAT_FIFTHS := {5: -1, 10: -2, 3: -3, 8: -4, 1: -5}
const _MINOR_FIFTHS := {9: 0, 4: 1, 11: 2, 6: 3, 1: 4, 8: 5, 3: 6, 2: -1, 7: -2, 0: -3, 5: -4, 10: -5}

const _SHARP_LETTERS := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


# Number of sharps (positive) / flats (negative) in the given key sig.
# pc is the tonic's pitch class (0=C..11=B); is_minor selects the parallel-minor table.
static func key_pc_to_fifths(pc: int, is_minor: bool) -> int:
	if is_minor:
		if _MINOR_FIFTHS.has(pc):
			return int(_MINOR_FIFTHS[pc])
		return 0
	if _MAJOR_SHARP_FIFTHS.has(pc):
		return int(_MAJOR_SHARP_FIFTHS[pc])
	if _MAJOR_FLAT_FIFTHS.has(pc):
		return int(_MAJOR_FLAT_FIFTHS[pc])
	return 0


# Tonic letter (with sharp spelling) for a given pitch class.
static func key_pc_to_letter(pc: int) -> String:
	var pc_clamped := ((int(pc) % 12) + 12) % 12
	return _SHARP_LETTERS[pc_clamped]


# Diatonic letter index (counts natural letters only, ignores accidentals):
# C4 = 23, D4 = 24, ..., C5 = 30, etc. Used so notes a 2nd apart visually
# alternate columns instead of overlapping.
static func natural_letter_index(pitch: int) -> int:
	var pc := ((pitch % 12) + 12) % 12
	var octave := int(floor(pitch / 12.0)) - 1
	return octave * 7 + int(_LETTER_PER_PC[pc])


# Lines-and-spaces distance between two pitches (positive = ref is higher).
static func diatonic_steps_between(pitch: int, ref_pitch: int) -> int:
	return natural_letter_index(ref_pitch) - natural_letter_index(pitch)


# Returns {midi_pitch: column_index} for the given chord. Notes a 2nd or
# closer apart alternate between column 0 and column 1 so noteheads don't
# collide; larger jumps reset to column 0.
static func notation_offsets(pitches: Array[int]) -> Dictionary:
	var offsets: Dictionary = {}
	if pitches.is_empty():
		return offsets
	var prev_letter_idx := -999
	var current_col := 0
	for p in pitches:
		var letter_idx := natural_letter_index(int(p))
		if prev_letter_idx == -999:
			current_col = 0
		elif (letter_idx - prev_letter_idx) <= 1:
			current_col = 1 - current_col
		else:
			current_col = 0
		offsets[int(p)] = current_col
		prev_letter_idx = letter_idx
	return offsets
