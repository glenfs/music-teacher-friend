class_name SightSingingRuntime
extends RefCounted

# State container for Sight Singing runtime. Owns the per-round melody +
# durations + the phrase-detection state machine. Same RefCounted pattern
# as NoteChaseRuntime / RhythmFlowRuntime: held with a strict-typed
# reference so Godot 4.6's typed-property dispatch works correctly.
#
# Parent (interval_birds.gd) keeps the widget refs + mic audio chain +
# take-playback audio engine and calls into the runtime for state queries.


# --- Round content ---
var melody: Array[int] = []
var durations: Array[float] = []
var started: bool = false  # true between round start and result display

# --- Settings (persisted between rounds via ear_settings.json) ---
var octave_strict: bool = false
var play_melody_first: bool = true
var rhythm_level: int = 1
var questions_per_round: int = 5

# --- Phrase-detection state machine ---
var phrase_detections: Array = []
var phrase_started: bool = false
var phrase_recording: bool = false
var phrase_start_msec: int = 0
var last_voice_msec: int = 0
var phrase_result: Dictionary = {}
var take_segments: Array = []
var take_curve: Array = []
var pitch_candidates: Array = []

# --- Mascot visibility (restored when round ends) ---
var prev_bird_visible: bool = false
var prev_tutorial_chicken_visible: bool = false


# --- Typed-Array write helpers ---


func set_melody(new_melody: Array[int]) -> void:
	melody = new_melody


func set_durations(new_durations: Array[float]) -> void:
	durations = new_durations


func clear_phrase_state() -> void:
	phrase_detections.clear()
	take_segments.clear()
	take_curve.clear()
	pitch_candidates.clear()
	phrase_started = false
	phrase_recording = false
	phrase_start_msec = 0
	last_voice_msec = 0
	phrase_result.clear()
