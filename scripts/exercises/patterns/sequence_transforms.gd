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


# =============================================================================
# Phase 5 — Transform palette.
# Pure functions on motifs (Array[int] of degrees or pitches) and events
# (Array[Dictionary] of note dicts). Stackable via apply_stack(). Each transform
# has a clear invariant verified in exercise_self_test.gd.
# =============================================================================


# Melodic inversion: reflects every element around an axis. invert(invert(m,a),a) == m.
# Works on degrees (1-indexed) or MIDI pitches — same arithmetic either way.
# axis_degree=4 with motif [1,3,4,5,6,5,4,3] → [7,5,4,3,2,3,4,5].
static func invert(motif: Array, axis_degree: int) -> Array:
	var out: Array = []
	for d in motif:
		out.append(2 * axis_degree - int(d))
	return out


# Time reversal. retrograde(retrograde(m)) == m. Preserves length.
static func retrograde(motif: Array) -> Array:
	var out: Array = motif.duplicate()
	out.reverse()
	return out


# Alias for invert(), expressing intent: the LH "mirror" of an RH motif moves
# in contrary motion around `axis_degree`. Common in Hanon Nos. 11–12 and
# contrary-motion scale exercises.
static func contrary_motion(motif: Array, axis_degree: int) -> Array:
	return invert(motif, axis_degree)


# Parallel-octave hand partner: shifts every element by 12 * octaves semitones.
# Use on MIDI pitches (not degrees). Default -1 covers the standard "LH plays
# the same shape, one octave below" Hanon convention.
static func octave_shift(pitches: Array, octaves: int = -1) -> Array:
	return shift_all(pitches, 12 * octaves)


# Rhythmic augmentation/diminution: scales every event's duration AND its
# beat_offset by `factor`. Factor 2.0 doubles durations (quarter → half);
# 0.5 halves them. Events outside Array[Dictionary] are returned untouched.
static func rhythmic_augment(events: Array, factor: float) -> Array:
	if factor <= 0.0:
		return events
	var out: Array = []
	for e_any in events:
		if typeof(e_any) != TYPE_DICTIONARY:
			out.append(e_any)
			continue
		var e: Dictionary = (e_any as Dictionary).duplicate()
		e["duration_beats"] = float(e.get("duration_beats", 0.0)) * factor
		e["beat_offset"] = float(e.get("beat_offset", 0.0)) * factor
		out.append(e)
	return out


# Broken-chord substitution: each input degree d becomes a pair [d, d + interval]
# (so length doubles). interval=2 yields broken thirds; interval=4 yields broken
# fifths. Useful for "Hanon No. 4 — Broken 3rds" style variations without
# encoding the bigger motif explicitly.
static func broken_chord_substitute(motif: Array, interval: int = 2) -> Array:
	var out: Array = []
	for d in motif:
		out.append(int(d))
		out.append(int(d) + interval)
	return out


# Passing-tone ornamentation: between consecutive events whose MIDI distance is
# >= 3 semitones, optionally insert a passing tone halfway in pitch and time.
# `density` ∈ [0,1] is the per-gap probability. Caller supplies a seeded RNG so
# the result is reproducible. Output is a new event list sorted by beat_offset.
static func ornament_passing_tones(events: Array, density: float, rng: RandomNumberGenerator) -> Array:
	if events.is_empty() or density <= 0.0 or rng == null:
		return events.duplicate()
	var out: Array = []
	for i in range(events.size()):
		var cur_any = events[i]
		out.append(cur_any)
		if typeof(cur_any) != TYPE_DICTIONARY:
			continue
		if i + 1 >= events.size():
			continue
		var nxt_any = events[i + 1]
		if typeof(nxt_any) != TYPE_DICTIONARY:
			continue
		var cur: Dictionary = cur_any
		var nxt: Dictionary = nxt_any
		if bool(cur.get("rest", false)) or bool(nxt.get("rest", false)):
			continue
		var midi_a: int = int(cur.get("midi", -1))
		var midi_b: int = int(nxt.get("midi", -1))
		if midi_a < 0 or midi_b < 0 or absi(midi_b - midi_a) < 3:
			continue
		if rng.randf() >= density:
			continue
		# Insert a passing tone at the midpoint in pitch and the midpoint in time.
		var cur_off: float = float(cur.get("beat_offset", 0.0))
		var cur_dur: float = float(cur.get("duration_beats", 0.0))
		var nxt_off: float = float(nxt.get("beat_offset", 0.0))
		var half_pitch: int = midi_a + int((midi_b - midi_a) / 2)
		var passing_off: float = cur_off + cur_dur * 0.5
		var passing_dur: float = maxf(0.0625, (nxt_off - passing_off) * 0.5)
		out.append({
			"midi": half_pitch,
			"duration_beats": passing_dur,
			"beat_offset": passing_off,
			"rest": false,
			"ornament": true,
		})
	return out


# Applies a sequence of transforms by name to a motif. Unknown names log a
# warning and are skipped. Used by composers that want to stack a stochastic
# variation recipe like ["retrograde", "invert(4)"] over a base motif.
#
# Names support an optional parenthesised integer argument:
#   "retrograde"           → retrograde(m)
#   "invert(4)"            → invert(m, 4)
#   "contrary_motion(4)"   → contrary_motion(m, 4)
#   "broken_thirds"        → broken_chord_substitute(m, 2)
#   "broken_fifths"        → broken_chord_substitute(m, 4)
#   "octave_shift(-1)"     → octave_shift(m, -1)
#
# `rng` is currently unused by the transforms in this stack; it's accepted so
# stochastic transforms (added later) plug in without changing the signature.
static func apply_stack(motif: Array, names: Array, _rng: RandomNumberGenerator = null) -> Array:
	var cur: Array = motif.duplicate()
	for raw_name in names:
		var name: String = str(raw_name).strip_edges()
		if name.is_empty():
			continue
		var arg: int = 0
		var has_arg: bool = false
		var paren_open: int = name.find("(")
		if paren_open >= 0:
			var paren_close: int = name.find(")", paren_open + 1)
			if paren_close > paren_open:
				arg = int(name.substr(paren_open + 1, paren_close - paren_open - 1))
				has_arg = true
			name = name.substr(0, paren_open)
		match name:
			"retrograde":
				cur = retrograde(cur)
			"invert":
				cur = invert(cur, arg if has_arg else 4)
			"contrary_motion":
				cur = contrary_motion(cur, arg if has_arg else 4)
			"broken_thirds":
				cur = broken_chord_substitute(cur, 2)
			"broken_fifths":
				cur = broken_chord_substitute(cur, 4)
			"broken_chord_substitute":
				cur = broken_chord_substitute(cur, arg if has_arg else 2)
			"octave_shift":
				cur = octave_shift(cur, arg if has_arg else -1)
			_:
				push_warning("[SequenceTransforms.apply_stack] unknown transform: %s" % name)
	return cur
