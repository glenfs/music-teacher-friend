extends RefCounted
class_name ChordRecognizer

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const SHARP_KEYS := ["C", "G", "D", "A", "E", "B", "F#"]

# Chord templates keyed by sorted interval set (relative to root, mod 12).
# Value: [quality_short, full_name, ranking_priority] (lower priority = preferred match).
# quality_short matches the existing Sight Chords mapping; display suffix is computed via _quality_to_suffix().
const CHORD_TEMPLATES := {
	# Triads
	"4,7":           ["Major",      "Major",                  1],
	"3,7":           ["Minor",      "Minor",                  1],
	"7":             ["5",          "Power Chord",            9],
	"3,6":           ["dim",        "Diminished",             2],
	"4,8":           ["aug",        "Augmented",              3],
	"2,7":           ["sus2",       "Sus2",                   4],
	"5,7":           ["sus4",       "Sus4",                   4],
	# 7ths
	"4,7,10":        ["7",          "Dominant 7",             1],
	"4,7,11":        ["maj7",       "Major 7",                1],
	"3,7,10":        ["m7",         "Minor 7",                1],
	"3,6,9":         ["dim7",       "Diminished 7",           2],
	"3,6,10":        ["m7b5",       "Half-Diminished 7",      2],
	"3,7,11":        ["mMaj7",      "Minor-Major 7",          3],
	"4,8,10":        ["aug7",       "Augmented 7",            3],
	"4,8,11":        ["augMaj7",    "Augmented Major 7",      4],
	"5,7,10":        ["7sus4",      "7 Sus4",                 4],
	# 6ths
	"4,7,9":         ["6",          "Major 6",                2],
	"3,7,9":         ["m6",         "Minor 6",                2],
	"2,4,7,9":       ["6/9",        "Major 6/9",              3],
	# 9ths / Add9
	"2,4,7,10":      ["9",          "Dominant 9",             2],
	"2,4,7,11":      ["maj9",       "Major 9",                2],
	"2,3,7,10":      ["m9",         "Minor 9",                2],
	"2,4,7":         ["add9",       "Add 9",                  3],
	# Altered dominants
	"4,6,10":        ["7b5",        "Dominant 7 ♭5",          3],
	"1,4,7,10":      ["7b9",        "Dominant 7 ♭9",          3],
	"3,4,7,10":      ["7#9",        "Dominant 7 ♯9 (Hendrix)", 3],
	"4,7,8,10":      ["7b13",       "Dominant 7 ♭13",         4],
	# Suspended extensions
	"2,5,7,10":      ["9sus4",      "9 Suspended 4",          3],
	# 11ths
	"2,4,5,7,10":    ["11",         "Dominant 11",            3],
	"2,3,5,7,10":    ["m11",        "Minor 11",               3],
	"2,4,5,7,11":    ["maj11",      "Major 11",               4],
	# 13ths (note: natural 11 omitted on Dom13 because it clashes with the M3)
	"2,4,7,9,10":    ["13",         "Dominant 13",            3],
	# Lydian color
	"2,4,6,7,11":    ["maj7#11",    "Major 7 ♯11 (Lydian)",   3],
	"2,4,6,11":      ["maj7#11",    "Major 7 ♯11 (no 5)",     4],
	# Minor add 9
	"2,3,7":         ["madd9",      "Minor Add 9",            3],
	# Quartal/clusters (less common but useful for jazz)
	"5,10":          ["sus4(no5)",  "Quartal Stack",          5],
	# Shell voicings — root + 3rd + 7th only, the 5th omitted. Classic jazz
	# comping voicing the Chord Explorer offers under "Shell". Recognized
	# at low priority so a full voicing of the same chord still wins when
	# both are possible.
	"4,11":          ["maj7",       "Major 7 (shell)",        5],
	"4,10":          ["7",          "Dominant 7 (shell)",     5],
	"3,10":          ["m7",         "Minor 7 (shell)",        5],
	"3,11":          ["mMaj7",      "Minor-Major 7 (shell)",  5],
	# 6th-chord shells (root + 3rd + 6th, no 5th)
	"4,9":           ["6",          "Major 6 (shell)",        5],
	"3,9":           ["m6",         "Minor 6 (shell)",        5],
}

# Roman numeral by scale degree for major and minor keys.
const ROMAN_MAJOR := ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
const ROMAN_MINOR := ["i", "ii°", "III", "iv", "v", "VI", "VII"]

# Scale intervals from tonic (semitones)
const MAJOR_SCALE_INTERVALS := [0, 2, 4, 5, 7, 9, 11]
const MINOR_SCALE_INTERVALS := [0, 2, 3, 5, 7, 8, 10]
# Harmonic minor — like natural minor with raised 7th (10→11). Used by the
# diatonic-membership check so V (Major triad on degree 5) and vii° are
# correctly recognized as in-key, not as borrowed chords.
const HARMONIC_MINOR_SCALE_INTERVALS := [0, 2, 3, 5, 7, 8, 11]

# Key flavors — caller picks which scale the recognizer uses for the
# in-key / borrowed badge.
enum KeyFlavor { MAJOR, NATURAL_MINOR, HARMONIC_MINOR }


# recognize() accepts:
# - pitches: array of MIDI notes the user played.
# - key_root_pc: tonic pitch class (0..11) for spelling + diatonic check.
#   -1 = no key context (default to sharps + skip diatonic).
# - key_is_minor: legacy flag, kept for backward compat. New callers
#   should prefer key_flavor.
# - key_uses_flats: forces flat-name spelling for the active key (Bb vs A#,
#   Gb vs F#). Without this the recognizer infers from key letter, which
#   can't distinguish chosen F# from chosen Gb (same pc 6).
# - key_flavor: KeyFlavor (or int 0/1/2). Drives the diatonic-membership
#   check. Defaults to natural minor when key_is_minor is true and no
#   flavor is supplied.
static func recognize(
	pitches: Array,
	key_root_pc: int = -1,
	key_is_minor: bool = false,
	key_uses_flats: bool = false,
	key_flavor: int = -1
) -> Dictionary:
	if pitches == null or pitches.is_empty():
		return _empty_result()
	var sorted_pitches: Array = []
	for p in pitches:
		sorted_pitches.append(int(p))
	sorted_pitches.sort()
	var bass: int = sorted_pitches[0]
	var pcs: Array[int] = []
	for p in sorted_pitches:
		var pc := ((int(p) % 12) + 12) % 12
		if not pcs.has(pc):
			pcs.append(pc)
	pcs.sort()

	if pcs.size() == 1:
		var single_name: String = _spell_pc(pcs[0], key_root_pc)
		return {
			"recognized": true,
			"short_name": single_name,
			"full_name": "%s (single note)" % single_name,
			"root_pc": pcs[0],
			"root_letter": single_name,
			"quality": "single",
			"inversion_label": "",
			"intervals_from_root": [0],
			"bass_pc": ((bass % 12) + 12) % 12,
			"bass_letter": single_name,
			"is_diatonic": _is_pc_in_key(pcs[0], key_root_pc, key_is_minor),
			"roman": _roman_for_root(pcs[0], "single", key_root_pc, key_is_minor),
			"played_pcs": pcs.duplicate(),
		}

	if pcs.size() == 2:
		var iv := ((pcs[1] - pcs[0]) + 12) % 12
		var iv_label := _interval_short_name(iv)
		var note_a: String = _spell_pc(pcs[0], key_root_pc)
		var note_b: String = _spell_pc(pcs[1], key_root_pc)
		return {
			"recognized": true,
			"short_name": "%s+%s" % [note_a, note_b],
			"full_name": "%s — %s interval" % [iv_label, "%s/%s" % [note_a, note_b]],
			"root_pc": pcs[0],
			"root_letter": note_a,
			"quality": "interval",
			"inversion_label": "",
			"intervals_from_root": [0, iv],
			"bass_pc": ((bass % 12) + 12) % 12,
			"bass_letter": _spell_pc(((bass % 12) + 12) % 12, key_root_pc),
			"is_diatonic": _is_pc_in_key(pcs[0], key_root_pc, key_is_minor) and _is_pc_in_key(pcs[1], key_root_pc, key_is_minor),
			"roman": "",
			"played_pcs": pcs.duplicate(),
		}

	# Try each pitch class as a root candidate; collect matching templates.
	var candidates: Array = []
	for root_pc in pcs:
		var intervals: Array[int] = []
		for pc in pcs:
			var iv2 := ((pc - root_pc) + 12) % 12
			if not intervals.has(iv2):
				intervals.append(iv2)
		intervals.sort()
		if not intervals.has(0):
			continue
		var key := _intervals_to_key(intervals)
		if not CHORD_TEMPLATES.has(key):
			continue
		var tpl: Array = CHORD_TEMPLATES[key]
		var bass_pc := ((bass % 12) + 12) % 12
		var inversion_score := 0 if root_pc == bass_pc else 1
		var priority: int = int(tpl[2])
		var score: int = priority * 10 + inversion_score
		candidates.append({
			"root_pc": root_pc,
			"short": tpl[0],
			"full": tpl[1],
			"intervals": intervals,
			"score": score,
			"inversion": inversion_score,
		})

	if candidates.is_empty():
		var played_names: Array[String] = []
		for pc in pcs:
			played_names.append(_spell_pc(pc, key_root_pc, key_uses_flats))
		return {
			"recognized": false,
			"short_name": "?",
			"full_name": "Cluster (%s)" % " + ".join(played_names),
			"root_pc": -1,
			"root_letter": "",
			"quality": "cluster",
			"inversion_label": "",
			"intervals_from_root": [],
			"bass_pc": ((bass % 12) + 12) % 12,
			"bass_letter": _spell_pc(((bass % 12) + 12) % 12, key_root_pc),
			"is_diatonic": false,
			"roman": "",
			"played_pcs": pcs.duplicate(),
		}

	candidates.sort_custom(func(a, b): return int(a["score"]) < int(b["score"]))
	var best: Dictionary = candidates[0]
	var root_letter := _spell_pc(int(best["root_pc"]), key_root_pc, key_uses_flats)
	var bass_letter := _spell_pc(((bass % 12) + 12) % 12, key_root_pc, key_uses_flats)
	var quality_short := str(best["short"])
	var suffix := _quality_to_suffix(quality_short)
	var base_name := "%s%s" % [root_letter, suffix]
	var display_name := base_name
	var inversion_label := ""
	if int(best["inversion"]) > 0:
		display_name = "%s/%s" % [base_name, bass_letter]
		inversion_label = _inversion_ordinal(((bass % 12) + 12) % 12, int(best["root_pc"]))
	# Resolve flavor: explicit arg wins; else infer from key_is_minor.
	var effective_flavor: int = key_flavor
	if effective_flavor < 0:
		effective_flavor = KeyFlavor.NATURAL_MINOR if key_is_minor else KeyFlavor.MAJOR
	var diatonic := _chord_is_diatonic_flavor(best["intervals"], int(best["root_pc"]), key_root_pc, effective_flavor)
	var roman_str := _roman_for_root(int(best["root_pc"]), quality_short, key_root_pc, key_is_minor)
	return {
		"recognized": true,
		"short_name": display_name,
		"full_name": "%s %s" % [root_letter, best["full"]],
		"root_pc": int(best["root_pc"]),
		"root_letter": root_letter,
		"quality": quality_short,
		"inversion_label": inversion_label,
		"intervals_from_root": best["intervals"],
		"bass_pc": ((bass % 12) + 12) % 12,
		"bass_letter": bass_letter,
		"is_diatonic": diatonic,
		"roman": roman_str,
		"played_pcs": pcs.duplicate(),
	}


static func _quality_to_suffix(quality_short: String) -> String:
	# Convert the recognizer's internal quality identifier into the standard chord-symbol suffix.
	# E.g., "Major" → "" (just the root letter), "Minor" → "m", others stay as-is.
	if quality_short == "Major":
		return ""
	if quality_short == "Minor":
		return "m"
	return quality_short


static func _inversion_ordinal(bass_pc: int, root_pc: int) -> String:
	var degree := ((int(bass_pc) - int(root_pc)) + 12) % 12
	match degree:
		3, 4: return "1st inversion"
		6, 7, 8: return "2nd inversion"
		10, 11: return "3rd inversion"
		_: return "inversion"


static func _empty_result() -> Dictionary:
	return {
		"recognized": false,
		"short_name": "",
		"full_name": "",
		"root_pc": -1,
		"root_letter": "",
		"quality": "",
		"inversion_label": "",
		"intervals_from_root": [],
		"bass_pc": -1,
		"bass_letter": "",
		"is_diatonic": false,
		"roman": "",
		"played_pcs": [],
	}


static func _intervals_to_key(intervals: Array) -> String:
	var parts: Array[String] = []
	for iv in intervals:
		if int(iv) == 0:
			continue
		parts.append(str(int(iv)))
	return ",".join(parts)


static func _spell_pc(pc: int, key_root_pc: int, force_flats: bool = false) -> String:
	var pc_clamped := ((int(pc) % 12) + 12) % 12
	# Explicit override from caller — used when the user chose a specifically
	# flat-spelled key (Bb, Eb, Ab, Db, Gb). Without this the pc-only key
	# letter can't distinguish chosen F# from chosen Gb (same pc 6).
	if force_flats:
		return NOTE_NAMES_FLAT[pc_clamped]
	var use_sharps := true
	if key_root_pc >= 0:
		var key_letter: String = NOTE_NAMES_SHARP[((int(key_root_pc) % 12) + 12) % 12]
		if not (key_letter in SHARP_KEYS):
			use_sharps = false
	if use_sharps:
		return NOTE_NAMES_SHARP[pc_clamped]
	return NOTE_NAMES_FLAT[pc_clamped]


static func _interval_short_name(semitones: int) -> String:
	var s := ((int(semitones) % 12) + 12) % 12
	match s:
		0: return "Unison"
		1: return "Minor 2nd"
		2: return "Major 2nd"
		3: return "Minor 3rd"
		4: return "Major 3rd"
		5: return "Perfect 4th"
		6: return "Tritone"
		7: return "Perfect 5th"
		8: return "Minor 6th"
		9: return "Major 6th"
		10: return "Minor 7th"
		11: return "Major 7th"
		_: return ""


static func _is_pc_in_key(pc: int, key_root_pc: int, key_is_minor: bool) -> bool:
	if key_root_pc < 0:
		return false
	var pc_clamped := ((int(pc) % 12) + 12) % 12
	var degree := ((pc_clamped - int(key_root_pc)) + 12) % 12
	var scale := MINOR_SCALE_INTERVALS if key_is_minor else MAJOR_SCALE_INTERVALS
	return degree in scale


static func _chord_is_diatonic(intervals: Array, root_pc: int, key_root_pc: int, key_is_minor: bool) -> bool:
	if key_root_pc < 0:
		return false
	for iv in intervals:
		var pc := (int(root_pc) + int(iv)) % 12
		if not _is_pc_in_key(pc, key_root_pc, key_is_minor):
			return false
	return true


# Flavor-aware diatonic check used by the new recognize() entry point.
# Falls back to the legacy major/natural-minor variant for those flavors,
# but uses the harmonic-minor scale (raised 7th) for the third option so
# V Major + vii° register as in-key instead of "Borrowed".
static func _chord_is_diatonic_flavor(intervals: Array, root_pc: int, key_root_pc: int, flavor: int) -> bool:
	if key_root_pc < 0:
		return false
	var scale: Array
	match flavor:
		KeyFlavor.HARMONIC_MINOR:
			scale = HARMONIC_MINOR_SCALE_INTERVALS
		KeyFlavor.NATURAL_MINOR:
			scale = MINOR_SCALE_INTERVALS
		_:
			scale = MAJOR_SCALE_INTERVALS
	for iv in intervals:
		var pc := (int(root_pc) + int(iv)) % 12
		var degree := ((pc - int(key_root_pc)) + 12) % 12
		if not (degree in scale):
			return false
	return true


static func _roman_for_root(root_pc: int, quality_short: String, key_root_pc: int, key_is_minor: bool) -> String:
	if key_root_pc < 0:
		return ""
	var pc_clamped := ((int(root_pc) % 12) + 12) % 12
	var degree := ((pc_clamped - int(key_root_pc)) + 12) % 12
	var scale := MINOR_SCALE_INTERVALS if key_is_minor else MAJOR_SCALE_INTERVALS
	var deg_idx := scale.find(degree)
	if deg_idx < 0:
		return ""
	var base: String = ROMAN_MINOR[deg_idx] if key_is_minor else ROMAN_MAJOR[deg_idx]
	# Append quality decoration for 7ths/extensions
	if quality_short.ends_with("7") or quality_short == "maj7" or quality_short == "m7" or quality_short == "dim7" or quality_short == "m7b5":
		if not base.ends_with("7"):
			base += "⁷"
	return base
