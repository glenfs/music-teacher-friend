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
	return {
		"passed": passed,
		"failed": failed,
		"failures": failures,
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
	var right: Dictionary = TechnicalExerciseGeneratorScript.generate(
		exercise_id, TEST_KEY_PC, false, TEST_LEVEL, "right", TEST_OCTAVES
	)
	var left: Dictionary = TechnicalExerciseGeneratorScript.generate(
		exercise_id, TEST_KEY_PC, false, TEST_LEVEL, "left", TEST_OCTAVES
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
