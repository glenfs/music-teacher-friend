extends RefCounted
class_name MusicTheoryCorrectnessTest

# Pure, deterministic "music correctness oracle" for the QA suite.
#
# WHY THIS EXISTS: the rest of the QA bot verifies that screens open, navigate,
# and don't crash — it does NOT check that the MUSIC the app produces is
# theoretically correct. That gap let real bugs reach manual testing (C7 drawn
# as A#, a Bb triad spelled A# C## E#, a minor "cadence" with no leading tone,
# altered dominants described as "bright major", mislabeled cadences, ...).
#
# These checks need no rendering and no scene — they call the pure theory
# modules (and read the app's chord/cadence/scale CONST tables) directly and
# assert against ground truth, so they run fast + headless and fail the instant
# a spelling/label/harmony rule regresses.
#
# Returns { "passed": int, "failed": int, "failures": Array[String] }.

const ChordRecognizerScript = preload("res://scripts/music_theory/chord_recognizer.gd")
const ChordToneSpellingScript = preload("res://scripts/music_theory/chord_tone_spelling.gd")
const MusicHelpersScript = preload("res://scripts/music_theory/music_helpers.gd")
const TheoryQGScript = preload("res://scripts/exercises/theory_question_generator.gd")
const ChordComposerScript = preload("res://scripts/exercises/composers/chord_composer.gd")

# Canonical interval id per semitone count (0..12) — what a teacher expects.
const SEMI_TO_INTERVAL_ID := [
	"P1", "m2", "M2", "m3", "M3", "P4", "TT", "P5", "m6", "M6", "m7", "M7", "P8"
]

# Chord qualities swept across all 12 roots. Each is the root-relative semitone
# set the recognizer matches. dim7 is excluded (its diminished 7th is a genuine
# double-flat — a separate, deliberate display choice, not a defect).
const CHORD_MATRIX := [
	[0, 4, 7], [0, 3, 7], [0, 3, 6], [0, 4, 8],
	[0, 4, 7, 10], [0, 4, 7, 11], [0, 3, 7, 10], [0, 3, 6, 10],
	[0, 4, 7, 9], [0, 3, 7, 9],
	# Extensions, including ones voiced LOW (compressed into the chord octave) so
	# the spelling must NOT degenerate into double accidentals — guards the
	# "add Eb to C7 -> B#,D#,Fb,Abb,Cbb" regression.
	[0, 2, 4, 7, 10],   # 9
	[0, 1, 4, 7, 10],   # 7b9 (b9 voiced low)
	[0, 3, 4, 7, 10],   # 7#9 (#9 voiced low — the reported case)
]

# Triad-tone basics for diatonic spot-checks.
const _BASIC_INTERVALS := {"Major": [0, 4, 7], "Minor": [0, 3, 7], "Dim": [0, 3, 6]}

# Roman numeral (any case, trailing ° allowed) -> 0-based scale degree.
const _ROMAN_DEGREE := {
	"i": 0, "ii": 1, "iii": 2, "iv": 3, "v": 4, "vi": 5, "vii": 6,
}

# Quality a chord-family id must NOT be when it is a dominant/altered dominant —
# guards against the "tense dominant described as a bright major triad" bug.
const _EXPECTED_FAMILY := {
	"Major": "major", "Minor": "minor", "Maj7": "maj7", "Dom7": "dom7",
	"Min7": "min7", "Dim": "dim", "Aug": "aug", "Half-dim": "halfdim",
	"Dim7": "dim7", "7b5": "dom7", "7b9": "dom7", "7#9": "dom7",
	"Dom11": "dom7", "Dom13": "dom7", "Madd9": "minor", "Maj11": "maj7",
	"Min11": "min7", "Maj7#11": "maj7",
}

const _CANONICAL_MODES := {
	"Major": [0, 2, 4, 5, 7, 9, 11],
	"Natural Minor": [0, 2, 3, 5, 7, 8, 10],
	"Dorian": [0, 2, 3, 5, 7, 9, 10],
	"Mixolydian": [0, 2, 4, 5, 7, 9, 10],
	"Lydian": [0, 2, 4, 6, 7, 9, 11],
	"Phrygian": [0, 1, 3, 5, 7, 8, 10],
}


static func run() -> Dictionary:
	var acc := {"passed": 0, "failed": 0, "failures": [] as Array[String]}
	_merge(acc, _check_intervals())
	_merge(acc, _check_chord_spelling())
	_merge(acc, _check_diatonic_triads())
	_merge(acc, _check_chord_families())
	_merge(acc, _check_drills_minor_cadence())
	_merge(acc, _check_cadence_defs())
	_merge(acc, _check_scale_mode_defs())
	_merge(acc, _check_functional_ear_degrees())
	return acc


static func _merge(acc: Dictionary, part: Dictionary) -> void:
	acc["passed"] = int(acc["passed"]) + int(part.get("passed", 0))
	acc["failed"] = int(acc["failed"]) + int(part.get("failed", 0))
	(acc["failures"] as Array).append_array(part.get("failures", []))


# --- 1. Interval id <-> semitone count ---
static func _check_intervals() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	for st in range(SEMI_TO_INTERVAL_ID.size()):
		var got: String = MusicHelpersScript.interval_id_for_semitones(st)
		if got != SEMI_TO_INTERVAL_ID[st]:
			fails.append("interval: %d semitones -> '%s', expected '%s'" % [st, got, SEMI_TO_INTERVAL_ID[st]])
			f += 1
		else:
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 2. Chord spelling across every quality x all 12 roots ---
static func _check_chord_spelling() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	var letter_pc: Dictionary = ChordToneSpellingScript.LETTER_PC
	for root_pc in range(12):
		for ivs in CHORD_MATRIX:
			var label := "pc%d %s" % [root_pc, str(ivs)]
			var pitches: Array[int] = []
			for iv in ivs:
				pitches.append(60 + root_pc + int(iv))
			var info: Dictionary = ChordRecognizerScript.recognize(pitches, 0, false, false, -1)
			if not bool(info.get("recognized", false)):
				fails.append("chord %s: not recognized" % label)
				f += 1
				continue
			# Some sets are genuinely ambiguous (C6 == Am7; aug triads are
			# symmetric). We assert the SPELLING of whatever chord it reports.
			var rroot: int = ((int(info.get("root_pc", 0)) % 12) + 12) % 12
			var quality: String = str(info.get("quality", ""))
			var ivs2: Array = info.get("intervals_from_root", [])
			var sorted_ivs: Array = ivs2.duplicate()
			sorted_ivs.sort()
			var rspell: Dictionary = ChordToneSpellingScript.best_root_spelling(rroot, ivs2, quality, false)
			var tones: Array = ChordToneSpellingScript.spell_chord_tones(
				str(rspell.get("letter", "C")), int(rspell.get("acc", 0)), ivs2, quality)
			if tones.size() != sorted_ivs.size():
				fails.append("chord %s: %d tones for %d intervals" % [label, tones.size(), sorted_ivs.size()])
				f += 1
				continue
			var ok := true
			var seen: Dictionary = {}
			var has_double := false
			for i in range(tones.size()):
				var t: Dictionary = tones[i]
				var letter := str(t.get("letter", ""))
				var a := int(t.get("accidental", 0))
				var tone_pc: int = ((int(letter_pc.get(letter, 0)) + a) % 12 + 12) % 12
				if tone_pc != (rroot + int(sorted_ivs[i])) % 12:
					fails.append("chord %s: tone %s -> pc %d, expected %d" % [label, letter, tone_pc, (rroot + int(sorted_ivs[i])) % 12])
					ok = false
					break
				if absi(a) >= 2:
					has_double = true
				if seen.has(letter):
					fails.append("chord %s: repeated letter '%s' (mis-stacked)" % [label, letter])
					ok = false
					break
				seen[letter] = true
			if not ok:
				f += 1
				continue
			if has_double and _double_free_root_exists(rroot, ivs2, quality, letter_pc):
				fails.append("chord %s: double accidental though an enharmonic root avoids it" % label)
				f += 1
				continue
			var name_root: String = ChordToneSpellingScript.format_pitch(str(rspell.get("letter", "C")), int(rspell.get("acc", 0)))
			if not str(info.get("short_name", "")).begins_with(name_root):
				fails.append("chord %s: name '%s' != clean root '%s'" % [label, str(info.get("short_name", "")), name_root])
				f += 1
				continue
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 3. Diatonic triad qualities in a major key (used by progression/cadence) ---
static func _check_diatonic_triads() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	# I ii iii IV V vi vii° -> Major Minor Minor Major Major Minor Dim.
	var expected := [[0, 4, 7], [0, 3, 7], [0, 3, 7], [0, 4, 7], [0, 4, 7], [0, 3, 7], [0, 3, 6]]
	for step in range(7):
		var notes: Array = TheoryQGScript.diatonic_triad_notes(step, 60, _BASIC_INTERVALS)
		var rel: Array = []
		for n in notes:
			rel.append(int(n) - int(notes[0]))
		if rel != expected[step]:
			fails.append("diatonic: degree %d triad intervals %s, expected %s" % [step + 1, str(rel), str(expected[step])])
			f += 1
		else:
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 4. Chord-family mapping used by feedback/hints ---
static func _check_chord_families() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	for quality in _EXPECTED_FAMILY.keys():
		var got: String = MusicHelpersScript.chord_family_id_from_name(str(quality))
		var want: String = str(_EXPECTED_FAMILY[quality])
		if got != want:
			fails.append("family: '%s' -> '%s', expected '%s'" % [str(quality), got, want])
			f += 1
		else:
			p += 1
		# Hard guard: a dominant/altered dominant must never read as plain major.
		if str(quality).to_lower().find("7") >= 0 and got == "major":
			fails.append("family: dominant '%s' mislabeled as 'major'" % str(quality))
			f += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 5. Practice-Drills minor I-iv-V-i cadence must have a leading tone ---
static func _check_drills_minor_cadence() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	for key_pc in [9, 2, 4, 7, 0]:  # A, D, E, G, C minor
		var ex: Dictionary = ChordComposerScript.generate_progression_classical(key_pc, true, "right", 60)
		var v_pcs: Dictionary = {}
		for n_any in ex.get("notes", []):
			var n: Dictionary = n_any
			if absf(float(n.get("beat_offset", -1.0)) - 8.0) < 0.01 and not bool(n.get("rest", false)):
				v_pcs[((int(n.get("midi", -1)) % 12) + 12) % 12] = true
		var leading_tone: int = ((key_pc - 1) % 12 + 12) % 12
		if not v_pcs.has(leading_tone):
			fails.append("drills minor cadence (key_pc %d): V chord lacks the leading tone (pc %d) — not an authentic cadence" % [key_pc, leading_tone])
			f += 1
		else:
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 6. Cadence definitions: labels must match their chord content ---
static func _check_cadence_defs() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	var defs: Dictionary = _ib_const("CADENCE_DEFS")
	if defs.is_empty():
		return {"passed": 0, "failed": 0, "failures": [] as Array[String]}
	for key in defs.keys():
		var def: Dictionary = defs[key]
		var label: String = str(def.get("label", ""))
		var steps: Array = def.get("steps", [])
		# Parse the roman tokens inside the parentheses, e.g. "Perfect (V-I)".
		var romans := _parse_roman_tokens(label)
		# (a) Roman tokens must map to the actual chord steps.
		if romans.size() == steps.size():
			for i in range(romans.size()):
				if int(_ROMAN_DEGREE.get(str(romans[i]).to_lower().replace("°", ""), -1)) != int(steps[i]):
					fails.append("cadence '%s': label roman '%s' != step %d" % [str(key), str(romans[i]), int(steps[i])])
					f += 1
				else:
					# (b) Roman CASE must match the diatonic quality of that degree.
					if not _roman_case_matches_degree(str(romans[i]), int(steps[i])):
						fails.append("cadence '%s': roman '%s' case/quality wrong for degree %d" % [str(key), str(romans[i]), int(steps[i])])
						f += 1
					else:
						p += 1
		elif not romans.is_empty():
			fails.append("cadence '%s': %d romans vs %d steps" % [str(key), romans.size(), steps.size()])
			f += 1
		# (c) The "perfect" substring trap: only the true Perfect cadence (V->I)
		# may contain "perfect" — otherwise feedback/hints misfire. Exclude
		# "imperfect" (the Half cadence's alternative name contains "perfect").
		if label.to_lower().find("perfect") >= 0 and label.to_lower().find("imperfect") < 0 and steps != [4, 0]:
			fails.append("cadence '%s': label '%s' contains 'perfect' but isn't V-I — will mis-route feedback" % [str(key), label])
			f += 1
		else:
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 7. Scale/mode definitions: valid + canonical ---
static func _check_scale_mode_defs() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	var defs: Dictionary = _ib_const("SCALE_MODE_DEFS")
	if defs.is_empty():
		return {"passed": 0, "failed": 0, "failures": [] as Array[String]}
	for name in defs.keys():
		var raw: Array = defs[name]
		# Drop a trailing octave (12) if present; we validate the 7 scale degrees.
		var steps: Array = []
		for v in raw:
			if int(v) < 12:
				steps.append(int(v))
		# Structural validity: 7 distinct, strictly ascending, in [0,11], starts on 0.
		var ok := steps.size() == 7 and int(steps[0]) == 0
		if ok:
			for i in range(1, steps.size()):
				if int(steps[i]) <= int(steps[i - 1]) or int(steps[i]) > 11:
					ok = false
					break
		if not ok:
			fails.append("scale '%s': malformed step set %s" % [str(name), str(steps)])
			f += 1
			continue
		# Match the canonical pattern when we know the mode.
		if _CANONICAL_MODES.has(name) and steps != _CANONICAL_MODES[name]:
			fails.append("scale '%s': %s != canonical %s" % [str(name), str(steps), str(_CANONICAL_MODES[name])])
			f += 1
		else:
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- 8. Functional Ear Training diatonic harmony (major + minor) ---
# Guards the FunctionalEarPanel.DEGREES table: correct degree semitones and
# qualities, and critically the MINOR V is a MAJOR dominant (raised leading
# tone) — a minor v would not be a functional dominant.
const _QUALITY_TRIAD := {"major": [0, 4, 7], "minor": [0, 3, 7], "diminished": [0, 3, 6]}
const _FE_EXPECTED := {
	"major": [
		[0, "major"], [2, "minor"], [4, "minor"], [5, "major"], [7, "major"], [9, "minor"], [11, "diminished"],
	],
	"minor": [
		[0, "minor"], [2, "diminished"], [3, "major"], [5, "minor"], [7, "major"], [8, "major"], [11, "diminished"],
	],
}

static func _check_functional_ear_degrees() -> Dictionary:
	var p := 0
	var f := 0
	var fails: Array[String] = []
	var script: GDScript = load("res://scripts/ui/functional_ear_panel.gd")
	if script == null:
		return {"passed": 0, "failed": 0, "failures": [] as Array[String]}
	var degrees_v: Variant = script.get_script_constant_map().get("DEGREES", {})
	if not (degrees_v is Dictionary):
		return {"passed": 0, "failed": 0, "failures": [] as Array[String]}
	var degrees: Dictionary = degrees_v
	for mode in _FE_EXPECTED.keys():
		var rows: Array = degrees.get(mode, [])
		var expected: Array = _FE_EXPECTED[mode]
		if rows.size() != expected.size():
			fails.append("functional-ear %s: %d degrees (expected %d)" % [str(mode), rows.size(), expected.size()])
			f += 1
			continue
		for i in range(rows.size()):
			var row: Dictionary = rows[i]
			var want_semis: int = int(expected[i][0])
			var want_quality: String = str(expected[i][1])
			if int(row.get("semis", -1)) != want_semis:
				fails.append("functional-ear %s degree %d: semis %d (expected %d)" % [str(mode), i + 1, int(row.get("semis", -1)), want_semis])
				f += 1
				continue
			if str(row.get("quality", "")) != want_quality:
				fails.append("functional-ear %s degree %d: quality '%s' (expected '%s')" % [str(mode), i + 1, str(row.get("quality", "")), want_quality])
				f += 1
				continue
			# Triad intervals must match the quality, and the 7th must contain the triad.
			var triad: Array = row.get("triad", [])
			if triad != _QUALITY_TRIAD.get(want_quality, []):
				fails.append("functional-ear %s degree %d: triad %s != %s" % [str(mode), i + 1, str(triad), str(_QUALITY_TRIAD.get(want_quality, []))])
				f += 1
				continue
			var seventh: Array = row.get("seventh", [])
			var has_triad := true
			for iv in triad:
				if not seventh.has(int(iv)):
					has_triad = false
					break
			if not has_triad:
				fails.append("functional-ear %s degree %d: 7th %s missing triad tones" % [str(mode), i + 1, str(seventh)])
				f += 1
				continue
			p += 1
	return {"passed": p, "failed": f, "failures": fails}


# --- Helpers ---

static func _ib_const(const_name: String) -> Dictionary:
	# Read a const table from interval_birds.gd at runtime (the script is already
	# loaded by the app). Runtime load() avoids any class-level circular preload.
	var ib: GDScript = load("res://scripts/interval_birds.gd")
	if ib == null:
		return {}
	var map: Dictionary = ib.get_script_constant_map()
	var v: Variant = map.get(const_name, {})
	return v if v is Dictionary else {}


static func _parse_roman_tokens(label: String) -> Array:
	# Extract tokens inside the first (...) group, split on '-'.
	var lp := label.find("(")
	var rp := label.find(")")
	if lp < 0 or rp <= lp:
		return []
	var inner := label.substr(lp + 1, rp - lp - 1)
	var out: Array = []
	for tok in inner.split("-", false):
		var t := str(tok).strip_edges()
		if t != "":
			out.append(t)
	return out


static func _roman_case_matches_degree(roman: String, degree: int) -> bool:
	# In a major key: I/IV/V major (uppercase), ii/iii/vi minor (lowercase),
	# vii° diminished (lowercase + °). Verify the token's case matches.
	var has_deg := degree >= 0 and degree <= 6
	if not has_deg:
		return true
	var is_lower := roman == roman.to_lower()
	var has_dim := roman.find("°") >= 0
	match degree:
		0, 3, 4:  # I, IV, V — major
			return not is_lower and not has_dim
		1, 2, 5:  # ii, iii, vi — minor
			return is_lower and not has_dim
		6:  # vii° — diminished
			return is_lower and has_dim
	return true


static func _double_free_root_exists(root_pc: int, intervals: Array, quality: String, letter_pc: Dictionary) -> bool:
	var note_letters: Array = ChordToneSpellingScript.NOTE_LETTERS
	for letter in note_letters:
		var natural_pc: int = int(letter_pc.get(letter, 0))
		var acc: int = ((root_pc - natural_pc + 6) % 12 + 12) % 12 - 6
		if absi(acc) > 1:
			continue
		var tones: Array = ChordToneSpellingScript.spell_chord_tones(str(letter), acc, intervals, quality)
		var clean := true
		for t in tones:
			if absi(int((t as Dictionary).get("accidental", 0))) >= 2:
				clean = false
				break
		if clean:
			return true
	return false
