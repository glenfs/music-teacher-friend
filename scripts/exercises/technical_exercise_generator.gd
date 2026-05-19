extends RefCounted
class_name TechnicalExerciseGenerator

const HanonComposerScript = preload("res://scripts/exercises/composers/hanon_composer.gd")
const ScaleComposerScript = preload("res://scripts/exercises/composers/scale_composer.gd")
const CzernyComposerScript = preload("res://scripts/exercises/composers/czerny_composer.gd")

# Generates technical practice exercises (scales, arpeggios, five-finger drills)
# at multiple difficulty levels. Output is a Dictionary that can be rendered
# by the in-app staff player AND encoded to MusicXML for export.
#
# Exercise dict shape:
#   {
#     "title": String,
#     "exercise_type": String,      # "scale" | "arpeggio" | "five_finger"
#     "key_pc": int (0-11),
#     "key_is_minor": bool,
#     "key_letter": String,         # e.g., "C", "F#", "Bb"
#     "level": int (1-10),
#     "tempo_bpm": int,
#     "time_sig_num": int,
#     "time_sig_den": int,
#     "octaves": int,
#     "hand": String,               # "right" | "left"
#     "fifths": int,                # MusicXML key signature (-7..7)
#     "notes": Array[Dictionary],   # each: {midi, duration_beats, beat_offset}
#     "total_beats": float,
#   }

const NOTE_NAMES_SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const NOTE_NAMES_FLAT := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
const SHARP_KEYS := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6}  # pc -> fifths
const FLAT_KEYS := {0: 0, 5: -1, 10: -2, 3: -3, 8: -4, 1: -5, 6: -6}
const MAJOR_SCALE := [0, 2, 4, 5, 7, 9, 11]
const NATURAL_MINOR_SCALE := [0, 2, 3, 5, 7, 8, 10]
const HARMONIC_MINOR_SCALE := [0, 2, 3, 5, 7, 8, 11]

const EXERCISE_TYPES := ["scale", "arpeggio", "five_finger"]

# Per-level defaults: { octaves, tempo_bpm }
const LEVEL_PRESETS := {
	1: {"octaves": 1, "tempo_bpm": 60},
	2: {"octaves": 1, "tempo_bpm": 72},
	3: {"octaves": 2, "tempo_bpm": 80},
	4: {"octaves": 2, "tempo_bpm": 92},
	5: {"octaves": 2, "tempo_bpm": 104},
	6: {"octaves": 3, "tempo_bpm": 100},
	7: {"octaves": 3, "tempo_bpm": 112},
	8: {"octaves": 3, "tempo_bpm": 120},
	9: {"octaves": 3, "tempo_bpm": 132},
	10: {"octaves": 3, "tempo_bpm": 144},
}


static func generate(exercise_type: String, key_pc: int, key_is_minor: bool, level: int = 1, hand: String = "right", octaves_override: int = -1, tempo_override: int = -1) -> Dictionary:
	var lvl: int = clampi(level, 1, 10)
	var preset: Dictionary = LEVEL_PRESETS.get(lvl, LEVEL_PRESETS[1])
	var octaves: int = octaves_override if octaves_override > 0 else int(preset["octaves"])
	var tempo: int = tempo_override if tempo_override > 0 else int(preset["tempo_bpm"])
	# Dispatch to Hanon composer for "hanon_N" types (N = exercise number).
	# Returns single-hand notes; the Practice Drills "Grand" mode calls this once
	# per hand and merges via its own logic.
	if exercise_type.begins_with("hanon_"):
		var num: int = int(exercise_type.substr(6))
		var hand_for_hanon: String = "right" if hand == "both" else hand
		return HanonComposerScript.generate(num, key_pc, key_is_minor, tempo, hand_for_hanon, false)
	# Scale variants (thirds, sixths, chromatic, contrary motion)
	var hand_norm: String = "right" if hand == "both" else hand
	match exercise_type:
		"scale_thirds":
			return ScaleComposerScript.generate_thirds(key_pc, key_is_minor, octaves, hand_norm, tempo)
		"scale_sixths":
			return ScaleComposerScript.generate_sixths(key_pc, key_is_minor, octaves, hand_norm, tempo)
		"scale_chromatic":
			return ScaleComposerScript.generate_chromatic(key_pc, key_is_minor, octaves, hand_norm, tempo)
		"scale_contrary":
			return ScaleComposerScript.generate_contrary(key_pc, key_is_minor, octaves, hand_norm, tempo)
		"czerny_velocity":
			return CzernyComposerScript.generate_velocity_run(key_pc, key_is_minor, octaves, hand_norm, tempo)
		"czerny_alberti":
			return CzernyComposerScript.generate_alberti_etude(key_pc, key_is_minor, octaves, hand_norm, tempo)
		"czerny_sequence":
			return CzernyComposerScript.generate_scale_sequence(key_pc, key_is_minor, octaves, hand_norm, tempo)
	var pc: int = ((int(key_pc) % 12) + 12) % 12
	var key_letter: String = _spell_key_letter(pc, key_is_minor)
	var fifths: int = _key_to_fifths(pc, key_is_minor)
	var pitches: Array = []
	var fingerings: Array = []
	match exercise_type:
		"scale":
			pitches = _build_scale(pc, key_is_minor, octaves, hand)
			fingerings = _scale_fingerings(octaves, hand)
		"arpeggio":
			pitches = _build_arpeggio(pc, key_is_minor, octaves, hand)
			fingerings = _arpeggio_fingerings(octaves, hand)
		"five_finger":
			pitches = _build_five_finger(pc, key_is_minor, hand)
			fingerings = _five_finger_fingerings(hand)
		_:
			pitches = _build_scale(pc, key_is_minor, octaves, hand)
			fingerings = _scale_fingerings(octaves, hand)
	# Convert pitches to a notes array with eighth-note durations.
	var notes: Array[Dictionary] = []
	var beat := 0.0
	var beat_per_note := 0.5  # eighth notes throughout
	for i in range(pitches.size()):
		var note_d: Dictionary = {
			"midi": int(pitches[i]),
			"duration_beats": beat_per_note,
			"beat_offset": beat,
		}
		if i < fingerings.size() and int(fingerings[i]) > 0:
			note_d["fingering"] = int(fingerings[i])
		notes.append(note_d)
		beat += beat_per_note
	# Pad to a full bar so MusicXML stays clean (4 beats per bar in 4/4).
	while int(beat) % 4 != 0:
		notes.append({"midi": -1, "duration_beats": beat_per_note, "beat_offset": beat, "rest": true})
		beat += beat_per_note
	var minor_label := "Minor" if key_is_minor else "Major"
	var type_label := exercise_type.capitalize().replace("_", " ")
	return {
		"title": "%s %s — %s (Level %d)" % [key_letter, minor_label, type_label, lvl],
		"exercise_type": exercise_type,
		"key_pc": pc,
		"key_is_minor": key_is_minor,
		"key_letter": key_letter,
		"level": lvl,
		"tempo_bpm": tempo,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"octaves": octaves,
		"hand": hand,
		"fifths": fifths,
		"notes": notes,
		"total_beats": beat,
	}


static func _build_scale(pc: int, key_is_minor: bool, octaves: int, hand: String) -> Array:
	var intervals: Array = NATURAL_MINOR_SCALE if key_is_minor else MAJOR_SCALE
	var base_midi: int = _hand_base_midi(hand)
	var pitches: Array = []
	for o in range(octaves):
		for s in intervals:
			pitches.append(base_midi + pc + o * 12 + int(s))
	pitches.append(base_midi + pc + octaves * 12)  # top tonic
	# Descend (skip the top duplicate)
	var descending: Array = pitches.duplicate()
	descending.reverse()
	descending = descending.slice(1)
	for d in descending:
		pitches.append(d)
	return pitches


static func _build_arpeggio(pc: int, key_is_minor: bool, octaves: int, hand: String) -> Array:
	var third: int = 3 if key_is_minor else 4
	var fifth: int = 7
	var base_midi: int = _hand_base_midi(hand)
	var pitches: Array = []
	for o in range(octaves):
		pitches.append(base_midi + pc + o * 12)            # 1
		pitches.append(base_midi + pc + o * 12 + third)    # 3
		pitches.append(base_midi + pc + o * 12 + fifth)    # 5
	pitches.append(base_midi + pc + octaves * 12)  # top 1
	var descending: Array = pitches.duplicate()
	descending.reverse()
	descending = descending.slice(1)
	for d in descending:
		pitches.append(d)
	return pitches


static func _build_five_finger(pc: int, key_is_minor: bool, hand: String) -> Array:
	# Five-finger pattern: 1-2-3-4-5 ascending then 4-3-2-1 descending.
	var intervals: Array = [0, 2, 3, 5, 7] if key_is_minor else [0, 2, 4, 5, 7]
	var base_midi: int = _hand_base_midi(hand)
	var pitches: Array = []
	for s in intervals:
		pitches.append(base_midi + pc + int(s))
	var descending: Array = pitches.duplicate()
	descending.reverse()
	descending = descending.slice(1)
	for d in descending:
		pitches.append(d)
	return pitches


static func _hand_base_midi(hand: String) -> int:
	# Right-hand exercises start at C4 (MIDI 60); left-hand starts an octave lower at C3 (MIDI 48).
	return 48 if hand == "left" else 60


# Standard piano scale fingerings (assumes C-major style — thumb-under every 4th note).
# Other key fingerings differ (Bb major LH starts on 4 e.g.), but for v1 this is correct
# for ~half the common keys and gives students a reasonable cue otherwise.
static func _scale_fingerings(octaves: int, hand: String) -> Array:
	# RH 1-octave ascending: 1-2-3-1-2-3-4-5 (8 fingers). RH descending (skip top): 4-3-2-1-3-2-1 (7).
	# For multi-octave: repeat the 1-3-1-3-4 pattern, with the 5th finger reserved for the very top.
	var result: Array = []
	var ascending_rh: Array = []
	for o in range(octaves):
		# Per octave 7 notes (the 8th = next octave's 1)
		var per_oct: Array = [1, 2, 3, 1, 2, 3, 4]
		for f in per_oct:
			ascending_rh.append(int(f))
	ascending_rh.append(5)  # top tonic finger
	if hand == "left":
		# LH is the mirror: 5-4-3-2-1-3-2-1 ascending, ending on thumb at top.
		# Build by reversing each "logical" finger group across the LH layout.
		var lh_asc: Array = []
		# LH ascending per octave: 5-4-3-2-1-3-2 (7 fingers per octave), ending on thumb at top.
		for o in range(octaves):
			var per_oct_lh: Array = [5, 4, 3, 2, 1, 3, 2]
			for f in per_oct_lh:
				lh_asc.append(int(f))
		lh_asc.append(1)  # thumb on top tonic for LH
		result = lh_asc
	else:
		result = ascending_rh
	# Build descending half (skip duplicate top — matches scale builder structure)
	var descending: Array = result.duplicate()
	descending.reverse()
	descending = descending.slice(1)
	for d in descending:
		result.append(int(d))
	return result


static func _arpeggio_fingerings(octaves: int, hand: String) -> Array:
	# RH 1-octave (4 notes 1-3-5-8): 1-2-3-5
	# RH 2-octave (7 notes): 1-2-3-1-2-3-5 (thumb-under between octaves)
	# LH 1-octave: 5-3-2-1 ascending
	# LH 2-octave: 5-3-2-1-3-2-1 ascending
	var result: Array = []
	if hand == "left":
		for o in range(octaves):
			result.append(5)
			result.append(3)
			result.append(2)
		result.append(1)
	else:
		for o in range(octaves):
			result.append(1)
			result.append(2)
			result.append(3)
		result.append(5)
	# Descending = reverse, skip top duplicate
	var descending: Array = result.duplicate()
	descending.reverse()
	descending = descending.slice(1)
	for d in descending:
		result.append(int(d))
	return result


static func _five_finger_fingerings(hand: String) -> Array:
	# 5 ascending notes + 4 descending (skipping top): 9 notes total
	if hand == "left":
		# LH 5-finger position has pinky on lowest note.
		return [5, 4, 3, 2, 1, 2, 3, 4, 5]
	return [1, 2, 3, 4, 5, 4, 3, 2, 1]


static func _key_to_fifths(pc: int, key_is_minor: bool) -> int:
	# Major: C=0, G=1, D=2, A=3, E=4, B=5, F#=6, F=-1, Bb=-2, Eb=-3, Ab=-4, Db=-5, Gb=-6
	# Minor: relative — A=0, E=1, B=2, F#=3, C#=4, G#=5, D#=6, D=-1, G=-2, C=-3, F=-4, Bb=-5, Eb=-6
	if key_is_minor:
		# Minor key fifths = (pc - 9 + 12) % 12 mapping to fifths circle
		var minor_map := {9: 0, 4: 1, 11: 2, 6: 3, 1: 4, 8: 5, 3: 6, 2: -1, 7: -2, 0: -3, 5: -4, 10: -5}
		if minor_map.has(pc):
			return int(minor_map[pc])
		return 0
	if SHARP_KEYS.has(pc):
		return int(SHARP_KEYS[pc])
	if FLAT_KEYS.has(pc):
		return int(FLAT_KEYS[pc])
	return 0


static func _spell_key_letter(pc: int, key_is_minor: bool) -> String:
	var pc_clamped := ((int(pc) % 12) + 12) % 12
	# Use sharps for sharp-circle keys, flats for flat-circle keys.
	if SHARP_KEYS.has(pc_clamped) and not (FLAT_KEYS.has(pc_clamped) and pc_clamped in [6]):
		return NOTE_NAMES_SHARP[pc_clamped]
	if FLAT_KEYS.has(pc_clamped):
		return NOTE_NAMES_FLAT[pc_clamped]
	return NOTE_NAMES_SHARP[pc_clamped]


# MIDI pitch -> [step ("C"/"D"/...), alter (-1/0/1), octave (int)]
# Spelling is key-aware: sharp keys prefer sharps, flat keys prefer flats.
static func midi_to_step_alter_octave(midi: int, fifths: int) -> Array:
	var pc := ((midi % 12) + 12) % 12
	var octave := int(floor(midi / 12.0)) - 1  # MIDI 60 = C4 -> octave 4
	var prefer_flats := fifths < 0
	if pc == 0:  return ["C", 0, octave]
	if pc == 2:  return ["D", 0, octave]
	if pc == 4:  return ["E", 0, octave]
	if pc == 5:  return ["F", 0, octave]
	if pc == 7:  return ["G", 0, octave]
	if pc == 9:  return ["A", 0, octave]
	if pc == 11: return ["B", 0, octave]
	# Black keys
	if prefer_flats:
		match pc:
			1:  return ["D", -1, octave]  # Db
			3:  return ["E", -1, octave]  # Eb
			6:  return ["G", -1, octave]  # Gb
			8:  return ["A", -1, octave]  # Ab
			10: return ["B", -1, octave]  # Bb
	match pc:
		1:  return ["C", 1, octave]   # C#
		3:  return ["D", 1, octave]   # D#
		6:  return ["F", 1, octave]   # F#
		8:  return ["G", 1, octave]   # G#
		10: return ["A", 1, octave]   # A#
	return ["C", 0, octave]
