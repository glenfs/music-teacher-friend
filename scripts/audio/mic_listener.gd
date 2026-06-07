class_name MicListener
extends RefCounted

# Thin per-panel wrapper around the host's PitchDetector. Owns no audio
# resources itself — start/stop/poll are routed to host-injected callables, so
# a single PitchDetector instance can be shared across panels that swap focus
# (Chord Explorer, Practice Drills, Sight Singing) without each spinning up
# its own mic bus.
#
# Usage:
#   var mic := MicListener.new()
#   mic.setup(start_cb, stop_cb, poll_cb)            # mandatory
#   mic.note_detected.connect(_on_mic_note_detected)
#   mic.status_changed.connect(_on_mic_status_changed)
#   mic.start()                                       # turn mic on
#   # in _process(delta): mic.tick()
#   mic.stop()                                        # when done

signal note_detected(midi: int, note_name: String, full_name: String, cents_off: float)
signal status_changed(text: String, listening: bool)

# Re-emit the same MIDI only after this gap. A sustained sung/held note would
# otherwise fire dozens of detections; the gap turns it into one event with
# occasional refresh (handy for "hold a chord" arpeggio modes where the user
# strikes one note then quickly retriggers it).
const SAME_NOTE_REPEAT_GAP_SEC := 0.40

var _start_cb: Callable = Callable()
var _stop_cb: Callable = Callable()
var _poll_cb: Callable = Callable()
var _set_target_pc_cb: Callable = Callable()
var _is_listening: bool = false
var _last_emitted_midi: int = -1
var _last_emit_time: float = -1.0
var _same_note_repeat_gap_sec: float = SAME_NOTE_REPEAT_GAP_SEC


func setup(start_cb: Callable, stop_cb: Callable, poll_cb: Callable, set_target_pc_cb: Callable = Callable()) -> void:
	_start_cb = start_cb
	_stop_cb = stop_cb
	_poll_cb = poll_cb
	_set_target_pc_cb = set_target_pc_cb


func start() -> bool:
	if not _start_cb.is_valid():
		status_changed.emit("Mic unavailable.", false)
		return false
	var ok: bool = bool(_start_cb.call())
	_is_listening = ok
	_last_emitted_midi = -1
	_last_emit_time = -1.0
	if ok:
		status_changed.emit("Mic: listening...", true)
	else:
		status_changed.emit("Mic unavailable.", false)
	return ok


func stop() -> void:
	if _stop_cb.is_valid():
		_stop_cb.call()
	_is_listening = false
	_last_emitted_midi = -1
	_last_emit_time = -1.0
	status_changed.emit("Mic off.", false)


func is_listening() -> bool:
	return _is_listening


# Bias octave correction toward this pitch class (0=C..11=B). Pass -1 to clear.
# Only takes effect when the host wired set_target_pc_cb in setup().
func set_target_pitch_class(pc: int) -> void:
	if _set_target_pc_cb.is_valid():
		_set_target_pc_cb.call(pc)


func set_same_note_repeat_gap(seconds: float) -> void:
	_same_note_repeat_gap_sec = clampf(seconds, 0.02, SAME_NOTE_REPEAT_GAP_SEC)


# Called once per frame by the owning panel's _process. Polls the host's
# PitchDetector and emits note_detected on stable detections.
func tick() -> void:
	if not _is_listening or not _poll_cb.is_valid():
		return
	var result: Dictionary = _poll_cb.call()
	if result.is_empty():
		return
	if not result.get("detected", false):
		var reason := str(result.get("reason", ""))
		if reason == "too_quiet":
			status_changed.emit("Mic: too quiet — play/sing louder.", true)
		elif reason == "stabilizing":
			status_changed.emit("Mic: hold the note...", true)
		elif reason == "no_frames":
			var nfp := int(result.get("no_frame_polls", 0))
			if nfp > 45:
				status_changed.emit("Mic: no input. Check permission/device.", true)
			else:
				status_changed.emit("Mic: waiting for input...", true)
		elif reason == "polyphonic":
			status_changed.emit("Mic: play one note at a time.", true)
		elif reason == "no_pitch" or reason == "low_confidence":
			status_changed.emit("Mic: hold a steady pitch.", true)
		else:
			status_changed.emit("Mic: listening...", true)
		return
	var midi: int = int(result.get("midi", -1))
	if midi < 0:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if midi == _last_emitted_midi and (now - _last_emit_time) < _same_note_repeat_gap_sec:
		return
	_last_emitted_midi = midi
	_last_emit_time = now
	var note_name: String = str(result.get("note_name", ""))
	var full_name: String = str(result.get("full_name", note_name))
	var cents_off: float = float(result.get("cents_off", 0.0))
	var status_text: String
	if absf(cents_off) > 5.0:
		status_text = "Heard: %s (%+d cents)" % [full_name, int(round(cents_off))]
	else:
		status_text = "Heard: %s" % full_name
	status_changed.emit(status_text, true)
	note_detected.emit(midi, note_name, full_name, cents_off)
