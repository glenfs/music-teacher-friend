class_name NoteChaseRuntime
extends RefCounted

# State container + pure mutators for Note Chase runtime. Owns the 26
# runtime variables that previously lived as _note_chase_* on the parent,
# plus the active-notes array. Parent (interval_birds.gd) keeps the widget
# refs + SFX + result-modal coordination and calls into the runtime for
# state queries / mutations.
#
# RefCounted (not Node) — held with a strict type-annotated reference in
# the parent so Godot 4.6's typed-property dispatch works correctly across
# scripts (Node-based access goes through Variant and breaks Array[Dict]
# writes). No scene-tree lifecycle needed — this is pure data + methods.


const NoteChaseDifficultyScript = preload("res://scripts/exercises/note_chase_difficulty.gd")
const NoteChasePhysicsScript = preload("res://scripts/exercises/note_chase_physics.gd")


# --- Round / loop state ---
var running: bool = false
var elapsed: float = 0.0
var spawned: int = 0

# --- Spawn pacing ---
var spawn_timer: float = 0.0
var spawn_interval: float = 1.2
var base_spawn_interval: float = 1.2

# --- Scroll speed ---
var scroll_speed: float = 95.0
var base_scroll_speed: float = 95.0
var staff_scroll_x: float = 0.0

# --- Difficulty ramp ---
var speed_stage: int = 0
var last_theme_stage: int = -1

# --- Score / accuracy ---
var correct_streak: int = 0
var correct_clicks: int = 0
var wrongs: int = 0
var combo_mult: int = 1
var target_spawn_streak: int = 0

# --- Effects ---
var fever_active: bool = false
var fever_timer: float = 0.0
var boss_active: bool = false
var boss_timer: float = 0.0
var boss_last_stage: int = -1
var freeze_timer: float = 0.0
var shield_timer: float = 0.0

# --- Clef switch (Both mode) ---
var clef_switch_cd: float = 0.0

# --- De-dup ---
var last_spawn_note: String = ""

# --- The live note panels ---
var active_notes: Array[Dictionary] = []


# Reset every per-round var to its starting value. Caller calls this when
# beginning a new Note Chase round, BEFORE applying speed-stage and the
# 3-2-1-Go count-in.
func reset_for_round() -> void:
	running = false
	elapsed = 0.0
	spawned = 0
	spawn_timer = 0.0
	staff_scroll_x = 0.0
	speed_stage = 0
	correct_streak = 0
	correct_clicks = 0
	wrongs = 0
	combo_mult = 1
	target_spawn_streak = 0
	fever_active = false
	fever_timer = 0.0
	boss_active = false
	boss_timer = 0.0
	boss_last_stage = -1
	last_theme_stage = -1
	clef_switch_cd = 0.0
	freeze_timer = 0.0
	shield_timer = 0.0
	last_spawn_note = ""
	active_notes.clear()


# Append a fresh note dict to active_notes. Typed wrapper so cross-script
# access doesn't trip over Godot 4.6's strict-Array dispatch (parent calls
# this instead of `_note_chase_runtime.active_notes.append(...)`).
func add_active_note(n: Dictionary) -> void:
	active_notes.append(n)


# Replace the entire active_notes array (e.g. after a clef-switch wipe or
# the per-frame "keep alive" filter in the update loop). Caller passes a
# strict Array[Dictionary] — same dispatch concern as add_active_note.
func set_active_notes(notes: Array[Dictionary]) -> void:
	active_notes = notes


# Update a single active_notes entry in place (used by the click handler
# after recording a hit / setting click_cd / clearing decoy state).
func update_active_note(idx: int, n: Dictionary) -> void:
	if idx >= 0 and idx < active_notes.size():
		active_notes[idx] = n


# Default speed profile (the "Speed selector removed from menu; keep
# default Normal profile" call site).
func set_default_speed_profile() -> void:
	base_scroll_speed = 82.0
	base_spawn_interval = 1.38


func start_fever() -> void:
	fever_active = true
	fever_timer = 5.0


func start_boss(stage: int) -> void:
	boss_active = true
	boss_timer = 20.0
	boss_last_stage = stage


# Caller queries this to decide whether to start a new spawn cycle. Encapsulates
# the freeze-pauses-spawning + boss-density-bump rules.
func effective_spawn_interval() -> float:
	if boss_active:
		return spawn_interval * 0.62
	return spawn_interval


# Increment streak after a correct target hit. Returns
# {fever_now: bool, level_up_now: bool, new_stage: int} so the caller can
# trigger fever / level-up side effects without re-computing rules.
func record_correct_hit() -> Dictionary:
	correct_clicks += 1
	correct_streak += 1
	var fever_now := correct_streak == 8 or correct_streak == 16 or correct_streak == 24
	var level_up_now := correct_streak > 0 and correct_streak % 8 == 0
	var new_stage := speed_stage
	if level_up_now:
		new_stage = mini(12, speed_stage + 1)
		speed_stage = new_stage
	return {
		"fever_now": fever_now,
		"level_up_now": level_up_now,
		"new_stage": new_stage,
	}


# Status-row text for the in-flight effects (freeze / fever / boss countdowns).
func progress_text() -> String:
	var parts: Array[String] = []
	if freeze_timer > 0.0:
		parts.append("Freeze %.1fs" % freeze_timer)
	if fever_active:
		parts.append("Fever %.1fs" % fever_timer)
	if boss_active:
		parts.append("Boss %.1fs" % boss_timer)
	return " | ".join(parts) if not parts.is_empty() else ""


# True when player has reached max difficulty and isn't in a boss round.
# Caller treats this as the win condition.
func is_round_complete() -> bool:
	return speed_stage >= 12 and not boss_active
