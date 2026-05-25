class_name NoteChaseDifficulty
extends RefCounted

# Pure difficulty / scoring / theming helpers for Note Chase mode.
# Caller owns the live stage / fever / boss / combo state and passes it in.
# Color tables move into the module so they're not rebuilt on every refresh.


const BGM_PATH := "res://assets/audio/sfx/module-complete.wav"

const NOTE_COLORS := [
	Color(1.0, 0.47, 0.73, 0.97), # pink
	Color(0.34, 0.58, 0.98, 0.97), # blue
	Color(0.35, 0.95, 0.95, 0.97), # cyan
	Color(0.66, 0.46, 0.96, 0.97), # purple
	Color(0.54, 0.35, 0.92, 0.97), # violet
	Color(0.13, 0.58, 0.25, 0.97), # dark green
	Color(0.96, 0.66, 0.36, 0.97), # warm orange
	Color(1.0, 0.41, 0.41, 0.97), # coral red
	Color(0.41, 0.93, 0.64, 0.97), # mint
	Color(0.98, 0.80, 0.25, 0.97), # amber
	Color(0.31, 0.84, 0.96, 0.97), # sky
	Color(0.92, 0.42, 0.84, 0.97), # magenta
	Color(0.74, 0.90, 0.34, 0.97), # lime
	Color(0.98, 0.52, 0.67, 0.97), # rose
	Color(0.44, 0.82, 0.76, 0.97), # teal mint
	Color(0.86, 0.60, 0.30, 0.97), # bronze
]

const STAFF_COLORS := [
	Color(1.0, 0.84, 0.40, 0.96),
	Color(0.45, 0.86, 1.0, 0.96),
	Color(1.0, 0.62, 0.78, 0.96),
	Color(0.58, 0.95, 0.66, 0.96),
	Color(0.83, 0.62, 1.0, 0.96),
	Color(1.0, 0.56, 0.38, 0.96),
	Color(0.48, 0.92, 0.78, 0.96),
	Color(0.94, 0.72, 0.34, 0.96),
	Color(0.35, 0.78, 0.98, 0.96),
	Color(0.94, 0.54, 0.88, 0.96),
	Color(0.72, 0.92, 0.35, 0.96),
	Color(0.94, 0.64, 0.46, 0.96),
]

const THEME_TINTS := [
	Color(0.90, 0.96, 1.0, 1.0),
	Color(1.0, 0.90, 0.96, 1.0),
	Color(0.90, 1.0, 1.0, 1.0),
	Color(0.94, 0.90, 1.0, 1.0),
	Color(0.92, 0.88, 1.0, 1.0),
	Color(0.88, 1.0, 0.90, 1.0),
	Color(1.0, 0.92, 0.84, 1.0),
	Color(0.86, 0.97, 0.93, 1.0),
	Color(0.98, 0.89, 0.83, 1.0),
	Color(0.90, 0.94, 1.0, 1.0),
	Color(0.89, 0.98, 0.92, 1.0),
	Color(0.98, 0.91, 0.90, 1.0),
	Color(0.91, 0.93, 0.99, 1.0),
]


# MVP-locked: only Treble is unlocked. Easy to remove the gate once Bass/Both
# clef variants are validated for Note Chase.
static func is_clef_enabled(clef_mode: String) -> bool:
	return clef_mode == "Treble"


# Stage-based scroll-speed multiplier. Curve is hand-tuned; level 6+ adds a
# small extra bump per level so the late game keeps ramping.
static func speed_multiplier(stage: int) -> float:
	var s := mini(stage, 12)
	var curve := [1.18, 1.62, 1.66, 1.84, 2.02, 2.24, 2.46, 2.68, 2.90, 3.12, 3.34, 3.56, 3.78]
	var mul := float(curve[s])
	if s >= 5:
		mul += 0.04 * float(s - 4)
	return mul


static func points_per_note(stage: int) -> int:
	return 10 + (stage * 2)


# Fraction of spawns that should be the player's target letter (vs. decoys).
# Higher when the player has fewer letters selected so the round still has
# meaningful target density.
static func target_bias(selected_count: int, boss_active: bool) -> float:
	var n := maxi(1, selected_count)
	var base := 0.72
	if n == 2:
		base = 0.60
	elif n >= 3:
		base = 0.48
	if boss_active:
		base += 0.10
	return clampf(base, 0.35, 0.86)


static func decoy_chance(stage: int, boss_active: bool) -> float:
	if stage < 2:
		return 0.0
	var c := 0.10 + (0.02 * float(stage - 2))
	if boss_active:
		c += 0.08
	return clampf(c, 0.0, 0.34)


static func rainbow_chance(stage: int) -> float:
	if stage < 3:
		return 0.0
	var c := 0.07 + (0.01 * float(stage - 3))
	if stage >= 6:
		c += 0.012
	if stage >= 9:
		c += 0.016
	return clampf(c, 0.0, 0.16)


# Score multiplier folds in fever, boss, and combo bonuses.
static func score_multiplier(fever_active: bool, boss_active: bool, combo_mult: int) -> float:
	var mul := 1.0
	if fever_active:
		mul *= 2.0
	if boss_active:
		mul *= 2.0
	mul *= float(maxi(1, combo_mult))
	return mul


# Picks a note color from the cyclic palette based on the current stage,
# so each level visually shifts.
static func stage_note_color(stage: int) -> Color:
	if NOTE_COLORS.is_empty():
		return Color(0.99, 0.99, 0.99, 0.97)
	return NOTE_COLORS[stage % NOTE_COLORS.size()]


static func stage_staff_color(stage: int) -> Color:
	if STAFF_COLORS.is_empty():
		return Color(1.0, 0.84, 0.40, 0.96)
	return STAFF_COLORS[stage % STAFF_COLORS.size()]


static func stage_theme_tint(stage: int) -> Color:
	if THEME_TINTS.is_empty():
		return Color(0.90, 0.96, 1.0, 1.0)
	return THEME_TINTS[stage % THEME_TINTS.size()]


# Per-clef step pool for the current stage. Steps are vertical staff
# positions (negative = above the top line; positive = below the bottom
# line; 0..8 = the five lines and four spaces).
#
# The pool grows with stage: level 1 already includes the milestone notes
# (B3 / D4 for treble, B3 / D4 / E4 for bass), level 1+ adds the immediate
# ledger neighbors, level 6+ adds far ledger notes. Caller passes
# safe_top/bottom from the staff frame layout to filter unreachable notes,
# and a step→y resolver so this module stays UI-free.
static func step_pool(clef: String, stage: int, safe_top: float, safe_bottom: float, step_to_y_fn: Callable) -> Array[int]:
	var pool: Array[int] = []
	if clef == "Bass":
		for s in range(-2, 6):
			if not pool.has(s):
				pool.append(s)
		if not pool.has(-1):
			pool.append(-1)  # B3
		if stage >= 0:
			if not pool.has(-3):
				pool.append(-3)  # D4
			if not pool.has(-4):
				pool.append(-4)  # E4
		if stage >= 5:
			if not pool.has(11):
				pool.append(11)  # D2
			if not pool.has(12):
				pool.append(12)  # C2
		if stage >= 1:
			for s in range(6, 11):
				if not pool.has(s):
					pool.append(s)
	else:
		for s in range(4, 11):
			if not pool.has(s):
				pool.append(s)
		if not pool.has(9):
			pool.append(9)  # D4
		if stage >= 0:
			if not pool.has(11):
				pool.append(11)  # B3
			if not pool.has(12):
				pool.append(12)  # A3
			for s in range(-3, 4):
				if not pool.has(s):
					pool.append(s)
		if stage >= 5:
			if not pool.has(-4):
				pool.append(-4)  # C6
	var filtered: Array[int] = []
	for s in pool:
		var y: float = float(step_to_y_fn.call(s))
		if y >= safe_top and y <= safe_bottom:
			filtered.append(s)
	# Required milestone notes survive even if their y falls in the safe-edge gap.
	var required_steps: Array[int] = []
	if clef == "Bass":
		required_steps.append(-1)
		if stage >= 0:
			required_steps.append(-3)
			required_steps.append(-4)
		if stage >= 5:
			required_steps.append(11)
			required_steps.append(12)
	else:
		required_steps.append(9)
		if stage >= 0:
			required_steps.append(11)
			required_steps.append(12)
		if stage >= 5:
			required_steps.append(-4)
	for rs in required_steps:
		if pool.has(rs) and not filtered.has(rs):
			filtered.append(rs)
	# Absolute clef bounds: Treble max C6 (step -4), Bass max C2 (step 12).
	var bounded: Array[int] = []
	for s in filtered:
		if clef == "Treble":
			if s < -4:
				continue
		elif clef == "Bass":
			if s > 12:
				continue
		bounded.append(s)
	if not bounded.is_empty():
		return bounded
	if pool.is_empty():
		pool = [4, 5, 6, 7, 8]
	return pool
