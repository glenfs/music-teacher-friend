class_name SightSingingTheory
extends RefCounted

# Pure music-theory helpers for Sight Singing mode. Caller owns the live
# rhythm templates / durations array / melody array / RNG / key signature
# and passes them in. This module knows nothing about UI or audio.


# Phrase/detection timing constants used by the mic listener.
const END_SILENCE_SEC := 1.15
const MIN_PHRASE_SEC := 1.0
const SECONDS_PER_NOTE_LIMIT := 1.45

# Reference tempo for free-pace playback (0.42 sec per beat = 142 BPM).
# Used so half/whole notes feel proportionally longer than quarters even
# when the user is singing at their own tempo.
const REFERENCE_SECONDS_PER_BEAT := 0.42


const _SIGHT_SINGING_KEY_PC := {
	"C": 0,    # C major
	"1#": 7,   # G major
	"2#": 2,   # D major
	"3#": 9,   # A major
	"1b": 5,   # F major
	"2b": 10,  # Bb major
	"3b": 3,   # Eb major
}

const _SHARP_FIFTHS := {0: 0, 7: 1, 2: 2, 9: 3, 4: 4, 11: 5, 6: 6}
const _FLAT_FIFTHS := {5: -1, 10: -2, 3: -3, 8: -4, 1: -5}


# Pitch class (0..11) of the tonic for the given sight-singing key sig.
static func key_pc(sight_key_signature: String) -> int:
	return int(_SIGHT_SINGING_KEY_PC.get(sight_key_signature, 0))


# Tonic MIDI = C4 + key_pc, so melodies center around the middle of the staff.
static func tonic_midi(sight_key_signature: String) -> int:
	return 60 + key_pc(sight_key_signature)


# Major triad on the tonic — used as the audio reference before each round.
# Typed Array[int] so the caller's _play_chord_block accepts it.
static func tonic_triad(sight_key_signature: String) -> Array[int]:
	var t := tonic_midi(sight_key_signature)
	var triad: Array[int] = [t, t + 4, t + 7]
	return triad


# I-IV-V-I cadence in the active key. V is always major for the classic
# leading-tone resolution. Each inner chord is typed Array[int].
static func cadence_chords(sight_key_signature: String) -> Array:
	var t := tonic_midi(sight_key_signature)
	var i_chord: Array[int] = [t, t + 4, t + 7]
	var iv_chord: Array[int] = [t + 5, t + 5 + 4, t + 5 + 7]
	var v_chord: Array[int] = [t + 7, t + 7 + 4, t + 7 + 7]
	return [i_chord, iv_chord, v_chord, i_chord]


# MusicXML-style fifths count for the key signature (positive = sharps,
# negative = flats). Used by the score-model builder.
static func fifths(sight_key_signature: String) -> int:
	var pc: int = key_pc(sight_key_signature)
	if _SHARP_FIFTHS.has(pc):
		return int(_SHARP_FIFTHS[pc])
	if _FLAT_FIFTHS.has(pc):
		return int(_FLAT_FIFTHS[pc])
	return 0


# Rhythm templates per difficulty level. Each template is a duration-in-beats
# array applied to a 5-note melody. Level 1 = all quarters; level 2 = mix of
# quarter + half + whole; level 3 = adds eighth notes.
static func rhythm_templates(level: int) -> Array:
	match clampi(level, 1, 3):
		1:
			return [[1.0, 1.0, 1.0, 1.0, 1.0]]
		2:
			return [
				[1.0, 1.0, 1.0, 1.0, 2.0],
				[2.0, 1.0, 1.0, 2.0, 1.0],
				[1.0, 2.0, 1.0, 2.0, 1.0],
				[2.0, 2.0, 1.0, 1.0, 2.0],
				[1.0, 1.0, 2.0, 1.0, 4.0],
			]
		_:
			return [
				[0.5, 0.5, 1.0, 1.0, 2.0],
				[1.0, 0.5, 0.5, 1.0, 2.0],
				[0.5, 0.5, 0.5, 0.5, 2.0],
				[1.0, 1.0, 0.5, 0.5, 1.0],
				[2.0, 0.5, 0.5, 1.0, 1.0],
				[0.5, 0.5, 1.0, 2.0, 4.0],
			]


# Pick a rhythm template at the given level and fill out an `note_count`-long
# durations array. Each duration is at least 0.5 beats.
static func generate_durations(note_count: int, rhythm_level: int, rng: RandomNumberGenerator) -> Array[float]:
	var durations: Array[float] = []
	if note_count <= 0:
		return durations
	var templates := rhythm_templates(rhythm_level)
	var picked: Array = []
	if not templates.is_empty():
		picked = templates[rng.randi_range(0, templates.size() - 1)]
	for i in range(note_count):
		var dur := 1.0
		if i < picked.size():
			dur = maxf(0.5, float(picked[i]))
		durations.append(dur)
	return durations


# Safe duration lookup: clamps to ≥0.5 beats; returns 1.0 if out of bounds.
static func duration_at(durations: Array, index: int) -> float:
	if index >= 0 and index < durations.size():
		return maxf(0.5, float(durations[index]))
	return 1.0


# Sum of all durations (falls back to melody length when durations array
# is empty/zero, so the staff still gets a nonzero width).
static func total_beats(durations: Array, melody: Array) -> float:
	var total := 0.0
	for dur in durations:
		total += maxf(0.5, float(dur))
	if total <= 0.0:
		total = float(maxi(1, melody.size()))
	return total


# Cumulative beats up to (but not including) the given index.
static func duration_prefix(durations: Array, melody: Array, end_exclusive: int) -> float:
	var total := 0.0
	for i in range(clampi(end_exclusive, 0, melody.size())):
		total += duration_at(durations, i)
	return total


# True when the melody uses anything other than straight quarters.
static func uses_varied_rhythm(durations: Array, rhythm_level: int) -> bool:
	if rhythm_level >= 2:
		return true
	for dur in durations:
		if absf(float(dur) - 1.0) > 0.05:
			return true
	return false


# Convert a duration in beats to a clamped reference-tempo seconds value.
# Range is [0.22, 1.85] sec so eighth-notes don't sound choppy and whole-notes
# don't drag out for too long during melody playback.
static func note_seconds(duration_beats: float) -> float:
	return clampf(maxf(0.5, duration_beats) * REFERENCE_SECONDS_PER_BEAT, 0.22, 1.85)


# Upper bound on phrase recording time: enough beats at the per-note limit,
# plus a 1.5s safety margin, with a 4-second floor for very short melodies.
static func max_phrase_seconds(durations: Array, melody: Array) -> float:
	return maxf(4.0, total_beats(durations, melody) * SECONDS_PER_NOTE_LIMIT + 1.5)


# Build a StaffRenderer score dict from the given melody + per-note durations
# in the given key. Caller passes the ScoreModel script so this module stays
# free of the score-engine preload chain.
static func build_score_dict(melody: Array, durations: Array, sight_key_signature: String, score_model_script) -> Dictionary:
	var notes: Array = []
	var beat := 0.0
	for i in range(melody.size()):
		var dur := duration_at(durations, i)
		notes.append({
			"midi": int(melody[i]),
			"duration_beats": dur,
			"beat_offset": beat,
		})
		beat += dur
	return score_model_script.from_flat_notes(
		notes, "treble", 4, 4, fifths(sight_key_signature), false, 100, ""
	)


# Did the take earn a point? Pitch ≥60%, overall ≥70%, and rhythm above the
# stricter gate when the melody actually has rhythmic variety.
static func phrase_earned_point(result: Dictionary, durations: Array, rhythm_level: int) -> bool:
	var pitch_pct := int(result.get("pitch_percent", 0))
	var rhythm_pct := int(result.get("rhythm_percent", 0))
	var overall_pct := int(result.get("percent", 0))
	var rhythm_gate := 60 if uses_varied_rhythm(durations, rhythm_level) else 45
	return overall_pct >= 70 and pitch_pct >= 60 and rhythm_pct >= rhythm_gate


# Decide whether the mic listener has captured enough valid pitch candidates
# to commit a take. Pure analysis over the captured candidate stream — UI
# layer just feeds in candidates + phrase duration and gets a bool back.
#
# When the melody uses straight quarters (rhythm_level 1), a simple span +
# count check is enough. For varied rhythms, the analysis windows each note
# slot in the captured time range and verifies enough candidates land in the
# expected window for each note.
static func live_candidates_enough(
	candidates: Array,
	phrase_duration: float,
	durations: Array,
	melody: Array,
	rhythm_level: int
) -> bool:
	var expected_count := maxi(1, melody.size())
	var valid_candidates: Array = []
	var first_t := INF
	var last_t := -INF
	for candidate_any in candidates:
		var candidate: Dictionary = candidate_any
		if int(candidate.get("midi", -1)) < 0:
			continue
		if float(candidate.get("confidence", 0.0)) < 0.30:
			continue
		var t := float(candidate.get("time", -1.0))
		if t < 0.0:
			continue
		valid_candidates.append(candidate)
		first_t = minf(first_t, t)
		last_t = maxf(last_t, t)
	if valid_candidates.size() < expected_count * 3:
		return false
	if first_t == INF or last_t <= first_t:
		return false
	var min_span := maxf(0.35, float(maxi(1, expected_count - 1)) * 0.10)
	if (last_t - first_t) < min_span:
		return false
	if not uses_varied_rhythm(durations, rhythm_level):
		return true
	var span := maxf(last_t - first_t, 0.001)
	var note_gap := span / float(maxi(1, expected_count - 1))
	var edge_pad := clampf(note_gap * 0.35, 0.06, 0.22)
	var vocal_start := maxf(0.0, first_t - edge_pad)
	var vocal_end := minf(maxf(phrase_duration, last_t), last_t + edge_pad)
	if vocal_end <= vocal_start:
		return false
	var vocal_duration := maxf(vocal_end - vocal_start, 0.001)
	var beats := total_beats(durations, melody)
	for i in range(expected_count):
		var duration_beats := duration_at(durations, i)
		var start_t := vocal_start + duration_prefix(durations, melody, i) / beats * vocal_duration
		var end_t := vocal_start + duration_prefix(durations, melody, i + 1) / beats * vocal_duration
		var window := maxf(end_t - start_t, 0.001)
		var short_window := duration_beats <= 0.5 or window <= 0.32
		var required_total := 5 if short_window else 3
		var required_core := 2 if short_window else 1
		var core_margin := minf(window * (0.18 if short_window else 0.10), window * 0.42)
		var core_start := start_t + core_margin
		var core_end := end_t - core_margin
		var pad := maxf(window * (0.18 if short_window else 0.30), 0.025 if short_window else 0.05)
		var total_count := 0
		var core_count := 0
		for candidate_any in valid_candidates:
			var candidate: Dictionary = candidate_any
			var t := float(candidate.get("time", -1.0))
			if t < start_t - pad or t > end_t + pad:
				continue
			total_count += 1
			if t >= core_start and t <= core_end:
				core_count += 1
		if total_count < required_total or core_count < required_core:
			return false
	return true
