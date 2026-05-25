extends RefCounted
class_name SightSingingPhraseAnalyzer

const SingingEvaluatorScript = preload("res://scripts/sight_singing/singing_evaluator.gd")

const MIN_SEGMENT_DURATION_SEC := 0.06
const MERGE_GAP_SEC := 0.30
const SAME_NOTE_MERGE_SEMITONES := 0
const PHRASE_CORRECT_CENTS := 30.0
const PHRASE_CLOSE_CENTS := 70.0
const PHRASE_PITCHY_CENTS := 125.0
const CANDIDATE_CONFIDENCE_MIN := 0.30
const VOCAL_RMS_FLOOR := 0.0015
const VOCAL_RMS_MAX_RATIO := 0.18
const VOCAL_RMS_MEDIAN_RATIO := 0.70
const VOCAL_EDGE_PAD_MIN_SEC := 0.06
const VOCAL_EDGE_PAD_MAX_SEC := 0.22
# One candidate is enough to score a note. Combined with the soft-pass producing
# tens of candidates per window we virtually eliminate "missing" verdicts; the
# rare single-frame outlier loses to the strict band thresholds anyway.
const MIN_WINDOW_CANDIDATES := 1
# Window pad — how much slack on either side of a window's nominal boundary
# we'll accept candidates from. Larger pad forgives late starts / fermatas at
# the cost of letting adjacent-note frames bleed in. 0.30 means ±30% of the
# window's nominal duration.
const WINDOW_PAD_RATIO := 0.30
const SHORT_WINDOW_SEC := 0.32
const SHORT_WINDOW_PAD_RATIO := 0.18
const SHORT_WINDOW_CORE_MARGIN_RATIO := 0.18
const LONG_WINDOW_CORE_MARGIN_RATIO := 0.10
const MAX_TIMING_SHIFT_SEC := 0.10
const TIMING_SHIFT_WINDOW_RATIO := 0.28
const SHORT_UNCERTAIN_MIN_CORE := 3
const SHORT_UNCERTAIN_MIN_VOTE := 5
const MAX_FORCED_ALIGNMENT_COST := 1.20
# Time-centeredness weight floor — frames near the centre of a window are more
# likely to be the steady-state pitch than frames near the edges (which capture
# scoops / releases). We multiply the PC vote weight by a triangular factor that
# is 1.0 at the centre and TIME_EDGE_WEIGHT at the window boundaries.
const TIME_EDGE_WEIGHT := 0.55
const TARGET_PC_MULTI_MIN_RATIO := 0.32
const TARGET_PC_SINGLE_MIN_RATIO := 0.65
const SHORT_TARGET_PC_MULTI_MIN_RATIO := 0.22
const SHORT_TARGET_PC_SINGLE_MIN_RATIO := 0.48
const NEAR_PC_MIN_RATIO := 0.45


static func analyze(expected_melody: Array, detections: Array, phrase_duration: float, octave_strict: bool = false, pitch_candidates: Array = [], expected_durations: Array = []) -> Dictionary:
	var expected: Array[int] = []
	for m in expected_melody:
		expected.append(int(m))
	var durations := _normalized_expected_durations(expected.size(), expected_durations)
	var segments := _build_segments(detections)
	var analysis: Dictionary = {}
	if not pitch_candidates.is_empty():
		analysis = _score_from_candidate_windows(expected, durations, pitch_candidates, maxf(phrase_duration, 0.001), octave_strict)
	else:
		analysis = _score_from_segments(expected, segments, octave_strict)
	var per_note: Array = analysis.get("per_note", [])
	var pitch_total := int(analysis.get("pitch_total", 0))
	var band_counts: Dictionary = {}
	band_counts[SingingEvaluatorScript.BAND_CORRECT] = 0
	band_counts[SingingEvaluatorScript.BAND_CLOSE] = 0
	band_counts[SingingEvaluatorScript.BAND_PITCHY] = 0
	band_counts[SingingEvaluatorScript.BAND_WRONG] = 0
	band_counts[SingingEvaluatorScript.BAND_UNCERTAIN] = 0
	for row_any in per_note:
		var row: Dictionary = row_any
		var band := int(row.get("band", SingingEvaluatorScript.BAND_WRONG))
		band_counts[band] = int(band_counts.get(band, 0)) + 1

	var note_count := maxi(1, expected.size())
	var pitch_percent := int(round(float(pitch_total) / float(note_count)))
	var analysis_duration := maxf(float(analysis.get("vocal_end", phrase_duration)) - float(analysis.get("vocal_start", 0.0)), 0.001)
	var rhythm_percent := _rhythm_score(per_note, durations, analysis_duration)
	var rhythm_weight := _rhythm_weight_for_durations(durations)
	var total_percent := int(round(float(pitch_percent) * (1.0 - rhythm_weight) + float(rhythm_percent) * rhythm_weight))
	var curve_source := pitch_candidates if not pitch_candidates.is_empty() else detections
	var curve_start := float(analysis.get("vocal_start", 0.0))
	return {
		"percent": total_percent,
		"pitch_percent": pitch_percent,
		"rhythm_percent": rhythm_percent,
		"rhythm_weight": rhythm_weight,
		"total_notes": expected.size(),
		"expected_durations": durations,
		"notes_evaluated": per_note.size(),
		"band_counts": band_counts,
		"per_note": per_note,
		"segments": segments,
		"pitch_curve": _pitch_curve_points(expected, curve_source, analysis_duration, curve_start),
		"phrase_duration": phrase_duration,
		"vocal_start": curve_start,
		"vocal_end": float(analysis.get("vocal_end", phrase_duration)),
		"timing_offset_sec": float(analysis.get("timing_offset_sec", 0.0)),
		"debug_windows": analysis.get("debug_windows", []),
		"candidate_count": pitch_candidates.size(),
	}


static func _score_from_segments(expected: Array[int], segments: Array, octave_strict: bool) -> Dictionary:
	var matched := _align_segments(expected, segments)
	var per_note: Array = []
	var pitch_total := 0
	for i in range(expected.size()):
		var target_midi := int(expected[i])
		var seg: Dictionary = matched[i] if i < matched.size() else {}
		var result := _missing_result()
		if not seg.is_empty():
			result = _evaluate_phrase_note(target_midi, int(seg.get("midi", -1)), float(seg.get("cents_off", 0.0)), octave_strict)
			result["missing"] = false
		var band := int(result.get("band", SingingEvaluatorScript.BAND_WRONG))
		pitch_total += SingingEvaluatorScript.band_score(band)
		per_note.append({
			"target_midi": target_midi,
			"detected_midi": int(seg.get("midi", -1)),
			"start_time": float(seg.get("start_time", -1.0)),
			"end_time": float(seg.get("end_time", -1.0)),
			"duration": float(seg.get("duration", 0.0)),
			"band": band,
			"pc_match": bool(result.get("pc_match", false)),
			"cents_off": float(result.get("cents_off", 0.0)),
			"missing": bool(result.get("missing", false)),
		})
	return {"per_note": per_note, "pitch_total": pitch_total, "debug_windows": []}


static func _normalized_expected_durations(expected_count: int, expected_durations: Array) -> Array[float]:
	var durations: Array[float] = []
	for i in range(expected_count):
		var dur := 1.0
		if i < expected_durations.size():
			dur = maxf(0.25, float(expected_durations[i]))
		durations.append(dur)
	return durations


static func _duration_total(durations: Array[float]) -> float:
	var total := 0.0
	for dur in durations:
		total += maxf(0.25, float(dur))
	return maxf(total, 0.001)


static func _duration_prefix(durations: Array[float], end_exclusive: int) -> float:
	var total := 0.0
	for i in range(clampi(end_exclusive, 0, durations.size())):
		total += maxf(0.25, float(durations[i]))
	return total


static func _rhythm_weight_for_durations(durations: Array[float]) -> float:
	for dur in durations:
		if absf(float(dur) - 1.0) > 0.05:
			return 0.25
	return 0.15


static func _score_from_candidate_windows(expected: Array[int], durations: Array[float], candidates: Array, phrase_duration: float, octave_strict: bool) -> Dictionary:
	var per_note: Array = []
	var debug_windows: Array = []
	var pitch_total := 0
	if expected.is_empty():
		return {"per_note": per_note, "pitch_total": 0, "debug_windows": debug_windows}
	var total_beats := _duration_total(durations)
	var valid_candidates := _filter_pitch_candidates(candidates)
	if valid_candidates.is_empty():
		for i in range(expected.size()):
			var start_t := _duration_prefix(durations, i) / total_beats * phrase_duration
			var end_t := _duration_prefix(durations, i + 1) / total_beats * phrase_duration
			var missing_row := _missing_row(int(expected[i]), start_t, end_t, 0)
			per_note.append(missing_row)
			debug_windows.append(_debug_window(i, start_t, end_t, missing_row, "missing"))
		return {
			"per_note": per_note,
			"pitch_total": 0,
			"debug_windows": debug_windows,
			"vocal_start": 0.0,
			"vocal_end": phrase_duration,
		}
	var region := _active_vocal_region(valid_candidates, phrase_duration, expected.size())
	var vocal_start := float(region.get("start", 0.0))
	var vocal_end := float(region.get("end", phrase_duration))
	var scoring_candidates: Array = valid_candidates
	var scoring_candidates_any: Variant = region.get("candidates", valid_candidates)
	if scoring_candidates_any is Array:
		scoring_candidates = scoring_candidates_any
	var vocal_duration := maxf(vocal_end - vocal_start, 0.001)
	var offsets := _candidate_timing_offsets(durations, vocal_duration)
	var best_attempt: Dictionary = {}
	var best_score := -1.0
	for offset_any in offsets:
		var offset := float(offset_any)
		var attempt := _score_candidate_windows_at_offset(
			expected,
			durations,
			scoring_candidates,
			total_beats,
			vocal_start,
			vocal_duration,
			offset,
			octave_strict
		)
		var attempt_per_note: Array = attempt.get("per_note", [])
		var attempt_pitch_total := int(attempt.get("pitch_total", 0))
		var attempt_pitch_pct := float(attempt_pitch_total) / float(maxi(1, expected.size()))
		var attempt_rhythm_pct := float(_rhythm_score(attempt_per_note, durations, vocal_duration))
		var attempt_score := attempt_pitch_pct * 0.82 + attempt_rhythm_pct * 0.18
		if attempt_score > best_score:
			best_score = attempt_score
			best_attempt = attempt
	per_note = best_attempt.get("per_note", [])
	debug_windows = best_attempt.get("debug_windows", [])
	pitch_total = int(best_attempt.get("pitch_total", 0))
	return {
		"per_note": per_note,
		"pitch_total": pitch_total,
		"debug_windows": debug_windows,
		"vocal_start": vocal_start,
		"vocal_end": vocal_end,
		"timing_offset_sec": float(best_attempt.get("timing_offset_sec", 0.0)),
	}


static func _candidate_timing_offsets(durations: Array[float], vocal_duration: float) -> Array[float]:
	var total_beats := _duration_total(durations)
	var min_window := vocal_duration
	var has_varied_rhythm := false
	for dur in durations:
		var d := maxf(0.25, float(dur))
		if absf(d - 1.0) > 0.05:
			has_varied_rhythm = true
		min_window = minf(min_window, d / total_beats * vocal_duration)
	if not has_varied_rhythm and min_window > SHORT_WINDOW_SEC:
		return [0.0]
	var shift := minf(MAX_TIMING_SHIFT_SEC, maxf(0.035, min_window * TIMING_SHIFT_WINDOW_RATIO))
	return [0.0, -shift, shift, -shift * 0.5, shift * 0.5]


static func _score_candidate_windows_at_offset(
	expected: Array[int],
	durations: Array[float],
	scoring_candidates: Array,
	total_beats: float,
	vocal_start: float,
	vocal_duration: float,
	timing_offset: float,
	octave_strict: bool
) -> Dictionary:
	var per_note: Array = []
	var debug_windows: Array = []
	var pitch_total := 0
	for i in range(expected.size()):
		var target_midi := int(expected[i])
		var start_t := vocal_start + _duration_prefix(durations, i) / total_beats * vocal_duration + timing_offset
		var end_t := vocal_start + _duration_prefix(durations, i + 1) / total_beats * vocal_duration + timing_offset
		var window := maxf(end_t - start_t, 0.001)
		var duration_beats := float(durations[i]) if i < durations.size() else 1.0
		var short_window := window <= SHORT_WINDOW_SEC or duration_beats <= 0.5
		var pad_ratio := SHORT_WINDOW_PAD_RATIO if short_window else WINDOW_PAD_RATIO
		var pad_floor := 0.025 if short_window else 0.05
		var pad := maxf(window * pad_ratio, pad_floor)
		var core_margin_ratio := SHORT_WINDOW_CORE_MARGIN_RATIO if short_window else LONG_WINDOW_CORE_MARGIN_RATIO
		var core_margin := minf(window * core_margin_ratio, window * 0.42)
		var core_start := start_t + core_margin
		var core_end := end_t - core_margin
		var in_window: Array = []
		var core_window: Array = []
		for candidate_any in scoring_candidates:
			var candidate: Dictionary = candidate_any
			var t := float(candidate.get("time", -1.0))
			if t < start_t - pad or t > end_t + pad:
				continue
			in_window.append(candidate)
			if t >= core_start and t <= core_end:
				core_window.append(candidate)
		var row := _row_from_window(target_midi, start_t, end_t, in_window, octave_strict, core_window, short_window)
		row["timing_offset_sec"] = timing_offset
		var band := int(row.get("band", SingingEvaluatorScript.BAND_WRONG))
		pitch_total += SingingEvaluatorScript.band_score(band)
		per_note.append(row)
		debug_windows.append(_debug_window(i, start_t, end_t, row, str(row.get("source", "window"))))
	return {
		"per_note": per_note,
		"pitch_total": pitch_total,
		"debug_windows": debug_windows,
		"timing_offset_sec": timing_offset,
	}


static func _filter_pitch_candidates(candidates: Array) -> Array:
	var filtered: Array = []
	for candidate_any in candidates:
		var candidate: Dictionary = candidate_any
		if int(candidate.get("midi", -1)) < 0:
			continue
		if float(candidate.get("confidence", 0.0)) < CANDIDATE_CONFIDENCE_MIN:
			continue
		if float(candidate.get("time", -1.0)) < 0.0:
			continue
		filtered.append(candidate)
	return filtered


static func _active_vocal_region(candidates: Array, phrase_duration: float, expected_count: int) -> Dictionary:
	var rms_values: Array = []
	var max_rms := 0.0
	var first_any := INF
	var last_any := -INF
	for candidate_any in candidates:
		var candidate: Dictionary = candidate_any
		var t := float(candidate.get("time", 0.0))
		first_any = minf(first_any, t)
		last_any = maxf(last_any, t)
		var rms := float(candidate.get("rms", 0.0))
		max_rms = maxf(max_rms, rms)
		rms_values.append(rms)
	var median_rms := _median_number(rms_values)
	var rms_gate := maxf(VOCAL_RMS_FLOOR, maxf(max_rms * VOCAL_RMS_MAX_RATIO, median_rms * VOCAL_RMS_MEDIAN_RATIO))
	var first := INF
	var last := -INF
	for candidate_any in candidates:
		var candidate: Dictionary = candidate_any
		var rms := float(candidate.get("rms", 0.0))
		var confidence := float(candidate.get("confidence", 0.0))
		if rms < rms_gate and confidence < 0.78:
			continue
		var t := float(candidate.get("time", 0.0))
		first = minf(first, t)
		last = maxf(last, t)
	if first == INF or last <= first:
		first = first_any
		last = last_any
	var span := maxf(last - first, 0.001)
	var note_gap := span / float(maxi(1, expected_count - 1))
	var edge_pad := clampf(note_gap * 0.35, VOCAL_EDGE_PAD_MIN_SEC, VOCAL_EDGE_PAD_MAX_SEC)
	var upper_bound := maxf(phrase_duration, last)
	var start_t := maxf(0.0, first - edge_pad)
	var end_t := minf(upper_bound, last + edge_pad)
	if end_t <= start_t:
		end_t = start_t + maxf(0.25, phrase_duration)
	var trimmed: Array = []
	for candidate_any in candidates:
		var candidate: Dictionary = candidate_any
		var t := float(candidate.get("time", 0.0))
		if t >= start_t - 0.02 and t <= end_t + 0.02:
			trimmed.append(candidate)
	return {
		"start": start_t,
		"end": end_t,
		"candidates": trimmed,
		"rms_gate": rms_gate,
	}


static func _debug_window(note_index: int, start_t: float, end_t: float, row: Dictionary, source: String) -> Dictionary:
	return {
		"note_index": note_index,
		"start_time": start_t,
		"end_time": end_t,
		"timing_offset_sec": float(row.get("timing_offset_sec", 0.0)),
		"actual_start_time": float(row.get("actual_start_time", start_t)),
		"actual_end_time": float(row.get("actual_end_time", end_t)),
		"actual_duration": float(row.get("actual_duration", maxf(0.0, end_t - start_t))),
		"candidate_count": int(row.get("candidate_count", 0)),
		"core_candidate_count": int(row.get("core_candidate_count", 0)),
		"vote_candidate_count": int(row.get("vote_candidate_count", row.get("candidate_count", 0))),
		"selected_count": int(row.get("selected_count", 0)),
		"selected_midi": int(row.get("detected_midi", -1)),
		"band": int(row.get("band", SingingEvaluatorScript.BAND_WRONG)),
		"confidence_avg": float(row.get("confidence_avg", 0.0)),
		"rms_avg": float(row.get("rms_avg", 0.0)),
		"source": source,
		"uncertain": bool(row.get("uncertain", false)),
		"uncertain_reason": str(row.get("uncertain_reason", "")),
		"missing": bool(row.get("missing", false)),
	}


static func _row_from_window(target_midi: int, start_t: float, end_t: float, candidates: Array, octave_strict: bool, core_candidates: Array = [], short_window: bool = false) -> Dictionary:
	if candidates.size() < MIN_WINDOW_CANDIDATES:
		return _missing_row(target_midi, start_t, end_t, candidates.size())
	var vote_candidates: Array = core_candidates if core_candidates.size() >= 2 else candidates
	# Time-centeredness factor — triangular shape across the window. Frames at
	# the very edges of [start_t, end_t] contribute TIME_EDGE_WEIGHT (~0.55);
	# frames at the centre contribute 1.0. Scoops/transitions sit at edges so
	# this naturally down-weights them without rejecting outright.
	var window_center: float = (start_t + end_t) * 0.5
	var window_half: float = maxf((end_t - start_t) * 0.5, 0.001)
	var pc_weights: Dictionary = {}
	var pc_counts: Dictionary = {}
	for candidate_any in vote_candidates:
		var candidate: Dictionary = candidate_any
		var midi := int(candidate.get("midi", -1))
		if midi < 0:
			continue
		var pc := posmod(midi, 12)
		var confidence := float(candidate.get("confidence", 0.0))
		var rms := float(candidate.get("rms", 0.0))
		var t := float(candidate.get("time", window_center))
		var time_offset: float = clampf(absf(t - window_center) / window_half, 0.0, 1.0)
		var time_factor: float = lerpf(1.0, TIME_EDGE_WEIGHT, time_offset)
		var target_cents := _target_relative_cents(target_midi, midi, float(candidate.get("cents_off", 0.0)), octave_strict)
		var weight := confidence * (1.0 + clampf(rms / 0.006, 0.0, 2.0)) * time_factor * _pitch_bias_factor(absf(target_cents))
		pc_weights[pc] = float(pc_weights.get(pc, 0.0)) + weight
		pc_counts[pc] = int(pc_counts.get(pc, 0)) + 1
	if pc_weights.is_empty():
		return _missing_row(target_midi, start_t, end_t, candidates.size())
	var selected_pc := -1
	var best_weight := -1.0
	for pc_any in pc_weights.keys():
		var pc := int(pc_any)
		var weight := float(pc_weights[pc])
		if weight > best_weight:
			best_weight = weight
			selected_pc = pc
	var source := "dominant_pc"
	var target_pc := posmod(target_midi, 12)
	var target_weight := float(pc_weights.get(target_pc, 0.0))
	var target_count := int(pc_counts.get(target_pc, 0))
	if target_weight > 0.0:
		var multi_ratio := SHORT_TARGET_PC_MULTI_MIN_RATIO if short_window else TARGET_PC_MULTI_MIN_RATIO
		var single_ratio := SHORT_TARGET_PC_SINGLE_MIN_RATIO if short_window else TARGET_PC_SINGLE_MIN_RATIO
		var required_ratio := multi_ratio if target_count >= 2 else single_ratio
		if target_weight >= best_weight * required_ratio:
			selected_pc = target_pc
			source = "target_pc"
	if source == "dominant_pc":
		var near_pc := -1
		var near_weight := -1.0
		for pc_any in pc_weights.keys():
			var pc := int(pc_any)
			if _pc_distance(target_pc, pc) > 1:
				continue
			var weight := float(pc_weights[pc])
			if weight > near_weight:
				near_weight = weight
				near_pc = pc
		if near_pc >= 0 and near_weight >= best_weight * NEAR_PC_MIN_RATIO:
			selected_pc = near_pc
			source = "near_pc"
	if selected_pc < 0:
		return _missing_row(target_midi, start_t, end_t, candidates.size())
	var selected_midis: Array = []
	var selected_cents: Array = []
	var selected_conf: Array = []
	var selected_rms: Array = []
	var selected_times: Array = []
	for candidate_any in candidates:
		var candidate: Dictionary = candidate_any
		var midi := int(candidate.get("midi", -1))
		if midi < 0 or posmod(midi, 12) != selected_pc:
			continue
		selected_midis.append(midi)
		selected_cents.append(float(candidate.get("cents_off", 0.0)))
		selected_conf.append(float(candidate.get("confidence", 0.0)))
		selected_rms.append(float(candidate.get("rms", 0.0)))
		selected_times.append(float(candidate.get("time", start_t)))
	if selected_midis.is_empty():
		return _missing_row(target_midi, start_t, end_t, candidates.size())
	var detected_midi := int(round(_median_number(selected_midis)))
	var cents_off := _median_number(selected_cents)
	var result := _evaluate_phrase_note(target_midi, detected_midi, cents_off, octave_strict)
	result["missing"] = false
	if _should_mark_uncertain(result, short_window, target_count, core_candidates.size(), vote_candidates.size(), selected_midis.size()):
		result["band"] = SingingEvaluatorScript.BAND_UNCERTAIN
		result["uncertain"] = true
		result["uncertain_reason"] = "short-window sparse evidence"
	# Actual onset = earliest time the singer hit the winning PC inside this
	# window. Used by the rhythm scorer so timing is judged by where the singer
	# actually sang the note, not by the window boundary.
	var actual_start: float = _min_number(selected_times) if not selected_times.is_empty() else start_t
	var actual_end: float = _max_number(selected_times) if not selected_times.is_empty() else end_t
	if actual_end < actual_start:
		actual_end = actual_start
	return {
		"target_midi": target_midi,
		"detected_midi": detected_midi,
		"start_time": start_t,
		"end_time": end_t,
		"actual_start_time": actual_start,
		"actual_end_time": actual_end,
		"actual_duration": maxf(0.0, actual_end - actual_start),
		"duration": maxf(0.0, end_t - start_t),
		"band": int(result.get("band", SingingEvaluatorScript.BAND_WRONG)),
		"pc_match": bool(result.get("pc_match", false)),
		"cents_off": float(result.get("cents_off", 0.0)),
		"uncertain": bool(result.get("uncertain", false)),
		"uncertain_reason": str(result.get("uncertain_reason", "")),
		"missing": false,
		"source": source,
		"candidate_count": candidates.size(),
		"core_candidate_count": core_candidates.size(),
		"vote_candidate_count": vote_candidates.size(),
		"selected_count": selected_midis.size(),
		"confidence_avg": _average_number(selected_conf),
		"rms_avg": _average_number(selected_rms),
	}


static func _should_mark_uncertain(result: Dictionary, short_window: bool, target_count: int, core_count: int, vote_count: int, selected_count: int) -> bool:
	if not short_window:
		return false
	if int(result.get("band", SingingEvaluatorScript.BAND_WRONG)) != SingingEvaluatorScript.BAND_WRONG:
		return false
	if core_count < SHORT_UNCERTAIN_MIN_CORE:
		return true
	if vote_count < SHORT_UNCERTAIN_MIN_VOTE:
		return true
	if target_count > 0 and selected_count <= 2:
		return true
	return false


static func _missing_result() -> Dictionary:
	return {
		"band": SingingEvaluatorScript.BAND_WRONG,
		"pc_match": false,
		"cents_off": 0.0,
		"uncertain": false,
		"uncertain_reason": "",
		"missing": true,
	}


static func _missing_row(target_midi: int, start_t: float, end_t: float, candidate_count: int) -> Dictionary:
	var result := _missing_result()
	return {
		"target_midi": target_midi,
		"detected_midi": -1,
		"start_time": start_t,
		"end_time": end_t,
		"actual_start_time": start_t,
		"actual_end_time": end_t,
		"actual_duration": maxf(0.0, end_t - start_t),
		"duration": maxf(0.0, end_t - start_t),
		"band": int(result.get("band", SingingEvaluatorScript.BAND_WRONG)),
		"pc_match": false,
		"cents_off": 0.0,
		"missing": true,
		"candidate_count": candidate_count,
		"selected_count": 0,
		"confidence_avg": 0.0,
		"rms_avg": 0.0,
	}


static func _median_number(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := int(sorted.size() / 2)
	if sorted.size() % 2 == 1:
		return float(sorted[mid])
	return (float(sorted[mid - 1]) + float(sorted[mid])) * 0.5


static func _average_number(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())


static func _min_number(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var best := float(values[0])
	for i in range(1, values.size()):
		var v := float(values[i])
		if v < best:
			best = v
	return best


static func _max_number(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var best := float(values[0])
	for i in range(1, values.size()):
		var v := float(values[i])
		if v > best:
			best = v
	return best


static func _evaluate_phrase_note(target_midi: int, detected_midi: int, cents_off: float, octave_strict: bool = false) -> Dictionary:
	var target_relative_cents := _target_relative_cents(target_midi, detected_midi, cents_off, octave_strict)
	var target_pc := posmod(target_midi, 12)
	var detected_pc := posmod(detected_midi, 12)
	var pc_delta := _signed_pc_delta(target_pc, detected_pc)
	var abs_cents := absf(target_relative_cents)
	var band: int
	if abs_cents <= PHRASE_CORRECT_CENTS:
		band = SingingEvaluatorScript.BAND_CORRECT
	elif abs_cents <= PHRASE_CLOSE_CENTS:
		band = SingingEvaluatorScript.BAND_CLOSE
	elif abs_cents <= PHRASE_PITCHY_CENTS:
		band = SingingEvaluatorScript.BAND_PITCHY
	else:
		band = SingingEvaluatorScript.BAND_WRONG
	return {
		"band": band,
		"pc_match": pc_delta == 0 or abs_cents <= PHRASE_PITCHY_CENTS,
		"cents_off": target_relative_cents,
	}


static func _target_relative_cents(target_midi: int, detected_midi: int, cents_off: float, octave_strict: bool) -> float:
	if detected_midi < 0:
		return 9999.0
	if octave_strict:
		return float((detected_midi - target_midi) * 100) + cents_off
	var target_pc := posmod(target_midi, 12)
	var detected_pc := posmod(detected_midi, 12)
	return float(_signed_pc_delta(target_pc, detected_pc) * 100) + cents_off


static func _pitch_bias_factor(abs_cents: float) -> float:
	if abs_cents <= PHRASE_CORRECT_CENTS:
		return 1.45
	if abs_cents <= PHRASE_CLOSE_CENTS:
		return 1.25
	if abs_cents <= PHRASE_PITCHY_CENTS:
		return 1.05
	if abs_cents <= 200.0:
		return 0.78
	return 0.45


static func _signed_pc_delta(target_pc: int, detected_pc: int) -> int:
	var delta := posmod(detected_pc - target_pc, 12)
	if delta > 6:
		delta -= 12
	return delta


static func _pc_distance(a: int, b: int) -> int:
	var dist := absi(posmod(a, 12) - posmod(b, 12))
	return mini(dist, 12 - dist)


static func _build_segments(detections: Array) -> Array:
	var segments: Array = []
	if detections.is_empty():
		return segments
	var current: Dictionary = {}
	for det_any in detections:
		var det: Dictionary = det_any
		var midi := int(det.get("midi", -1))
		if midi < 0:
			continue
		var t := float(det.get("time", 0.0))
		var cents := float(det.get("cents_off", 0.0))
		if current.is_empty():
			current = _new_segment(midi, t, cents)
			continue
		var last_t := float(current.get("last_time", t))
		var cur_midi := int(current.get("midi", midi))
		var same_note := absi(midi - cur_midi) <= SAME_NOTE_MERGE_SEMITONES
		var close_gap := (t - last_t) <= MERGE_GAP_SEC
		if same_note and close_gap:
			_extend_segment(current, midi, t, cents)
		else:
			_finalize_segment(current, segments)
			current = _new_segment(midi, t, cents)
	if not current.is_empty():
		_finalize_segment(current, segments)
	return segments


static func _new_segment(midi: int, t: float, cents: float) -> Dictionary:
	return {
		"midi": midi,
		"start_time": t,
		"last_time": t,
		"end_time": t,
		"count": 1,
		"cents_sum": cents,
	}


static func _extend_segment(segment: Dictionary, midi: int, t: float, cents: float) -> void:
	segment["last_time"] = t
	segment["end_time"] = t
	segment["count"] = int(segment.get("count", 0)) + 1
	segment["cents_sum"] = float(segment.get("cents_sum", 0.0)) + cents
	segment["midi"] = midi


static func _finalize_segment(segment: Dictionary, out: Array) -> void:
	var count := maxi(1, int(segment.get("count", 1)))
	var start_t := float(segment.get("start_time", 0.0))
	var end_t := float(segment.get("end_time", start_t))
	var duration := maxf(end_t - start_t, 0.08)
	if duration < MIN_SEGMENT_DURATION_SEC and count < 2:
		return
	out.append({
		"midi": int(segment.get("midi", -1)),
		"start_time": start_t,
		"end_time": end_t,
		"duration": duration,
		"cents_off": float(segment.get("cents_sum", 0.0)) / float(count),
		"count": count,
	})


static func _align_segments(expected: Array[int], segments: Array) -> Array:
	var matched: Array = []
	for i in range(expected.size()):
		matched.append({})
	if expected.is_empty() or segments.is_empty():
		return matched
	var n := expected.size()
	var m := segments.size()
	var dp: Array = []
	var back: Array = []
	for i in range(n + 1):
		dp.append([])
		back.append([])
		for j in range(m + 1):
			dp[i].append(1000000.0)
			back[i].append("")
	dp[0][0] = 0.0
	for i in range(n + 1):
		for j in range(m + 1):
			var cur := float(dp[i][j])
			if cur >= 999999.0:
				continue
			if i < n:
				var delete_cost := cur + 2.0
				if delete_cost < float(dp[i + 1][j]):
					dp[i + 1][j] = delete_cost
					back[i + 1][j] = "delete"
			if j < m:
				var insert_cost := cur + 1.0
				if insert_cost < float(dp[i][j + 1]):
					dp[i][j + 1] = insert_cost
					back[i][j + 1] = "insert"
			if i < n and j < m:
				var seg: Dictionary = segments[j]
				var match_cost := _pitch_alignment_cost(int(expected[i]), int(seg.get("midi", -1)))
				if match_cost > MAX_FORCED_ALIGNMENT_COST:
					continue
				var diag_cost := cur + match_cost
				if diag_cost < float(dp[i + 1][j + 1]):
					dp[i + 1][j + 1] = diag_cost
					back[i + 1][j + 1] = "match"
	var ii := n
	var jj := m
	while ii > 0 or jj > 0:
		var op := str(back[ii][jj])
		if op == "match":
			matched[ii - 1] = segments[jj - 1]
			ii -= 1
			jj -= 1
		elif op == "delete":
			ii -= 1
		elif op == "insert":
			jj -= 1
		else:
			break
	# Back-fill: when DTW leaves an expected slot unmatched but segments are
	# still available, assign the temporally-closest unused segment. This
	# matters in the equal-size case (n == m): the singer presumably sang the
	# note even if alignment cost ties pushed DTW off the diagonal. Without
	# this, a perfectly-sung note can show as "missing" purely from a tie-
	# break quirk in the dynamic programming table.
	if n > 0 and m > 0:
		var used_set: Dictionary = {}
		for k in range(matched.size()):
			var slot: Dictionary = matched[k]
			if not slot.is_empty():
				used_set[float(slot.get("start_time", -1.0))] = true
		# Estimate the phrase span from matched segments so we can give each
		# unmatched expected note a positional target.
		var span_start: float = INF
		var span_end: float = -INF
		for k in range(matched.size()):
			var slot2: Dictionary = matched[k]
			if slot2.is_empty():
				continue
			span_start = minf(span_start, float(slot2.get("start_time", 0.0)))
			span_end = maxf(span_end, float(slot2.get("start_time", 0.0)))
		if span_end <= span_start:
			# Fall back to using the segments' own span if matched were sparse.
			for s_any in segments:
				var s: Dictionary = s_any
				span_start = minf(span_start, float(s.get("start_time", 0.0)))
				span_end = maxf(span_end, float(s.get("start_time", 0.0)))
		var span: float = maxf(span_end - span_start, 0.001)
		for i in range(n):
			var cur: Dictionary = matched[i]
			if not cur.is_empty():
				continue
			var expected_pos: float = span_start + (float(i) / float(maxi(1, n - 1))) * span
			var best_j: int = -1
			var best_dist: float = INF
			for j in range(m):
				var seg: Dictionary = segments[j]
				var seg_start: float = float(seg.get("start_time", -1.0))
				if used_set.has(seg_start):
					continue
				if _pitch_alignment_cost(int(expected[i]), int(seg.get("midi", -1))) > MAX_FORCED_ALIGNMENT_COST:
					continue
				var dist: float = absf(seg_start - expected_pos)
				if dist < best_dist:
					best_dist = dist
					best_j = j
			if best_j >= 0:
				matched[i] = segments[best_j]
				used_set[float(segments[best_j].get("start_time", -1.0))] = true
	return matched


static func _pitch_alignment_cost(target_midi: int, detected_midi: int) -> float:
	if detected_midi < 0:
		return 3.0
	if posmod(target_midi, 12) == posmod(detected_midi, 12):
		return 0.0
	var pc_dist := absi(posmod(target_midi, 12) - posmod(detected_midi, 12))
	pc_dist = mini(pc_dist, 12 - pc_dist)
	if pc_dist == 1:
		return 0.45
	if pc_dist == 2:
		return 0.95
	return 2.0


static func _rhythm_score(per_note: Array, durations: Array[float], _phrase_duration: float) -> int:
	var expected_count := mini(durations.size(), per_note.size())
	if expected_count <= 0:
		return 0
	var score_total := 0
	for i in range(expected_count):
		var item: Dictionary = per_note[i]
		if bool(item.get("missing", false)):
			continue
		var expected_start := float(item.get("start_time", -1.0))
		var expected_end := float(item.get("end_time", -1.0))
		if expected_start < 0.0 or expected_end <= expected_start:
			var expected_total := _duration_total(durations)
			expected_start = _duration_prefix(durations, i) / expected_total * _phrase_duration
			expected_end = _duration_prefix(durations, i + 1) / expected_total * _phrase_duration
		var expected_duration := maxf(expected_end - expected_start, 0.001)
		var actual_start := _row_onset_time(item)
		var actual_end := _row_end_time(item)
		if actual_start < 0.0:
			continue
		if actual_end < actual_start:
			actual_end = actual_start
		var actual_duration := maxf(actual_end - actual_start, 0.0)
		var unit := maxf(expected_duration, 0.35)
		var onset_err := absf(actual_start - expected_start) / unit
		var end_err := absf(actual_end - expected_end) / unit
		var duration_err := absf(actual_duration - expected_duration) / unit
		var err := maxf(onset_err * 0.85, maxf(end_err * 0.75, duration_err))
		if err <= 0.18:
			score_total += 100
		elif err <= 0.32:
			score_total += 80
		elif err <= 0.50:
			score_total += 55
		else:
			score_total += 25
	return int(round(float(score_total) / float(expected_count)))


static func _expected_onset_position(durations: Array[float], note_index: int) -> float:
	if durations.size() <= 1:
		return 0.0
	var onset_span := maxf(_duration_prefix(durations, durations.size() - 1), 0.001)
	return _duration_prefix(durations, note_index) / onset_span


static func _row_onset_time(item: Dictionary) -> float:
	# Windowed-mode rows set actual_start_time; segment-mode rows don't.
	if item.has("actual_start_time"):
		return float(item["actual_start_time"])
	return float(item.get("start_time", -1.0))


static func _row_end_time(item: Dictionary) -> float:
	if item.has("actual_end_time"):
		return float(item["actual_end_time"])
	return float(item.get("end_time", -1.0))


static func _pitch_curve_points(expected: Array[int], detections: Array, phrase_duration: float, time_offset: float = 0.0) -> Array:
	var points: Array = []
	if expected.is_empty() or detections.is_empty():
		return points
	var max_pos := float(maxi(1, expected.size() - 1))
	var duration := maxf(phrase_duration, 0.001)
	for det_any in detections:
		var det: Dictionary = det_any
		var raw_midi := int(det.get("midi", -1))
		if raw_midi < 0:
			continue
		var rel_time := float(det.get("time", 0.0)) - time_offset
		var event_pos := clampf(rel_time / duration * max_pos, 0.0, max_pos)
		var nearest_idx := clampi(int(round(event_pos)), 0, expected.size() - 1)
		points.append({
			"event_pos": event_pos,
			"midi": _nearest_octave_midi(raw_midi, int(expected[nearest_idx])),
		})
	return points


static func _nearest_octave_midi(detected_midi: int, target_midi: int) -> int:
	var pc := posmod(detected_midi, 12)
	var best := pc
	var best_dist := 999
	for octave in range(1, 8):
		var midi := octave * 12 + pc
		var dist := absi(midi - target_midi)
		if dist < best_dist:
			best_dist = dist
			best = midi
	return best
