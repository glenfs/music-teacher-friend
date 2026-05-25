class_name PitchMatchTheory
extends RefCounted

# Pure music-theory helpers for Pitch Match mode (target-pitch ear training).
# Caller owns the live state (key, scale, level, label mode) and passes them
# in. This module knows nothing about UI or audio.


# Pitch-class names with flats for the black keys that are typically spelled
# as flats in tonal contexts. Used by note_label / display_label_for_midi.
const _PITCH_CLASS_NAMES := ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]


# Movable-do solfege keyed by semitone offset from the tonic. Flat/sharp
# alterations use the standard chromatic syllables.
const _SOLFEGE := {
	0: "Do", 1: "Ra", 2: "Re", 3: "Me", 4: "Mi", 5: "Fa",
	6: "Fi", 7: "Sol", 8: "Le", 9: "La", 10: "Te", 11: "Ti",
}


static func pitch_class_name(midi: int) -> String:
	return _PITCH_CLASS_NAMES[posmod(midi, 12)]


# Returns the pitch class (0..11) of the given key name. Falls back to C.
static func key_pc(pitch_match_key: String, key_options: Array) -> int:
	for opt in key_options:
		if str(opt[0]) == pitch_match_key:
			return int(opt[1])
	return 0


# Tonic MIDI = C4 + key_pc, so the default tonic is C4 (60).
static func tonic_midi(pitch_match_key: String, key_options: Array) -> int:
	return 60 + key_pc(pitch_match_key, key_options)


# Scale degrees (semitones from the tonic) for the active scale name.
static func scale_steps(scale_name: String, scale_mode_defs: Dictionary) -> Array[int]:
	var raw_steps: Array = scale_mode_defs.get(scale_name, scale_mode_defs["Major"])
	var steps: Array[int] = []
	for step_any in raw_steps:
		var step := int(step_any)
		if step >= 12:
			continue
		if not steps.has(step):
			steps.append(step)
	if steps.is_empty():
		steps = [0, 2, 4, 5, 7, 9, 11]
	return steps


# Level-restricted step pool:
#   L1 = tonic + 5th degree (dominant)
#   L2 = triad tones (1, 3, 5)
#   L3 = pentachord (1..5)
#   L4 = full diatonic
#   L5 = diatonic + chromatic borrows (b2, b3, #4/b5, b6, b7)
#   L6 = full chromatic (all 12 pitch classes)
static func level_steps(steps: Array[int], level: int) -> Array[int]:
	var lvl: int = clampi(level, 1, 6)
	match lvl:
		1:
			var out: Array[int] = []
			if steps.size() > 0:
				out.append(steps[0])
			if steps.size() > 4:
				out.append(steps[4])
			elif steps.size() > 0:
				out.append((steps[0] + 7) % 12)
			return out
		2:
			var out: Array[int] = []
			for i in [0, 2, 4]:
				if i < steps.size():
					out.append(steps[i])
			return out
		3:
			var out: Array[int] = []
			for i in range(mini(5, steps.size())):
				out.append(steps[i])
			return out
		4:
			return steps
		5:
			var chromatic_borrows: Array[int] = [1, 3, 6, 8, 10]
			var combined: Array[int] = []
			for s in steps:
				if not combined.has(s):
					combined.append(s)
			for s in chromatic_borrows:
				if not combined.has(s):
					combined.append(s)
			combined.sort()
			return combined
		6:
			return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
	return steps


static func level_label(level: int) -> String:
	match clampi(level, 1, 6):
		1: return "L1 — Tonic + 5th"
		2: return "L2 — Triad (1·3·5)"
		3: return "L3 — Pentachord (1–5)"
		4: return "L4 — Full Diatonic"
		5: return "L5 — Diatonic + Chromatic Borrows"
		6: return "L6 — Chromatic"
	return "L4 — Full Diatonic"


# "1", "♭3", "♯5" — labels a semitone offset relative to the current diatonic
# scale. Chromatic notes get a ♭/♯ alteration of the nearest scale degree.
static func degree_label_for_step(step: int, steps: Array[int]) -> String:
	var idx := steps.find(step)
	if idx >= 0:
		return str(idx + 1)
	var below: int = -1
	var above: int = -1
	for i in range(steps.size()):
		if steps[i] < step:
			below = i
		elif steps[i] > step and above == -1:
			above = i
	if below >= 0 and above >= 0:
		if absi(step - steps[above]) <= absi(step - steps[below]):
			return "♭%d" % (above + 1)
		return "♯%d" % (below + 1)
	if below >= 0:
		return "♯%d" % (below + 1)
	if above >= 0:
		return "♭%d" % (above + 1)
	return "?"


# Absolute note label with octave (e.g. C4).
static func note_label(midi: int) -> String:
	return "%s%d" % [pitch_class_name(midi), int(midi / 12 - 1)]


# Display label honoring the active label mode: "letter" | "solfege" | "degree".
static func display_label_for_midi(midi: int, mode: String, tonic: int, steps: Array[int]) -> String:
	if mode == "solfege":
		var off: int = posmod(midi - tonic, 12)
		return str(_SOLFEGE.get(off, "?"))
	if mode == "degree":
		var off2: int = posmod(midi - tonic, 12)
		return degree_label_for_step(off2, steps)
	return note_label(midi)


# I chord in the active key/scale. Minor scale uses ♭3.
static func tonic_triad(tonic: int, scale_name: String) -> Array[int]:
	var third := 3 if scale_name == "Natural Minor" else 4
	return [tonic, tonic + third, tonic + 7]


# I-IV-V-I cadence. V is always major (raised 7th in minor) for the leading-tone resolution.
static func cadence_chords(tonic: int, scale_name: String) -> Array:
	var is_minor: bool = scale_name == "Natural Minor"
	var third_i: int = 3 if is_minor else 4
	var third_iv: int = 3 if is_minor else 4
	var i_chord: Array[int] = [tonic, tonic + third_i, tonic + 7]
	var iv_chord: Array[int] = [tonic + 5, tonic + 5 + third_iv, tonic + 5 + 7]
	var v_chord: Array[int] = [tonic + 7, tonic + 7 + 4, tonic + 7 + 7]
	return [i_chord, iv_chord, v_chord, i_chord]
