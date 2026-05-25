extends RefCounted
class_name DifficultyEstimator

# Pure difficulty estimator over the exercise dict shape produced by
# TechnicalExerciseGenerator. Returns an integer level in [1, 10] that maps a
# generated exercise to roughly where it belongs on the curriculum ladder.
#
# Used in two places:
#   - exercise_self_test.gd: assert generated-vs-requested level stays within ±2
#                            for the canonical templates (regression check).
#   - Phase-6 generators: select among resamples by closeness to target level.
#
# Features blended (rough weights — tune against template fixtures):
#   - max_jump_semitones    big jumps drive difficulty fastest
#   - span_semitones        per-hand pitch range (whole-exercise)
#   - rhythmic_density      pitched notes / total beats
#   - |fifths|              key signature load (#/b count)
#   - tempo_bpm             baseline 60 = trivial; 144 = virtuoso

const ExerciseValidatorScript = preload("res://scripts/exercises/exercise_validator.gd")


# Estimates level. Pass a `features` dict (from ExerciseValidator.is_valid()) to
# avoid recomputing — otherwise this walks the notes once internally.
static func estimate_level(exercise: Dictionary, features_in: Dictionary = {}) -> int:
	var feat: Dictionary = features_in
	if feat.is_empty():
		# Run validator just to gather features. Reasons are ignored here.
		feat = ExerciseValidatorScript.is_valid(exercise).get("features", {})
	var score: float = _score(feat)
	# Score ~ 0..14 in practice; compress to 1..10 with a mild slope.
	var level: int = int(round(clampf(score * 0.75 + 0.8, 1.0, 10.0)))
	return level


# Returns the raw weighted score (useful for tuning / diagnostics).
static func score_features(exercise: Dictionary) -> float:
	var feat: Dictionary = ExerciseValidatorScript.is_valid(exercise).get("features", {})
	return _score(feat)


static func _score(feat: Dictionary) -> float:
	var max_jump: float = float(feat.get("max_jump", 0))
	var span: float = float(feat.get("span", 0))
	var density: float = 0.0
	var total_beats: float = float(feat.get("total_beats", 0.0))
	if total_beats > 0.0:
		density = float(feat.get("pitched_count", 0)) / total_beats
	var fifths: int = absi(int(feat.get("fifths", 0)))
	var tempo: float = float(feat.get("tempo_bpm", 60))

	var s: float = 0.0
	# Jumps: anything above a 3rd starts contributing; capped at octave equivalent.
	s += clampf(max_jump - 3.0, 0.0, 12.0) * 0.4
	# Span: each octave (~12 st) adds ~1.5 difficulty. 3-oct scale (~36) ≈ 4.5.
	s += clampf(span / 8.0, 0.0, 6.0)
	# Density: 2 notes/beat (eighths) = baseline +0.5; 4 notes/beat (16ths) = +1.5.
	s += clampf(density - 1.0, 0.0, 4.0) * 0.5
	# Key signature load: each accidental ~0.4 difficulty; capped at 6 (F#/Gb).
	s += clampf(float(fifths), 0.0, 6.0) * 0.4
	# Tempo: 60→0, 144→7.0. Each 12 bpm above 60 ≈ 1 unit.
	s += clampf((tempo - 60.0) / 12.0, 0.0, 7.0)
	return s
