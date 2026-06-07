extends RefCounted
class_name JazzComposer

# Jazz-specific drill patterns generated procedurally from the key.
# All patterns are foundational jazz-pedagogy constructs (ii-V-I cadence,
# stride bass, walking bass) — no copyrighted source material. The
# composer builds them per-key + per-quality from scratch.
#
# Pedagogical references for the patterns chosen:
# - ii-V-I major (Dm7 → G7 → Cmaj7 in C) — foundational jazz cadence
#   covered in every jazz piano method.
# - ii-V-i minor (Dm7♭5 → G7♭9 → Cm7 in C minor) — minor counterpart.
# - Stride bass (bass note on 1+3, chord on 2+4) — early jazz/ragtime
#   left-hand pattern (Joplin, James P. Johnson, Fats Waller era).
# - Walking bass (quarter-note bass line through chord changes) — bebop
#   double-bass pedagogy adapted for piano left hand.

const PatternPrimitivesScript = preload("res://scripts/exercises/patterns/pattern_primitives.gd")
const SequenceTransformsScript = preload("res://scripts/exercises/patterns/sequence_transforms.gd")


# ii-V-I in major. Dm7 → G7 → Cmaj7 when key_pc=0. Each chord = 1 bar,
# rooted voicing (root + 3 + 5 + 7). Total 3 bars, padded to 4 with the
# final Cmaj7 sustained one extra bar so the resolution rings.
static func generate_ii_v_i_major(key_pc: int, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.MAJOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var notes: Array = []
	var beat: float = 0.0
	# Chord qualities for ii-V-I major: ii=min7, V=dom7, I=maj7.
	# Per chord we just stack scale degrees [root, +2, +4, +6] and adjust
	# specific intervals via direct semitone tweaks.
	#
	# ii m7 (Dm7 = D F A C): scale-built degrees 2,4,6,1
	# V 7  (G7  = G B D F): scale-built degrees 5,7,2,4
	# I M7 (Cmaj7 = C E G B): scale-built degrees 1,3,5,7
	# All three naturally diatonic in major — clean.
	var chord_specs: Array = [
		{"label": "iim7",  "degrees": [2, 4, 6, 8]},
		{"label": "V7",    "degrees": [5, 7, 9, 11]},
		{"label": "Imaj7", "degrees": [1, 3, 5, 7]},
	]
	for spec in chord_specs:
		var pitches: Array = PatternPrimitivesScript.degrees_to_midi(spec["degrees"], key_pc, scale, base_midi)
		for p in pitches:
			notes.append({
				"midi": int(p),
				"duration_beats": 4.0,
				"beat_offset": beat,
				"rest": false,
			})
		beat += 4.0
	# Hold the I-chord one extra bar so the ear resolves before the loop ends.
	var hold_pitches: Array = PatternPrimitivesScript.degrees_to_midi([1, 3, 5, 7], key_pc, scale, base_midi)
	for p in hold_pitches:
		notes.append({
			"midi": int(p),
			"duration_beats": 4.0,
			"beat_offset": beat,
			"rest": false,
		})
	beat += 4.0
	return _wrap("jazz_ii_v_i_major", "Jazz ii-V-I (Major)", key_pc, false, hand, tempo_bpm, notes, beat)


# ii-V-i in minor. Dm7♭5 → G7♭9 → Cm7 when key_pc=0 + minor. We construct
# the altered tones explicitly via semitone offsets from natural minor.
static func generate_ii_v_i_minor(key_pc: int, hand: String = "right", tempo_bpm: int = 80) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE
	var base_midi: int = 48 if hand == "left" else 60
	var notes: Array = []
	var beat: float = 0.0
	# In C minor: ii° in natural minor is Dm7♭5 (D F Ab C) — built from
	# scale degrees [2, 4, 6, 1].
	# V7♭9 (G B D F Ab) — V is built from harmonic-minor concept: root +
	# major 3 + 5 + minor 7 + minor 9 (Ab). We add the explicit ♭9 (Ab)
	# above the root via +1 semitone over the 9th-degree (which in C
	# minor's natural scale would be D = degree 2 == 9 octave-displaced).
	# For simplicity we build V7 = [5, 7-natural-raised-to-major, 2, 4]
	# (i.e., V dominant of the minor key — major 3rd via harmonic minor).
	# i m7 (Cm7 = C Eb G Bb) — degrees [1, 3, 5, 7] in natural minor.
	var iim7b5: Array = PatternPrimitivesScript.degrees_to_midi([2, 4, 6, 8], key_pc, scale, base_midi)
	# V7 dominant: build from major-tonic of the relative dominant key.
	# Cleaner: hand-build G7 voicing relative to key_pc.
	var v_root_midi: int = base_midi + ((key_pc + 7) % 12)  # 5th scale degree of minor
	var v7: Array = [
		v_root_midi,                  # root
		v_root_midi + 4,              # major 3rd (harmonic minor raises this)
		v_root_midi + 7,              # 5th
		v_root_midi + 10,             # ♭7
	]
	# Add the ♭9 a half-step above the octave for the b9 colour.
	v7.append(v_root_midi + 13)
	var im7: Array = PatternPrimitivesScript.degrees_to_midi([1, 3, 5, 7], key_pc, scale, base_midi)
	var chord_pitch_arrays: Array = [iim7b5, v7, im7]
	for chord in chord_pitch_arrays:
		for p in chord:
			notes.append({
				"midi": int(p),
				"duration_beats": 4.0,
				"beat_offset": beat,
				"rest": false,
			})
		beat += 4.0
	# Hold the i chord one extra bar.
	for p in im7:
		notes.append({
			"midi": int(p),
			"duration_beats": 4.0,
			"beat_offset": beat,
			"rest": false,
		})
	beat += 4.0
	return _wrap("jazz_ii_v_i_minor", "Jazz ii-V-i (Minor)", key_pc, true, hand, tempo_bpm, notes, beat)


# Stride bass — left-hand pattern: low bass note on beats 1 and 3, mid-
# register chord on beats 2 and 4. Walks through I, V, vi, IV (popular
# stride-friendly progression) for 4 bars. Hand defaults left.
static func generate_stride_bass(key_pc: int, key_is_minor: bool, hand: String = "left", tempo_bpm: int = 100) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var bass_base: int = 36 if hand == "left" else 48
	var chord_base: int = bass_base + 24   # two octaves up for the chord
	var notes: Array = []
	var beat: float = 0.0
	var progression: Array = [1, 5, 6, 4]
	for root_deg in progression:
		var root_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg], key_pc, scale, bass_base)[0])
		var fifth_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg + 4], key_pc, scale, bass_base)[0])
		var triad_pitches: Array = PatternPrimitivesScript.degrees_to_midi(
			[root_deg, root_deg + 2, root_deg + 4], key_pc, scale, chord_base)
		# Beat 1: bass root (quarter)
		notes.append({"midi": root_midi, "duration_beats": 1.0, "beat_offset": beat, "rest": false})
		# Beat 2: chord (3 notes, quarter)
		for p in triad_pitches:
			notes.append({"midi": int(p), "duration_beats": 1.0, "beat_offset": beat + 1.0, "rest": false})
		# Beat 3: bass fifth (quarter)
		notes.append({"midi": fifth_midi, "duration_beats": 1.0, "beat_offset": beat + 2.0, "rest": false})
		# Beat 4: chord (3 notes, quarter)
		for p in triad_pitches:
			notes.append({"midi": int(p), "duration_beats": 1.0, "beat_offset": beat + 3.0, "rest": false})
		beat += 4.0
	var stride_dict: Dictionary = _wrap("jazz_stride_bass", "Stride Bass (I-V-vi-IV)", key_pc, key_is_minor, hand, tempo_bpm, notes, beat)
	# Stride idiom: the LH leaps ~2 octaves between the low bass note and the
	# mid-register chord. That's the defining (and playable) gesture, so allow it.
	stride_dict["max_jump"] = 32
	return stride_dict


# Walking bass — quarter-note bass line through I, vi, ii, V (jazz turnaround).
# Each bar walks: root → approach tone → next root via diatonic step or
# chromatic neighbor. Bebop-pedagogy template, generic to any key.
static func generate_walking_bass(key_pc: int, key_is_minor: bool, hand: String = "left", tempo_bpm: int = 100) -> Dictionary:
	var scale: Array = PatternPrimitivesScript.NATURAL_MINOR_SCALE if key_is_minor else PatternPrimitivesScript.MAJOR_SCALE
	var bass_base: int = 36 if hand == "left" else 48
	# Turnaround: I → vi → ii → V → back to I (last beat of bar 4 = leading
	# tone walking into the I).
	var roots: Array = [1, 6, 2, 5]
	var notes: Array = []
	var beat: float = 0.0
	for bar_idx in range(roots.size()):
		var root_deg: int = roots[bar_idx]
		var next_root_deg: int = roots[(bar_idx + 1) % roots.size()]
		var root_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg], key_pc, scale, bass_base)[0])
		var third_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg + 2], key_pc, scale, bass_base)[0])
		var fifth_midi: int = int(PatternPrimitivesScript.degrees_to_midi([root_deg + 4], key_pc, scale, bass_base)[0])
		var next_root_midi: int = int(PatternPrimitivesScript.degrees_to_midi([next_root_deg], key_pc, scale, bass_base)[0])
		# Approach tone (chromatic) — half step below the next root.
		var approach_midi: int = next_root_midi - 1
		# Quarter-note line: root, 3rd, 5th, chromatic-approach to next root.
		var bar_pitches: Array = [root_midi, third_midi, fifth_midi, approach_midi]
		for p in bar_pitches:
			notes.append({"midi": int(p), "duration_beats": 1.0, "beat_offset": beat, "rest": false})
			beat += 1.0
	var walk_dict: Dictionary = _wrap("jazz_walking_bass", "Walking Bass — Turnaround", key_pc, key_is_minor, hand, tempo_bpm, notes, beat)
	# Walking lines reset register at bar/turnaround boundaries (a 5th/6th leap
	# down to the next root's approach tone) — allow a little above the melodic
	# default so the idiomatic register reset isn't flagged.
	walk_dict["max_jump"] = 16
	return walk_dict


# --- Internal helpers (shared with ChordComposer; duplicated to avoid
# cross-file coupling for these small functions) ---


static func _wrap(type_str: String, label: String, key_pc: int, key_is_minor: bool, hand: String, tempo_bpm: int, notes: Array, total_beats: float) -> Dictionary:
	var fifths: int = _key_to_fifths(key_pc, key_is_minor)
	var key_letter: String = _spell_key_letter(key_pc, fifths)
	var minor_label: String = "Minor" if key_is_minor else "Major"
	return {
		"title": "%s %s — %s" % [key_letter, minor_label, label],
		"exercise_type": type_str,
		"key_pc": key_pc,
		"key_is_minor": key_is_minor,
		"key_letter": key_letter,
		"level": 5,
		"tempo_bpm": tempo_bpm,
		"time_sig_num": 4,
		"time_sig_den": 4,
		"octaves": 1,
		"hand": hand,
		"fifths": fifths,
		"notes": notes,
		"total_beats": total_beats,
	}


static func _key_to_fifths(pc: int, is_minor: bool) -> int:
	var maj_fifths := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6, 1: -5, 8: -4, 3: -3, 10: -2, 5: -1}
	var pc_norm := ((pc % 12) + 12) % 12
	if is_minor:
		var rel_pc: int = ((pc_norm + 3) % 12 + 12) % 12
		return int(maj_fifths.get(rel_pc, 0))
	return int(maj_fifths.get(pc_norm, 0))


static func _spell_key_letter(pc: int, fifths: int) -> String:
	const SHARP := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	const FLAT  := ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
	var pc_norm := ((pc % 12) + 12) % 12
	return FLAT[pc_norm] if fifths < 0 else SHARP[pc_norm]
