extends RefCounted
class_name SightSingingMelodyGenerator

# Builds short sight-singing melodies. Reuses the Phase-4 PatternPrimitives
# sampler so we don't write another walk-the-scale algorithm from scratch.
#
# Pedagogical defaults (v1):
#   - 4-8 notes
#   - Starts on the tonic (degree 1)
#   - Ends on the tonic (must_return_to_start = true) — gives the singer a
#     satisfying close and reinforces the key center
#   - Stepwise + small skips within the pentachord (degrees 1..5)
#   - Allowed steps: ±1, ±2 scale degrees (so the singer never has to leap)
#
# Returns Array[int] of MIDI notes. Caller controls the base octave by
# adjusting the returned pitches — default base C4 keeps everything in a
# comfortable mixed-voice range.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")

const MIN_LENGTH := 4
const MAX_LENGTH := 8


# Generates a melody for the given key (pitch class 0-11), scale, length.
# `rng` is required so the caller can seed reproducibly.
static func generate(key_pc: int, key_is_minor: bool, length: int, rng: RandomNumberGenerator) -> Array:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var len_clamped: int = clampi(length, MIN_LENGTH, MAX_LENGTH)
	var constraints := {
		"length": len_clamped,
		"start_degree": 1,
		"degree_range": [1, 5],
		"allowed_steps": [-2, -1, 1, 2],
		"contour_rule": "free",
		"must_return_to_start": true,
	}
	var degrees: Array = PatternPrimitivesScript.walk_degrees(rng, constraints)
	if degrees.is_empty():
		# Fallback: ascending pentachord then back down. Always usable.
		degrees = [1, 2, 3, 2, 1]
	# Base C4 keeps RH staff comfortable for most singers. The evaluator
	# matches octave-agnostically, so the singer can produce any octave.
	var base_midi: int = 60
	return PatternPrimitivesScript.degrees_to_midi(degrees, key_pc, scale, base_midi)
