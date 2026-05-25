extends RefCounted
class_name ExerciseValidator

# Pure validator over the exercise dict shape produced by TechnicalExerciseGenerator.
# Generators (Phase 6+) will call this on every sample they produce and resample
# on failure, so the rules here are the contract for "playable/pedagogically
# sensible". Canonical templates must all pass these checks — they are the
# regression fixtures (see exercise_self_test.gd).
#
# Returns:
#   { "ok": bool, "reasons": Array[String], "features": Dictionary }
#
# `features` is a small computed summary used both for diagnostics and (later)
# by the difficulty estimator, so we don't walk the notes list twice.

# --- Default thresholds. Override per call via opts dict. ---
const MAX_JUMP_SEMITONES_DEFAULT := 14   # M9 — generous: covers octave + step at scale-boundary
const MAX_HAND_SPAN_DEFAULT := 48        # 4 octaves — fits the canonical 3-octave scales w/ headroom
const MIN_DURATION_BEATS_DEFAULT := 0.0625  # 32nd note at 4/4
const MAX_DURATION_BEATS_DEFAULT := 8.0      # double whole; pedagogical drills never need more


# Top-level entry: returns ok/reasons + a features dict the estimator can reuse.
static func is_valid(exercise: Dictionary, opts: Dictionary = {}) -> Dictionary:
	if typeof(exercise) != TYPE_DICTIONARY or exercise.is_empty():
		return {"ok": false, "reasons": ["empty or non-dict exercise"], "features": {}}
	var notes: Array = exercise.get("notes", [])
	if notes.is_empty():
		return {"ok": false, "reasons": ["zero notes"], "features": {}}

	var max_jump: int = int(opts.get("max_jump", MAX_JUMP_SEMITONES_DEFAULT))
	var max_span: int = int(opts.get("max_span", MAX_HAND_SPAN_DEFAULT))
	var min_dur: float = float(opts.get("min_duration_beats", MIN_DURATION_BEATS_DEFAULT))
	var max_dur: float = float(opts.get("max_duration_beats", MAX_DURATION_BEATS_DEFAULT))

	var reasons: Array[String] = []
	var last_offset: float = -1e9
	var pitched_count: int = 0
	# Per-staff pitch tracking. Staves: 1=treble/RH, 2=bass/LH. Notes without a
	# staff field bucket into staff 0 (single-hand exercises).
	var staff_pitches: Dictionary = {}
	var staff_last_midi: Dictionary = {}
	var staff_max_jump: Dictionary = {}
	var observed_jump: int = 0

	for note_any in notes:
		if typeof(note_any) != TYPE_DICTIONARY:
			reasons.append("non-dict note encountered")
			continue
		var note: Dictionary = note_any
		var dur: float = float(note.get("duration_beats", 0.0))
		var off: float = float(note.get("beat_offset", 0.0))
		if dur <= 0.0:
			reasons.append("non-positive duration at beat %.3f" % off)
		elif dur < min_dur - 1e-6:
			reasons.append("duration %.4f below minimum %.4f at beat %.3f" % [dur, min_dur, off])
		elif dur > max_dur:
			reasons.append("duration %.4f exceeds maximum %.4f at beat %.3f" % [dur, max_dur, off])
		if off + 1e-6 < last_offset:
			reasons.append("non-monotonic beat_offset %.3f (after %.3f)" % [off, last_offset])
		last_offset = maxf(last_offset, off)
		if bool(note.get("rest", false)):
			continue
		var midi: int = int(note.get("midi", -1))
		if midi < 0:
			continue  # treat as implicit rest
		if midi > 127:
			reasons.append("midi %d out of range at beat %.3f" % [midi, off])
			continue
		pitched_count += 1
		var staff: int = int(note.get("staff", 0))
		if not staff_pitches.has(staff):
			staff_pitches[staff] = []
		(staff_pitches[staff] as Array).append(midi)
		if staff_last_midi.has(staff):
			var jump: int = absi(midi - int(staff_last_midi[staff]))
			observed_jump = maxi(observed_jump, jump)
			staff_max_jump[staff] = maxi(int(staff_max_jump.get(staff, 0)), jump)
			if jump > max_jump:
				reasons.append("staff %d: jump of %d semitones at beat %.3f (max %d)" % [staff, jump, off, max_jump])
		staff_last_midi[staff] = midi

	if pitched_count == 0:
		reasons.append("no pitched notes (all rests)")

	# Per-staff span check.
	var observed_span: int = 0
	for staff_v in staff_pitches.keys():
		var staff: int = int(staff_v)
		var arr: Array = staff_pitches[staff]
		if arr.size() < 2:
			continue
		var lo: int = 200
		var hi: int = -1
		for m in arr:
			lo = mini(lo, int(m))
			hi = maxi(hi, int(m))
		var span: int = hi - lo
		observed_span = maxi(observed_span, span)
		if span > max_span:
			reasons.append("staff %d span %d semitones exceeds max %d" % [staff, span, max_span])

	# Total-beats consistency: the dict carries total_beats, which should match
	# the highest note end-time. Mismatches are warnings (still a "fail" reason
	# so generators don't ship inconsistent dicts).
	var declared_total: float = float(exercise.get("total_beats", -1.0))
	if declared_total > 0.0:
		var computed_total: float = _computed_total_beats(notes)
		if absf(declared_total - computed_total) > 0.5:
			reasons.append("total_beats %.3f disagrees with notes end %.3f" % [declared_total, computed_total])

	var features := {
		"pitched_count": pitched_count,
		"max_jump": observed_jump,
		"span": observed_span,
		"per_staff_max_jump": staff_max_jump,
		"total_beats": declared_total if declared_total > 0.0 else _computed_total_beats(notes),
		"tempo_bpm": int(exercise.get("tempo_bpm", 60)),
		"fifths": int(exercise.get("fifths", 0)),
	}
	return {"ok": reasons.is_empty(), "reasons": reasons, "features": features}


# Convenience for callers that only want the boolean answer.
static func ok(exercise: Dictionary, opts: Dictionary = {}) -> bool:
	return bool(is_valid(exercise, opts).get("ok", false))


# Internal: derives total beats from the highest beat_offset + duration_beats.
static func _computed_total_beats(notes: Array) -> float:
	var total: float = 0.0
	for note_any in notes:
		if typeof(note_any) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = note_any
		total = maxf(total, float(note.get("beat_offset", 0.0)) + float(note.get("duration_beats", 0.0)))
	return total
