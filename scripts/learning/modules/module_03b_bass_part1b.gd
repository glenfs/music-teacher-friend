extends RefCounted

const LMD = preload("res://scripts/learning/learning_module_data.gd")


static func get_module_data() -> Dictionary:
	var steps: Array[Dictionary] = []

	# ── 1. Intro ──
	steps.append(LMD.create_intro_step(
		"More Bass Notes!",
		"You already know Middle C, B, and A in bass clef — now let's learn G and F to complete your first five bass notes!",
		"Bass Notes — Part 1B"
	))

	# Quick refresher
	steps.append(LMD.create_explanation_step(
		"Quick Refresher",
		"Remember: Middle C is on the ledger line above the staff, B is in the space above the top line, and A is on the top line. Now we'll keep going down!",
		"C (ledger) → B (space) → A (top line) → ...",
		"Notes keep alternating: line, space, line, space."
	))

	# ══════════════════════════════════════════════════════════════════════
	# GROUP C — G3 + F3
	# ══════════════════════════════════════════════════════════════════════

	# Visual: introduce G3
	steps.append(LMD.create_visual_step(
		"The Note G",
		"G is in the top space — the gap between the top line and the second line.",
		"note_on_staff",
		{"clef": "bass", "note_name": "G", "note_step": 1}
	))

	# Visual: introduce F3
	steps.append(LMD.create_visual_step(
		"The Note F",
		"F sits on the fourth line — where the bass clef dots are! The bass clef is actually called the F clef because those two dots surround the F line.",
		"note_on_staff",
		{"clef": "bass", "note_name": "F", "note_step": 2}
	))

	# Drag: G3 (hint on)
	steps.append(LMD.create_drag_note_step(
		"Drag G into the top space of the staff!",
		"bass", "G3", 1, true,
		"That's G — right in the top space!",
		"G goes in the top space, just below the top line."
	))

	# Drag: F3 (no hint)
	steps.append(LMD.create_drag_note_step(
		"Place F on the staff!",
		"bass", "F3", 2, false,
		"You got it! F is on the fourth line!",
		"F sits on the fourth line — between the bass clef dots."
	))

	# Quiz: name G3
	steps.append(LMD.create_note_quiz_step(
		"bass", "G3", 1,
		["E", "F", "G", "A"],
		2,
		"That's G — in the top space!",
		"This note is in the top space below the top line — that's G!"
	))

	# Quiz: name F3
	steps.append(LMD.create_note_quiz_step(
		"bass", "F3", 2,
		["D", "E", "F", "G"],
		2,
		"You got it! F is on the fourth line!",
		"This note is on the fourth line where the bass clef dots sit — that's F!"
	))

	# Listen & Find: F3 target, distractors G3 + A3
	steps.append(LMD.create_listen_find_step(
		"bass", "F3", 2, [1, 0],
		"Nice! That was F.",
		"Listen again — F is on the fourth line, between the bass clef dots."
	))

	# ══════════════════════════════════════════════════════════════════════
	# CONSOLIDATION — all 5 notes (C, B, A, G, F)
	# ══════════════════════════════════════════════════════════════════════

	# Recap: all 5 notes
	steps.append(LMD.create_recap_step(
		"All Five Bass Notes!",
		"Here are all five bass notes you now know:",
		[
			{"label": "C (Middle C)", "detail": "On its own ledger line above the staff", "clef": "bass", "note_step": -2},
			{"label": "B", "detail": "In the space just above the top line", "clef": "bass", "note_step": -1},
			{"label": "A", "detail": "On the top line of the staff", "clef": "bass", "note_step": 0},
			{"label": "G", "detail": "In the top space, just below the A line", "clef": "bass", "note_step": 1},
			{"label": "F", "detail": "On the fourth line — where the bass clef dots are", "clef": "bass", "note_step": 2},
		]
	))

	# Melody Example: C4 down to F3 and back
	steps.append(LMD.create_melody_example_step(
		"Simple Bass Scale",
		"These are all five notes — listen as they go down and back up!",
		"bass",
		[
			{"note_id": "C4", "note_step": -2, "beats": 1.0},
			{"note_id": "B3", "note_step": -1, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 1.0},
			{"note_id": "G3", "note_step": 1, "beats": 1.0},
			{"note_id": "F3", "note_step": 2, "beats": 2.0},
			{"note_id": "G3", "note_step": 1, "beats": 1.0},
			{"note_id": "A3", "note_step": 0, "beats": 1.0},
			{"note_id": "C4", "note_step": -2, "beats": 2.0},
		],
		"Simple Bass Scale"
	))

	# Practice Round — all 5 notes
	steps.append(LMD.create_practice_round_step(
		"Practice Round",
		"Let's practice all five bass clef notes! Name each note as it appears on the staff.",
		LMD.bass_note_pool_basic(),
		8
	))

	# Cumulative Quiz
	steps.append(LMD.create_cumulative_quiz_step(
		"Note Review",
		"Final review! Name these bass clef notes.",
		LMD.bass_note_pool_basic(),
		8
	))

	# Final Recap
	steps.append(LMD.create_recap_step(
		"Module Complete!",
		"Awesome! You've mastered your first five bass clef notes!",
		[
			{"label": "C (Middle C)", "detail": "On a ledger line above the bass staff", "clef": "bass", "note_step": -2},
			{"label": "B", "detail": "In the space just above the top line", "clef": "bass", "note_step": -1},
			{"label": "A", "detail": "On the top line of the staff", "clef": "bass", "note_step": 0},
			{"label": "G", "detail": "In the top space, just below the A line", "clef": "bass", "note_step": 1},
			{"label": "F", "detail": "On the fourth line — where the bass clef dots are!", "clef": "bass", "note_step": 2},
		]
	))

	return LMD.create_module(
		"bass_part1b",
		"Bass Notes — Part 1B",
		"Learn G and F in bass clef",
		"",
		steps,
		7,
		"Bass Beginner"
	)
