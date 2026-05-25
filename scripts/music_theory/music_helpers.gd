class_name MusicHelpers
extends RefCounted

# Cross-cutting pure music helpers used across many ear-training and
# sight-reading code paths. All static; no instance state.


const _INTERVAL_DISPLAY_NAMES := {
	"P1": "Unison", "m2": "Minor 2nd", "M2": "Major 2nd",
	"m3": "Minor 3rd", "M3": "Major 3rd", "P4": "Perfect 4th",
	"TT": "Tritone", "P5": "Perfect 5th", "m6": "Minor 6th",
	"M6": "Major 6th", "m7": "Minor 7th", "M7": "Major 7th",
	"P8": "Octave",
}

const _SEMITONES_TO_INTERVAL_ID := [
	"P1", "m2", "M2", "m3", "M3", "P4", "TT", "P5",
	"m6", "M6", "m7", "M7", "P8",
]

const _PITCH_CLASS_NAMES := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]

const _ROOT_PC := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

# Standard chord-tone semitone offsets keyed by family id. Used by
# chord_hint_meta to expose the basic skeleton of a quality.
const _CHORD_HINT_INTERVALS := {
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


static func inversion_name(inversion: int) -> String:
	match inversion:
		1: return "1st Inversion"
		2: return "2nd Inversion"
		3: return "3rd Inversion"
		_: return "Root Position"


static func interval_display_name(interval_id: String) -> String:
	return _INTERVAL_DISPLAY_NAMES.get(interval_id, interval_id)


# Map a semitone delta to the canonical interval id. Out-of-range values
# fall back to "P1" (caller's responsibility to normalize before calling).
static func interval_id_for_semitones(semitones: int) -> String:
	if semitones < 0 or semitones >= _SEMITONES_TO_INTERVAL_ID.size():
		return "P1"
	return _SEMITONES_TO_INTERVAL_ID[semitones]


static func midi_pitch_class_name(midi: int) -> String:
	return _PITCH_CLASS_NAMES[posmod(midi, 12)]


# Map a free-form chord quality name (e.g. "Maj7", "min7", "Augmented") to
# the canonical lowercase family id used by hint banks / explanations /
# CHORD_HINT_INTERVALS. Order matters: longer/more-specific strings come
# first so substrings don't shadow them.
static func chord_family_id_from_name(quality_name: String) -> String:
	var q := quality_name.to_lower()
	if q == "augmaj7" or q.find("augmaj7") >= 0:
		return "augmaj7"
	if q == "aug7" or q.find("aug7") >= 0:
		return "aug7"
	if q == "mmaj7" or q.find("mmaj7") >= 0:
		return "mmaj7"
	if q == "half-dim" or q.find("half-dim") >= 0 or q.find("m7b5") >= 0:
		return "halfdim"
	if q.find("dim7") >= 0 or q.find("diminished 7") >= 0:
		return "dim7"
	if q == "maj9" or q.find("maj9") >= 0:
		return "maj9"
	if q == "min9" or q.find("min9") >= 0:
		return "min9"
	if q == "dom9" or q.find("dom9") >= 0:
		return "dom9"
	if q == "add9" or q.find("add9") >= 0:
		return "add9"
	if q.find("maj7") >= 0 or q.find("major 7") >= 0:
		return "maj7"
	if q.find("min7") >= 0 or q.find("minor 7") >= 0:
		return "min7"
	if q.find("dom7") >= 0 or q.find("dominant 7") >= 0:
		return "dom7"
	if q == "7sus4" or q.find("7sus4") >= 0:
		return "7sus4"
	if q == "6/9" or q.find("6/9") >= 0:
		return "69"
	if q == "maj6" or q.find("maj6") >= 0:
		return "maj6"
	if q == "min6" or q.find("min6") >= 0:
		return "min6"
	if q.find("power") >= 0:
		return "power"
	if q.find("aug") >= 0:
		return "aug"
	if q.find("dim") >= 0:
		return "dim"
	if q.find("sus2") >= 0:
		return "sus2"
	if q.find("sus4") >= 0 or q.find("sus") >= 0:
		return "sus4"
	if q.find("min") >= 0 or q.find("minor") >= 0:
		return "minor"
	if q == "5":
		return "power"
	return "major"


# Returns {intervals: Array[int], family: String} for the given quality.
static func chord_hint_meta(quality_name: String) -> Dictionary:
	var family := chord_family_id_from_name(quality_name)
	return {"intervals": _CHORD_HINT_INTERVALS.get(family, [0, 4, 7]), "family": family}


# Parse the root of a chord name string (e.g. "C", "F# Major", "Bb min7")
# and return its MIDI pitch in the C4 octave. Returns 60 (C4) for unparseable input.
static func parse_root_midi_from_chord_name(chord_name: String) -> int:
	var t := chord_name.strip_edges()
	if t.is_empty():
		return 60
	var parts := t.split(" ", false)
	var root_token := parts[0] if not parts.is_empty() else "C"
	var base := root_token.substr(0, 1).to_upper()
	var semi: int = int(_ROOT_PC.get(base, 0))
	if root_token.find("#") >= 0:
		semi += 1
	if root_token.find("b") >= 0:
		semi -= 1
	return 60 + semi


# Returns the first letter (uppercased) of a note name. Falls back to "C"
# for empty/invalid input. Accepts the natural-letter set valid in either
# sharp or flat key signatures.
static func note_letter_from_name(note_name: String, valid_letters: Array) -> String:
	var t := note_name.strip_edges()
	if t.is_empty():
		return "C"
	var c := t.substr(0, 1).to_upper()
	if valid_letters.has(c):
		return c
	return "C"
