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

	# max_jump precedence: explicit opts override > exercise-declared tolerance >
	# default. Stride/leaping-bass idioms legitimately exceed the melodic default,
	# so those composers declare their own "max_jump" on the exercise dict.
	var max_jump: int = int(opts.get("max_jump", int(exercise.get("max_jump", MAX_JUMP_SEMITONES_DEFAULT))))
	var max_span: int = int(opts.get("max_span", MAX_HAND_SPAN_DEFAULT))
	var min_dur: float = float(opts.get("min_duration_beats", MIN_DURATION_BEATS_DEFAULT))
	var max_dur: float = float(opts.get("max_duration_beats", MAX_DURATION_BEATS_DEFAULT))

	var reasons: Array[String] = []
	var last_offset: float = -1e9
	var pitched_count: int = 0
	# Per-staff pitch tracking. Staves: 1=treble/RH, 2=bass/LH. Notes without a
	# staff field bucket into staff 0 (single-hand exercises).
	var staff_pitches: Dictionary = {}
	var staff_offsets: Dictionary = {}
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
			staff_offsets[staff] = []
		(staff_pitches[staff] as Array).append(midi)
		(staff_offsets[staff] as Array).append(off)

	if pitched_count == 0:
		reasons.append("no pitched notes (all rests)")

	# Per-staff melodic jump check — CHORD-AWARE. Notes that share a beat_offset
	# form a block chord; collapse each chord to its bass voice (lowest note) and
	# measure motion between consecutive beat-groups. This stops a block-chord
	# shape change (top of one chord → bottom of the next) from being mis-counted
	# as a melodic leap. For single-note lines every group has one note, so this
	# is identical to a plain note-to-note check.
	for staff_v in staff_pitches.keys():
		var staff_j: int = int(staff_v)
		var midis: Array = staff_pitches[staff_j]
		var offs: Array = staff_offsets.get(staff_j, [])
		var group_low: int = 1 << 30
		var group_off: float = 0.0
		var prev_group_low: int = -1
		var have_group: bool = false
		for i in range(midis.size()):
			var m: int = int(midis[i])
			var o: float = float(offs[i]) if i < offs.size() else 0.0
			if not have_group:
				group_off = o
				group_low = m
				have_group = true
			elif absf(o - group_off) <= 1e-6:
				group_low = mini(group_low, m)
			else:
				if prev_group_low >= 0:
					var jmp: int = absi(group_low - prev_group_low)
					observed_jump = maxi(observed_jump, jmp)
					staff_max_jump[staff_j] = maxi(int(staff_max_jump.get(staff_j, 0)), jmp)
					if jmp > max_jump:
						reasons.append("staff %d: jump of %d semitones at beat %.3f (max %d)" % [staff_j, jmp, group_off, max_jump])
				prev_group_low = group_low
				group_off = o
				group_low = m
		if have_group and prev_group_low >= 0:
			var jmp2: int = absi(group_low - prev_group_low)
			observed_jump = maxi(observed_jump, jmp2)
			staff_max_jump[staff_j] = maxi(int(staff_max_jump.get(staff_j, 0)), jmp2)
			if jmp2 > max_jump:
				reasons.append("staff %d: jump of %d semitones at beat %.3f (max %d)" % [staff_j, jmp2, group_off, max_jump])

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


# Left-hand fingering sanity check (CONTRACT).
#
# Catches the recurring class of bug where a composer ships a left-hand
# exercise with right-hand fingering patterns (1 on the lowest note,
# climbing to 5 on the highest). The piano LH is geometrically mirrored —
# pinky (5) belongs on the lowest note, thumb (1) on the highest. Any
# LH exercise where the LOWEST fingered note is fingered 1 is almost
# certainly wrong (the only legit case is a passage that starts mid-run
# with the thumb coming off a cross-under, which is rare and should be
# explicitly opted in via the `lh_fingering_starts_with_thumb` exercise
# flag).
#
# Returns: Array of human-readable warnings (empty == clean). Composers
# can call this in their self-tests; QA harness picks it up via
# exercise_self_test.gd.
static func validate_left_hand_fingering(exercise: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	if typeof(exercise) != TYPE_DICTIONARY:
		return warnings
	var hand_v: Variant = exercise.get("hand", "")
	if str(hand_v) != "left":
		# Grand-staff exercises split into per-hand caches — check the
		# left_hand_notes array if present.
		var lh_notes_v: Variant = exercise.get("left_hand_notes", null)
		if not (lh_notes_v is Array):
			return warnings
		return _validate_lh_notes(lh_notes_v as Array, exercise)
	return _validate_lh_notes(exercise.get("notes", []) as Array, exercise)


static func _validate_lh_notes(notes: Array, exercise: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	if bool(exercise.get("lh_fingering_starts_with_thumb", false)):
		return warnings
	# Find the lowest fingered note.
	var lowest_midi: int = 999
	var lowest_finger: int = -1
	var any_fingering: bool = false
	for note_any in notes:
		var note: Dictionary = note_any
		var midi: int = int(note.get("midi", -1))
		if midi < 0 or bool(note.get("rest", false)):
			continue
		var f: int = int(note.get("fingering", 0))
		if f <= 0:
			continue
		any_fingering = true
		if midi < lowest_midi:
			lowest_midi = midi
			lowest_finger = f
	if not any_fingering:
		return warnings  # No fingerings emitted — nothing to validate.
	if lowest_finger == 1:
		warnings.append(
			"Suspicious LH fingering: lowest note (MIDI %d) is fingered with thumb (1). " %
			lowest_midi + "Left hand normally puts the pinky (5) on the lowest note. " +
			"Did you route the pattern through FingeringRules.apply_fingering_pattern with hand=\"left\"?"
		)
	return warnings


# Internal: derives total beats from the highest beat_offset + duration_beats.
static func _computed_total_beats(notes: Array) -> float:
	var total: float = 0.0
	for note_any in notes:
		if typeof(note_any) != TYPE_DICTIONARY:
			continue
		var note: Dictionary = note_any
		total = maxf(total, float(note.get("beat_offset", 0.0)) + float(note.get("duration_beats", 0.0)))
	return total
