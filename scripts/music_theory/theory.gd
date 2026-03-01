class_name Theory
extends RefCounted

## Maps note spellings to pitch class (0..11).
const NOTE_TO_PC := {
	"C": 0, "C#": 1, "Db": 1,
	"D": 2, "D#": 3, "Eb": 3,
	"E": 4,
	"F": 5, "F#": 6, "Gb": 6,
	"G": 7, "G#": 8, "Ab": 8,
	"A": 9, "A#": 10, "Bb": 10,
	"B": 11
}

## Canonical pitch-class names with sharp spellings.
const PC_TO_NOTE_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
## Canonical pitch-class names with flat spellings.
const PC_TO_NOTE_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

## Scale/mode semitone steps from tonic.
const MODE_STEPS := {
	"Major": [0, 2, 4, 5, 7, 9, 11],
	"Natural Minor": [0, 2, 3, 5, 7, 8, 10],
	"Dorian": [0, 2, 3, 5, 7, 9, 10],
	"Mixolydian": [0, 2, 4, 5, 7, 9, 10]
}

## Triad quality mapping by Roman numeral in a major key.
## Values: "maj", "min", "dim"
const MAJOR_ROMAN_TRIAD_QUALITY := {
	"I": "maj", "ii": "min", "iii": "min",
	"IV": "maj", "V": "maj", "vi": "min",
	"vii": "dim"
}

## Roman numeral to scale degree in a major key.
const ROMAN_TO_DEGREE := {
	"I": 1, "ii": 2, "iii": 3, "IV": 4, "V": 5, "vi": 6, "vii": 7
}

## Progression presets in Roman numerals.
const PROGRESSIONS := {
	"IVviIV": ["I", "V", "vi", "IV"],
	"iiVI": ["ii", "V", "I"],
	"IIVVI": ["I", "IV", "V", "I"],
	"viIVIV": ["vi", "IV", "I", "V"]
}

## Cadence presets in Roman numeral pairs.
const CADENCES := {
	"Perfect": ["V", "I"],
	"Imperfect": ["V", "I"],
	"Plagal": ["IV", "I"],
	"Half": ["I", "V"],
	"Deceptive": ["V", "vi"]
}


## Returns pitch class 0..11 for note names like "C", "Bb", "F#".
## Returns -1 for unknown inputs.
static func note_to_pc(note_name: String) -> int:
	var normalized := _normalize_note_name(note_name)
	if not NOTE_TO_PC.has(normalized):
		return -1
	return int(NOTE_TO_PC[normalized])


## Returns canonical note string for a pitch class.
## Uses sharps by default; set prefer_flats=true to use flats.
static func pc_to_note(pc: int, prefer_flats: bool = false) -> String:
	var wrapped := wrap_pc(pc)
	return PC_TO_NOTE_FLAT[wrapped] if prefer_flats else PC_TO_NOTE_SHARP[wrapped]


## Converts pitch class + octave to MIDI number (C4 = 60).
static func pc_to_midi(pc: int, octave: int) -> int:
	return (octave + 1) * 12 + wrap_pc(pc)


## Safely wraps an integer to pitch class range 0..11.
static func wrap_pc(pc: int) -> int:
	return (pc % 12 + 12) % 12


## Transposes a pitch class by semitones and wraps to 0..11.
static func transpose_pc(root_pc: int, semitones: int) -> int:
	return wrap_pc(root_pc + semitones)


## Builds one-octave scale MIDI notes from root + mode.
## If asc_desc is true, appends descending notes without repeating top note.
static func build_scale_midi(root_note: String, mode_name: String, octave: int = 4, asc_desc: bool = false) -> Array[int]:
	if not MODE_STEPS.has(mode_name):
		return []
	var root_pc := note_to_pc(root_note)
	if root_pc < 0:
		return []
	var notes: Array[int] = []
	for step_value in MODE_STEPS[mode_name]:
		var step := int(step_value)
		notes.append(pc_to_midi(transpose_pc(root_pc, step), octave))
	if asc_desc and notes.size() > 1:
		var down := notes.duplicate()
		down.reverse()
		down.remove_at(0)
		notes.append_array(down)
	return notes


## Builds a triad chord from Roman numeral in a major key.
## Example: build_triad_midi("C", "V", 4) -> [67, 71, 74] (G-B-D)
static func build_triad_midi(key_root: String, roman: String, octave: int = 4) -> Array[int]:
	if not ROMAN_TO_DEGREE.has(roman):
		return []
	if not MAJOR_ROMAN_TRIAD_QUALITY.has(roman):
		return []
	var key_pc := note_to_pc(key_root)
	if key_pc < 0:
		return []
	var major_steps: Array = MODE_STEPS["Major"]
	var degree := int(ROMAN_TO_DEGREE[roman]) # 1..7
	var chord_root_pc := transpose_pc(key_pc, int(major_steps[degree - 1]))
	var quality := str(MAJOR_ROMAN_TRIAD_QUALITY[roman])
	var intervals: Array[int] = []
	match quality:
		"maj":
			intervals = [0, 4, 7]
		"min":
			intervals = [0, 3, 7]
		"dim":
			intervals = [0, 3, 6]
		_:
			return []
	var notes: Array[int] = []
	for iv in intervals:
		notes.append(pc_to_midi(transpose_pc(chord_root_pc, iv), octave))
	return notes


## Builds selected seventh chords.
## Supported roman inputs: "V7", "ii7", "Imaj7".
## Falls back to triad for unsupported labels.
static func build_seventh_midi(key_root: String, roman: String, octave: int = 4) -> Array[int]:
	var key_pc := note_to_pc(key_root)
	if key_pc < 0:
		return []
	var root_roman := ""
	var intervals: Array[int] = []
	match roman:
		"V7":
			root_roman = "V"
			intervals = [0, 4, 7, 10]
		"ii7":
			root_roman = "ii"
			intervals = [0, 3, 7, 10]
		"Imaj7":
			root_roman = "I"
			intervals = [0, 4, 7, 11]
		_:
			return build_triad_midi(key_root, roman, octave)
	if not ROMAN_TO_DEGREE.has(root_roman):
		return []
	var major_steps: Array = MODE_STEPS["Major"]
	var degree := int(ROMAN_TO_DEGREE[root_roman])
	var chord_root_pc := transpose_pc(key_pc, int(major_steps[degree - 1]))
	var notes: Array[int] = []
	for iv in intervals:
		notes.append(pc_to_midi(transpose_pc(chord_root_pc, iv), octave))
	return notes


## Builds progression chords from preset name.
## Returns array of chords (each chord is Array[int] MIDI notes).
static func build_progression_chords(key_root: String, progression_name: String, octave: int = 4, triads_only: bool = true) -> Array[Array[int]]:
	var numerals: Array = PROGRESSIONS.get(progression_name, [])
	var out: Array[Array[int]] = []
	for numeral_value in numerals:
		var numeral := str(numeral_value)
		var chord: Array[int] = []
		if triads_only:
			chord = build_triad_midi(key_root, numeral, octave)
		else:
			var seventh_label := _seventh_label_for_roman(numeral)
			if seventh_label != "":
				chord = build_seventh_midi(key_root, seventh_label, octave)
			if chord.is_empty():
				chord = build_triad_midi(key_root, numeral, octave)
		if chord.is_empty():
			return []
		out.append(chord)
	return out


## Builds cadence chords from cadence type.
## Returns exactly 2 chords when cadence type is valid.
static func build_cadence_chords(key_root: String, cadence_type: String, octave: int = 4, triads_only: bool = true) -> Array[Array[int]]:
	var pair: Array = CADENCES.get(cadence_type, [])
	if pair.size() < 2:
		return []
	var out: Array[Array[int]] = []
	for i in range(2):
		var roman := str(pair[i])
		var chord: Array[int] = []
		if triads_only:
			chord = build_triad_midi(key_root, roman, octave)
		else:
			var seventh_label := _seventh_label_for_roman(roman)
			if seventh_label != "":
				chord = build_seventh_midi(key_root, seventh_label, octave)
			if chord.is_empty():
				chord = build_triad_midi(key_root, roman, octave)
		if chord.is_empty():
			return []
		out.append(chord)
	return out


## Manual examples for quick debugging.
## Not called automatically.
static func _debug_examples() -> Dictionary:
	return {
		"scale_c_major": build_scale_midi("C", "Major", 4, false),
		"cadence_perfect_c": build_cadence_chords("C", "Perfect", 4, true),
		"progression_iiVI_c": build_progression_chords("C", "iiVI", 4, true)
	}


## Normalizes note spelling key for NOTE_TO_PC lookup.
static func _normalize_note_name(note_name: String) -> String:
	var raw := note_name.strip_edges()
	if raw.is_empty():
		return raw
	var head := raw.substr(0, 1).to_upper()
	var tail := ""
	if raw.length() > 1:
		tail = raw.substr(1, raw.length() - 1).replace("♭", "b").replace("♯", "#")
	return head + tail


## Returns optional seventh-chord label for supported Roman numerals.
static func _seventh_label_for_roman(roman: String) -> String:
	match roman:
		"V":
			return "V7"
		"ii":
			return "ii7"
		"I":
			return "Imaj7"
		_:
			return ""
