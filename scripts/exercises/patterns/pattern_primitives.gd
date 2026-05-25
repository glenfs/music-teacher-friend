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


# =============================================================================
# Phase 4 — Constrained random samplers.
# These are the engine the Phase-6 generator composers (Hanon-style random,
# etc.) will sit on top of. Pure functions; the caller supplies a seeded RNG.
# =============================================================================


# Walks a sequence of `length` scale degrees subject to constraints. Pure: same
# rng state + same constraints → same output, so a single seed reproduces a
# motif exactly.
#
# constraints (all optional, sensible defaults):
#   length: int                  — number of degrees in the motif. Default 8.
#   start_degree: int            — first degree (1 = root). Default 1.
#   degree_range: [lo, hi]       — inclusive bounds on the walk. Default [1, 5].
#   allowed_steps: Array[int]    — set of legal step sizes between consecutive
#                                  degrees. Default [-2, -1, 1, 2].
#   contour_rule: String         — "free" (default) | "alternating_step_skip" |
#                                  "arc" | "monotonic_up" | "monotonic_down".
#                                  Filters allowed_steps per position.
#   must_return_to_start: bool   — forces final degree == start_degree by
#                                  overriding the last step. Default false.
#
# Returns Array[int] of degrees (1-indexed). Empty array on impossible constraints.
static func walk_degrees(rng: RandomNumberGenerator, constraints: Dictionary = {}) -> Array:
	if rng == null:
		return []
	var length: int = int(constraints.get("length", 8))
	if length <= 0:
		return []
	var start: int = int(constraints.get("start_degree", 1))
	var rng_range: Array = constraints.get("degree_range", [1, 5])
	var lo: int = int(rng_range[0]) if rng_range.size() > 0 else 1
	var hi: int = int(rng_range[1]) if rng_range.size() > 1 else 5
	if hi < lo:
		return []
	var steps_set: Array = constraints.get("allowed_steps", [-2, -1, 1, 2])
	if steps_set.is_empty():
		return []
	var contour: String = str(constraints.get("contour_rule", "free"))
	var must_return: bool = bool(constraints.get("must_return_to_start", false))

	# Force start into range.
	var cur: int = clampi(start, lo, hi)
	var out: Array = [cur]
	for i in range(1, length):
		var allowed: Array = _filter_steps_for_position(steps_set, contour, i, length)
		# Filter steps that would leave the range.
		var feasible: Array = []
		for s in allowed:
			var nxt: int = cur + int(s)
			if nxt >= lo and nxt <= hi:
				feasible.append(int(s))
		if feasible.is_empty():
			# Relax contour rule rather than abort: any allowed_step that stays in range.
			for s in steps_set:
				var nxt2: int = cur + int(s)
				if nxt2 >= lo and nxt2 <= hi:
					feasible.append(int(s))
			if feasible.is_empty():
				# Constraints are over-tight; emit current degree as a stalled hold
				# rather than fail — caller can choose to re-roll the whole motif.
				out.append(cur)
				continue
		var step: int = int(feasible[rng.randi_range(0, feasible.size() - 1)])
		cur = cur + step
		out.append(cur)
	if must_return and out.size() > 0 and int(out[-1]) != start:
		# Override the last degree to satisfy the closure constraint.
		out[-1] = start
	return out


# Top-level entry: samples a complete motif (degrees + a suggested fingering)
# from a style profile. Style profiles are just constraint dicts plus a few
# motif-shaping knobs; Phase-6 composers will define a handful of well-tuned
# style profiles per genre (Hanon-5-finger, Hanon-alternating, etc.).
#
# Returns a Dictionary:
#   {
#     "degrees": Array[int],          # scale degrees (1-indexed)
#     "fingering": Array[int],        # finger numbers (1-5), heuristic mapping
#     "constraints_used": Dictionary, # the constraints actually applied
#   }
static func random_motif(rng: RandomNumberGenerator, style_profile: Dictionary = {}) -> Dictionary:
	if rng == null:
		return {"degrees": [], "fingering": [], "constraints_used": {}}
	var degrees: Array = walk_degrees(rng, style_profile)
	var fingering: Array = _heuristic_fingering(degrees, style_profile)
	return {
		"degrees": degrees,
		"fingering": fingering,
		"constraints_used": style_profile,
	}


# --- Internal helpers ---


# Returns the subset of `steps_set` permitted at position `i` (0-indexed) of a
# motif of given length, under the named contour rule.
static func _filter_steps_for_position(steps_set: Array, contour: String, i: int, length: int) -> Array:
	match contour:
		"free":
			return steps_set.duplicate()
		"alternating_step_skip":
			# Position 1, 3, 5, ... → step (±1); position 2, 4, 6, ... → skip (|step|≥2).
			# (Position 0 is the start and produces no transition; the first transition
			#  is on the way to position 1, so we key off i directly.)
			var want_step: bool = (i % 2 == 1)
			var out: Array = []
			for s in steps_set:
				var v: int = int(s)
				var is_step: bool = absi(v) == 1
				if (want_step and is_step) or (not want_step and not is_step):
					out.append(v)
			return out if not out.is_empty() else steps_set.duplicate()
		"arc":
			# First half ascends (positive steps), second half descends (negative).
			var ascending_phase: bool = i <= int(length / 2)
			var arr: Array = []
			for s in steps_set:
				if (ascending_phase and int(s) > 0) or (not ascending_phase and int(s) < 0):
					arr.append(int(s))
			return arr if not arr.is_empty() else steps_set.duplicate()
		"monotonic_up":
			var up: Array = []
			for s in steps_set:
				if int(s) > 0:
					up.append(int(s))
			return up if not up.is_empty() else steps_set.duplicate()
		"monotonic_down":
			var dn: Array = []
			for s in steps_set:
				if int(s) < 0:
					dn.append(int(s))
			return dn if not dn.is_empty() else steps_set.duplicate()
	return steps_set.duplicate()


# Heuristic finger numbering: in a 5-finger position the natural mapping is
# degree-1=finger-1, degree-2=finger-2, ..., degree-5=finger-5. Outside that
# range we clamp; for motifs that overflow the 5-finger position the Phase-6
# composer should refine the fingering. Mirrored for the LH if style_profile
# requests `hand: "left"`.
static func _heuristic_fingering(degrees: Array, style_profile: Dictionary) -> Array:
	var out: Array = []
	if degrees.is_empty():
		return out
	var lo: int = 200
	for d in degrees:
		lo = mini(lo, int(d))
	var is_left: bool = str(style_profile.get("hand", "right")) == "left"
	for d in degrees:
		var rel: int = int(d) - lo  # 0..N
		var f: int = clampi(rel + 1, 1, 5)
		if is_left:
			f = 6 - f  # LH mirrors: lowest note → pinky (5), highest → thumb (1)
		out.append(f)
	return out
