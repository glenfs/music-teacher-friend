class_name RhythmFlowRuntime
extends RefCounted

# State container for Rhythm Flow runtime. Owns the ~30 runtime vars that
# previously lived as _rhythm_flow_* on the parent. Same pattern as
# NoteChaseRuntime: RefCounted (not Node) held with a strict-typed reference
# so Godot 4.6's typed property dispatch works correctly across scripts.
#
# Parent (interval_birds.gd) keeps the widget refs + audio engine + setup
# UI and calls into the runtime for state queries/mutations. Typed-Array
# writes go through helper methods to avoid Variant-dispatch traps.


# --- Tempo / count-in ---
var bpm: int = 44
var paused: bool = false
var count_in_beats: int = 4
var count_in_seconds: float = 0.0
var count_in_announced: int = -1

# --- Patterns + events ---
var patterns: Array[Array] = []
var events: Array[Dictionary] = []
var next_spawn_idx: int = 0
var generated_bars: Array[String] = []
var generator: RefCounted = null

# --- Difficulty / seed ---
var difficulty_level: int = 1
var seed_base: int = -1
var seed_offset: int = 0
var next_seed: int = -1

# --- Scoring / input ---
var ok_hits: int = 0
var wrong_taps: int = 0
var last_click_beat_index: int = -1
var session_mode: int = 0  # 0 = playing, 1 = demo
var scoring_enabled: bool = true
var input_enabled: bool = true
var demo_next_event_idx: int = 0
var last_start_demo_mode: bool = false

# --- Toggles ---
var metronome_enabled: bool = true
var triplet_assist_enabled: bool = true
var triplet_guides_enabled: bool = true
var tap_latency_ms: int = 0
var syncing_ui_controls: bool = false

# --- Saved maps (user's saved patterns, max 5 slots) ---
var saved_maps: Array[Dictionary] = []


# --- Typed-Array write helpers (Godot 4.6 cross-script Variant dispatch) ---


# Replace the entire events array (e.g. after rebuilding from patterns).
func set_events(new_events: Array[Dictionary]) -> void:
	events = new_events


func clear_events() -> void:
	events.clear()


func add_event(evt: Dictionary) -> void:
	events.append(evt)


# Replace the entire saved_maps array (after ensure_slots cleanup, etc.).
func set_saved_maps(new_maps: Array[Dictionary]) -> void:
	saved_maps = new_maps


func clear_saved_maps() -> void:
	saved_maps.clear()


func append_saved_map(slot: Dictionary) -> void:
	saved_maps.append(slot)


func update_saved_map(idx: int, slot: Dictionary) -> void:
	if idx >= 0 and idx < saved_maps.size():
		saved_maps[idx] = slot


# Replace the entire generated_bars array (after a fresh generator run).
func set_generated_bars(bars: Array[String]) -> void:
	generated_bars = bars


func clear_generated_bars() -> void:
	generated_bars.clear()


func append_generated_bar(bar: String) -> void:
	generated_bars.append(bar)


# Replace the entire patterns array (after rebuilding from generated bars).
func set_patterns(new_patterns: Array[Array]) -> void:
	patterns = new_patterns
