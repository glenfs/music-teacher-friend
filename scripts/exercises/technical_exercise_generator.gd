extends RefCounted
class_name TechnicalExerciseGenerator

const HanonComposerScript = preload("res://scripts/exercises/composers/hanon_composer.gd")
const ScaleComposerScript = preload("res://scripts/exercises/composers/scale_composer.gd")
const CzernyComposerScript = preload("res://scripts/exercises/composers/czerny_composer.gd")
const ChordComposerScript = preload("res://scripts/exercises/composers/chord_composer.gd")
const JazzComposerScript = preload("res://scripts/exercises/composers/jazz_composer.gd")
const ExerciseLibraryScript = preload("res://scripts/exercises/exercise_library.gd")
const FingeringRulesScript = preload("res://scripts/exercises/fingering_rules.gd")

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


static func generate(exercise_type: String, key_pc: int, key_is_minor: bool, level: int = 1, hand: String = "right", octaves_override: int = -1, tempo_override: int = -1, seed: int = -1) -> Dictionary:
	var lvl: int = clampi(level, 1, 10)
	var preset: Dictionary = LEVEL_PRESETS.get(lvl, LEVEL_PRESETS[1])
	var octaves: int = octaves_override if octaves_override > 0 else int(preset["octaves"])
	var tempo: int = tempo_override if tempo_override > 0 else int(preset["tempo_bpm"])
	# Use the seed if provided so callers can reproduce a roll across runs;
	# templates ignore it but the field is plumbed end-to-end via _stamp_meta.
	var effective_seed: int = seed
	# Catalog mode dispatch. Generator entries route through a stochastic
	# sampler; templates use the deterministic path below.
	if ExerciseLibraryScript.is_generator(exercise_type):
		var rng := RandomNumberGenerator.new()
		if effective_seed < 0:
			effective_seed = int(Time.get_ticks_usec()) & 0x7fffffff
		rng.seed = effective_seed
		var profile: Dictionary = ExerciseLibraryScript.style_profile_for_id(exercise_type)
		var entry_dict: Dictionary = ExerciseLibraryScript.entry(exercise_type)
		var kind: String = str(entry_dict.get("kind", ""))
		var hand_norm_gen: String = "right" if hand == "both" else hand
		var ex_gen: Dictionary = {}
		match kind:
			"hanon":
				ex_gen = HanonComposerScript.generate_random(profile, key_pc, key_is_minor, lvl, tempo, hand_norm_gen, rng, exercise_type)
			"hanon_any":
				# Roll picks between the 5-finger and alternating-fingers style profiles.
				var picked: Dictionary = HanonComposerScript.STYLE_5_FINGER if (rng.randi() & 1) == 0 else HanonComposerScript.STYLE_ALTERNATING_FINGERS
				ex_gen = HanonComposerScript.generate_random(picked, key_pc, key_is_minor, lvl, tempo, hand_norm_gen, rng, exercise_type)
			"czerny":
				ex_gen = CzernyComposerScript.generate_random(profile, key_pc, key_is_minor, lvl, tempo, hand_norm_gen, octaves, rng, exercise_type)
			"scale":
				ex_gen = ScaleComposerScript.generate_random(profile, key_pc, key_is_minor, lvl, tempo, hand_norm_gen, octaves, rng, exercise_type)
			_:
				push_warning("[TechnicalExerciseGenerator] unknown generator kind '%s' for %s; falling through to template path." % [kind, exercise_type])
		if not ex_gen.is_empty():
			return _stamp_meta(ex_gen, effective_seed, exercise_type)
		# Otherwise fall through to the template path below.
	# Dispatch to Hanon composer for "hanon_N" types (N = exercise number).
	# Returns single-hand notes; the Practice Drills "Grand" mode calls this once
	# per hand and merges via its own logic.
	if exercise_type.begins_with("hanon_"):
		var num: int = int(exercise_type.substr(6))
		var hand_for_hanon: String = "right" if hand == "both" else hand
		return _stamp_meta(HanonComposerScript.generate(num, key_pc, key_is_minor, tempo, hand_for_hanon, false), effective_seed, exercise_type)
	# Scale variants (thirds, sixths, chromatic, contrary motion)
	var hand_norm: String = "right" if hand == "both" else hand
	match exercise_type:
		"scale_thirds":
			return _stamp_meta(ScaleComposerScript.generate_thirds(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"scale_sixths":
			return _stamp_meta(ScaleComposerScript.generate_sixths(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"scale_chromatic":
			return _stamp_meta(ScaleComposerScript.generate_chromatic(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"scale_contrary":
			return _stamp_meta(ScaleComposerScript.generate_contrary(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"czerny_velocity":
			return _stamp_meta(CzernyComposerScript.generate_velocity_run(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"czerny_alberti":
			return _stamp_meta(CzernyComposerScript.generate_alberti_etude(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"czerny_sequence":
			return _stamp_meta(CzernyComposerScript.generate_scale_sequence(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		# --- Smart Drill Library expansion: rhythmic variants ---
		"scale_16ths":
			return _stamp_meta(ScaleComposerScript.generate_scale_16ths(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"arpeggio_16ths":
			return _stamp_meta(ScaleComposerScript.generate_arpeggio_16ths(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"scale_triplets":
			return _stamp_meta(ScaleComposerScript.generate_scale_triplets(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"arpeggio_triplets":
			return _stamp_meta(ScaleComposerScript.generate_arpeggio_triplets(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		"bass_movement_16ths":
			return _stamp_meta(ScaleComposerScript.generate_bass_movement_16ths(key_pc, key_is_minor, octaves, hand_norm, tempo), effective_seed, exercise_type)
		# --- Simple chord exercises ---
		"chord_diatonic_triads":
			return _stamp_meta(ChordComposerScript.generate_diatonic_triads(key_pc, key_is_minor, hand_norm, tempo), effective_seed, exercise_type)
		"chord_progression_classical":
			return _stamp_meta(ChordComposerScript.generate_progression_classical(key_pc, key_is_minor, hand_norm, tempo), effective_seed, exercise_type)
		"chord_progression_pop":
			return _stamp_meta(ChordComposerScript.generate_progression_pop(key_pc, key_is_minor, hand_norm, tempo), effective_seed, exercise_type)
		"chord_diatonic_sevenths":
			return _stamp_meta(ChordComposerScript.generate_diatonic_sevenths(key_pc, key_is_minor, hand_norm, tempo), effective_seed, exercise_type)
		# --- Jazz exercises ---
		"jazz_ii_v_i_major":
			return _stamp_meta(JazzComposerScript.generate_ii_v_i_major(key_pc, hand_norm, tempo), effective_seed, exercise_type)
		"jazz_ii_v_i_minor":
			return _stamp_meta(JazzComposerScript.generate_ii_v_i_minor(key_pc, hand_norm, tempo), effective_seed, exercise_type)
		"jazz_stride_bass":
			return _stamp_meta(JazzComposerScript.generate_stride_bass(key_pc, key_is_minor, hand_norm, tempo), effective_seed, exercise_type)
		"jazz_walking_bass":
			return _stamp_meta(JazzComposerScript.generate_walking_bass(key_pc, key_is_minor, hand_norm, tempo), effective_seed, exercise_type)
	var pc: int = ((int(key_pc) % 12) + 12) % 12
	var key_letter: String = _spell_key_letter(pc, key_is_minor)
	var fifths: int = _key_to_fifths(pc, key_is_minor)
	var pitches: Array = []
	var fingerings: Array = []
	match exercise_type:
		"scale":
			pitches = _build_scale(pc, key_is_minor, octaves, hand)
			fingerings = FingeringRulesScript.scale_fingerings(fifths, key_is_minor, octaves, hand)
		"arpeggio":
			pitches = _build_arpeggio(pc, key_is_minor, octaves, hand)
			fingerings = FingeringRulesScript.arpeggio_fingerings(octaves, hand)
		"five_finger":
			pitches = _build_five_finger(pc, key_is_minor, hand)
			fingerings = FingeringRulesScript.five_finger_fingerings(hand)
		_:
			pitches = _build_scale(pc, key_is_minor, octaves, hand)
			fingerings = FingeringRulesScript.scale_fingerings(fifths, key_is_minor, octaves, hand)
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
		"seed": effective_seed,
		"generator_id": "",
	}


# Stamps catalog-level metadata onto an exercise dict returned by a composer.
# - `seed` rides along whether or not the composer used it (templates ignore it;
#   generators will read it once Phase 6 wires them up).
# - `generator_id` is empty for template entries; the generator path will set
#   it to the catalog ID that produced the sample.
# - `exercise_type` is filled in defensively in case a composer omits it.
static func _stamp_meta(ex: Dictionary, seed: int, exercise_type: String) -> Dictionary:
	if typeof(ex) != TYPE_DICTIONARY:
		return ex
	ex["seed"] = seed
	if not ex.has("generator_id"):
		ex["generator_id"] = ""
	if not ex.has("exercise_type"):
		ex["exercise_type"] = exercise_type
	return ex


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
