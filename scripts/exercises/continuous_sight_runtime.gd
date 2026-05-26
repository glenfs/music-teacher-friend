class_name ContinuousSightRuntime
extends RefCounted

# State container for Continuous Sight Reading (Note Flow / Rhythm Flow share
# the same scrolling-notes runtime). Same RefCounted pattern as the other
# Runtime modules.


# --- Round / loop state ---
var active: bool = false
var duration: float = 30.0
var elapsed: float = 0.0
var spawn_timer: float = 0.0
var waiting_start: bool = false

# --- Notes ---
var notes: Array[Dictionary] = []

# --- Tempo / scroll ---
var bpm: int = 80
var speed: float = 70.0
var base_speed: float = 70.0

# --- Hit detection ---
var hit_window: float = 24.0
var hit_window_base: float = 24.0
var zone_width: float = 64.0
var zone_width_base: float = 64.0
var early_window_mult: float = 1.35
var early_window_mult_base: float = 1.35

# --- Scoring ---
var total_hits: int = 0
var correct_hits: int = 0
var combo: int = 0
var best_combo: int = 0
var perfect_hits: int = 0
var good_hits: int = 0
var miss_hits: int = 0
var reaction_sum: float = 0.0
var reaction_count: int = 0

# --- Difficulty ---
var level: int = 1
var level_bounds: Vector2i = Vector2i(6, 10)
var allow_accidentals: bool = false


# --- Typed-Array write helpers ---


func set_notes(new_notes: Array[Dictionary]) -> void:
	notes = new_notes


func clear_notes() -> void:
	notes.clear()


func add_note(n: Dictionary) -> void:
	notes.append(n)


func update_note(idx: int, n: Dictionary) -> void:
	if idx >= 0 and idx < notes.size():
		notes[idx] = n
