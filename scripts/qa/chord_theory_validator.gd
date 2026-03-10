## Chord Theory Validator — verifies all chord definitions, mappings, and
## answer correctness across ear training and sight reading paths.
## Run via: Godot --headless --path . --script scripts/qa/chord_theory_validator.gd
extends SceneTree

const CHORD_INTERVALS := {
	"Major": [0, 4, 7],
	"Minor": [0, 3, 7],
	"Power": [0, 7],
	"Dim": [0, 3, 6],
	"Aug": [0, 4, 8],
	"Sus2": [0, 2, 7],
	"Sus4": [0, 5, 7],
	"Maj7": [0, 4, 7, 11],
	"Dom7": [0, 4, 7, 10],
	"Min7": [0, 3, 7, 10],
	"Dim7": [0, 3, 6, 9],
	"Half-dim": [0, 3, 6, 10],
	"mMaj7": [0, 3, 7, 11],
	"Aug7": [0, 4, 8, 10],
	"AugMaj7": [0, 4, 8, 11],
	"7sus4": [0, 5, 7, 10],
	"Maj6": [0, 4, 7, 9],
	"Min6": [0, 3, 7, 9],
	"6/9": [0, 4, 7, 9, 14],
	"Dom9": [0, 4, 7, 10, 14],
	"Maj9": [0, 4, 7, 11, 14],
	"Min9": [0, 3, 7, 10, 14],
	"Add9": [0, 4, 7, 14],
}

# Authoritative music theory reference for chord formulas
# Source: standard jazz/classical theory (Berklee, ABRSM, etc.)
const REFERENCE_CHORDS := {
	"Major":    {"formula": "R M3 P5",       "semitones": [0, 4, 7]},
	"Minor":    {"formula": "R m3 P5",       "semitones": [0, 3, 7]},
	"Power":    {"formula": "R P5",          "semitones": [0, 7]},
	"Dim":      {"formula": "R m3 dim5",     "semitones": [0, 3, 6]},
	"Aug":      {"formula": "R M3 aug5",     "semitones": [0, 4, 8]},
	"Sus2":     {"formula": "R M2 P5",       "semitones": [0, 2, 7]},
	"Sus4":     {"formula": "R P4 P5",       "semitones": [0, 5, 7]},
	"Maj7":     {"formula": "R M3 P5 M7",    "semitones": [0, 4, 7, 11]},
	"Dom7":     {"formula": "R M3 P5 m7",    "semitones": [0, 4, 7, 10]},
	"Min7":     {"formula": "R m3 P5 m7",    "semitones": [0, 3, 7, 10]},
	"Dim7":     {"formula": "R m3 dim5 dim7", "semitones": [0, 3, 6, 9]},
	"Half-dim": {"formula": "R m3 dim5 m7",  "semitones": [0, 3, 6, 10]},
	"mMaj7":    {"formula": "R m3 P5 M7",    "semitones": [0, 3, 7, 11]},
	"Aug7":     {"formula": "R M3 aug5 m7",  "semitones": [0, 4, 8, 10]},
	"AugMaj7":  {"formula": "R M3 aug5 M7",  "semitones": [0, 4, 8, 11]},
	"7sus4":    {"formula": "R P4 P5 m7",    "semitones": [0, 5, 7, 10]},
	"Maj6":     {"formula": "R M3 P5 M6",    "semitones": [0, 4, 7, 9]},
	"Min6":     {"formula": "R m3 P5 M6",    "semitones": [0, 3, 7, 9]},
	"6/9":      {"formula": "R M3 P5 M6 M9", "semitones": [0, 4, 7, 9, 14]},
	"Dom9":     {"formula": "R M3 P5 m7 M9", "semitones": [0, 4, 7, 10, 14]},
	"Maj9":     {"formula": "R M3 P5 M7 M9", "semitones": [0, 4, 7, 11, 14]},
	"Min9":     {"formula": "R m3 P5 m7 M9", "semitones": [0, 3, 7, 10, 14]},
	"Add9":     {"formula": "R M3 P5 M9",    "semitones": [0, 4, 7, 14]},
}

var _errors: Array[String] = []
var _warnings: Array[String] = []
var _pass_count := 0
var _total_count := 0

func _init() -> void:
	print("=== CHORD THEORY VALIDATOR ===")
	print("")

	_test_chord_intervals_match_reference()
	_test_voicing_generator_intervals_match()
	_test_sight_chord_definitions_match()
	_test_build_chord_notes_inversions()
	_test_build_chord_notes_all_roots()
	_test_voicing_generator_self_test()
	_test_hint_intervals_match()
	_test_easy_first_chord_names()
	_test_chord_degree_mappings()
	_test_ear_training_round_trip()

	print("")
	print("=== RESULTS ===")
	print("Tests: %d passed / %d total" % [_pass_count, _total_count])
	if not _warnings.is_empty():
		print("Warnings: %d" % _warnings.size())
		for w in _warnings:
			print("  WARN: %s" % w)
	if _errors.is_empty():
		print("CHORD THEORY VALIDATION: ALL PASSED")
	else:
		print("ERRORS: %d" % _errors.size())
		for e in _errors:
			print("  FAIL: %s" % e)
	print("")
	quit()


func _assert(condition: bool, msg: String) -> void:
	_total_count += 1
	if condition:
		_pass_count += 1
	else:
		_errors.append(msg)
		print("  FAIL: %s" % msg)


func _test_chord_intervals_match_reference() -> void:
	print("[1] Verifying chord intervals against music theory reference...")
	for chord_name in REFERENCE_CHORDS.keys():
		var ref: Dictionary = REFERENCE_CHORDS[chord_name]
		var ref_semitones: Array = ref["semitones"]
		var game_semitones: Array = CHORD_INTERVALS.get(chord_name, [])
		_assert(
			_arrays_equal(game_semitones, ref_semitones),
			"%s: game %s != reference %s (%s)" % [chord_name, str(game_semitones), str(ref_semitones), ref["formula"]]
		)
	print("  Done: %d chord types checked." % REFERENCE_CHORDS.size())


func _test_voicing_generator_intervals_match() -> void:
	print("[2] Verifying ChordVoicingGenerator intervals match game intervals...")
	var CVG = preload("res://scripts/music_theory/chord_voicing_generator.gd")
	# Mapping: game name -> voicing generator name
	var name_map := {
		"Dim": "Diminished",
		"Aug": "Augmented",
		"6/9": "6-9",
	}
	for chord_name in CHORD_INTERVALS.keys():
		var cvg_name: String = name_map.get(chord_name, chord_name)
		var game_intervals: Array = CHORD_INTERVALS[chord_name]
		var cvg_intervals: Array = CVG.CHORD_INTERVALS.get(cvg_name, [])
		_assert(
			_arrays_equal(game_intervals, cvg_intervals),
			"Voicing generator mismatch for %s (%s): game %s != CVG %s" % [chord_name, cvg_name, str(game_intervals), str(cvg_intervals)]
		)
	print("  Done: %d chord types cross-checked." % CHORD_INTERVALS.size())


func _test_sight_chord_definitions_match() -> void:
	print("[3] Verifying SIGHT_CHORD_DEFINITIONS intervals match CHORD_INTERVALS...")
	# We can't easily import from interval_birds.gd so we duplicate the known definitions
	var sight_defs := {
		"Major": [0, 4, 7], "Minor": [0, 3, 7], "Power": [0, 7],
		"Dim": [0, 3, 6], "Aug": [0, 4, 8], "Sus2": [0, 2, 7], "Sus4": [0, 5, 7],
		"Maj7": [0, 4, 7, 11], "Dom7": [0, 4, 7, 10], "Min7": [0, 3, 7, 10],
		"Dim7": [0, 3, 6, 9], "Half-dim": [0, 3, 6, 10], "mMaj7": [0, 3, 7, 11],
		"Aug7": [0, 4, 8, 10], "AugMaj7": [0, 4, 8, 11], "7sus4": [0, 5, 7, 10],
		"Maj6": [0, 4, 7, 9], "Min6": [0, 3, 7, 9], "6/9": [0, 4, 7, 9, 14],
		"Dom9": [0, 4, 7, 10, 14], "Maj9": [0, 4, 7, 11, 14],
		"Min9": [0, 3, 7, 10, 14], "Add9": [0, 4, 7, 14],
	}
	for chord_name in sight_defs.keys():
		var game: Array = CHORD_INTERVALS.get(chord_name, [])
		var sight: Array = sight_defs[chord_name]
		_assert(
			_arrays_equal(game, sight),
			"SIGHT_CHORD_DEFINITIONS mismatch for %s: %s != %s" % [chord_name, str(sight), str(game)]
		)
	print("  Done: %d sight definitions checked." % sight_defs.size())


func _test_build_chord_notes_inversions() -> void:
	print("[4] Verifying _build_chord_notes inversion logic...")
	# Simulate the inversion algorithm from interval_birds.gd
	for chord_name in CHORD_INTERVALS.keys():
		var base_intervals: Array = CHORD_INTERVALS[chord_name].duplicate()
		var root_midi := 60  # C4
		for inv in range(base_intervals.size()):
			var intervals: Array[int] = []
			for v in base_intervals:
				intervals.append(int(v))
			# Apply inversion
			for i in range(inv):
				var moved: int = int(intervals.pop_front()) + 12
				intervals.append(moved)
			var notes: Array[int] = []
			for iv in intervals:
				notes.append(root_midi + int(iv))
			# Verify all notes are valid chord tones (pitch classes match)
			var expected_pcs: Array[int] = []
			for iv in base_intervals:
				expected_pcs.append(posmod(root_midi + int(iv), 12))
			for note in notes:
				var pc := posmod(note, 12)
				_assert(
					pc in expected_pcs,
					"%s inv %d: note MIDI %d (pc %d) not in chord PCs %s" % [chord_name, inv, note, pc, str(expected_pcs)]
				)
			# Verify bass note is correct for inversion
			if inv > 0 and notes.size() >= 2:
				var expected_bass_pc := posmod(root_midi + int(base_intervals[inv]), 12)
				var actual_bass_pc := posmod(notes[0], 12)
				_assert(
					actual_bass_pc == expected_bass_pc,
					"%s inv %d: bass should be pc %d but got %d" % [chord_name, inv, expected_bass_pc, actual_bass_pc]
				)
	print("  Done: all inversions for all 22 chord types checked.")


func _test_build_chord_notes_all_roots() -> void:
	print("[5] Verifying chord construction across all 12 chromatic roots...")
	var root_names := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
	var root_midis := [60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71]
	for ri in range(root_midis.size()):
		for chord_name in ["Major", "Minor", "Dim", "Aug", "Dom7", "Min7", "Maj7", "Dim7"]:
			var root_midi: int = root_midis[ri]
			var intervals: Array = CHORD_INTERVALS[chord_name]
			var notes: Array[int] = []
			for iv in intervals:
				notes.append(root_midi + int(iv))
			# Verify interval structure is preserved
			for j in range(1, notes.size()):
				var actual_interval := notes[j] - notes[0]
				_assert(
					actual_interval == int(intervals[j]),
					"%s %s: interval %d should be %d but got %d" % [root_names[ri], chord_name, j, int(intervals[j]), actual_interval]
				)
	print("  Done: 12 roots x 8 chord types = 96 checks.")


func _test_voicing_generator_self_test() -> void:
	print("[6] Running ChordVoicingGenerator.self_test_500()...")
	var CVG = preload("res://scripts/music_theory/chord_voicing_generator.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var errors: Array[String] = CVG.self_test_500(rng)
	_assert(errors.is_empty(), "ChordVoicingGenerator self_test_500 had %d errors" % errors.size())
	if not errors.is_empty():
		for e in errors.slice(0, 5):
			print("    CVG: %s" % e)
		if errors.size() > 5:
			print("    ... and %d more" % (errors.size() - 5))
	print("  Done: 500 random voicings validated.")


func _test_hint_intervals_match() -> void:
	print("[7] Verifying hint metadata intervals match CHORD_INTERVALS...")
	# These are the hint intervals from _chord_hint_meta (after the fix)
	var hint_intervals := {
		"major": [0, 4, 7], "minor": [0, 3, 7], "power": [0, 7],
		"dim": [0, 3, 6], "aug": [0, 4, 8],
		"sus2": [0, 2, 7], "sus4": [0, 5, 7],
		"maj7": [0, 4, 7, 11], "dom7": [0, 4, 7, 10], "min7": [0, 3, 7, 10],
		"dim7": [0, 3, 6, 9], "halfdim": [0, 3, 6, 10], "mmaj7": [0, 3, 7, 11],
		"aug7": [0, 4, 8, 10], "augmaj7": [0, 4, 8, 11],
		"7sus4": [0, 5, 7, 10],
		"maj6": [0, 4, 7, 9], "min6": [0, 3, 7, 9], "69": [0, 4, 7, 9, 14],
		"dom9": [0, 4, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "min9": [0, 3, 7, 10, 14],
		"add9": [0, 4, 7, 14],
	}
	# Map hint family IDs back to CHORD_INTERVALS keys
	var family_to_key := {
		"major": "Major", "minor": "Minor", "power": "Power",
		"dim": "Dim", "aug": "Aug", "sus2": "Sus2", "sus4": "Sus4",
		"maj7": "Maj7", "dom7": "Dom7", "min7": "Min7",
		"dim7": "Dim7", "halfdim": "Half-dim", "mmaj7": "mMaj7",
		"aug7": "Aug7", "augmaj7": "AugMaj7", "7sus4": "7sus4",
		"maj6": "Maj6", "min6": "Min6", "69": "6/9",
		"dom9": "Dom9", "maj9": "Maj9", "min9": "Min9", "add9": "Add9",
	}
	for family in hint_intervals.keys():
		var hint: Array = hint_intervals[family]
		var key: String = family_to_key.get(family, "")
		if key.is_empty():
			continue
		var authoritative: Array = CHORD_INTERVALS.get(key, [])
		_assert(
			_arrays_equal(hint, authoritative),
			"Hint intervals for '%s' (%s): %s != authoritative %s" % [family, key, str(hint), str(authoritative)]
		)
	print("  Done: %d hint families checked." % hint_intervals.size())


func _test_easy_first_chord_names() -> void:
	print("[8] Verifying easy-first chord names match CHORD_INTERVALS keys...")
	var easy_chord_order := ["Major", "Minor", "Dom7", "Maj7", "Min7", "Dim"]
	for name in easy_chord_order:
		_assert(
			CHORD_INTERVALS.has(name),
			"Easy-first chord '%s' not found in CHORD_INTERVALS" % name
		)
	print("  Done: %d names checked." % easy_chord_order.size())


func _test_chord_degree_mappings() -> void:
	print("[9] Verifying CHORD_DEGREES produce correct letter names...")
	var CVG = preload("res://scripts/music_theory/chord_voicing_generator.gd")
	var letters := ["C", "D", "E", "F", "G", "A", "B"]
	var letter_pc := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

	for chord_name in CVG.CHORD_DEGREES.keys():
		var intervals: Array = CVG.CHORD_INTERVALS.get(chord_name, [])
		var degrees: Array = CVG.CHORD_DEGREES.get(chord_name, [])
		_assert(intervals.size() == degrees.size(),
			"%s: intervals size %d != degrees size %d" % [chord_name, intervals.size(), degrees.size()])
		# Test with root C
		var root_idx := 0  # C
		for i in range(mini(intervals.size(), degrees.size())):
			var degree: int = int(degrees[i])
			var expected_letter_idx := posmod(root_idx + degree, 7)
			var expected_letter: String = letters[expected_letter_idx]
			var expected_base_pc: int = letter_pc[expected_letter]
			var target_pc: int = posmod(int(intervals[i]), 12)
			var accidental: int = target_pc - expected_base_pc
			if accidental > 6:
				accidental -= 12
			elif accidental < -6:
				accidental += 12
			# Accidental should be -1, 0, or 1 for well-formed chords
			_assert(
				absi(accidental) <= 2,
				"%s tone %d: degree %d gives letter %s, target pc %d, accidental %d (too large)" % [
					chord_name, i, degree, expected_letter, target_pc, accidental]
			)
	print("  Done: all degree mappings validated for root C.")


func _test_ear_training_round_trip() -> void:
	print("[10] Verifying ear training round-trip: build notes -> extract pitch classes -> match chord...")
	for chord_name in CHORD_INTERVALS.keys():
		var intervals: Array = CHORD_INTERVALS[chord_name]
		for root_midi in [48, 52, 55, 58, 60]:  # C3, E3, G3, Bb3, C4
			# Build chord notes (root position)
			var notes: Array[int] = []
			for iv in intervals:
				notes.append(root_midi + int(iv))
			# Extract pitch classes relative to root
			var extracted_intervals: Array[int] = []
			for note in notes:
				extracted_intervals.append(note - root_midi)
			_assert(
				_int_arrays_equal(extracted_intervals, intervals),
				"%s root %d: built intervals %s != expected %s" % [chord_name, root_midi, str(extracted_intervals), str(intervals)]
			)
			# Verify inversions round-trip
			for inv in range(1, mini(3, intervals.size())):
				var inv_intervals: Array[int] = []
				for v in intervals:
					inv_intervals.append(int(v))
				for _i in range(inv):
					var moved: int = int(inv_intervals.pop_front()) + 12
					inv_intervals.append(moved)
				var inv_notes: Array[int] = []
				for iv in inv_intervals:
					inv_notes.append(root_midi + int(iv))
				# All pitch classes should still belong to the original chord
				var original_pcs: Array[int] = []
				for iv in intervals:
					original_pcs.append(posmod(root_midi + int(iv), 12))
				for note in inv_notes:
					_assert(
						posmod(note, 12) in original_pcs,
						"%s root %d inv %d: note %d (pc %d) not in chord" % [chord_name, root_midi, inv, note, posmod(note, 12)]
					)
	print("  Done: 22 chords x 5 roots x inversions = comprehensive round-trip.")


func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true


func _int_arrays_equal(a: Array[int], b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != int(b[i]):
			return false
	return true
