class_name ChordFormationSteps
extends RefCounted

const _ChordToneSpelling = preload("res://scripts/music_theory/chord_tone_spelling.gd")

# Generates "how to form this chord" step content for the Chord Explorer
# step-through teaching panel. Pure data — no Node dependency.
#
# Each step describes one note added to the chord, with:
#   • Interval label (Root, Major 3rd, Perfect 5th, Minor 7th, ...)
#   • Scale degree relative to the chord ROOT (1, 3, 5, ♭7, ...)
#   • Scale degree relative to the current KEY (so "G in C major" → degree 5)
#   • One-line "why" explaining the harmonic role
#   • The concrete note letter (in the key's preferred enharmonic spelling)
#
# Usage:
#   var data := ChordFormationSteps.build(intervals, root_pc, quality_short,
#                                          key_pc, is_minor, uses_flats)
#   data.steps -> Array of step dicts (Root first, then 3rd → 5th → 7th → ext.)
#   data.headline -> short summary line
#   data.function_in_key -> roman + plain-English role (or "" if non-diatonic)


# ---------------------------------------------------------------------------
# Chord-tone labels keyed by RAW semitones from root.
#
# Used when the interval is part of the core triad/seventh stack (0-11) and
# is unambiguously a chord tone. For compressed extensions (a 9 that's stored
# as 2 because the recognizer wraps to mod-12), _extension_descriptor() takes
# over and re-labels them as 9 / 11 / 13 family tones.
# Each entry: [abbr, full_name, chord_degree_label, why_one_liner]
# ---------------------------------------------------------------------------
const _CORE_TABLE := {
	0:  ["R",  "Root",         "1",  "Every chord starts on its root — the note the chord is named after."],
	3:  ["m3", "Minor 3rd",    "♭3", "The minor 3rd gives the chord its sad / shadowy color."],
	4:  ["M3", "Major 3rd",    "3",  "The major 3rd defines the bright, happy major sound."],
	6:  ["d5", "Diminished 5th","♭5","Tightens the chord — half-step lower than the perfect 5th."],
	7:  ["P5", "Perfect 5th",  "5",  "The 5th sits a perfect 5th above the root — the most stable interval."],
	8:  ["A5", "Augmented 5th","♯5","Raised 5th — adds an unsettled, suspended quality."],
	9:  ["M6", "Major 6th",    "6",  "Adds a sweet, open color above the triad."],
	10: ["m7", "Minor 7th",    "♭7", "The dominant / bluesy 7th — wants to pull toward home."],
	11: ["M7", "Major 7th",    "7",  "The major 7th gives that lush, jazzy shimmer."],
}

# Sus substitutes used when the chord HAS NO 3rd (sus2 / sus4 chords).
const _SUS_AS_THIRD := {
	2: ["sus2", "Sus 2nd", "2",  "Sus2 — a whole step replaces the 3rd; open, unresolved sound."],
	5: ["sus4", "Sus 4th", "4",  "Sus4 — a perfect 4th replaces the 3rd; suspended, wants to move."],
}

# Compressed extensions: when the chord has a real 3rd, intervals at semis
# 1/2/3 are 9th-family (♭9 / 9 / ♯9), 5 is 11, 6 is ♯11, 8 is ♭13, 9 is 13.
# Raw intervals ≥ 12 (the recognizer occasionally emits 14, 18 etc.) map the
# same way after mod 12.
const _EXTENSION_TABLE := {
	1: ["♭9",  "Flat 9th",   "♭9",  "A chromatic color tone — adds bite, common in altered dominants."],
	2: ["9",   "Natural 9th","9",   "Extension a 9th above the root — adds shimmer to the basic chord."],
	3: ["♯9",  "Sharp 9th",  "♯9",  "The 'Hendrix' tone — gritty against a dominant 7."],
	5: ["11",  "Natural 11th","11", "A perfect 4th above the root, voiced an octave up — bittersweet."],
	6: ["♯11", "Sharp 11th", "♯11", "Spicy color tone — the lydian sound."],
	8: ["♭13", "Flat 13th",  "♭13", "A chromatic 6 — adds tension in altered-dominant settings."],
	9: ["13",  "Natural 13th","13", "A 6th voiced an octave up — sophisticated, jazz-flavored."],
}


# ---------------------------------------------------------------------------
# Per-quality headlines + function-family lookup.
# Keyed by the chord recognizer's `quality_short` strings (Major / Minor /
# dim / aug / 7 / maj7 / m7 / dim7 / m7b5 / mMaj7 / 6 / m6 / 6/9 / 9 / maj9 /
# m9 / add9 / 7b5 / 7b9 / 7#9 / 7b13 / 9sus4 / 11 / m11 / maj11 / 13 / madd9
# / maj7#11 / sus2 / sus4 / 7sus4 / aug7 / augMaj7 / 5 / sus4(no5)).
# ---------------------------------------------------------------------------
const _QUALITY_HEADLINES := {
	"Major":     "Major — bright, stable, the 'home' sound.",
	"Minor":     "Minor — darker, often sad or pensive.",
	"dim":       "Diminished — tense, unstable, wants to resolve.",
	"aug":       "Augmented — floating, unsettled, dreamlike.",
	"sus2":      "Sus2 — the 3rd replaced by a 2nd; open, unresolved.",
	"sus4":      "Sus4 — the 3rd replaced by a 4th; suspended, wants to move.",
	"7":         "Dominant 7 — bluesy, restless; pulls strongly to the I chord.",
	"m7":        "Minor 7 — soft, smooth; the classic mellow jazz minor.",
	"maj7":      "Major 7 — lush, dreamy, jazz-ballad sweetness.",
	"dim7":      "Diminished 7 — symmetrically stacked minor 3rds; very tense.",
	"m7b5":      "Half-diminished (m7♭5) — diminished triad with a minor 7th.",
	"mMaj7":     "Minor-Major 7 — minor triad with a major 7th; mysterious noir.",
	"aug7":      "Augmented 7 — augmented triad with a ♭7; whole-tone vibe.",
	"augMaj7":   "Augmented Major 7 — augmented triad with a major 7th; eerie.",
	"7sus4":     "7sus4 — dominant 7 with a 4th replacing the 3rd; suspended pull.",
	"6":         "Major 6 — major triad with an added 6th; sweet and warm.",
	"m6":        "Minor 6 — minor triad with an added 6th; jazzy minor.",
	"6/9":       "Major 6/9 — major + 6 + 9; open, ringing, modern pop voicing.",
	"9":         "Dominant 9 — Dom7 plus a 9th on top; richer pull-to-home.",
	"maj9":      "Major 9 — Maj7 plus a 9th; jazz-ballad shimmer.",
	"m9":        "Minor 9 — m7 plus a 9th; smooth modal minor.",
	"madd9":     "Minor add9 — minor triad plus a 9th; bittersweet color.",
	"add9":      "Add9 — major triad plus a 9th (no 7th); shimmery.",
	"7b5":       "Dominant 7♭5 — lowered 5th adds chromatic tension.",
	"7b9":       "Dominant 7♭9 — ♭9 over a dominant; cinematic tension.",
	"7#9":       "Dominant 7♯9 — the 'Hendrix' chord; bluesy crunch.",
	"7b13":      "Dominant 7♭13 — alt-dom color; pulls hard to minor.",
	"9sus4":     "9sus4 — suspended dominant + 9; floating, modal jazz.",
	"11":        "Dominant 11 — Dom7 + 9 + 11; suspended, modal flavor.",
	"m11":       "Minor 11 — m7 + 9 + 11; the classic modal-jazz minor.",
	"maj11":     "Major 11 — Maj7 + 9 + 11; lush, dense lydian-ish color.",
	"13":        "Dominant 13 — Dom7 + 9 + 13; full-bodied jazz dominant.",
	"maj7#11":   "Major 7♯11 — lydian color, floating and bright.",
	"5":         "Power chord — root + 5th, no 3rd; neither major nor minor.",
	"sus4(no5)": "Quartal stack — stacked 4ths; modal, open, no clear tonality.",
}


# Pitch-class → scale-degree label, for MAJOR keys.
const _DEGREE_MAJOR := {
	0: "1", 1: "♭2", 2: "2", 3: "♭3", 4: "3", 5: "4",
	6: "♯4", 7: "5", 8: "♭6", 9: "6", 10: "♭7", 11: "7"
}

# Same, for NATURAL MINOR keys.
const _DEGREE_MINOR := {
	0: "1", 1: "♭2", 2: "2", 3: "♭3", 4: "♮3", 5: "4",
	6: "♯4", 7: "5", 8: "♭6", 9: "♮6", 10: "♭7", 11: "♮7"
}

# Common roman-numeral / plain-English role lookup, keyed by [degree_semi,
# is_minor_key, quality_family]. Quality_family lumps the recognizer's
# vocabulary into maj / min / dom7 / dim / aug / sus.
const _FUNCTION_ROLES := {
	# Major keys
	[0, false, "maj"]:  "I — the tonic (home).",
	[5, false, "maj"]:  "IV — the subdominant (away from home).",
	[7, false, "maj"]:  "V — the dominant (pull back to home).",
	[7, false, "dom7"]: "V7 — the dominant 7th (strong pull back to home).",
	[9, false, "min"]:  "vi — the relative minor.",
	[2, false, "min"]:  "ii — the supertonic (often precedes V).",
	[4, false, "min"]:  "iii — the mediant.",
	[11, false, "dim"]: "vii° — leading-tone, very pull-to-tonic.",
	# Minor keys
	[0, true,  "min"]:  "i — the tonic (minor home).",
	[5, true,  "min"]:  "iv — the minor subdominant.",
	[7, true,  "maj"]:  "V — the dominant (raised 7th cadence).",
	[7, true,  "dom7"]: "V7 — strong cadential dominant.",
	[10, true, "maj"]:  "♭VII — the natural-minor leading-tone chord.",
	[8, true,  "maj"]:  "♭VI — the relative-major-of-iv color.",
	[3, true,  "maj"]:  "III — the relative major.",
}


# ---------------------------------------------------------------------------
# Public entry point.
# ---------------------------------------------------------------------------


# Builds the walkthrough data from the raw intervals (semitones from root)
# the chord recognizer produced. `quality_short` only drives the headline +
# function-in-key lookup — the step list itself uses the actual intervals
# so every chord the recognizer can name works (not just the 18 hand-listed
# qualities in the legacy table).
static func build(intervals: Array, root_pc: int, quality_short: String, key_pc: int, key_is_minor: bool, key_uses_flats: bool) -> Dictionary:
	if intervals.is_empty():
		return {
			"valid": false,
			"steps": [],
			"headline": "",
			"function_in_key": "",
		}
	root_pc = ((root_pc % 12) + 12) % 12
	key_pc = ((key_pc % 12) + 12) % 12
	# Reorder intervals into tertian stack order: root, then 3rd, then 5th,
	# then 7th, then extensions (9 → ♯11 → 13). Without this, Maj9 reads as
	# Root → 9 → 3 → 5 → 7 which is musically backwards.
	var has_third: bool = _intervals_have_third(intervals)
	var ordered: Array = intervals.duplicate()
	ordered.sort_custom(func(a, b): return _tertian_sort_key(int(a), has_third) < _tertian_sort_key(int(b), has_third))
	# Spell every chord tone with stack-of-thirds rules (root_letter + 2 per
	# stacked-third) so a C Dom7's ♭7 displays "Bb" not "A#". Build a map
	# from raw semitone interval → properly-spelled note string. Falls back
	# to naive pc-only spelling for intervals the spelling helper can't
	# resolve under the current quality.
	var root_letter_only: String = _spell_pc(root_pc, key_uses_flats).substr(0, 1)
	var root_acc_for_spelling: int = 0
	var root_spell_full: String = _spell_pc(root_pc, key_uses_flats)
	if root_spell_full.length() > 1:
		var suf := root_spell_full.substr(1)
		if suf == "#":
			root_acc_for_spelling = 1
		elif suf == "b":
			root_acc_for_spelling = -1
	var spelled_tones: Array = _ChordToneSpelling.spell_chord_tones(
		root_letter_only, root_acc_for_spelling, intervals, quality_short
	)
	# Build interval-mod → spelled-string map. Sorted ascending intervals
	# match the order spell_chord_tones returns; use that as the key.
	var iv_sorted: Array = intervals.duplicate()
	iv_sorted.sort()
	var iv_to_spell: Dictionary = {}
	for si in iv_sorted.size():
		if si >= spelled_tones.size():
			break
		var tone: Dictionary = spelled_tones[si]
		var letter: String = str(tone.get("letter", ""))
		var acc: int = int(tone.get("accidental", 0))
		iv_to_spell[int(iv_sorted[si])] = _ChordToneSpelling.format_pitch(letter, acc)
	var steps: Array = []
	for i in ordered.size():
		var semitones: int = int(ordered[i])
		var entry: Array = _interval_descriptor(semitones, has_third)
		var chord_tone_pc: int = ((root_pc + semitones) % 12 + 12) % 12
		var key_degree_semi: int = ((chord_tone_pc - key_pc) % 12 + 12) % 12
		var key_degree_label: String = _key_degree_label(key_degree_semi, key_is_minor)
		var note_letter: String = str(iv_to_spell.get(semitones, _spell_pc(chord_tone_pc, key_uses_flats)))
		steps.append({
			"index": i,
			"step_number": i + 1,
			"total_steps": ordered.size(),
			"interval_semitones": semitones,
			"abbr": entry[0],
			"full_name": entry[1],
			"chord_degree": entry[2],
			"why": entry[3],
			"key_degree": key_degree_label,
			"note_letter": note_letter,
		})
	return {
		"valid": true,
		"steps": steps,
		"ordered_intervals": ordered,
		"headline": _QUALITY_HEADLINES.get(quality_short, _fallback_headline(quality_short)),
		"function_in_key": _function_in_key(root_pc, key_pc, key_is_minor, quality_short),
	}


# ---------------------------------------------------------------------------
# Descriptor lookup — picks the right label table for each interval.
# ---------------------------------------------------------------------------


static func _interval_descriptor(semitones: int, has_third: bool) -> Array:
	if semitones == 0:
		return _CORE_TABLE[0]
	var mod: int = ((semitones % 12) + 12) % 12
	# Core 3rd / 5th / 7th slots.
	if mod == 3 or mod == 4 or mod == 6 or mod == 7 or mod == 8 or mod == 9 or mod == 10 or mod == 11:
		# 9 also appears in dim7 (Major 6 / dim 7) — Core_TABLE entry covers it.
		if _CORE_TABLE.has(mod):
			return _CORE_TABLE[mod]
	# 2 or 5 with no real 3rd → sus substitute.
	if (mod == 2 or mod == 5) and not has_third:
		if _SUS_AS_THIRD.has(mod):
			return _SUS_AS_THIRD[mod]
	# Otherwise it's an extension (9 / 11 / 13 family or chromatic alteration).
	if _EXTENSION_TABLE.has(mod):
		return _EXTENSION_TABLE[mod]
	# Fallback — keep walkthrough usable even on exotic recognizer output.
	return ["?%d" % semitones, "Interval +%d" % semitones, "?", ""]


# Returns true if any interval (mod 12) lands on a real 3rd (m3=3 or M3=4).
static func _intervals_have_third(intervals: Array) -> bool:
	for iv in intervals:
		var mod: int = ((int(iv) % 12) + 12) % 12
		if mod == 3 or mod == 4:
			return true
	return false


# Tertian-stack sort key. Lower = earlier in the walkthrough.
# Root → 3rd / sus → 5th → 6th / 7th → extensions (9 → ♭9 → ♯9 → 11 → ♯11 → ♭13 → 13).
static func _tertian_sort_key(iv: int, has_third: bool) -> int:
	if iv == 0:
		return 0
	var mod: int = ((iv % 12) + 12) % 12
	# 3rd slot — real 3rds always claim it.
	if mod == 3 or mod == 4:
		return 100
	# sus2 / sus4 only claim the 3rd slot when no real 3rd is present.
	if (mod == 2 or mod == 5) and not has_third:
		return 100
	# 5th slot.
	if mod == 6 or mod == 7 or mod == 8:
		return 200
	# 6th / 7th slot.
	if mod == 9 or mod == 10 or mod == 11:
		return 300
	# Extensions — ordered by 9 family, then 11, then 13.
	# 1=♭9, 2=9, 3=♯9 (mod 3 captured above as 3rd; only hits here when has_third
	# and we have a separate raw interval at mod 3 — handled by sort).
	if mod == 1: return 401
	if mod == 2: return 402  # 9 (when real 3rd present)
	if mod == 3: return 403  # ♯9 fallback path (rare; usually claimed at 100)
	if mod == 5: return 411  # 11 (when real 3rd present)
	if mod == 6: return 412
	if mod == 8: return 421
	if mod == 9: return 422
	return 999


# ---------------------------------------------------------------------------
# Key / function helpers.
# ---------------------------------------------------------------------------


static func _key_degree_label(semi_from_tonic: int, is_minor: bool) -> String:
	var table := _DEGREE_MINOR if is_minor else _DEGREE_MAJOR
	return str(table.get(semi_from_tonic, "?"))


static func _spell_pc(pc: int, uses_flats: bool) -> String:
	const SHARP_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	const FLAT_NAMES  := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
	pc = ((pc % 12) + 12) % 12
	return FLAT_NAMES[pc] if uses_flats else SHARP_NAMES[pc]


static func _function_in_key(root_pc: int, key_pc: int, key_is_minor: bool, quality_short: String) -> String:
	var degree_semi: int = ((root_pc - key_pc) % 12 + 12) % 12
	var family: String = _quality_family(quality_short)
	var key: Array = [degree_semi, key_is_minor, family]
	if _FUNCTION_ROLES.has(key):
		return str(_FUNCTION_ROLES[key])
	var roman: String = _roman_for(degree_semi, key_is_minor, family)
	if roman == "":
		return ""
	return "%s — built on degree %s of the key." % [roman, _key_degree_label(degree_semi, key_is_minor)]


# Returns a generic headline when the recognizer's quality_short isn't in
# the hand-authored table — better than a blank line on exotic chords.
static func _fallback_headline(quality_short: String) -> String:
	if quality_short == "":
		return ""
	return "%s chord — explore the stack of intervals below." % quality_short


# Buckets recognizer quality_short into a broad function family for the
# roman-numeral / role lookup.
static func _quality_family(quality_short: String) -> String:
	# Dominant family — anything with a ♭7 over a major-ish triad.
	if quality_short in ["7", "9", "11", "13", "7b5", "7b9", "7#9", "7b13", "aug7"]:
		return "dom7"
	# Sus dominants behave dominant-ish for function purposes.
	if quality_short in ["7sus4", "9sus4"]:
		return "dom7"
	# Diminished family.
	if quality_short in ["dim", "dim7", "m7b5"]:
		return "dim"
	# Augmented family.
	if quality_short in ["aug", "augMaj7"]:
		return "aug"
	# Minor family.
	if quality_short in ["Minor", "m6", "m7", "m9", "madd9", "m11", "mMaj7"]:
		return "min"
	# Sus chords without ♭7 — treat as major-ish for function lookup.
	if quality_short in ["sus2", "sus4", "sus4(no5)"]:
		return "maj"
	# Power chord / unclassified — treat as major.
	if quality_short == "5":
		return "maj"
	# Default = major family.
	return "maj"


# Crude roman-numeral fallback used when no entry exists in _FUNCTION_ROLES.
static func _roman_for(degree_semi: int, is_minor_key: bool, family: String) -> String:
	const NUMERALS_MAJOR := {0: "I", 2: "ii", 4: "iii", 5: "IV", 7: "V", 9: "vi", 11: "vii"}
	const NUMERALS_MINOR := {0: "i", 2: "ii", 3: "III", 5: "iv", 7: "v", 8: "VI", 10: "VII"}
	const FLAT_NUMERALS := {1: "♭II", 3: "♭III", 6: "♭V", 8: "♭VI", 10: "♭VII"}
	var base_table = NUMERALS_MINOR if is_minor_key else NUMERALS_MAJOR
	var base: String = str(base_table.get(degree_semi, FLAT_NUMERALS.get(degree_semi, "")))
	if base == "":
		return ""
	if family == "min" or family == "dim":
		base = base.to_lower()
	else:
		base = base.to_upper()
	if family == "dom7":
		base += "7"
	elif family == "dim":
		base += "°"
	return base
