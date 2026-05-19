class_name PitchDetector
extends RefCounted

# YIN-based autocorrelation pitch detector for mic input.
# Usage: setup(owner_node) -> start_listening() -> poll() each frame -> stop_listening()

const NOTE_NAMES := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
const SAMPLE_RATE := 44100
const MIN_FREQ := 65.0   # C2
const MAX_FREQ := 1400.0  # ~F6
const MIN_BUFFER := 2048
const YIN_THRESHOLD := 0.15
const CONFIDENCE_THRESHOLD := 0.60
const STABILITY_REQUIRED := 3

var _capture: AudioEffectCapture = null
var _mic_player: AudioStreamPlayer = null
var _bus_idx: int = -1
var _is_listening := false
var _stable_midi: int = -1
var _stable_count: int = 0
var _last_detected_midi: int = -1
var _setup_done := false


func setup(owner: Node) -> bool:
	if _setup_done:
		return true
	# Create a dedicated mic capture bus (muted so we don't hear the mic)
	_bus_idx = AudioServer.bus_count
	AudioServer.add_bus(_bus_idx)
	AudioServer.set_bus_name(_bus_idx, "MicCapture")
	AudioServer.set_bus_mute(_bus_idx, true)
	AudioServer.set_bus_send(_bus_idx, "Master")

	_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(_bus_idx, _capture)

	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = &"MicCapture"
	owner.add_child(_mic_player)
	_setup_done = true
	return true


func start_listening() -> void:
	if not _setup_done or _mic_player == null:
		return
	_stable_midi = -1
	_stable_count = 0
	_last_detected_midi = -1
	_capture.clear_buffer()
	_mic_player.play()
	_is_listening = true


func stop_listening() -> void:
	if _mic_player != null and _mic_player.playing:
		_mic_player.stop()
	_is_listening = false
	_stable_midi = -1
	_stable_count = 0


func is_listening() -> bool:
	return _is_listening


func poll() -> Dictionary:
	if not _is_listening or _capture == null:
		return {"detected": false}

	var frames_avail := _capture.get_frames_available()
	if frames_avail < MIN_BUFFER:
		return {"detected": false}

	# Read available frames (take at most 4096 to keep processing fast)
	var read_count := mini(frames_avail, 4096)
	var buffer: PackedVector2Array = _capture.get_buffer(read_count)
	if buffer.size() < MIN_BUFFER:
		return {"detected": false}

	# Convert stereo to mono
	var mono := PackedFloat32Array()
	mono.resize(buffer.size())
	var rms := 0.0
	for i in buffer.size():
		var sample := (buffer[i].x + buffer[i].y) * 0.5
		mono[i] = sample
		rms += sample * sample
	rms = sqrt(rms / float(buffer.size()))

	# Volume gate -- reject silence / background noise
	if rms < 0.01:
		_stable_count = 0
		return {"detected": false}

	# Run YIN pitch detection
	var result := _yin_detect(mono)
	if not result["detected"]:
		_stable_count = 0
		return {"detected": false}

	var freq: float = result["freq"]
	var confidence: float = result["confidence"]
	if confidence < CONFIDENCE_THRESHOLD:
		_stable_count = 0
		return {"detected": false}

	var midi := freq_to_midi(freq)
	if midi < 24 or midi > 96:  # C1 to C7 safety range
		_stable_count = 0
		return {"detected": false}

	# Stability filter -- require N consecutive frames with same MIDI note
	if midi == _stable_midi:
		_stable_count += 1
	else:
		_stable_midi = midi
		_stable_count = 1

	if _stable_count < STABILITY_REQUIRED:
		return {"detected": false}

	_last_detected_midi = midi
	return {
		"detected": true,
		"freq": freq,
		"midi": midi,
		"note_name": midi_to_note_name(midi),
		"octave": midi_to_octave(midi),
		"full_name": midi_to_full_name(midi),
		"confidence": confidence,
	}


# YIN autocorrelation pitch detection
func _yin_detect(mono: PackedFloat32Array) -> Dictionary:
	var n := mono.size()
	var max_period := int(SAMPLE_RATE / MIN_FREQ)  # ~678 samples for 65Hz
	var min_period := int(SAMPLE_RATE / MAX_FREQ)  # ~31 samples for 1400Hz
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

	var freq := SAMPLE_RATE / refined_tau
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
