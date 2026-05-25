class_name RhythmFlowLibrary
extends RefCounted

# Pure rhythm-flow data tables + timing/judgement helpers. Caller owns the
# live difficulty level + per-event triplet-assist flags + BPM + saved-map
# storage and queries this module for the stateless layer.


const TAP_SFX_PATH := "res://assets/audio/sfx/178668__hanbaal__snare.wav"
const DOWNBEAT_SFX_PATH := "res://assets/audio/sfx/50982__matiasreccius__bass2.wav"

# Session-mode flags. Playing = normal scored run; Demo = autoplay walkthrough.
const SESSION_PLAYING := 0
const SESSION_DEMO := 1


# Timing windows in seconds: how close to the expected beat counts as
# "perfect" / "good" / "ok" hit. Caller may multiply these for triplet assist
# via timing_windows_for_event().
static func timing_windows() -> Dictionary:
	return {"perfect": 0.050, "good": 0.100, "ok": 0.200}


# Per-event windows: identity for non-triplet events; for triplets, widens
# windows because triplet timing is harder. t4 (quarter-note triplets) get
# the widest assist; default triplet token gets a smaller bump.
static func timing_windows_for_event(evt: Dictionary, triplet_assist_enabled: bool) -> Dictionary:
	var wins := timing_windows().duplicate()
	if not triplet_assist_enabled:
		return wins
	if not bool(evt.get("triplet", false)):
		return wins
	var token := str(evt.get("triplet_token", ""))
	var perfect_mult := 1.25
	var good_mult := 1.35
	var ok_mult := 1.45
	if token == "t4":
		perfect_mult = 1.35
		good_mult = 1.50
		ok_mult = 1.65
	wins["perfect"] = float(wins.get("perfect", 0.050)) * perfect_mult
	wins["good"] = float(wins.get("good", 0.100)) * good_mult
	wins["ok"] = float(wins.get("ok", 0.200)) * ok_mult
	return wins


# Convert input-latency setting from ms to seconds.
static func tap_latency_sec(tap_latency_ms: int) -> float:
	return float(tap_latency_ms) / 1000.0


# Seconds per beat at the given BPM.
static func seconds_per_beat(bpm: int) -> float:
	return 60.0 / float(maxi(1, bpm))


# Triplet snap window: how close a tap has to be to a triplet subdivision
# for the snapping assist to engage. Wider for quarter-note triplets.
static func triplet_snap_window_sec(evt: Dictionary, seconds_per_beat_value: float) -> float:
	var step_sec := seconds_per_beat_value / 3.0
	if step_sec <= 0.0:
		return 0.0
	var token := str(evt.get("triplet_token", ""))
	if token == "t4":
		return minf(0.110, step_sec * 0.45)
	return minf(0.085, step_sec * 0.38)


# If a triplet tap is close enough to a triplet subdivision, snap it to that
# subdivision so timing judgement uses the snapped value. Falls back to the
# raw tap when the snap is too far off or assist is disabled.
static func triplet_snapped_tap_time(
	tap_t: float,
	evt: Dictionary,
	count_in_seconds: float,
	seconds_per_beat_value: float,
	triplet_assist_enabled: bool
) -> float:
	if not triplet_assist_enabled:
		return tap_t
	if not bool(evt.get("triplet", false)):
		return tap_t
	var step_sec: float = seconds_per_beat_value / 3.0
	if step_sec <= 0.0:
		return tap_t
	var rel: float = tap_t - count_in_seconds
	var snapped: float = count_in_seconds + (roundf(rel / step_sec) * step_sec)
	var snap_delta: float = absf(snapped - tap_t)
	if snap_delta > triplet_snap_window_sec(evt, seconds_per_beat_value):
		return tap_t
	var expected_t := float(evt.get("expected_time_sec", tap_t))
	var ok_win := float(timing_windows_for_event(evt, triplet_assist_enabled).get("ok", 0.2))
	if absf(snapped - expected_t) > ok_win:
		return tap_t
	return snapped


# Color for the floating judgement label (Perfect/Good/OK/Miss/Demo).
static func feedback_color(judgement: String) -> Color:
	match judgement:
		"Demo":
			return Color(0.74, 0.98, 1.0, 1.0)
		"Perfect":
			return Color(0.72, 1.0, 0.20, 1.0)
		"Good":
			return Color(0.42, 0.92, 1.0, 1.0)
		"OK":
			return Color(1.0, 0.84, 0.25, 1.0)
		_:
			return Color(1.0, 0.42, 0.42, 1.0)


# True when the event at the given index is a hit landing on a downbeat
# (beat 1 of any measure, modulo 4 — Rhythm Flow uses 4/4 throughout).
# Caller provides the events array and the count-in offset.
static func is_downbeat_event(event_idx: int, events: Array, count_in_beats: int) -> bool:
	if event_idx < 0 or event_idx >= events.size():
		return false
	var evt: Dictionary = events[event_idx]
	if str(evt.get("type", "")) != "hit":
		return false
	var start_beat := float(evt.get("start_beat", 0.0))
	var beat_in_measure := fposmod(start_beat - float(count_in_beats), 4.0)
	return absf(beat_in_measure) <= 0.001


# Empty slot for the 5-slot saved-map storage (user can save up to 5 of
# their own generated/edited patterns).
static func empty_saved_map_slot() -> Dictionary:
	return {
		"name": "",
		"bars": [],
		"difficulty_level": 1,
		"bpm": 44,
		"saved_at": "",
	}


# Migrate / pad the saved-maps array so it always has exactly 5 well-formed
# slot dicts. Returns the cleaned-up array (caller assigns it back).
static func ensure_saved_maps_slots(saved_maps: Array) -> Array:
	var out: Array = saved_maps if saved_maps != null else []
	while out.size() < 5:
		out.append(empty_saved_map_slot())
	if out.size() > 5:
		out = out.slice(0, 5)
	for i in range(out.size()):
		var slot_v: Variant = out[i]
		if typeof(slot_v) != TYPE_DICTIONARY:
			out[i] = empty_saved_map_slot()
			continue
		var slot := (slot_v as Dictionary).duplicate(true)
		if not slot.has("name"):
			slot["name"] = ""
		if not slot.has("bars") or typeof(slot["bars"]) != TYPE_ARRAY:
			slot["bars"] = []
		if not slot.has("difficulty_level"):
			slot["difficulty_level"] = 1
		if not slot.has("bpm"):
			slot["bpm"] = 44
		if not slot.has("saved_at"):
			slot["saved_at"] = ""
		out[i] = slot
	return out


# True when the slot at the given index has actual recorded bars.
static func slot_is_filled(saved_maps: Array, slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= saved_maps.size():
		return false
	var slot_v: Variant = saved_maps[slot_idx]
	if typeof(slot_v) != TYPE_DICTIONARY:
		return false
	var bars_v: Variant = (slot_v as Dictionary).get("bars", [])
	return bars_v is Array and not (bars_v as Array).is_empty()


# Compact "YYYY-MM-DD HH:MM" stamp for saved-slot timestamps.
static func now_stamp() -> String:
	var d := Time.get_date_dict_from_system()
	var t := Time.get_time_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d" % [
		int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0)),
		int(t.get("hour", 0)), int(t.get("minute", 0)),
	]


# True when any bar in the generated bars contains the given token.
static func has_token(generated_bars: Array, token_text: String) -> bool:
	if token_text.is_empty():
		return false
	for bar_v in generated_bars:
		var toks := str(bar_v).split(" ", false)
		for t in toks:
			if str(t) == token_text:
				return true
	return false


# Status-line hint suffix surfaced when a generated exercise contains
# quarter-note triplets (t4) — most players need a nudge to count "3 over 2".
static func hint_suffix_for_bars(generated_bars: Array) -> String:
	if has_token(generated_bars, "t4"):
		return " | Quarter note triplet: fit 3 notes into 2 beats."
	return ""


# Returns the exercise pattern bank for the given 1-indexed difficulty level.
# Each pattern is an Array of event dicts: {type: "hit"|"rest", duration_beats: float}.
# Levels above the table cap clamp to the densest set.
static func pattern_library(difficulty_level: int) -> Array[Array]:
	var idx := clampi(difficulty_level - 1, 0, EXERCISES.size() - 1)
	var selected: Array = EXERCISES[idx]
	var out: Array[Array] = []
	for pattern_v in selected:
		out.append(pattern_v as Array)
	return out


const EXERCISES: Array = [
	[
		[
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 4.0}
		],
		[
			{"type": "rest", "duration_beats": 2.0},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "rest", "duration_beats": 2.0}
		]
	],
	[
		[
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 4.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 2.0}
		]
	],
	[
		[
			{"type": "hit", "duration_beats": 2.0},
			{"type": "rest", "duration_beats": 2.0}
		],
		[
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 3.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 4.0}
		]
	],
	[
		# 16th-note intro (beamed pairs/runs)
		[
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 1.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 1.0}
		]
	],
	[
		# 16th-note practice (denser runs)
		[
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 2.0}
		],
		[
			{"type": "hit", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "rest", "duration_beats": 1.0},
			{"type": "hit", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.5},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "rest", "duration_beats": 1.0}
		],
		[
			{"type": "hit", "duration_beats": 3.0},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25},
			{"type": "hit", "duration_beats": 0.25}
		]
	]
]
