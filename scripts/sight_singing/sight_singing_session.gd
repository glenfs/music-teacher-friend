extends RefCounted
class_name SightSingingSession

# State machine that walks a sight-singing melody note-by-note. Doesn't draw
# anything — the UI subscribes to the result of feed_detection() each frame
# and updates the staff cursor + per-note colors accordingly.
#
# Lifecycle:
#   1. start(melody) — resets state, melody is set
#   2. feed_detection(midi, cents_off) on every stable pitch reading
#      → returns {advanced: bool, band, cents_off, note_index, complete}
#   3. is_complete() / final_score() at the end
#
# Sustained-note integration (v2):
#   The first matching stable pitch advances the cursor (the UI feels
#   responsive). For COOLDOWN_FRAMES_AFTER_NOTE further frames we KEEP
#   integrating same-pitch-class detections into the just-completed note's
#   buffer. When the cooldown ends we re-score that note using the SETTLED
#   portion (last 50% of the sustain). The result: the singer's onset glide
#   doesn't penalise them — the band reflects where the note settled.

const SingingEvaluatorScript = preload("res://scripts/sight_singing/singing_evaluator.gd")

# Internal states. Exposed as ints so callers don't depend on enum scoping.
const STATE_IDLE      := 0
const STATE_LISTENING := 1
const STATE_COMPLETE  := 2

# After a successful evaluation we briefly ignore further note advancement so
# the same sustained sung note doesn't auto-advance through multiple targets.
# At ~30 Hz polling, 8 frames ≈ 250ms — about right for a singer's breath /
# transition between notes. During this window we KEEP integrating cents-off
# into the just-finalised note's sample bucket.
const COOLDOWN_FRAMES_AFTER_NOTE := 8

# Minimum samples we need before re-scoring the sustained note. With ~30 Hz
# polling this is roughly 130 ms of voiced audio.
const SETTLE_MIN_SAMPLES := 4

var melody: Array[int] = []
var note_results: Array = []  # Array of evaluator dicts
var current_index: int = 0
var state: int = STATE_IDLE
var _cooldown_frames: int = 0
# Cents-off samples gathered for the most recently advanced note. Cleared on
# the next advance.
var _last_note_samples: PackedFloat32Array = PackedFloat32Array()
var _last_note_target: int = -1


# Resets and arms the session with a new melody (Array of MIDI ints).
func start(new_melody: Array) -> void:
	melody.clear()
	for m in new_melody:
		melody.append(int(m))
	note_results.clear()
	current_index = 0
	_cooldown_frames = 0
	_last_note_samples.clear()
	_last_note_target = -1
	state = STATE_LISTENING if not melody.is_empty() else STATE_IDLE


func is_complete() -> bool:
	return state == STATE_COMPLETE


# Returns the current target MIDI, or -1 if there's none (idle / complete).
func current_target_midi() -> int:
	if state != STATE_LISTENING:
		return -1
	if current_index < 0 or current_index >= melody.size():
		return -1
	return melody[current_index]


# Decrements the post-note cooldown by one tick. Call from the UI's per-frame
# tick BEFORE feed_detection() — this is what makes the gap-between-notes work
# even when the singer holds the same pitch.
func tick_cooldown() -> void:
	if _cooldown_frames > 0:
		_cooldown_frames -= 1
		# When cooldown closes, re-score the last note using only its settled
		# tail (last half of samples) — onset glide is excluded.
		if _cooldown_frames == 0 and _last_note_samples.size() >= SETTLE_MIN_SAMPLES:
			_resolve_last_note_with_settled_tail()


# Feeds a stable detected pitch. Returns:
#   {} when nothing happened (cooldown without advance)
#   {
#     "advanced": bool,
#     "band": SingingEvaluator BAND_* int,
#     "pc_match": bool,
#     "cents_off": float,
#     "note_index": int,        # the index that was just evaluated
#     "complete": bool,         # session ended on this advance
#   }
func feed_detection(detected_midi: int, cents_off: float) -> Dictionary:
	# During cooldown we don't advance, but we do accumulate sustained-note
	# samples for the just-evaluated target so we can re-score it once the
	# singer settles.
	if state != STATE_LISTENING and state != STATE_COMPLETE:
		return {}
	if _cooldown_frames > 0:
		_maybe_accumulate_sustain(detected_midi, cents_off)
		return {}
	if state != STATE_LISTENING:
		return {}
	var target: int = current_target_midi()
	if target < 0:
		return {}
	var result: Dictionary = SingingEvaluatorScript.evaluate(target, detected_midi, cents_off)
	# Skip pure-wrong detections so a momentary off-pitch reading doesn't
	# advance past a note the singer hasn't actually attempted yet. Caller
	# can still see the result via current_detection_preview() if it wants
	# to show "you're singing X, target is Y" feedback.
	# Update: in this v1 we DO advance on wrong, because otherwise a singer
	# who can't find the note would be stuck forever. The result row records
	# wrong-band; the cursor moves on. Pedagogically OK for v1.
	note_results.append(result)
	var evaluated_index: int = current_index
	current_index += 1
	_cooldown_frames = COOLDOWN_FRAMES_AFTER_NOTE
	# Seed the sustain bucket with the onset sample — subsequent same-PC
	# detections during cooldown extend it.
	_last_note_samples.clear()
	_last_note_target = target
	_last_note_samples.append(cents_off)
	if current_index >= melody.size():
		state = STATE_COMPLETE
	return {
		"advanced": true,
		"band": int(result.get("band", SingingEvaluatorScript.BAND_WRONG)),
		"pc_match": bool(result.get("pc_match", false)),
		"cents_off": float(result.get("cents_off", 0.0)),
		"note_index": evaluated_index,
		"complete": state == STATE_COMPLETE,
	}


# Append a cents-off sample to the sustain bucket if the detected pitch is
# still the same pitch class as the target. Wrong-pitch frames during the gap
# don't poison the average.
func _maybe_accumulate_sustain(detected_midi: int, cents_off: float) -> void:
	if _last_note_target < 0:
		return
	if posmod(detected_midi, 12) != posmod(_last_note_target, 12):
		return
	_last_note_samples.append(cents_off)


# Recomputes the most recent note_result using the settled tail (last half) of
# the sustain samples. Onset glides get excluded; what counts is where the
# singer landed.
func _resolve_last_note_with_settled_tail() -> void:
	if note_results.is_empty():
		return
	var n: int = _last_note_samples.size()
	if n < SETTLE_MIN_SAMPLES:
		return
	var tail_start: int = int(n / 2)
	var sum: float = 0.0
	var count: int = 0
	for i in range(tail_start, n):
		sum += _last_note_samples[i]
		count += 1
	if count == 0:
		return
	var settled_cents: float = sum / float(count)
	# Re-evaluate. The detected MIDI is the same target PC (we only added
	# matching-PC samples); reuse the last result's detected_midi if present.
	var last: Dictionary = note_results[note_results.size() - 1]
	var detected_midi: int = int(last.get("detected_midi", _last_note_target))
	var refined: Dictionary = SingingEvaluatorScript.evaluate(_last_note_target, detected_midi, settled_cents)
	refined["onset_cents_off"] = float(last.get("cents_off", 0.0))
	refined["settled_cents_off"] = settled_cents
	refined["sustain_samples"] = n
	note_results[note_results.size() - 1] = refined


# Summary stats after the session ends — overall %, per-band counts, per-note
# breakdown. Caller renders this on the result screen.
func final_score() -> Dictionary:
	# Flush any pending sustain into the last note even if cooldown didn't run
	# its course (e.g. melody ended on the final note).
	if _last_note_samples.size() >= SETTLE_MIN_SAMPLES:
		_resolve_last_note_with_settled_tail()
		_last_note_samples.clear()
	var total: int = 0
	var bands: Dictionary = {
		SingingEvaluatorScript.BAND_CORRECT: 0,
		SingingEvaluatorScript.BAND_CLOSE: 0,
		SingingEvaluatorScript.BAND_PITCHY: 0,
		SingingEvaluatorScript.BAND_WRONG: 0,
		SingingEvaluatorScript.BAND_UNCERTAIN: 0,
	}
	for r in note_results:
		var b: int = int(r.get("band", SingingEvaluatorScript.BAND_WRONG))
		total += SingingEvaluatorScript.band_score(b)
		bands[b] = int(bands.get(b, 0)) + 1
	var pct: int = 0
	if note_results.size() > 0:
		pct = int(round(float(total) / float(note_results.size())))
	return {
		"percent": pct,
		"total_notes": melody.size(),
		"notes_evaluated": note_results.size(),
		"band_counts": bands,
		"per_note": note_results.duplicate(),
	}
