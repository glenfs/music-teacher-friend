extends RefCounted
class_name PatternPrimitives

# Tiny reusable note-pattern generators. Pure functions on integers (MIDI pitches).
# Build up larger exercises by combining these via SequenceTransforms.

const MAJOR_SCALE := [0, 2, 4, 5, 7, 9, 11]
const NATURAL_MINOR_SCALE := [0, 2, 3, 5, 7, 8, 10]
const HARMONIC_MINOR_SCALE := [0, 2, 3, 5, 7, 8, 11]
const CHROMATIC_SCALE := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]


# Convert a list of diatonic degrees (1-indexed: 1=root, 2=second, ..., 8=octave)
# to MIDI pitches in the given key + scale + base octave.
# Degrees beyond the scale wrap to the next octave (degree 8 = root + 12, etc.).
# Negative degrees wrap to the octave below.
static func degrees_to_midi(degrees: Array, key_pc: int, scale: Array, base_midi: int) -> Array:
	var pitches: Array = []
	var scale_size: int = scale.size()
	for d in degrees:
		var degree: int = int(d) - 1  # 1-indexed → 0-indexed
		var octave_offset: int = 0
		var scale_idx: int = degree
		if scale_idx >= 0:
			octave_offset = (scale_idx / scale_size) * 12
			scale_idx = scale_idx % scale_size
		else:
			# Negative degree handling
			var below: int = -scale_idx
			octave_offset = -((below + scale_size - 1) / scale_size) * 12
			scale_idx = (scale_size + scale_idx % scale_size) % scale_size
		var semitones: int = int(scale[scale_idx])
		pitches.append(base_midi + key_pc + octave_offset + semitones)
	return pitches


# Returns a 5-finger ascending pattern (5 notes from a scale).
# E.g., C major from MIDI 60: [60, 62, 64, 65, 67]
static func ascending_5_finger(root_midi: int, scale_intervals: Array) -> Array:
	var pitches: Array = []
	for i in range(mini(5, scale_intervals.size())):
		pitches.append(root_midi + int(scale_intervals[i]))
	return pitches


static func descending_5_finger(root_midi: int, scale_intervals: Array) -> Array:
	var pitches: Array = ascending_5_finger(root_midi, scale_intervals)
	pitches.reverse()
	return pitches


# Returns a broken triad in root position (3 notes ascending).
# third_semitones = 4 for major, 3 for minor.
static func broken_triad(root_midi: int, third_semitones: int = 4, fifth_semitones: int = 7) -> Array:
	return [root_midi, root_midi + third_semitones, root_midi + fifth_semitones]


# Returns a scale segment of `length` notes ascending, starting from root.
static func scale_segment(root_midi: int, length: int, scale_intervals: Array) -> Array:
	var pitches: Array = []
	var scale_size: int = scale_intervals.size()
	for i in range(length):
		var octave_offset: int = (i / scale_size) * 12
		var scale_idx: int = i % scale_size
		pitches.append(root_midi + octave_offset + int(scale_intervals[scale_idx]))
	return pitches


# Repeat a single pitch N times (for repeated-note drills).
static func repeated_note(pitch_midi: int, count: int) -> Array:
	var pitches: Array = []
	for i in range(count):
		pitches.append(pitch_midi)
	return pitches


# Trill between two pitches (rapid alternation).
static func trill(pitch_a: int, pitch_b: int, count: int) -> Array:
	var pitches: Array = []
	for i in range(count):
		pitches.append(pitch_a if (i % 2) == 0 else pitch_b)
	return pitches
