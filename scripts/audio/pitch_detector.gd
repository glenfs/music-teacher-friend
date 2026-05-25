class_name PitchDetector
extends RefCounted

# YIN-based autocorrelation pitch detector for mic input.
# Usage: setup(owner_node) -> start_listening() -> poll() each frame -> stop_listening()
#
# v2 additions (sight-singing recognition pass):
#   - 60 Hz single-pole high-pass filter to kill HVAC / room rumble
#   - Hann window applied to the YIN input frame (reduces edge artifacts)
#   - Adaptive RMS gate that tracks the room noise floor
#   - Spectral confidence check via Goertzel at the first harmonic (2F)
#   - Octave-error correction biased to recent voice range
#   - Optional target-pitch-class prior (caller can hint expected PC)
#   - Voice range adaptation — locks preferred octave after a few notes
#   - Onset detection via RMS rise relative to slow baseline

const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
# Sample rate is read from AudioServer at setup() time (not hardcoded). Android
# devices often default to 48000 Hz; a hardcoded 44100 made pitch reads slightly
# flat there. _sample_rate keeps the YIN tau→freq conversion correct.
const SAMPLE_RATE_FALLBACK := 44100.0
const MIN_FREQ := 90.0   # ~F#2 — below most adult sustained singing
const MAX_FREQ := 1400.0  # ~F6
# Voice-realistic search ceiling for adaptive narrowing — once we've observed
# the singer's range, we only need to search ~one octave outside it. ~98 Hz
# (G2) covers practically every adult voice's lowest sustained note; ~1100 Hz
# (~C6) covers above-soprano whistle. These bound the *adaptive* range, not
# the absolute YIN range, which stays at MIN_FREQ / MAX_FREQ.
const VOICE_FLOOR_HZ := 90.0
const VOICE_CEIL_HZ := 1050.0
const MIN_BUFFER := 768
# Sliding-YIN ring buffer: YIN runs on the last WINDOW_SIZE samples regardless
# of how many fresh samples arrived this poll. HOP_SIZE is the minimum number
# of new samples we require between successive YIN runs — it keeps CPU bounded
# and prevents redundant work when the harness polls faster than samples
# accumulate. With a 48 kHz mic, WINDOW=1280 ≈ 27 ms and HOP=512 ≈ 10.7 ms,
# so YIN runs at most ~93 Hz independent of polling rate.
# Halved from 2048 in v3 to cut YIN compute by ~50%. Constraint: WINDOW must
# hold at least 2 cycles of the lowest expected fundamental. At MIN_FREQ = 90 Hz
# and 48 kHz, two cycles = 1066 samples — so we round UP to 1280 to keep a
# comfortable margin. Voice up to F6 (1400 Hz) needs only 70 samples per cycle,
# trivially covered. Live YIN latency drops from ~15 ms to ~7 ms.
const WINDOW_SIZE := 1280
const HOP_SIZE := 512
# Soft-mode hop is wider — for offline candidate harvest we don't need every
# 10 ms refresh that live needs. 1024 samples (~21 ms at 48 kHz) still gives
# us ~46 candidates/second, which is plenty for the windowed PC vote, while
# halving the YIN compute over a full take.
const SOFT_HOP_SIZE := 1024
const YIN_THRESHOLD := 0.15
const CONFIDENCE_THRESHOLD := 0.52
# At "high confidence" (well above CONFIDENCE_THRESHOLD) we accept a single
# stable frame instead of waiting for two — cuts ~10 ms of onset latency on
# clean signals where YIN nailed it on the first try.
const HIGH_CONFIDENCE_FAST_TRACK := 0.78
const STABILITY_REQUIRED := 2
const RMS_THRESHOLD := 0.0025
# Median filter window — smaller = faster response, larger = more vibrato
# smoothing. 3 is enough to reject single-sample outliers without adding
# noticeable lag. (Was 5; saved ~21 ms of detection latency.)
const MEDIAN_WINDOW := 3
const MAX_TAKE_RECORDING_SECONDS := 20.0
const CANDIDATE_CONFIDENCE_MIN := 0.30
const SOFT_RMS_THRESHOLD := 0.0012
const SOFT_NOISE_GATE_MULT := 2.25
const ANALYSIS_TARGET_RMS := 0.035
const ANALYSIS_GAIN_MAX := 12.0
# HPF cutoff — 85 Hz kills HVAC rumble, computer fan whine, and most 60/50 Hz
# mains hum without clipping bass voices (E2 = 82 Hz is below the cutoff and
# gets ~6 dB attenuation; A2 = 110 Hz passes essentially unattenuated).
const HPF_CUTOFF_HZ := 85.0
# How long the HPF needs to settle before we trust its output. The one-pole
# transient is ~3 time-constants ≈ 6 ms at 85 Hz, which is well under 1024
# samples at any sample rate the engine supports.
const HPF_WARMUP_SAMPLES := 512

# Adaptive noise floor: rolling EMA over frames classified as silence. The
# effective volume gate is max(RMS_THRESHOLD, _noise_floor * NOISE_GATE_MULT).
const NOISE_FLOOR_DECAY := 0.95   # fast learn during silence
const NOISE_GATE_MULT := 4.0      # require 12 dB over noise floor to engage
# Onset detection: a fast baseline (EMA) tracks recent loudness; an onset is
# declared when the current frame RMS exceeds baseline * ONSET_RISE_RATIO.
const ONSET_BASELINE_DECAY := 0.80
const ONSET_RISE_RATIO := 2.0     # ~6 dB rise above recent baseline
# Spectral confidence: ratio of energy at the 2F bin to the fundamental bin.
# Sustained vowels carry meaningful energy at the first harmonic; pure noise
# does not. We don't require a hard threshold — we just demote weak harmonic
# evidence into a lower confidence.
const HARMONIC_RATIO_MIN := 0.10
# Voice range adaptation: after observing this many accepted detections we
# lock in a preferred octave center, which the octave-error corrector uses.
const VOICE_RANGE_WARMUP := 3

var _sample_rate: float = SAMPLE_RATE_FALLBACK
var _capture: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _bus_idx: int = -1
var _is_listening := false
var _stable_midi: int = -1
var _stable_count: int = 0
var _last_detected_midi: int = -1
var _setup_done := false
var _freq_history: PackedFloat32Array = PackedFloat32Array()  # rolling median buffer
var _no_frame_polls := 0
var _silence_after_capture: AudioEffectAmplify = null
var _take_recording_enabled := false
var _take_recording_samples: PackedFloat32Array = PackedFloat32Array()
var _soft_pitch_mode := false
var _samples_seen: int = 0

# DSP state — persisted across poll() calls
var _hpf_prev_in: float = 0.0
var _hpf_prev_out: float = 0.0
var _noise_floor: float = RMS_THRESHOLD
var _onset_baseline: float = 0.0
var _last_onset_frame: int = -1000
var _frame_counter: int = 0

# Voice range adaptation
var _voice_midi_samples: Array = []  # raw integer MIDI of recent accepted notes
var _voice_octave_center: float = 60.0  # ema of accepted MIDI values

# Caller-supplied prior — pitch class (0–11) we expect right now, or -1 if none.
var _target_pitch_class: int = -1

# Last raw RMS (made available in returned dicts for UI metering / debugging).
var _last_rms: float = 0.0

# Sliding-YIN ring buffer + hop accounting.
var _ring: PackedFloat32Array = PackedFloat32Array()  # head appends new, drop from front
var _samples_since_yin: int = 0

# Adaptive YIN search range. After a few accepted detections we know roughly
# where the singer's voice sits in tau-space; narrowing the search bounds
# avoids spurious low-tau matches (high-freq harmonics) and meaningfully
# speeds up the YIN difference function inner loop. Values of -1 mean
# "no adaptation yet — use full MIN_FREQ..MAX_FREQ range."
var _voice_period_min: int = -1
var _voice_period_max: int = -1
# Per-window cached HPF alpha (depends on _sample_rate, computed once at setup).
var _hpf_alpha_cached: float = 0.0


func setup(owner: Node) -> bool:
	if _setup_done:
		return true
	# Use the audio server's actual mix rate so YIN's tau→freq math stays correct
	# on devices that don't default to 44100 Hz.
	var srv_rate := AudioServer.get_mix_rate()
	if srv_rate > 0.0:
		_sample_rate = srv_rate
	# Create a dedicated mic capture bus. Do not mute/attenuate the bus before
	# capture: the detector needs the raw microphone signal. A post-capture
	# amplifier silences speaker output without shrinking the captured frames.
	_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_bus_idx)
	AudioServer.set_bus_name(_bus_idx, "MicCapture")
	AudioServer.set_bus_send(_bus_idx, "Master")
	AudioServer.set_bus_mute(_bus_idx, false)
	AudioServer.set_bus_volume_db(_bus_idx, 0.0)

	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(_bus_idx, _capture, 0)
	_silence_after_capture = AudioEffectAmplify.new()
	_silence_after_capture.volume_db = -80.0
	AudioServer.add_bus_effect(_bus_idx, _silence_after_capture, 1)

	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = &"MicCapture"
	owner.add_child(_mic_player)
	# Pre-compute the HPF coefficient once. α = exp(-2π·fc/fs). Cached so the
	# inner loop avoids a transcendental call per sample.
	_hpf_alpha_cached = exp(-2.0 * PI * HPF_CUTOFF_HZ / _sample_rate)
	_setup_done = true
	return true


func start_listening() -> void:
	if not _setup_done or _mic_player == null:
		return
	_stable_midi = -1
	_stable_count = 0
	_last_detected_midi = -1
	_freq_history.clear()
	_no_frame_polls = 0
	_onset_baseline = 0.0
	_last_onset_frame = -1000
	_frame_counter = 0
	_ring.clear()
	_samples_since_yin = 0
	_samples_seen = 0
	# Pre-warm the HPF: run HPF_WARMUP_SAMPLES samples of silence through the
	# filter so its state is settled before the first real mic frame arrives.
	# Without this, the first frame after start can be transient-distorted
	# (the singer's first attack is the most important note to read correctly).
	_hpf_prev_in = 0.0
	_hpf_prev_out = 0.0
	var alpha := _hpf_alpha_cached
	for _i in HPF_WARMUP_SAMPLES:
		# Apply HPF to 0.0 input — state decays toward zero without injecting
		# energy. After ~3 time-constants the output is effectively 0.
		_hpf_prev_out = alpha * (_hpf_prev_out + 0.0 - _hpf_prev_in)
		_hpf_prev_in = 0.0
	# Keep adaptive state (_noise_floor, _voice_octave_center, _voice_midi_samples,
	# _voice_period_min/_max) across start/stop so a singer's calibration
	# survives the brief pause between sight-singing rounds.
	if _capture != null:
		_capture.clear_buffer()
	_mic_player.play()
	_is_listening = _mic_player.playing


func stop_listening() -> void:
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()
	_is_listening = false
	_stable_midi = -1
	_stable_count = 0
	_no_frame_polls = 0


func is_listening() -> bool:
	return _is_listening


func reset_capture_buffer() -> void:
	if _capture != null:
		_capture.clear_buffer()
	_no_frame_polls = 0
	_stable_midi = -1
	_stable_count = 0
	_freq_history.clear()
	_ring.clear()
	_samples_since_yin = 0
	_samples_seen = 0


# Reset adaptive state (noise floor, voice range). Call between songs or when
# the singer/environment changes meaningfully.
func reset_adaptation() -> void:
	_noise_floor = RMS_THRESHOLD
	_voice_midi_samples.clear()
	_voice_octave_center = 60.0
	_onset_baseline = 0.0
	_voice_period_min = -1
	_voice_period_max = -1


# Stronger reset for between-take cleanup. Wipes EVERYTHING the detector has
# learned about the current session — voice range, noise floor, onset baseline,
# stability counters, median history, HPF state. Used after melody playback
# (when the speaker output may have polluted the noise floor) so the next take
# starts from a clean baseline.
func reset_voice_state() -> void:
	reset_adaptation()
	_stable_midi = -1
	_stable_count = 0
	_freq_history.clear()
	_ring.clear()
	_samples_since_yin = 0
	_samples_seen = 0
	# Pre-warm HPF again to drain any captured speaker bleed from the filter.
	_hpf_prev_in = 0.0
	_hpf_prev_out = 0.0
	var alpha := _hpf_alpha_cached
	for _i in HPF_WARMUP_SAMPLES:
		_hpf_prev_out = alpha * (_hpf_prev_out + 0.0 - _hpf_prev_in)
		_hpf_prev_in = 0.0
	if _capture != null:
		_capture.clear_buffer()


# Toggles the analysis (soft) mode. In analysis mode the volume gate, gain
# normalisation, and confidence floor relax so the detector emits a much denser
# stream of candidates per second — appropriate for *offline scoring* of an
# already-captured take, NOT for real-time UI feedback (which would flicker).
# Callers MUST clear it (call with false) after the analysis pass; the detector
# keeps the flag persistent across polls otherwise.
func set_analysis_mode(enabled: bool) -> void:
	_soft_pitch_mode = enabled
	# Reset frame-level transient state so the new mode doesn't inherit
	# stability counters from the previous mode.
	_stable_midi = -1
	_stable_count = 0
	_freq_history.clear()


func is_analysis_mode() -> bool:
	return _soft_pitch_mode


# Sets the expected pitch class (0=C…11=B). Pass -1 to clear. The detector uses
# this as a soft prior when resolving octave ambiguity — it doesn't force a
# match, just tilts the octave decision toward the target's PC when otherwise
# equally likely.
func set_target_pitch_class(pc: int) -> void:
	if pc < 0 or pc > 11:
		_target_pitch_class = -1
	else:
		_target_pitch_class = pc


func set_soft_pitch_mode(enabled: bool) -> void:
	_soft_pitch_mode = enabled


func start_take_recording() -> void:
	_take_recording_samples.clear()
	_take_recording_enabled = true


func stop_take_recording() -> void:
	_take_recording_enabled = false


func clear_take_recording() -> void:
	_take_recording_samples.clear()
	_take_recording_enabled = false


func has_take_recording() -> bool:
	return _take_recording_samples.size() > 0


# Raw (HPF'd, mono) take samples. Used by the offline soft pass to re-analyse
# the captured take. Returns a *copy* so caller mutations don't corrupt the
# detector's internal buffer.
func get_take_recording_samples() -> PackedFloat32Array:
	return _take_recording_samples.duplicate()


func get_sample_rate() -> float:
	return _sample_rate


func get_take_recording_stream() -> AudioStreamWAV:
	if _take_recording_samples.is_empty():
		return null
	var data := PackedByteArray()
	data.resize(_take_recording_samples.size() * 2)
	for i in range(_take_recording_samples.size()):
		var sample := int(round(clampf(_take_recording_samples[i], -1.0, 1.0) * 32767.0))
		if sample < 0:
			sample += 65536
		var byte_idx := i * 2
		data[byte_idx] = sample & 0xff
		data[byte_idx + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(_sample_rate)
	stream.stereo = false
	stream.data = data
	return stream


func poll() -> Dictionary:
	if not _is_listening or _capture == null:
		return {"detected": false, "reason": "not_listening"}

	# Drain whatever fresh frames the capture has into the ring buffer, HPF'd
	# inline. The ring keeps the last WINDOW_SIZE samples so YIN always sees a
	# full window even when individual polls only deliver a small chunk.
	var frames_avail := _capture.get_frames_available()
	if frames_avail > 0:
		var read_count := mini(frames_avail, 4096)
		var buffer: PackedVector2Array = _capture.get_buffer(read_count)
		var added := buffer.size()
		if added > 0:
			# HPF state persists across polls — no per-call discontinuity.
			# Cutoff is HPF_CUTOFF_HZ (85 Hz). Cached alpha avoids the per-poll
			# transcendental call.
			var hpf_alpha: float = _hpf_alpha_cached
			var prev_in := _hpf_prev_in
			var prev_out := _hpf_prev_out
			var new_chunk := PackedFloat32Array()
			new_chunk.resize(added)
			for i in added:
				var raw := (buffer[i].x + buffer[i].y) * 0.5
				var filtered: float = hpf_alpha * (prev_out + raw - prev_in)
				prev_in = raw
				prev_out = filtered
				new_chunk[i] = filtered
			_hpf_prev_in = prev_in
			_hpf_prev_out = prev_out
			# Append to ring; drop the oldest to keep size ≤ WINDOW_SIZE.
			_append_to_ring(new_chunk)
			_append_take_recording_samples(new_chunk)
			_samples_since_yin += added
			_samples_seen += added

	# Need a full window before YIN can run at all.
	if _ring.size() < MIN_BUFFER:
		_no_frame_polls += 1
		return {"detected": false, "reason": "no_frames", "frames": _ring.size(), "no_frame_polls": _no_frame_polls}

	# Hop guard: don't re-run YIN until HOP_SIZE new samples have accumulated.
	# Live polling stays at HOP_SIZE regardless of soft mode — soft mode in
	# live just relaxes confidence/RMS thresholds for denser candidate emission.
	# The wider SOFT_HOP_SIZE is used inside analyze_take_samples (offline).
	if _samples_since_yin < HOP_SIZE:
		return {"detected": false, "reason": "stabilizing", "rms": _last_rms}
	_samples_since_yin = 0
	_no_frame_polls = 0
	_frame_counter += 1

	# Pull the last WINDOW_SIZE samples (or whatever we have if less, which
	# only happens during the first second or so after start_listening).
	var window_n: int = mini(_ring.size(), WINDOW_SIZE)
	var mono := PackedFloat32Array()
	mono.resize(window_n)
	var start_idx: int = _ring.size() - window_n
	for i in window_n:
		mono[i] = _ring[start_idx + i]

	# RMS of the analysis window. Using the full window (not just the new
	# chunk) means the volume gate reflects "what YIN is actually analysing,"
	# so the gate logic stays consistent with the pitch decision.
	var rms := 0.0
	for i in window_n:
		rms += mono[i] * mono[i]
	rms = sqrt(rms / float(window_n))
	_last_rms = rms

	# Adaptive volume gate — the noise floor self-calibrates during silence,
	# so a quieter room gets a quieter gate (and louder room gets stricter).
	var base_gate := SOFT_RMS_THRESHOLD if _soft_pitch_mode else RMS_THRESHOLD
	var gate_mult := SOFT_NOISE_GATE_MULT if _soft_pitch_mode else NOISE_GATE_MULT
	var gate: float = maxf(base_gate, _noise_floor * gate_mult)
	if rms < gate:
		_noise_floor = lerpf(rms, _noise_floor, NOISE_FLOOR_DECAY)
		_onset_baseline = lerpf(rms, _onset_baseline, ONSET_BASELINE_DECAY)
		_stable_count = 0
		return {"detected": false, "reason": "too_quiet", "rms": rms, "gate": gate}

	var analysis_mono: PackedFloat32Array = _analysis_window(mono, rms)

	# Onset detection: did the volume just jump up? Used by the session so it
	# can distinguish "new note attacked" from "sustained continuation."
	var is_onset := false
	if _onset_baseline > 0.0001 and rms > _onset_baseline * ONSET_RISE_RATIO:
		is_onset = true
		_last_onset_frame = _frame_counter
	_onset_baseline = lerpf(rms, _onset_baseline, ONSET_BASELINE_DECAY)

	# Run YIN on the UNWINDOWED signal. Earlier we applied a Hann taper here
	# but that was a misapplication: YIN's difference function expects raw
	# samples, and tapering the edges to zero adds spurious energy at the
	# correct period (one side near zero, the other side mid-buffer at full
	# amplitude → non-zero squared diff at the right τ).
	# YIN's tau search range is narrowed adaptively — once we've observed the
	# singer's range, we only need to search slightly outside it. Speeds the
	# inner loop and reduces sub-harmonic false matches at low τ.
	var result := _yin_detect_ranged(analysis_mono, _voice_period_min, _voice_period_max)
	if not result["detected"]:
		_stable_count = 0
		return {"detected": false, "reason": "no_pitch", "rms": rms}

	var freq: float = result["freq"]
	var confidence: float = result["confidence"]
	# Multi-harmonic confidence: a sung vowel has energy at 2F AND 3F. We also
	# check F/2 — if the half-frequency has MORE energy than the detected F,
	# YIN almost certainly picked a sub-harmonic and the true fundamental is
	# F/2 (octave too low). The three checks together catch both kinds of
	# octave error YIN can make.
	var goertzel_input: PackedFloat32Array = _apply_hann_window(analysis_mono)
	var harmonic_ratio: float = _goertzel_ratio(goertzel_input, freq * 2.0, freq)
	var harmonic_ratio_3f: float = _goertzel_ratio(goertzel_input, freq * 3.0, freq)
	var half_ratio: float = _goertzel_ratio(goertzel_input, freq * 0.5, freq) if freq * 0.5 >= MIN_FREQ else 0.0
	# Weak harmonic content at BOTH 2F and 3F → likely octave error (or noise).
	# Demote a little but don't reject — the median + stability filter will
	# absorb a single weak frame, and we still want it in the candidate stream.
	if harmonic_ratio < HARMONIC_RATIO_MIN and harmonic_ratio_3f < HARMONIC_RATIO_MIN:
		confidence *= 0.78
	elif harmonic_ratio < HARMONIC_RATIO_MIN:
		confidence *= 0.90
	# If F/2 has substantially more energy than F, we picked the wrong octave.
	# Halve the reported frequency (i.e. move to the true fundamental).
	if half_ratio > 1.6:
		freq *= 0.5

	# Median filter over the last MEDIAN_WINDOW raw detections. Vibrato + singer
	# wobble can swing freq ±10–20 Hz frame to frame; median smooths the bounce
	# without adding much latency.
	_freq_history.append(freq)
	if _freq_history.size() > MEDIAN_WINDOW:
		_freq_history.remove_at(0)
	var smoothed_freq: float = _median_freq(_freq_history)

	var raw_midi := freq_to_midi(smoothed_freq)
	if raw_midi < 24 or raw_midi > 96:  # C1 to C7 safety range
		_stable_count = 0
		return {"detected": false, "reason": "out_of_range", "rms": rms, "freq": smoothed_freq}
	var raw_target_freq := 440.0 * pow(2.0, (float(raw_midi) - 69.0) / 12.0)
	var raw_cents_off := 1200.0 * log(smoothed_freq / raw_target_freq) / log(2.0)
	var candidate := _candidate_dict(
		smoothed_freq,
		freq,
		raw_midi,
		raw_cents_off,
		confidence,
		rms,
		harmonic_ratio,
		false,
		window_n
	)
	if confidence < CANDIDATE_CONFIDENCE_MIN:
		_stable_count = 0
		return {"detected": false, "reason": "low_confidence", "rms": rms, "confidence": confidence, "harmonic_ratio": harmonic_ratio}
	if confidence < CONFIDENCE_THRESHOLD:
		_stable_count = 0
		return {"detected": false, "reason": "low_confidence", "rms": rms, "confidence": confidence, "harmonic_ratio": harmonic_ratio, "candidate": candidate, "candidates": [candidate]}

	# Octave-error correction — guarded version. Earlier this ran on every
	# detection and snapped the raw MIDI to whichever candidate was closest to
	# the EMA voice center. That was too aggressive: a singer doing legato
	# sight-singing has no onset between notes, so a legitimate octave jump
	# (C4 → C5) was being dragged back down to the voice center. Worse, the
	# MIDI flip-flopping fragmented phrase segments and caused alignment to
	# mis-match notes → "wrong" verdicts on correct singing.
	# New policy: only correct when YIN's confidence is borderline, i.e. we
	# have reason to suspect a subharmonic / harmonic-overreach error. At
	# high confidence, trust the raw detection.
	var midi: int = raw_midi
	if is_onset:
		# Singer just attacked — definitely trust YIN.
		midi = raw_midi
	elif confidence < 0.65:
		midi = _correct_octave(raw_midi, false)

	# Stability filter -- require N consecutive frames with same MIDI note.
	# Fast-track: at confidence above HIGH_CONFIDENCE_FAST_TRACK we accept a
	# single stable frame — cuts ~10–20 ms off note-onset latency for clean
	# signals where YIN nailed it the first time.
	if midi == _stable_midi:
		_stable_count += 1
	else:
		_stable_midi = midi
		_stable_count = 1

	var required_stability: int = 1 if confidence >= HIGH_CONFIDENCE_FAST_TRACK else STABILITY_REQUIRED
	if _stable_count < required_stability:
		return {"detected": false, "reason": "stabilizing", "rms": rms, "midi": midi, "candidate": candidate, "candidates": [candidate]}

	_last_detected_midi = midi
	_record_voice_sample(midi)
	# Cents-off relative to the nearest equal-tempered MIDI note. Positive =
	# sharp, negative = flat. Used by the UI to coach singers/instrumentalists.
	# Compute against the FINAL chosen midi (after octave correction), but using
	# the smoothed frequency — so cents-off reads correctly even after octave
	# snap (we just shift the reference target_freq by the octave delta).
	var target_freq := 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
	# If we shifted octaves, the smoothed_freq is in the OTHER octave; bring
	# it back into the same octave as the target for the cents-off math.
	var ref_freq: float = smoothed_freq
	while ref_freq > target_freq * 1.5:
		ref_freq *= 0.5
	while ref_freq < target_freq * 0.6667:
		ref_freq *= 2.0
	var cents_off := 1200.0 * log(ref_freq / target_freq) / log(2.0)
	candidate["stable"] = true
	candidate["midi"] = midi
	candidate["cents_off"] = cents_off
	return {
		"detected": true,
		"freq": smoothed_freq,
		"raw_freq": freq,
		"raw_midi": raw_midi,
		"midi": midi,
		"note_name": midi_to_note_name(midi),
		"octave": midi_to_octave(midi),
		"full_name": midi_to_full_name(midi),
		"confidence": confidence,
		"cents_off": cents_off,
		"is_onset": is_onset,
		"harmonic_ratio": harmonic_ratio,
		"rms": rms,
		"candidate": candidate,
		"candidates": [candidate],
	}


# Offline pass: feed already-captured mono samples through the same YIN
# pipeline used by live poll() and return ALL candidate detections (stable +
# unstable, low + high confidence above CANDIDATE_CONFIDENCE_MIN). Used by the
# sight-singing scorer to produce a dense candidate list from a finished take.
#
# Caller is responsible for switching the detector into analysis mode first
# (set_analysis_mode(true)) and clearing it after; this method itself does not
# touch _soft_pitch_mode so the caller can also use it in strict mode if they
# want to compare passes.
func analyze_take_samples(mono_samples: PackedFloat32Array, analysis_hop: int = HOP_SIZE) -> Array:
	var out: Array = []
	if mono_samples.is_empty():
		return out
	analysis_hop = maxi(HOP_SIZE, analysis_hop)
	# Snapshot live state and reset transient counters so the offline pass
	# starts from a clean slate. We restore real-time state at the end.
	var saved_ring: PackedFloat32Array = _ring
	var saved_samples_since_yin: int = _samples_since_yin
	var saved_samples_seen: int = _samples_seen
	var saved_freq_history: PackedFloat32Array = _freq_history
	var saved_stable_midi: int = _stable_midi
	var saved_stable_count: int = _stable_count
	var saved_hpf_in: float = _hpf_prev_in
	var saved_hpf_out: float = _hpf_prev_out
	_ring = PackedFloat32Array()
	_samples_since_yin = 0
	_samples_seen = 0
	_freq_history = PackedFloat32Array()
	_stable_midi = -1
	_stable_count = 0
	_hpf_prev_in = 0.0
	_hpf_prev_out = 0.0
	# Apply HPF inline as we feed the ring (matches live pipeline exactly).
	# Use the same cached HPF alpha as live pipeline (85 Hz cutoff).
	var hpf_alpha: float = _hpf_alpha_cached
	var prev_in: float = 0.0
	var prev_out: float = 0.0
	# Process the take in HOP_SIZE chunks so we get the same YIN cadence the
	# live pipeline would have produced — but without any drop-on-no-frames.
	var i: int = 0
	while i < mono_samples.size():
		var chunk_end: int = mini(i + analysis_hop, mono_samples.size())
		var chunk_n: int = chunk_end - i
		var chunk := PackedFloat32Array()
		chunk.resize(chunk_n)
		for k in chunk_n:
			var raw: float = mono_samples[i + k]
			var filtered: float = hpf_alpha * (prev_out + raw - prev_in)
			prev_in = raw
			prev_out = filtered
			chunk[k] = filtered
		_append_to_ring(chunk)
		_samples_since_yin += chunk_n
		_samples_seen += chunk_n
		if _ring.size() >= MIN_BUFFER and _samples_since_yin >= HOP_SIZE:
			var step: Dictionary = _run_yin_step_for_analysis()
			_samples_since_yin = 0
			if not step.is_empty():
				out.append(step)
		i = chunk_end
	# Restore live state — the next live poll() should see no side effects.
	_ring = saved_ring
	_samples_since_yin = saved_samples_since_yin
	_samples_seen = saved_samples_seen
	_freq_history = saved_freq_history
	_stable_midi = saved_stable_midi
	_stable_count = saved_stable_count
	_hpf_prev_in = saved_hpf_in
	_hpf_prev_out = saved_hpf_out
	return out


# One YIN step against the current ring contents — used by the offline pass.
# Returns the candidate dict on a usable detection, {} otherwise. Mirrors the
# meaningful parts of poll()'s analysis section without the capture-buffer plumbing.
func _run_yin_step_for_analysis() -> Dictionary:
	var window_n: int = mini(_ring.size(), WINDOW_SIZE)
	if window_n < MIN_BUFFER:
		return {}
	var mono := PackedFloat32Array()
	mono.resize(window_n)
	var start_idx: int = _ring.size() - window_n
	for i in window_n:
		mono[i] = _ring[start_idx + i]
	var rms := 0.0
	for i in window_n:
		rms += mono[i] * mono[i]
	rms = sqrt(rms / float(window_n))
	_last_rms = rms
	var base_gate := SOFT_RMS_THRESHOLD if _soft_pitch_mode else RMS_THRESHOLD
	var gate_mult := SOFT_NOISE_GATE_MULT if _soft_pitch_mode else NOISE_GATE_MULT
	var gate: float = maxf(base_gate, _noise_floor * gate_mult)
	if rms < gate:
		_noise_floor = lerpf(rms, _noise_floor, NOISE_FLOOR_DECAY)
		return {}
	var analysis_mono: PackedFloat32Array = _analysis_window(mono, rms)
	# Use the same adaptive-range YIN as live so the offline pass gets the
	# same accuracy improvements (sub-harmonic rejection, octave-error catch).
	var result := _yin_detect_ranged(analysis_mono, _voice_period_min, _voice_period_max)
	if not result.get("detected", false):
		return {}
	var freq: float = result["freq"]
	var confidence: float = result["confidence"]
	var goertzel_input: PackedFloat32Array = _apply_hann_window(analysis_mono)
	var harmonic_ratio: float = _goertzel_ratio(goertzel_input, freq * 2.0, freq)
	var harmonic_ratio_3f: float = _goertzel_ratio(goertzel_input, freq * 3.0, freq)
	var half_ratio: float = _goertzel_ratio(goertzel_input, freq * 0.5, freq) if freq * 0.5 >= MIN_FREQ else 0.0
	if harmonic_ratio < HARMONIC_RATIO_MIN and harmonic_ratio_3f < HARMONIC_RATIO_MIN:
		confidence *= 0.78
	elif harmonic_ratio < HARMONIC_RATIO_MIN:
		confidence *= 0.90
	if half_ratio > 1.6:
		freq *= 0.5
	if confidence < CANDIDATE_CONFIDENCE_MIN:
		return {}
	_freq_history.append(freq)
	if _freq_history.size() > MEDIAN_WINDOW:
		_freq_history.remove_at(0)
	var smoothed_freq: float = _median_freq(_freq_history)
	var midi := freq_to_midi(smoothed_freq)
	if midi < 24 or midi > 96:
		return {}
	var target_freq := 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)
	var cents_off := 1200.0 * log(smoothed_freq / target_freq) / log(2.0)
	return _candidate_dict(smoothed_freq, freq, midi, cents_off, confidence, rms, harmonic_ratio, false, window_n)


func _analysis_window(mono: PackedFloat32Array, rms: float) -> PackedFloat32Array:
	if not _soft_pitch_mode or mono.is_empty() or rms <= 0.000001:
		return mono
	var gain := clampf(ANALYSIS_TARGET_RMS / rms, 1.0, ANALYSIS_GAIN_MAX)
	if gain <= 1.001:
		return mono
	var boosted := PackedFloat32Array()
	boosted.resize(mono.size())
	for i in mono.size():
		boosted[i] = clampf(mono[i] * gain, -1.0, 1.0)
	return boosted


func _candidate_dict(freq: float, raw_freq: float, midi: int, cents_off: float, confidence: float, rms: float, harmonic_ratio: float, stable: bool, window_n: int) -> Dictionary:
	var center_sample := maxf(0.0, float(_samples_seen) - float(window_n) * 0.5)
	return {
		"time": center_sample / _sample_rate,
		"freq": freq,
		"raw_freq": raw_freq,
		"midi": midi,
		"note_name": midi_to_note_name(midi),
		"octave": midi_to_octave(midi),
		"full_name": midi_to_full_name(midi),
		"confidence": confidence,
		"cents_off": cents_off,
		"rms": rms,
		"harmonic_ratio": harmonic_ratio,
		"stable": stable,
	}


# Picks the octave (raw_midi ± 12) closest to the voice center, with a small
# bias toward the caller-supplied target pitch class.
func _correct_octave(raw_midi: int, is_onset: bool) -> int:
	if is_onset:
		return raw_midi
	if _voice_midi_samples.size() < VOICE_RANGE_WARMUP:
		# Not enough data to correct — accept raw, just bias by target PC if any.
		return _pc_biased_pick([raw_midi - 12, raw_midi, raw_midi + 12], raw_midi)
	var candidates := [raw_midi - 12, raw_midi, raw_midi + 12]
	var best := raw_midi
	var best_score := INF
	for c in candidates:
		if c < 36 or c > 84:
			continue  # ignore unreasonable singing pitches
		var dist: float = absf(float(c) - _voice_octave_center)
		# Small bonus for matching the target PC: shave 1.5 semitones off the
		# effective distance. Enough to break a tie, not enough to overrule a
		# clear octave preference.
		if _target_pitch_class >= 0 and posmod(c, 12) == _target_pitch_class:
			dist -= 1.5
		if dist < best_score:
			best_score = dist
			best = c
	return best


# Helper used during voice-range warmup. With no center to anchor to, we can
# still prefer an octave that matches the expected pitch class.
func _pc_biased_pick(candidates: Array, fallback: int) -> int:
	if _target_pitch_class < 0:
		return fallback
	for c in candidates:
		if c < 36 or c > 84:
			continue
		if posmod(c, 12) == _target_pitch_class:
			return c
	return fallback


# Updates the voice range adaptation state. We keep the last N accepted MIDI
# values and a simple EMA of them; the corrector reads the EMA. We also track
# the [min, max] of recent MIDIs to derive an adaptive YIN search range.
func _record_voice_sample(midi: int) -> void:
	_voice_midi_samples.append(midi)
	if _voice_midi_samples.size() > 32:
		_voice_midi_samples.pop_front()
	# EMA with a moderately slow decay so a singer who briefly drifts an
	# octave (or sings a high cadence) doesn't permanently relocate the center.
	_voice_octave_center = lerpf(float(midi), _voice_octave_center, 0.7)
	# After the warmup, derive a YIN search range from observed voice MIDIs.
	# We span ~7 semitones above and below the observed extremes so legitimate
	# leaps still get matched.
	if _voice_midi_samples.size() >= VOICE_RANGE_WARMUP:
		var lo_midi: int = 127
		var hi_midi: int = 0
		for m in _voice_midi_samples:
			var mi: int = int(m)
			if mi < lo_midi:
				lo_midi = mi
			if mi > hi_midi:
				hi_midi = mi
		# Convert MIDI extremes to period bounds, with margin. Higher MIDI = lower
		# period (period is inversely proportional to frequency).
		var hi_freq: float = 440.0 * pow(2.0, (float(hi_midi + 7) - 69.0) / 12.0)
		var lo_freq: float = 440.0 * pow(2.0, (float(lo_midi - 7) - 69.0) / 12.0)
		hi_freq = clampf(hi_freq, VOICE_FLOOR_HZ, VOICE_CEIL_HZ)
		lo_freq = clampf(lo_freq, VOICE_FLOOR_HZ, VOICE_CEIL_HZ)
		_voice_period_min = int(_sample_rate / hi_freq)  # smallest tau for highest freq
		_voice_period_max = int(_sample_rate / lo_freq)  # largest tau for lowest freq


# Append a chunk of filtered samples to the sliding ring buffer. We keep the
# last WINDOW_SIZE samples; everything older is discarded. Implemented as a
# PackedFloat32Array because GDScript's array methods make ring-as-circular
# more error-prone than ring-as-trimmed-list, and at 2048 samples the cost of
# a single allocation per hop is negligible.
func _append_to_ring(chunk: PackedFloat32Array) -> void:
	if chunk.is_empty():
		return
	_ring.append_array(chunk)
	if _ring.size() > WINDOW_SIZE:
		var drop: int = _ring.size() - WINDOW_SIZE
		# PackedFloat32Array has no slice-assign or pop_front_many; rebuild.
		var kept := PackedFloat32Array()
		kept.resize(WINDOW_SIZE)
		for i in WINDOW_SIZE:
			kept[i] = _ring[drop + i]
		_ring = kept


func _append_take_recording_samples(mono: PackedFloat32Array) -> void:
	if not _take_recording_enabled or mono.is_empty():
		return
	var max_samples := int(_sample_rate * MAX_TAKE_RECORDING_SECONDS)
	if _take_recording_samples.size() >= max_samples:
		return
	var remaining := max_samples - _take_recording_samples.size()
	var count := mini(remaining, mono.size())
	for i in range(count):
		_take_recording_samples.append(mono[i])


# Returns the median value of a PackedFloat32Array without mutating it.
# Used to smooth raw frequency detections against vibrato / onset wobble.
static func _median_freq(values: PackedFloat32Array) -> float:
	var n := values.size()
	if n == 0:
		return 0.0
	if n == 1:
		return values[0]
	var copy: Array = []
	for v in values:
		copy.append(v)
	copy.sort()
	var mid := int(n / 2)
	if n % 2 == 1:
		return float(copy[mid])
	return (float(copy[mid - 1]) + float(copy[mid])) * 0.5


# Multiplies the signal by a Hann window in place into a new array. The
# tapered edges reduce edge artifacts in YIN's difference function and
# meaningfully reduce sub-harmonic mis-detections on short buffers.
static func _apply_hann_window(mono: PackedFloat32Array) -> PackedFloat32Array:
	var n := mono.size()
	if n < 2:
		return mono
	var out := PackedFloat32Array()
	out.resize(n)
	var denom: float = float(n - 1)
	for i in range(n):
		var w: float = 0.5 - 0.5 * cos(2.0 * PI * float(i) / denom)
		out[i] = mono[i] * w
	return out


# Returns the energy ratio between a probe frequency and a reference
# frequency, measured by a Goertzel filter at each. We use this to verify
# that the detected fundamental's first harmonic (2F) carries meaningful
# energy — a YIN octave error or a flat sine wave does not.
func _goertzel_ratio(mono: PackedFloat32Array, probe_freq: float, ref_freq: float) -> float:
	if probe_freq <= 0.0 or ref_freq <= 0.0 or mono.is_empty():
		return 0.0
	var n_max: int = mini(mono.size(), 1024)
	# Probe energy
	var probe_e: float = _goertzel_energy(mono, probe_freq, n_max)
	var ref_e: float = _goertzel_energy(mono, ref_freq, n_max)
	if ref_e < 0.000001:
		return 0.0
	return probe_e / ref_e


func _goertzel_energy(mono: PackedFloat32Array, freq: float, n: int) -> float:
	if n < 4:
		return 0.0
	var omega: float = 2.0 * PI * freq / _sample_rate
	var coeff: float = 2.0 * cos(omega)
	var s_prev: float = 0.0
	var s_prev2: float = 0.0
	for i in range(n):
		var s: float = mono[i] + coeff * s_prev - s_prev2
		s_prev2 = s_prev
		s_prev = s
	return s_prev2 * s_prev2 + s_prev * s_prev - coeff * s_prev * s_prev2


# Range-adaptive YIN entry point — narrows the period search to the singer's
# observed range plus margin. Falls back to the full MIN_FREQ..MAX_FREQ range
# before warmup completes. Called by poll(); _yin_detect retains the full-range
# implementation for unit tests and direct invocation.
func _yin_detect_ranged(mono: PackedFloat32Array, period_min: int, period_max: int) -> Dictionary:
	if period_min < 0 or period_max < 0:
		return _yin_detect(mono)
	# Translate adaptive bounds into a usable YIN search. We still compute the
	# diff/cmnd arrays at low τ because the cumulative-mean normalisation needs
	# the early terms to be correct, but we restrict the threshold search.
	var n := mono.size()
	var hard_max: int = int(_sample_rate / MIN_FREQ)
	var hard_min: int = int(_sample_rate / MAX_FREQ)
	# Use the smaller of hard_max and (adaptive max + 30% margin); biggest gain
	# is when the singer is solidly mid-range so we skip computing diff[] for
	# τ values near the bass floor that contribute only noise.
	var search_max: int = mini(hard_max, int(period_max * 1.3))
	search_max = mini(search_max, n / 2)
	var search_min: int = maxi(hard_min, int(period_min * 0.75))
	if search_max <= search_min + 2:
		return _yin_detect(mono)

	# Step 1: diff[tau] only up to search_max (rest stays defaulted to 0; cmnd
	# at those τ defaults to 1.0 below so threshold-crossing never matches).
	var diff := PackedFloat32Array()
	diff.resize(search_max + 1)
	for tau in range(1, search_max + 1):
		var sum := 0.0
		var jmax := n - search_max
		for j in range(jmax):
			var delta := mono[j] - mono[j + tau]
			sum += delta * delta
		diff[tau] = sum

	# Step 2: cmnd over the same range.
	var cmnd := PackedFloat32Array()
	cmnd.resize(search_max + 1)
	cmnd[0] = 1.0
	var running_sum := 0.0
	for tau in range(1, search_max + 1):
		running_sum += diff[tau]
		if running_sum < 0.0001:
			cmnd[tau] = 1.0
		else:
			cmnd[tau] = diff[tau] * float(tau) / running_sum

	# Step 3: threshold search within the adaptive bounds.
	var best_tau := -1
	for tau in range(search_min, search_max):
		if cmnd[tau] < YIN_THRESHOLD:
			while tau + 1 < search_max and cmnd[tau + 1] < cmnd[tau]:
				tau += 1
			best_tau = tau
			break

	if best_tau < 1:
		return {"detected": false}

	# Step 4: parabolic interpolation.
	var refined_tau := float(best_tau)
	if best_tau > 0 and best_tau < search_max:
		var s0 := cmnd[best_tau - 1]
		var s1 := cmnd[best_tau]
		var s2 := cmnd[best_tau + 1]
		var denom := 2.0 * s1 - s0 - s2
		if absf(denom) > 0.0001:
			refined_tau = float(best_tau) + (s0 - s2) / (2.0 * denom)

	var freq := _sample_rate / refined_tau
	var conf := 1.0 - cmnd[best_tau]
	return {"detected": true, "freq": freq, "confidence": conf}


# YIN autocorrelation pitch detection
func _yin_detect(mono: PackedFloat32Array) -> Dictionary:
	var n := mono.size()
	var max_period := int(_sample_rate / MIN_FREQ)  # ~678 samples for 65Hz @ 44.1kHz
	var min_period := int(_sample_rate / MAX_FREQ)  # ~31 samples for 1400Hz @ 44.1kHz
	max_period = mini(max_period, n / 2)
	if max_period <= min_period:
		return {"detected": false}

	# Step 1: Difference function d(tau)
	var diff := PackedFloat32Array()
	diff.resize(max_period + 1)
	diff[0] = 0.0
	for tau in range(1, max_period + 1):
		var sum := 0.0
		for j in range(n - max_period):
			var delta := mono[j] - mono[j + tau]
			sum += delta * delta
		diff[tau] = sum

	# Step 2: Cumulative mean normalized difference d'(tau)
	var cmnd := PackedFloat32Array()
	cmnd.resize(max_period + 1)
	cmnd[0] = 1.0
	var running_sum := 0.0
	for tau in range(1, max_period + 1):
		running_sum += diff[tau]
		if running_sum < 0.0001:
			cmnd[tau] = 1.0
		else:
			cmnd[tau] = diff[tau] * float(tau) / running_sum

	# Step 3: Find first tau below threshold (absolute threshold method)
	var best_tau := -1
	for tau in range(min_period, max_period):
		if cmnd[tau] < YIN_THRESHOLD:
			# Find the local minimum after crossing threshold
			while tau + 1 < max_period and cmnd[tau + 1] < cmnd[tau]:
				tau += 1
			best_tau = tau
			break

	if best_tau < 1:
		return {"detected": false}

	# Step 4: Parabolic interpolation for sub-sample accuracy
	var refined_tau := float(best_tau)
	if best_tau > 0 and best_tau < max_period:
		var s0 := cmnd[best_tau - 1]
		var s1 := cmnd[best_tau]
		var s2 := cmnd[best_tau + 1]
		var denom := 2.0 * s1 - s0 - s2
		if absf(denom) > 0.0001:
			refined_tau = float(best_tau) + (s0 - s2) / (2.0 * denom)

	var freq := _sample_rate / refined_tau
	var conf := 1.0 - cmnd[best_tau]  # Higher = better
	return {"detected": true, "freq": freq, "confidence": conf}


# Frequency / MIDI / note name utilities
static func freq_to_midi(freq: float) -> int:
	return int(round(12.0 * log(freq / 440.0) / log(2.0) + 69.0))


static func midi_to_note_name(midi: int) -> String:
	return NOTE_NAMES[posmod(midi, 12)]


static func midi_to_octave(midi: int) -> int:
	return (midi / 12) - 1


static func midi_to_full_name(midi: int) -> String:
	return "%s%d" % [midi_to_note_name(midi), midi_to_octave(midi)]


static func note_name_matches(detected: String, target: String) -> bool:
	if detected == target:
		return true
	# Enharmonic equivalents
	var enharmonics := {
		"C#": "Db", "Db": "C#",
		"D#": "Eb", "Eb": "D#",
		"F#": "Gb", "Gb": "F#",
		"G#": "Ab", "Ab": "G#",
		"A#": "Bb", "Bb": "A#",
	}
	return enharmonics.get(detected, "") == target
