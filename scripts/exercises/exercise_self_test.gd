extends RefCounted
class_name ExerciseSelfTest

# Smoke test that walks every entry in ExerciseLibrary and verifies the generator
# produces a valid exercise dict (non-empty notes, correct title, etc.). Used by
# the QA suite (and ad-hoc developer sanity checks) to catch regressions when
# new composers or templates are added.
#
# Returns a Dictionary { "passed": int, "failed": int, "failures": Array[String] }.

const ExerciseLibraryScript = preload("res://scripts/exercises/exercise_library.gd")
const TechnicalExerciseGeneratorScript = preload("res://scripts/exercises/technical_exercise_generator.gd")
const MusicXMLEncoderScript = preload("res://scripts/exercises/musicxml_encoder.gd")
const ExerciseValidatorScript = preload("res://scripts/exercises/exercise_validator.gd")
const DifficultyEstimatorScript = preload("res://scripts/exercises/difficulty_estimator.gd")
const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")
const SequenceTransformsScript = preload("res://scripts/exercises/patterns/sequence_transforms.gd")

# Phase 4 sampler sweep — drives PatternPrimitives.walk_degrees through a set
# of style profiles and asserts (a) every sample respects its constraints and
# (b) the sampler is producing real variety (uniqueness ratio).
const SAMPLER_SAMPLE_COUNT := 1000
const SAMPLER_UNIQUENESS_MIN := 0.05  # at least 5% distinct motifs (tight contour
                                      # rules like alternating_step_skip live in a
                                      # naturally small motif space — that's fine,
                                      # 50+ distinct motifs still yields real variety)

# Style profiles used for the sweep. Phase 6 will add many more once the
# generator composers wire them into the Hanon/Czerny/scale samplers.
const SAMPLER_STYLES := [
	{
		"name": "five_finger",
		"length": 8,
		"start_degree": 1,
		"degree_range": [1, 5],
		"allowed_steps": [-2, -1, 1, 2],
		"contour_rule": "free",
	},
	{
		"name": "alternating_step_skip",
		"length": 8,
		"start_degree": 1,
		"degree_range": [1, 6],
		"allowed_steps": [-3, -2, -1, 1, 2, 3],
		"contour_rule": "alternating_step_skip",
	},
	{
		"name": "ascending_arc",
		"length": 8,
		"start_degree": 1,
		"degree_range": [1, 8],
		"allowed_steps": [-2, -1, 1, 2],
		"contour_rule": "arc",
	},
]

# Levels swept by the validator/estimator regression. Two points are enough to
# detect tempo/octave bumps without ballooning QA runtime.
const VALIDATOR_SWEEP_LEVELS := [1, 7]
const ESTIMATOR_TOLERANCE := 3      # ±3 levels — first-pass acceptance band
const ESTIMATOR_MIN_HIT_RATE := 0.80  # 80% of templates must land in tolerance

# Test parameters — kept simple. We only verify exercises GENERATE, not that the
# output is musically perfect.
const TEST_KEY_PC := 0          # C
const TEST_LEVEL := 3
const TEST_OCTAVES := 1
const TEST_HANDS := ["right", "left"]


static func run() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for id_v in ExerciseLibraryScript.DEFAULT_ORDER:
		var id: String = str(id_v)
		for hand in TEST_HANDS:
			var ok: bool = _test_one(id, hand, failures)
			if ok:
				passed += 1
			else:
				failed += 1
		if bool(ExerciseLibraryScript.entry(id).get("two_hand_friendly", false)):
			if _test_two_hand_alignment(id, failures):
				passed += 1
			else:
				failed += 1
	# Also smoke-test the curriculum generator
	var Curriculum = preload("res://scripts/exercises/curriculum.gd")
	for level in [1, 5, 10]:
		var pick: Dictionary = Curriculum.daily_warmup_pick(level, "all", 42)
		if not pick.has("exercise_id") or str(pick["exercise_id"]).is_empty():
			failures.append("[curriculum] daily_warmup_pick(%d) returned empty pick" % level)
			failed += 1
		else:
			passed += 1
	# Phase 3 regression: validator must accept every canonical template, and the
	# estimator must land within ±N levels of the requested level for >= 80% of
	# samples. Templates ARE the ground truth — tuning happens here, not on the
	# generators that come later.
	var sweep: Dictionary = run_validator_estimator_sweep()
	passed += int(sweep.get("validator_pass", 0))
	failed += int(sweep.get("validator_fail", 0))
	for r in sweep.get("validator_failures", []):
		failures.append("[validator] " + str(r))
	if int(sweep.get("estimator_total", 0)) > 0:
		var hit_rate: float = float(sweep.get("estimator_within_tol", 0)) / float(sweep["estimator_total"])
		if hit_rate < ESTIMATOR_MIN_HIT_RATE:
			failures.append("[estimator] hit rate %.2f below minimum %.2f (band ±%d). See summary in result dict." % [hit_rate, ESTIMATOR_MIN_HIT_RATE, ESTIMATOR_TOLERANCE])
			failed += 1
		else:
			passed += 1
	# Plumbing check: Phase 2 added seed + generator_id fields to every returned
	# exercise dict. Verify they made it through end-to-end on a probe template.
	var probe: Dictionary = TechnicalExerciseGeneratorScript.generate("hanon_1", 0, false, 4, "right", 1, -1, 12345)
	if int(probe.get("seed", -2)) != 12345:
		failures.append("[plumbing] requested seed=12345 did not survive generate() (got %s)" % str(probe.get("seed", "<missing>")))
		failed += 1
	else:
		passed += 1
	if not probe.has("generator_id"):
		failures.append("[plumbing] generator_id field missing from template-path return dict")
		failed += 1
	else:
		passed += 1
	# Phase 4: PatternPrimitives sampler sweep. Every sample must respect its
	# constraint dict, and the sampler must produce real variety per style.
	var sampler: Dictionary = run_sampler_sweep()
	passed += int(sampler.get("passed", 0))
	failed += int(sampler.get("failed", 0))
	for f in sampler.get("failures", []):
		failures.append("[sampler] " + str(f))
	# Phase 5: SequenceTransforms invariants. Each transform must satisfy its
	# documented invariant; apply_stack must be safe with empty / unknown names.
	var transforms: Dictionary = run_transform_sweep()
	passed += int(transforms.get("passed", 0))
	failed += int(transforms.get("failed", 0))
	for f in transforms.get("failures", []):
		failures.append("[transforms] " + str(f))
	# Phase 7: Generator-entry end-to-end sweep. Every generator catalog entry
	# must produce a validator-clean exercise at multiple seeds, and the set of
	# samples must show real variety (not the same fallback every roll).
	var generators: Dictionary = run_generator_sweep()
	passed += int(generators.get("passed", 0))
	failed += int(generators.get("failed", 0))
	for f in generators.get("failures", []):
		failures.append("[generators] " + str(f))
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
		"validator_estimator_sweep": sweep,
		"sampler_sweep": sampler,
		"transform_sweep": transforms,
		"generator_sweep": generators,
	}


# Samples every generator catalog entry across multiple seeds and asserts the
# validator accepts every roll. Also tracks fingerprint uniqueness (first 12
# pitched MIDI values) to verify the samplers are producing real variety and
# not falling back to the same canonical template on every attempt.
const GENERATOR_SAMPLES_PER_ENTRY := 20
# Diversity floor — at least 3 distinct fingerprints per 20 samples. The Hanon
# samplers (true motif walks) comfortably exceed this; the Czerny/Scale
# samplers are constrained by their variant counts (~3-4 forms each) and tend
# to hit the floor exactly. Tightening this is a Phase-6 craft follow-up that
# would mean adding more per-variant variation (stochastic retrograde, tempo
# jitter, etc.) to Czerny/Scale composers.
const GENERATOR_UNIQUE_MIN := 3

static func run_generator_sweep() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	var per_entry: Array = []
	for id_v in ExerciseLibraryScript.DEFAULT_ORDER:
		var id: String = str(id_v)
		if not ExerciseLibraryScript.is_generator(id):
			continue
		var entry: Dictionary = ExerciseLibraryScript.entry(id)
		var min_lvl: int = int(entry.get("min_level", 1))
		var fingerprints: Dictionary = {}
		var bad_count: int = 0
		for i in range(GENERATOR_SAMPLES_PER_ENTRY):
			var ex: Dictionary = TechnicalExerciseGeneratorScript.generate(id, TEST_KEY_PC, false, min_lvl + (i % 3), "right", TEST_OCTAVES, -1, 1000 + i)
			var v: Dictionary = ExerciseValidatorScript.is_valid(ex)
			if not bool(v.get("ok", false)):
				bad_count += 1
				if bad_count <= 2:
					failures.append("%s seed %d: %s" % [id, 1000 + i, str(v.get("reasons", []))])
				continue
			if str(ex.get("generator_id", "")) != id:
				failures.append("%s seed %d: generator_id mismatch (got %s)" % [id, 1000 + i, str(ex.get("generator_id", ""))])
				bad_count += 1
				continue
			fingerprints[_fingerprint(ex)] = true
			passed += 1
		failed += bad_count
		var unique_count: int = fingerprints.size()
		per_entry.append({
			"id": id,
			"samples": GENERATOR_SAMPLES_PER_ENTRY,
			"unique_fingerprints": unique_count,
			"validator_failures": bad_count,
		})
		if unique_count < GENERATOR_UNIQUE_MIN:
			failures.append("%s: only %d distinct samples in %d (min %d) — sampler may be over-falling-back" % [id, unique_count, GENERATOR_SAMPLES_PER_ENTRY, GENERATOR_UNIQUE_MIN])
			failed += 1
		else:
			passed += 1
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
		"per_entry": per_entry,
	}


# Content fingerprint: pitched MIDI values sampled from the start, middle, and
# end of the exercise plus the variant title. The Czerny family otherwise
# shares opening pitches across variants (all begin with a scale run) so a
# first-N-notes fingerprint can't distinguish them — sampling three regions
# discriminates variants and octave choices reliably.
static func _fingerprint(exercise: Dictionary) -> String:
	var pitched: Array = []
	for note_any in exercise.get("notes", []):
		var n: Dictionary = note_any
		if int(n.get("midi", -1)) >= 0 and not bool(n.get("rest", false)):
			pitched.append(int(n["midi"]))
	if pitched.is_empty():
		return "title:" + str(exercise.get("title", ""))
	var parts: PackedStringArray = PackedStringArray()
	# Sample from start, middle, and end.
	var take_from := func(start_idx: int, n: int) -> void:
		for i in range(n):
			var idx: int = start_idx + i
			if idx >= 0 and idx < pitched.size():
				parts.append(str(pitched[idx]))
	take_from.call(0, 6)
	take_from.call(int(pitched.size() / 2) - 3, 6)
	take_from.call(maxi(0, pitched.size() - 6), 6)
	# Include the title — encodes variant choice for Czerny/Scale samplers
	# whose pitch content can coincide across rolls but whose label differs.
	return ",".join(parts) + "|" + str(exercise.get("title", ""))


# Runs PatternPrimitives.walk_degrees / random_motif across each style profile
# and verifies: (1) length matches, (2) degrees stay in range, (3) consecutive
# transitions are in allowed_steps OR a hold (cur→cur, the stalled fallback),
# (4) the set of distinct motifs covers the configured uniqueness floor.
#
# A fixed RNG seed per style keeps this deterministic across runs so QA
# regressions are reproducible.
static func run_sampler_sweep() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	var per_style: Array = []
	for style_v in SAMPLER_STYLES:
		var style: Dictionary = style_v
		var name: String = str(style.get("name", "<unnamed>"))
		var length_expected: int = int(style.get("length", 8))
		var deg_range: Array = style.get("degree_range", [1, 5])
		var lo: int = int(deg_range[0])
		var hi: int = int(deg_range[1])
		var allowed: Array = style.get("allowed_steps", [-2, -1, 1, 2])
		var rng := RandomNumberGenerator.new()
		# Deterministic seed per style: differentiate across styles, stable across runs.
		rng.seed = int(hash(name)) & 0x7fffffff
		var seen: Dictionary = {}
		var sample_failures: int = 0
		for i in range(SAMPLER_SAMPLE_COUNT):
			var motif: Array = PatternPrimitivesScript.walk_degrees(rng, style)
			if motif.size() != length_expected:
				sample_failures += 1
				if sample_failures <= 3:
					failures.append("%s sample %d length %d != %d" % [name, i, motif.size(), length_expected])
				continue
			var ok := true
			for d_idx in range(motif.size()):
				var d: int = int(motif[d_idx])
				if d < lo or d > hi:
					ok = false
					if sample_failures <= 3:
						failures.append("%s sample %d degree %d out of range [%d,%d]" % [name, i, d, lo, hi])
					sample_failures += 1
					break
				if d_idx > 0:
					var step: int = d - int(motif[d_idx - 1])
					# Either a permitted step OR a hold (the constraints-over-tight fallback).
					if step != 0 and not allowed.has(step):
						ok = false
						if sample_failures <= 3:
							failures.append("%s sample %d illegal step %d at index %d" % [name, i, step, d_idx])
						sample_failures += 1
						break
			if ok:
				passed += 1
				seen[str(motif)] = true
			else:
				failed += 1
		var uniqueness: float = float(seen.size()) / float(SAMPLER_SAMPLE_COUNT)
		per_style.append({
			"name": name,
			"distinct_motifs": seen.size(),
			"uniqueness": uniqueness,
		})
		if uniqueness < SAMPLER_UNIQUENESS_MIN:
			failures.append("%s uniqueness %.3f below floor %.3f (%d distinct of %d)" % [name, uniqueness, SAMPLER_UNIQUENESS_MIN, seen.size(), SAMPLER_SAMPLE_COUNT])
			failed += 1
		else:
			passed += 1
	# random_motif end-to-end smoke: ensure it returns degrees + fingering of equal length.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var motif_dict: Dictionary = PatternPrimitivesScript.random_motif(rng2, SAMPLER_STYLES[0])
	var degs: Array = motif_dict.get("degrees", [])
	var fingers: Array = motif_dict.get("fingering", [])
	if degs.size() != fingers.size() or degs.is_empty():
		failures.append("random_motif: degrees(%d) vs fingering(%d) mismatch" % [degs.size(), fingers.size()])
		failed += 1
	else:
		passed += 1
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
		"per_style": per_style,
	}


# Asserts the Phase-5 transform invariants. Each transform has one or two
# properties that must always hold; if any fails, the composer code that builds
# on these transforms can't be trusted.
static func run_transform_sweep() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	# Sample motifs to exercise the transforms with. The Hanon-1 motif gives us
	# a known-good real-world shape; a longer asymmetric one stresses edge cases.
	var motifs: Array = [
		[1, 3, 4, 5, 6, 5, 4, 3],
		[2, 4, 1, 5, 3, 7, 2, 6, 1],
		[5, 5, 5, 5],
	]

	# --- retrograde: involution (applying twice yields the original). ---
	for m_v in motifs:
		var m: Array = m_v
		var rr: Array = SequenceTransformsScript.retrograde(SequenceTransformsScript.retrograde(m))
		if rr != m:
			failures.append("retrograde not involutive on %s (got %s)" % [str(m), str(rr)])
			failed += 1
		else:
			passed += 1

	# --- invert: involution around the same axis. ---
	for m_v2 in motifs:
		var m2: Array = m_v2
		var ii: Array = SequenceTransformsScript.invert(SequenceTransformsScript.invert(m2, 4), 4)
		if ii != m2:
			failures.append("invert not involutive around axis 4 on %s (got %s)" % [str(m2), str(ii)])
			failed += 1
		else:
			passed += 1

	# --- contrary_motion is an alias of invert. ---
	for m_v3 in motifs:
		var m3: Array = m_v3
		var a: Array = SequenceTransformsScript.contrary_motion(m3, 4)
		var b: Array = SequenceTransformsScript.invert(m3, 4)
		if a != b:
			failures.append("contrary_motion not alias of invert on %s" % str(m3))
			failed += 1
		else:
			passed += 1

	# --- octave_shift: every element shifts by 12 * octaves; length preserved. ---
	var pitches: Array = [60, 62, 64, 65, 67]
	var shifted: Array = SequenceTransformsScript.octave_shift(pitches, -1)
	if shifted.size() != pitches.size():
		failures.append("octave_shift changed length (%d → %d)" % [pitches.size(), shifted.size()])
		failed += 1
	else:
		var ok: bool = true
		for i in range(pitches.size()):
			if int(shifted[i]) != int(pitches[i]) - 12:
				ok = false
				break
		if ok:
			passed += 1
		else:
			failures.append("octave_shift(-1) did not uniformly subtract 12")
			failed += 1

	# --- rhythmic_augment: scales duration_beats AND beat_offset by factor. ---
	var events: Array = [
		{"midi": 60, "duration_beats": 0.5, "beat_offset": 0.0, "rest": false},
		{"midi": 62, "duration_beats": 0.5, "beat_offset": 0.5, "rest": false},
		{"midi": -1, "duration_beats": 1.0, "beat_offset": 1.0, "rest": true},
	]
	var augmented: Array = SequenceTransformsScript.rhythmic_augment(events, 2.0)
	if augmented.size() != events.size():
		failures.append("rhythmic_augment changed event count")
		failed += 1
	else:
		var scaled_ok: bool = true
		for i in range(events.size()):
			var src: Dictionary = events[i]
			var dst: Dictionary = augmented[i]
			if absf(float(dst["duration_beats"]) - float(src["duration_beats"]) * 2.0) > 1e-6:
				scaled_ok = false; break
			if absf(float(dst["beat_offset"]) - float(src["beat_offset"]) * 2.0) > 1e-6:
				scaled_ok = false; break
		if scaled_ok:
			passed += 1
		else:
			failures.append("rhythmic_augment did not scale duration/offset by factor")
			failed += 1

	# --- broken_chord_substitute: doubles length; every other element is d+interval. ---
	var broken: Array = SequenceTransformsScript.broken_chord_substitute([1, 2, 3, 4], 2)
	if broken.size() != 8:
		failures.append("broken_chord_substitute did not double length (got %d)" % broken.size())
		failed += 1
	else:
		var bok: bool = true
		var src_arr: Array = [1, 2, 3, 4]
		for i in range(src_arr.size()):
			if int(broken[i * 2]) != int(src_arr[i]) or int(broken[i * 2 + 1]) != int(src_arr[i]) + 2:
				bok = false; break
		if bok:
			passed += 1
		else:
			failures.append("broken_chord_substitute did not produce [d, d+2] pairs")
			failed += 1

	# --- ornament_passing_tones: density=0 leaves events unchanged. ---
	var rng_orn := RandomNumberGenerator.new()
	rng_orn.seed = 7
	var orn0: Array = SequenceTransformsScript.ornament_passing_tones(events, 0.0, rng_orn)
	if orn0.size() != events.size():
		failures.append("ornament density=0 changed event count (%d → %d)" % [events.size(), orn0.size()])
		failed += 1
	else:
		passed += 1
	# density=1 with a gap >= 3 semitones must insert at least one passing tone.
	var leap_events: Array = [
		{"midi": 60, "duration_beats": 1.0, "beat_offset": 0.0, "rest": false},
		{"midi": 67, "duration_beats": 1.0, "beat_offset": 1.0, "rest": false},
	]
	var orn1: Array = SequenceTransformsScript.ornament_passing_tones(leap_events, 1.0, rng_orn)
	if orn1.size() <= leap_events.size():
		failures.append("ornament density=1 over a 7-semitone gap inserted no passing tone")
		failed += 1
	else:
		passed += 1

	# --- apply_stack: identity cases and round-trip cases. ---
	var ident: Array = SequenceTransformsScript.apply_stack([1, 2, 3], [], null)
	if ident != [1, 2, 3]:
		failures.append("apply_stack with empty names did not return identity")
		failed += 1
	else:
		passed += 1
	var rr_stack: Array = SequenceTransformsScript.apply_stack([1, 2, 3, 4], ["retrograde", "retrograde"], null)
	if rr_stack != [1, 2, 3, 4]:
		failures.append("apply_stack [retrograde, retrograde] not identity (got %s)" % str(rr_stack))
		failed += 1
	else:
		passed += 1
	var ii_stack: Array = SequenceTransformsScript.apply_stack([1, 3, 5], ["invert(4)", "invert(4)"], null)
	if ii_stack != [1, 3, 5]:
		failures.append("apply_stack [invert(4), invert(4)] not identity (got %s)" % str(ii_stack))
		failed += 1
	else:
		passed += 1
	# Unknown transform name must NOT crash (warns + skips).
	var unknown_stack: Array = SequenceTransformsScript.apply_stack([1, 2, 3], ["nope", "retrograde"], null)
	if unknown_stack != [3, 2, 1]:
		failures.append("apply_stack with unknown then retrograde produced %s, expected [3,2,1]" % str(unknown_stack))
		failed += 1
	else:
		passed += 1
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
	}


# Sweeps every canonical template at the levels in VALIDATOR_SWEEP_LEVELS, runs
# each through the validator (must pass) and the estimator (delta vs requested
# level tracked). Returns a dict with counters + a per-entry summary that the
# QA report can dump for tuning.
static func run_validator_estimator_sweep() -> Dictionary:
	var validator_pass: int = 0
	var validator_fail: int = 0
	var validator_failures: Array[String] = []
	var estimator_total: int = 0
	var estimator_within: int = 0
	var summary: Array = []
	for id_v in ExerciseLibraryScript.DEFAULT_ORDER:
		var id: String = str(id_v)
		# Only sweep templates — generator entries (Phase 7+) get their own sweep
		# inside their composer once they land.
		if ExerciseLibraryScript.is_generator(id):
			continue
		for level in VALIDATOR_SWEEP_LEVELS:
			var ex: Dictionary = TechnicalExerciseGeneratorScript.generate(id, TEST_KEY_PC, false, int(level), "right", TEST_OCTAVES)
			var result: Dictionary = ExerciseValidatorScript.is_valid(ex)
			var ok: bool = bool(result.get("ok", false))
			if ok:
				validator_pass += 1
			else:
				validator_fail += 1
				for r in result.get("reasons", []):
					validator_failures.append("%s @L%d: %s" % [id, int(level), str(r)])
			var features: Dictionary = result.get("features", {})
			var est_level: int = DifficultyEstimatorScript.estimate_level(ex, features)
			estimator_total += 1
			var delta: int = absi(est_level - int(level))
			if delta <= ESTIMATOR_TOLERANCE:
				estimator_within += 1
			summary.append({
				"id": id,
				"requested_level": int(level),
				"estimated_level": est_level,
				"delta": delta,
				"validator_ok": ok,
				"features": features,
			})
	return {
		"validator_pass": validator_pass,
		"validator_fail": validator_fail,
		"validator_failures": validator_failures,
		"estimator_total": estimator_total,
		"estimator_within_tol": estimator_within,
		"tolerance": ESTIMATOR_TOLERANCE,
		"summary": summary,
	}


static func _test_one(exercise_id: String, hand: String, failures: Array[String]) -> bool:
	var ex: Dictionary = TechnicalExerciseGeneratorScript.generate(
		exercise_id, TEST_KEY_PC, false, TEST_LEVEL, hand, TEST_OCTAVES
	)
	if ex.is_empty():
		failures.append("[%s/%s] generator returned empty dict" % [exercise_id, hand])
		return false
	var notes: Array = ex.get("notes", [])
	if notes.is_empty():
		failures.append("[%s/%s] generated zero notes" % [exercise_id, hand])
		return false
	var has_pitched: bool = false
	for n in notes:
		var midi: int = int(n.get("midi", -1))
		if midi >= 0 and midi <= 127 and not bool(n.get("rest", false)):
			has_pitched = true
			break
	if not has_pitched:
		failures.append("[%s/%s] all notes are rests" % [exercise_id, hand])
		return false
	# Verify MusicXML encoder accepts the output without raising
	var xml: String = MusicXMLEncoderScript.encode(ex)
	if xml.is_empty() or not xml.contains("score-partwise"):
		failures.append("[%s/%s] MusicXML encoding produced invalid output" % [exercise_id, hand])
		return false
	return true


static func _test_two_hand_alignment(exercise_id: String, failures: Array[String]) -> bool:
	# For generator entries the variant choice depends on the RNG seed, so pass
	# the SAME deterministic seed for both hands — otherwise RH might roll a
	# chromatic scale while LH rolls thirds and the lengths legitimately differ.
	# Templates ignore the seed; the field is harmless for them.
	var paired_seed: int = int(hash(exercise_id)) & 0x7fffffff
	var right: Dictionary = TechnicalExerciseGeneratorScript.generate(
		exercise_id, TEST_KEY_PC, false, TEST_LEVEL, "right", TEST_OCTAVES, -1, paired_seed
	)
	var left: Dictionary = TechnicalExerciseGeneratorScript.generate(
		exercise_id, TEST_KEY_PC, false, TEST_LEVEL, "left", TEST_OCTAVES, -1, paired_seed
	)
	if right.is_empty() or left.is_empty():
		failures.append("[%s/grand] one hand generated an empty dict" % exercise_id)
		return false
	var right_beats := _notes_total_beats(right.get("notes", []))
	var left_beats := _notes_total_beats(left.get("notes", []))
	if absf(right_beats - left_beats) > 0.001:
		failures.append("[%s/grand] RH total %.3f beats != LH total %.3f beats" % [exercise_id, right_beats, left_beats])
		return false
	return true


static func _notes_total_beats(notes: Array) -> float:
	var total := 0.0
	for note_any in notes:
		var note: Dictionary = note_any
		total = maxf(total, float(note.get("beat_offset", 0.0)) + float(note.get("duration_beats", 0.0)))
	return total
